// MixNutri - firmware do ESP32 da sala piloto (item 2, equipe 1). Versao 27/10/2026.
// Histerese de UR, classificacao acustica OPERANDO/PARADO, cliente Modbus TCP opcional,
// comandos MANUAL/AUTO e configuracao via MQTT, retencao de mensagens na Flash (LittleFS).
// Parametros, topicos e politicas sao propostas didaticas a combinar com as equipes 2 e 3.
// Som em dBFS relativo ao ADC, NAO dB SPL. No Wokwi, todos os dados sao sinteticos.
#include <Arduino.h>
#include <Wire.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <LittleFS.h>
#include <esp_system.h>
#include <time.h>
#include "logica.h"
using namespace mixnutri;

// ================================================================ implantacao
#define MIXNUTRI_SIMULACAO 1  // 1 no Wokwi: origem "simulacao" e fonte acustica "sintetico"
static const char *WIFI_SSID = "Wokwi-GUEST", *WIFI_SENHA = "";
static const int WIFI_CANAL = 6;  // acelera a conexao no Wokwi; usar 0 no hardware real
// Broker publico so para demonstracao com dados sinteticos. Trocar pelo Mosquitto da
// equipe 2. No Wokwi, broker local exige o gateway privado (host.wokwi.internal).
// String vazia desliga o MQTT: tudo fica retido na fila da Flash.
static const char *MQTT_HOST = "broker.hivemq.com";
static const uint16_t MQTT_PORTA = 1883;
static const char *MQTT_USUARIO = nullptr, *MQTT_SENHA = nullptr;
static const char *TOPICO_BASE = "mixnutri/sala01";
static const char *DEVICE_ID = "sala01-esp32", *SALA_ID = "sala01";
#if MIXNUTRI_SIMULACAO
static const char *ORIGEM = "simulacao", *FONTE_SOM = "sintetico";
#else
static const char *ORIGEM = "real", *FONTE_SOM = "audio";
#endif

// ======================================================= hardware (pinagem do item 1)
static const uint8_t PIN_SDA = 21, PIN_SCL = 22, PIN_RELE = 26, PIN_SOM = 34, PIN_LED_REDE = 2;
static const uint8_t RELE_ON = HIGH, RELE_OFF = LOW;  // modulo npn: verificado no item 1
static const uint8_t SHT_ADDR = 0x44;

// ================================================================== mensagens
enum Topico : uint8_t { T_TELEMETRIA, T_EVENTOS, T_CONFIRMACOES, T_DISPONIBILIDADE,
                        T_COMANDOS, T_CONFIGURACAO, T_CONTEXTO, T_TOTAL };
static const char *SUFIXO[T_TOTAL] = {"telemetria", "eventos", "confirmacoes", "disponibilidade",
                                      "comandos", "configuracao", "contexto"};
static char topico[T_TOTAL][64];
static const size_t MSG_MAX = 1000;  // pior caso estimado: telemetria ~830 B com lotes de 32 caracteres
struct Mensagem { uint8_t topico; uint16_t n; char payload[MSG_MAX + 1]; };
static QueueHandle_t qSaida, qEntrada;  // controle -> rede, rede -> controle
static SemaphoreHandle_t mtxConfig;

// Fila na Flash: um arquivo pequeno por slot no LittleFS, para nao reescrever a fila inteira.
static const size_t SLOT = 1024, SLOTS = 192;  // ~192 KB: ~16 min de telemetria a cada 5 s
struct ArmazenamentoLittleFS {
  static void nome(size_t off, char *b, size_t n) {
    if (off < 16) snprintf(b, n, "/fila/cab");
    else snprintf(b, n, "/fila/s%03u", (unsigned)((off - 16) / SLOT));
  }
  static size_t interno(size_t off) { return off < 16 ? off : (off - 16) % SLOT; }
  bool ler(size_t off, uint8_t *p, size_t n) {
    char b[20]; nome(off, b, sizeof b);
    if (!LittleFS.exists(b)) return false;
    File f = LittleFS.open(b, "r");
    if (!f) return false;
    bool ok = f.seek(interno(off)) && f.read(p, n) == n;
    f.close();
    return ok;
  }
  bool escrever(size_t off, const uint8_t *p, size_t n) {
    if (interno(off) != 0) return false;  // FilaCircular escreve sempre do inicio
    char b[20]; nome(off, b, sizeof b);
    File f = LittleFS.open(b, "w");
    if (!f) return false;
    bool ok = f.write(p, n) == n;
    f.close();
    return ok;
  }
};
static ArmazenamentoLittleFS armazenamento;
static FilaCircular<ArmazenamentoLittleFS, SLOT, SLOTS> filaFlash(armazenamento);
static bool filaOk = false;

// Estado compartilhado com a tarefa de rede.
static volatile bool wifiOk = false, mqttOk = false, redeBloqueada = false;
static volatile uint32_t filaQtd = 0, filaPerdidas = 0, descartes = 0, reenviadas = 0;
struct LeituraModbus { bool ok; uint16_t status, falha; uint32_t em; int erro; };
static portMUX_TYPE muxModbus = portMUX_INITIALIZER_UNLOCKED;
static LeituraModbus modbusUltima = {false, 0, 0, 0, 0};

// ================================================================ estado local
static Config cfg;
static Preferences prefs;
static char bootId[16];
static char produto[33] = "NAO_INFORMADO", loteProducao[33] = "NAO_INFORMADO";
static char loteCapsula[33] = "", lotePo[33] = "";
static uint32_t seqTelemetria = 0, seqEvento = 0, comandosSerial = 0;
static char ultimoCmdId[40] = "";
static Controlador controlador;
static ClassificadorSom classificadorSom;
static RastreadorParadas paradasSom, paradasModbus;
static EstadoMaquina estadoModbus = EstadoMaquina::DESCONHECIDO;
static uint16_t codigoFalhaModbus = 0;
static JsonDocument doc, entrada;  // saida e entrada, usados so pela tarefa de controle
static Mensagem saidaTmp;

