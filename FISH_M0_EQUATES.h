 // FISH NXP M0/M1+ VARIANTS FOR THIS SOURCE
 // #def are placed in the Assembler Preproccesor Defined Symbols section.
 // EQUATES are for REAL VALUES used in FISH assembly code
#ifdef NXP_M0_11xx_XRC10_50MHZ
.equ SYSTEMCLOCK, 50000000
#endif
#ifdef NXP_M0_11xx_IRC12_48MHZ
.equ SYSTEMCLOCK, 48000000
#endif
#ifdef NXP_M0_81x_IRC12_12MHZ
.equ SYSTEMCLOCK, 12000000
#endif
#ifdef NXP_M0_81x_IRC12_24MHZ
.equ SYSTEMCLOCK, 24000000
#endif

 //---------------------------------NXP M0/M1+ Flash Equates --------------------------------
 // Starting and Last Page cannot equal FLASH_PPAGE - which may be reserved and fault if read
 // FLASH_UPAGE1 = 0 = NO FLASH AVAILABLE

 // This section for NXP M0 1115 64k Flash parts
#ifdef NXP_M0_064kFlash_4KWrite
.equ FLASH_WR_SIZE, 0x1000
.equ FLASH_SPAGE, 0x4000
.equ FLASH_LPAGE, 0xF000
 // FOR LOOP CONTROL AND BOUNDS CHECKING
.equ FLASH_PPAGE, 0x10000
#endif // NXP_M0_064kFlash_4KWrite

 // This section for NXP M0 1114 32k Flash parts
#ifdef NXP_M0_032kFlash_4KWrite
.equ FLASH_WR_SIZE, 0x1000
.equ FLASH_SPAGE, 0x4000
.equ FLASH_LPAGE, 0x7000
 // FOR LOOP CONTROL AND BOUNDS CHECKING
.equ FLASH_PPAGE, 0x8000
#endif // NXP_M0_032kFlash_4KWrite

 // This section for NXP M1 812 16k Flash parts
 // Dictionary size is selectable in 1K pages via one ASM_DEFINES constant:
 //   (none)        = 1K dict (SPAGE 0x3C00) - legacy default
 //   FISH_DICT_2K  = 2K dict (SPAGE 0x3800)
 //   FISH_DICT_3K  = 3K dict (SPAGE 0x3400)
 //   FISH_DICT_4K  = 4K dict (SPAGE 0x3000)
 // The kernel image MUST fit below FLASH_SPAGE: `make` runs
 // fish_check_fit.py against FLASH_SPAGE_HEX in the Makefile - keep
 // Makefile FLASH_SPAGE_HEX in sync with the chosen FISH_DICT_xK!
#ifdef NXP_M0_016kFlash_1KWrite
.equ FLASH_WR_SIZE, 0x0400
 // .equ does not exist for the C preprocessor: use #if/#elif, never
 // #ifndef FLASH_SPAGE here.
#if defined(FISH_DICT_4K)
.equ FLASH_SPAGE, 0x3000 // 4K FREE
#elif defined(FISH_DICT_3K)
.equ FLASH_SPAGE, 0x3400 // 3K FREE
#elif defined(FISH_DICT_2K)
.equ FLASH_SPAGE, 0x3800 // 2K FREE
#else
#ifndef SRM
.equ FLASH_SPAGE, 0x3C00 // 1K FREE (legacy default)
#else
.equ FLASH_SPAGE, 0x3800 // SRM legacy default (2K FREE)
#endif // SRM
#endif // FISH_DICT_xK
.equ FLASH_LPAGE, 0x3C00
 // FOR LOOP CONTROL AND BOUNDS CHECKING
.equ FLASH_PPAGE, 0x4000
#endif // NXP_M0_016kFlash_1KWrite

 // Various RAM sizes set here
 // This is universal in NXP, Cortex M0/M1+'s !?!
.equ RAM_START, 0x10000000

#ifdef NXP_M0_004kRam
.equ RAM_END, 0x10001000
#endif
#ifdef NXP_M0_008kRam // STP NXP 32k/8k, 64k/8k and LPCxpresso Boards:
.equ RAM_END, 0x10002000
#endif

.equ DEFAULT_BAUD, 9600
.equ DEFAULT_BASE, 10
.equ XON_CHAR, 17
.equ XOFF_CHAR, 19
.equ IOBUFSIZE, 96
.equ MAXWORDLEN, 31

 // RESERVE SPACE FOR IAP PROGRAMMING execution and STACK:
