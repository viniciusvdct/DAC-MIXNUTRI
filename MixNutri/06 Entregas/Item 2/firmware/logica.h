// Logica pura do firmware MixNutri (sem Arduino): configuracao, histerese, modo
// AUTO/MANUAL, classificador acustico, Modbus TCP e fila circular. Compila no ESP32
// e no computador (testes/test_logica.cpp). Valores padrao sao propostas didaticas.
#pragma once
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <math.h>

namespace mixnutri {

// ---------------------------------------------------------------- configuracao
struct Config {
  uint32_t versao;
  float ur_liga, ur_desliga;                        // %UR (histerese)
  float limiar_operando_dbfs, limiar_parado_dbfs;   // dBFS relativo ao ADC, nao dB SPL
  uint32_t confirmar_operando_ms, confirmar_parado_ms;
  uint32_t telemetria_ms;
  uint32_t tempo_min_rele_ms;                       // protecao contra ciclo curto (didatico)
  uint32_t manual_validade_padrao_s, manual_validade_max_s;
  bool modbus_habilitado;                           // so com acesso ao CLP autorizado
  char modbus_host[40];
  uint16_t modbus_porta;
  uint8_t modbus_unit;
  uint16_t modbus_reg_status;                       // STATUS_MAQUINA (1 rodando, 0 parada)
  uint16_t modbus_reg_falha;                        // CODIGO_FALHA (exemplo do plano MVP)
  uint32_t modbus_intervalo_ms;
};

inline Config configPadrao() {
  Config c;
  memset(&c, 0, sizeof c);
  c.versao = 1;
  c.ur_liga = 55.0f; c.ur_desliga = 50.0f;
  c.limiar_operando_dbfs = -25.0f; c.limiar_parado_dbfs = -35.0f;
  c.confirmar_operando_ms = 3000; c.confirmar_parado_ms = 5000;
  c.telemetria_ms = 5000;
  c.tempo_min_rele_ms = 10000;
  c.manual_validade_padrao_s = 900; c.manual_validade_max_s = 28800;
  c.modbus_habilitado = false;
  c.modbus_porta = 502; c.modbus_unit = 1;
  c.modbus_reg_status = 0; c.modbus_reg_falha = 1;
  c.modbus_intervalo_ms = 2000;
  return c;
}

// Retorna nullptr se valida; senao, o motivo. Nao altera a configuracao.
inline const char *validarConfig(const Config &c) {
  if (c.versao == 0) return "versao_invalida";
  if (!isfinite(c.ur_liga) || !isfinite(c.ur_desliga)) return "ur_nao_numerica";
  if (c.ur_liga < 0 || c.ur_liga > 100 || c.ur_desliga < 0 || c.ur_desliga > 100) return "ur_fora_0_100";
  if (!(c.ur_desliga < c.ur_liga)) return "ur_desliga_deve_ser_menor_que_ur_liga";
  if (!isfinite(c.limiar_operando_dbfs) || !isfinite(c.limiar_parado_dbfs)) return "limiar_nao_numerico";
  if (c.limiar_operando_dbfs > 0 || c.limiar_parado_dbfs < -120) return "limiar_fora_faixa_dbfs";
  if (!(c.limiar_parado_dbfs < c.limiar_operando_dbfs)) return "limiar_parado_deve_ser_menor";
  if (c.confirmar_operando_ms < 500 || c.confirmar_operando_ms > 600000) return "confirmar_operando_fora_faixa";
  if (c.confirmar_parado_ms < 500 || c.confirmar_parado_ms > 600000) return "confirmar_parado_fora_faixa";
  if (c.telemetria_ms < 1000 || c.telemetria_ms > 3600000) return "telemetria_fora_faixa";
  if (c.tempo_min_rele_ms > 3600000) return "tempo_min_rele_fora_faixa";
  if (c.manual_validade_max_s < 60 || c.manual_validade_max_s > 86400) return "validade_max_fora_faixa";
  if (c.manual_validade_padrao_s < 1 || c.manual_validade_padrao_s > c.manual_validade_max_s) return "validade_padrao_fora_faixa";
  if (c.modbus_habilitado) {
    if (c.modbus_host[0] == '\0') return "modbus_host_vazio";
    if (c.modbus_porta == 0) return "modbus_porta_invalida";
    if (c.modbus_reg_falha == c.modbus_reg_status) return "modbus_registradores_iguais";
  }
  if (c.modbus_intervalo_ms < 500 || c.modbus_intervalo_ms > 60000) return "modbus_intervalo_fora_faixa";
  return nullptr;
}

// --------------------------------------------------------------- histerese
// Acima ou igual a ur_liga pede ON; abaixo ou igual a ur_desliga pede OFF; entre eles mantem.
inline bool histerese(bool pedidoAnterior, float ur, float urLiga, float urDesliga) {
  if (ur >= urLiga) return true;
  if (ur <= urDesliga) return false;
  return pedidoAnterior;
}

// Diferenca de tempo com sinal: robusta a um "agora" lido antes do evento (resultado
// negativo) e ao estouro de millis() apos ~49 dias.
inline int32_t decorrido(uint32_t agora, uint32_t desde) { return (int32_t)(agora - desde); }

enum class Modo : uint8_t { AUTO, MANUAL };
inline const char *nomeModo(Modo m) { return m == Modo::AUTO ? "AUTO" : "MANUAL"; }

// Decide o comando do rele. Saida inicial OFF. Em AUTO, falha de sensor pede OFF
// (proposta de bancada). MANUAL expira e volta a AUTO. tempo_min_rele_ms segura a
// comutacao, inclusive no MANUAL, para proteger compressor.
class Controlador {
 public:
  Modo modo = Modo::AUTO;
  bool pedido = false, saida = false;
  const char *motivo = "inicial";

