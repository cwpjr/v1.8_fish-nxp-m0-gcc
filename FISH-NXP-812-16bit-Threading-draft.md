# FISH-NXP-812 — 16-bit Threading Opportunity

Target: LPC812, Cortex-M0+, 16 KB flash / 4 KB RAM, `NXP_81x_PubRel` word set.
Baseline image: **15,284 B text, 76 B free** before `FLASH_SPAGE 0x3C00`
(`FISH_NXP_M0_FLASH.md` §5). Status: **proposal / analysis only, no code changed.**

---

## 1. Current Model (as built)

FISH is an indirect-threaded hybrid with 32-bit cells throughout:

| Element | Encoding today | Source |
|---|---|---|
| Thread cell (token) | 32-bit **absolute** CFA (`.word EMIT`) | `FISH_NXP_M0_Forth_GNU.S`, `SLIB.s`, `FLASH.s` |
| Code field | 32-bit: `.word .+5` (primitive) or `DOCOL`/`DOCON`/`DOVAR`/`CREATE_DOES_GOTO` | `SLIB.s` 662–760 |
| `NEXT` | `LDM i!,{w}` → `LDM w!,{x}` → `BLX x` (6 B, inlined 61×) | `FISH_NXP_M0_MACROS.h` |
| Branch args (`ZBRAN`/`BRAN`/`XLOOP`/`XPLOOP`) | 32-bit **relative** offset, `ADDS i,i,x` | `SLIB.s` ~915 |
| `LIT`/`RLIT` arg | 32-bit inline, fetched by `LDM i!,{t}` | `SLIB.s` 705–725 |
| Header link (LFA) | 32-bit absolute NFA pointer | `Forth_GNU.S` (217 NFAs) |

> **Correction to the earlier draft:** the earlier version of this doc said
> that `MACROS.h` already has 16-bit link fields and that 16-bit threading
> means "relative short link hopping." Both claims were wrong. All
> cells are 32-bit today. Branches are *already* relative. Also, a 16-bit
> **absolute** token is enough to reach every CFA in flash, because flash
> ends at `0x3FFF` (14 bits). Relative token hopping isn't needed (§4.1).

## 2. Measured Opportunity

These numbers come from scanning `build/gcc/fish.elf` with `fish.sym`. A
cell counts as a CFA when it holds `.+5` or a `DO*` code address.

| Item | Count | Bytes now | Bytes @16-bit | Saved |
|---|---:|---:|---:|---:|
| CFAs (104 prim, 153 DOCOL, 35 DOCON, 3 DOVAR, 2 CDG) | 297 | — | — | — |
| **Thread cells referencing a CFA** | **1,607** | 6,428 | 3,214 | **3,214** |
| Branch offsets (max \|off\| = 3,168) | 126 | 504 | 252 | 252 |
| `LIT` args (16-bit / `LITR` / `LIT32`, §4.8) | 123 | 492 | 252 | ~240 |
| `STRVA` args (`STRVR`/`STRVA`, §4.8) | 36 | 288 | 220 | ~68 |
| LFA links (header alignment absorbs part) | 217 | 868 | 434 | 0 – 434 |
| **Gross saving** | | | | **≈ 3.6 – 4.1 KB** |

Highest CFA = `0x3A38`, so every kernel token fits in 14 bits. If 10 of
the 16 flash pages are reserved for the kernel, the change frees about
**4 KB, roughly 25% of flash**. That space could hold `FLASH_SAVE` user
pages or more word sets. Today only 1 page (`0x3C00`) is left for users.

## 3. Benefits

1. **Flash capacity.** Thread bodies make up about 42% of the image. Halving
   them frees about 3–4 pages for saved user dictionaries, compared with 1
   page today.
2. **Smaller user words in RAM.** Words compiled interactively (before
   `FLASH_SAVE`) take half the RAM per token, which matters with a 4 KB RAM part.
   `DICTSPACE` effectively doubles for colon definitions.
3. **The linker checks range.** `.hword SYM` emits `R_ARM_ABS16`. If a
   kernel CFA ever moved above `0xFFFF`, the link would fail instead of
   producing a corrupt image.
