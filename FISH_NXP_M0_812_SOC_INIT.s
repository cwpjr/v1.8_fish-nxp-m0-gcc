 //      FISH_NXP_M0_81x_SOC_INIT.s

 //HEADERLESS SoCinit:        ( -- ) Initialize main SoC subsystems here.
 //      Use of IRC, external xtal's and PLL done here.
 //      Derive maximum SYSCLOCK frequiency possible.
 //      Initialize FISH SYSCLK to system clock frequency in Hz. Used By UARTx_INIT.
 //      Initialize SYSTICK, and others under #define control

.section .text, "ax", %progbits
.balign 4, 255
SoCinit:
	.word	DOCOL
 // SYSTICK SECTION: (SysTick uses the processor clock.)
 // SYST_RVR (Reload value) not set until user does with MS or DELAY.
#ifdef NXP_M0_812_IRC12_24MHZ
	.word	STRVA, 23999, SYST_RVR
#endif
 // SYSTICK TIMER ENABLE: Bit 0 = 1
 // SYSTICK CLKSOURCE: Bit 2 = 0 (SYSTEM CLOCK/2)
 // SYSTICK CLKSOURCE: Bit 2 = 1 (SYSTEM CLOCK)
 //  DC32    STRVA, 1, SYSTICKCSR    // SYSCLK/2
 //  DC32    STRVA, 5, SYST_CSR    // SYSCLK
	.word	STRVA, 7, SYST_CSR

#ifdef SLOW_POWERUP
 // DELAY SIGNON MESSAGE OUTPUT UNTIL SERIAL BOARD POWERED UP
	.word	LIT, 500, MS
#endif

 // SYSAHBCLKCTRL, address 0x40048080h can disable uartclks.
 // 0xFF = sys/rom/ram/flash/i2c/gpio and switch matrix
 // 0x1C0 = uart0-1&2
 // IOCON clockes are NOT enabled because the 812 special function pins
 // TXD, RXD, CTS and RTS are configured solely by PINASSSIGNx
	.word	STRVA, 0x1C0FF, SYSAHBCLKCTRL

 // UART HW FLOW CONTROL settings for STP 812 DevL Board:
 // 812 CTS IS INPUT FROM FT230 RTS.
 // 812 CTS enabled by pin assignment and CTSEN bit set in UART0_INIT.
 // 812 RTS IS OUTPUT TO FT230 CTS.
 // 812 RTS is enabled by pin assignment.
 // All pins come up as inputs pulled high.
 // CTS and RTS are active low, allowing flow.
 // So enable pins here making RTS signal active,
 // allowing CTSEN to be set in UART0_INIT if desired.
 // UARTCLKDIV is the U_PCLK used by all UARTS!
 // UARTCLKDIV set by value > 0 = U_PCLK - Value of 0 (power-up) stops uartclk

 // PINASSIGN0 addr 4000C000h FFH IS RESET (OFF!) VALUE
 // Default when XON_XOFF and CTS not defined RTS is defined so reset value is on
#ifdef NXP_812_mBed_MAX // use built in virtual USB serial interface
 // 0xFF0901006 where 0106 is RX = PIO0_1 and TX = PIO0_6 Feeds Serial to USB
	.word	STRVA, 0xFF090106, PINASSIGN0
#else
 // 0xFF0900004 where 0004 is RX = PIO0_0 and TX = PIO_4
	.word	STRVA, 0xFF090004, PINASSIGN0
#endif

 // ON STP Board CTS must be set for FTTDI chip!!!
#ifdef XON_XOFF
 // REVERSE of schematic
 // Asign CTS signal pin vs GPIO usage
 // Set RTS (bit 14 = 0x2000) to OUTPUT and CTS (bit 9 = 0x200) to INPUT
 // GPIO usage of RTS pin, which if assined as RTS signal which enables it.
	.word	STRVA, 0x2000, DIR0
 // Set RTS Low
	.word	STRVA,  0x00, PIN0
#endif

#ifdef CTS_RTS
 // Assign RTS = OUTPUT CTS = INPUT signals to pins - CTSEN in UART0_INIT
#ifdef NXP_812_mBed_MAX // use built in virtual USB serial interface
	.word	STRVA, 0x0E090106, PINASSIGN0
#else
	.word	STRVA, 0x0E090004, PINASSIGN0
#endif
#endif

#ifdef NXP_M0_81x_IRC12_24MHZ // Defined in IAR Project Configuration
 // Voltages should be stable now - proceed to init.
	.word	STRVA, 0x0ED70, PDRUNCFG

 // CHOOSE CLOCK TO FEED PLL
 // 0=irc, 1=sysclk, 2=wdt, 3=mainclock
	.word	STRVA, 0, SYSPLLCLKSEL
 // Tickle Update Register
	.word	STRVA, 0, SYSPLLCLKUEN
	.word	STRVA, 1, SYSPLLCLKUEN

 // SET PLL MULTIPLY AND DIVIDE IF NEEDED AND SET SYSCLOCK
	.word	STRVA, 0x1, SYSPLLCTRL
	.word	STRVA, SYSTEMCLOCK, SYSCLOCK
Hz_28000000:
_wPLLlock:
	.word	LIT,SYSPLLSTAT,AT,ONE,ANDD,ZBRAN
	.word	(_wPLLlock - .)

 // 0=irc, 1=sysclk, 2=wdt, 3=mainclock
	.word	STRVA, 3, MAINCLKSEL
 // Tickle Update Register
	.word	STRVA, 0, MAINCLKUEN
	.word	STRVA, 1, MAINCLKUEN

#endif // NXP_M0_81x_IRC12_24MHZ

#ifdef CLKOUT
 // Turn CLKOUT on and SET divide by...
 // Select Clock
 // Tickle Update Register
#endif

 // Set SYSCLOCK = SYSTEMCLOCK defined in FISH_M0_EQUATES.s
 // And set in Project Configuration ex: NXP_M0_81x_IRC12_12MHZ
 // in Assembler -> Preprocessor -> Defined Symbols
	.word	STRVA, SYSTEMCLOCK, SYSCLOCK

	.word	SEMIS
