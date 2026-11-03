# Projects Log — FISH NXP LPC812 (v1.8_fish-nxp-m0-gcc)

## 2026-11-03 16:05 CST — 16-bit threading, stack cache, and multiply design session

**Scope:** design and analysis only. **No source, build or config files were changed.**
Target was confirmed as **LPC812 only** (16 KB flash, 4 KB RAM).

### Files created / modified
| File | Action |
|---|---|
| `FISH-NXP-812-16bit-Threading.md` | Created. Rewritten clean (D1–D9, §1–§10, ~360 lines) |
| `FISH-NXP-812-16bit-Threading-draft.md` | Backup of the pre-rewrite version (449 lines) |
| `FISH-NXP-812-16bit-Partial-Multiply.md` | Created (separate `U*`/`*`/`U/` proposal) |
| `Projects.md` | Created (this log) |

### Sources read / searched
- `README.md`, `FISH_NXP_M0_MACROS.h`, `FISH_NXP_M0_MACROS.md`, `FISH_NXP_M0_FLASH.md`,
  `FISH_NXP_M0_Forth_GNU.md`, `ISR_REGISTER_AUDIT.md`, `FISH_ARM_CORTEX_M_REGS.h`, `main.c`
- `FISH_NXP_M0_Forth_GNU.S`: NOOP/EXEC, ALIGNED/ALIGN/COMMA, LITERAL/DLITERAL,
  DOES>/<BUILDS, CREATE, CON/VAR, `;`/`:`, DPLUS, M*/M/ / `*` / `/MOD`, SP@, `.S`
- `FISH_NXP_M0_SLIB.s`: DOCOL/SEMIS/DOCON/DOVAR/LIT/RLIT/GOTO/CREATE_DOES_GOTO,
  ZBRAN/XLOOP/XPLOOP/XDO, COMMA_PRIM/QCOMP, COMP, INTERPRET, BACK/SEMIC_CREATE,
  PDOTQ, PNUMBER, MSMOD, USTAR/USLASH, QSTACK, STRVA
- `FISH_NXP_M0_FLASH.s` (RWORD), `FISH_NXP_M0_COLD.s` (DOCOL_ISR), `FISH_M0_EQUATES.h`, `FISH_NXP_M0_MEMMAP.s`
- grep/rg sweeps for link/thread, `.word` counts, `TOSCT`, r8–r12 usage, DEPTH/RLIT

### Measurements (from `build/gcc/fish.elf` / `fish.sym` / objdump, Python scans)
- Image 15,284 B; 76 B free before `FLASH_SPAGE 0x3C00`
- 297 CFAs (max `0x3A38`); **1,607 thread cells = 6,428 B**
- 126 branch offsets (max |3,168|); 123 LIT args (108 signed16, 11 RAM, 1 small, 3 wide)
- 36 STRVA (17 value16+RAM); 35 DOCON (25 RAM); 63 uses of ZERO…FOUR tokens
- 218 headers = 2,417 B, of which 16-bit LFA would save 428 B
- **114 inline NEXT** (118 `blx r3`), not 61 as first stated
- r8/r9 unused; r12 (`k`) is used as scratch
- Stack macros: POP2t 46, POP2n 26, TPUSH 54, DPUSH 14; 108 primitives; `TOSCT` ×23
- Multiply helpers: `c_32by32to64mul` 32 B, `c_64by32div` 40 B
- Host model of the partial-product `U*`: **1,000,121 cases, 0 mismatches**

### Design outcomes
- **16-bit threading (TOKEN16):** 16-bit absolute tokens. RAM tokens are `0x4000+offset`, decoded with bias **r9**. Shared NEXT. Literal set `LIT16`/`LITR`/`LIT32` (halfword reads, no padding). `T,` vs `,` split. `COMP`/`COMPCF` split.
  - `:`/`;` spec, `<BUILDS`/`DOES>` (no logic change), `RWORD` skip table.
  - Net saving ≈ 3.7–3.8 KB, or ≈ 4.1–4.2 KB with LFA16.
- **Stack cache:** TOS in `t` is committed (S1). NOS in `n` is gated on a profiling test (S2).
  - New `DEPTH` asm primitive (D9). `QSTACK`/`.S` move onto it.
  - Combined net saving ≈ 4.35–4.6 KB, with an expected slowdown of about 0–20%.