static bool climaValido = false, aguardandoClima = false;
static int8_t climaEstado = -1;  // -1 inicializando, 0 falha, 1 valido
static float temperatura = NAN, umidade = NAN;
static uint32_t pedidoClimaEm = 0, ultimoPedidoClima = 0;

// Som: amostras a 4 kHz, janelas de 256 (64 ms), blocos de 8 janelas (~0,5 s).
static uint32_t ultimaAmostraUs = 0;
static uint16_t nJanela = 0;
static uint8_t janelasBloco = 0;
static double soma = 0, somaQ = 0, potenciaBloco = 0, potenciaTelemetria = 0;
static uint32_t blocosTelemetria = 0;
static bool blocoInvalido = false, somValido = false;
static float rmsAtual = 0, dbfsAtual = -66.2f;

static uint32_t ultimaTelemetria = 0, ultimoStatus = 0, ultimoControle = 0;

// ============================================================ utilitarios
static double r1(float v) { return round((double)v * 10.0) / 10.0; }
static double r2(float v) { return round((double)v * 100.0) / 100.0; }
static bool relogioOk() { return time(nullptr) > 1700000000; }
static void tempoUtc(JsonDocument &d, const char *chave, uint32_t uptimeMs) {
  if (!relogioOk()) { d[chave] = nullptr; return; }
  time_t t = time(nullptr) - (time_t)((millis() - uptimeMs) / 1000);
  struct tm tm; gmtime_r(&t, &tm);
  char b[24]; strftime(b, sizeof b, "%Y-%m-%dT%H:%M:%SZ", &tm);
  d[chave] = b;
}
static void cabecalho(JsonDocument &d, uint32_t seq, uint32_t agora) {
  d.clear();
  d["schema_version"] = 2; d["device_id"] = DEVICE_ID; d["sala_id"] = SALA_ID;
  d["boot_id"] = bootId; d["seq"] = seq; d["uptime_ms"] = agora;
  tempoUtc(d, "timestamp_utc", agora); d["clock_synced"] = relogioOk();
  d["origem_dados"] = ORIGEM;
}
static void contexto(JsonDocument &d) {
  d["produto"] = produto; d["lote_producao"] = loteProducao;
  if (loteCapsula[0]) d["lote_capsula"] = loteCapsula; else d["lote_capsula"] = nullptr;
  if (lotePo[0]) d["lote_po"] = lotePo; else d["lote_po"] = nullptr;
}
// Serializa e entrega a tarefa de rede sem bloquear o controle.
static bool enviar(uint8_t t, JsonDocument &d, const char *eco) {
  const size_t n = measureJson(d);
  if (n > MSG_MAX) { Serial.printf("ERRO payload %u > %u bytes\n", (unsigned)n, (unsigned)MSG_MAX); ++descartes; return false; }
  saidaTmp.topico = t;
  saidaTmp.n = serializeJson(d, saidaTmp.payload, sizeof saidaTmp.payload);
  if (eco) { Serial.print(eco); Serial.println(saidaTmp.payload); }
  if (xQueueSend(qSaida, &saidaTmp, 0) != pdTRUE) { ++descartes; return false; }
  return true;
}
static JsonDocument &evento(const char *tipo, uint32_t agora) {
  cabecalho(doc, seqEvento++, agora);
  doc["tipo"] = tipo;
  contexto(doc);
  return doc;
}
static void confirmar(const char *tipo, const char *id, bool aceito, const char *motivo) {
  const uint32_t agora = millis();
  cabecalho(doc, seqEvento++, agora);
  doc["tipo"] = tipo; doc["cmd_id"] = id; doc["aceito"] = aceito; doc["motivo"] = motivo;
  doc["modo"] = nomeModo(controlador.modo); doc["rele"] = controlador.saida ? "ON" : "OFF";
  doc["manual_restante_s"] = controlador.manualRestanteMs(agora) / 1000;
  doc["config_version"] = cfg.versao;
  enviar(T_CONFIRMACOES, doc, "ACK ");
}

// ============================================================== persistencia
static const uint32_t CFG_LAYOUT = 1;
static void carregarConfig() {
  cfg = configPadrao();
  if (prefs.getUInt("cfg_layout", 0) == CFG_LAYOUT && prefs.getBytesLength("cfg") == sizeof(Config)) {
    Config c;
    prefs.getBytes("cfg", &c, sizeof c);
    c.modbus_host[sizeof c.modbus_host - 1] = '\0';
    if (validarConfig(c) == nullptr) cfg = c;
    else Serial.println("CONFIG persistida invalida; usando padrao didatico");
  }
}
static void salvarConfig() { prefs.putBytes("cfg", &cfg, sizeof cfg); prefs.putUInt("cfg_layout", CFG_LAYOUT); }
static void carregarTexto(const char *chave, char *dst, size_t n) {
  if (prefs.isKey(chave)) prefs.getString(chave, dst, n);
}
static void carregarContexto() {
  carregarTexto("produto", produto, sizeof produto); carregarTexto("lote", loteProducao, sizeof loteProducao);
  carregarTexto("lote_cap", loteCapsula, sizeof loteCapsula); carregarTexto("lote_po", lotePo, sizeof lotePo);
}
static void salvarContexto() {
  prefs.putString("produto", produto); prefs.putString("lote", loteProducao);
  prefs.putString("lote_cap", loteCapsula); prefs.putString("lote_po", lotePo);
}
static bool abrirFila() {
  if (!LittleFS.begin(true)) { Serial.println("FILA erro: LittleFS.begin falhou (particao?)"); return false; }
  if (!LittleFS.exists("/fila") && !LittleFS.mkdir("/fila")) { Serial.println("FILA erro: mkdir /fila"); return false; }
  if (!filaFlash.abrir()) { Serial.println("FILA erro: cabecalho da fila"); return false; }
  return true;
}

