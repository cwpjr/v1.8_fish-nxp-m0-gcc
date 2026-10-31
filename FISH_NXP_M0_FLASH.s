 // FISH_NXP_FLASH.s
 // FLASH_SAVE, FLASH_FORGET, FLASH_SCAN and support :NONAME's

 //	FLASH_SAVE FLASH_SAVE:	( -- ) Save RAM to Flash

.section .text, "ax", %progbits
FLASH_SAVE_NFA:
	.byte	0x80+10
	.ascii	"FLASH_SAV"
	.byte	'E'+0x80
.balign 4, 255
 //#ifdef SRM
 //	DC32	WC_UARTx_NFA
 //#else
	.word	WC_IRQ_NFA
 //#endif
FLASH_SAVE:
	.word	DOCOL
 // SOMETHING TO SAVE TEST - IF LATEST IS NOT IN ROM
	.word	LATEST, DBASE, LESSTHAN
	.word	ZBRAN
	.word	FLPT-.

	.word	CR
	.word	PDOTQ
	.byte	15
	.ascii	"NOTHING TO SAVE"
.balign 4, 255
	.word	SEMIS

 // SAVE PAGE IF
FLPT:
 // LAST PAGE USED TEST - PPAGE = PAST PAGE
	.word	FPADDR, AT
	.word	LIT, FLASH_PPAGE
	.word	EQUAL
 // DC32 NOOP
	.word	ZBRAN
	.word	FSAVE-.

FSLASTPAGE:
	.word	CR
	.word	PDOTQ
	.byte	20
	.ascii	"LAST FLASH PAGE USED"
.balign 4, 255
	.word	SEMIS

 // Setup for saving - Assumes no error in relocation
 // Based on relocating UP and Latest to FPVAR and FPCURR
FSAVE:
 // Stop Downloads
	.word	XON
 // FPA SHOULD BE SET BY FLASH_SCAN IN WARM OR BY FISH OR FISH_ONLY
 // FPCURR AND FPVAR SAVE
	.word	UP_SV, AT, FPVAR, STORE
	.word	LATEST, TOFA, FPCURR, STORE

 // KEEP RELOCATING ONE WORD AT A TIME UNTIL RECHING FIRST WORD (DBASE)
FS_BEGIN:
	.word	LATEST, DBASE, EQUAL
	.word	ZBRAN
	.word	FS_RWORD-.

 // AFTER LAST WORD RELOCATED
FS_WRITE:
	.word	FLASHWRITE
	.word	DBASE, DP_SV, STORE
	.word	FPVAR, AT, UP_SV, STORE
	.word	FPCURR, AT, CURRENT_SV, STORE

 // UPDATE FPADDR - WILL BE FLASH_PPAGE WHEN ALL PAGES USED
	.word	LIT, FLASH_WR_SIZE, FPADDR, PSTORE

 // FLASH_SAVE Finish
FS_EXIT:
	.word	FLASH_SCAN
#if !defined(SRM) && !defined(FISH_LEAN_WORDSET)
	.word	CR, DOTVARSPACE, DOTDICTSPACE
#endif
	.word	XON
	.word	SEMIS

FS_RWORD:
	.word	LATEST, RWORD
	.word	BRAN
	.word	FS_BEGIN-.


 //:NONAME	FPADDR:	( -- addr ) Flash Page Addreess to operate on.
.section .text, "ax", %progbits
FPADDR:
	.word	DOCON, FPA


 //:NONAME	FPCURR:	( -- addr ) Flash Page CURRENT is NFA of last word saved in Flash.
.section .text, "ax", %progbits
FPCURR:
	.word	DOCON, FPC


 //:NONAME	FPVAR:	( -- addr ) Flash Page VAR is UP value when Flash page saved.
.section .text, "ax", %progbits
FPVAR:
	.word	DOCON, FPSV

 //:NONAME >FA >FA:	( addr -- raddr ) Relocate address relative to FPADDR.
 //	Convert address to raddr using FPADDR, which must be initialized.
.section .text, "ax", %progbits
.balign 4, 255
TOFA:
	.word	.+5
.section .text, "ax", %progbits
	POP2t
	LDR	w, = 0x0FFF
	ANDS	t, t, w
	LDR	w, = FPA
	LDR	w, [w]
	ADDS	t, t, w
	TPUSH
.ltorg


 //:NONAME RWORD:	( nfa -- ) Relocate this word relative to FPADDR
 //	Relocate word specified by it's NFA to FPADDR relative addresses
 //	Handle case of CON/VAR, CREATE_DOES_GOTO, PDOTQ and LIT by not relocating them.
 //      RLIT's WILL BE RELOCATED - LIT's WILL NOT.
.section .text, "ax", %progbits
RWORD:
	.word	DOCOL
	.word	PFA, DUP, TOR
	.word	CFA

