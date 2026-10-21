 //-----------------------------------FM0_COLD-----------------------------------

.section .text, "ax", %progbits
.global FM0_COLD
#ifdef USE_CMAIN
.global RET2c
.thumb_func
__iar_program_start:
#endif
 // No MAIN() entry point!
 // :NONAME FM0_COLD ( -- ) Reset Vector entry point. Setup FISH Virtual Machine.
.thumb_func
FM0_COLD:

 //	Set BOD (Power-up Threshold) register to max values.
 //	UM 10398 3.5.26 BOD control register

 //	ldr	t, = BODCTRL		// Set power-up threshold to 2.63v
 //	ldr	n, = 13h		// 10h = enable reset 3 = 2.63v
 //	str	n, [t]

 // Initialize RAM

	ldr	n, = 0x11111111 // fill pattern
	ldr	t, = RAM_START
	ldr	y, = DBAUD // START OF UNINT RAM, @ END OF  CSTACK
.thumb_func
_fillRAM:
	str	n, [t]
	adds	t, t, #4
	cmp	t, y
	blo	_fillRAM

 // Preserve some uninitialized RAM for system use such as MYBAUD

    ldr	t, = ALL_UNINITRAM_END
	ldr	y, = RAM_END
.thumb_func
_fillSTACKS:
	str	n, [t]
	adds	t, t, #4
	cmp	t, y
	blo	_fillSTACKS

#ifdef USE_CMAIN
 //	PUSH lr to sp for BYE
	SUB	sp, sp, #4
	MOV	t, lr
	STR	t, [sp]
#endif

	LDR  	p, =PINIT
	LDR  	r, =RINIT
	ADR	i, FM0_WARM
	PUSHi2r
	NEXT

.ltorg

 //---------------------------------FM0_WARM-------------------------------------
 // :NONAME FM0_WARM ( -- ) Start up FISH interpretation, then outer interpreter.
.section .text, "ax", %progbits
FM0_WARM:
#ifdef TESTRAM
    .word flogRAM
#endif
    .word FWARM
    .word SoCinit
    .word UART0_INIT
    .word CR
WTEST: // TEST CODE GOES HERE
 //        DC32    ILA
 //        DC32    DOTS            // SHOW ANY STACK ARTIFACTS HERE
 // TEST CODE END
	.word LIT, 0xFB, EMIT
	.word LIT, 0xF7, EMIT
	.word COLD
#ifdef USE_CMAIN
	.word RET2c
#endif
 //------------------------ for meta-single-stepping ----------------------------
 //:NONAME ssNEXT ( -- ) System Internal hi level breakpoint.
.section .text, "ax", %progbits
.balign 4, 255
.thumb_func
ssNEXT1:
	LDM	w!, {x} // contents of cfa, (pfa), -> x, bump w to cfa+4
	MOV     pc, x // w preserves cfa+4 (pfa) for DOCOL's benefit

 // STI_ON: 7 E000E010h !  STI_OFF: 5 E000E010h !

 // If BX not ued here and in SUBR's OR LDR t, 7 vs LDR t, =7 CAUSES:
 // Error[Lp002]: relocation failed: value out of range or illegal: 0xfffff457

 // #define required for #if / #ifdef in M0!!!
 // DC32 .+5 or 10...
 //#define ast
.global FM0_SYSTICK_ISR
.section .text, "ax", %progbits
.balign 4, 255
.thumb_func
FM0_SYSTICK_ISR:
#ifdef ast // this is asm prim #else is hi level
 // Start of the working asm isr-------------------------------------------------
 // save what you use
    PUSH    { t, n, lr}
    LDR     n, = STICKER
    LDR     t, [n]
    ADDS    t, t, #1
    STR     t, [n]
 // restore what was being used
    POP     { t, n, pc } // exec lr -> pc
 // End of the working asm isr---------------------------------------------------
.ltorg

 // Cortex MO PUSH and POP is limited r0-r7!!!
 //  PUSH  {r0-r5, lr }
 //  POP   {r0-r5, pc }
 // LABEL FOR HI-LEVEL WORD ISR CREATE WORD!
.section .text, "ax", %progbits
.balign 4, 255
ISR_SEMIS:
	.word .+5
.section .text, "ax", %progbits
	POPr2i // SEMIS to balance DOCOL!!!
 // needed!        POP     { r0-r5, r10-r12, pc }
    POP   {r0-r5, pc }
#else
 // Start of the Hi-Level WORD ISR Test------------------------------------------

 // Exceptions show mostly this:
 // R12 = BASE
 // R11 & R1 (n) = 10000010 b DICTSPACE_START
 // R10 & R0 (t) = 00003BC7 Close to LR value in Debugger upon entry!!!

 // R6 (r) = 7FFFFFFC Typically
 // R7 (s) = 0 Typically

 // ST CTR ? ST ? NOT WORD OR NUMBER   ok, go fish in BASE []
 // Multiple CR exceptions simular, it stops at      ^^^^^^^ !!!!
 // Implicating PFIND and BASE_TO_R12/BASE_FROM_R12  !!!!!!!!!!!!!!!


 // The Hi-Level WORD ISR Pre amble.
.section .text, "ax", %progbits
.balign 4, 255
.thumb_func
DOCOL_ISR:
 // needed!        PUSH    { r0-r5, r10-r12, lr }
    PUSH    {r0-r5, lr }
    MOV     r0, r10
    MOV     r1, r11
    MOV     r2, r12
    PUSH    {r0-r2}

    LDR     w, [PC, #0X4] //= MY_LTORG The High Level Target
	NEXT1 // -> SEMIS_ISR RETURN required instead of SEMIS!

 // LTORG
 // The Hi-Level WORD ISR Post amble.
.section .text, "ax", %progbits
.balign 4, 255
        .word NONAME_STCTR_INCR
MY_LTORG_ISR_SEMIS:
	.word .+5
.section .text, "ax", %progbits
	POPr2i // SEMIS to balance DOCOL!!!
 // needed!        POP     { r0-r5, r10-r12, pc }
    POP     {r0-r2}
    MOV     r10, r0
    MOV     r11, r1
    MOV     r12, r2
    POP     {r0-r5, pc }

 // The test Hi-Level target WORD.
.section .text, "ax", %progbits
.balign 4, 255
NONAME_STCTR_INCR:
    .word DOCOL
    .word ONE, STCTR, PSTORE
 //    DC32    STCTR, QUES   // Works showing longer execution can be done.
 //    DC32    DOTSHEX, CR
    .word MY_LTORG_ISR_SEMIS
 // End of the Hi-Level WORD ISR Test--------------------------------------------
 // NOTE: LTORG manual in this section!
#endif


/*
 //:NONAME ILA
.section .text, "ax", %progbits
.balign 4, 255
ILA:
	.word DOCOL
    .word NOOP
 //	DC32	ASM_START	// HW ISSUE
 //	NOP
 // DC32    ASM_END
	.word SEMIS
*/
