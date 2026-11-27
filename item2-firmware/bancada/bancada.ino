// Teste de bancada do kit fisico, SEM rede: confere DHT11, microfone, rele e LEDs antes de gravar
// o firmware completo. Monitor serial em 115200. Gravar (macOS/Linux): ./gravar_esp32.sh bancada
//
// Comandos no monitor serial:
//   ?  ajuda            h  GPIO 26 em HIGH     l  GPIO 26 em LOW      r  alterna o GPIO 26
//   t  testa os LEDs    1  alterna amarelo     2  alterna vermelho    3  alterna azul da placa
//   d  le o DHT11 agora c  calibra o som por 10 s (rode em silencio e depois com ruido)
// O som usa as mesmas janelas e a mesma formula do firmware: dBFS = 20 log10(RMS / 2048), nao dB SPL.
#include <Arduino.h>
#include <DHT.h>
#include <math.h>
#include "hardware_fisico.h"

static const uint8_t PIN_RELE = 26, PIN_SOM = 34, PIN_LED_REDE = 2;  // iguais ao firmware

static DHT dht(PIN_DHT, DHT11);
static uint32_t ultimoDht = 0, ultimoLog = 0;
static float temperatura = NAN, umidade = NAN;
static bool dhtOk = false;

// --------------------------------------------------------------------------- som
// 4 kHz, janelas de 256 amostras, blocos de 8 janelas (~0,5 s): igual ao firmware do item 2.
struct Bloco { float media, rms, dbfs; uint16_t min, max; };
static uint32_t ultimaAmostraUs = 0;
static uint16_t nJanela = 0, minBloco = 4095, maxBloco = 0;
static uint8_t janelas = 0;
static double soma = 0, somaQ = 0, potBloco = 0, mediaBloco = 0;
static Bloco ultimo = {0, 0, -66.2f, 0, 0};
static bool temBloco = false;

static const uint8_t CALIB_MAX = 40;  // 40 blocos de ~0,5 s cobrem os 10 s
static float calib[CALIB_MAX];
static uint8_t nCalib = 0;
static bool calibrando = false;
static uint32_t calibInicio = 0;

static float dbfs(float rms) { return 20.0f * log10f((rms < 1.0f ? 1.0f : rms) / 2048.0f); }

static void amostrarSom() {
  const uint32_t us = micros();
  if ((uint32_t)(us - ultimaAmostraUs) < 250) return;
  ultimaAmostraUs = us;
  const uint16_t x = analogRead(PIN_SOM);
  soma += x;
  somaQ += (double)x * x;
  if (x < minBloco) minBloco = x;
  if (x > maxBloco) maxBloco = x;
  if (++nJanela < 256) return;
  const double m = soma / nJanela;
  potBloco += fmax(0.0, somaQ / nJanela - m * m);  // remove o nivel DC de cada janela
  mediaBloco += m;
  soma = somaQ = 0;
  nJanela = 0;
  if (++janelas < 8) return;
  ultimo.media = mediaBloco / janelas;
  ultimo.rms = sqrt(potBloco / janelas);
  ultimo.dbfs = dbfs(ultimo.rms);
  ultimo.min = minBloco;
  ultimo.max = maxBloco;
  potBloco = mediaBloco = 0;
  janelas = 0;
  minBloco = 4095;
  maxBloco = 0;
  temBloco = true;
  if (calibrando && nCalib < CALIB_MAX) calib[nCalib++] = ultimo.dbfs;
}

// O firmware completo considera o sensor ausente se a media sair de 200..3900 contagens.
static const char *diagnosticoSom(const Bloco &b) {
  if (b.media < 200 || b.media > 3900) return "SEM POLARIZACAO: o firmware vai considerar o sensor ausente";
  if (b.min < 20 || b.max > 4075) return "SATURANDO: sinal forte demais ou polarizacao fora do centro";
  return "ok";
}

static void relatorioCalibracao() {
  if (nCalib == 0) { Serial.println("CALIBRACAO sem blocos medidos"); return; }
  for (uint8_t i = 1; i < nCalib; ++i) {  // ordena (insercao)
    const float v = calib[i];
    int8_t j = i - 1;
    while (j >= 0 && calib[j] > v) { calib[j + 1] = calib[j]; --j; }
    calib[j + 1] = v;
  }
  Serial.printf("CALIBRACAO %u blocos: min=%.1f p10=%.1f mediana=%.1f p90=%.1f max=%.1f dBFS\n", nCalib,
                calib[0], calib[nCalib / 10], calib[nCalib / 2], calib[(nCalib * 9) / 10], calib[nCalib - 1]);
  Serial.println("  Rode 'c' com a maquina PARADA e de novo OPERANDO. Sugestao para o Admin:");
  Serial.println("  limiar parado = p90 do silencio + 3 dB; limiar operando = p10 do ruido - 3 dB.");
  Serial.println("  Precisa sobrar uma folga entre os dois; se nao sobrar, aproxime o microfone da fonte.");
}