// ========================================================== controle do rele
static void controlar(uint32_t agora) {
  if (!controlador.passo(agora, climaValido, umidade, cfg)) return;
  digitalWrite(PIN_RELE, controlador.saida ? RELE_ON : RELE_OFF);
  JsonDocument &ev = evento("RELE", agora);
  ev["desumidificador_comandado"] = controlador.saida; ev["motivo"] = controlador.motivo;
  ev["modo"] = nomeModo(controlador.modo);
  if (climaValido) ev["umidade_pct"] = r2(umidade); else ev["umidade_pct"] = nullptr;
  enviar(T_EVENTOS, ev, "EVT ");
}

// ================================================================ SHT31 (I2C)
static void definirClima(bool valido, uint32_t agora) {
  climaValido = valido;
  if (!valido) temperatura = umidade = NAN;
  const int8_t novo = valido ? 1 : 0;
  if (novo != climaEstado) {
    if (novo == 0 || climaEstado == 0) {
      JsonDocument &ev = evento(valido ? "SENSOR_OK" : "SENSOR_FALHA", agora);
      ev["sensor"] = "SHT31";
      enviar(T_EVENTOS, ev, "EVT ");
    }
    climaEstado = novo;
  }
  controlar(agora);
}
static uint8_t crc8(const uint8_t *p) {
  uint8_t crc = 0xff;
  for (uint8_t i = 0; i < 2; ++i) {
    crc ^= p[i];
    for (uint8_t bit = 0; bit < 8; ++bit) crc = (crc & 0x80) ? (uint8_t)((crc << 1) ^ 0x31) : (uint8_t)(crc << 1);
  }
  return crc;
}
static void pedirClima(uint32_t agora) {
  Wire.beginTransmission(SHT_ADDR); Wire.write(0x24); Wire.write(0x00);  // single shot, sem stretching
  aguardandoClima = Wire.endTransmission() == 0;
  pedidoClimaEm = agora;
  if (!aguardandoClima) definirClima(false, agora);
}
static void receberClima(uint32_t agora) {
  uint8_t b[6];
  bool ok = Wire.requestFrom(SHT_ADDR, (uint8_t)6) == 6;
  if (ok) {
    for (uint8_t i = 0; i < 6; ++i) b[i] = Wire.read();
    ok = crc8(b) == b[2] && crc8(b + 3) == b[5];
  }
  while (Wire.available()) Wire.read();
  if (ok) {
    temperatura = -45.0f + 175.0f * ((uint16_t)(b[0] << 8) | b[1]) / 65535.0f;
    umidade = 100.0f * ((uint16_t)(b[3] << 8) | b[4]) / 65535.0f;
  }
  aguardandoClima = false;
  definirClima(ok, agora);
}

// ============================================================ estado da maquina
static void publicarTransicao(const char *fonte, EstadoMaquina de, EstadoMaquina para,
                              uint32_t em, const EventoParada &p, bool comFalha) {
  const uint32_t agora = millis();
  const char *tipo = p.tipo == EventoParada::INICIO ? "PARADA_INICIO"
                   : p.tipo == EventoParada::FIM ? "PARADA_FIM" : "ESTADO_MAQUINA";
  JsonDocument &ev = evento(tipo, agora);
  ev["fonte_estado"] = fonte; ev["de"] = nomeEstado(de); ev["para"] = nomeEstado(para);
  if (p.tipo != EventoParada::NENHUM) {
    char id[64];
    snprintf(id, sizeof id, "%s-%s-%s-%lu", DEVICE_ID, bootId, fonte, (unsigned long)p.numero);
    ev["evento_id"] = id;
    ev["inicio_uptime_ms"] = p.inicioMs; tempoUtc(ev, "inicio_utc", p.inicioMs);
    if (p.tipo == EventoParada::FIM) {
      ev["fim_uptime_ms"] = p.fimMs; tempoUtc(ev, "fim_utc", p.fimMs);
      ev["duracao_ms"] = p.fimMs - p.inicioMs; ev["motivo_fim"] = p.motivoFim;
    }
  } else {
    ev["confirmado_desde_ms"] = em;
  }
  if (comFalha) ev["codigo_falha"] = codigoFalhaModbus; else ev["codigo_falha"] = nullptr;
  enviar(T_EVENTOS, ev, "EVT ");
}
static void amostrarSom(uint32_t agora) {
  const uint32_t us = micros();
  if ((uint32_t)(us - ultimaAmostraUs) < 250) return;
  ultimaAmostraUs = us;
  const double x = analogRead(PIN_SOM);
  soma += x; somaQ += x * x;
  if (++nJanela < 256) return;
  const double media = soma / nJanela;
  if (media < 200 || media > 3900) blocoInvalido = true;  // sem polarizacao: sensor ausente
  potenciaBloco += fmax(0.0, somaQ / nJanela - media * media);
  soma = somaQ = 0; nJanela = 0;
  if (++janelasBloco < 8) return;
  somValido = !blocoInvalido;
  if (somValido) {
    const double p = potenciaBloco / janelasBloco;
    rmsAtual = sqrt(p); dbfsAtual = dbfsDeRms(rmsAtual);
    potenciaTelemetria += p; ++blocosTelemetria;
  }
  potenciaBloco = 0; janelasBloco = 0; blocoInvalido = false;
  const EstadoMaquina antes = classificadorSom.estado;
  if (classificadorSom.atualizar(agora, somValido, dbfsAtual, cfg)) {
    const EventoParada p = paradasSom.transicao(antes, classificadorSom.estado, classificadorSom.transicaoEm);
    publicarTransicao(FONTE_SOM, antes, classificadorSom.estado, classificadorSom.transicaoEm, p, false);
  }
}
static void avaliarModbus(uint32_t agora) {
  EstadoMaquina novo = EstadoMaquina::DESCONHECIDO;
  if (cfg.modbus_habilitado) {
    LeituraModbus l;
    portENTER_CRITICAL(&muxModbus); l = modbusUltima; portEXIT_CRITICAL(&muxModbus);
    const bool recente = l.ok && (uint32_t)(agora - l.em) <= 3 * cfg.modbus_intervalo_ms;
    novo = estadoDeStatusModbus(recente, l.status);
    codigoFalhaModbus = recente ? l.falha : 0;
  }
  if (novo == estadoModbus) return;
  const EstadoMaquina antes = estadoModbus;
  estadoModbus = novo;
  const EventoParada p = paradasModbus.transicao(antes, novo, agora);
  publicarTransicao("modbus", antes, novo, agora, p, true);
}
// Modbus (se habilitado e com leitura recente) tem prioridade; senao, som.
static const char *fontePrincipal(EstadoMaquina &e) {
  if (cfg.modbus_habilitado && estadoModbus != EstadoMaquina::DESCONHECIDO) { e = estadoModbus; return "modbus"; }
  e = classificadorSom.estado;
  return somValido ? FONTE_SOM : "indisponivel";
}

