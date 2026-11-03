 // Created FISH_NXP_M0_SLIB.s
 // - To place :NONAME's before dynamic content to make their CFA addresses static.

 //------------------------------------------------------------------------------
 // SECTION HEADER TO ALIGN ALL HI LEVEL CODE - ASM SECTION AT END DIFFERS!
.section .text, "ax", %progbits
.balign 4, 255
	NEXT_TAILS // first shared NEXT copy - must precede every NEXT use
 //------------------------------------------------------------------------------
 //:NONAME BELL:       ( -- ) Emit BELL char.
BELL:
	.word	DOCOL, LIT, 0x07, EMIT, SEMIS

 //:NONAME EIGHT:      ( -- n )
 //= :NONAME BACKSPACE_CHAR:  ( -- n )
EIGHT:
BACKSPACE_CHAR:
	.word	DOCON, 8

 //:NONAME BSOUT:      ( -- ) Emit BACKSPACE char erasing it and maintain OUT.
BSOUT:
	.word	DOCOL
	.word	BACKSPACE_CHAR, EMIT
	.word	SPACE
	.word	BACKSPACE_CHAR, EMIT
	.word	LIT, -3, OUT_SV, PSTORE
	.word	SEMIS

 //------------------------------------------------------------------------------
#ifndef SRM
 //:NONAME DOTSBASE:   ( n -- ) Pass n as base to .S
DOTSBASE:
	.word	DOCOL
	.word	BASE_TO_R12
	.word	BASE_SV, STORE, DOTS
	.word	BASE_FROM_R12
	.word	SEMIS

 //:NONAME PRINT_SUFFIX ( -- ) Print char representing BASE ( b d or h )
PRINT_SUFFIX:
	.word	DOCOL
	.word	BASE_SV, AT, DUP
	.word	TWO, EQUAL
	.word	ZBRAN
	.word	DEC_OR_HEX-.

IS_BIN:
	.word	LIT, 'b', EMIT, DROP
	.word	SEMIS

DEC_OR_HEX:
	.word	LIT, 10, EQUAL
	.word	ZBRAN
	.word	IS_HEX-.

IS_DECIMAL:
	.word	LIT, 'd', EMIT
	.word	SEMIS

IS_HEX:
	.word	LIT, 'h', EMIT
	.word	SEMIS

 //#ifndef SRM
 //:NONAME DOT_BASE_SUFFIX: ( n -- ) DOT with BASE suffix appended.
 // USED in . .D and .SD
.section .text, "ax", %progbits
DOT_BASE_SUFFIX:
	.word	DOCOL
	.word	STOD
	.word	ZERO
	.word	DDOTR
	.word	PRINT_SUFFIX
	.word	SEMIS

 //:NONAME UDOT_BASE_SUFFIX: ( n -- ) UDOT with BASE suffix appended.
 // USED in .B .H .SB AND .SH
UDOT_BASE_SUFFIX:
	.word	DOCOL
	.word	ZERO, ZERO
	.word	DDOTR
	.word	PRINT_SUFFIX
	.word	SEMIS

 //:NONAME DOTBASE:   ( n n -- ) Use TOP n as temporary BASE to output with.
 //       Save current BASE and use n as BASE for this DOT or U.
 //       Used by .B .D and .H
DOTBASE:
	.word	DOCOL
	.word	BASE_TO_R12
	.word	DUP, BASE_SV, STORE
 // IF THIS IS ELIMINATED AND UDOT ONLY USED -1 .D IS 42432762367
	.word	LIT, 10, EQUAL
	.word	ZBRAN
	.word	DBUSEDUDOT-.

	.word	DOT_BASE_SUFFIX

	.word	BRAN
	.word	DBASEDONE-.

DBUSEDUDOT:
	.word	UDOT_BASE_SUFFIX

DBASEDONE:
	.word	SPACE
	.word	BASE_FROM_R12
	.word	SEMIS
#endif // not SRM
 //------------------------------------------------------------------------------

 //:NONAME INITSO_SV:	( -- addr of INITSO )
 //	A system variable that contains the initial value for the stack pointer.
 //	Pronounced S-zero. See SP!
INITSO_SV:
	.word	DOCON, INITSO

 //:NONAME INITRO_SV:	( -- addr of INITRO )
 //	A system variable containing the initial location of the return stack.
 //	Pronounced R-zero. See RP!
INITRO_SV:
	.word	DOCON, INITRO


 //:NONAME CSP_SV:	( -- addr of CSP ) Stack address save for compile error checking
 //       A system variable temporarily storing the stack pointer position, for
 //       compilation error checking.
CSP_SV:
	.word	DOCON, CSP

 //:NONAME HLD_SV:	( -- addr of NHLD ) Holds address of numeric output conversion
 //	A system variable that holds the address of the latest character of
 //	text during numeric output conversion. Usually pad relative.
HLD_SV:
	.word	DOCON, NHLD

 //:NONAME DICTFULL_ABORT ( -- ) Issue Dictionary Full Message and ABORT
DICTFULL_ABORT:
	.word	DOCOL
	.word	LIT, msg_dictfull
	.word	NULLSTRLEN, TYPE
	.word	ABORT

 //:NONAME ALLOT_PRIM: ( un -- ) ALLOT WITHOUT DICTIONARY CHECK
ALLOT_PRIM:
	.word	DOCOL
	.word	DP_SV
	.word	PSTORE
	.word	SEMIS

 //:NONAME COMMA_PRIM ( CFA -- ) COMMA WITHOUT DICTSPACE TEST
COMMA_PRIM:
	.word	DOCOL
	.word	ALIGN32_FF_PAD
	.word	HERE
	.word	STORE
	.word	FOUR
	.word	ALLOT_PRIM
	.word	SEMIS

 //:NONAME QCOMP: ( -- ) Issue error message if not compiling.