CFA_CREATE_DOES_GOTO:
	.word	DUP, AT
	.word	LIT, CREATE_DOES_GOTO
	.word	EQUAL
	.word	ZBRAN
	.word	RW_DOCONVAR-.

	.word	FOURP, DUP, DUP
	.word	AT, TOFA
	.word	SWAP, STORE
	.word	BRAN
	.word	RW_UNTIL-.

RW_DOCONVAR:
 // CHECK FOR DOCON AND DOVAR
	.word	DUP, AT
	.word	LIT, DOCON
	.word	EQUAL

	.word	OVER, AT
	.word	LIT, DOVAR
	.word	EQUAL

	.word	OR
	.word	ZBRAN
	.word	RW_BEGIN-.
 // IS DOCON OR DOVAR
	.word	DROP
	.word	BRAN
	.word	RW_LFA-.

 // CFA -- BECOMES EACH WORD IN BODY OF THIS DEFINITION
RW_BEGIN:
	.word	FOURP, DUP, AT
 // RLIT's WILL BE RELOCATED - LIT's WILL NOT
CFA_LIT:
	.word	LIT, LIT, EQUAL
	.word	ZBRAN
	.word	CFA_PDOTQ-.
 // IS LITERAL SO SKIP TO NEXT WORD IN THIS DEFINITION
	.word	FOURP
	.word	BRAN
	.word	RW_BEGIN-.

CFA_PDOTQ:
	.word	DUP, AT
	.word	LIT, PDOTQ, EQUAL
	.word	ZBRAN
	.word	CFA_SEMIS-.
 // PDOTQ SO BYPASS TEXT AND LOOK FOR NEXT WORD IN THIS DEFINITION
	.word	DUP, FOURP, CAT
	.word	PLUS
	.word	ALIGNED
	.word	BRAN
	.word	RW_BEGIN-.

CFA_SEMIS:
	.word	DUP, AT
	.word	LIT, SEMIS, EQUAL
	.word	ZEQU, ZBRAN
	.word	RW_UNTIL-.

RELOC_THIS_WORD:
 // NOT AT SEMIS - IS THIS A ADDRESS TO RELOCATE?
	.word	DUP, AT
	.word	DBASE, GREATERTHAN
	.word	ZBRAN
	.word	RW_BEGIN-.
 // THIS IS A RAM ADDRESS THAT NEEDS TO BE RELOCATED TO A FLASH ADDRESS
	.word	DUP, DUP, AT
	.word	TOFA
	.word	SWAP, STORE
	.word	BRAN
	.word	RW_BEGIN-.

RW_UNTIL:
 // ADDRESS OF SEMI OR LAST WORD IN THIS DEFINITION
	.word	DROP
RW_LFA: // RELOCATE LFA AND SET CURRENT/LATEST TO Next WORD
	.word	RFROM
	.word	LFA, DUP, AT
	.word	DUP
	.word	CURRENT_SV, STORE
	.word	TOFA, SWAP, STORE
	.word	SEMIS


 //:NONAME FLASHPREP:	( -- ) Prepare FPADDR Flash page for writing
 //	PREPARE SECTORS FOR WRITE OPERATION USING FPADDR
.section .text, "ax", %progbits
.balign 4, 255
FLASHPREP:
	.word	.+5
.section .text, "ax", %progbits
#ifdef TOSCT
	MOV	k, t // save TOS
#endif
	LDR	t, = FLASHCMD // t and n DO NOT SURVIVE FLASHCALL
	LDR	n, = FLASHRET
	LDR	w, = 50 // Prepare sector to write
	STR	w, [t]
	LDR	x, = FPA // DERIVE SECTOR
	LDR	w, [x] // FROM PAGE ADDR
#if NXP_M0_032kFlash_4KWrite | NXP_M0_064kFlash_4KWrite
	LSRS	w, w, #12 // BY SHIFTING RIGHT BY 12
#endif
#ifdef NXP_M0_016kFlash_1KWrite
	LSRS	w, w, #10 // BY SHIFTING RIGHT BY 10