// ================================================================= telemetria
static void publicarTelemetria(uint32_t agora) {
  cabecalho(doc, seqTelemetria++, agora);
  contexto(doc);
  if (climaValido) { doc["temperatura_c"] = r2(temperatura); doc["umidade_pct"] = r2(umidade); }
  else { doc["temperatura_c"] = nullptr; doc["umidade_pct"] = nullptr; }
  doc["clima_valido"] = climaValido;
  if (blocosTelemetria) {
    const float rms = sqrt(potenciaTelemetria / blocosTelemetria);
    doc["nivel_ruido"] = r1(dbfsDeRms(rms)); doc["unidade_ruido"] = "dBFS"; doc["ruido_adc_rms"] = r1(rms);
  } else {
    doc["nivel_ruido"] = nullptr; doc["unidade_ruido"] = nullptr; doc["ruido_adc_rms"] = nullptr;
  }
  potenciaTelemetria = 0; blocosTelemetria = 0;
  EstadoMaquina e;
  doc["fonte_estado"] = fontePrincipal(e); doc["estado_maquina"] = nomeEstado(e);
  doc["estado_som"] = nomeEstado(classificadorSom.estado);
  if (cfg.modbus_habilitado) { doc["estado_modbus"] = nomeEstado(estadoModbus); doc["codigo_falha"] = codigoFalhaModbus; }
  else { doc["estado_modbus"] = nullptr; doc["codigo_falha"] = nullptr; }
  doc["modo"] = nomeModo(controlador.modo);
  doc["manual_restante_s"] = controlador.manualRestanteMs(agora) / 1000;
  doc["desumidificador_comandado"] = controlador.saida; doc["motivo_rele"] = controlador.motivo;
  doc["config_version"] = cfg.versao; doc["fila_flash"] = filaQtd;
  enviar(T_TELEMETRIA, doc, "TEL ");
}

