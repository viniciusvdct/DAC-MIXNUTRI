// Testes nativos da logica do firmware (sem ESP32). Compilar a partir da pasta firmware:
//   clang++ -std=c++17 -Wall -Wextra -Werror -I . testes/test_logica.cpp -o /tmp/mixnutri-logica
#include <assert.h>
#include <stdio.h>
#include <vector>
#include "logica.h"
using namespace mixnutri;

struct Memoria {
  std::vector<uint8_t> b;
  explicit Memoria(size_t n) : b(n, 0xff) {}
  bool ler(size_t off, uint8_t *p, size_t n) { if (off + n > b.size()) return false; memcpy(p, &b[off], n); return true; }
  bool escrever(size_t off, const uint8_t *p, size_t n) { if (off + n > b.size()) return false; memcpy(&b[off], p, n); return true; }
};

static void testeConfig() {
  Config c = configPadrao();
  assert(validarConfig(c) == nullptr);
  Config x = c; x.ur_desliga = 55; assert(validarConfig(x) != nullptr);
  x = c; x.ur_liga = 101; assert(validarConfig(x) != nullptr);
  x = c; x.ur_liga = NAN; assert(validarConfig(x) != nullptr);
  x = c; x.limiar_parado_dbfs = -20; assert(validarConfig(x) != nullptr);
  x = c; x.limiar_operando_dbfs = 3; assert(validarConfig(x) != nullptr);
  x = c; x.telemetria_ms = 10; assert(validarConfig(x) != nullptr);
  x = c; x.modbus_habilitado = true; assert(validarConfig(x) != nullptr);  // host vazio
  strcpy(x.modbus_host, "192.168.0.10"); assert(validarConfig(x) == nullptr);
  puts("OK: configuracao padrao valida; invalidas rejeitadas sem aplicar");
}

static void testeHisterese() {
  Config c = configPadrao(); c.tempo_min_rele_ms = 0;
  Controlador k; uint32_t t = 0;
  const float urs[] = {45, 60, 53, 49, 53, 55};
  const bool esperado[] = {false, true, true, false, false, true};
  for (int i = 0; i < 6; ++i) { k.passo(t += 2000, true, urs[i], c); assert(k.saida == esperado[i]); }
  puts("OK: histerese 45->60->53->49->53->55 = OFF ON ON OFF OFF ON");
  k.passo(t += 2000, false, NAN, c); assert(!k.saida && strcmp(k.motivo, "sensor_falha") == 0);
  puts("OK: falha de sensor em AUTO desliga");
}

static void testeTempoMinimoEManual() {
  Config c = configPadrao(); c.tempo_min_rele_ms = 10000;
  Controlador k;
  assert(k.passo(1000, true, 60, c) && k.saida);           // primeira comutacao imediata
  assert(!k.passo(5000, true, 40, c) && k.saida);          // segura por tempo minimo
  assert(strcmp(k.motivo, "tempo_minimo") == 0);
  assert(k.passo(11000, true, 40, c) && !k.saida);
  puts("OK: tempo minimo entre comutacoes respeitado");
  k.manual(true, 60000, 30000);
  assert(k.passo(30000, true, 40, c) && k.saida && k.modo == Modo::MANUAL);
  assert(k.manualRestanteMs(60000) == 30000);
  assert(!k.verificarExpiracao(89999));
  assert(k.verificarExpiracao(90000) && k.modo == Modo::AUTO);
  assert(!k.verificarExpiracao(90001));
  assert(k.passo(90000, true, 40, c) && !k.saida);
  puts("OK: MANUAL ON vence e volta a AUTO uma unica vez");
  // Regressao (achada no Wokwi): o loop le millis() antes de processar o comando, entao
  // "agora" pode ser anterior ao inicio do MANUAL. Nao pode expirar nem zerar o restante.
  k.manual(true, 40000, 100500);
  assert(!k.verificarExpiracao(100480) && k.modo == Modo::MANUAL);
  assert(k.manualRestanteMs(100480) == 40000 && k.manualRestanteMs(110500) == 30000);
  assert(k.verificarExpiracao(140500) && k.modo == Modo::AUTO);
  Controlador z; z.passo(500000, true, 60, c);                 // comutou em 500000
  assert(!z.passo(499990, true, 40, c) && z.saida);           // agora "atrasado" segura
  // Estouro de millis(): comutacao perto de 2^32 e leitura apos dar a volta
  Controlador w; w.passo(4294960000u, true, 60, c);
  assert(!w.passo(1000, true, 40, c) && w.saida);             // 8,3 s depois: segura
  assert(w.passo(4000, true, 40, c) && !w.saida);             // 11,3 s depois: comuta
  puts("OK: agora anterior ao comando e estouro de millis() tratados");
}

