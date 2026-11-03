# FISH-NXP-812 — 16-bit Threading Design

Target: **LPC812 only** (Cortex-M0+, 24 MHz, 16 KB flash in 1 KB pages, 4 KB RAM). Other LPC8xx parts are out of scope.
Baseline: `build/gcc/fish.elf` **15,284 B**, 76 B free before `FLASH_SPAGE 0x3C00`.
Status: **design only, no code changed.** Replaces `FISH-NXP-812-16bit-Threading-draft.md`.
Related (independent): `FISH-NXP-812-16bit-Partial-Multiply.md`.

---

## 1. Summary

Turn FISH into a **16-bit-threaded, 32-bit-cell Forth**:

- Thread tokens, branch offsets, most inline literals and header links become 16-bit.
- Cells, both stacks, `@ ! ,`, `CON`, `VAR`, `NUMBER` and code fields stay 32-bit.
- Expected net saving: **≈ 3.7–3.8 KB, or ≈ 4.1–4.2 KB with 16-bit header links (Phase 5) — 3–4 flash pages**. Today only one page (0x3C00) is left for `FLASH_SAVE`.
- Cost: threaded code runs **about 20–40% slower**, because `NEXT` roughly doubles in cycles.
- **Goal: keep TOS (and NOS) in registers.** TOS in `t` (r0) is committed. It
  recovers most of the `NEXT` slowdown and saves about 0.25–0.4 KB more. NOS in
  `n` (r1) is a goal with a **measurement gate**, because a fixed two-register
  cache makes pushes and drops more expensive (§4.4).

Key decisions:

| # | Decision | Section |
|---|---|---|
| D1 | Token = CFA for flash (< `0x4000`). RAM CFA → `0x4000 + (addr − 0x1000_0000)`, decoded with bias register **r9** | §4.1 |
| D2 | Code fields, `CON`/`VAR` bodies and `DOES>` targets stay 32-bit and 4-aligned | §3 |
| D3 | A shared `NEXT` reached by `B`/`BL`, with inline copies only in hot primitives | §4.2 |
| D4 | Literals: `0..4` token / `LIT16` / `LITR` / `LIT32` (halfword reads, never padded) | §6 |
| D5 | `,` is always 32-bit data. `T,` is the only word that emits tokens | §3 |
| D6 | Everything sits behind the `TOKEN16` build switch. With it off, the image must be byte-identical | §9 |
| D7 | **TOS cached in `t` (r0)** between primitives, behind a `TOS_CACHE` switch. This replaces the broken `TOSCT` | §4.4 |
| D8 | **NOS cached in `n` (r1)** behind a `NOS_CACHE` switch. Adopted only if the §4.4.4 gate passes | §4.4 |
| D9 | ✅ **Done 2026-11-03.** Add **`DEPTH`** as an asm primitive (reads `p`, correct in both builds). `QSTACK` and `.S` are rebuilt on it | §4.4.1 |

## 2. Current Model (measured from `fish.elf`)

| Element | Today | Count / size |
|---|---|---|
| Thread cells (32-bit absolute CFA) | `.word EMIT` | **1,607 cells = 6,428 B** (42% of the image) |
| CFAs | 104 prim (`.+5`), 153 `DOCOL`, 35 `DOCON`, 3 `DOVAR`, 2 `CREATE_DOES_GOTO` | 297, highest `0x3A38` |
| `NEXT` (`LDM i!,{w}; LDM w!,{x}; BLX x`) | 6 B, inline | **114 copies** (+4 `NEXT1`-only) = 684 B |
| Branch args (`ZBRAN BRAN XLOOP XPLOOP`) | 32-bit **relative**, `ADDS i,i,x` | 126, max \|offset\| 3,168 |
| `LIT` args | 32-bit | 123: 108 signed16, 1 in 0..4, 11 RAM addr, 3 other 32-bit |
| `STRVA val addr` (kernel only) | 2 × 32-bit | 36: 17 are value16 + RAM addr |
| `DOCON` bodies | 32-bit | 35: 25 RAM, 8 fit 16, 2 periph |
| Headers (name, `.balign 4,0xFF`, LFA32) | | 218 headers = 2,417 B |
| Stacks | 32 cells × 4 B each (`STACKSIZE`) | |
| Free low registers | none. **r8, r9 unused** (r12 `k` is scratch in FLASH/PFIND/SLIB) | |
| Stack caching | **none.** TOS lives in memory at `[p]`. Each primitive does `POP2t` … `TPUSH`. `TOSCT` (23 `#ifdef`s) is half-done and broken (`Forth_GNU.md` §3.2, `MACROS.md` §3.1) | 108 primitives; `POP2t` 46, `POP2n` 26, `TPUSH` 54, `DPUSH` 14 |

