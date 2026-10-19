.syntax unified
.cpu cortex-m0plus
.thumb
// FISH_NXP_M0_GNU.s - FULL WORD
#include "FISH_NXP_M0_MAIN_INCLUDES.h"
//------------------------------------------------------------------------------

// 2DO: Add VIO_UARTX, VIO_KEY, VIO_?KEY and VIO_EMIT
// (EMIT), (KEY?), and (KEY).

// v1.7:

// #define EOL_DLE // DLE 0x10/16d in QUIT>CR after last word interpreted.
// #define EOL_NAK // NAK 0x15/21d in error messages for STDLED editor highlight
// The EOL_NAK makes SPACE NAK end of string in FISH_RM_MSGS.h

// Signon updated. (FOR TEST - FIX B4 SHIP)
// 2DO: Updated .hex .out and sym.bat

// Split out files to FISH_RM_COMMON and FISH_RM_COMMON_CODE_CORTEX_M

// ADDED EHON and EHOFF to FISH RM
// Changes iar.s COLD, ERROR and ABORT
// Changes FISH_STM32F4_SLIB.s SV_INIT_VALUES: & FWARM:
// Adds 1 word to FISH_STM32F4_MEMMAP.s - ERROR_HALT: SV

// ADDED P(PROMPT), PON(PROMPTON) and POFF(PROMPTOFF) to FISH RM
// Changes FISH_NXP_M0_SLIB.s SV_INIT_VALUES: & FWARM: & QUIT:
// Adds 1 word to FISH_NXP_M0_SYSTEM.s - PROMPT: SV

// Added #define TRUE_EQU_NEG_ONE
// Changed all user visible true flags to -1

// Added SXTB Rd, Rm  and SXTH Rd, Rm

// Number Stuff Wordcat reorganized (search NOEXEC or WC_NUMBERS_NFA)
// EXPECT does counted null strings:
// NUMBER to look for null terminatiion instead of BLANK.
// WORD changed to expect null string and elimated BLANKS fill of HERE.
//      SPEEDS UP TOKENIZATION OF TIB INPUT!
// ALL IN AND IN_SV INIT SET TO 1 in QUERY SV_INIT_VALUES CLRTIB
// NUMBERSUFFIX changed to replace suffix with null
// PAREN ( changed to use TIB+1
// DPL restored to dictionairy.
// FISH DATE AND TIMESTAMP removed from SRM to allow for DPL

// FISH ARM V1.6:
// Added LPC1115 64X8 Configuration.
// Added any key escape from DUMP

// FISH ARM DebugSrc V1.5.4:
// CONTSANT, VARIABLE and EXECUTE fit in SRM.

// FISH ARM DebugSrc V1.5.3:
// CREATE for DOES>
// IRQS_SUSPEND/RESUME for FLASH_SAVE and FLASH_FORGET
// BASE in prompt restored.

// FISH ARM DebugSrc V1.5.2:
// FIXED FLASH_SAVE/SCAN STACK LEAVINGS
//
//
//------------------------------------------------------------------------------
// START OF SIGNON MESSAGE
.section .text, "ax", %progbits
msg_FISH:
// DC8 "?" IS A NULL TERMINATED STRING
// DC8 '?' IS NOT
//     DC8     'FISH ARM'
    .ascii "FISH ARM Hi-Level ISR Test!!!"
//------------------------------------------------------------------------------
// CHIP FLASH and RAM DESIGNATION
#ifdef  NXP_M0_812
    .ascii " LPC812 16x4"
#endif
#if     NXP_M0_11xx & NXP_M0_004kRam
    .ascii " LPC111x 32x4 "
#endif
#if     NXP_M0_11xx & NXP_M0_008kRam
    .ascii " LPC111x 32x8 "
#endif
#if     NXP_M0_1115 & NXP_M0_008kRam & NXP_M0_064kFlash_4KWrite
    .ascii " LPC1115 64x8 "
#endif
//------------------------------------------------------------------------------
// FISH MODEL
//     DC8     'RM DebugSrc V1.6.1 : '

#if FISH_PubRel_WORDSET
    .ascii "RM "
#endif
#if     FISH_NXP_M0_PRO_WORDCAT
    .ascii "RM Pro "
#endif
#if     SRM
    .ascii "SRM "
#endif
#if FISH_Debug_WORDSET
    .ascii "FISH debug NOT RELEASED"
#endif
//------------------------------------------------------------------------------
// FISH Version
    .ascii "V1.8"
//------------------------------------------------------------------------------
// FISH COPYRIGHT AND TEAM
    .ascii " (C)2014-2026 A-TEAM FORTH : "
//------------------------------------------------------------------------------
#ifndef SRM
// FISH DATE AND TIMESTAMP
    .ascii __DATE__
msg_FISH_TIMESTAMP:
    .ascii " at "
    .ascii __TIME__
#endif
#ifdef EOL_DLE
msg_SIGNON_DLE:
    .byte 0x10
    .byte 0
#endif

// END OF SIGNON MESSAGE
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// FISH PROMPT
msg_MY_OK:
    .ascii " ok, go fish in BASE "
//------------------------------------------------------------------------------

//-----------------START OF DICTIONARY = Last word in search--------------------
//     NOOP NOOP:      ( -- )
.section .text, "ax", %progbits
NOOP_NFA:
    .byte 0x84
    .ascii "NOO"
    .byte 'P'+0x80
.balign 4, 255
    .word 0
NOOP:
//  mixed asm hi lvel test
    .word DOCOL
// This need to point to the +5?
    .word ASM_NOOP_1
ASM_NOOP_1:
    .word .+5
.section .text, "ax", %progbits
    NOP
    LDR i, =ASM_NOOP_2
    NEXT // or TPUSH or DPUSH

// fix alignment !
.section .text, "ax", %progbits
ASM_NOOP_2:
    .word SEMIS

/* Oroginal
        .word .+5
.section .text, "ax", %progbits
    NOP
        NEXT
*/

//     EXECUTE EXEC:   ( cfa -- ) RENAMED: EXECUTE to EXEC
//     Execute a single word whose cfa is on the stack

.section .text, "ax", %progbits
EXEC_NFA:
    .byte 0x87
    .ascii "EXECUT"
    .byte 'E'+0x80
.balign 4, 255
    .word NOOP_NFA
EXEC:
    .word .+5
.section .text, "ax", %progbits
#ifdef XON_XOFF
    BL TXRDY_SUBR
    BL XOFF_SUBR
#endif // XON_XOFF
    POPp2w // as in xeq token at ToS setup for exec LDM     p!, {w}
    NEXT1

// TXRDY_SUBR:
.section .text, "ax", %progbits
.thumb_func
TXRDY_SUBR:
    MOV w, lr // Allow for interrupts to use LR

#if NXP_M0_11xx | NXP_M0_1115
    LDR y, = U0LSR // Line Status Register
#endif

#ifdef NXP_M0_812
    LDR y, = UART0_STAT // 40064008h UART0 STAT Line Status Register
#endif

txRDY_Q:
    LDR n, [y]// Get Line Status
//------------------------------------------------------------------------------
#if             NXP_M0_11xx | NXP_M0_1115
    LSRS n, n, #6 // 7 = TX BUF EMPTY 6 = TX HOLD REG EMPTY
#endif
#ifdef NXP_M0_812
    LSRS n, n, #3 // 3 = TX BUF RDY
#endif
//------------------------------------------------------------------------------
    BCC txRDY_Q // Ready
    BX w //lr              // SUBR RETURN

// XOFF_SUBR:
    /*
     Note this drops the TXRDY wait on the skip path — that alone removes ~1 char-time per EXEC during compiles. Keep the TXRDY BL at call sites that need it, or move it inside after the state check.
    ## Why this shape
    - **Transition-only emission**: EXEC's per-word XOFF becomes a 3-instruction no-op while gated; EXPECT's XON fires once per line, exactly when the host was stopped. You keep the belt-and-braces call sites but pay for them only on transitions.
    - **Init to 0** (`.space` zero-fills): the first XON at boot is a real transition, so it always goes out — no special cold-start case.
    - **No races**: the system is fully polled, no RX/TX IRQs, so no atomicity concerns. If you ever add the RX DMA + high-water XOFF from an interrupt, this byte must move to a `__IO` (volatile) location and the ISR must own XOFF while the foreground owns XON.
    - **Self-healing option**: if you ever worry the host missed a byte (glitchy USB-serial bridge), add a cheap re-send policy — e.g. re-send XOFF every Nth EXEC — rather than every time.
    ## Integration with the other findings
    - **FSAVE fix**: the NXP `.word XON` under "Stop Downloads" becomes `.word XOFF`; with state, the matching `.word XON` at the end of FSAVE is safe and only emits if actually gated.
    - **TIB-full XOFF**: the count-exhausted EXPECT exit calls XOFF the same way — state makes it free when the line already ended with CR.
    - **?KEY spam**: QKEY's XON collapses to transitions; `BEGIN ?KEY UNTIL` stops streaming 0x11s.
    - One caveat to document: with dedup, a user typing `XOFF` manually then `XON` still works (both are transitions), but a user word that needs a *guaranteed* re-send should write `0` to FLOW_STATE first — worth one line in the port README.
    */
#ifdef XON_XOFF
.section .text, "ax", %progbits
.thumb_func
XOFF_SUBR:
    MOV w, lr // Allow for interrupts to use LR
//------------------------------------------------------------------------------
    LDR y, = XOFF_CHAR
    LDR x, = FLOW_STATE
    LDRB n, [x]// n = last byte sent (scratch)
    CMP n, y
    BEQ XOFF_DONE           // already gated — skip the TXE wait + transmit
    STRB y, [x]             // record transition
// load TXDAT after state check: LDRB above clobbers n
//------------------------------------------------------------------------------
#if     NXP_M0_11xx | NXP_M0_1115
    LDR n, = U0RBRTHR
#endif
#ifdef NXP_M0_812
    LDR n, = USART0_TXDAT // 4006401Ch TXDAT USART0
#endif
//------------------------------------------------------------------------------
    STRB y, [n]
XOFF_DONE:
    BX w //lr              // SUBR RETURN
#endif // XON_XOFF

// XON_SUBR:
#ifdef XON_XOFF
.section .text, "ax", %progbits
.thumb_func
XON_SUBR:
    MOV w, lr // Allow for interrupts to use LR
//------------------------------------------------------------------------------
// XON:
    LDR y, = XON_CHAR // preserve TOS 11 24 01 49
    LDR x, = FLOW_STATE
    LDRB n, [x]// n = last byte sent (scratch)
    CMP n, y
    BEQ XON_DONE // already gated — skip the TXE wait + transmit
    STRB y, [x]// record transition
// load TXDAT after state check: LDRB above clobbers n
//------------------------------------------------------------------------------
#if NXP_M0_11xx | NXP_M0_1115
    LDR n, = U0RBRTHR
#endif
#ifdef NXP_M0_812
    LDR n, = USART0_TXDAT // 4006401Ch TXDAT USART0
#endif
//------------------------------------------------------------------------------
    STRB y, [n]// send XON
XON_DONE:
    BX w //lr
#endif // XON_XOFF
.ltorg

//     BL BLANK:       ( -- n )
//     Push ascii space character as n to TOS.

.section .text, "ax", %progbits
BLANK_NFA:
    .byte 0x82
    .ascii "B"
    .byte 'L'+0x80
.balign 4, 255
    .word EXEC_NFA
BLANK:
    .word DOCOL
//        DC32    NOOP
    .word ASM_ENTRY_1
ASM_ENTRY_1:
    .word .+5
.section .text, "ax", %progbits
    LDR i, =ASM_EXIT_1
    LDR t, =0x20
    TPUSH
// fix alignment !
.section .text, "ax", %progbits
ASM_EXIT_1:
    .word SEMIS

//        DC32    DOCON, 0x20

//========================= START SYSTEM VARIABLES ===========================//
// _SV IS cfa label of WORD's that return their address.
// MODIFIED ALL to be label based vs. offset based.

//     UP UP_SV:       ( -- addr of UP ) Value stored here is ALIGNED
//     A system variable, the RAM VAR pointer, which contains
//      the address of the next free memory above in the USERRAMSPACE.
//      The value may be read by .UV and altered by VAR.

.section .text, "ax", %progbits
UP_NFA:
    .byte 0x82
    .ascii "U"
    .byte 'P'+0x80
.balign 4, 255
    .word BLANK_NFA
UP_SV:
    .word DOCON, UP

//     FENCE FENCE_SV: ( -- addr of FENCE )
//     A system variable containing an address below which FORGET ting is
//     trapped. To forget below this point the system must alter the contents
//     of FENCE.

.section .text, "ax", %progbits
FENCE_NFA:
    .byte 0x85
    .ascii "FENC"
    .byte 'E'+0x80
.balign 4, 255
    .word UP_NFA
FENCE_SV:
    .word DOCON, FENCE

//     DP DP_SV:       ( -- addr of DP ) Value stored here is ALIGNED
//     A system variable, the dictionary pointer, which contains the address
//     of the next free memory above the dictionary. The value may be read
//     by HERE and altered by COMMA (ALIGNED) , ALLOT and CALLOT (UNALIGNED) .

.section .text, "ax", %progbits
DP_NFA:
    .byte 0x82
    .ascii "D"
    .byte 'P'+0x80
.balign 4, 255
    .word FENCE_NFA
DP_SV:
    .word DOCON, DP

//     BASE BASE_SV:   ( -- addr of NBASE )
//      A system variable containing the current number base used for input
//      and output conversion.

.section .text, "ax", %progbits
BASE_NFA:
    .byte 0x84
    .ascii "BAS"
    .byte 'E'+0x80
.balign 4, 255
    .word DP_NFA
BASE_SV:
    .word DOCON, NBASE

//     CURRENT CURRENT_SV:     ( -- addr of CURRENT )
//     CURRENT searched everytime. CONTEXT is not used
//     Used by Create, Definitions, etc and by Latest
//      to leave the nfa of the topmost word in the CURRENT
//      vocabulary.  See LATEST NOTE:(FIG) CURR @ @ this CURR @

.section .text, "ax", %progbits
CURRENT_NFA:
    .byte 0x87
    .ascii "CURREN"
    .byte 'T'+0x80
.balign 4, 255
    .word BASE_NFA
CURRENT_SV:
    .word DOCON, CURRENT

//     STATE STATE_SV: ( -- addr of CSTATE )
//     A system variable containing the compilation state. A non-zero value
//     indicates compilation. The value itself may be implementation
//     dependent. 0xC0 must be used for INTERPRET to execute IMMEDIATE words.

.section .text, "ax", %progbits
STATE_NFA:
    .byte 0x85
    .ascii "STAT"
    .byte 'E'+0x80
.balign 4, 255
    .word CURRENT_NFA
STATE_SV:
    .word DOCON, CSTATE

//     OUT OUT_SV:     ( --  addr of OUT )
//      A system variable that contains a value incremented by EMIT. The system
//      may alter and examine OUT to control display formating.

.section .text, "ax", %progbits
OUT_NFA:
    .byte 0x83
    .ascii "OU"
    .byte 'T'+0x80
.balign 4, 255
    .word STATE_NFA
OUT_SV:
    .word DOCON, OUT

//     IN IN_SV:       ( -- addr of IN )
//     A system variable containing the byte offset within (TIB),
//      from which the tokens are parsed by WORD and moved to HERE,
//      as a counted null terminated string (created by EXPECT).
//      Initialized to 1 to skip count byte produced by EXPECT.

.section .text, "ax", %progbits
IN_NFA:
    .byte 0x82
    .ascii "I"
    .byte 'N'+0x80
.balign 4, 255
    .word OUT_NFA
IN_SV:
    .word DOCON, IN

//     PAD PAD_SV:     ( -- addr of PAD )
//      Leave the address of the text output buffer PAD on the stack.
//     Typically at least 82 bytes long.

.section .text, "ax", %progbits
PAD_NFA:
    .byte 0x83
    .ascii "PA"
    .byte 'D'+0x80
.balign 4, 255
    .word IN_NFA
PAD_SV:
    .word DOCON, PAD

//     TIB TIB_SV:     ( -- addr of INITTIB )
//      Leave the address of the text input buffer TIB on the stack.
//     Typically at least 82 bytes long.

.section .text, "ax", %progbits
TIB_NFA:
    .byte 0x83
    .ascii "TI"
    .byte 'B'+0x80
.balign 4, 255
    .word PAD_NFA
TIB_SV:
    .word DOCON, TIB

//======================== END SYSTEM VARIABLES ==============================//

//     HERE HERE:      ( -- addr ) Value stored here is ALIGNED
//      Leave the address of the next available dictionary location.

.section .text, "ax", %progbits
HERE_NFA:
    .byte 0x84
    .ascii "HER"
    .byte 'E'+0x80
.balign 4, 255
    .word TIB_NFA
HERE:
    .word DOCOL
    .word DP_SV
    .word AT
    .word SEMIS

//     ALLOT ALLOT:    ( sn -- ) Warning: UNALIGNED:
//     IF DICTIONAIRY FULL PRINT error MESSAGE AND abort.
//     Add the signed number to the dictionary pointer DP. May be used to
//     reserve dictionary space or re-origin memory.
//     CAUTION!
//     ALLOT and C, (CCOMMA:) ARE THE ONLY WORDS THAT CAN ALLOT UNEVEN AMOUNTS
//     NOTE: USE ALIGN32_FF_PAD after ALLOT or C, (CCOMMA) .

.section .text, "ax", %progbits
ALLOT_NFA:
    .byte 0x85
    .ascii "ALLO"
    .byte 'T'+0x80
.balign 4, 255
    .word HERE_NFA
ALLOT:
    .word DOCOL
    .word DICTSPACE
    .word OVER, SUBB
    .word ZLESS
    .word ZBRAN
    .word ALLOTOK-.

    .word DICTFULL_ABORT

ALLOTOK:
    .word DP_SV
    .word PSTORE
    .word SEMIS

//     ALIGNED ALIGNED:        ( addr -- a-addr ) DPANS94

.section .text, "ax", %progbits
ALIGNED_NFA:
    .byte 0x87
    .ascii "ALIGNE"
    .byte 'D'+0x80
.balign 4, 255
    .word ALLOT_NFA
ALIGNED:
    .word .+5
.section .text, "ax", %progbits
    POP2t
    ADDS t, t, #3
    LDR n, =-4
    ANDS t, t, n
    TPUSH
.ltorg

//     ALIGN32_FF_PAD ALIGN:   ( -- ) DPANS94
//     Align DP_SV primitive. Pads current DP with 0xFF until aligned.
//     USED in , (COMMA:) .  Reflected by HERE .
//     CAUTION! USE AFTER ALLOT or C, (CCOMMA:) .
//     See , (COMMA:) which is ALIGNED.

.section .text, "ax", %progbits
ALIGN_NFA:
    .byte 0x85
    .ascii "ALIG"
    .byte 'N'+0x80
.balign 4, 255
    .word ALIGNED_NFA
ALIGN32_FF_PAD:
    .word DOCOL
    .word HERE
// COULD ADD CODE TO SEE IF ALIGNED ALREADY
    .word THREE, PLUS
    .word DUP, TOR
    .word HERE
    .word XDO
ALIGN_PAD_DO:
    .word LIT, 0xFF, I, CSTORE
    .word XLOOP
    .word ALIGN_PAD_DO-.

    .word RFROM
    .word LIT, 0xFFFFFFFC
    .word ANDD
    .word DP_SV, STORE
    .word SEMIS

//     , COMMA:        ( n -- ) ALIGNED
//     IF DICTIONAIRY FULL PRINT Error MESSAGE AND Abort.
//     Write n into next ALIGNED dictionary memory cell, DP reflected by HERE

.section .text, "ax", %progbits
COMMA_NFA:
    .byte 0x81
    .byte ','+0x80
.balign 4, 255
    .word ALIGN_NFA
COMMA:
    .word DOCOL
    .word DICTSPACE
    .word ZLESS
    .word ZBRAN
    .word COMMA_OK-.

    .word DICTFULL_ABORT

COMMA_OK:
    .word COMMA_PRIM
    .word SEMIS

//     C, CCOMMA:      ( n -- ) Warning: UNALIGNED:
//     IF DICTIONAIRY FULL PRINT Error MESSAGE AND Abort.
//     Store LS 8 bits of n into the next available dictionary byte, advancing
//     the dictionary pointer.
//     CAUTION!
//     ALLOT and C, (CCOMMA:) ARE THE ONLY WORDS THAT CAN ALLOT UNEVEN AMOUNTS
//     NOTE: USE ALIGN32_FF_PAD after ALLOT or C, (CCOMMA) .
//     See , (COMMA:) which is ALIGNED.

.section .text, "ax", %progbits
CCOMMA_NFA:
    .byte 0x82
    .ascii "C"
    .byte ','+0x80
.balign 4, 255
    .word COMMA_NFA
CCOMMA:
    .word DOCOL
    .word DICTSPACE
    .word ZLESS
    .word ZBRAN
    .word CCOMMA_OK-.

    .word DICTFULL_ABORT

CCOMMA_OK:
    .word HERE
    .word CSTORE
    .word ONE
    .word ALLOT_PRIM
    .word SEMIS

