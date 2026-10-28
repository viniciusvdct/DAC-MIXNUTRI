// Exercita os callbacks reais dos modelos, com adaptadores de host.
#include <assert.h>
#include <stdio.h>
#include <math.h>
#include <string.h>
#include "wokwi-api.h"
static uint32_t values[16], attrs;
static const char *names[16];
static uint64_t now;
static i2c_config_t bus;
static timer_config_t timer;
static float voltage;
pin_t pin_init(const char *name,uint32_t mode) { (void)name;(void)mode;return 1; }
uint32_t attr_init(const char *name,uint32_t initial) { names[attrs]=name;values[attrs]=initial;return attrs++; }
uint32_t attr_read(uint32_t id) { assert(id<attrs);return values[id]; }
uint64_t get_sim_nanos(void) { return now; }
uint32_t i2c_init(const i2c_config_t *c) { bus=*c;return 1; }
void pin_dac_write(pin_t pin,float v) { (void)pin;voltage=v; }
uint32_t timer_init(const timer_config_t *c) { timer=*c;return 1; }
void timer_start(uint32_t id,uint32_t us,bool repeat) { assert(id==1&&us==500&&repeat); }
// Ajusta todos os atributos com o nome (ex.: "online" existe nos dois modelos).
static void set(const char *name,uint32_t value) {
 bool achou=false;
 for(uint32_t i=0;i<attrs;i++) if(strcmp(names[i],name)==0) {values[i]=value;achou=true;}
 assert(achou&&"atributo inexistente");
}
#define chip_init sht_model_init
#include "../circuito/sht31.chip.c"
#undef chip_init
#define chip_init sound_model_init
#include "../circuito/som.chip.c"
#undef chip_init
static bool command(uint16_t c) {
 assert(bus.connect(bus.user_data,0x44,false));
 assert(bus.write(bus.user_data,c>>8));
 return bus.write(bus.user_data,c&255);
}
int main(void) {
 sht_model_init();assert(bus.address==0x44);
 uint8_t known[]={0xbe,0xef};assert(sht_crc(known)==0x92);
 puts("OK: vetor CRC do datasheet 0xBEEF -> 0x92");
 assert(!bus.connect(bus.user_data,0x45,false));
 assert(!bus.connect(bus.user_data,0x44,true));
 assert(command(0x2400));
 assert(!bus.connect(bus.user_data,0x44,true));
 now=14999999;assert(!bus.connect(bus.user_data,0x44,true));
 now=15000000;assert(bus.connect(bus.user_data,0x44,true));
 uint8_t b[6];for(int i=0;i<6;i++)b[i]=bus.read(bus.user_data);
 assert(sht_crc(b)==b[2]&&sht_crc(b+3)==b[5]);
 double t=-45.+175.*((b[0]<<8)|b[1])/65535.;
 double h=100.*((b[3]<<8)|b[4])/65535.;
 assert(fabs(t-25.)<0.01&&fabs(h-45.)<0.01);
 puts("OK: 25C e 45%UR com CRC e espera minima de 15ms");
 assert(command(0xf32d));assert(bus.connect(bus.user_data,0x44,true));
 for(int i=0;i<3;i++)b[i]=bus.read(bus.user_data);
 assert(b[0]==0&&b[1]==0&&b[2]==sht_crc(b));
 assert(command(0x30a2));assert(!bus.connect(bus.user_data,0x44,true));
 assert(!command(0xffff));assert(!bus.connect(bus.user_data,0x44,true));
 puts("OK: status, reset e comando nao suportado");
 set("online",0);assert(!bus.connect(bus.user_data,0x44,false));set("online",1);
 puts("OK: falha de comunicacao gera NACK");
 for(int i=0;i<2;i++) {
  set("humidityPercent",i?100:0);set("temperatureC",i?50:0);
  assert(command(0x2400));now+=15000000;
  assert(bus.connect(bus.user_data,0x44,true));for(int k=0;k<6;k++)b[k]=bus.read(bus.user_data);
  h=100.*((b[3]<<8)|b[4])/65535.;assert(fabs(h-(i?100:0))<0.01);
 }
 puts("OK: limites de umidade 0% e 100%");
 set("crcFault",1);assert(command(0x2400));now+=15000000;
 assert(bus.connect(bus.user_data,0x44,true));for(int k=0;k<6;k++)b[k]=bus.read(bus.user_data);
 assert(sht_crc(b+3)!=b[5]);puts("OK: injecao de erro CRC detectavel");
 sound_model_init();assert(fabs(voltage-1.65)<0.001);
 set("amplitudePercent",0);set("ruidoFundoPercent",0);timer.callback(timer.user_data);
 assert(fabs(voltage-1.65)<0.001);
 set("amplitudePercent",100);
 int ultimaTroca=-1,trocas=0;float anterior=-1;
 for(int i=0;i<40;i++){
  timer.callback(timer.user_data);
  assert(fabs(voltage-.75)<.001||fabs(voltage-2.55)<.001);
  if(anterior>=0&&fabs(voltage-anterior)>1){if(ultimaTroca>=0)assert(i-ultimaTroca==5);ultimaTroca=i;trocas++;}
  anterior=voltage;
 }
 assert(trocas>=7);  /* troca a cada 5 passos de 500 us = 2,5 ms -> 200 Hz */
 puts("OK: tom de 200 Hz entre 0,75V e 2,55V, silencio em 1,65V");
 set("amplitudePercent",0);set("ruidoFundoPercent",100);
 float vmin=9,vmax=-9;
 for(int i=0;i<2000;i++){timer.callback(timer.user_data);if(voltage<vmin)vmin=voltage;if(voltage>vmax)vmax=voltage;}
 assert(vmin>=1.35f-1e-3f&&vmax<=1.95f+1e-3f&&vmax-vmin>0.5f);
 puts("OK: ruido de fundo limitado a 1,65V +/- 0,3V e nao constante");
 set("online",0);timer.callback(timer.user_data);assert(fabs(voltage)<1e-6);set("online",1);
 puts("OK: sensor desconectado leva a saida a 0V");
 return 0;
}