Note: `FISH_ARM_CORTEX_M_REGS.h` labels r8/r9 as "lr/pc". That's wrong:
on Cortex-M lr is r14 and pc is r15. r8/r9 are free, AAPCS callee-saved
high registers.

## 3. Design Rules (authoritative)

1. **16-bit:** thread tokens, branch offsets, `LIT16`/`LITR` arguments, `STRVR`
   arguments, LFAs (Phase 5), and explicit `H@ H! H,` data.
2. **32-bit:** stack cells, both stacks, `@ ! , C@`, code fields, `CON`/`VAR`
   bodies, `<BUILDS` data, `DOES>` target (cfa+4), `LIT32` value, `NUMBER`
   results, `CURRENT`/`LATEST`/`DP`.
3. **Alignment:** code fields are 4-aligned (`.balign 4,0xFF` stays). Threads
   and token arguments are 2-aligned. The M0+ has no unaligned access, so
   **no 32-bit `LDR/LDM` ever reads from a thread**. `LIT32` uses two `LDRH`.
4. **Only `T,` emits tokens, and only `,` emits 32-bit data.** Code fields are
   written by `COMPCF` (through `,`).
5. **One 16-bit address form:** flash `< 0x4000` as-is, and RAM as `0x4000 + offset`
   (`0x4000–0x4FFF`). Tokens, `LITR`, `STRVR` and LFA16 all use it. Decoding
   adds **r9 = `0x0FFF_C000`** when the value is ≥ `0x4000`.
6. The bank boundary is fixed for the LPC812: flash ends at `0x3FFF`, so RAM tokens
   start at `0x4000`. Keep it as one named equate (`TOKEN_RAM_BASE`) for
   readability and assembler checks, not for portability.
7. **Stack cache contract (D7/D8):** between primitives, `t` = TOS (and `n` =
   NOS when `NOS_CACHE` is on), and memory at `[p]` holds the next item down.
   Only `w`, `x`, `y` are free scratch. `NEXT_SHARED` uses only `w`/`x`, so it's
   compatible. The stack-macro contract lives in `MACROS.h` and nowhere else.

## 4. Virtual Machine

### 4.1 Token encoding (D1)

| Option | Decode cost in `NEXT` | Verdict |
|---|---|---|
| A. Flash-only execution | 0 | ✗ RAM words couldn't run before `FLASH_SAVE` |
| B. Branch-free bank math | +5 instructions | ✗ slowest |
| C′. **Bias in r9** | `LSRS x,w,#14; BEQ 1f; ADD w,r9` (+3) | ✅ **chosen** |
| D. i-relative tokens | +1 instruction | ✗ `FLASH_SAVE` would re-encode everything, and `'`/`EXEC` would need conversion |

Why r9:
- r9 is unused today.
- It's AAPCS callee-saved, so the IAP ROM and the C helpers preserve it (verify for the IAP ROM).
- It holds a constant, so ISRs don't need to save it.
- `COLD` loads it once.
- `ADD Rd, r9` is a 16-bit encoding on ARMv6-M.

### 4.2 `NEXT` (D3)

```asm
NEXT_SHARED:                 // 14 B
	LDRH	w, [i]
	ADDS	i, i, #2
	LSRS	x, w, #14        // 0 => flash token
	BEQ	1f
	ADD	w, r9            // RAM token -> 0x1000_0xxx
1:	LDM	w!, {x}          // code field (32-bit, aligned) - unchanged
	BLX	x                // w = cfa+4 for DOCOL - unchanged
```

