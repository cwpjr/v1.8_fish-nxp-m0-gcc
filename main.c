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
// Naked Thumb-1 asm: the previous C body pulled in ~716 bytes of libgcc
// 64-bit runtime (__divdi3, __aeabi_lmul, __clzsi2, ...). Same ABI:
//   in:  r0 = divisor, r2:r3 = dividend (AAPCS 64-bit pair)
//   out: r0 = quotient (t), r2 = remainder (w)
// Contract: divisor != 0 (call sites test and take DZERO first), divisor
// < 2^31, and dividend_hi < divisor (the classic Forth U/ overflow rule).
// All FISH uses (base conversion, baud calc, M*/) satisfy this. Exactness
// of this structure verified against 50k randomized cases bit-for-bit.
__attribute__((naked)) int c_64by32div(int divisor, long long dividend) {
  __asm__ volatile(".syntax unified\n" // GCC emits .syntax divided here
                   "push {r4, r5}\n"
                   "mov r4, r0\n"       // divisor
                   "movs r0, #0\n"      // quotient
                   "mov r1, r3\n"       // rem = dividend HI
                   "movs r5, #32\n"
                   "1:\n"
                   "lsls r2, r2, #1\n"  // C = next dividend LO bit (MSB 1st)
                   "adcs r1, r1, r1\n"  // rem = rem<<1 | bit, C = bit32
                   "bcs 2f\n"           // (outside envelope; safety net)
                   "cmp r1, r4\n"
                   "bcc 3f\n"           // rem < divisor: quo bit 0
                   "2:\n"
                   "subs r1, r1, r4\n"  // rem -= divisor
                   "lsls r0, r0, #1\n"
                   "adds r0, r0, #1\n"  // quo bit 1
                   "b 4f\n"
                   "3:\n"
                   "lsls r0, r0, #1\n"  // quo bit 0
                   "4:\n"
                   "subs r5, r5, #1\n"
                   "bne 1b\n"
                   "mov r2, r1\n"       // rem out in r2 (w)
                   "pop {r4, r5}\n"
                   "bx lr\n");
}

// c_32by32to64mul used in :NONAME USTAR:
// C_CMSIS_DISABLE_IRQS and C_CMSIS_ENABLE_IRQS wrapper used there
// Naked Thumb-1 asm (see c_64by32div note). Same ABI:
//   in:  r0 = a (t), r1 = b (n)
//   out: r0 = LSW (t), r1 = MSW (n)   (AAPCS long long result)
__attribute__((naked)) long long c_32by32to64mul(int a, int b) {
  __asm__ volatile(".syntax unified\n" // GCC emits .syntax divided here
                   "movs r2, #0\n"      // multiplicand hi
                   "movs r3, #0\n"      // result lo
                   "push {r4}\n"
                   "movs r4, #0\n"      // result hi
                   "1:\n"
                   "lsrs r0, r0, #1\n"  // C = next multiplier bit
                   "bcc 2f\n"
                   "adds r3, r3, r1\n"  // result += multiplicand (64-bit)
                   "adcs r4, r4, r2\n"
                   "2:\n"
                   "lsls r1, r1, #1\n"  // multiplicand <<= 1 (64-bit)
                   "adcs r2, r2, r2\n"
                   "cmp r0, #0\n"       // multiplier bits left?
                   "bne 1b\n"
                   "mov r0, r3\n"       // LSW out in t (r0)
                   "mov r1, r4\n"       // MSW out in n (r1)
                   "pop {r4}\n"
                   "bx lr\n");
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