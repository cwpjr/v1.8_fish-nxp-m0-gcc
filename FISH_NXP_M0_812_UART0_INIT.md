# FISH_NXP_M0_812_UART0_INIT.s — Code Review

Date: 2025-10-31
Scope: `UART0_INIT` — baud selection + USART0 bring-up (130 lines).
Build context: stock defconfig; runs in `FM0_WARM` after `SoCinit`.

---

## 1. Mechanism (verified against MEMMAP/COLD)

- **MYBAUD persistence**: `DBAUD ≠ 0` (power-up pattern `0x11111111`) →
  `DEFAULT_BAUD` (9600); `DBAUD == 0` → `UBAUD`. `MYBAUD` writes
  `DBAUD=0, UBAUD=n` into the reset-surviving uninit region
  (`0x10000D40/44`, between the two COLD fill loops — verified in
  `FISH_NXP_M0_MEMMAP.md` §1/§2). Under `DEFAULT_BAUD_TEST` the whole
  selection compiles out (off in stock ✓).
- **Baud math**: `BRG = SYSCLK/(baud×16) − 1`, using `SYSCLK` (live RAM
  value, not the equate) so `MYBAUD`+PLL changes stay coherent ✓.
  Stock: 24 MHz/9600 → 156 → BRG=155 → actual 9615.38 baud (**+0.16 %**,
  fine). Signed `SLASH` safe here (all-positive operands).
- **Clock path**: `UARTCLKDIV = 1` (U_PCLK = 24 MHz ✓), `UARTFRGDIV = 0xFF`
  (UM10601-mandated denominator when FRG unused ✓, FRGMULT untouched = 0
  → straight divide ✓).
- **Sequence**: BRG=0 → BRG=val → `CFG = 0x05` (ENABLE + 8N1). UM's
  "disable via CFG.ENABLE=0, change BRG, re-enable" is approximated by the
  BRG=0 pre-write; since this only runs at init before any traffic, it's
  safe — but the comment should say so.
- `CTS_RTS` off in stock → `CFG=0x05`; `CTS_RTS` build would use
  `0x205` (+CTSEN) with pins from `SoCinit` ✓.

## 2. Findings

### 2.1 ⚠️ Baud edge cases (document, no code change)
- `UBAUD` garbage ⇒ garbage baud (e.g. after `MYBAUD` with a junk value).
  Cheap guard candidate: clamp to `300..115200` and fall back to
  `DEFAULT_BAUD`. Not applied — behavior change, needs author sign-off.
- `SYSCLK/(baud×16)` truncates; at 24 MHz all standard rates ≤115200 land
  within 0.2 % except 57600 (0.64 %) — acceptable for the FRG-unused
  design; note for the manual.

### 2.2 Cosmetic
- UM quotation blocks are helpful; the remark ".word STRVA, 1, UARTCLKDIV"
  buried inside the 15.5 quote looks like commented code inside a comment —
  it IS the live note; fine, but mark quotation ends.
- `DEFAULT_BAUD_TEST` writes `0x31` ('1') as a TX test byte — off in
  stock; label as bench-only.
- Typos: "UseDEFAULT_BAUD", "venly", "ofstandard".

### 2.3 Verified-good
- DBAUD/UBAUD addressing uses `#define`d absolute equates (not the RAM-map
  section) — correct, since they must live in the COLD-preserved gap ✓.
- `CFG` written last (enable after BRG) ✓.
- The interaction with the hard-fault-reset policy (`startup` doc §1) is
  coherent: fault → reset → baud preserved via UBAUD ✓.

## 3. Action Items

- [ ] Optional `UBAUD` sanity clamp (§2.1) — **needs author decision**.
- [ ] Comment sweep (§2.2).
- [ ] Bench: `115200 MYBAUD` + reset → reconnect 115200 (Δ baud error
      observable), then restore 9600. Also fault-recovery: force a fault,
      confirm baud survives (already partially in `BENCH_CHECKLIST.md` A.5).

**Last file reviewed: `FISH_NXP_M0_812_UART0_INIT.s`** (prior:
`FISH_NXP_M0_812_SOC_INIT.s`).