QCOMP:
	.word	DOCOL
	.word	STATE_SV
	.word	AT
	.word	ZEQU
	.word	LIT, msg_qcomp
	.word	QERROR
	.word	SEMIS

 //:NONAME QEXEC:	( -- ) Issue error message if not executing.
QEXEC:
	.word	DOCOL
	.word	STATE_SV
	.word	AT
	.word	LIT, msg_qexec
	.word	QERROR
	.word	SEMIS

 //:NONAME QPAIR:	( n1 n2 -- ) Issue an error message if n1 does not equal n2.
 //	The message indicates that compiled conditionals do not match.
QPAIR:
	.word	DOCOL
	.word	SUBB
	.word	LIT, msg_qpair
	.word	QERROR
	.word	SEMIS

 //:NONAME QSTACK:	( -- ) If Stack Error type error message then Abort.
 //	Issue an error message if the stack is out of bounds. This
 //	definition may be installation dependent.
QSTACK:
	.word	DOCOL
 // Underflow if DEPTH < 0. DEPTH reads p directly, so this stays correct
 // if TOS is ever cached in t (SP@-based checks would be one cell late).
	.word	DEPTH, ZLESS
	.word	LIT, msg_qstack
	.word	QERROR
	.word	SEMIS

 //:NONAME PDOTQ:	( -- ) DOTQ run-time
 //      The run-time proceedure, compiled by ." which transmits the
 //      following in-line text to the selected output device. See ."
 //      USE SINGLE QUOTES in SOURCE USAGE!!!!
PDOTQ:
	.word	DOCOL
	.word	RFROM
	.word	DUP, COUNT, TYPE
	.word	COUNT, PLUS
	.word	ALIGNED
	.word	TOR
	.word	SEMIS

 //:NONAME QUERY:	( -- ) Use Expect to fill TIB
 //	Input characters into TIB as a NULL terminated string using EXPECT.
 //      TIB is filled until CR/EMTER or count argument to EXPECT is reached.
 //      IN is set to zero and the string in TIB is NULL terminated.
QUERY:
	.word	DOCOL
	.word	TIB_SV
	.word	LIT, IOBUFSIZE-2
	.word	EXPECT
	.word	STRVA, 1, IN
#ifdef  IOBUFS_DEBUG
	.word	TIB_SV, ONE, DUMP
#endif
	.word	SEMIS

 //:NONAME PNUMBER:	( 0 0 addr1 -- d addr2 )
 //                      ( 0 0 addr1 -- LSW MSW addr2=addr1+chars )
 //	Convert the ascii text beginning at addr1+l
 //	with regard to BASE into a 64 bIt unsigned number d.
 //	Addr2 is the address of the first unconvertable digit, usually space
 //      or NULL.
 //	Used by NUMBER.
PNUMBER:
	.word	DOCOL
PNUM1: // Begin
	.word	ONEP
	.word	DUP, TOR
	.word	CAT
	.word	BASE_SV, AT
	.word	DIGIT
 // | ( 0 0 0 (bad))
 // digit gets 0, 0x20 or 0x2E and returns 0 then branches to fromr semis...
	.word	ZBRAN
	.word	PNUM2-.

	.word	SWAP
	.word	BASE_SV, AT
 //	U* (un un --  ud=<LSW MSW> )
	.word	USTAR
	.word	DROP
	.word	ROT
	.word	BASE_SV, AT
	.word	USTAR
	.word	DPLUS
	.word	DPL_SV, AT, ONEP
	.word	ZBRAN
	.word	PNUM3-.

	.word	ONE, DPL_SV, PSTORE

PNUM3: // endif
 // ( 0 0 <c | 0> -- )
	.word	RFROM
	.word	BRAN
	.word	PNUM1-.

PNUM2:
	.word	RFROM
	.word	SEMIS

 //:NONAME DFIND:	( --- pfa len tf )(found)
 //		        ( --- ff ) (not found)
 //	Accepts the next text word (delimited by blanks) in the input stream
 //      to HERE, and searches the CONTEXT and then CURRENT vocabularies
 //      for a matching entry. If found, the dictionary entry's parameter
 //      field address, its length byte, and a boolean true is left.
 //      Otherwise, only a boolean false is left.
 //      DFIND LEN HAS TO BE smudged header byte for INTERPRET.
DFIND:
	.word	DOCOL
#ifdef IO2TP
TIB_INPUT_HERE_IN_DFIND:
	.word	NOOP
#endif
	.word	BLANK
	.word	WORD
	.word	HERE
#ifdef  IOBUFS_DEBUG
	.word	DUP, ONE, DUMP
#endif
	.word	LATEST
	.word	PFIND
 // | ( txt nfa -- 0 ) (bad)
	.word	SEMIS

 //:NONAME COMP:	( -- ) Compile CFA of word that follows inside a definition.
 // DOTQ: DO: LOOP: PLOOP: LITERAL: DLITERALl COLON: SEMIS:
 // DO DICTSPACE CHECK, AS DOES COMMA, CCOMMA and ALLOT
 // SO COMMA_PRIM CREATED AND USED HERE FOR COMPILER SPEEDUP
 //	Compile CFA of word that follows.
 //	When the word containing COMPILE executes, the execution address of
 //      the word following COMPILE is copied (compiled) into the dictionary.
 //      This allows specific compilation situations to be handled in
 //      addition to simply compiling an execution address (which the
 //      interpreter already does).
