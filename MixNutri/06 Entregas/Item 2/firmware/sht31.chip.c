// Modelo funcional parcial SHT31, I2C 0x44. Dados inteiramente sinteticos.
// Implementa somente 0x2400 (single-shot), 0x30A2 (reset) e 0xF32D (status).
// Nao reproduz precisao, deriva, aquecimento, clock stretching ou falhas eletricas.
#include "wokwi-api.h"
#include <stdint.h>
#include <stdbool.h>

typedef struct {
  uint32_t temperature, humidity, online, crc_fault;
  uint16_t command;
  uint8_t written, response[6], length, position;
  uint64_t ready_ns;
} sht31_state_t;
static sht31_state_t sht;

static uint8_t sht_crc(const uint8_t *p) {
  uint8_t crc = 0xff;
  for (uint8_t n = 0; n < 2; ++n) {
    crc ^= p[n];
    for (uint8_t bit = 0; bit < 8; ++bit)
      crc = (crc & 0x80) ? (uint8_t)((crc << 1) ^ 0x31) : (uint8_t)(crc << 1);
  }
  return crc;
}
static bool sht_connect(void *data, uint32_t address, bool read) {
  sht31_state_t *s = data;
  if (address != 0x44 || !attr_read(s->online)) return false;
  if (!read) { s->written = 0; s->command = 0; return true; }
  s->position = 0;
  return s->length > 0 && get_sim_nanos() >= s->ready_ns;
}
static bool sht_write(void *data, uint8_t value) {
  sht31_state_t *s = data;
  if (s->written >= 2) return false;
  s->command = (uint16_t)((s->command << 8) | value);
  if (++s->written < 2) return true;
  s->length = 0;
  if (s->command == 0x30a2) { s->ready_ns = 0; return true; }
  if (s->command == 0xf32d) {
    s->response[0] = 0; s->response[1] = 0;
    s->response[2] = sht_crc(s->response);
    s->length = 3; s->ready_ns = get_sim_nanos(); return true;
  }
  if (s->command != 0x2400) return false;
  uint32_t t = attr_read(s->temperature), h = attr_read(s->humidity);
  if (t > 50) t = 50;
  if (h > 100) h = 100;
  const uint16_t raw_t = (uint16_t)(((uint64_t)(t + 45) * 65535 + 87) / 175);
  const uint16_t raw_h = (uint16_t)(((uint64_t)h * 65535 + 50) / 100);
  s->response[0] = raw_t >> 8; s->response[1] = raw_t & 0xff;
  s->response[2] = sht_crc(s->response);
  s->response[3] = raw_h >> 8; s->response[4] = raw_h & 0xff;
  s->response[5] = sht_crc(s->response + 3);
  if (attr_read(s->crc_fault)) s->response[5] ^= 1;
  s->length = 6; s->ready_ns = get_sim_nanos() + 15000000ULL;
  return true;
}
static uint8_t sht_read(void *data) {
  sht31_state_t *s = data;
  return s->position < s->length ? s->response[s->position++] : 0xff;
}
void chip_init(void) {
  sht.temperature = attr_init("temperatureC", 25);
  sht.humidity = attr_init("humidityPercent", 45);
  sht.online = attr_init("online", 1);
  sht.crc_fault = attr_init("crcFault", 0);
  pin_init("VCC", INPUT); pin_init("GND", INPUT);
  i2c_config_t config = {
    .address = 0x44, .scl = pin_init("SCL", INPUT_PULLUP),
    .sda = pin_init("SDA", INPUT_PULLUP), .connect = sht_connect,
    .read = sht_read, .write = sht_write, .user_data = &sht
  };
  i2c_init(&config);
}
