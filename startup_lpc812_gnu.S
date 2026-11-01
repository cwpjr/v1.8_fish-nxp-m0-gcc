.syntax unified
.cpu cortex-m0plus
.thumb

.section .isr_vector, "a", %progbits
.balign 4
.global __vector_table
.type __vector_table, %object
__vector_table:
	.word	_estack
	.word	Reset_Handler
	.word	NMI_Handler
	.word	HardFault_Handler
	.word	MemManage_Handler
	.word	BusFault_Handler
	.word	UsageFault_Handler
	.word	__vector_checksum // LPC boot ROM: sum of vectors 0..7 must be 0
	.word	0
	.word	0
	.word	0
	.word	SVC_Handler
	.word	DebugMon_Handler
	.word	0
	.word	PendSV_Handler
	.word	FM0_SYSTICK_ISR
.rept 32
	.word	Default_Handler
.endr
.size __vector_table, . - __vector_table

.section .text.Reset_Handler, "ax", %progbits
.thumb_func
.global Reset_Handler
.type Reset_Handler, %function
Reset_Handler:
	ldr	r0, =_sidata
	ldr	r1, =_sdata
	ldr	r2, =_edata
1:
	cmp	r1, r2
	bcs	2f
	ldr	r3, [r0]
	str	r3, [r1]
	adds	r0, #4
	adds	r1, #4
	b	1b
2:
	ldr	r1, =_sbss
	ldr	r2, =_ebss
	movs	r3, #0
3:
	cmp	r1, r2
	bcs	4f
	str	r3, [r1]
	adds	r1, #4
	b	3b
4:
	ldr	r0, =FM0_COLD
	bx	r0
.size Reset_Handler, . - Reset_Handler

.section .text.Default_Handler, "ax", %progbits
.thumb_func
.global Default_Handler
.type Default_Handler, %function
Default_Handler:
	b	Default_Handler
.size Default_Handler, . - Default_Handler

.macro DEFAULT_VECTOR name
.weak \name
.thumb_func
	\name:
	b	Default_Handler
.endm

	DEFAULT_VECTOR	NMI_Handler
	DEFAULT_VECTOR	MemManage_Handler
	DEFAULT_VECTOR	BusFault_Handler
	DEFAULT_VECTOR	UsageFault_Handler
	DEFAULT_VECTOR	SVC_Handler
	DEFAULT_VECTOR	DebugMon_Handler
	DEFAULT_VECTOR	PendSV_Handler

.weak HardFault_Handler
.thumb_func
HardFault_Handler:
	ldr	r0, =0xE000ED0C
	ldr	r1, =0x05FA0004
	str	r1, [r0]
	b	Default_Handler