COMP:
	.word	DOCOL
 //	DC32	QEXEC   // QCOMP
	.word	RFROM
	.word	DUP
	.word	FOURP
	.word	TOR
	.word	AT
 //	DC32	COMMA	// ALIGNED, INCREMENTS DP REFLECTED by HERE
	.word	COMMA_PRIM
	.word	SEMIS

 //:NONAME MSMOD:	( ud1 n2 -- n3 ud4 )
 //      An unsigned mixed magnitude math operation which leaves a double
 //      quotient ud4 and remainder u3, from a double dividend ud1 and single
 //      divisor u2. Primarily used in pictured numeric output DIG
MSMOD:
	.word	DOCOL
	.word	TOR
	.word	ZERO
	.word	R
	.word	USLASH
	.word	RFROM
	.word	SWAP
	.word	TOR
	.word	USLASH
	.word	RFROM
	.word	SEMIS

 //:NONAME SCSP:	( -- ) Save the parameter stack position in CSP.
 //      Part of the compiler security.
 //	Means Store (save) Compile time stack position.
SCSP:
	.word	DOCOL
	.word	SPAT
	.word	CSP_SV
	.word	STORE
	.word	SEMIS

 //:NONAME QCSP: ( -- ) Issue error message if stack and CSP don't match.
 //      Indicates unbalanced compilation. Part of compiler security
QCSP:
	.word	DOCOL
	.word	SPAT
	.word	CSP_SV
	.word	AT
	.word	SUBB
	.word	LIT, msg_qstack
	.word	QERROR
	.word	SEMIS

 //:NONAME INTERPRET:	( -- ) The space delimited text Token Interpreter
 //	Find or convert a text token then execute it's semantics or compile it,
 //      depending on STATE. The token text is from the TIB.

 //	If the token cannot be found in a dictionary (by a search of CURRENT),
 //	an attempt to converte it to a number according to the current base.
 //      is tried. That also failing, an error message will TYPE and ABORT.

 //	Text input will be taken according to the convention for WORD. If a
 //	decimal point is found as part of a number, a double number value
 //	will be left. The decimal point is saved in DPL but otherwise
 //	has no other purpose than to force this action.
 //	See NUMBER.
INTERPRET:
	.word	DOCOL
INTE1: // Begin
	.word	DFIND
 //	-FIND ( --- pfa len tf )(found) ( --- ff ) (not found)
	.word	ZBRAN
	.word	INTE2-.

	.word	STATE_SV
	.word	AT
	.word	LESSTHAN
	.word	ZBRAN
	.word	INTE3-.

	.word	CFA
	.word	COMMA_PRIM
	.word	BRAN
	.word	INTE4-.

INTE3:
	.word	CFA
	.word	EXEC
INTE4:
	.word	QSTACK
	.word	BRAN
	.word	INTE1-.

INTE2:
	.word	HERE
	.word	NUMBER
	.word	DPL_SV
	.word	AT
	.word	ONEP
	.word	ZBRAN
	.word	INTE6-.

	.word	DLITERAL
	.word	BRAN
	.word	INTE7-.

INTE6:
	.word	DROP
	.word	LITERAL

INTE7:
	.word	QSTACK

INTE5:
	.word	BRAN
	.word	INTE1-.

 //:NONAME QUIT:	( -- ) The Outer Interpreter.
 //	THE OUTER INTERPRETER WAITS FOR INPUT
 //	THEN CONVERTS NUMBERS AND EXECUTES WORDS
 //	Clear the return stack, stop compilation, and return control to the
 //	operators terminal. No message is given.
QUIT:
	.word	DOCOL
	.word	LBRAC
	.word	SPSTO
QUIT1: // Begin
#ifdef IO2TP
	.word	CLRPAD
#endif
	.word	RPSTO
	.word	QUERY
	.word	INTERPRET
#ifdef IO2TP
	.word	NOOP
	.word	CLRPAD
#endif
 // ISSUE INLY CR IF COMPILING OR IF PROMPT: SET TO 0 WITH POFF(PROMPTOFF)
	.word	STATE_SV
	.word	AT
	.word	ZEQU
	.word	ZBRAN
	.word	QUIT2-.

 // v1.7 new feature to vector the system prompt
 // zero means only cr with every line - for download suppression of all but errs
	.word	LIT, PROMPT, AT
	.word	ZBRAN
	.word	QUIT2-.

 // PROMPT$ is not zero
	.word	LIT, PROMPT, AT
 //        DC32    LIT, msg_MY_OK
	.word	NULLSTRLEN, TYPE
 //------------------------------------------------------------------------------
#ifdef SRM
 // use this code so the SRM prompt can act like DOTDEC output
	.word	BASE_TO_R12
	.word	BASE_SV, AT
	.word	DECIMAL, DOT
	.word	BASE_FROM_R12
#else
	.word	BASE_SV, AT
	.word	DOTDEC
#endif

 //------------------------------------------------------------------------------
BP1_QUIT:
#ifdef IO2TP
	.word	NOOP
	.word	CLRTIB
	.word	CLRPAD
#endif
QUIT2:
#ifdef EOL_DLE
QUIT_EOL_DLE:
	.word	LIT, 0x10, EMIT
 //        DC32    LIT, 0xFE, EMIT // 255d BLACK SQUARE or '|o' in EOL_DLE
#endif
	.word	CR
	.word	BRAN
	.word	QUIT1-.

 //:NONAME BACK:	( addr -- ) Branch back primitive
 //	Calculate the backward branch offset from HERE to addr and compile
 //      into the next available dictionary memory address.
BACK:
	.word	DOCOL
	.word	HERE
	.word	SUBB
	.word	COMMA
	.word	SEMIS

 //:NONAME SEMIC_CREATE:      ( -- ) Used after CREATE to reset CSDP
 //      Used in
 //      Words that have errors during compilation.
SEMIC_CREATE:
	.word	DOCOL
	.word	STRVA, 0, CSDP
	.word	SEMIS

 //:NONAME CSDP_SV ( -- addr of CSDP ) Holds where to reset if definition fails
