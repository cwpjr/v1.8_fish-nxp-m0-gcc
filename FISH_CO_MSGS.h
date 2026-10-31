 //------------------------------------------------------------------------------

.section .text, "ax", %progbits

 // DC8 "?" IS A NULL TERMINATED STRING
 // DC8 '?' IS NOT

.balign 4, 255

 // IF this fits in 1114 move to FISH_RM_MSGS.h

msg_CO:
	.ascii	" Error Halt (EHON/EHOFF) - To COntinue Type CO then Enter: "

