// FISH (FIG-ISH FORTH) for the NXP ARM Cortex series SystemsOnaChip (SoC).
// This FISH is for the Cortex M0 series,
// which does not support these math routines in hardware.
#include "LPC11xx.h" // $PROG_DIR version
// #include <LPC11xx.h>  // $TOOL_DIR version
// #include <core_cm0.h> // NVIC_SystemReset()
#include "core_cm0.h" // $PROG_DIR version

void C_CMSIS_DISABLE_IRQS() {
  //  NVIC_EnableIRQ(IRQn_Type IRQn);
  //  NVIC_EnableIRQ(-1);
  __disable_irq();
}

void C_CMSIS_ENABLE_IRQS() {
  //  NVIC_EnableIRQ(IRQn_Type IRQn);
  //  NVIC_EnableIRQ(-1);
  __enable_irq();
}

// c_64by32div used in :NONAME USLASH:
// C_CMSIS_DISABLE_IRQS and C_CMSIS_ENABLE_IRQS wrapper used there
int c_64by32div(int divisor, long long dividend) {
  //  __disable_irq();
  int rem = dividend % divisor; // rem = divmsw+divlsb % divisor;
  int quo = dividend / divisor; // quo = divmsw+divlsb / divisor;
                                //  __enable_irq();
  return (quo);                 // LSW of quo in t (r0), rem in w (r2)
}

// c_32by32to64mul used in :NONAME USTAR:
// C_CMSIS_DISABLE_IRQS and C_CMSIS_ENABLE_IRQS wrapper used there
long long c_32by32to64mul(int a, int b) {
  //  __disable_irq();
  long long res = a * b;
  //  __enable_irq();
  return (res); // LSW in t (r0), MSW in n (r1)
}

#ifdef USE_CMAIN
int main(void) {

  extern void FM0_COLD();
  volatile static int i = 0;
  while (1) {
    FM0_COLD(); // ret2c returns here
    i++;
  }
  return 0;
}
#endif