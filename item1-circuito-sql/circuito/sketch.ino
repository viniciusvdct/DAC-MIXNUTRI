// ITEM 1: programa de diagnostico local do circuito. Nao e o firmware completo do item 2.
// Sem MQTT, Modbus, NVS, fila offline ou classificacao industrial de maquina.
#include <Arduino.h>
#include <Wire.h>
#include <math.h>
const uint8_t SHT_ADDR = 0x44, PIN_RELE = 26, PIN_SOM = 34;
// Verificado no Wokwi: modulo npn, IN HIGH fecha COM-NO e acende a carga.
// Verificar o LED nos CONTATOS, sem inferir pelo LED interno do modulo.
const uint8_t RELE_ON = HIGH, RELE_OFF = LOW;
bool releOn = false, autoDemo = false, climaValido = false, aguardando = false;
float temperatura = NAN, umidade = NAN, ruidoRms = 0, ruidoDbfs = -66.2f;
// dBFS relativo a 2048 contagens (meia escala do ADC de 12 bits). Nao e dB SPL.
const float ADC_REF_DBFS = 2048.0f;
uint32_t ultimoPedido = 0, pedidoEm = 0, ultimoLog = 0, ultimaAmostraUs = 0;
uint16_t n = 0; double soma = 0, somaQuadrados = 0;

uint8_t crc8(const uint8_t *p) {
  uint8_t crc = 0xff;
  for (uint8_t i = 0; i < 2; ++i) {
    crc ^= p[i];
    for (uint8_t bit = 0; bit < 8; ++bit)
      crc = (crc & 0x80) ? (uint8_t)((crc << 1) ^ 0x31) : (uint8_t)(crc << 1);
  }
  return crc;
}
void acionar(bool on) {
  releOn = on;
  digitalWrite(PIN_RELE, on ? RELE_ON : RELE_OFF);
}
void pedirClima(uint32_t agora) {
  Wire.beginTransmission(SHT_ADDR); Wire.write(0x24); Wire.write(0x00);
  aguardando = Wire.endTransmission() == 0;
  pedidoEm = agora;
  if (!aguardando) { climaValido = false; temperatura = umidade = NAN; if (autoDemo) acionar(false); }
}
void receberClima() {
  uint8_t b[6];
  size_t total = Wire.requestFrom(SHT_ADDR, (uint8_t)6);
  if (total != 6) { while (Wire.available()) Wire.read(); climaValido = false; }
  else {
    for (uint8_t i = 0; i < 6; ++i) b[i] = Wire.read();
    climaValido = crc8(b) == b[2] && crc8(b + 3) == b[5];
    if (climaValido) {
      temperatura = -45.0f + 175.0f * ((uint16_t)(b[0] << 8) | b[1]) / 65535.0f;
      umidade = 100.0f * ((uint16_t)(b[3] << 8) | b[4]) / 65535.0f;
    }
  }
  if (!climaValido) temperatura = umidade = NAN;
  if (autoDemo) {
    if (!climaValido) acionar(false);
    else if (umidade >= 55.0f) acionar(true);
    else if (umidade <= 50.0f) acionar(false);
  }
  aguardando = false;
}
void setup() {
  digitalWrite(PIN_RELE, RELE_OFF); pinMode(PIN_RELE, OUTPUT);
  Serial.begin(115200); Wire.begin(21, 22); Wire.setTimeOut(50);
  analogReadResolution(12); pinMode(PIN_SOM, INPUT);
  Serial.println("ITEM1 DIAGNOSTICO | dados sinteticos | produto/lote ainda nao enviados");
  Serial.println("Comandos: 1=ON, 0=OFF, a=AUTO didatico 55/50%UR. Sem MQTT/Modbus/NVS.");
  Serial.println("SHT31 0x44, SDA21/SCL22; som ADC34, rele26. Ruido em ADC RMS e dBFS, nao dB SPL.");
  pedirClima(millis());
}
void loop() {
  uint32_t agora = millis();
  if (Serial.available()) {
    char c = Serial.read();
    if (c == '1' || c == '0') { autoDemo = false; acionar(c == '1'); }
    if (c == 'a' || c == 'A') { autoDemo = true; acionar(false); climaValido = false; }
  }
  if (aguardando && (uint32_t)(agora - pedidoEm) >= 20) receberClima();
  if (!aguardando && (uint32_t)(agora - ultimoPedido) >= 2000) {
    ultimoPedido = agora; pedirClima(agora);
  }
  uint32_t agoraUs = micros();
  if ((uint32_t)(agoraUs - ultimaAmostraUs) >= 250) {
    ultimaAmostraUs = agoraUs;
    double x = analogRead(PIN_SOM); soma += x; somaQuadrados += x * x;
    if (++n >= 256) {
      double media = soma / n;
      ruidoRms = sqrt(fmax(0.0, somaQuadrados / n - media * media));
      ruidoDbfs = 20.0f * log10f(fmaxf(ruidoRms, 1.0f) / ADC_REF_DBFS);
      soma = somaQuadrados = 0; n = 0;
    }
  }
  if ((uint32_t)(agora - ultimoLog) >= 1000) {
    ultimoLog = agora;
    Serial.printf("uptime_ms=%lu clima=%s T=%.2fC UR=%.2f%% ruido_adc_rms=%.2f ruido_dbfs=%.1f rele=%s modo=%s\n",
      (unsigned long)agora, climaValido ? "VALIDO" : "FALHA", temperatura, umidade,
      ruidoRms, ruidoDbfs, releOn ? "ON" : "OFF", autoDemo ? "AUTO_DEMO" : "MANUAL_DIAG");
  }
}
