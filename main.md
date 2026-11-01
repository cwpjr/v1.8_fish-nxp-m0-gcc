# main.c — Code Review

Date: 2025-10-31
Scope: the C helper layer — CMSIS IRQ wrappers, two naked Thumb-1 math
routines, optional `main()`. 110 lines. History: created in the
size-engineering pass (`PORTING_PLAN.md` §"Size Engineering": replaced
~716 B of libgcc 64-bit runtime with ~76 B naked asm, bit-exactness
validated against 50k+ randomized cases).
Build context: stock defconfig, `-Os -ffreestanding`, links `-lgcc`.

---

## 1. Contents & Verification

| Symbol | Role | Check |
|---|---|---|
| `C_CMSIS_DISABLE_IRQS` / `C_CMSIS_ENABLE_IRQS` | `__disable_irq()`/`__enable_irq()` (PRIMASK) | trivially correct; **nest-safety contract** in §2.1 |
| `c_32by32to64mul(int a, int b)` | shift-add 32×32→64, out r0=LSW r1=MSW | algorithm re-verified vs §1.1; ABI matches `USTAR` call site (SLIB §4) ✓ |
| `c_64by32div(int divisor, long long dividend)` | shift-subtract restoring division, in r0 + r2:r3, out r0=quo r2=rem | 50k randomized cases (per source comment) + structure re-check §1.1 ✓; `DZERO` (÷0 → `-1,-1`) handled at the Forth call site ✓ |
| `main()` (`USE_CMAIN` only) | `while(1) FM0_COLD();` | pairs with `RET2c` LR stack handoff in COLD.s; OFF in stock ✓ |

### 1.1 Structure re-check of the two loops
- mul: classic LSB-first shift-add; `cmp r0,#0 / bne` termination after the
  shift → correct for a=0 (result 0) ✓; 64-bit add via `adds/adcs` pair ✓.
- div: MSB-first restoring division; `bcs 2f` rem-overflow safety net; the
  documented precondition (`dividend_hi < divisor`, Forth U/ rule) is what
  keeps the quotient in 32 bits — satisfied by `MSMOD`/`DIG` and the baud
  path by construction ✓ (SLIB §4).
- Both push/pop their callee-saves (`r4`/`r4,r5`) ✓ AAPCS-clean.

## 2. Findings

### 2.1 ⚠️ `C_CMSIS_ENABLE_IRQS` is not nest-safe — now a written contract
`__enable_irq()` unconditionally clears PRIMASK. Any code that runs inside a
`CMSIS_DISABLE_IRQS … CMSIS_ENABLE_IRQS` window and internally calls
`USLASH`/`USTAR` (i.e. **any number printing**: `DIG → MSMOD → USLASH`)
would re-enable interrupts mid-window.
- Author's own code already avoids it: `ASSUREPAGE`/`FF_LOOP` print only
  after re-enable ✓.
- My `FLASHQERR` addition initially violated it (its error path prints
  inside `FLASHWRITE`'s window) — **fixed this session** by splitting
  `FLASHWRITE` into two windows with the checks outside (see
  `FISH_NXP_M0_FLASH.md` §3.2 amendment).
- Rule going forward: *between IRQS_SUSPEND and IRQS_RESUME, only
  non-printing words.* Candidate hardening: make the C wrappers
  save/restore PRIMASK (read-modify-write `__get_PRIMASK()`) — deferred;
  costs bytes on a 76 B margin and current call sites are all flat pairs.

### 2.2 Verified-good
- `-Wunused-parameter` warnings on the naked routines are inherent to
  `__attribute__((naked))` (args live in registers) — correctly identified
  as benign in the original build review; do not "fix" by naming usage.
- `#include "LPC11xx.h"` + `core_cm0.h` resolve to the local copies ✓;
  no IAR headers leak (PORTING_PLAN §5).
- `-lgcc` retained for future C needs; currently nothing pulls from it
  (that's the point of the size pass).

## 3. Action Items

- [x] FLASHWRITE window split (§2.1) — DONE, fitcheck OK (76 B free).
- [ ] Add the "no printing inside IRQ-off windows" contract as a comment
      above the wrappers (§2.1).
- [ ] Bench stress exists in `BENCH_CHECKLIST.md` A.3/A.4 (÷, M*) ✓;
      post-review additions appended there (§C).

**Last file reviewed: `main.c`** (prior: `io_NXP_M0+_header.h`).
That completes the sweep of all remaining files.
