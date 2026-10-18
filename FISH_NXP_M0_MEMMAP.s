 // FISH_NXP_M0_SYSTEM.s
 //------------------------------------------------------------------------------
 // FISH FORTH for the NXP ARM Cortex M0 series SystemsOnaChip (SoC).
 // Tested: NXP UM11049 board and NXP LPC1114FD/102 chip with 32kFlash and 4kRam.
 //      RESERVE SPACE FOR FISH SYSTEM VARS AND BUFFERS IN .bss

.section FISH_Ram_MemMap, "aw", %nobits
 // RAM_START and RAM_END defined in FISH_M0_EQUATES.H
SYSCLOCK: .space (4 * (1))
FPA: .space (4 * (1))
FPC: .space (4 * (1))
FPSV: .space (4 * (1))
 // The above 4 words are the SIGNATURE for saved code in a flash pages.
 // The FISH Dictionary starts 0x10 bytes after RBASE (RAMstart)

DICTSPACE_START:
#ifdef NXP_M0_004kRam
ORIG: .space (1 * (2600))
DICTSPACE_END: // For DICTSPACE calculation
#endif
#ifdef NXP_M0_008kRam
ORIG: .space (1 * (4000))
DICTSPACE_END: // For DICTSPACE calculation
#endif

PAD: .space (1 * (IOBUFSIZE))
TIB: .space (1 * (IOBUFSIZE))
FLOW_STATE: .space 1 // 0 = none sent yet, else XON_CHAR/XOFF_CHAR
STICKER: .space (4 * (1))

RAMVARSPACE_START:
RAMVARSPACE: .space (1 * (24*4))
 // For VARSPACE calculation
.balign 4
 // REARRANGE LATER FOR TASKING AND SIZE BASED OFFSETS!!
 // ZERO
END_RAMVARSPACE_SV_START:
 // BYTE VALUES
NBASE: .space (4 * (1))
IN: .space (4 * (1))
OUT: .space (4 * (1))
CSTATE: .space (4 * (1))
 // ADDRESS VALUES
INITSO: .space (4 * (1))
INITRO: .space (4 * (1))
INITTIB: .space (4 * (1))
UP: .space (4 * (1))
DP: .space (4 * (1))
CSDP: .space (4 * (1))
FENCE: .space (4 * (1))
CURRENT: .space (4 * (1))
PROMPT: .space (4 * (1))
ERROR_HALT: .space (4 * (1))
 // THESE ARE INITIALIZED WHEN USED AT RUN-TIME
CSP: .space (4 * (1))
NDPL: .space (4 * (1))
NHLD: .space (4 * (1))
 // BUFFERS
 // 0x1FFF1FF1      // Call Address of IAP routine
FLASHCMD: .space (4 * (4*5))
FLASHRET: .space (4 * (4*4))
I2CCMD: .space (4 * (1))
I2CROLE: .space (4 * (1))
I2CSTATE: .space (4 * (1))
I2CBUFFER: .space (1 * (12))
SV_END:
 // BE CAREFUL: Uninitialized RAM is between CSTACK$$Limit and END_RAMVARSPACE-4