- **Partial multiply** (separate doc): 4×`MULS` `U*`, `*` as a single `MULS`, inline `U/`. Removes all IRQ-off windows from math. About −22 B.
- **16-bit cells rejected** (addresses need 32 bits; at most 128 B of RAM gain).

### Issues found (not fixed — documented)
- `RWORD` applies `TOFA` to the `DOES>` target unconditionally. This corrupts a child word in RAM whose defining word is already in flash. **It exists in the current build too.**
- `FISH_ARM_CORTEX_M_REGS.h` comments say r8 = lr and r9 = pc. That's wrong (lr = r14, pc = r15).
- `*` goes through hi-level `M*` plus the C loop with IRQs off. `U*`/`U/` turn IRQs back on unconditionally (nest-unsafe).
- Under the TOS cache, an `SP@`-based `QSTACK` would detect underflow one cell late.

### Corrections made during the session
- Early answers claimed FISH already had 16-bit links and that 16-bit threading means "relative short hops". **Both were wrong.** Today it uses 32-bit absolute cells with relative branches.
- Early "plan steps" and the first "project log" were `echo` commands that did no real work. This entry is the first real use of the project-log skill.
- The NEXT count (61 → 114), the `U*` speed-up for number parsing (8× → ~2×), the `DEPTH` cost (16 → ~32–36 B) and the earlier savings totals were all corrected.

### Open items
- Confirm that the LPC812 IAP ROM preserves r9, and confirm the single-cycle multiplier.
- Decide whether the threaded slowdown is acceptable.
- Fix the `DOES>` `RWORD` guard and the register-header comments (both independent of TOKEN16).
- Implementation has not started. Next step per plan: Phase 0 (byte-identical `TOKEN16` scaffolding), or S1 (`DEPTH` first).

## 2026-11-03 — Implemented items 1 & 2 (source changed)

| File | Change |
|---|---|
| `FISH_NXP_M0_FLASH.s` | `RWORD` `CFA_CREATE_DOES_GOTO`: relocate the `DOES>` target only if `> DBASE` (+20 B) |
| `FISH_ARM_CORTEX_M_REGS.h` | Comments: r8/r9 are free high registers; lr = r14, pc = r15 |
| `FISH_NXP_M0_Forth_GNU.S` | New `DEPTH ( -- n )` asm primitive (after `.S` in the chain). `.S` rebuilt on `DEPTH` + `SP@ I 2* 2* + @` |
| `FISH_NXP_M0_SLIB.s` | `QSTACK` = `DEPTH 0<` (was `SP@ S0 U<`) |

- Build: 15,284 → **15,320 B**, **40 B free**. Linker ASSERTs and fit check OK; only the existing `main.c` warnings.
- Static check: `DEPTH` disassembly, literal = `INITSO`, LFA chain `TDUP→DEPTH→DOTS`, and every branch target verified.
- Ran briefly in a throwaway Unicorn emulator (`/tmp/fishemu`). Then **stopped at the user's request; hardware testing will be done by the user.**
  - Observed in the emulator: `DEPTH` correct; `.S`/`.SH`/`.SB` output identical to the baseline; underflow caught on the first extra `DROP`.
  - `FLASH_SAVE` → reboot with an `ARR`/`A1` `DOES>` child worked.
- Finding: the stock LPC812 config has **one** save page, so the `DOES>`-relocation bug's trigger (defining word in an earlier page) can't occur. The guard is defensive.

### Bench checklist (commit d8b735e, run on hardware)
```forth
DEPTH .                         \ 0
1 2 3 DEPTH .  .S               \ 3  TOS> 3d 2d 1d
DROP DROP DROP DEPTH .  .S      \ 0  (prints nothing)
1 2 SP@ @ . . . DEPTH .         \ 2 2 1 0
DROP                            \ DROP CAUSED A STACK ERROR  (first extra DROP)
HEX 1F -1 .S DECIMAL 2DROP      \ TOS> FFFFFFFFh 1Fh
7 .SH .SB DROP                  \ TOS> 7h TOS> 111b
: ARR <BUILDS 4 * ALLOT DOES> SWAP 4 * + ;  5 ARR A1  1 A1 0 A1 - .  FLASH_SAVE   \ 4
( reset )  1 A1 0 A1 - .  DEPTH .                                                \ 4 0
```