CSDP_SV:
	.word	DOCON, CSDP

 //:NONAME	PM:  ( n1 n2 -- n3 ) Apply the sign of n2 to n1, which is left as n3.
PM:
	.word	DOCOL
	.word	ZLESS
	.word	ZBRAN
	.word	PM1-.

	.word	NEGATE
PM1:
	.word	SEMIS

 //:NONAME	DPM: ( d1 n -- d2) Apply the sign of n to the double number d1.
DPM:
	.word	DOCOL
	.word	ZLESS
	.word	ZBRAN
	.word	DPM1-.

	.word	DNEGATE
DPM1:
	.word	SEMIS

 //:NONAME SIGNON:     ( -- ) type SIGNON message.
SIGNON:
	.word	DOCOL
#ifdef IO2TP
	.word	NOOP
	.word	STRVA, 0, OUT
#endif
	.word	CR, LIT, msg_FISH
	.word	NULLSTRLEN, TYPE
#ifdef SRM
	.word	CR
#endif
#if !defined(SRM) && !defined(FISH_NO_TIMESTAMP)
	.word	LIT, msg_FISH_TIMESTAMP
	.word	NULLSTRLEN, TYPE
#endif
#ifdef EOL_DLE
	.word	LIT, msg_SIGNON_DLE
	.word	NULLSTRLEN, TYPE
#endif
#ifndef SRM
	.word	CR
#endif
#ifdef IO2TP
	.word	NOOP
	.word	CLRPAD
#endif
	.word	SEMIS

 //:NONAME WARM:       ( -- ) Perform FWARM and FLASH_SCAN
 //      SYSTEM RAMVARSPACE INIT
 //      Patch in FLASH_SAVE'd Code.
WARM:
	.word	DOCOL
	.word	FWARM
	.word	FLASH_SCAN
	.word	SEMIS

 //:NONAME	TRAVERSE TRAVERSE: ( addr1 n -- addr2 ) Used in NFA and PFA
 //	USED only in NFA and PFA, padding alignment is done there.
 //	Move across a variable length padding aligned name field with smudged 1rst and last byte.
 //	addr1 is the address of either the length byte or the last letter.
 //      If n=1, the motion is toward nfa - hi memory, if n=-l, the motion is
 //      toward CFA - low memory. The addr2 resulting is address
 //	of the other end of the name.
TRAVERSE:
	.word	DOCOL
	.word	SWAP
TRAVERSE_BEGIN:
	.word	OVER
	.word	PLUS
	.word	LIT,0x7F
	.word	OVER
	.word	CAT
	.word	LESSTHAN
	.word	ZBRAN
	.word	TRAVERSE_BEGIN-.

	.word	SWAP
	.word	DROP
	.word	SEMIS

 //------------------------------------------------------------------------------
 // ASM CODE START - MUST BE ALLIGNED AGAIN
/* AS in:
.section .text, "ax", %progbits
.balign 4, 255
LABEL:
	.word .+5
.section .text, "ax", %progbits
        ASM     CODE
*/
 //------------------------------------------------------------------------------
 //:NONAME SECTION:
 //:NONAME SV_INIT_VALUES: Table of FISH SYSTEM VAR Iinitial values.
.section .text, "ax", %progbits
.balign 4, 255
SV_INIT_VALUES:
 // 4 words of System Variables
	.word	DEFAULT_BASE
	.word	1
	.word	0
	.word	0
 // 5 addresses of System Data Structures
	.word	PINIT
	.word	RINIT
	.word	TIB
	.word	RAMVARSPACE
	.word	ORIG
 // 4 addresses of System Pointers
	.word	0
	.word	0
#ifdef FISH_PubRel_WORDSET
	.word	WC_FISH_PubRel_NFA
#endif
#ifdef FISH_NXP_M0_PRO_WORDCAT
	.word	WC_FISH_PRO_NFA
#endif
	.word	msg_MY_OK
	.word	0
 // 14d WORDS TO COPY


 //:NONAME FWARM   ( -- ) FISH SYSTEM VAR Initialization primitive.
.section .text, "ax", %progbits
.balign 4, 255
FWARM:
	.word	.+5
.section .text, "ax", %progbits
	LDR	t, = SV_INIT_VALUES
	LDR	n, = END_RAMVARSPACE_SV_START
	LDR	w, = 14
.thumb_func
FWBEGIN:
	LDR	x, [t]
	STR	x, [n]
	ADDS	t, #4
	ADDS	n, #4
	SUBS	w, #1
	BNE	FWBEGIN
	NEXT
.ltorg

 //:NONAME DOCOL   ( -- )  COMPILED VERSION OF COLON
.section .text, "ax", %progbits
.balign 4, 255
.thumb_func
DOCOL: // no cfa for DOCOL!!!!!	<<<<<<<<<<<<<<<<<<
	PUSHi2r // save IP to Rstack
	MOV	i, w // jam new IP = cfa+4
	NEXT

 //:NONAME SEMIS:	( -- ) COMPILED VERSION OF SEMICOLON
 //      Terminate a colon-definition,
 //	: pushed the calling word return addr to the return stack
 //	This retrieves it and returns to calling word.
.section .text, "ax", %progbits
.balign 4, 255
SEMIS:
	.word	.+5
.section .text, "ax", %progbits
	POPr2i // pop docol saved IP from Rstack
	NEXT

 //:NONAME DOVAR   ( -- ) COMPILED VERSION OF VAR
 // VAR is a CON but DOVAR is 'duplicated' to allow search for it's CFA
 // so FORGET can reclaim VAR space.