// ===================================================== comandos e configuracao
static bool lerFloat(JsonVariantConst v, float &dst, const char *&erro) {
  if (v.isNull()) return true;
  if (!v.is<double>()) { erro = "tipo_invalido"; return false; }
  dst = (float)v.as<double>();
  return true;
}
static bool lerU32(JsonVariantConst v, uint32_t &dst, uint32_t max, const char *&erro) {
  if (v.isNull()) return true;
  const double x = v.is<double>() ? v.as<double>() : -1;
  if (x < 0 || x > max || x != floor(x)) { erro = "inteiro_invalido"; return false; }
  dst = (uint32_t)x;
  return true;
}
static void tratarComando(const char *json, size_t n) {
  const uint32_t agora = millis();
  if (deserializeJson(entrada, json, n)) { confirmar("comando", "", false, "json_invalido"); return; }
  const char *id = entrada["cmd_id"] | "";
  if (!id[0] || strlen(id) >= sizeof ultimoCmdId) { confirmar("comando", id, false, "cmd_id_ausente_ou_longo"); return; }
  if (strcmp(id, ultimoCmdId) == 0) { confirmar("comando", id, false, "duplicado"); return; }
  JsonVariantConst ts = entrada["ts"];
  if (!ts.isNull()) {
    if (!ts.is<double>()) { confirmar("comando", id, false, "ts_invalido"); return; }
    const double idade = (double)time(nullptr) - ts.as<double>();
    if (relogioOk() && (idade > 120 || idade < -120)) { confirmar("comando", id, false, "comando_vencido"); return; }
  }
  const char *modo = entrada["modo"] | "";
  if (strcmp(modo, "AUTO") == 0) {
    controlador.automatico();
  } else if (strcmp(modo, "MANUAL") == 0) {
    JsonVariantConst r = entrada["rele"];
    bool on;
    if (r.is<bool>()) on = r.as<bool>();
    else if (r.is<const char *>() && strcmp(r.as<const char *>(), "ON") == 0) on = true;
    else if (r.is<const char *>() && strcmp(r.as<const char *>(), "OFF") == 0) on = false;
    else { confirmar("comando", id, false, "rele_invalido"); return; }
    const double validade = entrada["validade_s"] | (double)cfg.manual_validade_padrao_s;
    if (!(validade >= 1 && validade <= cfg.manual_validade_max_s)) { confirmar("comando", id, false, "validade_fora_faixa"); return; }
    controlador.manual(on, (uint32_t)(validade * 1000), agora);
  } else {
    confirmar("comando", id, false, "modo_invalido"); return;
  }
  strlcpy(ultimoCmdId, id, sizeof ultimoCmdId);
  JsonDocument &ev = evento("MODO", agora);
  ev["modo"] = nomeModo(controlador.modo); ev["cmd_id"] = ultimoCmdId;
  ev["manual_restante_s"] = controlador.manualRestanteMs(agora) / 1000;
  enviar(T_EVENTOS, ev, "EVT ");
  controlar(agora);
  confirmar("comando", ultimoCmdId, true, "aplicado");
}
static void tratarConfig(const char *json, size_t n) {
  const uint32_t agora = millis();
  if (deserializeJson(entrada, json, n)) { confirmar("configuracao", "", false, "json_invalido"); return; }
  const char *id = entrada["cmd_id"] | "";
  JsonVariantConst vv = entrada["versao"];
  const double v = vv.is<double>() ? vv.as<double>() : 0;
  if (v < 1 || v > 4e9 || v != floor(v)) { confirmar("configuracao", id, false, "versao_ausente"); return; }
  const uint32_t versao = (uint32_t)v;
  if (versao == cfg.versao) { confirmar("configuracao", id, true, "ja_aplicada"); return; }
  if (versao < cfg.versao) { confirmar("configuracao", id, false, "versao_antiga"); return; }
  Config c = cfg;
  c.versao = versao;
  const char *erro = nullptr;
  bool ok = lerFloat(entrada["ur_liga"], c.ur_liga, erro) && lerFloat(entrada["ur_desliga"], c.ur_desliga, erro);
  if (ok && (!entrada["ur_max"].isNull() || !entrada["histerese"].isNull())) {  // formulario Admin
    float urMax = c.ur_liga, hist = c.ur_liga - c.ur_desliga;
    ok = lerFloat(entrada["ur_max"], urMax, erro) && lerFloat(entrada["histerese"], hist, erro);
    c.ur_liga = urMax; c.ur_desliga = urMax - hist;
  }
  if (ok && !entrada["limiar_db"].isNull()) {  // limiar unico do Admin; parado = limiar - banda
    float limiar = c.limiar_operando_dbfs, banda = c.limiar_operando_dbfs - c.limiar_parado_dbfs;
    ok = lerFloat(entrada["limiar_db"], limiar, erro) && lerFloat(entrada["banda_db"], banda, erro);
    c.limiar_operando_dbfs = limiar; c.limiar_parado_dbfs = limiar - banda;
  }
  ok = ok && lerFloat(entrada["limiar_operando_dbfs"], c.limiar_operando_dbfs, erro)
          && lerFloat(entrada["limiar_parado_dbfs"], c.limiar_parado_dbfs, erro)
          && lerU32(entrada["confirmar_operando_ms"], c.confirmar_operando_ms, 600000, erro)
          && lerU32(entrada["confirmar_parado_ms"], c.confirmar_parado_ms, 600000, erro)
          && lerU32(entrada["telemetria_ms"], c.telemetria_ms, 3600000, erro)
          && lerU32(entrada["tempo_min_rele_ms"], c.tempo_min_rele_ms, 3600000, erro)
          && lerU32(entrada["manual_validade_padrao_s"], c.manual_validade_padrao_s, 86400, erro)
          && lerU32(entrada["manual_validade_max_s"], c.manual_validade_max_s, 86400, erro);
  JsonVariantConst mb = entrada["modbus"];
  if (ok && !mb.isNull()) {
    uint32_t porta = c.modbus_porta, unit = c.modbus_unit, rs = c.modbus_reg_status, rf = c.modbus_reg_falha;
    if (!mb.is<JsonObjectConst>()) { ok = false; erro = "modbus_invalido"; }
    if (ok && !mb["habilitado"].isNull()) {
      if (mb["habilitado"].is<bool>()) c.modbus_habilitado = mb["habilitado"].as<bool>();
      else { ok = false; erro = "tipo_invalido"; }
    }
    if (ok && !mb["host"].isNull()) {
      const char *h = mb["host"] | "";
      if (!mb["host"].is<const char *>() || strlen(h) >= sizeof c.modbus_host) { ok = false; erro = "modbus_host_invalido"; }
      else strlcpy(c.modbus_host, h, sizeof c.modbus_host);
    }
    ok = ok && lerU32(mb["porta"], porta, 65535, erro) && lerU32(mb["unit"], unit, 247, erro)
            && lerU32(mb["reg_status"], rs, 65535, erro) && lerU32(mb["reg_falha"], rf, 65535, erro)
            && lerU32(mb["intervalo_ms"], c.modbus_intervalo_ms, 60000, erro);
    c.modbus_porta = porta; c.modbus_unit = unit; c.modbus_reg_status = rs; c.modbus_reg_falha = rf;
  }
  if (!ok) { confirmar("configuracao", id, false, erro ? erro : "tipo_invalido"); return; }
  const char *motivo = validarConfig(c);
  if (motivo) { confirmar("configuracao", id, false, motivo); return; }
  xSemaphoreTake(mtxConfig, portMAX_DELAY); cfg = c; xSemaphoreGive(mtxConfig);
  salvarConfig();
  JsonDocument &ev = evento("CONFIG_APLICADA", agora);
  ev["config_version"] = cfg.versao; ev["ur_liga"] = r2(cfg.ur_liga); ev["ur_desliga"] = r2(cfg.ur_desliga);
  ev["limiar_operando_dbfs"] = r1(cfg.limiar_operando_dbfs); ev["limiar_parado_dbfs"] = r1(cfg.limiar_parado_dbfs);
  ev["modbus_habilitado"] = cfg.modbus_habilitado;
  enviar(T_EVENTOS, ev, "EVT ");
  confirmar("configuracao", id, true, "aplicada");
  controlar(agora);
}
static bool textoContexto(JsonVariantConst v, bool obrigatorio, char *dst, const char *&erro) {
  if (v.isNull() && !obrigatorio) { dst[0] = '\0'; return true; }
  const char *s = v | "";
  if (!v.is<const char *>() || !s[0] || s[0] == ' ' || strlen(s) > 32) { erro = "texto_invalido_1_a_32"; return false; }
  strlcpy(dst, s, 33);
  return true;
}
static void tratarContexto(const char *json, size_t n) {
  const uint32_t agora = millis();
  if (deserializeJson(entrada, json, n)) { confirmar("contexto", "", false, "json_invalido"); return; }
  const char *id = entrada["cmd_id"] | "";
  char p[33], l[33], lc[33], lp[33];
  const char *erro = nullptr;
  if (!(textoContexto(entrada["produto"], true, p, erro) && textoContexto(entrada["lote_producao"], true, l, erro) &&
        textoContexto(entrada["lote_capsula"], false, lc, erro) && textoContexto(entrada["lote_po"], false, lp, erro))) {
    confirmar("contexto", id, false, erro); return;
  }
  if (!strcmp(p, produto) && !strcmp(l, loteProducao) && !strcmp(lc, loteCapsula) && !strcmp(lp, lotePo)) {
    confirmar("contexto", id, true, "sem_alteracao"); return;
  }
  strcpy(produto, p); strcpy(loteProducao, l); strcpy(loteCapsula, lc); strcpy(lotePo, lp);
  salvarContexto();
  enviar(T_EVENTOS, evento("CONTEXTO_ALTERADO", agora), "EVT ");
  confirmar("contexto", id, true, "aplicado");
}

