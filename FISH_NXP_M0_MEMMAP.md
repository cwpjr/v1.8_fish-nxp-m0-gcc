# FISH_NXP_M0_MEMMAP.s — Code Review

Date: 2025-10-31
Scope: the `FISH_Ram_MemMap` NOLOAD section — every FISH system variable,
buffer, and the flash-save signature block. 68 lines, ~0xC4C bytes allocated.
Addresses below are from the verified stock build (`build/gcc/fish.sym`).
Build context: stock defconfig (see `FISH_NXP_M0_Forth_GNU.md` §2).

---

## 1. Verified RAM Layout (4K part, `RAM_START 0x10000000` / `RAM_END 0x10001000`)

```
0x10000000  SYSCLOCK FPA FPC FPSV        flash-page signature block (0x10)
0x10000010  ORIG … DICTSPACE_END         dictionary workspace, 2600 B
0x10000A38  PAD (96)  TIB (96)           IOBUFSIZE each
0x10000AF8  FLOW_STATE (1)               ← 1-byte hole, see 3.1
0x10000AF9  STICKER (4)                  ✗ UNALIGNED — HardFault vector
0x10000AFD  RAMVARSPACE (24×4 = 96)      ✗ UNALIGNED — all user VAR cells
0x10000B60  NBASE … ERROR_HALT CSP NDPL NHLD   (.balign 4 repairs here)
0x10000BA4  FLASHCMD (80; 20 used)  FLASHRET (64; 16 used)
0x10000C34  I2CCMD/I2CROLE/I2CSTATE/I2CBUFFER (24)  ← zero references
0x10000C4C  SV_END
            ── linker script territory ──
0x10000C4C  .heap (0x44)
0x10000C90  .stack (0xA0) → _estack 0x10000D30   (ASSERT ≤ 0x10000D40 ✓)
0x10000D40  DBAUD / UBAUD … ALL_UNINITRAM_END 0x10000EEC
            preserved across reset (MYBAUD mechanism); 420 B free at +8
0x10000EEC  COLD pattern-fill … BOTTOM_RSTACK 0x10000EF0
0x10000EF0  return stack ↓ 128 B → RINIT 0x10000F70
0x10000F70  (gap 0x70)  … PINIT 0x10000FF0; param stack ↓ 16 B → RAM_END
```

## 2. Verified-Good Mechanics

- **Flash signature block** (`SYSCLOCK FPA FPC FPSV` = page offset
  0/4/8/0xC) matches `FLASH_SCAN` exactly: `[pg+0]==SYSCLK` magic,
  `[pg+8]→CURRENT_SV`, `[pg+0xC]→UP_SV` (see `FISH_NXP_M0_FLASH.md` §1).
- **MYBAUD preservation**: `DBAUD/UBAUD` at `ALL_UNINITRAM_START 0xD40` sit
  between the two `FM0_COLD` fill loops → survive warm/hard-fault resets ✓.
- **FISH stacks** (`PINIT`/`RINIT`/`BOTTOM_RSTACK`) derived from `RAM_END`
  arithmetically — consistent with COLD literal pool and `STACKSIZE 128`.
- **Linker contract**: `SV_END 0xC4C` = `_heap_start` exactly; the fixed
  linker rule now genuinely matches this section (no more orphan — see
  `ISR_REGISTER_AUDIT.md` §5).

## 3. Findings

### 3.1 🐛 CRITICAL — `FLOW_STATE` (1 byte) un-aligns `STICKER` and the whole VAR space
```
10000af8  FLOW_STATE   .space 1
10000af9  STICKER      .space 4    ← LDR/STR word access on odd address
10000afd  RAMVARSPACE  24 VAR cells, all odd
```
ARMv6-M has **no** unaligned word access — every hit is a HardFault:
- `DELAY`/`MS`: `STR t, [STICKER]` → fault on first use.
- SysTick ISR (either path): asm `STR t,[STICKER]`, or hi-level
  `ONE STCTR PSTORE` → fault on first tick after `SYSTICK_IRQ_ON`.
- Any user `VAR x` + `x @`/`!` → fault (UP initializes to
  `RAMVARSPACE_START` via `FISH_ONLY`).