4. **No branch-range change.** Branch offsets are already relative, and the
   largest is 3,168. They fit in signed 16 bits with lots of margin.
5. **`FLASH_SAVE` gets simpler.** Relocating 16-bit tokens is a narrower
   test than the current "any cell > `DBASE`" heuristic (FLASH.md §4). Data
   constants above 16 bits can no longer be mistaken for RAM addresses.

## 4. Costs and Risks

### 4.1 Token encoding and RAM words (the central decision)
Kernel CFAs are all below `0x4000`, but words compiled interactively live in
RAM at `0x1000_0000–0x1000_0FFF`. The token format has to cover both:

| Option | Token | NEXT decode | Notes |
|---|---|---|---|
| **A. Flash-only exec** | raw addr | none | RAM words can't run until `FLASH_SAVE`. This breaks interactive Forth, so it's rejected. |
| **B. Bank bit** | `0x4000 + (addr & 0xFFF)` for RAM | Branch-free: `LSRS x,w,#14; LSLS x,x,#28; ADDS w,x; LSRS x,x,#14; SUBS w,x` (+5 instr) | Self-contained. Costs the most cycles. |
| **C. Bias register** | same as B | `CMP w,limit; BLO 1f; ADD w,k; 1:` (+3 instr) | Uses `k` (r12) as the RAM bias. Needs a check against `ISR_REGISTER_AUDIT.md` §4 (the r10–r12 contract). |
| **D. Relative (i-relative)** | `target − i` | `ADDS w,w,i` (+1 instr) | Cheapest decode. `FLASH_SAVE` would have to re-encode every token whenever code moves, and `'`/`EXEC` would have to convert. High complexity. |

**Recommendation:** start with **C**. Prototype **B** if `k` turns out not
to be free for the VM.

### 4.2 NEXT size and speed
- Today `NEXT` takes 6 B and about 6 cycles (M0+: LDM 1 reg = 2, BLX = 3).
- The 16-bit version is `LDRH w,[i]; ADDS i,#2` plus the decode, which is
  about 8 B to 16 B. **Because NEXT is inlined 61×, each added 2-byte
  instruction costs 122 B.** Option C adds about 5 instructions: 61 × 10 B ≈ 610 B.
- Mitigation: keep a short inline `NEXT` only in the hot primitives (`LIT`,
  `ZBRAN`, `@`, `!`, `+`, `DUP`). Everywhere else, replace it with `B NEXT_SHARED` (2 B, ±2 KB).
  That means placing 2–3 copies of the shared NEXT across the image. Expected
  net growth is about 150–250 B.
- Expect threaded code to run roughly **15–30% slower**, depending on how much
  the hot path uses RAM words.

**Net saving after VM growth: about 3.2–3.8 KB.**

### 4.3 Alignment hazards (M0+ has no unaligned access)
- `LIT` with a 32-bit inline arg after a 2-byte token may be misaligned, and
  `LDM i!,{t}` would hard-fault. Fix: add `LIT16` (sign-extended `LDRSH`, which
  covers 109/123 sites). `LIT32` reads its argument as **two halfwords**
  (`LDRH lo; LDRH hi; LSLS hi,#16; ORRS`). That takes 3 extra instructions in one
  primitive, and in exchange no padding is needed anywhere in a thread. This
  replaces the earlier pad-token idea, so the compiler never has to insert alignment fill.
- Keep **code fields 32-bit and 4-aligned**. `NEXT1` (`LDM w!,{x}`), `DOCOL`
  (`MOV i,w`, w = cfa+4), `DOCON`/`DOVAR` (`LDM w!,{t}`) and
  `CREATE_DOES_GOTO` (`LDR i,[w]`) then stay unchanged. Every `.balign 4, 255`
  before a CFA stays too (README note).
- `PDOTQ` ends with `ALIGNED` and needs a 2-byte `HALIGNED`. Audit the same
  thing in every word that moves `i` past inline data (`STRVA`, `PDOTQ`,
  `ABORT"`-style words).
- Mixed hi/lo-level words (`.word .+5` + `LDR i,=label` in `NOOP`/`BLANK`)
  are unaffected, because the resume label is a full address loaded into `i`.

