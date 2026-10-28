// Adaptador local para testar callbacks em C nativo. Nao e usado pelo compilador Wokwi.
#ifndef TEST_WOKWI_API_H
#define TEST_WOKWI_API_H
#include <stdint.h>
#include <stdbool.h>
typedef int32_t pin_t;
enum { INPUT=0, OUTPUT=1, INPUT_PULLUP=2, ANALOG=4 };
typedef struct {
 void *user_data; uint32_t address; pin_t scl,sda;
 bool (*connect)(void*,uint32_t,bool); uint8_t (*read)(void*);
 bool (*write)(void*,uint8_t); void (*disconnect)(void*); uint32_t reserved[8];
} i2c_config_t;
typedef struct { void *user_data; void (*callback)(void*); uint32_t reserved[8]; } timer_config_t;
pin_t pin_init(const char*,uint32_t);
uint32_t attr_init(const char*,uint32_t);
uint32_t attr_read(uint32_t);
uint64_t get_sim_nanos(void);
uint32_t i2c_init(const i2c_config_t*);
void pin_dac_write(pin_t,float);
uint32_t timer_init(const timer_config_t*);
void timer_start(uint32_t,uint32_t,bool);
#endif