| Strategy | Size of 114 sites | vs today (684 B) | `NEXT` cycles |
|---|---:|---:|---:|
| Inline everywhere (14 B) | 1,596 B | **+912 B** | ~10–11 |
| `BL NEXT_SHARED` everywhere (4 B, lr is free) | 456 + 14 | **−214 B** | ~13–14 |
| `B` (2 B, ±2 KB) with about 4 copies spread through the image, `BL` as fallback | ~290 | **≈ −390 B** | ~12–13 |
| **Chosen:** `B`/`BL` shared + inline in hot prims (`DOCOL SEMIS LIT16 ZBRAN BRAN XLOOP @ ! + DUP`) | ~430 | **≈ −250 B** | hot ~10, others ~13 |

`NEXT` takes about 7 cycles today. Threaded code should run **20–40% slower**
overall. `EXEC` and the other `NEXT1`-only sites take full addresses and don't change.

### 4.3 Primitives that change

| Primitive | New behaviour |
|---|---|
| `LIT16` | `LDRSH t,[i]; ADDS i,#2` (sign-extends) |
| `LITR` | `LDRH t,[i]; ADDS i,#2; ADD t,r9` (RAM address) |
| `LIT32` | `LDRH lo; LDRH hi,[i,#2]; LSLS hi,#16; ORRS; ADDS i,#4` |
| `ZBRAN BRAN XLOOP XPLOOP` | offset read with `LDRSH`; "not taken" skips with `ADDS i,#2` |
| `STRVR` (new) / `STRVA` | `STRVR val16 addr16(RAM form)`, 4 B of arguments. `STRVA` reads val32 and addr32 as halfwords, 8 B |
| `DOCOL SEMIS DOCON DOVAR CREATE_DOES_GOTO` | **unchanged** (code fields and `i` stay 32-bit) |
| `H@ H! H, HS@` (new) | `LDRH`/`STRH`/`LDRSH`. `H!` drops the upper 16 bits without warning |
| `COLD` | `LDR r9, =0x0FFFC000` before the first `NEXT` |

### 4.4 Stack cache: TOS and NOS in registers (D7, D8)

**Goal:** stop round-tripping the top of stack through memory on every
primitive, and get back the cycles that 16-bit `NEXT` costs.

#### 4.4.1 TOS in `t` (committed)

Invariant: `t` = TOS, and `[p]` = NOS. Memory holds everything except TOS.

| Primitive shape | Today | TOS cached | Δ per primitive |
|---|---|---|---|
| unary `( a -- b )`: `@ 1+ NOT C@ ABS…` | `LDR t,[p]; ADDS; …; SUBS; STR` | `…` only | **−4 instr, −8 B** |
| binary `( a b -- c )`: `+ - AND = <…` | `POP2t; POP2n; op; TPUSH` | `LDR n,[p]; ADDS p; op` | **−4 instr, −8 B** |
| push `( -- a )`: `LIT* DOCON DOVAR I R@ DUP` | `…; SUBS; STR t` | `SUBS; STR t` (spill) `; …` | 0 |
| consume `( a -- )`: `DROP ! ZBRAN EXEC` | `LDR t,[p]; ADDS` | use `t`; refill `LDR t,[p]; ADDS` | 0 |
| stack ops `SWAP OVER ROT` | 4–6 memory ops | 2–4 | −2 … −4 instr |

Estimate: 30–50 unary/binary primitives × 8 B gives **≈ −0.25 … −0.4 KB**.
Each executed unary or binary primitive saves about 6 cycles, against a 16-bit
`NEXT` of ~13 cycles, so caching TOS should recover **about half or more** of
the TOKEN16 slowdown. These numbers are estimates; the S1 pilot measures them (§9).

Things TOS caching touches:
- **`MACROS.h`:** redefine `POP2t`/`TPUSH`/`DPUSH`/`NDPOP2t` per the
  `MACROS.md` §3.1 decision table, then delete all 23 `TOSCT` `#ifdef`s.