//     VARALLOT VARALLOT:      ( n -- addr ) Value stored here is ALIGNED
//     IF USERVAR SPACE FULL PRINT Error MESSAGE AND Abort.
//     Add n * 32 bits to the RAMVARSPACE pointer UP.
//     Used to allocate space in Ram for VAR's and other system data structures

.section .text, "ax", %progbits
VARALLOT_NFA:
    .byte 0x88
    .ascii "VARALLO"
    .byte 'T'+0x80
.balign 4, 255
    .word CCOMMA_NFA
VARALLOT:
    .word DOCOL
    .word VARSPACE
    .word FOUR, SLASH, OVER, SUBB
    .word ZLESS
    .word ZBRAN
    .word VALLOT_OK-.

    .word LIT, msg_uvfull
    .word NULLSTRLEN, TYPE
#ifdef IO2TP
    .word NOOP
    .word CLRPAD
#endif
    .word ABORT

VALLOT_OK:
    .word UP_SV, AT
    .word SWAP
    .word FOUR, STAR
    .word UP_SV
    .word PSTORE
    .word SEMIS

//     LATEST LATEST: ( -- nfa )
//     Initially ADDR OF LAST WORD in THE DICTIONARY
//      Leave the nfa of the topmost word in the dictionary.

.section .text, "ax", %progbits
LATEST_NFA:
    .byte 0x86
    .ascii "LATES"
    .byte 'T'+0x80
.balign 4, 255
    .word VARALLOT_NFA
LATEST:
    .word DOCOL
    .word CURRENT_SV
    .word AT
    .word SEMIS

//     LFA LFA:        ( pfa -- lfa )
//      Convert the parameter field address of a dictionary definition to
//      its link field address.

.section .text, "ax", %progbits
LFA_NFA:
    .byte 0x83
    .ascii "LF"
    .byte 'A'+0x80
.balign 4, 255
    .word LATEST_NFA
LFA:
    .word .+5
.section .text, "ax", %progbits
    POP2t
    SUBS t, t, #8
    TPUSH

//     CFA CFA:        ( pfa -- cfa )
//      Convert the parameter field address of a dictionary definition to
//      its code field address. <if thumb2 execution addr smudged>

.section .text, "ax", %progbits
CFA_NFA:
    .byte 0x83
    .ascii "CF"
    .byte 'A'+0x80
.balign 4, 255
    .word LFA_NFA
CFA:
    .word .+5
.section .text, "ax", %progbits
    POP2t
    SUBS t, t, #4
    TPUSH

//     NFA NFA:        ( pfa -- nfa )
//      Convert the parameter field address of a definition to its name
//      field. Modified for nfa alighnment padding

.section .text, "ax", %progbits
NFA_NFA:
    .byte 0x83
    .ascii "NF"
    .byte 'A'+0x80
.balign 4, 255
    .word CFA_NFA
NFA:
    .word DOCOL
    .word EIGHT, SUBB

NFA_ALIGN_BEGIN:
    .word ONEM
    .word DUP, CAT
    .word LIT, 0xFF, SUBB
    .word ZBRAN
    .word NFA_ALIGN_BEGIN-.

    .word LIT, -1
    .word TRAVERSE
    .word SEMIS

//     PFA PFA:        ( nfa -- pfa )
//      Convert the name field address of a compiled definition to its
//      parameter field address.

.section .text, "ax", %progbits
PFA_NFA:
    .byte 0x83
    .ascii "PF"
    .byte 'A'+0x80
.balign 4, 255
    .word NFA_NFA
PFA:
    .word DOCOL
    .word ONE
    .word TRAVERSE

PFA_ALIGN_BEGIN:
    .word ONEP
    .word DUP, CAT
    .word LIT, 0xFF, SUBB
    .word ZBRAN
    .word PFA_ALIGN_BEGIN-.

    .word EIGHT
    .word PLUS
    .word SEMIS

//     ?ALIGNED QALIGNED: ( value -- )
//     If value not aligned by 4 issue message and ABORT.

.section .text, "ax", %progbits
QALIGNED_NFA:
    .byte 0x88
    .ascii "?ALIGNE"
    .byte 'D'+0x80
.balign 4, 255
    .word PFA_NFA
QALIGNED:
    .word DOCOL
    .word LIT, 3, ANDD
    .word ZBRAN
    .word QALIGN_OK-.

    .word PDOTQ
    .byte 46
    .ascii "VALUE MUST BE EVEN NOT ODD AND MULTIPLE OF 4! "
.balign 4, 255
    .word ABORT

QALIGN_OK:
    .word SEMIS

//     ?ERROR QERROR: ( f nullstr -- )
//     If f NON ZERO type error message (nullstr) and ABORT.

.section .text, "ax", %progbits
QERROR_NFA:
    .byte 0x86
    .ascii "?ERRO"
    .byte 'R'+0x80
.balign 4, 255
    .word QALIGNED_NFA
QERROR:
    .word DOCOL
    .word SWAP
    .word ZBRAN
    .word QERROR_FINISH-.

    .word ERROR
    .word BRAN
    .word QERROR_DONE-.

QERROR_FINISH:
    .word DROP

QERROR_DONE:
    .word SEMIS

//     DIGIT DIGIT:    ( c base -- digit 1 ) (ok)
//                     ( c base -- 0 (bad)
//     Converts the ascii character c using base to its binary
//     equivalent digit, accompanied by a true flag. If the conversion is
//     invalid, leaves only a false flag.

.section .text, "ax", %progbits
DIGIT_NFA:
    .byte 0x85
    .ascii "DIGI"
    .byte 'T'+0x80
.balign 4, 255
    .word QERROR_NFA
DIGIT:
    .word .+5
.section .text, "ax", %progbits
    POP2w     // Number base
    POP2t     // ASCII DIGIT
    SUBS t, t, #'0'
    BMI DIGI2 // Number error

    CMP t, #9
    BLE DIGI1 // Number = 0 THRU 9

// Combine?
    SUBS t, t, #7
    CMP t, #10 // Number 'A' THRU 'Z'?
    BLT DIGI2 // NO

.thumb_func
DIGI1:
    CMP t, w // COMPARE Number TO base
    BGE DIGI2

    MOV w, t // NEW BINARY Number
    MOVS t, #1 // TRUE FLAG
    DPUSH

// Number error
.thumb_func
DIGI2:
    MOVS t, #0 // FALSE FLAG
    TPUSH

//     ENCLOSE ENCL:   ( addr1 c -- addr1 n1 n2 n3 )
//     A text scanning iterative primitive used only in WORD.
//     IN is used before and after callS for the iteration
//     Typically TIB + IN = addr1
//      noop EX//( TIB   32 -- TIB   0 4 5 )
//      NULL EX//( TIB   32 -- ADDR-B4-NULL 0 1 1 ) So DFIND CAN FIND IT!
//      NULL EX//  WORD/ENCL -> TIB 1, 0, 20'S
//      From the text address addr1 and an ascii delimiting character c,
//      is determined the byte offset to the first non-delimiter character n1,
//      the offset to the first delimiter after the text n2,
//      and the offset to the first character not included.
//      This procedure will not process past an ASCII 'null', treating it
//      as an unconditional delimiter. NULL termination by EXPECT in QUERY.

.section .text, "ax", %progbits
ENCL_NFA:
    .byte 0x87
    .ascii "ENCLOS"
    .byte 'E'+0x80
.balign 4, 255
    .word DIGIT_NFA
ENCL:
    .word .+5
.section .text, "ax", %progbits
    POP2t // TERMINATOR CHAR
    LDR n, [p]// get text address but leave on stack
    MOVS w, #0
    SUBS w, w, #1        // CHAR  COUNTER
    SUBS n, n, #1        // ADDR -1

//  SCAN TO FIRST NON-TERMINATOR CHARACTER
//     and PUSH count to stack leaving last 2 params to compute
.thumb_func
ENCL1:
    ADDS n, n, #1        // ADDR+1
    ADDS w, w, #1        // COUNT+1
    LDRB x, [n]
    CMP t, x //CMP      AL,[BX]
    BEQ ENCL1 //JZ      ENCL1   // WAIT FOR NON-TERMINATOR
    PUSHw //offset to the first non-delimiter character
//EXiT is now only DPUSH
    CMP x, #0         //CMP     AH,[BX] // null CHAR?
    BNE ENCL2         //JNZ     ENCL2   // NO

// FOUND null BEFORE 1ST NON-TERM CHAR
// RETURN ok args = NULL EX//
// ( TIB   32 -- ADDR-B4-NULL 0 1 1 ) So DFIND CAN FIND IT!
//
    MOV t, x
    ADDS w, w, #1 // w = offset to the delimiter after the text
    DPUSH

//   FOUND FIRST TEXT CHAR - COUNT THE CHARS
.thumb_func
ENCL2:
    ADDS n, n, #1        // ADDR+1
    ADDS w, w, #1        //COUNT+1
    LDRB x, [n]
    CMP t, x //TERMINATOR CHAR?
    BEQ ENCL4 //YES

    CMP x, #0         //null CHAR?
    BNE ENCL2         //NO, LOOP AGAIN

.thumb_func
ENCL3: //   FOUND null AT END OF TEXT
.thumb_func
ENCL4: //   FOUND TERMINATOR CHARACTER
    MOV t, w // COUNT+1 =
    ADDS t, t, #1 // offset to the first character not included
    DPUSH

//     0 NULL: ( -- ) IMMEDIATE
//     Don't return to Interpret, return to Quit at end of a line of input.
//      Executed at end of TIB when QUERY lenght or CR entered.

.section .text, "ax", %progbits
NULL_NFA:
    .byte 0x0C1
    .byte 0x80
.balign 4, 255
    .word ENCL_NFA
NULL:
//     DC32    SEMIS                   // Actual Semis code below
    .word .+5
.section .text, "ax", %progbits
    POPr2i // pop docol saved IP from Rstack
    NEXT

//     WORD WORD:      ( c -- )
//     Parse the text in TIB , until a delimiter c is found, tokenizing input.
//     Move the token to HERE, with a count byte and 2 nulls at the end.
//     Leading occurrences of c are ignored. IN is incremented.
//      IN is initialized by FISH to 1 to account for the count byte in EXPECT.
//     See IN. Usually used inside a definition.

.section .text, "ax", %progbits
WORD_NFA:
    .byte 0x84
    .ascii "WOR"
    .byte 'D'+0x80
.balign 4, 255
    .word NULL_NFA
WORD:
    .word DOCOL
WORD1:
//      This is required for number suffix's at least ???
//     DC32    HERE, LIT, MAXWORDLEN+2, BLANKS
    .word TIB_SV
WORD2:
    .word IN_SV
    .word AT
    .word PLUS
    .word SWAP
    .word ENCL
WENCL:
    .word IN_SV
    .word PSTORE
    .word OVER
    .word SUBB
    .word TOR
    .word R
    .word HERE
    .word CSTORE
    .word PLUS
    .word HERE
    .word ONEP
//     DC32    RFROM
// MOVE word TO DICT FOR finding ENDING WITH NULLS
    .word R
    .word CMOVE
// add null to end of token - NUMBER adjusted
    .word ZERO, HERE, ONEP, RFROM, PLUS, CSTORE
#ifdef  IOBUFS_DEBUG
    .word HERE, ONE, DUMP
#endif
    .word SEMIS

//     NUMBER NUMBER:  ( addr -- sd )
//     If error print message and ABORT.
//      Convert a character string left at addr with a preceeding count,
//      and a terminating null, to a signed number, in the current numeric base.
//      If a decimal point is encountered in the text, its position will be
//      given in DPL, but no other effect occurs. If numeric conversion is
//      not possible, an error message will be given.

//      Added support for , as a single number formatter.

#define comma_test

.section .text, "ax", %progbits
NUMBER_NFA:
    .byte 0x86
    .ascii "NUMBE"
    .byte 'R'+0x80
.balign 4, 255
    .word WORD_NFA
NUMBER:
    .word DOCOL
    .word BASE_TO_R12
    .word NUMBERSUFFIX

// SETUP: stack arguments for PNUMBER.
    .word ZERO, ZERO
    .word ROT

// SETUP: reeturn stack with sign flag
// NONAME CANDIDATE!
// START: Handle minus sign by saving status on Return Stack.
// and incrementing to addr after it.
    .word DUP, ONEP
    .word CAT
    .word LIT, '-'
    .word EQUAL
#ifdef TRUE_EQU_NEG_ONE // EQUAL returns -1 NEED 0 or 1 here!
    .word ONE, ANDD
#endif
    .word DUP, TOR
// END: Handle - by saving status on Return Stack.

// SETUP: addr pointing to 1rst digit.
// If minus sign, flag from above will increment to next char.
    .word PLUS

// So could be at 1rst OR 2nd character in string here!

// ENTER LOOP WITH -1 DPL = single number and sign flag on return stack.
    .word LIT, -1
// PNUMBER is used in loop to convert string segment until non-mumeric chracter.
// A period in the string manipulates DPL to create a double number.
// A comma in the string resets DPL to create a single number.
// A null indicates the end of the string.
NUMB1: // Begin
    .word DPL_SV, STORE

// PNUMBER converts one or more characters until first unconvertable digit.
// ud and addr in string is maintained while in loop.
    .word PNUMBER
// Perform check for period, comma and null.
// Any other character here invalidates this number conversion.

// Null Test: = end of string.
    .word DUP, CAT
    .word ZERO
    .word SUBB
    .word ZBRAN
    .word NUMB2-.

// Period Test: = increment DPL.
    .word DUP, CAT
    .word LIT, '.'
    .word SUBB
    .word ZBRAN
    .word DPL_ZERO_INCR-.

#ifdef  comma_test
// Comma Test: = reset DPL.
    .word DUP, CAT
    .word LIT, ','
    .word EQUAL
    .word ZBRAN
    .word BASE_RESET_THEN_ERROR-.

// Fall thru if comma so reset DPL to create a single number.
DPL_RESET:
    .word LIT, -1
    .word BRAN
    .word NUMB1-.
#endif

BASE_RESET_THEN_ERROR:
// GOING TO ERROR SO RESTORE BASE!
    .word BASE_FROM_R12
//NO_BASE_RESTORE:
    .word ONE
    .word LIT, msg_number_error
    .word QERROR

DPL_ZERO_INCR: // set DPL to zero
    .word ZERO
    .word BRAN
    .word NUMB1-.

NUMB2:
    .word DROP
    .word RFROM
// IF
    .word ZBRAN
    .word NUMB3-.

    .word DNEGATE

NUMB3: // endif
    .word BASE_FROM_R12
    .word SEMIS

//     ERROR ERROR:    ( nullstr --- )
//     Execute error notification and restart of system.

.section .text, "ax", %progbits
ERROR_NFA:
    .byte 0x85
    .ascii "ERRO"
    .byte 'R'+0x80
.balign 4, 255
//     DC32    DFIND_NFA
    .word NUMBER_NFA
ERROR:
    .word DOCOL
    .word HERE, COUNT, TYPE
    .word NULLSTRLEN, TYPE
#ifdef IO2TP
    .word NOOP
//        DC32    CLRPAD  // Resets OUT
#endif
#ifdef XON_XOFF
    .word XOFF
#endif

//      DO THIS WHERE STATE IS SET BACK TO ZERO
    .word STATE_SV, AT
    .word ZBRAN
    .word CREATED_OK-.

//      NON-ZERO CSDP = RESTORE DP TO forget DAMAGED WORDS
    .word CSDP_SV, AT
    .word ZBRAN
    .word CREATED_OK-.

// assume ITS A CREATE'd WORD!!!!
ERROR_FIXUP: // CSDP_SV contains NFA of definition that has error.
    .word CSDP_SV, AT
    .word PFA
    .word LFA, AT
    .word CURRENT_SV, STORE
// RESET DP!
    .word CSDP_SV, AT
    .word DP_SV, STORE

CREATED_OK:
    .word SEMIC_CREATE

BP1_ERROR:
#ifdef IO2TP
    .word NOOP
#endif
//     DC32    SPSTO   // DONE in QUIT
#ifdef ABORT_STOP_TILL_CO
    .word ABORT
#else
    .word QUIT
#endif

//     ' TICK: ( -- pfa ) IMMEDIATE
//     Used in the form: .
//     ' CCcc
//     Leaves the parameter field address of dictionary word CCcc.
//     If the word is not found after a search of CURRENT,
//     an appropriate error message is given.
//     As a compiler directive, executed in a colon-definition to compile
//      the address as a literal.
//     Pronounced "TICK".

.section .text, "ax", %progbits
TICK_NFA:
    .byte 0x0C1
    .byte 0x27+0x80
.balign 4, 255
    .word ERROR_NFA
TICK:
    .word DOCOL
    .word DFIND
    .word ZEQU
    .word LIT, msg_word_error
    .word QERROR
    .word DROP
    .word LITERAL
    .word SEMIS

//     EXPECT EXPECT:  ( addr count -- )
//     Transfer characters from the terminal to the buffer starting at addr+1,
//     until a "return" or the count of characters have been received.
//     One or two nulls are added at the end creating a null-terminated string.
//      A count byte is placed at addr, the count being derived by $LEN
//     Use COUNT with TYPE for strings saved this way.
//      Strings longer that 255 will have an invalid count byte. Use $LEN:
//      $LEN and TYPE can be used when the argument to $LEN is addr+1.

//      Comments below use TIB input (QUERY in INTERPRET) as an example.

.section .text, "ax", %progbits
EXPECT_NFA:
    .byte 0x86
    .ascii "EXPEC"
    .byte 'T'+0x80
.balign 4, 255
    .word TICK_NFA
EXPECT: // ( NOS TOS -- NOS TOS )
    .word DOCOL
    .word ONEP
    .word OVER
    .word PLUS
    .word OVER
    .word ONEP

///* FISH System compiled KEY does not issue XON - user version does!
#ifdef XON_XOFF
    .word XON
#endif
//*/

// ( ORGIGINAL-TIB TIB+LEN+1 TIB+1 -- ORGIGINAL-TIB )
//                (Index & Limit)+1 for count byte
    .word XDO
EXPE1:
    .word KEY
#ifdef XON_XOFF
    .word IF_EOL_SEND_XOFF
#endif
// goto main branch (EL1:)if not tab
    .word DUP, LIT, 9, EQUAL
    .word ZBRAN
    .word EL1-.

// REPLACE TAB WITH SPACE               // -- ch f
    .word DROP, BLANK
EL1:
// MAIN LOOP ENTERED WITH CHAR ON TOS
    .word DUP
// FALL THRU IF BACKSPACE OR DELETE KEY
    .word BACKSPACE_CHAR
    .word EQUAL
    .word OVER
    .word LIT, 0x07F
    .word EQUAL
    .word OR
// BRANCH IF NOT BACKSPACE OR DELETE KEY
    .word ZBRAN
    .word EXPE2-.

// CASE OF BACKSPACE/DELETE KEY
    .word DROP
    .word DUP
    .word I
// COMPENSATE FOR COUNT BYTE - BUMP ADDR+1 (NEXT CHAR LOCATION) BACK TO CURRENT
    .word ONEM
    .word EQUAL
    .word DUP
// I AND RFROM STARTS AT TIB+1
// REMOVE INDEX FROM LOOP TO REPLACE IT WITH BACKSPACE CORRECTED ADDRESS
    .word RFROM
// ADDING 2 BECAUSE TIB+1 IS FROM I AND FLAG MAKES IT = TO 1
// WHEN AT THE BEGIINING (ADDR+1) OF THE ADDR BUFFER
    .word TWO
    .word SUBB
// ADD FLAG
    .word PLUS
    .word TOR
    .word ZBRAN
    .word EXPE6-.

    .word BELL
    .word BRAN
    .word EXPE33-.

EXPE6: // Fix OUTPUT and TIB
// Getting 1rts BELL only - erased word being interpreted.
    .word BSOUT
    .word ZERO, I, ONEP, CSTORE
EXPE7: // LABEL NOT USED BECAUSE BELL AND BSOUT Emit THEMSELVES
    .word BRAN
    .word EXPE33-.

EXPE2:
    .word DUP
    .word LIT, 0x0D
    .word EQUAL
    .word ZBRAN
    .word EXPE4-.

    .word LEAVE
#ifdef  IOBUFS_DEBUG
    .word DOTSHEX
#endif
// CR DROPPED HERE I USED AT END FOR CASE OF EXPECT COUNT REACHED
    .word DROP
    .word BLANK
    .word ZERO
    .word BRAN
    .word EXPE5-.

EXPE4:
    .word DUP

EXPE5:
    .word I
    .word CSTORE
    .word ZERO
// CASE OF CR ( TOS> 0 20h TIB -- )
    .word I
    .word ONEP
    .word CSTORE
EXPE3:
// CASE OF CR ( TOS> 20H TIB -- )
    .word EMIT
EXPE33:
    .word XLOOP
    .word EXPE1-.

#ifdef XON_XOFF
    .word XOFF
#endif
// Create count byte
// ( ORIGINAL ADDR -- )
// ORIGINAL ADDR (TIB) ON STACK HERE SO CORRECT FOR $LEN
    .word ONEP
// NULLSTRLEN:          // ( addr -- addr len )
    .word NULLSTRLEN
    .word SWAP, ONEM
    .word CSTORE
    .word SEMIS