### 4.4 Tooling and compiler words
- Compiling words: `,` (COMMA) stays 32-bit for data. Add `H,` for tokens.
  `COMPILE`, `[COMPILE]`, `LITERAL`, `IF/ELSE/THEN/BEGIN/UNTIL/DO/LOOP`
  then switch to `H,` and step 2 bytes when back-patching.
- `RWORD` (`FLASH.s` 126) walks threads in 4-byte steps. It needs a 2-byte
  stride, the new token-decode rule, and `LIT16`/`LIT32`/pad skipping.
- Decompiler/`DUMP`-style tools: same stride change.
- Unaffected: `EXEC` (takes a full address from the stack), return-stack
  contents (32-bit `i`), and `I`/`J`.

### 4.5 Compiler words `:` and `;` (spec)

Under `TOKEN16`, every word created by `:` has a **32-bit code field
followed by a 16-bit token body**, ending with a 16-bit `SEMIS` token.

**How they work today** (`Forth_GNU.S` 3125–3170, `SLIB.s` 151/310/374):

```
:  = DOCOL  QEXEC SCSP CREATE ]  LIT -8 DP +!  COMPILE DOCOL  SEMIS
;  = DOCOL  ?CSP COMPILE SEMIS [  SEMIC_CREATE  SEMIS
INTERPRET (compiling) : ... CFA COMMA_PRIM ...       \ token append
COMPILE   = R> DUP 4+ >R @  COMMA_PRIM               \ 32-bit inline read+append
COMMA_PRIM= ALIGN32_FF_PAD HERE ! 4 ALLOT_PRIM
```

`COMPILE` (`COMP`) currently does two different jobs. It emits the
**code field** (`COMPILE DOCOL` in `:` and `COMPILE DOCON` in `CREATE`)
and it also emits **tokens** (`COMPILE SEMIS` in `;`, `COMPILE LIT` in
`LITERAL`). The 16-bit design has to split these:

| New / changed word | Behaviour under `TOKEN16` | Used by |
|---|---|---|
| `T,` (`TCOMMA_PRIM`) | `( cfa -- )` encode addr→token (§4.1: flash = raw, RAM = `0x4000+(a&0xFFF)`), `HALIGN` (pad to 2), `H!` at HERE, `2 ALLOT_PRIM` | INTERPRET, `COMP` |
| `COMP` (token) | `R> DUP 2+ >R H@ T,`. The inline operand in the kernel thread is now a 16-bit cell. | `;` (`SEMIS`), `LITERAL`, `DOTQ`, `DO`/`LOOP`/`IF`… |
| `COMPCF` (code field, new) | `R> DUP 2+ >R H@ ,`. Reads a 16-bit inline code address (`DOCOL`=0x685 fits) and emits a **32-bit, 4-aligned** cell through `COMMA_PRIM`. | `:` (`DOCOL`), `CREATE` (`DOCON`), `VAR` (`DOVAR`) |
| INTERPRET | `CFA COMMA_PRIM` → `CFA T,` | every compiled word |

**`:` under TOKEN16**
```
:  = DOCOL  QEXEC SCSP CREATE ]  LIT16 -8 DP +!  COMPCF DOCOL  SEMIS
```
- `CREATE` still lays down header, LFA, `DOCON` and pfa. The LFA goes through `,`,
  so it is padded to 4 with 0xFF just like the `.balign 4, 255` kernel headers.
  `-8 DP +!` still rewinds exactly the 32-bit `DOCON`+pfa pair, so the rewind
  amount doesn't change.
- `COMPCF DOCOL` writes a 4-aligned 32-bit code field. `NEXT1` (`LDM w!,{x}`)
  and `DOCOL` (`MOV i,w`, w = cfa+4) work as they do now, and the body
  starts at cfa+4, which is the first **16-bit token**.

**`;` under TOKEN16**
```
;  = DOCOL  ?CSP COMP SEMIS [  SEMIC_CREATE  SEMIS
```
- `COMP SEMIS` now appends a **2-byte** `SEMIS` token. After `;`, HERE can be
  2-aligned. That's harmless because the next `CREATE`/`,` pads to 4 before
  any 32-bit cell.