- **Depth:** the first push spills a junk `t` to `[S0−4]`. So depth =
  (S0 − p)/4, **the same formula as today when computed from `p`**.
- **New word `DEPTH` `( -- n )`** (decided). It's an asm primitive that reads
  `p` *before* any spill, so the same source is correct in both builds:
  ```asm
  DEPTH:  .word .+5
          LDR   x, =INITSO
          LDR   x, [x]
          SUBS  x, x, p          // S0 - p   (p before the push)
          ASRS  x, x, #2         // cells
          // 32-bit image: MOV t,x ; TPUSH
          // TOS_CACHE:   spill t (SUBS p,#4 ; STR t,[p]) ; MOV t,x ; NEXT
  ```
  It costs about 32–36 B (header "DEPTH" 12 B + code field + about 8 instructions +
  literal). Don't build it high-level on `SP@`; see the next point.
- **`SP@` (`SPAT`):** spill `t`, then return the new `p`. That keeps the
  documented behaviour (`1 2 SP@ @ . . .` → `2 2 1`), but the value is **one
  cell lower** than in the 32-bit build. Anything that does arithmetic on `SP@` has to change:
  - **`QSTACK`** (`SP@ INITSO @ SWAP U<`) would catch underflow one cell late.
    Rewrite it as `DEPTH 0<`, which works in both builds.
  - **`.S` (`DOTS`)**: `INITSO @ SP@ 4+ … XDO … I @` walks memory. Rewrite
    it as a loop over `DEPTH` (printing the top from `t`), or fix the bounds for the
    spilled TOS and the junk cell at `S0−4`.
- **`SP!` (`SPSTO`):** reset `p`. `t` becomes junk.
- **`EXEC`:** `MOV w,t`, refill `t`, `NEXT1`.
- **`ZBRAN`:** test `t`, then refill.
- **`DOCON`/`DOVAR`/`CREATE_DOES_GOTO`/`LIT*`:** spill, then load.
- **ISRs:** r0–r3 are hardware-saved on exception entry, so cached `t`/`n`
  survive. The ISR thread's own stack use is balanced (`ISR_REGISTER_AUDIT.md`)
  and spills below `p`, which is free memory.
- **IAP calls (`FLASH.s`):** they already save `t` in `k` around the ROM call.
  With NOS caching, `n` (r1 is an IAP argument) also needs saving, in r8.
- **Asm-heavy primitives** (`PFIND`, `TIB_CHAR_SCAN`, `CMOVE`, `FILL`, `TYPE`, `DIGIT`, `USTAR`/`USLASH`):
  load their inputs from `t` plus memory, and leave TOS in `t`.

#### 4.4.2 NOS in `n` (goal, gated)

Invariant: `t` = TOS, `n` = NOS, and `[p]` = third item.

| Primitive shape | TOS only | TOS+NOS | Δ |
|---|---|---|---|
| binary `( a b -- c )` | `LDR n; ADDS; op` | `op; LDR n,[p]; ADDS` (refill) | 0 |
| push `( -- a )` (`LIT*`, `DOCON`, `DUP`, `I`) | `SUBS; STR t; load` | `SUBS; STR n; MOV n,t; load` | **+1 instr** |
| drop `( a -- )` | `LDR t; ADDS` | `MOV t,n; LDR n; ADDS` | **+1 instr** |
| `SWAP` | `LDR n; STR t; MOV t,n` | 3 × `MOV` (no memory) | −2 cycles |
| double ops `D+ 2DUP 2SWAP U* U/ M*` | memory pops | inputs already in `t`/`n` | **−2 … −6 instr** |

Risks:
- Pushes (`LIT*`, `DOCON`) are the most frequently executed primitives, and drops are close behind.
- `n` stops being scratch. Primitives that need 3+ temporaries have only
  `w x y` left and must spill. `NEXT_SHARED` takes `w`/`x`.
- The literature on threaded interpreters agrees that a single TOS register
  gets most of the benefit. Fixed two-register caching usually costs more
  moves than it saves, unless the interpreter switches caching states
  dynamically, which this design doesn't do.