//     COUNT COUNT:    ( addr1 --- addr2 n )
//     Leave the byte address addr2 and byte count n of a count byte string,
//      beginning at address addr1. It is presumed that the first byte at
//      addr1 contains the text byte count and the actual text starts with
//      the second byte. NFA's may report SMUDGE'd byte counts, handled only
//      by ID. User Strings may be up to 255 characters.
//      Typically COUNT is followed by TYPE.
//      See TYPE $LEN and EXPECT

.section .text, "ax", %progbits
COUNT_NFA:
    .byte 0x85
    .ascii "COUN"
    .byte 'T'+0x80
.balign 4, 255
    .word EXPECT_NFA
COUNT:
    .word DOCOL
    .word DUP
    .word ONEP
    .word SWAP
//        DC32    CATLT7F
    .word CAT
    .word SEMIS

//     $LEN NULLSTRLEN:        ( addr - addr len )
//     Count length of null terminated string.
//     TYPE can be used after this word.

.section .text, "ax", %progbits
NULLSTRLEN_NFA:
    .byte 0x84
    .ascii "$LE"
    .byte 'N'+0x80
.balign 4, 255
    .word COUNT_NFA
NULLSTRLEN:
    .word .+5
.section .text, "ax", %progbits
    NDPOP2w // Get but leave addr on stack
    EORS t, t // zero count

.thumb_func
NSLEN_LOOP:
    LDRB n, [w, t]
    ORRS n, n
    BEQ NSLEN_DONE
    ADDS t, t, #1
    B NSLEN_LOOP

.thumb_func
NSLEN_DONE:
    TPUSH

//     FORGET FORGET:  ( -- )
//     PRINTS NEW HERE IF SUCCESSFUL. FIXED FIG VERSION MEMORY LEAK.
//     Executed in the form:
//     FORGET CCcc
//     Deletes definition named CCcc from the dictionary with all entries
//     physically following it. In fig-FORTH, an error message will occur
//     if the CURRENT and CONTEXT vocabularies are not currently the same.
//     MODIFIED: To update Current along with context and reset DP,
//     and execute .DS and .VS

.section .text, "ax", %progbits
FORGET_NFA:
    .byte 0x86
    .ascii "FORGE"
    .byte 'T'+0x80
.balign 4, 255
    .word NULLSTRLEN_NFA
FORGET:
    .word DOCOL
    .word TICK
    .word DUP
    .word LIT, FLASH_SPAGE
    .word LESSTHAN
    .word LIT, msg_forget_fish
    .word QERROR
    .word DUP
    .word LIT, FLASH_PPAGE
    .word LESSTHAN
    .word LIT, msg_forget_saved
    .word QERROR
//     MOVE NFA update of the DP to after Currrent and Context
    .word DUP
    .word LFA

// VAR space reclamation starts here:
// PFA LFA --
    .word TOR

VS_RECVR_LOOP:
    .word LATEST, PFA, LFA
    .word DUP, AT
    .word CURRENT_SV, STORE
    .word DUP, FOURP, AT
    .word LIT, DOVAR, EQUAL
    .word ZBRAN
    .word VS_RECVR_NEXT-.

    .word LIT, -4, UP_SV, PSTORE

VS_RECVR_NEXT:
    .word R, EQUAL
    .word ZBRAN
    .word VS_RECVR_LOOP-.

    .word RFROM
// VAR SPACE RECLAMATION DONE

// PFA LFA --
    .word AT
    .word CURRENT_SV
    .word STORE
    .word NFA
    .word DP_SV
    .word STORE
    .word DOTVARSPACE, DOTDICTSPACE
    .word SEMIS

//     BYE BYE: ( -- ) COLD RESTART WITH SERIAL INITIALIZATION

.section .text, "ax", %progbits
BYE_NFA:
    .byte 0x83
    .ascii "BY"
    .byte 'E'+0x80
.balign 4, 255
    .word FORGET_NFA
BYE:
    .word .+5
.section .text, "ax", %progbits
    BLX FM0_COLD // __iar_program_start
.ltorg

//     ABORT ABORT:    ( -- )
//     Clear the stacks, zero out and execute RUN or QUIT
//     DOES NOT RESET DICTIONAIRY. SEE COLD.

.section .text, "ax", %progbits
ABORT_NFA:
    .byte 0x85
    .ascii "ABOR"
    .byte 'T'+0x80
.balign 4, 255
    .word BYE_NFA
ABORT:
    .word DOCOL
    .word SPSTO
    .word RPSTO
#ifdef IO2TP
//     DC32    NOOP    // TEMP TEST IO2TP
    .word CLRTIB
    .word CLRPAD
#endif
    .word STRVA, 0, OUT
//     DC32    QSTACK  // IF STACK error abort using QERROR->ERROR

// LOOK UP RUN AND EXEC IT
    .word LIT, msg_RUN, LATEST
    .word PFIND
    .word ZBRAN
    .word ABORT_QUIT-.

    .word DROP
    .word CFA, EXEC

ABORT_QUIT:
//      DC32    SEMIC_CREATE // Use ERROR if need to recover from bad definition
#ifdef ABORT_STOP_TILL_CO
    .word LIT, ERROR_HALT, AT
    .word ZBRAN
    .word CO_END-.
// halt on all errors until "CO" entered
// BEGIN
    .word LIT, msg_CO, NULLSTRLEN, TYPE
NOT_CO:
    .word QKEY
    .word ZBRAN
    .word NOT_CO-.
// IF KEY = "C'
    .word KEY, LIT, 0x43, EQUAL
    .word ZBRAN
    .word NOT_CO-.
// NEXT KEY "0"
    .word KEY, LIT, 0x4F, EQUAL
    .word ZBRAN
    .word NOT_CO-.
// NEXT KEY "Enter"
    .word KEY, LIT, 0x0D, EQUAL
    .word ZBRAN
    .word NOT_CO-.
// UNTIL
    .word CR
CO_END:
#endif
    .word QUIT
#ifdef ABORT_STOP_TILL_CO
#include "FISH_CO_MSGS.h"
#endif
    .word QUIT

//     COLD COLD:      ( -- )  MODIFIED:
//     FIGISH SYSTEM COLD = WARM (INIT RAMVARSPACE) -> type signon MSG ->ABORT
//     CLEARS DICTIONAIRY. SEE ABORT.

.section .text, "ax", %progbits
COLD_NFA:
    .byte 0x84
    .ascii "COL"
    .byte 'D'+0x80
.balign 4, 255
    .word ABORT_NFA
COLD:
    .word DOCOL
    .word WARM
    .word SIGNON
//#ifdef ABORT_STOP_TILL_CO
//        DC32    QUIT
//#else
    .word ABORT
//#endif

//=============================== WORDCAT ====================================//
//NOEXEC HEADERFORWORDCATEGORIES
//     WC_FISH_SYS: = FISH System: CATEGORY

.section .text, "ax", %progbits
WC_FISH_SYS_NFA:
    .byte 0x80+4+12
    .byte 0x0D
    .byte 0x0A
    .ascii "FISH System:"
    .byte 0x0D
    .byte 0x0A+0x80
.balign 4, 255
    .word COLD_NFA

//----------------------------- DOTSTACK SECTION -------------------------------
//     .SH DOTSHEX:    ( -- )
//     Nondestructively print items on stack in HEX, preserving base.
//     Prints TOS 1rst, i.e. TOS, NOS, etc.

.section .text, "ax", %progbits
DOTSHEX_NFA:
    .byte 0x83
    .ascii ".S"
    .byte 'H'+0x80
.balign 4, 255
    .word WC_FISH_SYS_NFA
DOTSHEX:
    .word DOCOL
#ifdef SRM
    .word BASE_TO_R12, HEX, DOTS, BASE_FROM_R12
#else
    .word LIT, 16, DOTSBASE
#endif
    .word SEMIS

#ifndef SRM
//     .SD DOTSDEC:    ( -- )
//     Nondestructively print items on stack in DECIMAL, preserving base.
//     Prints TOS 1rst, i.e. TOS, NOS, etc.

.section .text, "ax", %progbits
DOTSDEC_NFA:
    .byte 0x83
    .ascii ".S"
    .byte 'D'+0x80
.balign 4, 255
    .word DOTSHEX_NFA
DOTSDEC:
    .word DOCOL
    .word LIT, 10, DOTSBASE
    .word SEMIS

//     .SB DOTSBIN:    ( -- )
//     Nondestructively print items on stack in BINARY, preserving base.
//     Prints TOS 1rst, i.e. TOS, NOS, etc.

.section .text, "ax", %progbits
DOTSBIN_NFA:
    .byte 0x83
    .ascii ".S"
    .byte 'B'+0x80
.balign 4, 255
    .word DOTSDEC_NFA
DOTSBIN:
    .word DOCOL
    .word TWO, DOTSBASE
    .word SEMIS
#endif // not SRM

//     .S DOTS:        ( -- )
//     Nondestructively print items on stack in current base.
//     Prints TOS 1rst, i.e. TOS, NOS, etc.

.section .text, "ax", %progbits
DOTS_NFA:
    .byte 0x82
    .ascii "."
    .byte 'S'+0x80
.balign 4, 255
#ifdef SRM
    .word DOTSHEX_NFA
#else
    .word DOTSBIN_NFA
#endif // SRM
DOTS:
    .word DOCOL
    .word INITSO_SV, AT, SPAT, FOURP
    .word EQUAL, ZEQU, ZBRAN
    .word DOTSEND-.

    .word PDOTQ
    .byte 5
    .ascii "TOS> "
.balign 4, 255

    .word INITSO_SV, AT, SPAT, FOURP
    .word XDO

DOTSLOOP:
    .word I, AT
    .word BASE_SV, AT
    .word LIT, 10, EQUAL
    .word ZBRAN
    .word DBSUSEDUDOT-.
#ifdef SRM
    .word DOT
#else
    .word DOT_BASE_SUFFIX
#endif // SRM
    .word BRAN
    .word DBSUSEDOT-.

DBSUSEDUDOT:
#ifdef SRM
    .word UDOT
#else
    .word UDOT_BASE_SUFFIX
#endif // SRM
DBSUSEDOT:
    .word SPACE
    .word FOUR, XPLOOP
    .word DOTSLOOP-.

DOTSEND:
    .word SEMIS

//     2DUP TDUP:      ( n2 n1 -- n2 n1 n2 n1 )
//     Duplicate top two stack items. The prefix 2 convention means
//      an operation on the top two stack items.

.section .text, "ax", %progbits
TDUP_NFA:
    .byte 0x84
    .ascii "2DU"
    .byte 'P'+0x80
.balign 4, 255
    .word DOTS_NFA
TDUP:
    .word .+5