  void manual(bool on, uint32_t validadeMs, uint32_t agora) {
    modo = Modo::MANUAL; manualOn_ = on; manualDesde_ = agora; manualValidadeMs_ = validadeMs;
  }
  void automatico() { modo = Modo::AUTO; }
  // true uma unica vez quando o MANUAL vence
  bool verificarExpiracao(uint32_t agora) {
    if (modo == Modo::MANUAL && decorrido(agora, manualDesde_) >= (int32_t)manualValidadeMs_) {
      modo = Modo::AUTO; return true;
    }
    return false;
  }
  uint32_t manualRestanteMs(uint32_t agora) const {
    if (modo != Modo::MANUAL) return 0;
    const int32_t dec = decorrido(agora, manualDesde_);
    if (dec <= 0) return manualValidadeMs_;
    return (uint32_t)dec >= manualValidadeMs_ ? 0 : manualValidadeMs_ - (uint32_t)dec;
  }
  // true se a saida mudou
  bool passo(uint32_t agora, bool climaValido, float ur, const Config &c) {
    if (modo == Modo::MANUAL) { pedido = manualOn_; motivoPedido_ = "manual"; }
    else if (!climaValido) { pedido = false; motivoPedido_ = "sensor_falha"; }
    else { pedido = histerese(pedido, ur, c.ur_liga, c.ur_desliga); motivoPedido_ = "histerese"; }
    if (pedido == saida) { motivo = motivoPedido_; return false; }
    if (jaComutou_ && decorrido(agora, ultimaComutacao_) < (int32_t)c.tempo_min_rele_ms) {
      motivo = "tempo_minimo"; return false;
    }
    saida = pedido; jaComutou_ = true; ultimaComutacao_ = agora; motivo = motivoPedido_;
    return true;
  }

 private:
  bool manualOn_ = false, jaComutou_ = false;
  uint32_t manualDesde_ = 0, manualValidadeMs_ = 0, ultimaComutacao_ = 0;
  const char *motivoPedido_ = "inicial";
};

// ------------------------------------------------------ classificacao acustica
enum class EstadoMaquina : uint8_t { DESCONHECIDO, OPERANDO, PARADO };
inline const char *nomeEstado(EstadoMaquina e) {
  return e == EstadoMaquina::OPERANDO ? "OPERANDO" : e == EstadoMaquina::PARADO ? "PARADO" : "DESCONHECIDO";
}

inline float dbfsDeRms(float rms, float referencia = 2048.0f) {
  return 20.0f * log10f((rms < 1.0f ? 1.0f : rms) / referencia);
}

// Acima de limiar_operando por confirmar_operando_ms -> OPERANDO; abaixo de
// limiar_parado por confirmar_parado_ms -> PARADO; entre os limiares mantem o estado
// e reinicia as confirmacoes; entrada invalida -> DESCONHECIDO.
// transicaoEm = instante em que a condicao confirmada comecou (inicio real da parada).
class ClassificadorSom {
 public:
  EstadoMaquina estado = EstadoMaquina::DESCONHECIDO;
  uint32_t transicaoEm = 0;