#### 4.4.3 Fit with the other proposals
- **TOKEN16:** `LIT16`/`LITR`/`LIT32` are push-shaped (spill, then `LDRSH t,[i]`). `NEXT_SHARED`
  doesn't touch `t`/`n`. Both changes rewrite every primitive, so do them in one
  pass per primitive, but turn them on one at a time (§9 S1 before Phase 1).
- **Partial multiply** (`FISH-NXP-812-16bit-Partial-Multiply.md`): `USTAR` uses
  `t n w x y`. With TOS caching, `t` is an input and `n` comes from memory. With
  NOS caching, both inputs and both results (`n`=LSW, `t`=MSW) stay in
  registers, which is the best case.

#### 4.4.4 NOS adoption gate
1. Build with S1 (TOS cache) and profile how often each primitive executes,
   using the existing `ss` single-step hook (`NEXT1` → `ssNEXT1`) as a counter.
   Workloads: number entry, `WORDS`, compile a 20-line source, a `FLASH_SAVE` cycle,
   and a user DO-loop benchmark.
2. Classify the primitives (push, drop, binary, double, stack-op) and compute
   the net cycles as Σ count × Δ from §4.4.2. Measure the size change from a trial build.
3. **Adopt `NOS_CACHE` only if** net cycles improve by ≥ 5% **and** size grows by ≤ 0 B.
   Otherwise keep TOS only, and record the numbers in this section.

## 5. Compiler Words

### 5.1 Word changes

| Word | Today | Under `TOKEN16` |
|---|---|---|
| `T,` (new, `TCOMMA_PRIM`) | — | `( cfa -- )` encode (§3.5), `HALIGN`, `H!`, `2 ALLOT_PRIM` |
| `COMP` (`COMPILE`) | `R> DUP 4+ >R @ COMMA_PRIM` | `R> DUP 2+ >R H@ T,` (tokens) |
| `COMPCF` (new) | — | `R> DUP 2+ >R H@ ,` (32-bit code field) |
| INTERPRET (compiling) | `CFA COMMA_PRIM` | `CFA T,` |
| `LITERAL` | `COMP LIT ,` | choose encoding per §6.2 |
| `BACK`, `IF ELSE THEN BEGIN UNTIL AGAIN WHILE REPEAT DO LOOP +LOOP` | `,`/`!` offsets | `H,`/`H!`; placeholders are 2 B; offsets stay relative to the offset cell |
| `DOTQ` / `PDOTQ` | string + `ALIGNED` | string + `HALIGNED` |

`COMP` does two jobs today: code fields (`COMPILE DOCOL`, `COMPILE DOCON`,
`COMPILE DOVAR`) and tokens (`COMPILE SEMIS`, `COMPILE LIT`). Under
TOKEN16 they split into `COMPCF` and `COMP`.

### 5.2 `:` and `;`

```
:  = DOCOL  QEXEC SCSP CREATE ]  LIT16 -8 DP +!  COMPCF DOCOL  SEMIS
;  = DOCOL  ?CSP COMP SEMIS [  SEMIC_CREATE  SEMIS
```
- `CREATE` still lays down the header, LFA, and the `DOCON` + pfa pair. `-8 DP +!`
  still rewinds exactly that 8-byte pair.
- `COMPCF DOCOL` writes a 4-aligned 32-bit code field, and the body starts at
  cfa+4 as 16-bit tokens.
- `;` appends a 2-byte `SEMIS`. HERE may end up 2-aligned, and the next `CREATE`/`,`
  pads to 4. `CSDP` error rewind doesn't change.
- Resulting layout: `[DOCOL:32][tok:16]…[SEMIS:16]`.

### 5.3 `<BUILDS` and `DOES>` (no logic change)

```
<BUILDS = DOCOL CREATE SEMIS
DOES>   = DOCOL R> LATEST PFA DUP CFA LIT CREATE_DOES_GOTO SWAP ! ! SEMIS   (not IMMEDIATE)
CREATE_DOES_GOTO: PUSHi2r; LDR i,[w]; ADDS w,#4; PUSHw; NEXT
```