- `SEMIC_CREATE` (clears `CSDP`) doesn't change. On a compile error,
  `ERROR` rewinds `DP` to `CSDP` as before. `CSDP` is a byte address, so
  the width doesn't matter.

**Companion words that must change with `;`** (otherwise a `:` word would
compile mixed widths):
- `LITERAL`: if `n` fits in **signed** 16 bits (−32768..32767) → `COMP LIT16 H,`;
  otherwise `COMP LIT32 H, H,` (lo then hi). See §4.7. `DLITERAL` calls
  `LITERAL` twice and needs no change.
- Branch compilers `IF ELSE THEN BEGIN UNTIL AGAIN WHILE REPEAT DO LOOP +LOOP`
  and `BACK` change `,`/`!` → `H,`/`H!` for offsets. Forward-patch
  placeholders become 2 bytes. Offsets keep their current meaning
  (relative to the offset cell). The largest kernel offset is 3,168, well
  within signed 16 bits.
- `DOTQ`/`PDOTQ`: the string after the token ends with `HALIGNED`
  (2-byte) instead of `ALIGNED`.
- `<BUILDS`/`DOES>`: see §4.6.
- `RECURSE` and calls to earlier RAM words go through `T,`, so they get the
  RAM token encoding automatically.

**Acceptance tests (Phase 3)**
```forth
: T1 ;                    \ body = [DOCOL:32][SEMIS:16]   → 6 B (+2 pad before next hdr)
: T2 1 2 + . ;            \ LIT16 ×2, +, ., SEMIS        → 4 + 2+2+2+2+2+2+2 = 18 B
: T3 100000 . ;           \ LIT32 lo/hi                  → 4 + 2+4+2+2   = 14 B
: T4 5 0 DO I . LOOP ;    \ XDO/XLOOP 16-bit offset back-patch
: T5 T2 T4 ;              \ RAM tokens 0x4xxx resolve via §4.1 decode
: ARR <BUILDS 4 * ALLOT DOES> SWAP 4 * + ;   \ §4.6 defining word
10 ARR A1  : T6 1234567 3 A1 ! 3 A1 @ . ;   \ 32-bit data cell + LIT32 → 1234567
70000 CON BIG  -5 CON NEG  : T7 BIG . NEG . 65535 . 32767 . -32768 . ;
                          \ §4.7 → 70000 -5 65535 32767 -32768
T1 T2 T3 T4 T5 T6 T7  FLASH_SAVE  ( reset )  T5 T6 T7   \ survives RWORD 16-bit relocation
```
Check each body with `' Tn 20 DUMP`. After `DOCOL` there should be no 32-bit cell except
`LIT32` halves.

### 4.6 `<BUILDS` and `DOES>` (spec)

**How they work today** (`Forth_GNU.S` 2532–2582, `SLIB.s` 747, `FLASH.s` 136):

```
<BUILDS = DOCOL CREATE SEMIS               \ header, LFA, [DOCON][cfa+8]
DOES>   = DOCOL R> LATEST PFA DUP CFA      \ not IMMEDIATE (0x85): runs inside CCcc
          LIT CREATE_DOES_GOTO SWAP !      \ [cfa]   := CREATE_DOES_GOTO
          !  SEMIS                         \ [cfa+4] := does-thread addr (old i)
CREATE_DOES_GOTO: PUSHi2r; LDR i,[w]; ADDS w,#4; PUSHw; NEXT   \ w=cfa+4 → push cfa+8
```

Layout of a child word `nnnn` (made by `CCcc nnnn`):

| Offset | Before `DOES>` | After `DOES>` | Width under TOKEN16 |
|---|---|---|---|
| cfa | `DOCON` | `CREATE_DOES_GOTO` | **32-bit code field (unchanged)** |
| cfa+4 | `cfa+8` | full address of the does-thread | **32-bit full address (unchanged)** |
| cfa+8… | user data from `,` `C,` `ALLOT` | same | **32-bit data (unchanged)** |

Layout of the defining word `CCcc`:

```
[DOCOL:32] <BUILDS-tok ...build tokens... DOES>-tok  ...does-thread tokens...  SEMIS-tok
           \________________ all 16-bit tokens through INTERPRET T, ________________/
```