/* UM10398 LPC111x/LPC11Cxx User manual
26.4.7 Interrupts during IAP
The on-chip flash memory is not accessible during erase/write operations. When the user
application code starts executing the interrupt vectors from the user flash area are active.
Before making any IAP call, either disable the interrupts or ensure that the user interrupt
vectors are active in RAM and that the interrupt handlers reside in RAM. The IAP code
does not use or disable interrupts.
26.4.8 RAM used by ISP command handler
ISP commands use on-chip RAM from 0x1000 017C to 0x1000 025B. The user could use
this area, but the contents may be lost upon reset. Flash programming commands use the
top 32 bytes of on-chip RAM. The stack is located at (RAM top - 32). The maximum stack
usage is 256 bytes and it grows downwards.
26.4.9 RAM used by IAP command handler
Flash programming commands use the top 32bytes of on-chip RAM. The maximum stack
usage in the user allocated stack space is 128 bytes and it grows downwards.
*/

 // So (RAM top - 32) + 256 byte stack needs to be provided!
 // By section IAP-ISP_Reserved in memap and .icf (The 32 bytes)
 // - Verify SP? (is it sp or cstack?) has 256 bytes available

 // IAR PROJECT->LINKER->COMFIG->EDIT->MEMORY REGIONS->RAM->END<<<<<<<<<<<<<<<<<<
 // RESERVE SPACE FOR CSTACK
 // IAR PROJECT->LINKER->COMFIG->EDIT->STACK/HEAP SIZES<<<<<<<<<<<<<<<<<<<<<<<<<<
 // FISH SETS THESE VALUES TO 0x40
.equ IAPCALL, 0x1FFF1FF1
/*
#ifdef NXP_M0_004kRam
.equ BOTTOM_IAPSTACK, 0x10000FE0
.equ TOP_IAPSTACK, BOTTOM_IAPSTACK+32
#endif
#ifdef NXP_M0_008kRam
.equ BOTTOM_IAPSTACK, 0x10001FE0
.equ TOP_IAPSTACK, BOTTOM_IAPSTACK+32
#endif
*/
.equ STACKSIZE, 32*4

 //------------------------------------------------------------------------------
 // RESERVE SPACE AFTER .bss FOR FISH STACKS, AND UNINITIALIZED RAM

.equ PINIT, (RAM_END-16)
.equ RINIT, (PINIT - STACKSIZE)
.equ BOTTOM_RSTACK, (RINIT - STACKSIZE)

 // Uninitialized RAM is between CSTACK$$Limit and RINIT-(size)
 // RECALCULATE IF ANY NEW _SV'S ADDED OR STACKSIZE CHANGED<<<<<<<<<<<<<<<<<<<<<<
 // CSTACK AND HEAP IF ALLOCATED FOLLOWS .bss ( FOLLOWING FROM SYM FILE )

 // 10000c78 B CSTACK$$Limit
 // 10000c80 a UNINITRAMBASE
 // 10000edc a UNINITRAMEND 592 BYTES
 // 10000ee0 a BOTTOM_RSTACK
#ifdef NXP_M0_004kRam
.equ ALL_UNINITRAM_START, 0x10000D40
 // USED FOR SAVING BAUDRATE BETWEEN RESETS AND HARD FAULT RESETS
#define DBAUD	ALL_UNINITRAM_START // .bss zeroing out one word past WARNING
#define UBAUD	ALL_UNINITRAM_START+4
 // Define space for user use of this resource - After DBAUD and UBAUD so far!
.equ ALL_UNINITRAM_FREE_START, ALL_UNINITRAM_START+8
.equ ALL_UNINITRAM_END, BOTTOM_RSTACK-4
#endif // NXP_M0_004kRam

#ifdef NXP_M0_008kRam
.equ ALL_UNINITRAM_START, 0x10001300
 // USED FOR SAVING BAUDRATE BETWEEN RESETS AND HARD FAULT RESETS
#define DBAUD	ALL_UNINITRAM_START // .bss zeroing out one word past WARNING
#define UBAUD	ALL_UNINITRAM_START+4
 // Define space for user use of this resource - After DBAUD and UBAUD so far!
.equ ALL_UNINITRAM_FREE_START, ALL_UNINITRAM_START+8
.equ ALL_UNINITRAM_END, BOTTOM_RSTACK-4
#endif // NXP_M0_008kRam

.equ DBAUDADDR, DBAUD
.equ UBAUDADDR, UBAUD