| Child `nnnn` | Before `DOES>` | After | Width |
|---|---|---|---|
| cfa | `DOCON` | `CREATE_DOES_GOTO` | 32-bit |
| cfa+4 | `cfa+8` | full address of the does-thread | 32-bit |
| cfa+8… | user data (`,` `C,` `ALLOT`) | same | 32-bit |

- The defining word `CCcc` is `[DOCOL:32] <BUILDS … DOES> …does-thread… SEMIS`,
  with all 16-bit tokens.
- The does-thread address comes from `R>` as a full 32-bit address, so RAM
  and flash both work without decoding. It may be only 2-aligned, which is
  fine because it's loaded with `LDR i,[w]` from an aligned cell.
- In the `DOES>` kernel thread, `LIT CREATE_DOES_GOTO` becomes `LIT16` (0x6E7).

## 6. Numbers and Constants

### 6.1 The outer interpreter and stacks stay 32-bit
- **Interpret state:** `NUMBER` → `PNUMBER` builds a 64-bit double
  (`U*`/`D+`) and pushes 32-bit cells. Nothing changes.
- **Compile state:** the same value goes to `LITERAL`/`DLITERAL`. That is the only
  place a 16-bit encoding is chosen, and the round-trip is exact.
- **16-bit cells were rejected.**
  - They'd save at most 128 B of stack RAM.
  - RAM `0x1000xxxx`, peripherals `0x4004xxxx`, GPIO `0xA000xxxx` and NVIC
    `0xE000xxxx` addresses would all become doubles.
  - The CPU registers are 32-bit, so there'd be no speed gain.
  - See `FISH-NXP-812-16bit-Partial-Multiply.md` §2.

### 6.2 Literal encodings (`LITERAL` picks the first that fits)

| Order | Encoding | Bytes | Condition |
|---|---|---:|---|
| 1 | `ZERO`…`FOUR` token (optional `TRUE` for −1) | 2 | 0..4 |
| 2 | `LIT16` | 4 | −32768..32767 (**signed**: 65535/0x8000 go to `LIT32`) |
| 3 | `LITR` | 4 | `0x1000_0000`..`0x1000_0FFF` |
| 4 | `LIT32` | 6 | anything else |

Today every literal costs 8 B. `DLITERAL` is two `LITERAL`s, so a 64-bit
double is handled automatically.

**Kernel assembler macros.** RAM variables (`PAD`, `TIB`, `CSDP`, `FLASHRET`) are
relocatable `.bss` labels, so `PAD & 0xFFFF` won't assemble. But
`PAD − 0x0FFFC000` does: it emits `R_ARM_ABS16` with an addend, and the linker
checks the range.
```
.macro L16 n ; .hword LIT16, \n                          ; .endm
.macro LR  a ; .hword LITR,  (\a - 0x0FFFC000)           ; .endm
.macro L32 n ; .hword LIT32, (\n) & 0xFFFF, (\n) >> 16   ; .endm   // absolute only
.macro T   a ; .hword \a                                 ; .endm   // flash CFA
```

### 6.3 Constants vs inline literals
`CON` bodies stay `[DOCON:32][n:32]`. Each *use* is a 2-byte token.

| Value | Inline per use | `CON` per use | `CON` one-off (4-char name) | Break-even |
|---|---:|---:|---:|---:|
| signed 16 / RAM address | 4 B | 2 B | ~20 B | ~10 uses |
| 32-bit (periph, mask) | 6 B | 2 B | ~20 B | **~5 uses** |
| kernel `:NONAME DOCON` | — | 2 B | 8 B | 2–4 uses |

Don't add `CON16`. The next header pads back to 4, so it saves about nothing.

## 7. `FLASH_SAVE` / `RWORD`

`RWORD` (`FLASH.s` 126) walks threads in 4-byte steps and relocates any cell
`> DBASE`. Under TOKEN16 it:

- steps 2 bytes at a time, relocating tokens in `0x4000–0x4FFF` into flash form;
- **skips every inline argument by its size**, because 16-bit literals and offsets can
  look like RAM tokens:

| After token | Skip |
|---|---:|
| `LIT16`, `LITR`, `ZBRAN`, `BRAN`, `XLOOP`, `XPLOOP` | 2 |
| `LIT32` | 4 |
| `STRVA` / `STRVR` | 8 / 4 (kernel only) |
| `PDOTQ` | count + string, `HALIGNED` |

- `LITR`, like `LIT` today, is **not** relocated, because RAM variables don't move.
- The `CREATE_DOES_GOTO` case (cfa+4, 32-bit `TOFA`) stays the same.
- ✅ **Fixed 2026-11-03** (`FLASH.s`, `DBASE >` guard; unreachable with the stock single save page, so the fix is defensive). Was: **existing bug (also in the current 32-bit build):** `TOFA` is applied
  to cfa+4 unconditionally. If the defining word is already in flash and the
  child is in RAM, the pointer gets corrupted. Fix: guard it with `DUP DBASE >`,
  as `RELOC_THIS_WORD` does. Fix this independently of TOKEN16.

## 8. Savings and Costs (reconciled)

| Item | Now | TOKEN16 | Δ |
|---|---:|---:|---:|
| Thread tokens (1,607) | 6,428 | 3,214 | −3,214 |
| Branch offsets (126) | 504 | 252 | −252 |
| `LIT` args (123) | 492 | ~250 | −240 |
| `STRVA` args (36) | 288 | 220 | −68 |
| `NEXT` (114 sites, §4.2 chosen) | 684 | ~430 | −250 |
| New/changed primitives and compiler words (`LIT16/LITR/LIT32/STRVR`, `H@ H! H, T, COMPCF HALIGN`, `LITERAL` select, `RWORD` skips) | — | — | +250 … +350 |
| **Net, Phases 1–4** | | | **≈ −3.7 … −3.8 KB** |
| LFA16 (Phase 5; LFA at CFA−2, measured across 218 headers) | 2,417 | 1,989 | −428 |
| **Net with Phase 5** | | | **≈ −4.1 … −4.2 KB** |
| TOS cache (S1; 30–50 unary/binary primitives × 8 B, estimate) | | | −250 … −400 |
| NOS cache (S2) | | | gate: ≤ 0 B or rejected |
| **Net with S1 + Phases 1–5** | | | **≈ −4.35 … −4.6 KB** |

Other effects:
- RAM-compiled words take about half the dictionary space.
- **Speed:** TOKEN16 alone makes threaded code about 20–40% slower. With the
  TOS cache, the expected net is about **0–20% slower** (S1 measures it).
- **Range safety:** `.hword` makes the linker reject any token that doesn't fit.

## 9. Implementation Phases

| Phase | Work | Exit check |
|---|---|---|
| 0 | Add the `TOKEN16` define (default off), `T/L16/LR/L32` macros, and split mixed lines (`.word DOCOL, LIT, 0x07, EMIT, SEMIS`) into a code field and a token line | **Byte-identical** image with `TOKEN16` off |
| S1 | **TOS cache on the 32-bit image** (§4.4.1): `TOS_CACHE` switch, macro contract, delete `TOSCT`. **Add `DEPTH` first, with the cache off**, and move `QSTACK`/`.S` onto it. Then convert all 108 primitives and the asm escapes, and update `SP@`/`SP!`/`EXEC`/`ZBRAN`/IAP | `DEPTH` S-tests pass on the stock build first, then with `TOS_CACHE`; `make size` and cycle counts recorded; T1–T7 run again once TOKEN16 lands |
| S2 | **NOS gate** (§4.4.4): profile, trial `NOS_CACHE` build, decide | Decision and numbers recorded in §4.4.4 |
| 1 | VM: r9 init in `COLD`, `NEXT_SHARED` + hot inline copies, `LIT16/LITR/LIT32`, `STRVR/STRVA`, 16-bit branch/loop args, `H@ H! H, HS@` | Kernel boots; signon and `WORDS` work |
| 2 | Convert threads with a script, then review by hand: `SLIB.s` → `Forth_GNU.S` → `FLASH.s` → `COLD.s`/`SOC_INIT.s`/`UART0_INIT.s` (~1,750 `.word` lines) | `make size` matches §8; linker ASSERTs pass |
| 3 | Compiler (§5, §6.2): `T,`, `COMP`/`COMPCF` split (`:`, `CREATE`, `VAR`), `;`, INTERPRET, `LITERAL`, branch compilers, `DOTQ`/`PDOTQ` | Tests T1–T7 pass from RAM |
| 4 | `RWORD` (§7): 2-byte stride, skip table, `DOES>` guard | `FLASH_SAVE` → reset → T5–T7 run (bench) |
| 5 | Optional LFA16: header layout `[name][pad][LFA16][CFA]`, PFIND (`SLIB.s` ~858), `FLASH_FORGET` relink, `RW_UNTIL` LFA relocation | Measured −428 B; `WORDS`/`FORGET` OK |