.section .text, "ax", %progbits
.balign 4, 255
.thumb_func
DOVAR:
	LDM	w!, {t}
	TPUSH

 //:NONAME DOCON   ( -- ) COMPILED VERSION OF CON
.section .text, "ax", %progbits
.balign 4, 255
.thumb_func
DOCON:
	LDM	w!, {t}
	TPUSH

 //:NONAME LIT:        ( -- n ) The primitive that pushes a number in a definition.
 //      Within a colon-definition, LIT is automatically compiled before each
 //      32 bit literal number encountered in input text. Later execution of
 //      LIT causes the contents of the next dictionary address ( the LITERAL #)
 //      to be pushed to the stack.
 //      Use LITERAL
.section .text, "ax", %progbits
.balign 4, 255
LIT:
	.word	.+5
.section .text, "ax", %progbits
	LIT2t // LDM		i!, {t}
 // fetch memory i points to into {t}, inc i after
	TPUSH

 //:NONAME RLIT:	( -- n ) LIT primitive that can have it's value relocated.
 //	SEE LIT. ALLOWS RELOCATION OF THIS type OF LIT
.section .text, "ax", %progbits
.balign 4, 255
RLIT:
	.word	.+5
.section .text, "ax", %progbits
	LIT2t // LDM		i!, {t}
 // fetch memory i points to into {t}, inc i after
	TPUSH

 //:NONAME GOTO:   ( cfa -- ) Redirect execution to cfa in another hi-level word.
 //	CAUTION!!!!!!! A SYSTEM WORD EXPOSED FOR THE BOLD AND BRAVE!!!!!!!
 //	Stack in CURRENT WORD MUST BE CLEANED UP!
 //	AND STACK MUSTE BE SET UP as expected where you GOTO.
 //	YOU CANNOT VIOLATE controls structure (LOOPS, BEGINs IFs, etc).
 //	Unless you come from the same point in the same control structure!
.section .text, "ax", %progbits
.balign 4, 255
GOTO:
	.word	.+5
.section .text, "ax", %progbits
	POP2i // set i as pointer to cfa to start execution
	NEXT

 //:NONAME CREATE_DOES_GOTO:   ( -- )
 //      PUSH ADDRESS OF CREATED WORDS PFA THEN
 //      Redirect execution to cfa of the CREATE DOES> word.
 //      THIS IS LIKE A DOCON IE NO DOCOL!!!!
 //	CAUTION!!!!!!! A SYSTEM WORD EXPOSED FOR THE BOLD AND BRAVE!!!!!!!
 //	Stack in CURRENT WORD MUST BE CLEANED UP!
 //	AND STACK MUSTE BE SET UP as expected where you GOTO.
 //	YOU CANNOT VIOLATE controls structure (LOOPS, BEGINs IFs, etc).
 //	Unless you come from the same point in the same control structure!
.thumb_func
CREATE_DOES_GOTO:
.section .text, "ax", %progbits
 // WILL NEED A NEW CASE in FLASH_SAVE!
 // NO DOCOL - SO FUDGE ONE
 // PUSH ADDR AFTER EXEC in INTERPRET TO r:
	PUSHi2r // save IP to Rstack
 // NEXT1 leaves w = cfa+4 (t is user TOS, never the cfa - IAR-era bug)
 // AND THIS LOADS GOTO ADDR
	LDR	i, [w] // GET GOTO ADDRESS = [cfa+4]
 // THIS PUSHES PFA
	ADDS	w, w, #4 // COMPUTE REAL PFA = cfa+8
	PUSHw
	NEXT

 //:NONAME DICTSPACE:  ( -- n ) Calculate and push dictionary space available
.section .text, "ax", %progbits
.balign 4, 255
DICTSPACE:
	.word	.+5
.section .text, "ax", %progbits
	LDR	t, = DICTSPACE_END
	LDR	n, = DP
	LDR	n, [n]
	SUBS	t, t, n
	TPUSH
 // LTORG

 //:NONAME VARSPACE:    ( -- n ) Calculate and push VAR space available
.section .text, "ax", %progbits
.balign 4, 255
VARSPACE:
	.word	.+5
.section .text, "ax", %progbits
	LDR	t, = END_RAMVARSPACE_SV_START
	LDR	n, = UP // UP IS ALLOCATION POINTER FOR VARS AND VARALLOT
	LDR	n, [n]
	SUBS	t, t, n
	TPUSH
.ltorg

 // Rewrite for TOSCT interop?
 //:NONAME PFIND:	( addr1 addr2 -- pfa b tf ) (ok)
 //              ( addr1 addr2 -- ff ) (bad)
 //      LEN HAS TO BE smudged header byte for INTERPRET.
 //	Header LEN BYTE REQUIRED by Interpret for immediate word execution
 //	Searches the dictionary starting at the name field address addr2,
 //      matching to the text at addr1. Returns parameter field address,
 //      length byte of name field and boolean true for a good match. If no
 //      match is found, only a boolean false is left.
 //
 //	To step thru to a word set bp at :NONAME
 //	and watch r3 for match of word addr from symbol file
.section .text, "ax", %progbits
.balign 4, 255
PFIND:
	.word	.+5
.section .text, "ax", %progbits
	POP2x // r3 Dict Name NFA
	POP2w // r2 String Addr usually at here
	MOV	rb, w // r11 Save TXT String ADDR

 //	SEARCH LOOP
 //	nfa length test
 //      x must = Dict nfa