// ===================================================================== serial
static void imprimirAjuda() {
  Serial.println("Serial: 1/0=MANUAL ON/OFF, a=AUTO, s=telemetria agora, n=simular queda de rede (alterna),");
  Serial.println("        f=fila, r=reiniciar, h=ajuda; cmd {json}, cfg {json}, ctx {json} = mesmo formato do MQTT");
}
static void comandoLocal(const char *modo, const char *rele) {
  char json[96];
  if (rele) snprintf(json, sizeof json, "{\"cmd_id\":\"serial-%lu\",\"modo\":\"%s\",\"rele\":\"%s\"}", (unsigned long)++comandosSerial, modo, rele);
  else snprintf(json, sizeof json, "{\"cmd_id\":\"serial-%lu\",\"modo\":\"%s\"}", (unsigned long)++comandosSerial, modo);
  tratarComando(json, strlen(json));
}
static void executarCaractere(char c) {
  switch (c) {
    case '1': comandoLocal("MANUAL", "ON"); break;
    case '0': comandoLocal("MANUAL", "OFF"); break;
    case 'a': case 'A': comandoLocal("AUTO", nullptr); break;
    case 's': publicarTelemetria(millis()); break;
    case 'n':
      redeBloqueada = !redeBloqueada;
      Serial.printf("REDE queda simulada %s\n", redeBloqueada ? "ATIVA (mensagens vao para a Flash)" : "ENCERRADA");
      break;
    case 'f':
      Serial.printf("FILA flash_ok=%d itens=%u capacidade=%u perdidas=%u reenviadas=%u descartes=%u\n", filaOk,
                    (unsigned)filaQtd, (unsigned)SLOTS, (unsigned)filaPerdidas, (unsigned)reenviadas, (unsigned)descartes);
      break;
    case 'r': Serial.println("REINICIANDO"); Serial.flush(); ESP.restart(); break;
    default: imprimirAjuda();
  }
}
static char linha[MSG_MAX + 8];
static size_t nLinha = 0;
static void lerSerial() {
  while (Serial.available()) {
    const char ch = (char)Serial.read();
    if (ch == '\r') continue;
    if (nLinha == 0 && ch && strchr("10aAsnfrh", ch)) { executarCaractere(ch); continue; }
    if (ch != '\n') { if (nLinha < sizeof linha - 1) linha[nLinha++] = ch; continue; }
    linha[nLinha] = '\0';
    const size_t n = nLinha;
    nLinha = 0;
    if (n > 4 && !strncmp(linha, "cmd ", 4)) tratarComando(linha + 4, n - 4);
    else if (n > 4 && !strncmp(linha, "cfg ", 4)) tratarConfig(linha + 4, n - 4);
    else if (n > 4 && !strncmp(linha, "ctx ", 4)) tratarContexto(linha + 4, n - 4);
    else if (n) imprimirAjuda();
  }
}
static void processarEntradas() {
  static Mensagem e;
  while (xQueueReceive(qEntrada, &e, 0) == pdTRUE) {
    Serial.printf("MQTT <- %s %s\n", topico[e.topico], e.payload);
    if (e.topico == T_COMANDOS) tratarComando(e.payload, e.n);
    else if (e.topico == T_CONFIGURACAO) tratarConfig(e.payload, e.n);
    else if (e.topico == T_CONTEXTO) tratarContexto(e.payload, e.n);
  }
}

// ======================================================= tarefa de rede (nucleo 0)
static WiFiClient tcpMqtt, tcpModbus;
static PubSubClient mqtt(tcpMqtt);
static Mensagem entradaRede, saidaRede;
static char bufReenvio[MSG_MAX + 1];
static uint16_t modbusTid = 0;

