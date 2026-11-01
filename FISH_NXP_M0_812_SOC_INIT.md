# FISH_NXP_M0_812_SOC_INIT.s — Code Review

Date: 2025-10-31
Scope: `SoCinit` — clock/PLL/SysTick/bus-clock/pin setup, runs in `FM0_WARM`
before `UART0_INIT` (correct ordering: `SYSCLK` must be valid before baud
math). 121 lines, high-level Forth thread of `STRVA` stores.
Build context: stock defconfig (`NXP_M0_81x_IRC12_24MHZ`).

---

## 1. What it does (stock path)

1. `SYST_RVR = 23999`, `SYST_CSR = 7` — **SysTick ON, interrupt ON, CPU
   clock** (24 MHz → exactly 1 ms tick ✓ consistent with `MS`'s 23999).
2. `SYSAHBCLKCTRL = 0x1C0FF` — clocks to ROM/RAM/FLASH/I2C/GPIO/switch-matrix
   + UART0-2. (I2C clock on though I2C unused — same vestige as the MEMMAP
   I2C block; harmless µA.)
3. `PINASSIGN0 = 0xFF090004` — TXD=PIO0_4, RXD=PIO0_0, RTS=PIO0_9,
   CTS unassigned (mBed variant swaps RX/TX to PIO0_1/PIO0_6 ✓).
4. `XON_XOFF` active: `DIR0 = 0x2000` (PIO0_13 output), `PIN0 = 0`
   (drives outputs low) — board-wiring for the STP dev board's FTDI
   handshake (see §3.1).
5. Clock tree: `PDRUNCFG = 0x0ED70` (power IRC/PLL/flash…), PLL in = IRC,
   `SYSPLLCTRL = 1` (M=2 → 12 MHz IRC × 2 = 24 MHz ✓), lock-wait loop on
   `SYSPLLSTAT.0` ✓, `MAINCLKSEL = 3` (PLL out) with UEN tickles ✓.
   `SYSTEMCLOCK (24000000) → SYSCLOCK` — feeds `SYSCLK` and the
   `FLASH_SCAN` page magic ✓.

## 2. ⚠️ Notable: SysTick IRQ is live from boot

`SYST_CSR = 7` during `SoCinit` means the **high-level `DOCOL_ISR` runs
every 1 ms from early boot onward** — during UART init, signon, and every
interactive session forever. Two consequences:
- The `ISR_REGISTER_AUDIT.md` r4–r7 fix is genuinely load-bearing, not
  theoretical (pre-fix, every tick risked VM stack-pointer corruption).
- The boot-time ISR thread (`ONE STCTR PSTORE`) hammers the
  previously-**unaligned** `STICKER` — with the MEMMAP §3.1 fix it now
  lands on `0x10000AFC` ✓. Pre-align-fix, enabling SysTick would have
  HardFault-reset the board within 1 ms of `SoCinit`. These two fixes
  likely were boot blockers #2 and #3 after the vector checksum.

If a minimal-power config is ever wanted, `SYST_CSR = 5` (no TICKINT) also
works — `DELAY` forces the IRQ on itself and restores the user setting.

## 3. Findings

### 3.1 Comment/pin mismatch (docs only, not changed)
- `PINASSIGN0` puts hw-RTS on **PIO0_9**, but `DIR0 = 0x2000` is **PIO0_13**
  and the comment says "bit 14 = 0x2000" (0x2000 is bit **13**). Three
  different stories. Working interpretation: hw-RTS (PIO0_9) auto-asserts
  (always-ready) once assigned; PIO0_13 is a separate GPIO-driven
  always-allow line for the STP board's FTDI. Confirm against the STP
  schematic and fix the comment block to name the actual pins.
- "REVERSE of schematic" comment is doing heavy lifting — same fix.

### 3.2 Cosmetic
- Dead label `Hz_28000000:` (28 MHz remnant from another config).
- `CLKOUT` ifdef body is an empty comment block (feature never ported).
- "Defined in IAR Project Configuration" — stale; define lives in the
  Makefile now.

### 3.3 Verified-good
- PLL lock-wait `ZBRAN` loop is correct (polls `SYSPLLSTAT` bit 0).
- UEN tickle sequence (0→1) correct on both PLL and MAINCLK selectors.
- `PDRUNCFG 0x0ED70` is the standard LPC812 "IRC on, PLL on, flash on"
  value; bits match UM10801 assignments (spot-checked).
- Ordering discipline: SysTick reload before enable; clocks before
  peripherals; `SYSCLOCK` before UART.

## 4. Action Items

- [ ] Fix the RTS/CTS comment block to name actual pins after checking the
      STP 812 board schematic (§3.1).
- [ ] Delete `Hz_28000000:` and the empty `CLKOUT` frame (§3.2).
- [ ] Bench: verify 1 ms `STCTR` cadence (`STCTR ?` twice, Δ = elapsed ms).

**Last file reviewed: `FISH_NXP_M0_812_SOC_INIT.s`** (prior:
`startup_lpc812_gnu.S` — vector checksum fixed).
