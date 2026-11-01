# FISH NXP M0 — ISR Register Audit (Stock Case)

Date: 2025-10-31
Scope: `FM0_SYSTICK_ISR` high-level path (`DOCOL_ISR`) as built by the stock
Makefile (`ast` **not** defined → the `#else` high-level branch is what ships).
Goal: preserve exactly what the inner interpreter uses — no more, no less.

---

## 1. VM Register Map (`FISH_ARM_CORTEX_M_REGS.h`)

| Reg  | Alias | Role                        | Saved by HW exception entry? |
|------|-------|-----------------------------|------------------------------|
| r0   | t     | TOS cache                   | YES                          |
| r1   | n     | 4th stack / scratch         | YES                          |
| r2   | w     | word scratch (cfa+4)        | YES                          |
| r3   | x     | execution scratch           | YES                          |
| r4   | y     | scratch (ROT, math)         | **NO**                       |
| r5   | i     | **IP (interp pointer)**     | **NO**                       |
| r6   | r     | **Return stack ptr**        | **NO**                       |
| r7   | p     | **Param stack ptr**         | **NO**                       |
| r8   | —     | (lr occupies CPU lr)        | lr: YES                      |
| r10  | ra    | local-var use only          | **NO**                       |
| r11  | rb    | local-var use only          | **NO**                       |
| r12  | k     | local-var use only / BASE   | YES                          |

Cortex-M0 exception entry pushes **r0–r3, r12, lr, pc, xPSR** automatically;
`EXC_RETURN` in lr must be kept to trigger the restore.

## 2. Inner Interpreter — Exact Register Footprint

```
NEXT   : LDM i!, {w}          → uses i (r5), w (r2)
NEXT1  : LDM w!, {x}; BLX x   → uses w (r2), x (r3), CLOBBERS lr
DOCOL  : PUSHi2r; MOV i, w    → uses r (r6), i (r5), w (r2)
SEMIS  : POPr2i               → uses r (r6), i (r5)
```

Stock ISR thread (`NONAME_STCTR_INCR`): `DOCOL, ONE, STCTR, PSTORE, MY_LTORG_ISR_SEMIS`
→ additionally touches t (r0), n (r1), p (r7) via the data stack.

**Complete set the stock ISR can clobber:** r0–r7 + lr.
**Of these, software must save:** **r4, r5, r6, r7** and the `EXC_RETURN` lr.
(r0–r3, r12 are already on the exception frame.)

`ra (r10)` / `rb (r11)` / `k (r12)` are used only inside specific SLIB words
(TYPE/string search at SLIB:805–857, IN calc :1023, :1258) — **never** by
NEXT/NEXT1/DOCOL/SEMIS and **never** by the stock ISR thread. The r10–r12
shuttle in the current prologue is unnecessary in the stock case; r12 is
hardware-saved regardless.

## 3. Defects in Current `DOCOL_ISR` (stock)

```asm
PUSH {r0-r5, lr}          // r0-r3 redundant (HW-saved); OK but wasteful
MOV  r0, r10 / r1, r11 / r2, r12
PUSH {r0-r2}              // r10/r11 unneeded in stock; r12 HW-saved
```

1. **r6 (r) and r7 (p) are NOT saved.** The test thread survives only because
   DOCOL/SEMIS nest symmetrically on the return stack and the data stack is
   net-balanced. Any future ISR thread with an unbalanced stack effect (or an
   exception mid-thread) corrupts the interrupted Forth task silently.
2. **r10–r12 shuttle is dead weight** in the stock case (see §2).
3. r0–r3 software save is redundant (HW frame already has them).

## 4. Corrected Stock Prologue/Epilogue

```asm
DOCOL_ISR:
	// HW exception frame holds r0-r3, r12, lr, pc, xPSR.
	// Inner interpreter + stack words need y,i,r,p saved (r4-r7);
	// lr (EXC_RETURN) must survive the BLX in NEXT1.
	PUSH	{r4-r7, lr}
	LDR	w, [PC, #0X4]		// target CFA (NONAME_STCTR_INCR)
	NEXT1
	.word	NONAME_STCTR_INCR	// via MY_LTORG

MY_LTORG_ISR_SEMIS:
	.word	.+5
	POPr2i				// balance DOCOL's PUSHi2r
	POP	{r4-r7, pc}		// restore y,i,r,p; pc=EXC_RETURN → HW restore
```

Contract for future ISR threads: if a called word uses `ra`/`rb` (r10/r11)
— currently only TYPE/search/number-parse words in SLIB — add the low-reg
shuttle back for r10/r11 only. `k` (r12) never needs saving (HW frame).

## 5. Linker Section-Name Mismatch (found during verify)

`FISH_NXP_M0_MEMMAP.s:7` emits:

```asm
.section FISH_Ram_MemMap, "aw", %nobits     // NO leading dot
```

`lpc812_gnu.ld` rule targets `.FISH_Ram_MemMap` **with** a leading dot:

```
section          size     vma          note
.FISH_Ram_MemMap 0x000    0x10000000   ← script rule matched NOTHING
FISH_Ram_MemMap  0xC4C    0x10000000   ← placed as ORPHAN by luck
```

The 0xC4C-byte RAM map currently lands at `ORIGIN(RAM)` only because GNU ld's
orphan placement happens to put it there; the script's `KEEP` and the
`ADDR(.FISH_Ram_MemMap)` ASSERT are checking an empty section. A future
linker/version could relocate it and silently break the VM memory map.

**Fix:** match both spellings in the script and assert on the real section:

```ld
.FISH_Ram_MemMap ORIGIN(RAM) (NOLOAD) :
{
    . = ALIGN(4);
    KEEP(*(FISH_Ram_MemMap .FISH_Ram_MemMap))
    . = ALIGN(4);
} > RAM
```

(Longer term: rename the asm section to `.FISH_Ram_MemMap` for dot-consistency.)

## 6. Build/Verify Snapshot (pre-fix, stock defconfig)

```
arm-none-eabi-gcc 13.2.1, -mcpu=cortex-m0plus -mthumb
defines: NXP_M0_812 FISH_PubRel_WORDSET NXP_M0_81x_IRC12_24MHZ
         NXP_M0_016kFlash_1KWrite NXP_M0_004kRam FISH_NO_TIMESTAMP FISH_LEAN_WORDSET

text 15204 / 16384 (93%)   data 0   bss 0
fitcheck: OK — image end 0x3B64, 156 B free before FLASH_SPAGE 0x3C00
vector[0] SP    = 0x10000D30 = _estack ✓ (ASSERT ≤ 0x10000D40)
vector[1] reset = 0x00003AB5 → Reset_Handler ✓ → bx 0x9F9 = FM0_COLD|1 ✓
vector[15] systick = 0x00000A71 → FM0_SYSTICK_ISR|1 ✓
all 3 linker ASSERTs pass; only warnings: unused params in naked C stubs (benign)
```

## 7. Action Items

- [ ] `FISH_NXP_M0_COLD.s`: rework `DOCOL_ISR` prologue/epilogue per §4
      (save r4–r7 + lr; drop r10–r12 shuttle; document the ra/rb contract).
- [ ] `lpc812_gnu.ld`: accept `FISH_Ram_MemMap` (no-dot) input section per §5.
- [ ] Rebuild; re-run fitcheck + vector/symbol verification.