Regression introduced when `FLOW_STATE` was inserted (XON/XOFF dedup
feature) without re-alignment. **Fix**: `.balign 4` immediately after
`FLOW_STATE` (cost: 3 B RAM). All references are by label (`STICKER`,
`RAMVARSPACE_START`, `VBASE`, `FISH_ONLY`) — shifting is safe. Rebuild and
re-check `fish.sym` for `STICKER % 4 == 0`.

### 3.2 ⚠️ `FLOW_STATE` never initialized — pattern fill collides with `XON_CHAR`
The dedup design (documented in `XOFF_SUBR`'s comment block) assumes
"`.space` zero-fills … the first XON at boot is a real transition". But
`FM0_COLD` fills this region with `0x11111111`, whose low byte `0x11` **is**
`XON_CHAR` (17). If boot reaches `EXPECT` without a prior `EXEC` (e.g.
`ABORT` finds no `RUN` → straight to `QUIT`), the first XON is swallowed and
a host gated by a pre-reset XOFF stays gated — terminal looks dead.
**Fix**: add `FLOW_STATE` (value `0xFF` or `0`) to `FWARM`/`SV_INIT_VALUES`
in `SLIB.s`, or accept it only works when `RUN` is defined. (Either way,
3.1's fix must land first — the two fixes are independent.)

### 3.3 ⚠️ IAP scratch overlaps the parameter stack's top cells
UM10398: flash commands use the **top 32 bytes of RAM**
(`0x10000FE0–0x10000FFF`). `PINIT = 0x10000FF0` puts the parameter stack's
top 4 cells inside that window. Safe today only because stacks grow
*downward* and live cells during `FLASHCRTF` sit far below (param depth < 4,
return depth < ~26 during IAP). Freeze as a contract comment near `PINIT`:
"param stack must hold < 4 cells at any IAP call; return stack < 26 deep."

### 3.4 Dead / over-allocated
- `I2CCMD/I2CROLE/I2CSTATE/I2CBUFFER` (24 B): zero references tree-wide —
  vestigial or future work; label as such.
- `FLASHCMD` 80 B for 20 B used, `FLASHRET` 64 B for 16 B (carried from
  `FISH_NXP_M0_FLASH.md` open items — this is where they live).

### 3.5 Stale comments
Header cites LPC1114/UM11049 testing and IAR-isms (".bss", `CSTACK$$Limit`,
IAR project menu paths, the commented `BOTTOM_IAPSTACK` block). The GNU
reality is the linker script + `FISH_M0_EQUATES.h`; reword on next touch.
"REARRANGE LATER FOR TASKING" note retained deliberately (multitasking
offsets) — keep.

## 4. Action Items

- [x] **`.balign 4` after `FLOW_STATE`** (§3.1) — DONE 2025-10-31. Verified in
      `fish.sym`: `STICKER 0x10000AFC`, `RAMVARSPACE_START 0x10000B00`,
      `NBASE 0x10000B60` — all 4-aligned. Net RAM cost **0 B** (the pad
      bytes moved into the slack the post-RAMVARSPACE `.balign` was already
      absorbing; `NBASE..SV_END` unchanged, section still 0xC4C).
      Flash image unchanged: 15,272 B, fitcheck OK (88 B free).
- [ ] Init `FLOW_STATE` in `FWARM` SV init (§3.2).
- [ ] IAP/param-stack contract comment at `PINIT` (§3.3).
- [ ] Label or remove the I2C allocation; right-size `FLASHCMD`/`FLASHRET`
      (§3.4).
- [ ] Bench after 3.1+3.2: `VAR T  5 T !  T ?` (expect `5`), `10 MS`,
      `SYSTICK_IRQ_ON STCTR ?` — add to `BENCH_CHECKLIST.md`.

## 5. Build Impact

§3.1 applied: zero RAM cost (pad absorbed by existing `.balign` slack),
flash image unchanged (15,272 B / 88 B free). Remaining items (3.2–3.5)
are small and independent.
**Last file reviewed: `FISH_NXP_M0_MEMMAP.s` (align fix applied & verified).**