#endif
	STR	w, [t,#4]
	STR	w, [t,#8]
	LDR	x, = IAPCALL
	BLX	x
#ifdef TOSCT
	MOV	t, k // restore TOS
#endif
	NEXT // FLASHPREP
.ltorg


 //:NONAME FLASHESEC:	( -- ) Erase Flash sectors using FPADDR - flashprep 1rst!
 //	MUST USE FLASHPREP FIRST.
.section .text, "ax", %progbits
.balign 4, 255
FLASHESEC:
	.word	.+5
.section .text, "ax", %progbits
#ifdef TOSCT
	MOV	k, t // save TOS
#endif
	LDR	t, = FLASHCMD // t and n DO NOT SURVIVE FLASHCALL
	LDR	n, = FLASHRET
	LDR	w, = 52 // Prepare sector to write
	STR	w, [t]
	LDR	x, = FPA // DERIVE SECTOR
	LDR	w, [x] // FROM PAGE ADDR
#if NXP_M0_032kFlash_4KWrite | NXP_M0_064kFlash_4KWrite
	LSRS	w, w, #12 // BY SHIFTING RIGHT BY 12
#endif
#ifdef NXP_M0_016kFlash_1KWrite
	LSRS	w, w, #10 // BY SHIFTING RIGHT BY 10
#endif
	STR	w, [t,#4]
	STR	w, [t,#8]
	LDR	w, = (SYSTEMCLOCK / 1000) // in Khz
	STR	w, [t,#12]
	LDR	x, = IAPCALL
	BLX	x
#ifdef TOSCT
	MOV	t, k // restore TOS
#endif
	NEXT // FLASHESEC
.ltorg


 //:NONAME FLASHCRTF:	( -- ) Copy Ram to Flash using FPADDR
 //	FLASH COPY RAM TO FLASH COMMAND USING FPADDR and FLASH_WR_SIZE
.section .text, "ax", %progbits
.balign 4, 255
FLASHCRTF:
	.word	.+5
.section .text, "ax", %progbits
#ifdef TOSCT
	MOV	k, t // save TOS
#endif
	LDR	t, = FLASHCMD
	LDR	n, = FLASHRET
	LDR	w, = 51 // Copy Ram to Flash
	STR	w, [t]
	LDR	w, = FPA
	LDR	w, [w]
	STR	w, [t,#4]
	LDR	w, = RAM_START // START OF RAM NOT ORIG (START OF DICTIONARY)
	STR	w, [t,#8]
	LDR	w, = FLASH_WR_SIZE // Smallest writeable page size
	STR	w, [t,#0x0C]
	LDR	w, = (SYSTEMCLOCK / 1000) // in Khz
	STR	w, [t,#0x10]
	LDR	x, = IAPCALL
	BLX	x
#ifdef TOSCT
	MOV	t, k // restore TOS
#endif
	NEXT // FLASHCRTF	// NO RETURN VALUE
 //	LDR	t, [n]		// RETURN STATUS CODE
 //	APUSH
.ltorg

 //------------------------------------------------------------------------------
 //	FLASH_FORGET FLASH_FORGET:	( --  ) Erase Flash Pages

.section .text, "ax", %progbits
FLASH_FORGET_NFA:
	.byte	0x80+12
	.ascii	"FLASH_FORGE"
	.byte	'T'+0x80
.balign 4, 255
	.word	FLASH_SAVE_NFA
FLASH_FORGET:
	.word	DOCOL
	.word	XOFF
 // FF Setup starting page
	.word	STRVA, FLASH_SPAGE, FPA

FF_LOOP:
 // IF at last page Branch to FF_FINISH
	.word	FPADDR, AT
	.word	LIT, FLASH_PPAGE
	.word	EQUAL, ZEQU
	.word	ZBRAN
	.word	FF_FINISH-.

 // Erase a page at a time using current FPA value
	.word	CMSIS_DISABLE_IRQS
	.word	FLASHPREP, FLASHESEC
	.word	CMSIS_ENABLE_IRQS
 //        DC32    FPADDR, AT, DOTHEX
	.word	LIT, FLASH_WR_SIZE
	.word	FPADDR, PSTORE
	.word	BRAN
	.word	FF_LOOP-.

 //      RESET DICTIONARY POINTERS APPROPRIATELY
FF_FINISH:
 // IF NO WORDS IN RAM TEST
	.word	RBASE, LATEST
	.word	GREATERTHAN
	.word	ZBRAN
	.word	RAMWORDS-.
 // RESET ALL POINTERS
	.word	FISH_ONLY
 // RESET FPA
	.word	BRAN
	.word	FFDONE-.

 // WORDS IN RAM NEED TO BE RELINKED TO FLASH
RAMWORDS:
 //        DC32    LIT, TASK_NFA         // Fish WITH TASKER IN RAM starts here
#ifdef FISH_PubRel_WORDSET
	.word	LIT, WC_FISH_PubRel_NFA
#endif
#ifdef FISH_NXP_M0_PRO_WORDCAT
	.word	LIT, WC_FISH_PRO_NFA
#endif
	.word	DBASE, PFA, LFA
	.word	STORE

 // FLASH_FORGET Finish
FFDONE:
	.word	STRVA, FLASH_SPAGE, FPA
	.word	LIT, 0x11111111, DUP, FPCURR, STORE, FPVAR, STORE
 // Show results
	.word	FLASH_SCAN
#if !defined(SRM) && !defined(FISH_LEAN_WORDSET)
	.word	CR, DOTVARSPACE, DOTDICTSPACE
#endif
	.word	XON
	.word	SEMIS


 //:NONAME FLASHWRITE:	( --  ) Commands to save Ram to Flash using FPADDR.
 //	FLASH SEQ OF CMDS TO COPY 4K RAM USING FPADDR
.section .text, "ax", %progbits
FLASHWRITE:
	.word	DOCOL
	.word	HERE
	.word	LIT, DICTSPACE_END-1
	.word	HERE, SUBB
	.word	LIT, 0xFF
	.word	FILL
	.word	CMSIS_DISABLE_IRQS
	.word	FLASHPREP, FLASHESEC
	.word	FLASHPREP, FLASHCRTF
	.word	CMSIS_ENABLE_IRQS
	.word	SEMIS

 //------------------------------------------------------------------------------
 //:NONAME FLASH_SCAN:       ( -- ) SCAN FLASH PAGES FOR SAVED CODE
 //      Patch in FLASH_SAVE'd Code.
.section .text, "ax", %progbits
FLASH_SCAN:
	.word	DOCOL

 // First page available must be at least equal to last page
 // FLASH_PPAGE can be reserved and Hard_fault if accessed!
	.word	LIT, FLASH_SPAGE
	.word	DUP, FPADDR, STORE

FLSCLP:
	.word	DUP, TOR
	.word	AT
	.word	SYSCLK
	.word	EQUAL
/*
        .word R, LIT, 8, PLUS
        .word AT, FPADDR, AT
        .word GREATERTHAN
        .word OR
*/
	.word	ZBRAN
	.word	CHECKPAGE-.

 //      PAGE PASSES VERIFICATION, LINK IT
	.word	R, LIT, 8, PLUS
	.word	DUP, AT
	.word	CURRENT_SV
	.word	STORE
	.word	FOURP, AT
	.word	UP_SV, STORE
	.word	CR
	.word	PDOTQ
	.byte	23
	.ascii	"ADDED WORDS FROM PAGE "
.balign 4, 255
	.word	R
	.word	DOTHEX

	.word	R, LIT, FLASH_WR_SIZE
	.word	PLUS, FPADDR, STORE

	.word	BRAN
	.word	FSNEXT-.

CHECKPAGE:
	.word	R, ASSUREPAGE

FSNEXT:
	.word	R, LIT, FLASH_WR_SIZE
	.word	PLUS
	.word	DUP
	.word	LIT, FLASH_PPAGE
	.word	SUBB
	.word	ZBRAN
	.word	FSDONE-.

	.word	DROP
	.word	RFROM, LIT, FLASH_WR_SIZE
	.word	PLUS
	.word	BRAN
	.word	FLSCLP-.

FSDONE:
	.word	DROP
	.word	RFROM, DROP
	.word	SEMIS


 //:NONAME ASSUREPAGE: ( fpa -- next-fpa) Verify this Flash page has code or is empty.
 //      Make sure PAGE IN fpa page is erased and let user know what you do.
 //      Works in 812 SRM!!!

 // 2 STACK ITEMS LEFT ON EXIT, BOTH ARE fpa+1000H LIKE WHATS PUT ON r<<<<<<<<<<<

.section .text, "ax", %progbits
ASSUREPAGE:
	.word	DOCOL
	.word	DUP
	.word	LIT, FLASH_WR_SIZE
	.word	PLUS
	.word	TOR
	.word	DUP

APNEXT:
	.word	AT
	.word	ONEP
	.word	ZBRAN
	.word	APCONT-.

 //      ERASE THIS PAGE                 // fpa
 //        DC32    FPADDR, AT, DOTHEX

	.word	CMSIS_DISABLE_IRQS
	.word	FLASHPREP
	.word	FLASHESEC
	.word	CMSIS_ENABLE_IRQS
	.word	CR
	.word	PDOTQ
	.byte	23
	.ascii	"ERASED BAD FLASH PAGE  "
.balign 4, 255
	.word	DOTHEX

 //        DC32    CR, DOTS // DEBUG
	.word	DROP

	.word	RFROM, DROP
	.word	SEMIS

 //      SO FAR SO GOOD
APCONT: // addr
	.word	FOURP, DUP
	.word	DUP, R, SWAP
	.word	SUBB
	.word	ZBRAN
	.word	APGOOD-.

	.word	BRAN
	.word	APNEXT-.

APGOOD: // addr addr
	.word	CR
	.word	PDOTQ
	.byte	14
	.ascii	"FLASH PAGE OK "
.balign 4, 255
	.word	DROP, LIT, FLASH_WR_SIZE
	.word	SUBB
	.word	DOTHEX

APDONE:
	.word	RFROM, DROP
	.word	SEMIS

