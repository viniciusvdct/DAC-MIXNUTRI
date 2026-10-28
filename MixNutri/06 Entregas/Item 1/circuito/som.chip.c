// Gerador de sinal analogico sintetico. NAO e modelo calibrado de MAX9814/INMP441.
// Tom de 200 Hz (onda quadrada) representando a maquina + ruido de fundo pseudoaleatorio,
// em torno de 1,65 V. Tom ate 0,9 V e ruido ate 0,3 V; saida limitada a 0-3,3 V.
// online=0 leva a saida a 0 V para simular sensor desconectado.
#include "wokwi-api.h"
#include <stdbool.h>
#include <stdint.h>
typedef struct {
  pin_t out;
  uint32_t amplitude, ruido, online;
  uint16_t lfsr;
  uint8_t passo;
  bool high;
} sound_state_t;
static sound_state_t sound;

static float sound_level(uint32_t attr, float full) {
  uint32_t v = attr_read(attr);
  if (v > 100) v = 100;
  return full * v / 100.0f;
}
// LFSR de 16 bits (taps 16,14,13,11): sequencia pseudoaleatoria deterministica.
static float sound_noise(sound_state_t *s) {
  uint16_t bit = (uint16_t)(((s->lfsr >> 0) ^ (s->lfsr >> 2) ^ (s->lfsr >> 3) ^ (s->lfsr >> 5)) & 1u);
  s->lfsr = (uint16_t)((s->lfsr >> 1) | (bit << 15));
  return (float)s->lfsr / 32767.5f - 1.0f;
}
static void sound_tick(void *data) {
  sound_state_t *s = data;
  if (!attr_read(s->online)) { pin_dac_write(s->out, 0.0f); return; }
  // Passo de 500 us; inverte o tom a cada 5 passos = 2,5 ms -> 200 Hz.
  if (++s->passo >= 5) { s->passo = 0; s->high = !s->high; }
  float v = 1.65f + (s->high ? 1.0f : -1.0f) * sound_level(s->amplitude, 0.9f)
          + sound_noise(s) * sound_level(s->ruido, 0.3f);
  if (v < 0.0f) v = 0.0f;
  if (v > 3.3f) v = 3.3f;
  pin_dac_write(s->out, v);
}
void chip_init(void) {
  pin_init("VCC", INPUT); pin_init("GND", INPUT);
  sound.out = pin_init("OUT", ANALOG);
  sound.amplitude = attr_init("amplitudePercent", 80);
  sound.ruido = attr_init("ruidoFundoPercent", 5);
  sound.online = attr_init("online", 1);
  sound.lfsr = 0xACE1u;
  pin_dac_write(sound.out, 1.65f);
  timer_config_t config = { .callback = sound_tick, .user_data = &sound };
  timer_start(timer_init(&config), 500, true);
}