// ------------------------------------------------------------------- DHT11
static void lerDht() {
  dhtOk = dht.read(true);
  if (dhtOk) {
    umidade = dht.readHumidity();
    temperatura = dht.readTemperature();
    dhtOk = isfinite(umidade) && isfinite(temperatura);
  }
  if (!dhtOk) temperatura = umidade = NAN;
}

// -------------------------------------------------------------- rele e LEDs
static void nivelRele(bool alto) {
  digitalWrite(PIN_RELE, alto ? HIGH : LOW);
  Serial.printf("RELE GPIO %u = %s. O rele estalou e o LED verde (COM/NO) acendeu?\n", PIN_RELE, alto ? "HIGH" : "LOW");
  Serial.println("  Se o LED verde acende com HIGH: RELE_ATIVO_EM_HIGH 1. Se acende com LOW: 0 (hardware_fisico.h).");
}

static void alternar(uint8_t pino, const char *nome) {
  const bool novo = !digitalRead(pino);
  digitalWrite(pino, novo);
  Serial.printf("LED %s (GPIO %u) %s\n", nome, pino, novo ? "ACESO" : "apagado");
}

static void testarLeds() {
  const uint8_t pinos[] = {PIN_LED_PARADA, PIN_LED_ALERTA, PIN_LED_REDE};
  const char *nomes[] = {"amarelo", "vermelho", "azul da placa"};
  for (uint8_t i = 0; i < 3; ++i) {
    Serial.printf("LED %s (GPIO %u) aceso por 0,7 s\n", nomes[i], pinos[i]);
    digitalWrite(pinos[i], HIGH);
    delay(700);
    digitalWrite(pinos[i], LOW);
  }
}

static void ajuda() {
  Serial.println("Comandos: ? ajuda | h/l/r rele (GPIO 26) | t testa LEDs | 1 amarelo | 2 vermelho | 3 azul");
  Serial.println("          d le o DHT11 agora | c calibra o som por 10 s");
}

static void comando(char c) {
  switch (c) {
    case 'h': nivelRele(true); break;
    case 'l': nivelRele(false); break;
    case 'r': nivelRele(!digitalRead(PIN_RELE)); break;
    case 't': testarLeds(); break;
    case '1': alternar(PIN_LED_PARADA, "amarelo"); break;
    case '2': alternar(PIN_LED_ALERTA, "vermelho"); break;
    case '3': alternar(PIN_LED_REDE, "azul da placa"); break;
    case 'd':
      lerDht();
      Serial.printf("DHT11 %s T=%.1f C UR=%.0f %%\n", dhtOk ? "ok" : "FALHA", temperatura, umidade);
      break;
    case 'c':
      nCalib = 0;
      calibrando = true;
      calibInicio = millis();
      Serial.println("CALIBRACAO iniciada: 10 s medindo o som...");
      break;
    case '\r': case '\n': case ' ': break;
    default: ajuda();
  }
}

void setup() {
  digitalWrite(PIN_RELE, LOW);
  pinMode(PIN_RELE, OUTPUT);
  pinMode(PIN_LED_PARADA, OUTPUT);
  pinMode(PIN_LED_ALERTA, OUTPUT);
  pinMode(PIN_LED_REDE, OUTPUT);
  Serial.begin(115200);
  analogReadResolution(12);
  pinMode(PIN_SOM, INPUT);
  dht.begin();
  delay(300);
  Serial.println();
  Serial.println("MIXNUTRI TESTE DE BANCADA | sem rede | som em dBFS (nao dB SPL)");
  Serial.printf("Pinos: DHT11=%u  microfone=%u (ADC)  rele=%u  amarelo=%u  vermelho=%u  azul=%u\n", PIN_DHT, PIN_SOM,
                PIN_RELE, PIN_LED_PARADA, PIN_LED_ALERTA, PIN_LED_REDE);
  Serial.printf("Rele comeca em LOW. hardware_fisico.h diz RELE_ATIVO_EM_HIGH=%d.\n", RELE_ATIVO_EM_HIGH);
  ajuda();
  testarLeds();
}

void loop() {
  amostrarSom();
  if (Serial.available()) comando((char)Serial.read());
  const uint32_t agora = millis();
  if (calibrando && (uint32_t)(agora - calibInicio) >= 10000) {
    calibrando = false;
    relatorioCalibracao();
  }
  if ((uint32_t)(agora - ultimoDht) >= 2000) {  // DHT11: no maximo uma leitura por segundo
    ultimoDht = agora;
    lerDht();
  }
  if (temBloco && (uint32_t)(agora - ultimoLog) >= 1000) {
    ultimoLog = agora;
    temBloco = false;
    char clima[48];
    if (dhtOk) snprintf(clima, sizeof clima, "UR=%.0f%% T=%.1fC", umidade, temperatura);
    else snprintf(clima, sizeof clima, "DHT11 FALHA");
    Serial.printf("%s | SOM media=%.0f (~%.2f V) rms=%.1f dBFS=%.1f min=%u max=%u %s | RELE=%s\n", clima,
                  ultimo.media, ultimo.media * 3.3f / 4095.0f, ultimo.rms, ultimo.dbfs, ultimo.min, ultimo.max,
                  diagnosticoSom(ultimo), digitalRead(PIN_RELE) ? "HIGH" : "LOW");
  }
}