.thumb_func
PFIN1: // ADDR-->char counted strings
	MOV	w, rb // restore txt str addr
	LDRB	t, [x] // GET nfa LENGTH from r3
 //      LEN HAS TO BE smudged header byte for DFIND -> INTERPRET.
 //      ELSE DO THIS HERE TO MAKE IT ACTUAL & REMOVE SECTION BELOW
 //	MOVS	y, #0x3F
 //	ANDS	t, y
	MOV	k, t // r12 Save search word length
	LDRB	n, [w] // r1 r2 TXT WORD LEN
	EORS	t, t, n
	MOVS	y, # 0x03F
	ANDS	t, y
	BNE	PFIN5 // Len mismatch, GET NEXT LINK FIELD ADDR (lfa)

 //	LENGTHS MATCH - CHECK EACH CHARACTER in NAME
 // 	TEST FIRST CHAR AND DETERMINE IF LAST
.thumb_func
PFIN2:
	ADDS	w, w, #1 // str
	ADDS	x, x, #1 // nfa
	LDRB	t, [x] // GET nfa 1RST CHAR
	LDRB	n, [w] // GET TXT 1RST CHAR
	CMP	t, n // eor was working but this make 0x80 subb
	BEQ	PFIN2 // matched try next char

	MOVS	y, #0x80
	SUBS	t, t, y // ascii only in t and n
	cmp	t, n
	BNE	PFIN51 // goto  WORD MISMATCH

 //      FOUND END OF NAME (BIT 8 SET) - A MATCH
 //      GET to pfa of found word
.thumb_func
PFIN21:

	ADDS	x, x, #1 // Dict addr
	LDRB	t, [x]
	CMP	t, #0xFF
	BEQ	PFIN21

.thumb_func
thispfa:

	ADDS	x, x, #8 // at cfa -> pfa
	PUSHx // PUSH pfa
	MOVS	t, #1 // TRUE VALUE
	MOV	w, k // RETURN Header Byte LENGTH
	DPUSH

 //	NO NAME MATCH - TRY ANOTHER
 //      Set NEXT LINK FIELD ADDR (lfa) to x
 //      ( ZERO = FIRST WORD OF DICTIONARY )
 //      GET TO END OF NAME BEFORE Padding IF ANY
 //      ENTER HERE FROM LEN!= (RB->CNT)
.thumb_func
PFIN5:
	ADDS	x, x, #1 // inc char in name addr

 //      ENTER HERE FROM WORD MISMATCH
.thumb_func
PFIN51:
	LDRB	t, [x] // get Dict Word char
	MOVS	y, #0x80
	TST	t, y // is last char in word bit set
	BEQ	PFIN5

 //      UNMATCHED NAME - POINTING AT LAST CHAR BEFORE Padding IF ANY
 //      GET PAST FF Padding AND GET lfa
.thumb_func
PFIN7:
 // Code for ALIGNED
 //	ADDS		x, x, #3
	ADDS	x, x, #4 // add 1 for entry
	LDR	t, =-4
	ANDS	x, x, t
	LDR	x, [x] // r3 GET lfa to next word
	CMP	x, #0 // START OF DICT ( 0 ) ?
	BEQ	WORDNOTFOUND

 // NOT A BRAN TARGET - This one used for breakpoint
.thumb_func
PFIND_NEXT_NFA:
	B	PFIN1 // Search next word x must = Dict nfa

.thumb_func
WORDNOTFOUND: // PFIND: DONE ( NO MATCH FOUND )
	MOVS	t, #0
	TPUSH
.ltorg

 //:NONAME BRAN:	( -- ) Branch in definitions primitive
 //      In IAR branch target MUST BE ON Next LINE!!!<<<<<<<<<<<<<<<<<<<<<<<<
 //      The run-time proceedure to unconditionally branch. An in-line offset
 //	is added to the interpretive pointer IP to branch ahead or back.
 //	BRANCH is compiled by ELSE, AGAIN, REPEAT.
.section .text, "ax", %progbits
.balign 4, 255
BRAN:
	.word	.+5
.section .text, "ax", %progbits
.thumb_func
BRAN1:
	LDR	x, [i] // Get branck target
	ADDS	i, i, x // use as offset
	NEXT

 //:NONAME ZBRAN:	( f -- ) Branch if zero definition primitive.
 //      In IAR branch target MUST BE ON Next LINE!!!<<<<<<<<<<<<<<<<<<<<<<<<
 //	The run-time proceedure to conditionally branch. If f is false
 //	(zero), the following in-line parameter is added to the interpretive
 //	pointer to branch ahead or back. Compiled by IF, UNTIL, and WHILE.
.section .text, "ax", %progbits
.balign 4, 255
ZBRAN:
	.word	.+5
.section .text, "ax", %progbits
	POP2t
	CMP	t, #0 // ZERO?
#ifdef TOSCT // CMP CONSUMES t
	LDR	t, [p] // REFRESH t
#endif
	beq	BRAN1 // YES, BRANCH

	ADDS	i, i, #4 // NO - CONTINUE...
	NEXT

 //:NONAME XLOOP:	( -- ) Loop primitive in a definition.
 //      The run-time proceedure compiled by LOOP which increments
 //	the loop index by one and tests for loop completion.
 //      See LOOP.
.section .text, "ax", %progbits
.balign 4, 255
XLOOP:
	.word	.+5
.section .text, "ax", %progbits
	MOVS	x, #1