static void aoReceberMqtt(char *t, uint8_t *p, unsigned int n) {
  int idx = -1;
  for (int i = T_COMANDOS; i <= T_CONTEXTO; ++i) if (!strcmp(t, topico[i])) idx = i;
  if (idx < 0 || n > MSG_MAX) return;
  entradaRede.topico = (uint8_t)idx; entradaRede.n = (uint16_t)n;
  memcpy(entradaRede.payload, p, n); entradaRede.payload[n] = '\0';
  if (xQueueSend(qEntrada, &entradaRede, 0) != pdTRUE) ++descartes;
}
// Le um registrador holding (FC03). Retorna 0, excecao Modbus (>0) ou erro local (<0).
static int modbusLer(const Config &c, uint16_t reg, uint16_t &valor) {
  if (!tcpModbus.connected()) {
    tcpModbus.stop();
    if (!tcpModbus.connect(c.modbus_host, c.modbus_porta, 1000)) return -10;
  }
  uint8_t q[12], r[16];
  const uint16_t tid = ++modbusTid;
  modbusMontarFC03(q, tid, c.modbus_unit, reg, 1);
  if (tcpModbus.write(q, sizeof q) != sizeof q) { tcpModbus.stop(); return -11; }
  size_t n = 0, esperado = 11;
  const uint32_t t0 = millis();
  while (n < esperado && (uint32_t)(millis() - t0) < 1000) {
    if (tcpModbus.available()) {
      r[n++] = (uint8_t)tcpModbus.read();
      if (n == 8 && (r[7] & 0x80)) esperado = 9;
    } else {
      vTaskDelay(1);
    }
  }
  const int res = modbusLerRespostaFC03(r, n, tid, c.modbus_unit, 1, &valor);
  if (res < 0) tcpModbus.stop();
  return res;
}
static void tarefaRede(void *) {
  WiFi.mode(WIFI_STA);
  mqtt.setServer(MQTT_HOST, MQTT_PORTA);
  mqtt.setCallback(aoReceberMqtt);
  mqtt.setBufferSize(MSG_MAX + 128);
  mqtt.setKeepAlive(15);
  mqtt.setSocketTimeout(3);
  uint32_t ultimaWifi = 0, ultimaMqtt = 0, esperaMqtt = 2000, ultimoModbus = 0;
  bool tentouWifi = false, ntp = false, wifiAntes = false, mqttAntes = false;
  uint32_t filaAntes = 0;
  Config c;
  for (;;) {
    const uint32_t agora = millis();
    xSemaphoreTake(mtxConfig, portMAX_DELAY); c = cfg; xSemaphoreGive(mtxConfig);
    if (redeBloqueada) {
      if (tentouWifi) { tcpMqtt.stop(); tcpModbus.stop(); WiFi.disconnect(); tentouWifi = false; }
    } else if (WiFi.status() != WL_CONNECTED && (!tentouWifi || (uint32_t)(agora - ultimaWifi) >= 15000)) {
      WiFi.disconnect(); WiFi.begin(WIFI_SSID, WIFI_SENHA, WIFI_CANAL);
      ultimaWifi = agora; tentouWifi = true;
    }
    wifiOk = !redeBloqueada && WiFi.status() == WL_CONNECTED;
    if (wifiOk && !ntp) { configTime(0, 0, "pool.ntp.org", "time.google.com"); ntp = true; }
    if (wifiOk && MQTT_HOST[0] && !mqtt.connected() && (uint32_t)(agora - ultimaMqtt) >= esperaMqtt) {
      char cid[48];
      snprintf(cid, sizeof cid, "%s-%s-%04x", DEVICE_ID, bootId, (unsigned)(esp_random() & 0xffff));
      if (mqtt.connect(cid, MQTT_USUARIO, MQTT_SENHA, topico[T_DISPONIBILIDADE], 1, true, "{\"estado\":\"offline\"}")) {
        mqtt.subscribe(topico[T_COMANDOS], 1);
        mqtt.subscribe(topico[T_CONFIGURACAO], 1);
        mqtt.subscribe(topico[T_CONTEXTO], 1);
        char on[96];
        snprintf(on, sizeof on, "{\"estado\":\"online\",\"device_id\":\"%s\",\"boot_id\":\"%s\"}", DEVICE_ID, bootId);
        mqtt.publish(topico[T_DISPONIBILIDADE], on, true);
        esperaMqtt = 2000;
      } else {
        esperaMqtt = esperaMqtt >= 30000 ? 60000 : esperaMqtt * 2;
        Serial.printf("REDE mqtt falhou rc=%d; nova tentativa em %lu ms\n", mqtt.state(), (unsigned long)esperaMqtt);
      }
      ultimaMqtt = millis();
    }
    if (mqtt.connected()) mqtt.loop();
    mqttOk = wifiOk && mqtt.connected();
    if (wifiOk != wifiAntes || mqttOk != mqttAntes) {
      Serial.printf("REDE wifi=%d mqtt=%d broker=%s fila=%u\n", wifiOk, mqttOk, MQTT_HOST, (unsigned)filaQtd);
      wifiAntes = wifiOk; mqttAntes = mqttOk;
    }
    // Saida: publica direto se online e sem fila; senao grava na Flash (ordem preservada).
    while (xQueueReceive(qSaida, &saidaRede, 0) == pdTRUE) {
      const bool enviado = mqttOk && (!filaOk || filaFlash.quantidade() == 0) &&
          mqtt.publish(topico[saidaRede.topico], (const uint8_t *)saidaRede.payload, saidaRede.n, false);
      if (!enviado && !(filaOk && filaFlash.inserir(saidaRede.topico, saidaRede.payload, saidaRede.n))) ++descartes;
    }
    // Reenvio da fila da Flash, do mais antigo para o mais novo, ate 10 por ciclo.
    if (mqttOk && filaOk) {
      for (int i = 0; i < 10 && filaFlash.quantidade() > 0; ++i) {
        uint8_t t; size_t n;
        if (!filaFlash.espiar(t, bufReenvio, n) || t >= T_TOTAL) { filaFlash.remover(); ++descartes; continue; }
        if (!mqtt.publish(topico[t], (const uint8_t *)bufReenvio, n, false)) break;
        filaFlash.remover(); ++reenviadas;
      }
    }
    if (c.modbus_habilitado && wifiOk && (uint32_t)(agora - ultimoModbus) >= c.modbus_intervalo_ms) {
      ultimoModbus = agora;
      uint16_t status = 0, falha = 0;
      const int erroStatus = modbusLer(c, c.modbus_reg_status, status);
      const int erroFalha = erroStatus == 0 ? modbusLer(c, c.modbus_reg_falha, falha) : erroStatus;
      portENTER_CRITICAL(&muxModbus);
      modbusUltima.ok = erroStatus == 0; modbusUltima.status = status;
      modbusUltima.falha = erroFalha == 0 ? falha : 0; modbusUltima.erro = erroStatus;
      if (erroStatus == 0) modbusUltima.em = millis();
      portEXIT_CRITICAL(&muxModbus);
    }
    filaQtd = filaOk ? filaFlash.quantidade() : 0;
    filaPerdidas = filaFlash.perdidas;
    if (filaAntes > 0 && filaQtd == 0 && mqttOk)
      Serial.printf("REDE fila da Flash reenviada; total reenviado=%u\n", (unsigned)reenviadas);
    filaAntes = filaQtd;
    vTaskDelay(pdMS_TO_TICKS(20));
  }
}