  bool atualizar(uint32_t agora, bool valido, float dbfs, const Config &c) {
    EstadoMaquina novo = estado;
    if (!valido || !isfinite(dbfs)) {
      acima_ = abaixo_ = false; novo = EstadoMaquina::DESCONHECIDO; transicaoEm = agora;
    } else if (dbfs >= c.limiar_operando_dbfs) {
      abaixo_ = false;
      if (!acima_) { acima_ = true; desde_ = agora; }
      if (estado != EstadoMaquina::OPERANDO && decorrido(agora, desde_) >= (int32_t)c.confirmar_operando_ms) {
        novo = EstadoMaquina::OPERANDO; transicaoEm = desde_;
      }
    } else if (dbfs <= c.limiar_parado_dbfs) {
      acima_ = false;
      if (!abaixo_) { abaixo_ = true; desde_ = agora; }
      if (estado != EstadoMaquina::PARADO && decorrido(agora, desde_) >= (int32_t)c.confirmar_parado_ms) {
        novo = EstadoMaquina::PARADO; transicaoEm = desde_;
      }
    } else {
      acima_ = abaixo_ = false;
    }
    if (novo == estado) return false;
    estado = novo;
    return true;
  }

 private:
  bool acima_ = false, abaixo_ = false;
  uint32_t desde_ = 0;
};

// Abre/fecha eventos de parada a partir das transicoes de uma fonte.
struct EventoParada {
  enum Tipo : uint8_t { NENHUM, INICIO, FIM } tipo = NENHUM;
  uint32_t numero = 0;          // sequencial da parada nesta fonte e boot
  uint32_t inicioMs = 0, fimMs = 0;
  const char *motivoFim = nullptr;
};
class RastreadorParadas {
 public:
  bool aberta = false;
  uint32_t numero = 0, inicioMs = 0;
  EventoParada transicao(EstadoMaquina anterior, EstadoMaquina novo, uint32_t em) {
    EventoParada ev;
    if (novo == EstadoMaquina::PARADO && !aberta) {
      aberta = true; inicioMs = em; ++numero;
      ev.tipo = EventoParada::INICIO; ev.numero = numero; ev.inicioMs = em;
    } else if (novo != EstadoMaquina::PARADO && aberta) {
      aberta = false;
      ev.tipo = EventoParada::FIM; ev.numero = numero; ev.inicioMs = inicioMs; ev.fimMs = em;
      ev.motivoFim = novo == EstadoMaquina::OPERANDO ? "retorno_operacao" : "fonte_indisponivel";
    }
    (void)anterior;
    return ev;
  }
};

// ------------------------------------------------------------- Modbus TCP
// Funcao 0x03 (Read Holding Registers). Enderecos base 0 no quadro.
inline size_t modbusMontarFC03(uint8_t *q, uint16_t tid, uint8_t unit, uint16_t endereco, uint16_t qtd) {
  q[0] = tid >> 8; q[1] = tid & 0xff; q[2] = 0; q[3] = 0; q[4] = 0; q[5] = 6;
  q[6] = unit; q[7] = 0x03; q[8] = endereco >> 8; q[9] = endereco & 0xff;
  q[10] = qtd >> 8; q[11] = qtd & 0xff;
  return 12;
}
// 0 = ok; >0 = codigo de excecao Modbus; <0 = resposta malformada.
inline int modbusLerRespostaFC03(const uint8_t *r, size_t n, uint16_t tid, uint8_t unit,
                                 uint16_t qtd, uint16_t *saida) {
  if (n < 9) return -1;
  if (((uint16_t)(r[0] << 8) | r[1]) != tid) return -2;
  if (r[2] != 0 || r[3] != 0) return -3;
  if (r[6] != unit) return -4;
  if (r[7] == (0x03 | 0x80)) return r[8] ? r[8] : -5;
  if (r[7] != 0x03) return -6;
  const uint16_t len = (uint16_t)(r[4] << 8) | r[5];
  if (r[8] != 2 * qtd || len != 3 + 2 * qtd || n < (size_t)(9 + 2 * qtd)) return -7;
  for (uint16_t i = 0; i < qtd; ++i) saida[i] = (uint16_t)(r[9 + 2 * i] << 8) | r[10 + 2 * i];
  return 0;
}
inline EstadoMaquina estadoDeStatusModbus(bool leituraOk, uint16_t status) {
  if (!leituraOk) return EstadoMaquina::DESCONHECIDO;  // perda de comunicacao nao e PARADO
  if (status == 1) return EstadoMaquina::OPERANDO;
  if (status == 0) return EstadoMaquina::PARADO;
  return EstadoMaquina::DESCONHECIDO;
}

// --------------------------------------------- fila circular em armazenamento
// Slots de tamanho fixo num arquivo/memoria: [cabecalho 16 B][slot 0]...[slot N-1].
// Slot: [topico 1 B][tamanho 2 B][payload]. Cheia: sobrescreve a mais antiga e conta perda.
// Armazenamento: ler(offset, buf, n) e escrever(offset, buf, n) retornam bool.
// Cada escrita comeca no inicio do cabecalho ou de um slot (permite um arquivo por slot).
template <class Armazenamento, size_t SLOT, size_t SLOTS>
class FilaCircular {
 public:
  static constexpr uint32_t MAGICO = 0x4D584631;  // "MXF1"
  static constexpr size_t CAB = 16, PAYLOAD_MAX = SLOT - 3;
  explicit FilaCircular(Armazenamento &a) : a_(a) {}