.thumb_func
XLOO1:
 // Get Limit and Index from r w/o popping them
	LDR	y, [r, #4] // Limit
	LDR	w, [r] // Index
	CMP	y, w // If equal
	BEQ	XLOO2 // done

	adds	w, w, x // INDEX = INDEX + INCR
	str	w, [r] // Put it back by overwrite for I
	SUBS	y, y, w
	BNE	BRAN1 // End of `DO' LOOP
.thumb_func
XLOO2:
 // Drop Limit and Index, increment i
	ADDS	r, r, #8
	ADDS	i, i, #4
	NEXT

 //:NONAME XPLOOP:	( n -- ) +LOOP primitive in definitions.
 //      The run-time proceedure compiled by +LOOP, which increments the loop
 //      index by n and tests for loop completion. See +LOOP.
.section .text, "ax", %progbits
.balign 4, 255
XPLOOP:
	.word	.+5
.section .text, "ax", %progbits
	POP2x // GET LOOP VALUE
#ifdef TOSCT
	LDR	t, [p]
#endif
	b	XLOO1 // see XLOO1 for why it's put in x

 //:NONAME XDO:	( Limit Index -- ) The DO primitive in definitions.
 //	( Limit = addr+cnt Index = addr  -- ) as in ( TIB+LEN TIB -- )
 //      The run-time proceedure compiled by DO which moves the loop control
 //      parameters to the return stack. See DO.
.section .text, "ax", %progbits
.balign 4, 255
XDO:
	.word	.+5
.section .text, "ax", %progbits
	POP2t // INITIAL INDEX VALUE = ADDR
	POP2w // LIMIT VALUE = ADDR+CNT
	PUSHw2r
	PUSHt2r // i expects index TOP of RSTACK
#ifdef TOSCT
	LDR	t, [p] // REFRESH t
#endif
	NEXT

 //:NONAME CATLT7F  ( addr -- c ) Get char at addr then AND it with 7Fh
.section .text, "ax", %progbits
.balign 4, 255
CATLT7F:
	.word	.+5
.section .text, "ax", %progbits
	POP2t
	LDRB	t, [t]
	LDR	n, =0x7F
	ANDS	t, t, n
	TPUSH

 //:NONAME TIB_CHAR_SCAN   ( c -- f ) Scan TIB for c or until null found.
 // Scan TIB, a null terminated string at TIB+IN for 'c' or null termination.
 // Uses and adjusts IN to reflect offset to c or null in TIB.
 // Return false flag if null found first, indicating end of input in TIB,
 // ( usually from QUERY ) else return true flag, either with IN adjusted.
.section .text, "ax", %progbits
.balign 4, 255
TIB_CHAR_SCAN:
	.word	.+5
.section .text, "ax", %progbits
 // t is char matched from TIB as flag to return
	POP2n // Char were lookin for
	LDR	w, = TIB
	MOV	ra, w // Save for IN calculation.
	LDR	x, = IN
	LDR	y, [x] // Get offset in to TIB
	ADDS	w, w, y // Create TIB+IN
.thumb_func
TCS_LOOP:
	LDRB	t, [w] // Strting at TIB+IN ( ex space after ( .
	ADDS	w, #1 // When matched
	CMP	t, n // Character passed to test
	BEQ	TCS_FOUND

	CMP	t, #0 // Null at end of TIB?
	BNE	TCS_LOOP // no keep looking

.thumb_func
TCS_FOUND:
	MOV	y, ra // TIB
	SUBS	w, w, y // TIB+Char offset
	STRB	w, [x] // Set IN
	TPUSH // t is null or char

 //:NONAME TOGGLE:	( addr b -- ) Complement BYTE at addr by the bit pattern b.
 //      Byte operator for NFA count byte
 //      Complement (FLIP) the BYTE contents of addr by the bit pattern b.
 //	SEE SETBITS and CLRBITS
.section .text, "ax", %progbits
.balign 4, 255
TOGGLE:
	.word	.+5
.section .text, "ax", %progbits
	POP2n // Bit PATTERN
	POP2w // ADDR
	LDRB	t, [w]
	EORS	t, t, n
	STRB	t, [w]
	NEXT

#ifdef XON_XOFF
 //:NONAME IF_EOL_SEND_XOFF: Get xoff out ASAP in EXPECT!
 //      Must leave char in t!!!!!!!!!
.section .text, "ax", %progbits
.balign 4, 255
IF_EOL_SEND_XOFF:
	.word	.+5
.section .text, "ax", %progbits
 //------------------------------------------------------------------------------
#ifdef  IO2TP
	NEXT
#else
 //------------------------------------------------------------------------------
	LDR	n, = 0x0A // ^J
	CMP	t, n
	BNE	CR_CHECK

.thumb_func
SUB_CR_4_NL:
	POP2t
	LDR	t, = 0x0D // ^M
	PUSHt
	B	EOL_SEND_XOFF

.thumb_func
CR_CHECK:
	LDR	n, = 0x0D
	CMP	t, n // LEAVE CHAR in T!!!!
	BNE	NOT_CR

.thumb_func
EOL_SEND_XOFF:
 // IO2TP DOES NOT GET HERE
	BL	TXRDY_SUBR
	BL	XOFF_SUBR
 //------------------------------------------------------------------------------
.thumb_func
NOT_CR:
	NEXT
#endif // else IO2TP
#endif // XON_XOFF


 //:NONAME NUMBERSUFFIX:      ( addr -- addr ) Number BASE suffix eval primitive.
 //      In NUMBER temporarily change base if number has valid suffix.
 //      IF LEN =1 LEAVE IT!
 //      IF LEN =2 CHECK FOR .suffix!
 //      addr is counted number striong. The count is ignored by NUMBER
 //      If valid Base suffix replace suffix with null for NUMBER.
 //      NUMBER must save and restore base outside of this call.
.section .text, "ax", %progbits
.balign 4, 255
NUMBERSUFFIX:
	.word	.+5
.section .text, "ax", %progbits
	NDPOP2t // macro = copy tos to t, leave it on the stack
	LDRB	n, [t] // get string lentgth
	CMP	n, #1
	BEQ	NSEXIT1

	CMP	n, #2
	BEQ	NSTWO

.thumb_func
NSNOTTWO:
	ADD	n, n, t // point to end of string
	LDRB	w, [n] // get possible suffix
	CMP	w, #'b' // 62h
	BEQ	USEBIN
	CMP	w, #'%'
	BEQ	USEBIN

	CMP	w, #'d' // 64h
	BEQ	USEDEC
	CMP	w, #'#'
	BEQ	USEDEC

	CMP	w, #'h' // 68h
	BEQ	USEHEX
	CMP	w, #'$'
	BEQ	USEHEX

.thumb_func
NSEXIT1:
	NEXT

.thumb_func
NSTWO: // HERE BECAUSE INPUT LEN IS 2 SO IF . IS FIRST
	LDRB	w, [t, #1] // GET 1RST CHAR
	CMP	w, #'.' // IF IT'S A DOT
	BNE	NSNOTTWO
	NEXT

.thumb_func
USEBIN:
	LDR	y, =2
	B	CLRSUFFIX
.thumb_func
USEDEC:
	LDR	y, =10
	B	CLRSUFFIX
.thumb_func
USEHEX:
	LDR	y, =16

.thumb_func
CLRSUFFIX:
	LDR	w, =0X00 // =0x20
	STRB	w, [n]
	LDR	w, =NBASE // BASE_SV in FISH
	STR	y, [w]
	NEXT
.ltorg

 //:NONAME       USTAR:	(u1 u2 --  ud=<LSW MSW> ) USED INTERNALLY - NOT UNSIGNED
 //      Leave the unsigned double number product of two unsigned numbers.
.section .text, "ax", %progbits
.balign 4, 255
USTAR:
	.word	.+5
.section .text, "ax", %progbits
	POP2t
	POP2n

 // IRQ's and c routines share cstack
.extern C_CMSIS_DISABLE_IRQS
	BL	C_CMSIS_DISABLE_IRQS
.extern c_32by32to64mul
	BL	c_32by32to64mul
.extern C_CMSIS_ENABLE_IRQS
	BL	C_CMSIS_ENABLE_IRQS
	MOV	w, t // LSW
	MOV	t, n // MSW
	DPUSH //  --  LSW MSW )

	NEXT_TAILS // shared NEXT copy (B range)
 //:NONAME       USLASH:	( d n --- u32REM u32QUO ) USED INTERNALLY - NOT UNSIGNED
 //      Leave the unsigned remainder u2 and unsigned quotient u3 from the
 //      unsigned double dividend ud and unsigned divisor u1.
 //      RESULTS ARE NOT A TRADITOIONAL DOUBLE NUMBER ONE WOULD PRINT USING D.
 //      Quotient = int ( Dividend / Divisor )
 //      Remainder = Dividend - Quotient * Divisor
.section .text, "ax", %progbits
.balign 4, 255
USLASH:
	.word	.+5
.section .text, "ax", %progbits
 //	U/  USLASH: ( uLSW uMSW u32 --- u32REMAINDER u32QUOTIENT )
	POP2t // U32  divisor
	POP2x // UMSW  dividendHI
	POP2w // ULSW dividendLO
	CMP	t, #0 // divide by zero is divisor = 0
	BEQ	DZERO // J Not Below
 // IRQ's and c routines share cstack
.extern C_CMSIS_DISABLE_IRQS
	BL	C_CMSIS_DISABLE_IRQS
.extern c_64by32div
	BL	c_64by32div
.extern C_CMSIS_ENABLE_IRQS
	BL	C_CMSIS_ENABLE_IRQS
	DPUSH //  --  LSW MSW )

.thumb_func
DZERO:
	EORS	t, t // zero
	SUBS	t, t, #1 //
	MOV	w, t //
	DPUSH //  --  LSW MSW )

 //:NONAME SPSTO:	( -- ) Initialize the stack pointer from INITSO.
.section .text, "ax", %progbits
.balign 4, 255
SPSTO:
	.word	.+5
.section .text, "ax", %progbits
	LDR	w, = INITSO // SYSTEM VAR BASE ADDR, Initially set to PINIT
	LDR	p, [w] // RESET PARAMETER STACK PTR
	NEXT
 // LTORG

 //:NONAME RPSTO:	( -- ) Initialize the return stack pointer from INITR0.
.section .text, "ax", %progbits
.balign 4, 255
RPSTO:
	.word	.+5
.section .text, "ax", %progbits
	LDR	w, = INITRO // SYSTEM VAR BASE ADDR, Initially set to RINIT
	LDR	r, [w] // SET RETURN STACK PTR
	NEXT
.ltorg

 //:NONAME BASE_TO_R12:    ( -- ) Copy BASE to r12
.section .text, "ax", %progbits
.balign 4, 255
BASE_TO_R12:
	.word	.+5
.section .text, "ax", %progbits
	LDR	w, =NBASE
	LDR	n, [w]
	MOV	k, n
	NEXT
.ltorg

 //:NONAME BASE_FROM_R12:    ( -- ) Set BASE from r12
.section .text, "ax", %progbits
.balign 4, 255
BASE_FROM_R12:
	.word	.+5
.section .text, "ax", %progbits
	LDR	w, =NBASE
	MOV	n, k
	STR	n, [w]
	NEXT
.ltorg

 //:NONAME STRVA:    ( -- ) GET VALUE THEN ADDR FROM NEXT 2 CELLS AND WRITE TO ADDR
 //      Use proper LABEL for values/addresses!!! EX: FPA vs FPADDR
.section .text, "ax", %progbits
.balign 4, 255
STRVA:
	.word	.+5
.section .text, "ax", %progbits
	LDM	i!, {n} // GET FROM [w] TO n
	LDM	i!, {w}
	STR	n, [w]
	NEXT

 //------------------------------------------------------------------------------
 // SECTION HEADER TO RE ALIGN ALL CODE AFTER THIS INCLUDE
.section .text, "ax", %progbits
.balign 4, 255
 //------------------------------------------------------------------------------