### Acceptance tests
```forth
: T1 ;                     \ [DOCOL][SEMIS]                    = 6 B body
: T2 1 2 + . ;             \ ONE TWO + . SEMIS (0..4 tokens)   = 4+2+2+2+2+2 = 14 B
: T3 100000 . ;            \ LIT32 lo hi . SEMIS               = 4+6+2+2     = 14 B
: T4 5 0 DO I . LOOP ;     \ 16-bit loop offset back-patch
: T5 T2 T4 ;               \ RAM tokens 0x4xxx via r9
: ARR <BUILDS 4 * ALLOT DOES> SWAP 4 * + ;
10 ARR A1  : T6 1234567 3 A1 ! 3 A1 @ . ;       \ 32-bit data + LIT32 -> 1234567
70000 CON BIG  -5 CON NEG
: T7 BIG . NEG . 65535 . 32767 . -32768 . ;     \ -> 70000 -5 65535 32767 -32768
T1 T2 T3 T4 T5 T6 T7  FLASH_SAVE  ( reset )  T5 T6 T7
```
Stack-cache tests (S1/S2, run on both the 32-bit and TOKEN16 images):
```forth
DEPTH .  1 2 3 DEPTH .  .S  DROP DROP DROP DEPTH .   \ 0 3 TOS> 3 2 1  0
1 2 SWAP . .  1 2 OVER . . .  1 2 3 ROT . . .        \ 1 2 / 1 2 1 / 1 3 2
1 2 SP@ @ . . . DEPTH .                              \ 2 2 1 0  (SP@ spill keeps the documented behaviour)
5 SP@ @ . DROP                                       \ 5
DROP DEPTH .                                         \ underflow error on the FIRST extra DROP, then 0
' DUP 7 SWAP EXEC . .                                \ 7 7  (EXEC refill)
1 0 IF 2 THEN .                                      \ 1    (ZBRAN refill)
65536 65536 M* D.  12345 6789 * .                    \ double ops through t/n
: SPIN 10000 0 DO I DROP LOOP ;  SPIN               \ with SysTick running: STCTR advances, no stack drift
```
Run `FLASH_SAVE` with words on the stack. The stack should be unchanged after the IAP calls.

Check each body with `' Tn 20 DUMP`. After `DOCOL`, the only 32-bit values
should be the two halves of a `LIT32`.

## 10. Open Questions

1. Confirm that the LPC812 IAP ROM preserves r9 (AAPCS callee-saved). Otherwise, reload r9 after `FLASHPREP`/`FLASHESEC`/`FLASHCRTF`.
2. Is the remaining threaded slowdown acceptable? It's 20–40% with TOKEN16 alone, or about 0–20% with the S1 TOS cache. (UART at 9600 bps is not the bottleneck.)
3. ✅ r8/r9 comments fixed (2026-11-03). Still to do in Phase 1: add `#define rbias r9`.
4. Verify that the backward NFA traverse (`NFA`/`TRAVERSE`) still skips the 0xFF pad when LFA16 sits at CFA−2 (Phase 5).
5. Bound the RAM dictionary below 4 KB, so RAM tokens stay within `0x4000–0x4FFF`.