**What changes under TOKEN16:**
- `<BUILDS` doesn't change. It is `CREATE`, which uses `COMPCF DOCON` per §4.5.
- `DOES>` does **not change in behaviour**. Its kernel thread is converted like
  any other: `LIT CREATE_DOES_GOTO` becomes `LIT16` (0x6E7). `R>` still returns
  the full 32-bit `i`, which points at the first token after `DOES>`.
  `!` writes it as a 32-bit cell into the 4-aligned cfa+4.
- **The does-thread address may be only 2-aligned.** That's fine, because
  `CREATE_DOES_GOTO` loads it into `i` with `LDR i,[w]` (an aligned cell)
  and from then on `i` is only read with `LDRH`.
- The does-thread address is a **full address, not a token**. RAM (`0x1000xxxx`)
  and flash addresses both work without the §4.1 decode.
- `CREATE_DOES_GOTO` doesn't change (it already fakes DOCOL with `PUSHi2r`).
- The child's data area starts at cfa+8, which is 4-aligned. `,` stays a
  32-bit data comma there (see §4.7). **Only `T,` emits tokens. `,` never does.**

**`FLASH_SAVE` / `RWORD`:**
- The `CFA_CREATE_DOES_GOTO` case (`AT`/`TOFA`/`!` on cfa+4) stays 32-bit, and
  `TOFA` keeps the low offset bits, so a 2-aligned target survives.