// ====================================================================== setup
static void imprimirStatus(uint32_t agora) {
  EstadoMaquina e;
  const char *fonte = fontePrincipal(e);
  char ur[12] = "nan", t[12] = "nan";
  if (climaValido) { snprintf(ur, sizeof ur, "%.2f", umidade); snprintf(t, sizeof t, "%.2f", temperatura); }
  Serial.printf("ST t=%lus UR=%s T=%s clima=%s dBFS=%.1f som=%s maquina=%s(%s) rele=%s(%s) modo=%s "
                "wifi=%d mqtt=%d fila=%u\n", (unsigned long)(agora / 1000), ur, t, climaValido ? "OK" : "FALHA",
                somValido ? dbfsAtual : NAN, nomeEstado(classificadorSom.estado), nomeEstado(e), fonte,
                controlador.saida ? "ON" : "OFF", controlador.motivo, nomeModo(controlador.modo), wifiOk, mqttOk,
                (unsigned)filaQtd);
}
void setup() {
  digitalWrite(PIN_RELE, RELE_OFF); pinMode(PIN_RELE, OUTPUT);  // saida definida antes da rede
  pinMode(PIN_LED_REDE, OUTPUT);
  Serial.setTxBufferSize(4096);
  Serial.begin(115200);
  prefs.begin("mixnutri", false);
  const uint32_t boot = prefs.getUInt("boot", 0) + 1;
  prefs.putUInt("boot", boot);
  snprintf(bootId, sizeof bootId, "b%lu", (unsigned long)boot);
  carregarConfig();
  carregarContexto();
  for (int i = 0; i < T_TOTAL; ++i) snprintf(topico[i], sizeof topico[i], "%s/%s", TOPICO_BASE, SUFIXO[i]);
  filaOk = abrirFila();
  filaQtd = filaOk ? filaFlash.quantidade() : 0;
  qSaida = xQueueCreate(16, sizeof(Mensagem));
  qEntrada = xQueueCreate(4, sizeof(Mensagem));
  mtxConfig = xSemaphoreCreateMutex();
  Wire.begin(PIN_SDA, PIN_SCL); Wire.setTimeOut(50);
  analogReadResolution(12); pinMode(PIN_SOM, INPUT);

  Serial.printf("MIXNUTRI FIRMWARE ITEM 2 | %s | boot=%s | origem=%s | som em dBFS (nao dB SPL)\n", DEVICE_ID, bootId, ORIGEM);
  imprimirAjuda();
  Serial.printf("MQTT broker=%s:%u base=%s\n", MQTT_HOST[0] ? MQTT_HOST : "(desligado)", MQTT_PORTA, TOPICO_BASE);
  Serial.printf("FILA flash_ok=%d itens=%u capacidade=%u slot=%uB\n", filaOk, (unsigned)filaQtd, (unsigned)SLOTS, (unsigned)SLOT);
  Serial.printf("CONFIG versao=%lu ur_liga=%.1f ur_desliga=%.1f operando>=%.1fdBFS parado<=%.1fdBFS modbus=%d\n",
                (unsigned long)cfg.versao, cfg.ur_liga, cfg.ur_desliga, cfg.limiar_operando_dbfs,
                cfg.limiar_parado_dbfs, cfg.modbus_habilitado);
  Serial.printf("CONTEXTO produto=%s lote=%s\n", produto, loteProducao);

  JsonDocument &ev = evento("BOOT", millis());
  ev["reset_reason"] = (int)esp_reset_reason(); ev["config_version"] = cfg.versao;
  ev["fila_flash"] = filaQtd; ev["modo"] = "AUTO";
  enviar(T_EVENTOS, ev, "EVT ");
  xTaskCreatePinnedToCore(tarefaRede, "rede", 8192, nullptr, 1, nullptr, 0);
  pedirClima(millis());
}

// ======================================================================= loop
void loop() {
  const uint32_t agora = millis();
  lerSerial();
  processarEntradas();
  if (aguardandoClima && (uint32_t)(agora - pedidoClimaEm) >= 20) receberClima(agora);
  if (!aguardandoClima && (uint32_t)(agora - ultimoPedidoClima) >= 2000) { ultimoPedidoClima = agora; pedirClima(agora); }
  amostrarSom(agora);
  avaliarModbus(agora);
  if (controlador.verificarExpiracao(agora)) {
    JsonDocument &ev = evento("MANUAL_EXPIRADO", agora);
    ev["modo"] = "AUTO";
    enviar(T_EVENTOS, ev, "EVT ");
    controlar(agora);
  }
  if ((uint32_t)(agora - ultimoControle) >= 200) { ultimoControle = agora; controlar(agora); }
  if ((uint32_t)(agora - ultimaTelemetria) >= cfg.telemetria_ms) { ultimaTelemetria = agora; publicarTelemetria(agora); }
  if ((uint32_t)(agora - ultimoStatus) >= 2000) { ultimoStatus = agora; imprimirStatus(agora); }
  digitalWrite(PIN_LED_REDE, mqttOk ? HIGH : wifiOk ? (agora / 500) % 2 : (agora / 125) % 2);
}
