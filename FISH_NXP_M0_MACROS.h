
 //ss	SET	1	// "single-step" switch for debug/shakedown testing
 //#define ss

 //------------------------------------------------------------------------------
 //	Inner Interpreter Macros
 //	Beauty is you can put any ISA in a macro and no prob till referenced!

 // IF	ss
#ifdef ss
.macro NEXT1
	LDR	x, =ssNEXT1 // meta-single-step for debugging
	BX	x
.endm
 // LTORG

 // ELSE
#else
.macro NEXT1
	LDM	w!, {x} // contents of cfa, (pfa), -> x, bump w to cfa+4
	BLX	x // w preserves cfa+4 (pfa) for DOCOL's benefit
.endm
#endif
 // ENDIF

.macro NEXT_I
	LDM	i!, {w} // get cfa addr to w, incr i after
	NEXT1
.endm

.macro TPUSH_I
	PUSHt // push t to p, pre decrement p
	NEXT_I
.endm

.macro DPUSH_I
	PUSHw // push w to p, pre decrement p
	TPUSH_I
.endm

 //------------------------------------------------------------------------------
 //	SHARED NEXT (size): NEXT/TPUSH/DPUSH are a 2-byte B to the nearest
 //	NEXT_TAILS copy BEFORE the use site (GAS local labels 71b/72b/73b).
 //	Thumb B reaches -2048 B: the assembler errors if a copy is too far,
 //	then add another NEXT_TAILS in a dead spot (between dictionary entries).
 //	*_I variants are the original inline expansions (hot primitives).
 //	Labels 71/72/73 are reserved for NEXT_TAILS in this assembly unit.
.macro NEXT_TAILS
71:	PUSHw // DPUSH entry: push w, fall into TPUSH
72:	PUSHt // TPUSH entry: push t, fall into NEXT
73:	NEXT_I // NEXT entry
.balign 4, 255
.endm

.macro NEXT
	B	73b
.endm

.macro TPUSH
	B	72b
.endm

.macro DPUSH
	B	71b
.endm

 //------------------------------------------------------------------------------
 //      FISH STACK MACRO's
 //	Beauty is you can put any ISA in a macro and no prob till referenced!
 // 	Cortex M0 THUMB only does STMia and LDMia
 //	I (rstack value to pstack) expects POP to be post increment
 //	Meaning that TOS is = to current p or r
 //	Therefore PUSH is pre decrement

.macro PUSHt
	SUBS	p, p, #4 // push t to p, pre decrement p
	STR	t, [p]
.endm

.macro POP2t
#ifndef TOSCT
	LDR	t, [p] // pop tos to t, post increment p
#endif
	ADDS	p, p, #4
.endm

.macro NDPOP2t
	LDR	t, [p]
.endm

.macro PUSHn
	SUBS	p, p, #4 // push n to p, pre decrement p
	STR	n, [p]
.endm

.macro POP2n
	LDR	n, [p]
	ADDS	p, p, #4
.endm

.macro PUSHw
	SUBS	p, p, #4 //  push w to p, pre decrement p
	STR	w, [p]
.endm

.macro POP2w
	LDR	w, [p]
	ADDS	p, p, #4
.endm

.macro NDPOP2w
	LDR	w, [p]
.endm

.macro PUSHx
	SUBS	p, p, #4 //  push x to p, pre decrement p
	STR	x, [p]
.endm

.macro POP2x
	LDR	x, [p]
	ADDS	p, p, #4
.endm

.macro NDPOP2x
	LDR	x, [p]
.endm

.macro PUSHi
	SUBS	p, p, #4 // push i to p, pore increment p
	STR	i, [p]
.endm

.macro POP2i
	LDR	i, [p]
	ADDS	p, p, #4
.endm

.macro PUSHt2r
	SUBS	r, r, #4 //  push t to r, pre decrement r
	STR	t, [r]
.endm

.macro PUSHi2r
	SUBS	r, r, #4 //  push i to r, pre decrement r
	STR	i, [r]
.endm

.macro POPr2i
	LDR	i, [r] //  pop r to i, post increment r
	ADDS	r, r, #4
.endm

 //POP2p	MACRO
 //	ENDM
 //POP2PC	MACRO
 //	ENDM

.macro POPr2t
	LDR	t, [r]
	ADDS	r, r, #4
.endm

.macro PUSHn2r
	SUBS	r, r, #4 //  push t to r, pre decrement r
	STR	n, [r]
.endm

.macro PUSHw2r
	SUBS	r, r, #4 //  push w to r, pre decrement r
	STR	w, [r]
.endm

.macro LIT2t
 // as in xeq token at ToS setup for lit
	LDM	i!, {t} // fetch memory p points to into {t}, inc i
.endm

 // SV val, addr : one STRVAS table entry (cells: addr, val). See STRVAS.
.macro SV val, addr
	.word	\addr, \val
.endm

.macro POPp2w
 // as in xeq token at ToS setup for exec
	LDM	p!, {w} // fetch memory p points to into {w}, inc p
.endm