- ⚠️ **Pre-existing issue (also present in today's 32-bit build):** `RWORD`
  runs `TOFA` on cfa+4 *unconditionally*. If `CCcc` already lives in flash
  (an earlier saved page) and the child `nnnn` is in RAM, the flash address
  gets remapped into the new page and the pointer is corrupted. Fix: guard
  it with `DUP DBASE >` the same way `RELOC_THIS_WORD` does. This should
  be fixed regardless of TOKEN16.

### 4.7 32-bit constants, numbers and data stay 32-bit

**Only thread tokens shrink.** Every value keeps its full 32-bit range:

| Construct | How it's stored under TOKEN16 | Range |
|---|---|---|
| `n CON X` / `CONSTANT` | `CREATE`, `-4 DP +!`, `,` → `[DOCON:32][n:32]`. `DOCON` uses `LDM w!,{t}` on the 4-aligned cfa+4 | full 32-bit, **unchanged** |
| `VAR X` / `VARIABLE` | `[DOVAR:32][addr:32]` → RAM cell via `VARALLOT` | full 32-bit, **unchanged** |
| `,` (COMMA) | `ALIGN32_FF_PAD`, 4-byte store | full 32-bit data, **unchanged** |
| `<BUILDS … , … DOES>` data | 32-bit cells from cfa+8 | **unchanged** |
| Number inside `:` (`LITERAL`) | `LIT16` + 2 B if −32768..32767, else `LIT32` + 4 B (two halfwords) | full 32-bit value |
| Double number `123.` (`DLITERAL`) | two `LITERAL`s | full 64-bit |
| `[ … ] LITERAL` | same as a number in `:` | full 32-bit |
| `' X` / `[']` | full address on the stack. Compiled as `LITERAL` (RAM addr → `LIT32`) | full 32-bit |

Rules the implementation must follow:
1. `LIT16` **sign-extends** (`LDRSH`). `LITERAL` must therefore use the *signed* range
   test. `65535`, `0x8000` and `0xFFFF` go through `LIT32`, otherwise they would come back
   as `-1`/`-32768` (test T7). An unsigned `LIT16U` (`LDRH`) is optional and could
   handle small masks and register offsets.
2. `LIT32` reassembles `lo | hi<<16` from two `LDRH`s, so the value doesn't need
   any alignment (§4.3).
3. Data never passes through `T,`, and tokens never pass through `,`. Code fields (`COMPCF`),
   `CON`/`VAR` bodies, LFAs and `DOES>` targets stay 32-bit and 4-aligned.
4. **`RWORD` must skip every inline argument explicitly.** Today branch offsets
   aren't skipped, which is safe only because they're never greater than
   `DBASE`. Under TOKEN16, a `LIT16 16384` (0x4000), a branch offset, or a
   `LIT32` half could look like a RAM token (`0x4000–0x4FFF`) and get
   "relocated". The walker needs to skip: `LIT16` (+2), `LIT32` (+4),
   `ZBRAN`/`BRAN`/`XLOOP`/`XPLOOP` (+2), `STRVA` (+4), `PDOTQ` (string, `HALIGNED`).
5. Pre-existing behaviour: `LIT` values are never relocated. `RLIT` exists in
   `SLIB.s` but nothing compiles it. A RAM address compiled as a literal
   (`[ ' X ] LITERAL`) isn't fixed by `FLASH_SAVE` today, and that doesn't change.
   Ordinary references to RAM words are tokens and *are* relocated.

## 4.8 Using 16-bit Numbers and Constants

In short: **FISH under TOKEN16 is a 16-bit-threaded, 32-bit-cell Forth.**
16 bits appear only *inside threads* (tokens and compact inline arguments).
Every value a program can see (on the stacks, in `CON`/`VAR`, through `,`/`@`/`!`)
is 32-bit.

### 4.8.1 Outer interpreter: numbers stay 32-bit

- **Interpret state** (`STATE`=0): `INTERPRET` → `NUMBER` → `PNUMBER`
  (`SLIB.s` 237) builds a **64-bit double** with `U*`/`D+`, then pushes one 32-bit
  cell (or two for a `.` double). Nothing is narrowed. `70000 .` prints
  `70000`, and `0x4004800C @` reads the full peripheral address. **No change under TOKEN16.**
- **Compile state** (`STATE`≠0): the same 32-bit value goes to `LITERAL`/`DLITERAL`.
  This is the **only** place where a 16-bit encoding is chosen, and it is
  chosen automatically. The user never writes anything different, and the value
  read back at run time always equals the value that was typed.
- `NUMBER` errors, `BASE`, `DPL` and the `.`-double rule don't change.

### 4.8.2 Stacks stay 32-bit

| Stack | Size today | Under TOKEN16 |
|---|---|---|
| Parameter (`p`=r7) | `STACKSIZE` = 32 cells × 4 B | **unchanged**, `SUBS/ADDS #4` macros (`MACROS.h`) |
| Return (`r`=r6) | 32 cells × 4 B | **unchanged**. Holds the full 32-bit `i` (threads run from flash *and* RAM `0x1000xxxx`), `DO` limit/index (often addresses, e.g. `TIB+LEN`), and `>R` values. |

**A 16-bit stack/cell was considered and rejected:**
- The most RAM it could save is 128 B (2 × 32 × 2 B), which is less than the
  flash cost of the extra address-handling code.
- Addresses don't fit in 16 bits. RAM is at `0x1000_0xxx`, peripherals at
  `0x4000_xxxx`, GPIO at `0xA000_xxxx`, SysTick/NVIC at `0xE000_xxxx`. The
  kernel's 36 `STRVA` stores alone hit 16 different peripheral registers.
  Every `@`/`!` would need a bank decode.
- The CPU registers are 32-bit, so there is no speed gain. `U*`, `D+`,
  `PNUMBER` and the IAP command and result blocks (`FLASHCMD`/`FLASHRET`) are all
  defined in 32-bit units.

### 4.8.3 Measured usage in the current image

| Kind | Count | Fits signed 16 | RAM addr | Peripheral / other 32-bit |
|---|---:|---:|---:|---:|
| `LIT` inline values | 123 | 109 (1 is 0..4, four are −1) | 11 | 3 (`0x40064020`, `0x4004800C`, `0x11111111`) |
| `STRVA val addr` (2 args) | 36 | values: 31 | addrs: 19 | addrs: 17 periph |
| `DOCON` constant bodies | 35 | 8 | 25 | 2 |
| Tokens `ZERO`…`FOUR` (already used instead of `LIT`) | 63 | — | — | — |

### 4.8.4 Inline number encodings (inside threads)

| Encoding | Bytes (token+arg) | When `LITERAL` picks it (in this order) | Run time |
|---|---:|---|---|
| `ZERO`…`FOUR` token | 2 | n = 0..4 (optionally add `TRUE` for −1) | existing `DOCON` |
| `LIT16` | 4 | −32768 ≤ n ≤ 32767 | `LDRSH t,[i]; ADDS i,#2` |
| `LITR` (new) | 4 | `0x1000_0000` ≤ n < `0x1000_1000` (RAM address) | `LDRH t,[i]; ADDS i,#2; ADD t,RAM_START` |
| `LIT32` | 6 | anything else | 2×`LDRH`, `LSLS #16`, `ORRS` |

Today every literal costs 8 B (token + 32-bit argument).

**Assembler note (kernel source):** RAM variables such as `PAD`, `TIB`,
`CSDP` and `FLASHRET` are **relocatable `.bss` labels** (`fish.sym` type `b`).
That means `.hword PAD & 0xFFFF` / `PAD >> 16` will **not assemble**, so a
`LIT32` can't be split from a relocatable RAM label. `.hword PAD - RAM_START`
**does** work. It emits `R_ARM_ABS16` with an addend, and the linker checks that
the result fits. This is the main reason to have `LITR`. `LIT32` halves only
ever hold absolute `.equ` values or plain numbers, which the assembler can
split. Suggested macros for Phase 2:

```
.macro L16  n ;  .hword LIT16, \n                        ; .endm
.macro LR   a ;  .hword LITR,  (\a - RAM_START)          ; .endm
.macro L32  n ;  .hword LIT32, (\n) & 0xFFFF, (\n) >> 16 ; .endm   // absolute only
```

**`STRVA` (kernel-only, `:NONAME`).** Today it reads two 32-bit inline cells
with `LDM i!`, which would misalign under TOKEN16. Proposal:
- `STRVR val16 ramoff16`: 4 B of arguments. Covers 17 sites.
- `STRVA val32 addr32` using halfwords: 8 B. Covers the other 19 sites.

That cuts the arguments from 288 B to 220 B. A third variant with a 16-bit value and
a 32-bit address would save about 30 B more, which probably isn't worth another primitive.

**Savings beyond the token count in §2:** `LIT` arguments 492 → 252 B
(**≈240 B**), and `STRVA` arguments 288 → 220 B (**≈68 B**).

### 4.8.5 Constants: `CON` vs inline literal

`CON` bodies stay `[DOCON:32][n:32]`, because `DOCON` uses `LDM w!,{t}`. Every
*use* of a constant becomes a **2-byte token**. That changes the usual
trade-off between a constant and an inline number:

| Value kind | Inline literal per use | `CON` per use | One-off cost of the `CON` | Break-even (uses) |
|---|---:|---:|---:|---:|
| fits signed 16 | 4 B | 2 B | ~20 B (4-char name: 5 B name+pad 8, LFA 4, CF 4, value 4) | ~10 |
| RAM address | 4 B (`LITR`) | 2 B | ~20 B | ~10 |
| 32-bit (periph/mask) | 6 B | 2 B | ~20 B | **~5** |
| kernel `:NONAME` constant (no header) | — | 2 B | 8 B | 2–4 |

Guidance:
- Peripheral addresses and masks used more than about 4 times should be
  `CON`s (or `:NONAME DOCON` in the kernel, like `U0RBRTHR`).
- Small numbers should stay inline. `LITERAL` already maps 0..4 to tokens.
- **No `CON16` / `DOCON16`.** A 16-bit body saves 2 B, but the next header's
  LFA is padded back to 4, so the average gain is about 0. It's not worth a code field type.

### 4.8.6 16-bit memory access words

The compiler needs these internally (§4.5). They're worth exposing for 16-bit data tables:

| Word | Stack | Notes |
|---|---|---|
| `H@` | `( addr -- u16 )` | `LDRH`, zero-extended into a 32-bit cell. `addr` must be 2-aligned (M0+ faults otherwise). |
| `H!` | `( n addr -- )` | `STRH`. **Silently drops the upper 16 bits.** Document this as a caution, like `C!`. |
| `H,` | `( n -- )` | `HALIGN`, `H!` at HERE, `2 ALLOT`. Data only. Use `T,` for tokens. |
| `HS@` (optional) | `( addr -- n )` | `LDRSH`, sign-extended. Use it for signed 16-bit tables. |

A table built with `<BUILDS … H, … DOES> SWAP 2* + H@ ;` takes half the space of
its `,` version, and the values on the stack are still normal 32-bit cells.

### 4.8.7 Rules summary

1. Cells, stacks, `@ ! ,`, `CON`, `VAR` and `NUMBER` are always 32-bit.
2. 16-bit appears only as thread tokens, `LIT16`/`LITR` arguments, branch
   offsets, `STRVR` arguments, and explicit `H@ H! H,` data.
3. The literal encoding is chosen only by `LITERAL`, in this order: 0..4 token →
   signed16 → RAM range → `LIT32`. Round-trip is exact (test T7).
4. `RWORD` skips every inline argument by its size (§4.7 rule 4). `LITR`, like `LIT`,
   is **not** relocated, because RAM variables don't move on `FLASH_SAVE`.

## 5. Implementation Plan

| Phase | Work | Exit check |
|---|---|---|
| 0 | Add `T` macro (`.macro T a; .hword \a; .endm`) and a `TOKEN16` config define in `FISH_RM_CONFIG_#DEFINES.h`, defaulting to off. Split the mixed lines (`.word DOCOL, LIT, 0x07, EMIT, SEMIS`) into a code field plus tokens. | Byte-identical image with `TOKEN16` off. |
| 1 | VM: `NEXT`/`NEXT_SHARED` with option-C decode; `LIT16` (signed), `LITR` (RAM offset), `LIT32` (two halfwords); `STRVR`/`STRVA` (halfword args); 16-bit `ZBRAN`/`BRAN`/`XLOOP`/`XPLOOP` arg fetch (`LDRSH`, `ADDS i,#2`); `H@`/`H!`/`H,`. | Kernel boots, signon and `WORDS` work. |
| 2 | Convert thread bodies in `SLIB.s` → `Forth_GNU.S` → `FLASH.s` → `COLD.s`/`SOC_INIT.s`/`UART0_INIT.s` (~1,750 `.word` lines; script the conversion, then review by hand). | `make size` reports the saving, and all linker ASSERTs pass. |
| 3 | Compiler words per §4.5–4.7: `T,`/`H,`/`H!`/`H@`/`HALIGN(ED)`, split `COMP`→`COMP`+`COMPCF` (`:`, `CREATE`, `VAR`), `;` (`COMP SEMIS`, 16-bit), INTERPRET `T,`, signed `LITERAL` 16/32, branch back-patching, `DOTQ`/`PDOTQ`. `<BUILDS`/`DOES>` need no logic change. | §4.5 acceptance tests T1–T7 pass from RAM. |
| 4 | `RWORD`/`TOFA`: 2-byte stride, skip all inline args (§4.7 rule 4), guard the `CREATE_DOES_GOTO` relocation with `DBASE >` (§4.6). | `FLASH_SAVE` → reset → `FLASH_SCAN` runs T5–T7 (bench, see `BENCH_CHECKLIST.md`). |
| 5 | Optional: 16-bit LFA, if header padding allows real savings. | Measured gain > 0. |

Fallback: `TOKEN16` stays a build switch, so the 32-bit image remains
available for faster but larger builds.

## 6. Open Questions

- Is `k` (r12) free in the VM, and how does it interact with the ISR save
  set in `ISR_REGISTER_AUDIT.md` §4?
- Should the RAM dictionary space be bounded below 4 KB so the token range
  stays at `0x4000–0x4FFF`?
- Is a 15–30% slowdown in threaded code acceptable for the target apps?
  UART at 9600 bps is not the bottleneck.

## 7. Conclusion

16-bit tokens are a strong fit for the LPC812. Every flash CFA fits in 14 bits,
branches are already relative, and thread cells take up about 6.4 KB of a 15.3 KB
image. After VM growth, the expected net saving is about **3.2–3.8 KB, or 3–4 flash pages**.
The two pieces that need real design work are executing **RAM-resident words** (§4.1)
and **inline-literal alignment** (§4.3). Everything else is a mechanical conversion
behind a build switch.