  // Recupera cabecalho existente ou inicializa vazio.
  bool abrir() {
    uint32_t cab[4];
    if (a_.ler(0, (uint8_t *)cab, sizeof cab) && cab[0] == MAGICO && cab[1] == SLOTS &&
        cab[2] < SLOTS && cab[3] <= SLOTS) {
      inicio_ = cab[2]; quantidade_ = cab[3]; return true;
    }
    inicio_ = quantidade_ = 0;
    return salvarCabecalho();
  }
  bool inserir(uint8_t topico, const char *payload, size_t n) {
    if (n > PAYLOAD_MAX) return false;
    if (quantidade_ == SLOTS) { inicio_ = (inicio_ + 1) % SLOTS; --quantidade_; ++perdidas; }
    const uint32_t idx = (inicio_ + quantidade_) % SLOTS;
    tmp_[0] = topico; tmp_[1] = (uint8_t)(n >> 8); tmp_[2] = (uint8_t)(n & 0xff);
    memcpy(tmp_ + 3, payload, n);
    if (!a_.escrever(CAB + (size_t)idx * SLOT, tmp_, 3 + n)) return false;
    ++quantidade_;
    return salvarCabecalho();
  }
  // Le a mais antiga sem remover. buf precisa de PAYLOAD_MAX + 1 bytes.
  bool espiar(uint8_t &topico, char *buf, size_t &n) {
    if (quantidade_ == 0) return false;
    const size_t off = CAB + (size_t)inicio_ * SLOT;
    uint8_t cab[3];
    if (!a_.ler(off, cab, 3)) return false;
    n = (size_t)(cab[1] << 8) | cab[2];
    if (n > PAYLOAD_MAX || !a_.ler(off + 3, (uint8_t *)buf, n)) return false;
    buf[n] = '\0'; topico = cab[0];
    return true;
  }
  bool remover() {
    if (quantidade_ == 0) return false;
    inicio_ = (inicio_ + 1) % SLOTS; --quantidade_;
    return salvarCabecalho();
  }
  uint32_t quantidade() const { return quantidade_; }
  static constexpr size_t capacidade() { return SLOTS; }
  static constexpr size_t bytesTotais() { return CAB + SLOT * SLOTS; }
  uint32_t perdidas = 0;  // descartes por fila cheia desde o boot

 private:
  bool salvarCabecalho() {
    uint32_t cab[4] = {MAGICO, (uint32_t)SLOTS, inicio_, quantidade_};
    return a_.escrever(0, (const uint8_t *)cab, sizeof cab);
  }
  Armazenamento &a_;
  uint32_t inicio_ = 0, quantidade_ = 0;
  uint8_t tmp_[SLOT];
};

}  // namespace mixnutri