.section .text, "ax", %progbits
// TDUP: OPT by picking pops
    LDR t, [p]//
    LDR w, [p, #4]//
    DPUSH //

//     -DUP ZNDUP:     ( n1 -- n1 (if zero)
//                      ( n1 -- n1 n1 (non-zero)
//     Reproduce n1 only if it is non-zero. Used in type andSPACES.
//      This is usually used to copy a value just before IF, to eliminate
//      the need for an ELSE part to drop it.

.section .text, "ax", %progbits
DDUP_NFA:
    .byte 0x84
    .ascii "-DU"
    .byte 'P'+0x80
.balign 4, 255
    .word TDUP_NFA
ZNDUP:
    .word DOCOL
    .word DUP
    .word ZBRAN
    .word DDUP1-.

    .word DUP
DDUP1:
    .word SEMIS

//     ROT ROT: ( nl n2 n3 --- n2 n3 nl )
//     Rotate the top three values on the stack, bringing the third to the top.

.section .text, "ax", %progbits
ROT_NFA:
    .byte 0x83
    .ascii "RO"
    .byte 'T'+0x80
.balign 4, 255
    .word DDUP_NFA
ROT:
    .word .+5
.section .text, "ax", %progbits
    POP2w
    POP2n
#ifdef TOSCT
    LDR t, [p]// get new TOS
#endif
    POP2t
    PUSHn
    DPUSH //  --  LSW MSW )

//     I I:    ( -- n )
//      Used within a DO-LOOP to copy the loop index to the stack. Other use
//      is implementation dependent.
//      See R.

.section .text, "ax", %progbits
I_NFA:
    .byte 0x81
    .byte 'I'+0x80
.balign 4, 255
    .word ROT_NFA
I:
    .word .+5
.section .text, "ax", %progbits
    LDR t, [r]// GET INDEX VALUE
    TPUSH

//     SP@ SPAT:       ( -- addr )
//     ( -- addr = Current TOP of the parameter stack (p) )
//      Place the address of the TOP of the parameter stack (p)
//     on the parameter stack (p) as it was before RP@ was executed.
//      e.g.  1  2  SP@  @  .   .   .     would type 2  2  1

.section .text, "ax", %progbits
SPAT_NFA:
    .byte 0x83
    .ascii "SP"
    .byte '@'+0x80
.balign 4, 255
    .word I_NFA
SPAT:
    .word .+5
.section .text, "ax", %progbits
    MOV t, p
    TPUSH

//     RP@ RPAT:       ( -- addr )
//     ( -- addr = Current TOP of the Return Stack (r) )
//      Place the address of the TOP of the return stack (r)
//     on the parameter stack (p) as it was before RP@ was executed.
//      e.g.  1 >R  2 >R  RP@  @  .   .   . would type 2  2  1

.section .text, "ax", %progbits
RPAT_NFA:
    .byte 0x83
    .ascii "RP"
    .byte '@'+0x80
.balign 4, 255
    .word SPAT_NFA
RPAT:
    .word .+5
.section .text, "ax", %progbits
    MOV t, r
    TPUSH

//     LEAVE LEAVE:    ( -- )
//      Force termination of a DO-LOOP at the next opportunity by setting
//      the loop limit equal to the current value of the index. The index
//      itself remains unchanged, and execution proceeds until LOOP
//      or +LOOP is encountered.

.section .text, "ax", %progbits
LEAVE_NFA:
    .byte 0x85
    .ascii "LEAV"
    .byte 'E'+0x80
.balign 4, 255
//     DC32    RPSTO_NFA
    .word RPAT_NFA
LEAVE:
    .word .+5
.section .text, "ax", %progbits
    LDR w, [r]// GET Index
    STR w, [r, #4]// Store it at Limit
    NEXT

//     R> RFROM:       ( -- n )                           L0
//      Remove the top value from the return stack and leave it on the
//      computation stack. See >R and R.

.section .text, "ax", %progbits
RFROM_NFA:
    .byte 0x82
    .ascii "R"
    .byte '>'+0x80
.balign 4, 255
    .word LEAVE_NFA
RFROM:
    .word .+5
.section .text, "ax", %progbits
    POPr2t
    TPUSH

//     R R:    ( -- n )
//     Copy the top of the return stack to the computation stack.

.section .text, "ax", %progbits
R_NFA:
    .byte 0x81
    .byte 'R'+0x80
.balign 4, 255
    .word RFROM_NFA
R:
    .word .+5
.section .text, "ax", %progbits
    LDR t, [r]// Get Index
    TPUSH

//     >R TOR: ( n -- )
//      Remove a number from the computation stack and place as the most
//      accessable on the return stack. Use should be balanced with R> in
//      the same definition.

.section .text, "ax", %progbits
TOR_NFA:
    .byte 0x82
    .ascii ">"
    .byte 'R'+0x80
.balign 4, 255
    .word R_NFA
TOR:
    .word .+5
.section .text, "ax", %progbits
    POP2n // preserve TOS
    PUSHn2r
#ifdef TOSCT
    LDR t, [p]
#endif
    NEXT

//     OVER OVER:      ( nl n2 -- nl n2 n1 )
//     Copy the second stack value, placing it as the new top.

.section .text, "ax", %progbits
OVER_NFA:
    .byte 0x84
    .ascii "OVE"
    .byte 'R'+0x80
.balign 4, 255
    .word TOR_NFA
OVER:
    .word .+5
.section .text, "ax", %progbits
    POP2w // n2
#ifdef TOSCT
// Get new t - This could become REFRESHt
    LDR t, [p]// t invalid so get it
    POP2t // do the increment
#else
    POP2t // n1
#endif
    PUSHt     // -- n1 )
    DPUSH     //  --  LSW MSW )

//     DROP DROP:      ( n1 -- )
//     Drop n1 from the stack.

.section .text, "ax", %progbits
DROP_NFA:
    .byte 0x84
    .ascii "DRO"
    .byte 'P'+0x80
.balign 4, 255
    .word OVER_NFA
DROP:
    .word .+5
.section .text, "ax", %progbits
#ifdef TOSCT
//        POP2t           // this one just adds 4 to p
    ADDS p, p, #4
    LDR t, [p]// REFRESH t
#else // DROP:
//        POP2t                // Opt to just do p
    ADDS p, p, #4

#endif
    NEXT

//     SWAP SWAP:      ( nl n2 -- n2 n1 )
//     Exchange the top two values On the stack.

.section .text, "ax", %progbits
SWAP_NFA:
    .byte 0x84
    .ascii "SWA"
    .byte 'P'+0x80
.balign 4, 255
    .word DROP_NFA
SWAP:
    .word .+5
.section .text, "ax", %progbits
#ifdef TOSCT
    MOV w, t
    LDR t, [p, #4]
    ADDS p, p, #8
#else // SWAP:
    POP2w     // n2
    POP2t     // n1
#endif
    DPUSH //  --  LSW MSW )

//     DUP DUP:        ( n1 -- n1 n1 )
//     Duplicate the value n1 on the stack.

.section .text, "ax", %progbits
DUP_NFA:
    .byte 0x83
    .ascii "DU"
    .byte 'P'+0x80
.balign 4, 255
    .word SWAP_NFA
DUP:
    .word .+5
.section .text, "ax", %progbits
//#ifdef TOSCT
// NO NEED TO REFRESH t ?
//#else DUP:
// OPT by picking pops
    LDR t, [p]
//#endif
    TPUSH

//=============================== WORDCAT ====================================//
//NOEXEC HEADERFORWORDCATEGORIES
//     WC_STACK_NFA = Stack Stuff: CATEGORY

.section .text, "ax", %progbits
WC_STACK_NFA:
    .byte 0x80+4+12
    .byte 0x0D
    .byte 0x0A
    .ascii "Stack Stuff:"
    .byte 0x0D
    .byte 0x0A+0x80
.balign 4, 255
    .word DUP_NFA

//     ANDBITS ANDBITS:        ( addr val -- )

.section .text, "ax", %progbits
ANDBITS_NFA:
    .byte 0x87
    .ascii "ANDBIT"
    .byte 'S'+0x80
.balign 4, 255
    .word WC_STACK_NFA
ANDBITS:
    .word .+5
.section .text, "ax", %progbits
    POPp2w  // val
    POP2n  // addr
    LDR t, [n]         // read [val]
    ANDS t, t, w       // modify val
    STR t, [n]         // Write val
    NEXT

//     SETBITS SETBITS:        ( addr val -- )
//     OR val bits into addr. See also CLRBITS.
//     Preserves bits at addr - useful for ARM SoC initialization.

.section .text, "ax", %progbits
SETBITS_NFA:
    .byte 0x87
    .ascii "SETBIT"
    .byte 'S'+0x80
.balign 4, 255
    .word ANDBITS_NFA
SETBITS:
    .word .+5
.section .text, "ax", %progbits
    POPp2w  // val
    POP2n  // addr
    LDR t, [n]         // read[val]
    ORRS t, t, w       // modify val
    STR t, [n]         // Write val
    NEXT

//     CLRBITS CLRBITS:        ( addr val -- )
//     XOR val bits into addr. See also SETBITS.
//     Preserves bits at addr - useful for ARM SoC initialization.

.section .text, "ax", %progbits
CLRBITS_NFA:
    .byte 0x87
    .ascii "CLRBIT"
    .byte 'S'+0x80
.balign 4, 255
    .word SETBITS_NFA
CLRBITS:
    .word .+5
.section .text, "ax", %progbits
    POPp2w  // val
    POP2n  // addr
    LDR t, [n]         // read [val]
    BICS t, t, w       // modify val  - AND-NOT
    STR t, [n]         // write val
    NEXT

//     CMOVE CMOVE:    ( from to count -- )
//      Move the specified quantity of bytes beginning at address from to
//      address to. The contents of address from is moved first proceeding
//      toward high memory. Further specification is necessary on word
//      addressing computers.

.section .text, "ax", %progbits
CMOVE_NFA:
    .byte 0x85
    .ascii "CMOV"
    .byte 'E'+0x80
.balign 4, 255
    .word CLRBITS_NFA
CMOVE:
    .word .+5
.section .text, "ax", %progbits
    POP2n     //    ldr n, [p],#4      //COUNT
    POP2w     //    ldr w, [p],#4      //DEST
    POP2x     //    ldr x, [p],#4      //SOURCE
    CMP n, #0
    BEQ CM2
.thumb_func
CM1:
//not for THUMB
//strcpy  LDRB R2, [R1], #1
//        STRB R2, [R0], #1
//        TST R2, R2      // repeat if R2 is nonzero
//        BNE strcpy
    LDRB t, [x]
    STRB t, [w]
    SUBS n, n, #1
    CMP n, #0
    BEQ CM2

    ADDS w, w, #1
    ADDS x, x, #1
    BNE CM1
.thumb_func
CM2:
#ifdef TOSCT
    LDR t, [p]// REFRESH t
#endif
    NEXT

//     FILL FILL:      ( addr quan b -- )
//      Fill memory at the address with the specified quantity of bytes b.

.section .text, "ax", %progbits
FILL_NFA:
    .byte 0x84
    .ascii "FIL"
    .byte 'L'+0x80
.balign 4, 255
    .word CMOVE_NFA
FILL:
    .word .+5
.section .text, "ax", %progbits
    POP2t     // Fill CHAR
    POP2n     // Fill COUNT
    POP2w     // Beginning ADDR
    CMP n, #0
    BEQ FEND // Count is zero
    ADDS x, n, w
.thumb_func
FLOOP:
    STRB t, [w]
    ADDS w, w, #1
    CMP w, x
    BNE FLOOP
.thumb_func
FEND:
#ifdef TOSCT
    LDR t, [p]// REFRESH t
#endif
    NEXT

//     ERASE ERASE:    ( addr n -- )
//      Clear a region of memory to zero from addr over n addresses.

.section .text, "ax", %progbits
ERASE_NFA:
    .byte 0x85
    .ascii "ERAS"
    .byte 'E'+0x80
.balign 4, 255
    .word FILL_NFA
ERASE:
    .word DOCOL
    .word ZERO
    .word FILL
    .word SEMIS

//     BLANKS BLANKS:  ( addr count -- )
//      Fill an area of memory beginning at addr with blanks (0x20).

.section .text, "ax", %progbits
BLANKS_NFA:
    .byte 0x86
    .ascii "BLANK"
    .byte 'S'+0x80
.balign 4, 255
    .word ERASE_NFA
BLANKS:
    .word DOCOL
    .word BLANK
    .word FILL
    .word SEMIS

//     +! PSTORE:      ( n addr -- )
//     Add n to the value at the address.
//     Pronounced Plus Store

.section .text, "ax", %progbits
PSTORE_NFA:
    .byte 0x82
    .ascii "+"
    .byte '!'+0x80
.balign 4, 255
    .word BLANKS_NFA
PSTORE:
    .word .+5
.section .text, "ax", %progbits
    POP2n // ADDRESS
#ifdef TOSCT
    LDR t, [p]// REFRESH t
#endif
    POP2t // INCREMENT
    LDR w, [n]
    ADDS t, t, w
    STR t, [n]
    NEXT

//     @ AT:   ( addr -- n )
//     Read 32 bit contents of address to TOS.
//     Pronounced Fetch, as in Fetch word at addr.

.section .text, "ax", %progbits
AT_NFA:
    .byte 0x81
    .byte '@'+0x80
.balign 4, 255
//     DC32    TOGGLE_NFA
    .word PSTORE_NFA
AT:
    .word .+5
.section .text, "ax", %progbits
//#ifdef TOSCT
//        LDR     t, [t]
//        STR     t, [p]
//        NEXT
//#else AT:
    POP2n
    LDR t, [n]
    TPUSH
//#endif

//     C@ CAT: ( addr -- b )
//     Leave the 8 bit contents of addr on the stack.
//     Pronounced "Char Fetch", as in Fetch byte at addr.

.section .text, "ax", %progbits
CAT_NFA:
    .byte 0x82
    .ascii "C"
    .byte '@'+0x80
.balign 4, 255
    .word AT_NFA
CAT:
    .word .+5
.section .text, "ax", %progbits
    POP2n
    LDRB t, [n]
    TPUSH

//     ! STORE:        ( n addr -- )
//      Store n at address. Pronounced "Store".

.section .text, "ax", %progbits
STORE_NFA:
    .byte 0x81
    .byte '!'+0x80
.balign 4, 255
    .word CAT_NFA
STORE:
    .word .+5
.section .text, "ax", %progbits
    POP2t     // ADDR
    POP2n     // DATA
    STR n, [t]
    NEXT

//     C! CSTORE:      ( n addr -- )
//      Store LS 8 bits of n at address. Pronounced "Char Store".

.section .text, "ax", %progbits
CSTORE_NFA:
    .byte 0x82
    .ascii "C"
    .byte '!'+0x80
.balign 4, 255
    .word STORE_NFA
CSTORE:
    .word .+5
.section .text, "ax", %progbits
    POP2t
    POP2n
    STRB n, [t]
    NEXT

//=============================== WORDCAT ====================================//
//NOEXEC HEADERFORWORDCATEGORIES
//     WC_RWMEMORY_NFA = Read and Write Memory With: CATEGORY

.section .text, "ax", %progbits
WC_RWMEMORY_NFA:
    .byte 0x80+31
    .byte 0x0D
    .byte 0x0A
    .ascii "Read and Write Memory With:"
    .byte 0x0D
    .byte 0x0A+0x80
.balign 4, 255
    .word CSTORE_NFA

//     ] RBRAC:        ( -- )
//     Resume compilation, by STATE back to 0xC0 (zero is interpreting)
//      0xC0 STATE  used in INTERPRET to execute Immediate words while compiling
//      See [.

.section .text, "ax", %progbits
RBRAC_NFA:
    .byte 0x81
    .byte ']'+0x80
.balign 4, 255
//     DC32    SMUDGE_NFA
    .word WC_RWMEMORY_NFA
RBRAC:
    .word DOCOL
    .word STRVA, 0xC0, CSTATE
    .word SEMIS

//     [ LBRAC:        ( -- ) IMMEDIATE
//     Used in a colon-definition in form
//              xxx    [  words   ]    more
//     Suspend compilation by setting STATE to zero (0xC0 is compiling).
//     The words after [ are executed, not compiled. This allows calculation
//     or compilation exceptions before resuming compilation with ] .
//     See LITERAL and ]

.section .text, "ax", %progbits
LBRAC_NFA:
    .byte 0x0C1
    .byte '['+0x80
.balign 4, 255
    .word RBRAC_NFA
LBRAC:
    .word DOCOL
    .word STRVA, 0, CSTATE
    .word SEMIS

//     [COMPILE] BCOMP:        ( -- ) IMMEDIATE
//     Used in a colon-definition in form:
//              :  xxx    [COMPILE]   immediate_word
//     [COMPILE] will force the compilation of an IMMEDIATE WORD
//     that would otherwise execute during compilation. The above example
//     will select the FORTH vocabulary then xxx executes, rather than at
//     compile time.

.section .text, "ax", %progbits
BCOMP_NFA:
    .byte 0x0C9
    .ascii "[COMPILE"
    .byte ']'+0x80
.balign 4, 255
    .word LBRAC_NFA
BCOMP:
    .word DOCOL
    .word DFIND
//     -FIND ( --- pfa len tf )(found) ( --- ff ) (not found)
    .word ZEQU
    .word LIT, msg_qstack
    .word QERROR
    .word DROP
    .word CFA
    .word COMMA
    .word SEMIS

//     DLITERAL DLITERAL:      ( d -- d ) IMMEDIATE
//                             ( d -- )   (compiling)
//     If compiling, compile a stack double number into a literal. Later
//     execution of the definition containing the literal will push it to
//     the stack. If executing, the number will remain on the stack.
//     : xxx    [ calculate ]  DLITERAL

.section .text, "ax", %progbits
DLITERAL_NFA:
    .byte 0x0C8
    .ascii "DLITERA"
    .byte 'L'+0x80
.balign 4, 255
    .word BCOMP_NFA
DLITERAL:
    .word DOCOL
    .word STATE_SV
    .word AT
    .word ZBRAN
    .word DLIT1-.

    .word SWAP
    .word LITERAL
    .word LITERAL
DLIT1:
    .word SEMIS

//     LITERAL LITERAL:        ( n -- ) IMMEDIATE
//     If compiling, then compile the stack value n as a 32 bit literal.
//     This definition is immediate so that it will execute during a colon
//     definition. The intended use is:
//     : xxx    [ calculate ]  LITERAL
//     Compilation is suspended for the compile time calculation of value.
//     Compilation is resumed and LITERAL compiles this value.

.section .text, "ax", %progbits
LITERAL_NFA:
    .byte 0x0C7
    .ascii "LITERA"
    .byte 'L'+0x80
.balign 4, 255
    .word DLITERAL_NFA
LITERAL:
    .word DOCOL
    .word STATE_SV
    .word AT
    .word ZBRAN
    .word LITE1-.

    .word COMP
    .word LIT
    .word COMMA
LITE1:
    .word SEMIS

//     #> EDIGS:       ( d=(LSW MSW) -- addr count )
//     Terminates numeric output conversion by dropping dnum,
//     leaving the text address and character count suitable for type.

.section .text, "ax", %progbits
EDIGS_NFA:
    .byte 0x82
    .ascii "#"
    .byte '>'+0x80
.balign 4, 255
    .word LITERAL_NFA
EDIGS:
    .word DOCOL
    .word DROP
    .word DROP
    .word HLD_SV
    .word AT
    .word PAD_SV
    .word OVER
    .word SUBB
    .word SEMIS

//     HOLD HOLD:      ( c -- )
//     Used between <# and #> to insert an ascii character into a pictured
//      numeric output string.
//      e.g. 0x2E HOLD will place a decimal point.

.section .text, "ax", %progbits
HOLD_NFA:
    .byte 0x84
    .ascii "HOL"
    .byte 'D'+0x80
.balign 4, 255
    .word EDIGS_NFA
HOLD:
    .word DOCOL
    .word LIT, -1
    .word HLD_SV
    .word PSTORE
    .word HLD_SV
    .word AT
    .word CSTORE
    .word SEMIS

//     SIGN SIGN:      ( n d=<LSW MSW> -- d=<LSW MSW> )
//      Place an ascii "-" sign just before a converted numeric output
//      string in the text output buffer when n is negative. n is discarded
//      but double number dnum is maintained. Must be used between <# and #>.

.section .text, "ax", %progbits
SIGN_NFA:
    .byte 0x84
    .ascii "SIG"
    .byte 'N'+0x80
.balign 4, 255
    .word HOLD_NFA
SIGN:
    .word DOCOL
    .word ROT
    .word ZLESS
    .word ZBRAN
    .word SIGN1-.

    .word LIT, '-'
    .word HOLD
SIGN1:
    .word SEMIS

//     #S DIGS:        ( d1=<LSW MSW> -- d2=<LSW MSW> )
//      Generates ascii text in the text output buffer, by the use of #,
//      until a zero double number d2 results.
//      Used between <# and #>.
//      EACH NUMBER = BASE*number+(character-'0')

.section .text, "ax", %progbits
DIGS_NFA:
    .byte 0x82
    .ascii "#"
    .byte 'S'+0x80
.balign 4, 255
    .word SIGN_NFA
DIGS:
    .word DOCOL
DIGS1: // Begin generating ascii chars by DIG
    .word DIG
    .word OVER
    .word OVER
    .word OR
    .word ZEQU
    .word ZBRAN
    .word DIGS1-.
    .word SEMIS

//     # DIG:  ( d1=<LSW MSW> -- d2=QUO=<LSW MSW> ) BASE MUST BE SET!
//     Generate from a double number d1, the next ascii character which is
//      placed in an output string. Result d2 is the quotient after division
//      by base, and is maintained for further processing.
//      Used between <# and #>.
//      See #S.
//      EACH NUMBER = BASE*number+(character-'0')

.section .text, "ax", %progbits
DIG_NFA:
    .byte 0x81
    .byte '#'+0x80
.balign 4, 255
    .word DIGS_NFA
DIG:
    .word DOCOL
    .word BASE_SV
    .word AT
    .word MSMOD
    .word ROT
    .word LIT, 9
    .word OVER
    .word LESSTHAN
    .word ZBRAN
    .word DIG1-.

    .word LIT, 7
    .word PLUS
DIG1:
    .word LIT, 0x30
    .word PLUS
    .word HOLD
    .word SEMIS

//     <# BDIGS:       ( -- )
//     Setup for pictured numeric output formatting using the words:
//              <# # #S SIGN HOLD #>
//      The conversion is done on a double number producing text at Pad

.section .text, "ax", %progbits
BDIGS_NFA:
    .byte 0x82
    .ascii "<"
    .byte '#'+0x80
.balign 4, 255
    .word DIG_NFA
BDIGS:
    .word DOCOL
    .word STRVA, PAD, NHLD
    .word SEMIS

//     DOES> DOES:     ( pfa -- ) MODIFIED:
//     A word which defines the run-time action within a high-level
//      defining word. DOES> alters the code field and first parameter of
//      the new word to execute the sequence of compiled word addresses
//      following DOES>. Used in combination with <BUILDS. When the DOES>
//      part executes it begins with the address of the first parameter of
//      the new word on the stack. This allows interpretation using this
//      area or its contents. Typical uses include the Forth assembler,
//      multidimensional arrays, and compiler generation.

.section .text, "ax", %progbits
DOES_NFA:
    .byte 0x85
    .ascii "DOES"
    .byte '>'+0x80
.balign 4, 255
    .word BDIGS_NFA
DOES:
    .word DOCOL
    .word RFROM
    .word LATEST
    .word PFA
    .word DUP, CFA
    .word LIT, CREATE_DOES_GOTO
    .word SWAP, STORE
    .word STORE
    .word SEMIS

//     <BUILDS BUILDS: ( -- )  MODIFIED: See CREATE and DOES>
//     Used within a colon-definition
//              CCcc  <BUILDS  ...  DOES>     ...
//     Each time CCcc is executed, <BUILDS defines a new word with a
//      high-level execution proceedure. Executing CCcc in the form
//              CCcc nnnn
//      uses <BUILDS to create a dictionary entry for nnnn with a call to
//      the DOES> part for nnnn. When nnnn is later executed, it has the
//      address of its parameter area on the stack and executes the words
//      after DOES> in CCcc. <BUILDS and DOES> allow runtime proceedures to
//      written in high-level code.

.section .text, "ax", %progbits
BUILDS_NFA:
    .byte 0x87
    .ascii "<BUILD"
    .byte 'S'+0x80
.balign 4, 255
    .word DOES_NFA
BUILDS:
    .word DOCOL
    .word CREATE
    .word SEMIS

//      +LOOP PLOOP:   ( n1 -- ) IMMEDIATE
//                     ( addr n2 -- ) COMPILE
//     At run time, DO begins a sequence with repetitive execution
//     controlled by a loop limit n1 and an index with initial value n2. DO
//     removes these from the stack. Upon reaching LOOP the index is
//     incremented by one.
//     Until the new index equals or exceeds the limit, execution loops
//     back to just after DO// otherwise the loop parameters are discarded
//     and execution continues ahead. Both n1 and n2 are determined at
//     run-time and may be the result of other operations.
//     Within a loop 'I' will copy the current value of the index to the
//     stack. See I, LOOP, +LOOP, LEAVE.
//
//     When compiling within the colon definition, DO compiles (DO), leaves
//     the following address addr and n for later error checking.

.section .text, "ax", %progbits
PLOOP_NFA:
    .byte 0x0C5
    .ascii "+LOO"
    .byte 'P'+0x80
.balign 4, 255
    .word BUILDS_NFA
PLOOP:
    .word DOCOL
    .word THREE
    .word QPAIR
    .word COMP
    .word XPLOOP
    .word BACK
    .word SEMIS

//     LOOP LOOP:      ( addr n -- ) IMMEDIATE
//     Occurs in a colon-definition in form:
//             DO ... LOOP
//     At run-time, LOOP selectively controls branching back to the
//     corresponding DO based on the loop index and limit. The loop index
//     is incremented by one and compared to the limit. The branch back to
//     DO occurs until the index equals or exceeds the limit, then
//     the parameters are discarded and execution continues ahead.
//
//     At compile-time. LOOP compiles (LOOP) and uses addr to calculate an
//     offset to DO. n is used for error testing.

.section .text, "ax", %progbits
LOOP_NFA:
    .byte 0x0C4
    .ascii "LOO"
    .byte 'P'+0x80
.balign 4, 255
    .word PLOOP_NFA
LOOP:
    .word DOCOL
    .word THREE
    .word QPAIR
    .word COMP
    .word XLOOP
    .word BACK
    .word SEMIS

//     DO DO:  ( n1 n2 -- ) IMMEDIATE
//             (addr n -- ) COMPILE
//     Occurs in a colon-definition in form:
//     DO ... LOOP

.section .text, "ax", %progbits
DO_NFA:
    .byte 0x0C2
    .ascii "D"
    .byte 'O'+0x80
.balign 4, 255
    .word LOOP_NFA
DO:
    .word DOCOL
    .word COMP
    .word XDO
    .word HERE
    .word THREE
    .word SEMIS

//     ENDIF ENDIF:    ( addr n -- ) IMMEDIATE
//     Occurs in a colon-definition in form:
//             IF ... ENDIF
//             IF ... ELSE ... ENDIF
//     At run-time, ENDIF serves only as the destination of a forward
//     branch from IF or ELSE. It marks the conclusion of the conditional
//     structure. THEN is another name for ENDIF. Both names are supported
//     in fig-FORTH. See also IF and ELSE.
//
//     At compile-time, ENDIF computes the forward branch offset from addr
//     to HERE and stores it at addr. n is used for error tests.

.section .text, "ax", %progbits
ENDIF_NFA:
    .byte 0x0C5
    .ascii "ENDI"
    .byte 'F'+0x80
.balign 4, 255
    .word DO_NFA
ENDIF:
    .word DOCOL
    .word QCOMP
    .word TWO
    .word QPAIR
    .word HERE
    .word OVER
    .word SUBB
    .word SWAP
    .word STORE
    .word SEMIS

//     THEN THEN:      ( -- ) IMMEDIATE
//     An alias for ENDIF.

.section .text, "ax", %progbits
THEN_NFA:
    .byte 0x0C4
    .ascii "THE"
    .byte 'N'+0x80
.balign 4, 255
    .word ENDIF_NFA
THEN:
    .word DOCOL
    .word ENDIF
    .word SEMIS

//     ELSE ELSE:      ( addr1 n1 -- ) IMMEDIATE
//                     ( addr2 n2 -- ) COMPILING
//     Occurs within a colon-definition in the form:
//             IF ... ELSE ... ENDIF
//     At run-time, ELSE executes after the true part following IF. ELSE
//     forces execution to skip over the following false part and resumes
//     execution after the ENDIF. It has no stack effect.
//
//     At compile-time ELSE emplaces BRANCH reserving a branch offset,
//     leaves the address addr2 and n2 for error testing. ELSE also
//     resolves the pending forward branch from IF by calculating the
//     offset from addr1 to HERE and storing at addr1.

.section .text, "ax", %progbits
ELSE_NFA:
    .byte 0x0C4
    .ascii "ELS"
    .byte 'E'+0x80
.balign 4, 255
    .word THEN_NFA
ELSE:
    .word DOCOL
    .word TWO
    .word QPAIR
    .word COMP
    .word BRAN
    .word HERE
    .word ZERO
    .word COMMA
    .word SWAP
    .word TWO
    .word ENDIF
    .word TWO
    .word SEMIS

//     IF IF:  ( f -- ) IMMEDIATE
//             ( -- addr n ) COMPILE
//     Occurs is a colon-definition in form:
//             IF (tp) ...  ENDIF      .
//             IF (tp) ... ELSE (fp) ... ENDIF
//     At run-time, IF selects execution based on a boolean flag. If f is
//     true (non-zero), execution continues ahead thru the true part. If f
//     is false (zero), execution skips till just after ELSE to execute
//     the false part. After either part, execution resumes after ENDIF.
//     ELSE and its false part are optional.
//     skips to just after ENDIF..
//
//     At compile-time IF compiles 0BRANCH and reserves space for an offset
//     at addr. addr and n are used later for resolution of the offset and
//     error testing.

.section .text, "ax", %progbits
IF_NFA:
    .byte 0x0C2
    .ascii "I"
    .byte 'F'+0x80
.balign 4, 255
    .word ELSE_NFA
IF:
    .word DOCOL
    .word COMP
    .word ZBRAN
    .word HERE
    .word ZERO
    .word COMMA
    .word TWO
    .word SEMIS

//     UNTIL UNTIL:    ( f -- ) IMMEDIATE
//                     ( addr n -- ) COMPILE:
//     Occurs within a colon-definition in the form:
//             BEGIN ... UNTIL
//     At run-time, UNTIL controls the conditional branch back to the
//     corresponding BEGIN. If f is false, execution returns to just after.
//     BEGIN:  if true, execution continues ahead.
//     At compile-time, UNTIL compiles (0BRANCH) and an offset from HERE to
//     addr. n is used for error tests.

.section .text, "ax", %progbits
UNTIL_NFA:
    .byte 0x0C5
    .ascii "UNTI"
    .byte 'L'+0x80
.balign 4, 255
    .word IF_NFA
UNTIL:
    .word DOCOL
    .word ONE
    .word QPAIR
    .word COMP
    .word ZBRAN
    .word BACK
    .word SEMIS

//     AGAIN AGAIN:    ( addr n -- ) IMMEDIATE
//     Used in a colon-definition in the form:
//                     BEGIN ... AGAIN
//     At run-time, AGAIN forces execution to return to corresponding BEGIN.
//     There is no effect on the stack. Execution cannot leave this loop
//     (unless R> DROP is executed one level below).
//
//     At compile time, AGAIN compiles BRANCH with an offset from HERE to
//     addr. n is used for compile-time error checking.

.section .text, "ax", %progbits
AGAIN_NFA:
    .byte 0x0C5
    .ascii "AGAI"
    .byte 'N'+0x80
.balign 4, 255
    .word UNTIL_NFA
AGAIN:
    .word DOCOL
    .word ONE
    .word QPAIR
    .word COMP
    .word BRAN
    .word BACK
    .word SEMIS

//     REPEAT REPEAT:  ( addr n -- ) IMMEDIATE
//     Used within a colon-definition in the form:
//             BEGIN ... WHILE ... REPEAT
//     At run-time, REPEAT forces an unconditional branch back to just
//     after the corresponding BEGIN.
//
//     At compile-time, REPEAT compiles BRANCH and the offset from HERE to
//     addr. n is used for error testing.

.section .text, "ax", %progbits
REPEAT_NFA:
    .byte 0x0C6
    .ascii "REPEA"
    .byte 'T'+0x80
.balign 4, 255
    .word AGAIN_NFA
REPEAT:
    .word DOCOL
    .word TOR
    .word TOR
    .word AGAIN
    .word RFROM
    .word RFROM
    .word TWO
    .word SUBB
    .word ENDIF
    .word SEMIS

//     WHILE WHILE:    ( f -- ) IMMEDIATE
//                     (ad1 nl -- ad1 n1 ad2 n2 ) COMPILE
//     Occurs in a colon-definition in the form:
//             BEGIN ... WHILE (tp) ... REPEAT
//     At run-time, WHILE selects conditional execution based on boolean
//     flag f. If f is true (non-zero), WHILE continues execution of the
//     true part thru to REPEAT, which then branches back to BEGIN. If f is
//     false (zero), execution skips to just after REPEAT, exiting the
//     structure.
//
//     At compile time, WHILE emplaces (0BRANCH) and leaves ad2 of the
//     reserved offset. The stack values will be resolved by REPEAT.

.section .text, "ax", %progbits
WHILE_NFA:
    .byte 0x0C5
    .ascii "WHIL"
    .byte 'E'+0x80
.balign 4, 255
    .word REPEAT_NFA
WHILE:
    .word DOCOL
    .word IF
    .word TWOP
    .word SEMIS

//     BEGIN BEGIN:    ( -- addr n ) IMMEDIATE
//     Occurs in a colon-definition in form:
//     BEGIN ... UNTIL
//     BEGIN ... AGAIN
//     BEGIN ... WHILE ... REPEAT
//     At run-time, BEGIN marks the start of a sequence that may be
//     repetitively executed. It serves as a return point from the
//     corresponding UNTIL, AGAIN or REPEAT. When executing UNTIL, a return
//     to BEGIN will occur if the top of the stack is false//
//     for AGAIN and REPEAT a return to BEGIN always occurs.
//
//     At compile time BEGIN leaves its return address and n for compiler
//     error checking.

.section .text, "ax", %progbits
BEGIN_NFA:
    .byte 0x0C5
    .ascii "BEGI"
    .byte 'N'+0x80
.balign 4, 255
    .word WHILE_NFA
BEGIN:
    .word DOCOL
    .word QCOMP
    .word HERE
    .word ONE
    .word SEMIS

//=============================== WORDCAT ====================================//
//NOEXEC HEADERFORWORDCATEGORIES
//     WC_COMPILE_NFA = Inside Colon WORDS: CATEGORY

.section .text, "ax", %progbits
WC_COMPILE_NFA:
    .byte 0x80+4+19
    .byte 0x0D
    .byte 0x0A
    .ascii "Inside Colon WORDS:"
    .byte 0x0D
    .byte 0x0A+0x80
.balign 4, 255
    .word BEGIN_NFA

//     IMMEDIATE IMMED:        ( -- )
//     Mark the most recently made definition so that when encountered at
//      compile time, it will be executed rather than being compiled. i.e.
//     the precedence bit in its header is set.
//     This method allows definitions to handle unusual compiling
//     situations, rather. than build them into the fundamental compiler.
//     The system may force compilation of an immediate definition by
//     preceeding it with [COMPILE].

.section .text, "ax", %progbits
IMMED_NFA:
    .byte 0x89
    .ascii "IMMEDIAT"
    .byte 'E'+0x80
.balign 4, 255
    .word WC_COMPILE_NFA
IMMED:
    .word DOCOL
    .word LATEST
    .word LIT, 0x40
    .word TOGGLE
    .word SEMIS

//     CREATE CREATE:  ( -- )
//      Create a word in The Dictionary.
//      Make searchable and forgetable NFA/LFA, DOCON, ADDR->PFA
//     USE <BUILDS with DOES> instead of CREATE.
//     IF DICTIONAIRY FULL PRINT Error MESSAGE AND Abort.
//
//      Saves HERE in CSDP in case there's an error creating a word.
//      CSDP is reset when a word is completed, by
//
//     A defining word used in the form:
//             CREATE CCcc
//     by such words as VAR, CON AND <BUILDS to create a dictionary header for
//     a new word. The code field contains the address of the words
//     parameter field.

.section .text, "ax", %progbits
CREATE_NFA:
    .byte 0x86
    .ascii "CREAT"
    .byte 'E'+0x80
.balign 4, 255
    .word IMMED_NFA
CREATE:
    .word DOCOL
    .word DICTSPACE
    .word LIT, 15, SUBB
    .word ZLESS
    .word ZBRAN
    .word CREATEOK-.

    .word DICTFULL_ABORT

CREATEOK:
    .word DFIND
//     -FIND DFIND ( --- pfa len tf )(found) ( --- ff ) (not found)
    .word ZBRAN
    .word CREA1-.

#ifdef IO2TP
    .word NOOP
    .word CLRPAD
#endif
    .word DROP
    .word NFA
    .word IDDOT
    .word LIT, msg_wordexists
// Nothing created yet so ABORT is correct.
//        DC32    ERROR
    .word NULLSTRLEN, TYPE
    .word ABORT

CREA1:
// Save HERE in CSDP so ERROR can reset DP if this definition fails.
// CSDP is reset by SEMIC_CREATE when this definition is completed.
// SEMIC_CREATE used in

// This new definitions cstring name has been moved to HERE
    .word HERE, DUP
    .word CSDP_SV, STORE
// Dup HERE-NFA to allot NFAx
    .word DUP
// Limit NFA allot to maxwordlen. DOES NOT CHANGE actual count!
// If count is larger than MAXWORDLEN behaviour of this def is unpredictable!
    .word CAT
    .word LIT, MAXWORDLEN
    .word MIN
    .word ALLOT_PRIM
// Dup HERE-NFA to set count byte, and to be consumed later
// for setting CURRENT after previous CURRENT compiled into LFA.
    .word DUP
// Make regular (not immediate) NFA count byte
    .word LIT, 0x80
    .word TOGGLE
// HERE is new now. Mark end of NFA for PFIND search
    .word HERE
    .word LIT, 0x80
    .word TOGGLE
// Bump DP to LFA
    .word ONE, DP_SV
    .word PSTORE
// Set LFA
    .word LATEST
    .word COMMA
// DUP'd HERE should be on stack
// Have to set CURRENT with last dup's HERE-NFA after LATEST is compiled
    .word CURRENT_SV
    .word STORE
    .word COMP, DOCON
    .word HERE, FOURP
    .word COMMA
//     DC32    SMUDGE          // ELIMINATED
//      DC32    SEMIC_CREATE    // USED in CALLERS OF CREATE, NOT HERE!
    .word SEMIS

//     CON CON:        ( n -- )  MODIFIED: and CONSTANT renamed CON
//     IF DICTIONAIRY FULL PRINT Error MESSAGE AND Abort.
//     A defining word used in the form:
//              n CONSTANT CCcc
//     to create word CCcc, with its parameter field containing n. When
//     CCcc is later executed, it will push the value of n to the stack.
.section .text, "ax", %progbits
CONSTANT_NFA:
    .byte 0x88
    .ascii "CONSTAN"
    .byte 'T'+0x80
.balign 4, 255
    .word CREATE_NFA
CONSTANT:
    .word DOCOL, CON, SEMIS

.section .text, "ax", %progbits
CON_NFA:
    .byte 0x83
    .ascii "CO"
    .byte 'N'+0x80
.balign 4, 255
//     DC32    CREATE_NFA
    .word CONSTANT_NFA
CON:
    .word DOCOL
    .word CREATE
    .word LIT, -4, DP_SV, PSTORE
    .word COMMA
    .word SEMIC_CREATE
//        DC32    DOTDICTSPACE
    .word SEMIS

//     VAR VAR:        ( -- ) RENAMED: VARIABLE to VAR
//     IF RAMVARSPACE FULL PRINT Error MESSAGE AND Abort.
//     A defining word used in the form:
//              VARIABLE CCcc
//     When VARIABLE is executed, it creates the definition CCcc with its
//     with its cell space uninitialized. When CCcc is executed,
//     its cell space address is put on the stack. Use with @ or !
//     NOTE: VAR's cell space is allocated in ram. See UP and VARALLOT.

.section .text, "ax", %progbits
VARIABLE_NFA:
    .byte 0x88
    .ascii "VARIABL"
    .byte 'E'+0x80
.balign 4, 255
    .word CON_NFA
VARIABLE:
    .word DOCOL, VAR_, SEMIS

.section .text, "ax", %progbits
VAR_NFA:
    .byte 0x83
    .ascii "VA"
    .byte 'R'+0x80
.balign 4, 255
//     DC32    CON_NFA
    .word VARIABLE_NFA
VAR_:
    .word DOCOL
    .word CREATE
    .word LIT, -8, DP_SV, PSTORE
    .word COMP, DOVAR
//        DC32    COMP, DOCON     // CFA of VAR's
// aligned, INCREMENTS DP REFLECTED by HERE
// compile the value ( v -- )
    .word ONE
    .word VARALLOT
    .word COMMA
    .word SEMIC_CREATE
//        DC32    DOTDICTSPACE
//        DC32    DOTVARSPACE
    .word SEMIS

//
//     Terminate a colon-definition and stop further compilation.
//     Compiles the run-time

.section .text, "ax", %progbits
SEMI_NFA:
    .byte 0x0C1
    .byte ';'+0x80
.balign 4, 255
    .word VAR_NFA
SEMI:
    .word DOCOL
    .word QCSP
    .word COMP
    .word SEMIS
    .word LBRAC
    .word SEMIC_CREATE
//        DC32    DOTDICTSPACE
    .word SEMIS

//     : COLON:        ( -- ) IMMEDIATE
//     IF DICTIONAIRY FULL PRINT Error MESSAGE AND Abort.
//     Used in the form called a colon-definition:
//             : CCcc     ...     //
//     Creates a dictionary entry defining CCcc as equivalent to the
//     following sequence of Forth word definitions '...' until the next
//     ';' or ';CODE'.
//     The compiling process is done by the text interpreter as long as
//     STATE is non-zero. Other details are that the CONTEXT vocabulary is
//     set to the CURRENT vocabulary and that words with the precedence bit
//     set (P) are executed rather than being compiled.

.section .text, "ax", %progbits
COLON_NFA:
    .byte 0x0C1
    .byte ':'+0x80
.balign 4, 255
    .word SEMI_NFA
COLON:
    .word DOCOL
//     DICTSPACE TEST DONE in CREATE
    .word QEXEC
    .word SCSP
    .word CREATE
    .word RBRAC
    .word LIT, -8, DP_SV, PSTORE
    .word COMP, DOCOL
    .word SEMIS

//=============================== WORDCAT ====================================//
//NOEXEC HEADERFORWORDCATEGORIES
//     WC_CREATE_NFA = CREATE WORDS With: CATEGORY

.section .text, "ax", %progbits
WC_CREATE_NFA:
    .byte 0x80+22
    .byte 0x0D
    .byte 0x0A
    .ascii "CREATE WORDS With:"
    .byte 0x0D
    .byte 0x0A+0x80
.balign 4, 255
    .word COLON_NFA

//     DABS DABS: ( sd=(LSW MSW) -- ud=(LSW MSW) )
//      Leave the absolute value ud of a signed double number.

.section .text, "ax", %progbits
DABS_NFA:
    .byte 0x84
    .ascii "DAB"
    .byte 'S'+0x80
.balign 4, 255
    .word WC_CREATE_NFA
DABSF:
DABS:
    .word DOCOL
    .word DUP
    .word DPM
    .word SEMIS

//     DNEGATE DNEGATE: ( d1 -- d<2>=(LSW MSW) ) RENAMED: DMINUS to DNEGATE
//      Convert d1 to its double number two's complement d2.

.section .text, "ax", %progbits
DNEGATE_NFA:
    .byte 0x87
    .ascii "DNEGAT"
    .byte 'E'+0x80
.balign 4, 255
    .word DABS_NFA
DNEGATE:
    .word .+5
.section .text, "ax", %progbits
    POP2t     // MSW   //POP    BX
    POP2w     // LSW   //POP    CX
    MVNS t, t        // negate MSW
    MVNS w, w        // negate LSW
    ADDS w, w, #1 // add 1 to LSW
    DPUSH //  --  LSW MSW )

//     DPL_SV: ( -- addr of NDPL ) Contains # of digits after . in double number
//     A system variable containing the number of digits to the right of the
//     decimal on double integer input. It may also be used to hold output
//     column location of a decimal point, in system generated formating. The
//     default value on single number input is -1.
.section .text, "ax", %progbits
DPL_NFA:
    .byte 0x83
    .ascii "DP"
    .byte 'L'+0x80
.balign 4, 255
    .word DNEGATE_NFA
DPL_SV:
    .word DOCON, NDPL

//     D.R DDOTR:      ( sd=<LSW MSW> n -- ) SIGNED:
//     Print a signed double number sd right aligned
//     in a field n characters wide.

.section .text, "ax", %progbits
DDOTR_NFA:
    .byte 0x83
    .ascii "D."
    .byte 'R'+0x80
.balign 4, 255
    .word DPL_NFA
DDOTR:
    .word DOCOL
    .word TOR
    .word SWAP
    .word OVER
    .word DABS
    .word BDIGS
    .word DIGS
    .word SIGN
    .word EDIGS
    .word RFROM
    .word OVER
    .word SUBB
    .word SPACES
    .word TYPE
    .word SEMIS

//     D. DDOT:        ( S32-2'S COMPLEMET = (d=<LSW MSW> -- )
//     Print a signed double number from a 32 bit two's complement value.
//      The high-order 32 bits are most accessable on the stack. Conversion
//      is performed according to the current base. A blank follows.

.section .text, "ax", %progbits
DDOT_NFA:
    .byte 0x82
    .ascii "D"
    .byte '.'+0x80
.balign 4, 255
    .word DDOTR_NFA
DDOT:
    .word DOCOL
    .word ZERO
    .word DDOTR
    .word SPACE
    .word SEMIS

//     D+ DPLUS:       ( LSW1 MSW1 LSW2 MSW2 --- LSW MSW )  SIGNED:
//     Leave the signed double number sum of two signed double numbers.

.section .text, "ax", %progbits
DPLUS_NFA:
    .byte 0x82
    .ascii "D"
    .byte '+'+0x80
.balign 4, 255
    .word DDOT_NFA
DPLUS:
    .word .+5
.section .text, "ax", %progbits
    POP2t     //    ldr     t, [p],#4       // MS
    POP2n     //    ldr     n, [p],#4       // LS
    POP2x     //    ldr     x, [p],#4       // MS
    POP2w     //    ldr     w, [p],#4       // LS
    ADDS w, w, n        // LS sum, set status flags
    ADCS t, t, x        // MS sum + carry
    DPUSH //  --  LSW MSW )

//     S->D STOD:      ( n -- d=<LSW MSW> ) SIGNED:
//      Sign extend a single number to form a double number.
//     : S->D DUP 0< NEGATE // hi level equivalent

.section .text, "ax", %progbits
STOD_NFA:
    .byte 0x84
    .ascii "S->"
    .byte 'D'+0x80
.balign 4, 255
    .word DPLUS_NFA
STOD:
    .word .+5
.section .text, "ax", %progbits
    POP2w // POP LSW
    EORS t, t // Zero MSW
    ORRS w, w, w // OR LSW
    BPL STOD1 // LSW is POS

    SUBS t, t, #1 // LSW is NEG
.thumb_func
STOD1:
    DPUSH //  --  LSW MSW )

//     2* TWOSTAR:     ( n -- n*2 ) LSL 1

.section .text, "ax", %progbits
TWOSTAR_NFA:
    .byte 0x82
    .ascii "2"
    .byte '*'+0x80
.balign 4, 255
    .word STOD_NFA
TWOSTAR:
    .word .+5
.section .text, "ax", %progbits
    POP2t
    LSLS t, t, #1 //
    TPUSH

//     2/ TWOSLASH:    ( n -- n/1 ) ASR 1 (FLOORED)

.section .text, "ax", %progbits
TWOSLASH_NFA:
    .byte 0x82
    .ascii "2"
    .byte '/'+0x80
.balign 4, 255
    .word TWOSTAR_NFA
TWOSLASH:
    .word .+5
.section .text, "ax", %progbits
    POP2t
    ASRS t, t, #1 //
    TPUSH

//     1- ONEM:        ( n -- n-1 )

.section .text, "ax", %progbits
ONEM_NFA:
    .byte 0x82
    .ascii "1"
    .byte '-'+0x80
.balign 4, 255
    .word TWOSLASH_NFA
ONEM:
    .word .+5
.section .text, "ax", %progbits
    POP2t
    SUBS t, t, #1 //
    TPUSH

//     1+ ONEP:        ( n -- n+1 )

.section .text, "ax", %progbits
ONEP_NFA:
    .byte 0x82
    .ascii "1"
    .byte '+'+0x80
.balign 4, 255
    .word ONEM_NFA
ONEP:
    .word .+5
.section .text, "ax", %progbits
    POP2t
    ADDS t, t, #1 //
    TPUSH

//     2+ TWOP:        ( n -- n+2 )

.section .text, "ax", %progbits
TWOP_NFA:
    .byte 0x82
    .ascii "2"
    .byte '+'+0x80
.balign 4, 255
    .word ONEP_NFA
TWOP:
    .word .+5
.section .text, "ax", %progbits
    POP2t
    ADDS t, t, #2
    TPUSH

//     4+ FOURP:       ( n -- n+4 )

.section .text, "ax", %progbits
FOURP_NFA:
    .byte 0x82
    .ascii "4"
    .byte '+'+0x80
.balign 4, 255
    .word TWOP_NFA
FOURP:
    .word .+5
.section .text, "ax", %progbits
    POP2t
    ADDS t, t, #4
    TPUSH

//     4- FOURM:       ( n -- n-4 )

.section .text, "ax", %progbits
FOURM_NFA:
    .byte 0x82
    .ascii "4"
    .byte '-'+0x80
.balign 4, 255
    .word FOURP_NFA
FOURM:
    .word .+5
.section .text, "ax", %progbits
    POP2t
    SUBS t, t, #4
    TPUSH

//     0 ZERO: ( -- 0 )

.section .text, "ax", %progbits
ZERO_NFA:
    .byte 0x81
    .byte '0'+0x80
.balign 4, 255
    .word FOURM_NFA
ZERO:
    .word DOCON, 0x0

//     1 ONE: ( -- 1 )

.section .text, "ax", %progbits
ONE_NFA:
    .byte 0x81
    .byte '1'+0x80
.balign 4, 255
    .word ZERO_NFA
ONE:
    .word DOCON, 0x1

//     2 TWO: ( -- 2 )

.section .text, "ax", %progbits
TWO_NFA:
    .byte 0x81
    .byte '2'+0x80
.balign 4, 255
    .word ONE_NFA
TWO:
    .word DOCON, 0x2

//     3 THREE: ( -- 3 )

.section .text, "ax", %progbits
THREE_NFA:
    .byte 0x81
    .byte '3'+0x80
.balign 4, 255
    .word TWO_NFA
THREE:
    .word DOCON, 0x3

//     4 FOUR: ( -- 4 )

.section .text, "ax", %progbits
FOUR_NFA:
    .byte 0x81
    .byte '4'+0x80
.balign 4, 255
    .word THREE_NFA
FOUR:
    .word DOCON, 0x4

//     M* MSTAR:       ( n1 n2 -- d=<S32LSW S32MSW> )  SIGNED:
//      A mixed magnitude math operation which leaves the double number
//      signed product of two signed number.

.section .text, "ax", %progbits
MSTAR_NFA:
    .byte 0x82
    .ascii "M"
    .byte '*'+0x80
.balign 4, 255
    .word FOUR_NFA
MSTAR:
    .word DOCOL, TDUP
    .word XORR
    .word TOR
    .word ABS
    .word SWAP
    .word ABS
    .word USTAR
    .word RFROM
    .word DPM
    .word SEMIS

//     M/ MSLASH:      ( sd  n1  ---  d=<s32REM  S32QUO> )
//      A mixed magnitude math operator which leaves the signed remainder
//      and signed quotient from sd, a double number dividend and divisor n1.
//      The remainder takes its sign from the dividend.

.section .text, "ax", %progbits
MSLASH_NFA:
    .byte 0x82
    .ascii "M"
    .byte '/'+0x80
.balign 4, 255
    .word MSTAR_NFA
MSLASH:
    .word DOCOL
    .word OVER
    .word TOR
    .word TOR
    .word DABS
    .word R
    .word ABS
    .word USLASH
    .word RFROM
    .word R
    .word XORR
    .word PM
    .word SWAP
    .word RFROM
    .word PM
    .word SWAP
    .word SEMIS

//     * STAR: ( n1 n2 -- prod=n3 )
//     Leave the signed product n3 of two (32bit) signed numbers n1 and n2.

.section .text, "ax", %progbits
STAR_NFA:
    .byte 0x81
    .byte '*'+0x80
.balign 4, 255
    .word MSLASH_NFA
STAR:
    .word DOCOL
    .word MSTAR
    .word DROP
    .word SEMIS

//     /MOD SLMOD:     ( n1 n2 -- rem quot )   SIGNED:
//     Leave the remainder and signed quotient of n1/n2. The remainder has
//     the sign of the dividend.

.section .text, "ax", %progbits
SLMOD_NFA:
    .byte 0x84
    .ascii "/MO"
    .byte 'D'+0x80
.balign 4, 255
    .word STAR_NFA
SLMOD:
    .word DOCOL
    .word TOR
    .word STOD
    .word RFROM
    .word MSLASH
    .word SEMIS

//     / SLASH:        ( sn1 sn2 -- sn ) SIGNED:
//     Leave the signed quotient sn of sn1/sn2.

.section .text, "ax", %progbits
SLASH_NFA:
    .byte 0x81
    .byte '/'+0x80
.balign 4, 255
    .word SLMOD_NFA
SLASH:
    .word DOCOL
    .word SLMOD
    .word SWAP
    .word DROP
    .word SEMIS

//     MOD MOD:        ( sn1 n2 -- modulo )
//     Leave the remainder of sn1/n2, with the same sign as sn1.

.section .text, "ax", %progbits
MODD_NFA:
    .byte 0x83
    .ascii "MO"
    .byte 'D'+0x80
.balign 4, 255
    .word SLASH_NFA
MOD:
    .word DOCOL
    .word SLMOD
    .word DROP
    .word SEMIS

//     */MOD SSMOD:    ( n1 n2 n3 -- n4 n5 )
//     Leave the quotient n5 and remainder n4 of the operation n1*n2/n3 A
//     31 bit intermediate product is used as for */.

.section .text, "ax", %progbits
SSMOD_NFA:
    .byte 0x85
    .ascii "*/MO"
    .byte 'D'+0x80
.balign 4, 255
    .word MODD_NFA
SSMOD:
    .word DOCOL
    .word TOR
    .word MSTAR
    .word RFROM
    .word MSLASH
    .word SEMIS

//     */ SSLASH:      ( n1 n2 n3 -- n4 )
//     Leave the ratio n4 = n1*n2/n3 where all are signed numbers.
//     Retention of an intermediate 31 bit product permits greater accuracy
//     than would. be available with the sequence:
//             n1  n2  *  n3  /

.section .text, "ax", %progbits
SSLASH_NFA:
    .byte 0x82
    .ascii "*"
    .byte '/'+0x80
.balign 4, 255
    .word SSMOD_NFA
SSLASH:
    .word DOCOL
    .word SSMOD
    .word SWAP
    .word DROP
    .word SEMIS

//     + PLUS: ( n1 n2 -- n3 )
//     Add n1 and n2, leaving sum n3

.section .text, "ax", %progbits
PLUS_NFA:
    .byte 0x81
    .byte 0xAB
.balign 4, 255
    .word SSLASH_NFA
PLUS:
    .word .+5
.section .text, "ax", %progbits
    POP2t
    POP2n
    ADDS t, t, n
    TPUSH

//     - SUBB: ( n1 n2 -- n3 )
//     Leave the difference of n1-n2 as n3.
//     1 2 - . -1
//     2 1 - .  1

.section .text, "ax", %progbits
SUB_NFA:
    .byte 0x81
    .byte '-'+0x80
.balign 4, 255
    .word PLUS_NFA
SUBB:
    .word .+5
.section .text, "ax", %progbits
    POP2t
    POP2n
    SUBS t, n, t
    TPUSH

//     = EQUAL:        (n1 n2 -- f )
//     Leave a non-zero true flag if n1=n2// otherwise leave a false flag.

.section .text, "ax", %progbits
EQUAL_NFA:
    .byte 0x81
    .byte '='+0x80
.balign 4, 255
    .word SUB_NFA
EQUAL:
    .word .+5
.section .text, "ax", %progbits
#ifdef TRUE_EQU_NEG_ONE
    EORS t, t
#endif
    POP2n
    POP2w
    SUBS n, n, w
    BEQ EQUAL_TRUE
    TPUSH // zero

.thumb_func
EQUAL_TRUE:
#ifdef TRUE_EQU_NEG_ONE
    SUBS t, #1 // -1
#else
    ADDS t, #1 // 1
#endif
    TPUSH
/*
        .word DOCOL
        .word SUBB
        .word ZEQU
        .word SEMIS
*/

//     < LESSTHAN:     ( n1 n2 -- f ) SIGNED:
//     Leave a true flag if n1 is less than n2 otherwise leave a false flag.
//     C0 1 < . 0  -1 C0 < . 1

.section .text, "ax", %progbits
LESSTHAN_NFA:
    .byte 0x81
    .byte '<'+0x80
.balign 4, 255
    .word EQUAL_NFA
LESSTHAN:
    .word .+5
.section .text, "ax", %progbits
#ifdef TRUE_EQU_NEG_ONE
    EORS t, t // zero t
    SUBS t, #1 // -1
#else
    MOVS t, #1
#endif
    POP2n     // n2
    POP2w     // n1
    CMP n, w // n1 < n2
    BGT LESS1

    EORS t, t // zero t =< n
.thumb_func
LESS1:
    TPUSH

//     U< ULESSTHAN:   ( n1 n2 -- f )  UNSIGNED:
//     Leave a true flag if n1 is less than n2 otherwise leave a false flag.
//     -1 -2 U< . 0  -1 2 U< . 0  1 2 U< . 1

.section .text, "ax", %progbits
ULESSTHAN_NFA:
    .byte 0x82
    .ascii "U"
    .byte '<'+0x80
.balign 4, 255
    .word LESSTHAN_NFA
ULESSTHAN:
    .word DOCOL, TDUP
    .word XORR, ZLESS
    .word ZBRAN
    .word ULES1-.

    .word DROP, ZLESS
    .word ZEQU
    .word BRAN
    .word ULES2-.

ULES1:
    .word SUBB, ZLESS

ULES2:
    .word SEMIS

//     > GREATERTHAN:  ( n1 n2 -- f )  SIGNED: L0
//     Leave a true flag if n1 is greater than n2 otherwise a false flag.
//     -1 1 > . 0  1 -1 > . 1

.section .text, "ax", %progbits
GREATERTHAN_NFA:
    .byte 0x81
    .byte '>'+0x80
.balign 4, 255
    .word ULESSTHAN_NFA
GREATERTHAN:
    .word DOCOL
    .word SWAP
    .word LESSTHAN
    .word SEMIS

//     0= ZEQU:        ( n -- f )
//     Leave a true flag is the number is equal to zero, otherwise leave a
//     false flag. CHANGED Code dependent on true flag being 1 FOR -1 TRUE

.section .text, "ax", %progbits
ZEQU_NFA:
    .byte 0x82
    .ascii "0"
    .byte '='+0x80
.balign 4, 255
    .word GREATERTHAN_NFA
ZEQU:
    .word .+5
.section .text, "ax", %progbits
    EORS t, t
    POP2n
    CMP n, #0
    BNE ZEQU1

#ifdef TRUE_EQU_NEG_ONE
    SUBS t, t, #1
#else
    ADDS t, t, #1
#endif

.thumb_func
ZEQU1:
    TPUSH

//     0< ZLESS:       ( n -- f )
//     Leave a true flag if the number is less than zero (negative),
//     otherwise leave a false flag.

.section .text, "ax", %progbits
ZLESS_NFA:
    .byte 0x82
    .ascii "0"
    .byte '<'+0x80
.balign 4, 255
    .word ZEQU_NFA
ZLESS:
    .word .+5
.section .text, "ax", %progbits
#ifdef TOSCT // REPLACING t SO THIS IS FASTER THAN POP2n
    POP2t
    MOV n, t
#else
    POP2n
#endif
#ifdef TRUE_EQU_NEG_ONE
    EORS t, t
    SUBS t, #1 // TRUE -1
#else
    MOVS t, #1 // TRUE
#endif
    ORRS n, n, n // SET FLAGS
    BMI ZLESS1 // JS    ZLESS1

    EORS t, t // FALSE
.thumb_func
ZLESS1:
    TPUSH

//     BIN BIN:        ( -- )
//     Set the numeric conversion base to TWO (bianry).

.section .text, "ax", %progbits
BIN_NFA:
    .byte 0x83
    .ascii "BI"
    .byte 'N'+0x80
.balign 4, 255
    .word ZLESS_NFA
BIN:
    .word DOCOL
    .word STRVA, 2, NBASE
    .word SEMIS

//     HEX HEX:        ( -- )
//     Set the numeric conversion base to sixteen (hexadecimal).

.section .text, "ax", %progbits
HEX_NFA:
    .byte 0x83
    .ascii "HE"
    .byte 'X'+0x80
.balign 4, 255
    .word BIN_NFA
HEX:
    .word DOCOL
    .word STRVA, 16, NBASE
    .word SEMIS

//     DECIMAL DECIMAL:        ( -- )
//     Set the numeric conversion base to TEN (decimal).
//     DEC IS A NUMBER!

.section .text, "ax", %progbits
DECIMAL_NFA:
    .byte 0x87
    .ascii "DECIMA"
    .byte 'L'+0x80
.balign 4, 255
    .word HEX_NFA
DECIMAL:
    .word DOCOL
    .word STRVA, 10, NBASE
    .word SEMIS

//     NEGATE NEGATE: ( n1 -- n2 ) RENAMED: MINUS to NEGATE
//     Leave the two's complement of a number.

.section .text, "ax", %progbits
NEGATE_NFA:
    .byte 0x86
    .ascii "NEGAT"
    .byte 'E'+0x80
.balign 4, 255
    .word DECIMAL_NFA
NEGATE:
    .word .+5
.section .text, "ax", %progbits
    POP2t // MVN YES
    MVNS t, t // 1's compliment
    ADDS t, t, #1 // 2's compliment
    TPUSH

//     ABS ABS:        ( n -- ub )
//      Leave the absolute value of n as un.

.section .text, "ax", %progbits
ABS1_NFA:
    .byte 0x83
    .ascii "AB"
    .byte 'S'+0x80
.balign 4, 255
    .word NEGATE_NFA
ABS:
    .word DOCOL
    .word DUP
    .word PM
    .word SEMIS

//     MIN MIN:        ( n1 n2 -- min )
//      Leave the smaller of two numbers.

.section .text, "ax", %progbits
MIN_NFA:
    .byte 0x83
    .ascii "MI"
    .byte 'N'+0x80
.balign 4, 255
    .word ABS1_NFA
MIN:
    .word DOCOL, TDUP
    .word GREATERTHAN
    .word ZBRAN
    .word MIN1-.

    .word SWAP
MIN1:
    .word DROP
    .word SEMIS

//     MAX MAX:        ( n1 n2 -- max )
//      Leave the greater of two numbers.

.section .text, "ax", %progbits
MAX_NFA:
    .byte 0x83
    .ascii "MA"
    .byte 'X'+0x80
.balign 4, 255
    .word MIN_NFA
MAX:
    .word DOCOL, TDUP
    .word LESSTHAN
    .word ZBRAN
    .word MAX1-.

    .word SWAP
MAX1:
    .word DROP
    .word SEMIS

//     AND ANDD:       ( n1 n2 -- n2 )
//     Leave the bitwise logical and of n1 and n2 as n3.

.section .text, "ax", %progbits
ANDD_NFA:
    .byte 0x83
    .ascii "AN"
    .byte 'D'+0x80
.balign 4, 255
    .word MAX_NFA
ANDD:
    .word .+5
.section .text, "ax", %progbits
    POP2t
    POP2n
    ANDS t, t, n
    TPUSH

//     OR OR:  ( n1 n2 -- n3 )
//     Leave the bit-wise logical or of n1 and n2 as n3.

.section .text, "ax", %progbits
OR_NFA:
    .byte 0x82
    .ascii "O"
    .byte 'R'+0x80
.balign 4, 255
    .word ANDD_NFA
OR:
    .word .+5
.section .text, "ax", %progbits
    POP2t
    POP2n
    ORRS t, t, n
    TPUSH

//     NOT NOT: ( nl -- n2 )
//     Leave the bitwise logical not of n1 as n2

.section .text, "ax", %progbits
NOT_NFA:
    .byte 0x83
    .ascii "NO"
    .byte 'T'+0x80
.balign 4, 255
    .word OR_NFA
NOT:
    .word .+5
.section .text, "ax", %progbits
    POP2t
    MVNS t, t // 1's compliment
    TPUSH

//     XORR XOR:       ( nl n2 -- n3 )
//     Leave the bitwise logical exclusive or n1 and n2 as n3

.section .text, "ax", %progbits
XORR_NFA:
    .byte 0x83
    .ascii "XO"
    .byte 'R'+0x80
.balign 4, 255
    .word NOT_NFA
XORR:
    .word .+5
.section .text, "ax", %progbits
    POP2t
    POP2n
    EORS t, t, n
    TPUSH

//     SXTH SXTH:      ( nl -- n3 )
//     Sign extend HALFWORD on the stack

.section .text, "ax", %progbits
SXTH_NFA:
    .byte 0x84
    .ascii "SXT"
    .byte 'H'+0x80
.balign 4, 255
    .word XORR_NFA
SXTH:
    .word .+5
.section .text, "ax", %progbits
    POP2t
    SXTH t, t
    TPUSH

//     SXTB SXTB:      ( nl -- n3 )
//     Sign extend byte in the word on the stack

.section .text, "ax", %progbits
SXTB_NFA:
    .byte 0x84
    .ascii "SXT"
    .byte 'B'+0x80
.balign 4, 255
    .word SXTH_NFA
SXTB:
    .word .+5
.section .text, "ax", %progbits
    POP2t
    SXTB t, t
    TPUSH

//     REVW REVW:      ( n -- n )
//     Reverse bytes in n.

.section .text, "ax", %progbits
REVW_NFA:
    .byte 0x84
    .ascii "REV"
    .byte 'W'+0x80
.balign 4, 255
    .word SXTB_NFA
REVW:
    .word .+5
.section .text, "ax", %progbits
    POP2t
    REV t, t
    TPUSH

//     ASR ASR:   ( sn count -- sn' )
//      Shift sn (sign-extended) right by count.
//     Valid count values are 0 to 31.

.section .text, "ax", %progbits
ASR_NFA:
    .byte 0x83
    .ascii "AS"
    .byte 'R'+0x80
.balign 4, 255
    .word REVW_NFA
ASR:
    .word .+5
.section .text, "ax", %progbits
    POP2w
    POP2t
    ASRS t, t, w
    TPUSH

//     LSR LSR:   ( n count -- n' )
//      Logical (zero-extended) shift right by count.
//     Valid count values are 0 to 31.

.section .text, "ax", %progbits
LSR_NFA:
    .byte 0x83
    .ascii "LS"
    .byte 'R'+0x80
.balign 4, 255
    .word ASR_NFA
LSR:
    .word .+5
.section .text, "ax", %progbits
    POP2w
    POP2t
    LSRS t, t, w
    TPUSH

//     LSL LSL:   ( n count -- n' )
//      Logical (zero-extended) shift left by count.
//     Valid count values are 0 to 31.

.section .text, "ax", %progbits
LSL_NFA:
    .byte 0x83
    .ascii "LS"
    .byte 'L'+0x80
.balign 4, 255
    .word LSR_NFA
LSL:
    .word .+5
.section .text, "ax", %progbits
    POP2w
    POP2t
    LSLS t, t, w
    TPUSH

//     .R DOTR:        ( sn1 n2 -- ) SIGNED:
//     Print the signed number sn1 right aligned in a field whose width is n2.
//      No following blank is printed.

.section .text, "ax", %progbits
DOTR_NFA:
    .byte 0x82
    .ascii "."
    .byte 'R'+0x80
.balign 4, 255
    .word LSL_NFA
DOTR:
    .word DOCOL
    .word TOR
    .word STOD
    .word RFROM
    .word DDOTR
    .word SEMIS

//     .RU DOTRU:      ( n1 n2 -- ) UNSIGNED:
//     Print the unsigned number n1 right aligned in a field whose width is n2.
//     No following blank is printed.

.section .text, "ax", %progbits
DOTRU_NFA:
    .byte 0x83
    .ascii ".R"
    .byte 'U'+0x80
.balign 4, 255
    .word DOTR_NFA
DOTRU:
    .word DOCOL
    .word TOR
    .word ZERO
    .word BDIGS, DIGS, EDIGS
    .word DUP, RFROM
    .word SWAP, SUBB, SPACES, TYPE
#ifdef IO2TP
    .word NOOP
    .word CLRPAD
#endif
    .word SEMIS

//     U. UDOT:        ( n -- ) USIGNED DOT

.section .text, "ax", %progbits
UDOT_NFA:
    .byte 0x82
    .ascii "U"
    .byte '.'+0x80
.balign 4, 255
    .word DOTRU_NFA
UDOT:
    .word DOCOL
    .word ZERO
    .word DDOT
    .word SEMIS

//     ? QUES: ( addr -- )
//     Print the value contained at the address in free format according to
//      the current base using DOT.

.section .text, "ax", %progbits
QUES_NFA:
    .byte 0x81
    .byte '?'+0x80
.balign 4, 255
    .word UDOT_NFA
QUES:
    .word DOCOL
    .word AT
    .word DOT
    .word SEMIS

//     . DOT:  ( n -- ) SIGNED 2'S COMPLEMENT:
//     Print a number from a signed 32 bit two's complement value,
//      converted according to the numeric base.
//      A trailing blanks follows.

.section .text, "ax", %progbits
DOT_NFA:
    .byte 0x81
    .byte '.'+0x80
.balign 4, 255
    .word QUES_NFA
DOT:
    .word DOCOL
    .word STOD
    .word DDOT
    .word SEMIS

//------------------------------ DOTBASE SECTION -------------------------------

#ifndef SRM
//     .B DOTBIN:      ( n -- )
//     Prints TOS in BINARY using DOT, not affecting Base in the system

.section .text, "ax", %progbits
DOTBIN_NFA:
    .byte 0x82
    .ascii "."
    .byte 'B'+0x80
.balign 4, 255
    .word DOT_NFA
DOTBIN:
    .word DOCOL
    .word TWO, DOTBASE
    .word SEMIS
#endif // not SRM

//     .H DOTHEX:      ( n -- )
//     Prints TOS in Hex using DOT, not affecting Base in the system
.section .text, "ax", %progbits
DOTHEX_NFA:
    .byte 0x82
    .ascii "."
    .byte 'H'+0x80
.balign 4, 255
#ifdef SRM
    .word DOT_NFA
#else
    .word DOTBIN_NFA
#endif
DOTHEX:
    .word DOCOL
#ifdef SRM
    .word BASE_TO_R12, HEX, UDOT, BASE_FROM_R12
#else
    .word LIT, 16, DOTBASE
#endif
    .word SEMIS

#ifndef SRM
//     .D DOTDEC:      ( n -- )
//     Prints TOS in DECIMAL using DOT, not affecting Base in the system

.section .text, "ax", %progbits
DOTDEC_NFA:
    .byte 0x82
    .ascii "."
    .byte 'D'+0x80
.balign 4, 255
    .word DOTHEX_NFA
DOTDEC:
    .word DOCOL
    .word LIT, 10, DOTBASE
    .word SEMIS
#endif // not SRM

//=============================== WORDCAT ====================================//
//NOEXEC HEADERFORWORDCATEGORIES
//     WC_NUMBERS_NFA = NUMBER Stuff: CATEGORY

.section .text, "ax", %progbits
WC_NUMBERS_NFA:
    .byte 0x80+4+13
    .byte 0x0D
    .byte 0x0A
    .ascii "NUMBER Stuff:"
    .byte 0x0D
    .byte 0x0A+0x80
.balign 4, 255
#ifdef SRM
    .word DOTHEX_NFA
#else
    .word DOTDEC_NFA
#endif
//=============================== UART0_INIT =================================//

// LFA ABOVE NEEDS TO BE WC_NUMBERS_NFA

#if     NXP_M0_11xx | NXP_M0_1115
#include "FISH_NXP_M0_11xx_UART0_INIT.s"
#endif // NXP_M0_11xx

#ifdef NXP_M0_812
#include "FISH_NXP_M0_812_UART0_INIT.s"
#endif // NXP_M0_812

// LFA BELOW NEEDS TO BE UART0_INIT_NFA

//     MYBAUD MYBAUD: ( n -- ) BAUD MUST BE in DECIMAL or EQUIVALENT!!!
//     MUST BE USED BEFORE USING UART0_INIT!!!
//     Because FISH does a reset if you invoke a HARD FAULT RESET
//     THIS MECHANISM IS ESSENTIAL TO STAYING AT USER SET BAUDRATE THRU A RESET!
//     SET NON-INIT RAM VARIABLES DBAUD TO ZERO AND UBAUD n.
//     See UART0_INIT

.section .text, "ax", %progbits
MYBAUD_NFA:
    .byte 0x86
    .ascii "MYBAU"
    .byte 'D'+0x80
.balign 4, 255
    .word UART0_INIT_NFA
MYBAUD:
    .word DOCOL
    .word STRVA, 0, DBAUD
    .word LIT, UBAUD, STORE
    .word SEMIS

//=============================== UART0_INIT =================================//

//     UART0_LSR UART0_LSR: ( -- value ) of NXP M0 UART 0 Line Status Register
//      11xx:
//     0x40008014 Reset value - 0x60 0b1100000
//     After Init SEEING 0x96 FIRST
//
//     BIT 0 = Receiver Data Ready
//     BIT 0 WHEN 0 = U0RBR is empty
//     BIT 0 WHEN 1 = U0RBR contains valid data.
//
//     BIT 4 = Break Interrupt BI when 1
//
//     BIT 5 = Transmitter Holding Register Empty
//     BIT 5 WHEN 0 = U0THR contains valid data
//     BIT 5 WHEN 1 = U0THR is empty.
//
//     BIT 6 = Transmitter Empty
//     BIT 6 WHEN 0 = U0THR and/or the U0TSR contains valid data.
//     BIT 6 WHEN 1 = U0THR and the U0TSR are empty.

//      81x:
//      UART0_STAT // 40064008h UART0 STAT Line Status Register

.section .text, "ax", %progbits
UART0_LSR_NFA:
    .byte 0x89
    .ascii "UART0_LS"
    .byte 'R'+0x80
.balign 4, 255
    .word MYBAUD_NFA
UART0_LSR:
    .word .+5
.section .text, "ax", %progbits
#if     NXP_M0_11xx | NXP_M0_1115
    LDR n, = U0LSR
#endif
#ifdef NXP_M0_812
    LDR n, = UART0_STAT // 40064008h UART0 STAT Line Status Register
#endif
    LDRB t, [n]
    TPUSH
.ltorg

//     UART0_RX UART0_RX: ( -- addr ) of UART 0 RX Buffer
//     This is the serial terminal.

.section .text, "ax", %progbits
UART0_RX_NFA:
    .byte 0x88
    .ascii "UART0_R"
    .byte 'X'+0x80
.balign 4, 255
    .word UART0_LSR_NFA
UART0_RX:
#if     NXP_M0_11xx | NXP_M0_1115
    .word DOCON, U0RBRTHR
#endif
#ifdef NXP_M0_812
    .word DOCON, USART0_RXDAT
#endif

//     UART0_TX UART0_TX: ( -- addr ) of UART 0 TX Buffer
//     This is the serial terminal.

.section .text, "ax", %progbits
UART0_TX_NFA:
    .byte 0x88
    .ascii "UART0_T"
    .byte 'X'+0x80
.balign 4, 255
    .word UART0_RX_NFA
UART0_TX:
#if     NXP_M0_11xx | NXP_M0_1115
    .word DOCON, U0RBRTHR
#endif
#ifdef NXP_M0_812
    .word DOCON, USART0_TXDAT
#endif

#ifdef XON_XOFF
//     XOFF XOFF: ( -- ) Send XOFF

.section .text, "ax", %progbits
XOFF_NFA:
    .byte 0x84
    .ascii "XOF"
    .byte 'F'+0x80
.balign 4, 255
    .word UART0_TX_NFA
XOFF:
    .word .+5
.section .text, "ax", %progbits
#ifdef IO2TP
    NEXT
#else
    BL TXRDY_SUBR
    BL XOFF_SUBR
    NEXT
#endif // #else IO2TP
//#endif // XON_XOFF after XON:

//     XON XON: ( -- ) Send XON

.section .text, "ax", %progbits
XON_NFA:
    .byte 0x83
    .ascii "XO"
    .byte 'N'+0x80
.balign 4, 255
    .word XOFF_NFA
XON:
    .word .+5
.section .text, "ax", %progbits
#ifdef IO2TP
    NEXT
#else
// Required, no 'quick send'
    BL TXRDY_SUBR
    BL XON_SUBR
    NEXT
#endif // #else IO2TP
#endif // XON_XOFF

//---------------- EMIT KEY ?KEY CR SECTION ------------------------------

//     SPACES SPACES:  ( n -- )
//     Transmit n ascii blanks (0x20) to the output device.

.section .text, "ax", %progbits
SPACES_NFA:
    .byte 0x86
    .ascii "SPACE"
    .byte 'S'+0x80
.balign 4, 255
#ifdef XON_XOFF
    .word XON_NFA
#else
    .word UART0_TX_NFA
#endif
SPACES:
    .word DOCOL
    .word ZERO
    .word MAX
    .word ZNDUP
    .word ZBRAN
    .word SPACES_DONE-.

    .word ZERO
    .word XDO

SPACES_DO:
    .word SPACE
    .word XLOOP
    .word SPACES_DO-.

SPACES_DONE:
    .word SEMIS

//     SPACE SPACE: ( -- )
//     Emit a space character, 0x20.

.section .text, "ax", %progbits
SPACE_NFA:
    .byte 0x85
    .ascii "SPAC"
    .byte 'E'+0x80
.balign 4, 255
    .word SPACES_NFA
SPACE:
    .word DOCOL
    .word BLANK
    .word EMIT
    .word SEMIS

//     ID. IDDOT:      ( NFA-addr -- ) ?RENAME .NFA
//     Print a definition's name from its name field address.

.section .text, "ax", %progbits
IDDOT_NFA:
    .byte 0x83
    .ascii "ID"
    .byte '.'+0x80
.balign 4, 255
    .word SPACE_NFA
IDDOT:
    .word DOCOL
//     NOW COUNT is on NFA, fig code copied it out to pad
    .word COUNT
    .word LIT, MAXWORDLEN
    .word ANDD
    .word TYPE
    .word SPACE
    .word SEMIS

//     ." DOTQ:        ( -- ) IMMEDIATE
//     Type quoted string out or compile inline string to be typed at runtime
//     CHANGED COMPILE TIME ACTION TO WORK WITH 4 byte alighment REQUIREMENT.
//     Used in the form:
//             .' CCcc"
//     Compiles an in-line string CCcc (delimited by the trailing ") with
//     an execution proceedure to transmit the text to the output device.
//     If executed outside a definition, ." will immediately print the text
//     until the final ',. The maximum number of characters may be an
//     installation dependent value. See (.").

.section .text, "ax", %progbits
DOTQ_NFA:
    .byte 0x0C2
    .ascii "."
    .byte '"'+0x80
.balign 4, 255
    .word IDDOT_NFA
DOTQ:
    .word DOCOL
    .word LIT, '"'
    .word STATE_SV
    .word AT
    .word ZBRAN
    .word DOTQ1-.

    .word COMP
    .word PDOTQ
    .word WORD
    .word HERE
    .word CAT
    .word ONEP
    .word ALIGNED
    .word ALLOT_PRIM
    .word BRAN
    .word DOTQ2-.
DOTQ1:
    .word WORD
    .word HERE
    .word COUNT
    .word TYPE
// endif
#ifdef IO2TP
    .word NOOP
    .word CLRPAD
#endif
DOTQ2:
    .word SEMIS

//     TYPE TYPE:      ( addr count -- )
//     ADDR must be ALIGNED!
//     OUT MUST BE INITIALIZED!!
//     EMIT COUNT OF 8-bits in a string, preferably ascii characters,
//     (last nfa char (+80h)ok!) from addr thru count,

.section .text, "ax", %progbits
TYPE_NFA:
    .byte 0x84
    .ascii "TYP"
    .byte 'E'+0x80
.balign 4, 255
    .word DOTQ_NFA
TYPE:
    .word DOCOL
    .word ZNDUP
    .word ZBRAN
    .word TYPE1-.

#ifdef XON_XOFF
    .word XOFF
#endif
    .word OVER
    .word PLUS
    .word SWAP
    .word XDO
TYPE2:
    .word I
    .word CATLT7F
    .word EMIT
TT1:
    .word XLOOP
TT2:
    .word TYPE2-.

    .word BRAN
    .word TYPE3-.
TYPE1:
    .word DROP
TYPE3:
    .word SEMIS

//     EMIT EMIT:      ( c -- )
//     Transmit ascii character c to the selected output device. OUT is
//      incremented for each character output.

.section .text, "ax", %progbits
EMIT_NFA:
    .byte 0x84
    .ascii "EMI"
    .byte 'T'+0x80
.balign 4, 255
    .word TYPE_NFA
EMIT:
//------------------------------------------------------------------------------
#ifndef IO2TP
// NOT IO2TP SECTION:
    .word .+5
.section .text, "ax", %progbits
    POP2t // GET CHAR
    BL TXRDY_SUBR
#if     NXP_M0_11xx | NXP_M0_1115
    LDR n, = U0THR // TXD
#endif
#ifdef NXP_M0_812
    LDR n, = USART0_TXDAT // EMIT 4006401Ch TXDAT USART0
#endif
// BSOUT handles negative OUT issue
    STRB t, [n]// EMIT (Send) Char
    LDR n, = OUT // Increment Out
    LDR t, [n]
    ADDS t, t, #1
    STR t, [n]
    NEXT
#else // if IO2TP Transmit char to PAD, increment OUT
//------------------------------------------------------------------------------
// SECTION .text : CONST (2)
    .word .+5
.section .text, "ax", %progbits
    POP2t // Get CHAR
    LDR w, = OUT // Update OUT
    LDR x, [w]// LDRB would limit pad to >255
    LDR n, = PAD
    ADD n, x
    STRB t, [n]// Send CHAR to PAD
//      +!
    ADDS x, x, #1 // +  Increment by 1
    STR x, [w]// ! new OUT value to OUT

    NEXT
#endif // else IO2TP
.ltorg

//     KEY KEY:        (  -- ch )

.section .text, "ax", %progbits
KEY_NFA:
    .byte 0x83
    .ascii "KE"
    .byte 'Y'+0x80
.balign 4, 255
    .word EMIT_NFA
KEY_INTERPRETED_ENTRY:
#ifndef IO2TP
    .word DOCOL
#ifdef XON_XOFF
// EXEC SETS XOFF SO UNDO IT
    .word XON
// TEST XON_XOFF TEMINAL COMPLIANCE WITH KEY .S <CR> Send Break to bypass!
//        DC32    XOFF
#endif
    .word KEY
    .word SEMIS
#else
    .word BL
#endif

//
// NONAME KEY KEY:(-- CH)
// This is the FISH System KEY compiled in the FISH RM
// KEY_INTERPRETED_ENTRY is the user interpreted/compiled hi-level version
// That issues XON  before calling this KEY
KEY:
#ifndef IO2TP
    .word .+5
.section .text, "ax", %progbits
#if     NXP_M0_11xx | NXP_M0_1115
    LDR w, = U0RBR         // RXD
    LDR x, = U0LSR         // Line Status Register
#endif
#ifdef NXP_M0_812
    LDR w, = USART0_RXDAT // 40064014h RXDAT USART0
    LDR x, = UART0_STAT // 40064008h UART0 STAT Line Status Register
#endif
// UART0_STAT / UART0_LSR : BIT 0 = RXRDY FLAG
// A BREAK CONDITION (FROM SINGLE STEPPING) WILL SHOW AS 30h in THE LSR
// WHEN A TERMINAL SENDS A BREAK THE CARRY IS MAGICALLY SET!
// AND THE KEY RECIEVED IS NULL SO NULL IS EXECUTED WITHOUT A CR!
rxRDY_Q:
    LDR n, [x]// Get Line Status
    LSRS n, n, #1 // Char available
    BCC rxRDY_Q // sets carry flag

    LDR t, [w]
    TPUSH
#else
//------------------------------------------------------------------------------
    .word DOCOL, LIT, 0X0D, SEMIS
#endif // else IO2TP
.ltorg

//     ?KEY QKEY: ( -- f )
//     Return zero unless key in fifo - key is not consumed.
//     : TB BEGIN ?BREAK UNTIL

.section .text, "ax", %progbits
QKEY_NFA:
    .byte 0x84
    .ascii "?KE"
    .byte 'Y'+0x80
.balign 4, 255
    .word KEY_NFA
QKEY:
    .word .+5
.section .text, "ax", %progbits
#ifndef IO2TP
#ifdef XON_XOFF // XON in QKEY
    BL TXRDY_SUBR
    BL XON_SUBR
#endif
#if     NXP_M0_11xx | NXP_M0_1115
    LDR x, = U0LSR // Line Status Register
#endif
#ifdef NXP_M0_812
    LDR x, = UART0_STAT // 40064008h UART0 STAT Line Status Register
#endif
    LDR n, [x]// Get Line Status
// UART0_STAT / UART0_LSR : BIT 0 = RXRDY FLAG
    LSRS n, n, #1 // Char available
    BCC NO_KEY // No char, not Ready

// HAVE A KEY - DON'T CONSUME IT
#ifdef TRUE_EQU_NEG_ONE
    EORS t, t // zero t
    SUBS t, #1 // -1
#else
    MOVS t, #1
#endif
    TPUSH

#endif // DEFAULT TO NO KEY IF IO2TP
.thumb_func
NO_KEY:
    EORS t, t // zero t
    TPUSH
.ltorg

//     CRS CRS:        ( n -- )
//      Emit n cr'S (0x0d) and lf (0x0A)

.section .text, "ax", %progbits
CRS_NFA:
    .byte 0x83
    .ascii "CR"
    .byte 'S'+0x80
.balign 4, 255
    .word QKEY_NFA
CRS:
    .word DOCOL
    .word ZERO
    .word XDO
CRS_BEGIN:
    .word CR
    .word XLOOP
    .word CRS_BEGIN-.
    .word SEMIS

//     CR CR:  ( -- )
//      Emit cr (0x0d) and lf (0x0A)

.section .text, "ax", %progbits
CR_NFA:
    .byte 0x82
    .ascii "C"
    .byte 'R'+0x80
.balign 4, 255
    .word CRS_NFA
CR:
#ifdef IO2TP
    .word DOCOL, STRVA, 0, OUT
    .word LIT, msg_cr, NULLSTRLEN, TYPE, SEMIS
#else
    .word DOCOL
    .word STRVA, 0, OUT
    .word PDOTQ
    .byte 2
    .byte 0x0D
    .byte 0x0A
.balign 4, 255
    .word SEMIS
#endif

//=============================== WORDCAT ====================================//
//NOEXEC HEADERFORWORDCATEGORIES
//!!!!!fixx in nxp
//     WC_FISH_IO_NFA = FISH IO: CATEGORY

.section .text, "ax", %progbits
WC_UARTx_NFA:
    .byte 0x80+4+9
    .byte 0x0D
    .byte 0x0A
    .ascii "FISH IO:"
    .byte 0x0D
    .byte 0x0A+0x80
.balign 4, 255
    .word CR_NFA

//     CMSIS_ENABLE_IRQS IRQS_RESUME:  ( -- )
.section .text, "ax", %progbits
IRQS_RESUME_NFA:
    .byte 0x8B
    .ascii "IRQS_RESUM"
    .byte 'E'+0x80
.balign 4, 255
    .word WC_UARTx_NFA
CMSIS_ENABLE_IRQS:
    .word .+5
.section .text, "ax", %progbits
.balign 4, 255
.extern C_CMSIS_ENABLE_IRQS
    BL C_CMSIS_ENABLE_IRQS
    NEXT

//     CMSIS_DISABLE_IRQS IRQS_SUSPEND:        ( -- )
.section .text, "ax", %progbits
IRQS_SUSPEND_NFA:
    .byte 0x8C
    .ascii "IRQS_SUSPEN"
    .byte 'D'+0x80
.balign 4, 255
    .word IRQS_RESUME_NFA
CMSIS_DISABLE_IRQS:
    .word .+5
.section .text, "ax", %progbits
.balign 4, 255
.extern C_CMSIS_DISABLE_IRQS
    BL C_CMSIS_DISABLE_IRQS
    NEXT

//     SYSTICK_IRQ_OFF SYSTICK_IRQ_OFF:        ( -- )
//      Turn SYSTICK interrupt off.
//      STCTR only incremented when SYSTICK interrupt is on.
//      STI_ON: 7 E000E010h !  STI_OFF: 5 E000E010h ! E000E010h @ .H
.section .text, "ax", %progbits
SYSTICK_IRQ_OFF_NFA:
    .byte 0x8F
    .ascii "SYSTICK_IRQ_OF"
    .byte 'F'+0x80
.balign 4, 255
    .word IRQS_SUSPEND_NFA
//        DC32    WC_UARTx_NFA
SYSTICK_IRQ_OFF:
    .word .+5
.section .text, "ax", %progbits
    LDR n, = SYST_CSR // SYSTICK Control and Status Register
    MOVS t, #5
    STR t, [n]
    NEXT
// LTORG        //Always outside of code, else data in words

//     SYSTICK_IRQ_ON SYSTICK_IRQ_ON:  ( -- )
//      Turn SYSTICK interrupt on.
//      STCTR only incremented when SYSTICK interrupt is on.
//      STI_ON: 7 E000E010h !  STI_OFF: 5 E000E010h ! E000E010h @ .H
.section .text, "ax", %progbits
SYSTICK_IRQ_ON_NFA:
    .byte 0x8E
    .ascii "SYSTICK_IRQ_O"
    .byte 'N'+0x80
.balign 4, 255
    .word SYSTICK_IRQ_OFF_NFA
SYSTICK_IRQ_ON:
    .word .+5
.section .text, "ax", %progbits
    LDR n, = SYST_CSR // SYSTICK Control and Status Register
    MOVS t, #7
    STR t, [n]
    NEXT
.ltorg

//=============================== WORDCAT ====================================//
//NOEXEC HEADERFORWORDCATEGORIES
//     WC_IRQ_NFA = INTERRUPTS: CATEGORY

.section .text, "ax", %progbits
WC_IRQ_NFA:
    .byte 0x80+4+11
    .byte 0x0D
    .byte 0x0A
    .ascii "INTERRUPTS:"
    .byte 0x0D
    .byte 0x0A+0x80
.balign 4, 255
    .word SYSTICK_IRQ_ON_NFA
//------------------------------------------------------------------------------
#include "FISH_NXP_M0_FLASH.s"
// LFA BELOW NEEDS TO BE FLASH_FORGET_NFA
//------------------------------------------------------------------------------

//-------------------------- PROMPT VECTOR SECTION -----------------------------

//      POFF ( -- )   Set NULL$ address in PROMPT to zero so quit does CR only.

.section .text, "ax", %progbits
POFF_NFA:
    .byte 0x84
    .ascii "POF"
    .byte 'F'+0x80
.balign 4, 255
    .word FLASH_FORGET_NFA
POFF:
    .word DOCOL
    .word STRVA, 0, PROMPT
    .word SEMIS

//      PON ( -- )   Set NULL$ address in PROMPT to msg_MY_OK

.section .text, "ax", %progbits
PON_NFA:
    .byte 0x83
    .ascii "PO"
    .byte 'N'+0x80
.balign 4, 255
    .word POFF_NFA
PON:
    .word DOCOL
    .word STRVA, msg_MY_OK, PROMPT
    .word SEMIS

//      P ( -- addr )   Address of PROMPT, contains 0 or NULL$ address.

.section .text, "ax", %progbits
P_NFA:
    .byte 0x81
    .byte 'P'+0x80
.balign 4, 255
    .word PON_NFA
P:
    .word DOCON, PROMPT

//-------------------------- ERROR_HALT SECTION -----------------------------

//      EHOFF ( -- )   Set ERROR_HALT to 0

.section .text, "ax", %progbits
EHOFF_NFA:
    .byte 0x85
    .ascii "EHOF"
    .byte 'F'+0x80
.balign 4, 255
    .word P_NFA
EHOFF:
    .word DOCOL, ZERO, LIT, ERROR_HALT, STORE, SEMIS

//      EHON ( -- )   Set ERROR_HALT to 1

.section .text, "ax", %progbits
EHON_NFA:
    .byte 0x84
    .ascii "EHO"
    .byte 'N'+0x80
.balign 4, 255
    .word EHOFF_NFA
EHON:
    .word DOCOL, ONE, LIT, ERROR_HALT, STORE, SEMIS

//-------------------------- DOTDICTSPACE SECTION ------------------------------

//     .DS DOTDICTSPACE:       ( n -- )
//     Prints number of bytes availble in dictionary in DECIMAL using DOT,
//     not affecting Base in the system

.section .text, "ax", %progbits
DOTDICTSPACE_NFA:
    .byte 0x83
    .ascii ".D"
    .byte 'S'+0x80
.balign 4, 255
//     DC32    FLASH_FORGET_NFA
//        DC32    P_NFA
    .word EHON_NFA
DOTDICTSPACE:
    .word DOCOL
    .word DICTSPACE
#ifdef SRM
    .word BASE_TO_R12
    .word DECIMAL, DOT
    .word BASE_FROM_R12
#else
    .word DOTDEC
#endif // SRM
    .word LIT, msg_dictspace
    .word NULLSTRLEN, TYPE
#ifdef IO2TP
    .word NOOP
    .word CLRPAD
#endif
    .word SEMIS

//-------------------------- DOTVARSPACE SECTION -------------------------------

//     .VS DOTVARSPACE:        ( n -- )
//     Prints number of bytes availble in RAM VAR SPACE in DECIMAL using DOT,
//     not affecting Base in the system.

.section .text, "ax", %progbits
DOTVARSPACE_NFA:
    .byte 0x83
    .ascii ".V"
    .byte 'S'+0x80
.balign 4, 255
    .word DOTDICTSPACE_NFA
DOTVARSPACE:
    .word DOCOL
    .word VARSPACE
    .word FOUR, SLASH
#ifdef SRM
    .word BASE_TO_R12
    .word DECIMAL, DOT
    .word BASE_FROM_R12
#else
    .word DOTDEC
#endif // SRM
    .word LIT, msg_uvspace
    .word NULLSTRLEN, TYPE
#ifdef IO2TP
    .word NOOP
    .word CLRPAD
#endif
    .word SEMIS

//     DUMP DUMP:      ( addr n -- )
//     Print adrr and n lines of 4 columns of memory values in hexadecimal.
//     Address must be even and a multiple of 4 else error message issued.
//      QKEY used to abort dump.

.section .text, "ax", %progbits
DUMP_NFA:
    .byte 0x84
    .ascii "DUM"
    .byte 'P'+0x80
.balign 4, 255
    .word DOTVARSPACE_NFA
DUMP:
    .word DOCOL

    .word OVER, QALIGNED
// DON'T SAVE BASE UNTIL AFTER ALIGNED TEST
    .word BASE_TO_R12
    .word HEX
    .word ZERO, XDO
DUMP_ADDR_LINE:
    .word CR
    .word DUP, LIT, 10, DOTRU
    .word FOUR, ZERO, XDO
DUMP_EACH_LOC:
    .word DUP, AT
// Little Endian means addresses will print correctly
// but to see character strings REVW is needed
// but the addresses are scrambled!
//        DC32    REVW                    // Reverse bytes in word
    .word LIT, 14, DOTRU
    .word FOURP
    .word XLOOP
    .word DUMP_EACH_LOC-.

#ifdef IO2TP
    .word NOOP
    .word CLRPAD
#endif
    .word QKEY
    .word ZBRAN
    .word DUMP_CONT-.
    .word LEAVE
DUMP_CONT:
    .word XLOOP
    .word DUMP_ADDR_LINE-.

    .word DROP, CR
    .word BASE_FROM_R12
    .word SEMIS

//     VBASE VBASE:    ( -- addr )
//       Return base addr of VAR's .

.section .text, "ax", %progbits
VBASE_NFA:
    .byte 0x85
    .ascii "VBAS"
    .byte 'E'+0x80
.balign 4, 255
    .word DUMP_NFA
VBASE:
    .word DOCON, RAMVARSPACE_START

//     DBASE DBASE:    ( -- addr )
//     Return base addr of the dictionary.

.section .text, "ax", %progbits
DBASE_NFA:
    .byte 0x85
    .ascii "DBAS"
    .byte 'E'+0x80
.balign 4, 255
    .word VBASE_NFA
DBASE:
    .word DOCON, ORIG

//     RBASE RBASE:    ( -- addr )
//     Return base addr of RAM.

.section .text, "ax", %progbits
RBASE_NFA:
    .byte 0x85
    .ascii "RBAS"
    .byte 'E'+0x80
.balign 4, 255
    .word DBASE_NFA
RBASE:
    .word DOCON, RAM_START

//     CLS CLS:        ( -- )
//     Clear serial terminal screen using a formfeed character

.section .text, "ax", %progbits
CLS_NFA:
    .byte 0x83
    .ascii "CL"
    .byte 'S'+0x80
.balign 4, 255
    .word RBASE_NFA
CLS:
    .word DOCOL
    .word PDOTQ
    .byte 4
    .byte 0x1B
    .ascii "["
    .ascii "2J"
.balign 4, 255
    .word PDOTQ
    .byte 4
    .byte 0x1B
    .ascii "["
    .ascii ";H"
.balign 4, 255
    .word CR
    .word SEMIS

//     ( PAREN:        ( -- ) IMMEDIATE
//     Used in the form:
//             ( CCcc )
//     Ignore comments within parenthesis. A right parenthesis ends comment.
//      The comments may be multi-line but a space or tab is required
//      for any line that is otherwise empty for formatting purposes,
//      else a comment error will be printed. May occur during execution or in a
//     colon-definition. A blank after the leading parenthesis is required.

.section .text, "ax", %progbits
PAREN_NFA:
    .byte 0x0C1
    .byte '('+0x80
.balign 4, 255
    .word CLS_NFA
PAREN:
// Slow Single line comment
//      DC32    DOCOL, LIT, ')', WORD, SEMIS
    .word DOCOL
PML_LOOP:
    .word LIT, ')'
    .word TIB_CHAR_SCAN
//
    .word ZEQU
    .word ZBRAN
    .word PE_DONE-.

// Acting like the outer interpreter here, signal DLE
    .word CR, LIT, 0x10, EMIT
    .word QUERY
//  AND IF ONLY CR (null) ERR
//        DC32    TIB_SV, CAT
    .word LIT, TIB+1, CAT
    .word ZBRAN
    .word PAREN_ERR-.

//  If closing paren not in this line LOOP
    .word BRAN
    .word PML_LOOP-.

PE_DONE:
    .word SEMIS

PAREN_ERR:
    .word LIT, msg_paren_err
    .word NULLSTRLEN, TYPE
    .word SEMIS

//     BACKSLASH BACKSLASH:    ( --  )
//      After a trailing space treat the rest of the line as a comment.
//      By setting a null terminator in TIB

.section .text, "ax", %progbits
BACKSLASH_NFA:
    .byte 0x0C1
    .byte '\\'+0x80
.balign 4, 255
    .word PAREN_NFA
BACKSLASH:
    .word DOCOL
    .word ZERO, TIB_SV, IN_SV, AT, PLUS, CSTORE
    .word SEMIS

//     SYSCLK SYSCLK:  ( -- value )
//      Returns system clock value in Hz, i.e. 48000000 = 48Mhz.

.section .text, "ax", %progbits
SYSCLK_NFA:
    .byte 0x86
    .ascii "SYSCL"
    .byte 'K'+0x80
.balign 4, 255
    .word BACKSLASH_NFA
SYSCLK:
    .word .+5
.section .text, "ax", %progbits
    LDR n, = SYSCLOCK // SystemCoreClock
    LDR t, [n]
    TPUSH // Push -- t
.ltorg

//      STCTR   ( -- addr ) SYSTICK Interrupt increments this with 32but wrap.
//      STI_ON: 7 E000E010h !  STI_OFF: 5 E000E010h ! E000E010h @ .H
.section .text, "ax", %progbits
STCTR_NFA:
    .byte 0x85
    .ascii "STCT"
    .byte 'R'+0x80
.balign 4, 255
    .word SYSCLK_NFA
STCTR:
    .word DOCON, STICKER

//      DELAY ( n value -- ) 7 E000E010h !   5 E000E010h !
.section .text, "ax", %progbits
DELAY_NFA:
    .byte 0x85
    .ascii "DELA"
    .byte 'Y'+0x80
.balign 4, 255
    .word STCTR_NFA
DELAY:
    .word .+5
.section .text, "ax", %progbits
    POP2n     // Reload value in n
    POP2t     // loop count in t
// SET STCTR TO NEGATIVE LOOP COUNT TO END AT ZERO
    LDR y, = STICKER
    MVNS t, t // 1's compliment
    ADDS t, t, #1 // 2's compliment
    STR t, [y]
// Load SYST_RVR with countdown value
    LDR w, = SYST_RVR
    STR n, [w]
// and reset SYST_CVR to start countdown.
    LDR w, = SYST_CVR
// Writing it clears the System Tick counter and the COUNTFLAG bit in STCTRL.
    STR n, [w]
// If n=0 ( in t ) user is just setting reload value
    CMP t, #0 // LOOP OF ZERO
    BEQ DELAY_DONE
// INTERRUPT VERSION: negate n to STCTR and leave when STCTR = 0
// STI_ON: 7 E000E010h !  STI_OFF: 5 E000E010h ! E000E010h @ .H
// Save and restore user interrupt setting
// y = STICKER
    LDR w, = SYST_CSR
    LDR t, [w]// Save user SYSTICK interrupt setting
    MOVS n, #7
    STR n, [w]// Turn SYSTICK interrupt on in case it's off
.thumb_func
DELAY_LOOP:
    LDR n, [y]
    CMP n, #0
    BNE DELAY_LOOP
.thumb_func
DELAY_DONE:
    STR t, [w]// Restore user SYSTICK interrupt setting
    NEXT
.ltorg

//     MS MS: ( n -- ) n * 1 millisecond execution time
//      STI_ON: 7 E000E010h !  STI_OFF: 5 E000E010h ! E000E010h @ .H

.section .text, "ax", %progbits
MS_NFA:
    .byte 0x82
    .ascii "M"
    .byte 'S'+0x80
.balign 4, 255
    .word DELAY_NFA
MS:
    .word DOCOL
#ifdef NXP_M0_11xx_IRC12_48MHZ
    .word LIT, 47999
#endif
#ifdef NXP_M0_812_IRC12_24MHZ
    .word LIT, 23999
#endif
    .word DELAY
    .word SEMIS

//     WORDCAT WORDCAT: ( -- )
//     Creates a Word Category NFA and LFA that cannot be searched for,
//     but is displayed by WORDS and MYWORDS to label a group of Words.
//     Define a group of Words and then add a category name with WORDCAT.
//     EX: WORDCAT MY APP WORDS:
//     It must be on a line of it's own.
//     The colon at the end is FISH convention.
.section .text, "ax", %progbits
WORDCAT_NFA:
    .byte 0x87
    .ascii "WORDCA"
    .byte 'T'+0x80
.balign 4, 255
    .word MS_NFA
WORDCAT:
    .word DOCOL
    .word HERE, TOR
    .word ZERO, CCOMMA
    .word LIT, 0x0D, CCOMMA
    .word HERE
    .word LIT, 0x0D, WORD
    .word DUP, CAT
    .word LIT, 0x0A, ROT, CSTORE
    .word DUP, ONEP, ALLOT
    .word LIT, 0x084
    .word PLUS, R, CSTORE
    .word LIT, 0x0D, CCOMMA
    .word LIT, 0x08A, CCOMMA
    .word ALIGN32_FF_PAD
    .word LATEST, COMMA
    .word RFROM
    .word LIT, CURRENT
    .word STORE
    .word SEMIS

//     WORDS WORDS:    ( -- ) RENAMED: VLIST to WORDS
//      Output list of Words in the dictionary in search order.
//      Uses WC_ nfa's to format Word Categories.
//      Uses FENCE for where to stop.
//      See MYWORDS.

.section .text, "ax", %progbits
WORDS_NFA:
    .byte 0x85
    .ascii "WORD"
    .byte 'S'+0x80
.balign 4, 255
    .word WORDCAT_NFA
WORDS:
    .word DOCOL
    .word THREE, SPACES
    .word LATEST
#ifdef XON_XOFF
    .word XOFF
#endif
VLIS1: // ADD nfa length to current out_uv & verify it doesn't violate csll.

    .word ZERO, OVER
    .word ONEP, CAT
    .word LIT, 0x0D
    .word EQUAL, ZEQU
    .word ZBRAN
    .word WORDS2-.

    .word DROP
    .word DUP, PFA, LFA
    .word OVER, SUBB

WORDS2: // -- nfa n

    .word OUT_SV, AT
    .word PLUS
    .word LIT, 74
    .word GREATERTHAN
    .word ZBRAN
    .word WORD21-.

    .word CR
    .word THREE, SPACES

WORD21:
#ifdef  IO2TP
BP1_WORDS:
    .word NOOP
#endif
// For MYWORDS test FENCE and stop if less
    .word DUP
    .word FENCE_SV, AT
    .word LESSTHAN
    .word ZBRAN
    .word WORDSCONT-.

    .word BRAN
    .word WORDSDONE-.

WORDSCONT:
    .word DUP
    .word IDDOT
    .word TWO, SPACES

    .word DUP, ONEP, CAT
    .word LIT, 0x0D
    .word EQUAL
    .word ZBRAN
    .word NOT_WC-.

    .word STRVA, 0, OUT

NOT_WC:
    .word PFA
    .word LFA
    .word AT
    .word DUP
    .word ZEQU

// REMOVED SO WORDS AND MYWORDS CAN BE USED in DOWNLOAD FILES
//     DC32    QKEY           // Zero or break key ( ^C = 0x03 )
//     DC32    OR

    .word ZBRAN
    .word VLIS1-.

#ifdef  IO2TP
BP2_WORDS:
    .word NOOP
#endif
WORDSDONE:
    .word DROP, CR
    .word SEMIS

//     MYWORDS MYWORDS: ( -- )
//      Print only system defined words by manipulating FENCE.

.section .text, "ax", %progbits
MYWORDS_NFA:
    .byte 0x87
    .ascii "MYWORD"
    .byte 'S'+0x80
.balign 4, 255
    .word WORDS_NFA
MYWORDS:
    .word DOCOL
    .word STRVA, FLASH_SPAGE, FENCE
    .word WORDS
    .word STRVA, 0, FENCE
    .word SEMIS

//     FISH_ONLY FISH_ONLY     ( -- ) MODIFIED:
//      RESET DP, UP AND CURRENT TO ORIGINAL FLASH IMAGE

.section .text, "ax", %progbits
FISH_ONLY_NFA:
    .byte 0x80+9
    .ascii "FISH_ONL"
    .byte 'Y'+0x80
.balign 4, 255
    .word MYWORDS_NFA
FISH_ONLY:
    .word .+5
.section .text, "ax", %progbits
//     LDR     n, = TASK_NFA           // preserve TOS
#ifdef FISH_PubRel_WORDSET
    LDR n, = WC_FISH_PubRel_NFA
#endif
#ifdef FISH_NXP_M0_PRO_WORDCAT
    LDR n, = WC_FISH_PRO_NFA
#endif
    LDR y, = CURRENT // CURRENT SETTING
    STR n, [y]
    LDR y, = FPC // FLASH CURRENT
    STR n, [y]
    LDR n, = RAMVARSPACE_START
    LDR y, = UP // UP SETTING
    STR n, [y]
    LDR y, = FPSV // FLASH USER VARS
    STR n, [y]
    LDR n, = ORIG
    LDR y, = DP // DP SETTING
    STR n, [y]
    NEXT
.ltorg

//     FISH FISH:      ( -- )
//     Print Flash Status and FISH Signon Message.

.section .text, "ax", %progbits
FISH_NFA:
    .byte 0x84
    .ascii "FIS"
    .byte 'H'+0x80
.balign 4, 255
    .word FISH_ONLY_NFA
FISH:
    .word DOCOL
    .word FLASH_SCAN
    .word SIGNON
    .word ABORT

//=============================== WORDCAT ====================================//
//NOEXEC HEADERFORWORDCATEGORIES
//     WC_FISH_PubRel: = FISH Reference Model: CATEGORY
.section .text, "ax", %progbits
WC_FISH_PubRel_NFA:
    .byte 0x80+4+21
    .byte 0x0D
    .byte 0x0A
    .ascii "FISH Reference Model:"
    .byte 0x0D
    .byte 0x0A+0x80
.balign 4, 255
    .word FISH_NFA

//=============================== WORDCAT ====================================//

#ifdef FISH_NXP_M0_PRO_WORDCAT
#include "FISH_NXP_M0_PRO_WORDSET.s"
#endif
// FIRST WORDCAT

//------------------------------------------------------------------------------
// FOR MULTI TASKING MUST BE PLACED in RAM AND OFFSET USED in SYSTEM VARS!!!!!!
//            T A S K
//

/*
.section .text, "ax", %progbits
TASK_NFA:
        .byte 0x84
        .ascii "TAS"
        .byte 'K'+0x80
.balign 4, 255
 //     TASK Is top of dictionary until new definitionsa added
 //     PATCH CONTEXT or LATEST else LFA in TASK FROM SYM TABLE
 //     To debug dictionary searches - see - PFIND & DFIND
 //     DC32    ZEQU_NFA        // 4 (no match) bombing at +
 //     DC32    NOOP_NFA        // Patch here to shorten test of PFIND
 //     DC32    CAT_NFA         // C@ before @
 //     DC32    LESS_NFA        // < before =
 //       DC32  SoCinit_NFA     //XON_NFA               // FULL DICT SEARCH
        .word MS_NFA
TASK:
        .word DOCOL
        .word SEMIS
*/

//------------------------------------------------------------------------------
//  NONAME SECTION:
// THESE STAY HERE (INSTEAD OF SLLIB) BECAUSE THEY ARE CONDITIONALLY INCLUDED
// HI-LEVEL THEM ASM SECTIONS
#ifdef IO2TP
//:
//  NONAME CLRPAD:(--)FILL PAD with BLANK'S.
.section .text, "ax", %progbits
// ALIGNROM 2,0xFFFFFFFF
CLRPAD:
    .word DOCOL, PAD_SV, LIT, IOBUFSIZE
    .word BLANK, FILL
    .word STRVA, 0, OUT
    .word SEMIS
#endif

#ifdef IO2TP
//:
    NONAME CLRTIB:(--)FILL TIB with NULLS to terminate input
.section .text, "ax", %progbits
// ALIGNROM 2,0xFFFFFFFF
CLRTIB:
    .word DOCOL, TIB_SV, LIT, IOBUFSIZE
    .word ERASE
    .word STRVA, 1, IN
    .word SEMIS
#endif

#ifdef USE_CMAIN
//:
    NONAME RET2c:(--)POP main.c saved lr saved in FM0_COLD
.section .text, "ax", %progbits
.balign 4, 255
RET2C:
    .word .+5
.section .text, "ax", %progbits
    LDR t, [sp]
    ADD sp, sp, #4
    MOV pc, t
#endif

#ifdef TESTRAM
//:
    NONAME flogRAM:(--)Non destructively test RAM
// RAM_START and RAM_END defined in FISH_M0_EQUATES.H
.section .text, "ax", %progbits
.balign 4, 255
FLOGRAM:
    .word .+5
.section .text, "ax", %progbits
    MOV r8, t
    MOV r9, n
    MOV r10, i //  SAVE IP !!!
    LDR t, = RAM_START // RAM_START
    LDR y, = RAM_END // (RAM_END +1)            //  limit
.thumb_func
_FLOGRAM:
    LDR x, [t]//  save original contents

    movs n, #0 //  all zeros
    STR n, [t]
    LDR w, [t]
    EORS w, w, n
    BNE _trap

    LDR n, =-1 //  all ones
    STR n, [t]
    LDR w, [t]
    EORS w, w, n
    BNE _trap

    movs n, t //  it's own address
    STR n, [t]
    LDR w, [t]
    EORS w, w, n
    BNE _trap

    MVNS n, t //  complement of it's own address
    STR n, [t]
    LDR w, [t]
    EORS w, w, n
    BNE _trap

    LDR n, =0xFFFFFFFE
    movs i, #32
.thumb_func
_WALKZEROS:
    STR n, [t]
    LDR w, [t]
    EORS w, w, n
    BNE _trap

    lsls n, n, #1
    ADDS n, n, #1
    SUBS i, i, #1
    BNE _walkzeros

    movs n, #1
    movs i, #32
.thumb_func
_WALKONES:
    STR n, [t]
    LDR w, [t]
    EORS w, w, n
    BNE _trap

    lsls n, n, #1
    SUBS i, i, #1
    BNE _walkones

    LDR n, =0xFFFFFFFE
    movs i, #32
.thumb_func
_SLIDEZEROS:
    STR n, [t]
    LDR w, [t]
    EORS w, n
    BNE _trap

    lsls n, n, #1
    SUBS i, i, #1
    BNE _slidezeros

    movs n, #1
    movs i, #32
.thumb_func
_SLIDEONES:
    STR n, [t]
    LDR w, [t]
    EORS w, n
    BNE _trap

    lsls n, n, #1
    ADDS n, n, #1
    SUBS i, i, #1
    BNE _slideones

    STR x, [t]//  restore original contents
    ADDS t, t, #4
    CMP t, y
    BLO _flogRAM

.thumb_func
_NOTRAP:
    MOV t, r8
    MOV n, r9
    MOV i, r10 //  RESTORE IP !!!
    NEXT
.thumb_func
_TRAP:
    B .
.ltorg
#endif // TESTRAM
//------------------------------------------------------------------------------
// Placing blocks that can change at end of link map
// Place :NONAME for static Library first in FISH_NXP_M0_SLIB.s

// $PROJ_DIR$\..\FISH_RM_COMMON
// $PROJ_DIR$\..\FISH_RM_CORTEX_M_COMMON_CODE
// In Assembler preprocessor set additional include directories
#include "FISH_RM_MSGS.h"
// equals below
//#include ".\..\FISH_COMMON_CODE\FISH_RM_MSGS.h"

// SYSTEMCLOCK #define set in FISH_M0_EQUATES.s for SYSCLOCK value.
// THIS IS A :NONAME WORDSET

#if     NXP_M0_11xx | NXP_M0_1115
#include "FISH_NXP_M0_11xx_SOC_INIT.s"
#endif // NXP_M0_11xx

#ifdef NXP_M0_812
#include "FISH_NXP_M0_812_SOC_INIT.s"
#endif // NXP_M0_812
