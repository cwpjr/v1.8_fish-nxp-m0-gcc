 //      FISH_NXP_M0_81x_UART0_INIT.s

 //	UART0_INIT UART0_INIT: ( -- )
 //	If setting BAUD MYBAUD MUST BE USED FIRST
 //	THIS IS TO PRESERVE YOUR BAUD DURING HARD FAULT RESET
 //	UseDEFAULT_BAUD UNLESS DBAUD IS ZERO, THEN USE UBAUD VALUE
 //	WHEN DBAUD IS NOT ZERO USE DEFAULT_BAUD	        // PWRUP
 //	WHEN DBAUD IS ZERO USE UBAUD			// RESET

.section .text, "ax", %progbits
UART0_INIT_NFA:
	.byte	0x8A
	.ascii	"UART0_INI"
	.byte	'T'+0x80
.balign 4, 255
	.word	WC_NUMBERS_NFA
UART0_INIT:
	.word	DOCOL

/* [LPC800] UM10601 4.6.18
USART fractional generator divider value register
All USART peripherals share a common clock U_PCLK, which can be adjusted by a
fractional divider:
U_PCLK = UARTCLKDIV/(1 + MULT/DIV).
UARTCLKDIV is the USART clock configured in the UARTCLKDIV register.
The fractional portion (1 + MULT/DIV) is determined by the
two USART fractional divider registers in the SYSCON block:
1. The DIV value programmed in this register is the denominator
 of the divider used by the fractional rate generator
 to create the fractional component of U_PCLK.
2. The MULT value of the fractional divider is programmed in the UARTFRGMULT
  register. See Table 24.
Remark: To use of the fractional baud rate generator, you must write 0xFF
  to this register to yield a denominator value of 256.
  All other values are not supported.
15.7.1.1 Fractional Rate Generator (FRG)
The Fractional Rate Generator can be used to obtain more precise baud rates when the
peripheral clock is not a good multiple ofstandard (or otherwise desirable) baud rates.
The FRG is typically set up to produce an integer multiple of the highest required baud
rate, or a very close approximation. The BRG is then used to obtain the actual baud rate
needed.:
The FRG register controls the USART Fractional Rate Generator, which provides the
base clock for the USART. The Fractional Rate Generator creates a lower rate output
clock by suppressing selected input clocks. When not needed, the value of 0 can be set
for the FRG, which will then not divide the input clock.
The FRG output clock is defined as the inputs clock divided by 1 + (MULT / 256), where
MULT is in the range of 1 to 255. This allows producing an output clock that ranges from
the input clock divided by 1+1/256 to 1+255/256 (just more than 1 to just less than 2). Any
further division can be done specific to each USART block by the integer BRG divider
contained in each USART. The base clock produced by the FRG cannotbe perfectly symmetrical, so the FRG
distributes the output clocks asevenly as is practical. Since the USART normally uses 16x
overclocking, the jitter in the fractional rate clock in these cases tends to disappear in the
ultimate USART output.
*/

#ifndef DEFAULT_BAUD_TEST
	.word	LIT, DBAUD, AT, ZEQU
	.word	ZBRAN
	.word	BAUDDEFAULT-.
	.word	LIT, UBAUD, AT
	.word	TOR
	.word	BRAN
	.word	BAUD1-.
#endif

BAUDDEFAULT: // ELSE
	.word	LIT, DEFAULT_BAUD
	.word	TOR

/* [LPC800] UM10601 15.5
The Baud Rate Generator block divides the incoming clock to create a
16x baud rate clock in the standard asynchronous operating mode.
The BRG clock input source is the shared Fractional Rate Generator
that runs from the common USART peripheral clock U_PCLK).
Typically, the baud rate clock is 16 times the actual baud rate.
Remark: The fractional value and the USART peripheral clock
are shared between all USARTs. UARTCLKDIV_81x set by value > 0 = U_PCLK
.word STRVA, 1, UARTCLKDIV_81x
*/

BAUD1:
	.word	STRVA, 1, UARTCLKDIV_81x

	.word	STRVA, 0x0FF, UARTFRGDIV

	.word	RFROM, LIT, 16, STAR
	.word	SYSCLK, SWAP, SLASH
	.word	ONE, SUBB

/* [LPC800] UM10601 15.6.9
Remark: If software needs to change the baud rate,
the following sequence should be used:

1) Make sure the USART is not currently sending or receiving data.
2) Disable the USART by writing a 0 to the BRG Enable bit
  (0 may be written to the entire registers).
3) Write the new BRGVAL.
4) Write to the CFG register to set the Enable bit to 1.
CFG, address 0x40064000h (USART0
*/
BRG81x:
	.word	STRVA, 0, USART0_BRG
#ifdef SLOW_POWERUP
	.word	FOUR, MS
#endif
	.word	LIT, USART0_BRG
	.word	STORE

#ifdef CTS_RTS
 // NOT ASSIGNING CTS IN SoCinit:
 // ?CTS not working on 812 JTAG because its not connected!?!
 // ?CTS not working on 812 USB ?????
 // 0x200 = CTSEN + 5 = 8,N,1 Pinout done in SoCinit
	.word	STRVA, 0x205, USART0_CFG
#else
	.word	STRVA, 0x05, USART0_CFG
#endif
#ifdef DEFAULT_BAUD_TEST
	.word	STRVA, 0X31, UART0_TX
#endif

	.word	SEMIS
