// Cliente Modbus TCP (funcao 03, um registrador) independente da plataforma: o mesmo codigo
// roda com WiFiClient no ESP32 e com um adaptador de sockets no computador
// (testes/test_modbus_rede.cpp). Espera no maximo ~1 s pela resposta.
#pragma once
#include "logica.h"

namespace mixnutri {

// Cliente: connected(), stop(), connect(host, porta, timeout_ms), write(buf, n), available(), read().
// Relogio: agoraMs() e esperar1ms().
// Retorna 0, codigo de excecao Modbus (>0) ou erro local (<0; -10 conexao, -11 escrita).
template <class Cliente, class Relogio>
int modbusLerRegistrador(Cliente &cli, Relogio &relogio, const char *host, uint16_t porta, uint8_t unit,
                         uint16_t reg, uint16_t &tid, uint16_t &valor) {
  if (!cli.connected()) {
    cli.stop();
    if (!cli.connect(host, porta, 1000)) return -10;
  }
  uint8_t q[12], r[16];
  const uint16_t id = ++tid;
  modbusMontarFC03(q, id, unit, reg, 1);
  if (cli.write(q, sizeof q) != sizeof q) { cli.stop(); return -11; }
  size_t n = 0, esperado = 11;
  const uint32_t t0 = relogio.agoraMs();
  while (n < esperado && (uint32_t)(relogio.agoraMs() - t0) < 1000) {
    if (cli.available()) {
      r[n++] = (uint8_t)cli.read();
      if (n == 8 && (r[7] & 0x80)) esperado = 9;
    } else {
      relogio.esperar1ms();
    }
  }
  const int res = modbusLerRespostaFC03(r, n, id, unit, 1, &valor);
  if (res < 0) cli.stop();
  return res;
}

}  // namespace mixnutri