static void testeClassificador() {
  Config c = configPadrao();  // operando >= -25, parado <= -35, 3 s / 5 s
  ClassificadorSom s; RastreadorParadas r; uint32_t t = 0;
  auto passo = [&](float db) {
    EstadoMaquina antes = s.estado;
    bool mudou = s.atualizar(t, true, db, c);
    EventoParada ev; if (mudou) ev = r.transicao(antes, s.estado, s.transicaoEm);
    t += 500; return ev;
  };
  for (int i = 0; i < 6; ++i) passo(-10);       // 0..2500 ms
  assert(s.estado == EstadoMaquina::DESCONHECIDO);
  passo(-10);                                   // 3000 ms
  assert(s.estado == EstadoMaquina::OPERANDO && s.transicaoEm == 0);
  puts("OK: OPERANDO confirmado apos 3 s acima do limiar");
  for (int i = 0; i < 20; ++i) passo(-30);      // zona morta mantem
  assert(s.estado == EstadoMaquina::OPERANDO);
  const uint32_t quedaEm = t;
  EventoParada ev;
  for (int i = 0; i < 10; ++i) { ev = passo(-50); assert(ev.tipo == EventoParada::NENHUM); }
  ev = passo(-50);
  assert(s.estado == EstadoMaquina::PARADO && ev.tipo == EventoParada::INICIO && ev.inicioMs == quedaEm);
  puts("OK: PARADO apos 5 s, inicio da parada no instante da queda");
  for (int i = 0; i < 5; ++i) passo(-50);
  // retorno curto (2 s) nao confirma operacao
  for (int i = 0; i < 4; ++i) assert(passo(-10).tipo == EventoParada::NENHUM);
  passo(-50);
  assert(s.estado == EstadoMaquina::PARADO);
  const uint32_t voltaEm = t;
  for (int i = 0; i < 6; ++i) assert(passo(-10).tipo == EventoParada::NENHUM);
  ev = passo(-10);
  assert(ev.tipo == EventoParada::FIM && ev.fimMs == voltaEm && ev.inicioMs == quedaEm);
  assert(strcmp(ev.motivoFim, "retorno_operacao") == 0 && ev.numero == 1);
  puts("OK: pulso curto ignorado; fim da parada no retorno confirmado");
  for (int i = 0; i < 12; ++i) passo(-50);
  assert(s.estado == EstadoMaquina::PARADO && r.aberta && r.numero == 2);
  EstadoMaquina antes = s.estado;
  assert(s.atualizar(t, false, -50, c) && s.estado == EstadoMaquina::DESCONHECIDO);
  ev = r.transicao(antes, s.estado, s.transicaoEm);
  assert(ev.tipo == EventoParada::FIM && strcmp(ev.motivoFim, "fonte_indisponivel") == 0);
  puts("OK: sensor invalido -> DESCONHECIDO e parada encerrada como fonte_indisponivel");
  assert(fabsf(dbfsDeRms(2048) - 0) < 1e-4f && fabsf(dbfsDeRms(204.8f) + 20) < 1e-3f);
  assert(fabsf(dbfsDeRms(0) - dbfsDeRms(1)) < 1e-6f);
  puts("OK: dBFS = 20 log10(rms/2048), piso em 1 contagem");
}

