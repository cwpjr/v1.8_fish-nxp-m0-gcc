# io_NXP_M0+_header.h — Code Review

Date: 2025-10-31
Scope: 404 `.equ` register-address definitions for LPC81x (switch matrix,
GPIO, USART0, SYSCON, SysTick, NVIC, SCB), translated from the IAR NXP
device header. Pure constants — no code, no image bytes.
Build context: stock defconfig.

---

## 1. Verification Method

Cross-checked every equate **actually referenced by active code** against
UM10601/UM10801 memory maps:

| Equate | Value | UM10801 | Used by |
|---|---|---|---|
| `PINASSIGN0` | `0x4000C000` | ✓ | SoCinit pin mux |
| `PINENABLE0` | `0x4000C1C0` | ✓ | (available) |
| `DIR0` / `PIN0` | `0xA0002000` / `0xA0002100` | ✓ | SoCinit RTS/CTS GPIO |
| `SYSAHBCLKCTRL` | `0x40048080` | ✓ | SoCinit |
| `PDRUNCFG` | `0x40048238` | ✓ | SoCinit |
| `SYSPLLCTRL/STAT/CLKSEL/CLKUEN` | `0x40048008/0C/40/44` | ✓ | SoCinit PLL |
| `MAINCLKSEL/UEN` | `0x40048070/74` | ✓ | SoCinit |
| `UARTCLKDIV_81x` | `0x40048094` | ✓ | UART0_INIT |
| `UARTFRGDIV` | `0x400480F0` | ✓ | UART0_INIT |
| `USART0_CFG/STAT/RXDAT/TXDAT/BRG` | `0x40064000/08/14/1C/20` | ✓ | UART0_INIT, TXRDY/KEY/EMIT |
| `DEVICE_ID_81x` | `0x400483F8` | ✓ | (available) |
| `SYST_CSR/RVR/CVR/CALIB` | `0xE000E010/14/18/1C` | ✓ | SoCinit, DELAY, SYSTICK_IRQ_ON/OFF |
| `AIRCR` | `0xE000ED0C` | ✓ | startup HardFault reset |
| NVIC `ISER/ICER/ISPR/ICPR/IP0-7` | `0xE000E100…` | ✓ | (available; unused in stock — SysTick needs no NVIC setup) |

**Zero wrong addresses among referenced equates.** The remaining ~350
unreferenced equates are a free reference table (no image cost).

## 2. Findings

### 2.1 Cosmetic only
- Duplicate aliases (`SYST_CSR`/`SYSTICKCSR`, `ISER`/`SETENA0`, …) — IAR
  header had both naming generations; harmless, keep (used by different
  source generations).
- Filename `+` — noted in `FISH_NXP_M0_MAIN_INCLUDES.md` §3.3; low
  priority rename candidate.
- Header comment cites the IAR install path — historical.

### 2.2 Contract worth one comment line
These equates are **LPC81x-only**; the 11xx/1115 builds include a sibling
header. The `#if NXP_M0_11xx | NXP_M0_1115` / `#ifdef NXP_M0_812` splits in
`Forth_GNU.S` (TXRDY, UART0_LSR, EMIT, KEY…) are what keep it straight.
A wrong-include guard (`#ifdef NXP_M0_11xx` → `#error`) would make a
mismatched pairing fail at build time instead of at the UART.

## 3. Action Items

- [ ] Add the wrong-include `#error` guard (§2.2) — build-time only.
- [ ] No value changes — verified.

**Last file reviewed: `io_NXP_M0+_header.h`** (prior: `FISH_RM_MSGS.h` /
`FISH_CO_MSGS.h` — null-terminator fixes applied).
