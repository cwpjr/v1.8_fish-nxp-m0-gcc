 //------------------------------------------------------------------------------

.section .text, "ax", %progbits

 // DC8 "?" IS A NULL TERMINATED STRING
 // DC8 '?' IS NOT
 // #define EOL_DLE // DLE 0x10/16d in QUIT>CR after last word interpreted.
 // #define EOL_NAK // NAK 0x15/21d in error messages for STDLED editor highlight
 // The EOL_NAK makes SPACE NAK end of string in FISH_RM_MSGS.h

.balign 4, 255
 // ALIGN THIS ONE FOR PFIND
msg_RUN:
	.byte	3
	.ascii	"RUN "
msg_questionmark:
	.ascii	" ? "

msg_cr:
	.ascii	" <CR> "

#ifndef FISH_LEAN_WORDSET
msg_uvspace:
	.ascii	"VAR CELLS "

msg_dictspace:
	.ascii	"DICTIONARY BYTES "
#endif

msg_paren_err:
#ifdef EOL_NAK
	.ascii	" COMMENT LINE CANNOT BE EMPTY "
	.byte	0x15
	.byte	0
#else
	.ascii	" COMMENT LINE CANNOT BE EMPTY "
	.byte	0 // NULLSTRLEN terminator (EOL_NAK off)
#endif

msg_forget_fish:
#ifdef EOL_NAK
	.ascii	" CANT FORGET FISH IN FLASH "
	.byte	0x15
	.byte	0
#else
	.ascii	" CANT FORGET FISH IN FLASH "
	.byte	0
#endif

msg_forget_saved:
#ifdef EOL_NAK
	.ascii	" IN FLASH - SEE FLASH_FORGET "
	.byte	0x15
	.byte	0
#else
	.ascii	" IN FLASH - SEE FLASH_FORGET "
	.byte	0
#endif

msg_dictfull:
#ifdef EOL_NAK
	.ascii	" DICTIONARY FULL - SEE .DS "
	.byte	0x15
	.byte	0
#else
	.ascii	" DICTIONARY FULL - SEE .DS "
	.byte	0
#endif

msg_uvfull:
#ifdef EOL_NAK
	.ascii	" RAM VAR SPACE FULL - SEE .VS "
	.byte	0x15
	.byte	0
#else
	.ascii	" RAM VAR SPACE FULL - SEE .VS "
	.byte	0
#endif

msg_wordexists:
#ifdef EOL_NAK
	.ascii	" IS ALREADY DEFINED "
	.byte	0x15
	.byte	0
#else
	.ascii	" IS ALREADY DEFINED "
	.byte	0
#endif

msg_word_error:
#ifdef EOL_NAK
	.ascii	" ? NOT WORD "
	.byte	0x15
	.byte	0
#else
	.ascii	" ? NOT WORD "
	.byte	0
#endif

msg_number_error:
#ifdef EOL_NAK
	.ascii	" ? NOT WORD OR NUMBER "
	.byte	0x15
	.byte	0
#else
	.ascii	" ? NOT WORD OR NUMBER "
	.byte	0
#endif

msg_qstack:
#ifdef EOL_NAK
	.ascii	" CAUSED A STACK ERROR "
	.byte	0x15
	.byte	0
#else
	.ascii	" CAUSED A STACK ERROR "
	.byte	0
#endif

msg_qpair:
#ifdef EOL_NAK
	.ascii	" STACK ERROR WHILE EXECUTING OR COMPILING "
	.byte	0x15
	.byte	0
#else
	.ascii	" STACK ERROR WHILE EXECUTING OR COMPILING "
	.byte	0
#endif

msg_qcomp:
#ifdef EOL_NAK
	.ascii	" ERROR - NOT COMPILING "
	.byte	0x15
	.byte	0
#else
	.ascii	" ERROR - NOT COMPILING "
	.byte	0
#endif

msg_qexec:
#ifdef EOL_NAK
	.ascii	" ERROR - EXECUTED WHILE COMPILING "
	.byte	0x15
	.byte	0
#else
	.ascii	" ERROR - EXECUTED WHILE COMPILING "
	.byte	0
#endif