static void testeModbus() {
  uint8_t q[12];
  assert(modbusMontarFC03(q, 0x1234, 1, 0, 2) == 12);
  const uint8_t esperado[12] = {0x12, 0x34, 0, 0, 0, 6, 1, 3, 0, 0, 0, 2};
  assert(memcmp(q, esperado, 12) == 0);
  const uint8_t ok[] = {0x12, 0x34, 0, 0, 0, 7, 1, 3, 4, 0, 1, 0, 101};
  uint16_t regs[2];
  assert(modbusLerRespostaFC03(ok, sizeof ok, 0x1234, 1, 2, regs) == 0 && regs[0] == 1 && regs[1] == 101);
  const uint8_t exc[] = {0x12, 0x34, 0, 0, 0, 3, 1, 0x83, 2};
  assert(modbusLerRespostaFC03(exc, sizeof exc, 0x1234, 1, 2, regs) == 2);
  assert(modbusLerRespostaFC03(ok, sizeof ok, 0x9999, 1, 2, regs) < 0);
  assert(modbusLerRespostaFC03(ok, 10, 0x1234, 1, 2, regs) < 0);
  assert(estadoDeStatusModbus(true, 1) == EstadoMaquina::OPERANDO);
  assert(estadoDeStatusModbus(true, 0) == EstadoMaquina::PARADO);
  assert(estadoDeStatusModbus(false, 0) == EstadoMaquina::DESCONHECIDO);
  assert(estadoDeStatusModbus(true, 7) == EstadoMaquina::DESCONHECIDO);
  puts("OK: Modbus FC03 quadro, resposta, excecao e perda de comunicacao");
}

static void testeFila() {
  typedef FilaCircular<Memoria, 64, 4> Fila;
  Memoria m(Fila::bytesTotais());
  Fila f(m); assert(f.abrir() && f.quantidade() == 0);
  char buf[Fila::PAYLOAD_MAX + 1]; uint8_t top; size_t n;
  for (int i = 0; i < 3; ++i) { char s[16]; snprintf(s, sizeof s, "msg%d", i); assert(f.inserir(i, s, strlen(s))); }
  assert(f.espiar(top, buf, n) && top == 0 && strcmp(buf, "msg0") == 0);
  assert(f.remover() && f.quantidade() == 2);
  Fila g(m); assert(g.abrir() && g.quantidade() == 2);  // reabrir = reinicio do ESP32
  assert(g.espiar(top, buf, n) && strcmp(buf, "msg1") == 0);
  puts("OK: fila preserva ordem e sobrevive a reabertura (reinicio)");
  for (int i = 3; i < 8; ++i) { char s[16]; snprintf(s, sizeof s, "msg%d", i); assert(g.inserir(1, s, strlen(s))); }
  assert(g.quantidade() == 4 && g.perdidas == 3);
  assert(g.espiar(top, buf, n) && strcmp(buf, "msg4") == 0);
  puts("OK: fila cheia descarta a mais antiga e conta perdas");
  std::vector<char> grande(Fila::PAYLOAD_MAX + 1, 'x');
  assert(!g.inserir(0, grande.data(), grande.size()));
  while (g.remover()) {}
  assert(g.quantidade() == 0 && !g.espiar(top, buf, n));
  Memoria lixo(Fila::bytesTotais()); lixo.b[0] = 0x12;
  Fila h(lixo); assert(h.abrir() && h.quantidade() == 0);
  puts("OK: payload grande rejeitado; cabecalho corrompido reinicia vazio");
}

int main() {
  testeConfig(); testeHisterese(); testeTempoMinimoEManual();
  testeClassificador(); testeModbus(); testeFila();
  puts("TODOS OS TESTES DE LOGICA PASSARAM");
  return 0;
}
