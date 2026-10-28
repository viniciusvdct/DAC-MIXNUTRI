// Testa o cliente Modbus do firmware (modbus_cliente.h, o mesmo codigo do ESP32) por TCP de
// verdade, contra o simulador Modbus do kit do item 3. Compilar a partir da pasta firmware:
//   clang++ -std=c++17 -Wall -Wextra -Werror -I . testes/test_modbus_rede.cpp -o /tmp/modbus-rede
//   /tmp/modbus-rede 127.0.0.1 5020
// Registradores do simulador: 0 UR x10, 1 temperatura x10, 2 ruido x10, 3 rodando (1/0),
// 4 desumidificador, 5 codigo de falha. O estado "rodando" alterna a cada 35 s.
#include <arpa/inet.h>
#include <assert.h>
#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>
#include "modbus_cliente.h"
using namespace mixnutri;

// Adaptador com a mesma interface usada do WiFiClient.
struct ClienteSocket {
  int fd = -1;
  bool connected() const { return fd >= 0; }
  void stop() { if (fd >= 0) close(fd); fd = -1; }
  int connect(const char *host, uint16_t porta, int32_t timeoutMs) {
    char p[8]; snprintf(p, sizeof p, "%u", porta);
    addrinfo dica = {}, *res = nullptr;
    dica.ai_family = AF_INET; dica.ai_socktype = SOCK_STREAM;
    if (getaddrinfo(host, p, &dica, &res) != 0) return 0;
    fd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
    timeval tv = {timeoutMs / 1000, (timeoutMs % 1000) * 1000};
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof tv);
    const bool ok = ::connect(fd, res->ai_addr, res->ai_addrlen) == 0;
    freeaddrinfo(res);
    if (!ok) stop();
    return ok;
  }
  size_t write(const uint8_t *b, size_t n) { const ssize_t w = send(fd, b, n, 0); return w < 0 ? 0 : (size_t)w; }
  int available() { int n = 0; return ioctl(fd, FIONREAD, &n) == 0 ? n : 0; }
  int read() { uint8_t b; return recv(fd, &b, 1, 0) == 1 ? b : -1; }
};
struct RelogioHost {
  uint32_t agoraMs() { timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return (uint32_t)(t.tv_sec * 1000 + t.tv_nsec / 1000000); }
  void esperar1ms() { usleep(1000); }
};

int main(int argc, char **argv) {
  const char *host = argc > 1 ? argv[1] : "127.0.0.1";
  const uint16_t porta = (uint16_t)(argc > 2 ? atoi(argv[2]) : 5020);
  ClienteSocket cli; RelogioHost rel; uint16_t tid = 0, v = 0;

  assert(modbusLerRegistrador(cli, rel, host, porta, 1, 0, tid, v) == 0);
  assert(v >= 520 && v <= 600);
  printf("OK: UR x10 = %u (simulador: 52 a 60%%)\n", v);
  uint16_t falha = 99;
  assert(modbusLerRegistrador(cli, rel, host, porta, 1, 5, tid, falha) == 0 && falha == 0);
  puts("OK: CODIGO_FALHA (reg 5) = 0");
  assert(modbusLerRegistrador(cli, rel, host, porta, 1, 10, tid, v) == 2);
  puts("OK: registrador inexistente -> excecao Modbus 2 (endereco ilegal)");

  // Mesma conexao reaproveitada; acompanha STATUS_MAQUINA (reg 3) ate ver as duas condicoes.
  bool viuOperando = false, viuParado = false;
  int anterior = -1, transicoes = 0;
  const uint32_t t0 = rel.agoraMs();
  while (!(viuOperando && viuParado) && rel.agoraMs() - t0 < 40000) {
    uint16_t st = 9;
    assert(modbusLerRegistrador(cli, rel, host, porta, 1, 3, tid, st) == 0);
    const EstadoMaquina e = estadoDeStatusModbus(true, st);
    viuOperando |= e == EstadoMaquina::OPERANDO; viuParado |= e == EstadoMaquina::PARADO;
    if (anterior >= 0 && st != anterior) {
      ++transicoes;
      printf("     transicao STATUS_MAQUINA %d -> %u (%s) apos %.1f s\n", anterior, st, nomeEstado(e), (rel.agoraMs() - t0) / 1000.0);
    }
    anterior = st;
    usleep(500000);
  }
  assert(viuOperando && viuParado && transicoes >= 1);
  printf("OK: STATUS_MAQUINA lido como OPERANDO e PARADO; %u leituras na mesma conexao\n", tid);

  cli.stop();
  assert(modbusLerRegistrador(cli, rel, host, 5999, 1, 3, tid, v) == -10);
  assert(estadoDeStatusModbus(false, 0) == EstadoMaquina::DESCONHECIDO);
  puts("OK: servidor fora do ar -> erro de conexao (-10) -> DESCONHECIDO, nao PARADO");
  puts("TODOS OS TESTES MODBUS POR REDE PASSARAM");
  return 0;
}
