# FISH_NXP_M0_Forth_GNU.S — Code Review

Date: 2025-10-31
Scope: main dictionary kernel — 217 NFA'd words (signon, UART I/O, number
conversion I/O, fig-style compiler, CREATE/DOES>, memory ops, WORDS/DUMP,
SysTick/DELAY, FISH_ONLY/FISH), 5,793 lines.
Build context: stock defconfig (`NXP_M0_812`, `FISH_PubRel_WORDSET`,
`NXP_M0_81x_IRC12_24MHZ`, `NXP_M0_016kFlash_1KWrite`, `NXP_M0_004kRam`,
`FISH_NO_TIMESTAMP`, `FISH_LEAN_WORDSET`).

---

## 0. Lineage: FISH = FIG-ISH Forth

fig-model heritage is intentional: `'`→pfa vs `EXEC`→cfa split, CSP
compiler security, CURRENT-only search, FENCE/FORGET, smudge(0x80)/
precedence(0x40) bits, TRAVERSE, underflow-only QSTACK, DPL, EXPECT/WORD
counted strings, ITC DOCOL/SEMIS. **All fig-inherited machinery reviewed
clean.** Every confirmed defect in this review series lives in a
FISH-specific addition: CREATE_DOES_GOTO (SLIB §2), the flash persistence
layer (FLASH.md §3.1/3.3), XON/XOFF dedup + FLOW_STATE placement
(MEMMAP §3.1/3.2), and the asm DNEGATE (§3.1 below — fig's high-level
DNEGATE propagated carry correctly via `1. D+`). Bench testing should
concentrate on the FISH-specific layers.

## 1. File Boundaries (what is NOT here)

| Lives elsewhere | Content |
|---|---|
| `FISH_NXP_M0_SLIB.s` | Inner interpreter (DOCOL/SEMIS/DOCON/DOVAR/CREATE_DOES_GOTO), NEXT macros users, INTERPRET/QUIT/QUERY, PFIND/DFIND/TRAVERSE, XDO/XLOOP/XPLOOP, COMP/BACK/QPAIR/QCSP/QEXEC, SPSTO/RPSTO, USTAR/USLASH/MSMOD/PM/DPM, DICTSPACE/VARSPACE, DICTFULL_ABORT, PDOTQ, DOTBASE/DOTSBASE, BASE_TO_R12/BASE_FROM_R12, WARM/SIGNON, SEMIC_CREATE/CSDP_SV, TIB_CHAR_SCAN, BSOUT/BELL, COMMA_PRIM/ALLOT_PRIM/TOGGLE, HLD_SV/INITSO_SV |
| `FISH_NXP_M0_COLD.s` | FM0_COLD/FM0_WARM, SysTick ISR (see `ISR_REGISTER_AUDIT.md`) |
| `FISH_NXP_M0_FLASH.s` | `#include`d mid-file between `WC_IRQ_NFA` and `POFF_NFA` — LFA chain dependency noted in comments (see `FISH_NXP_M0_FLASH.md`) |
| `*_UART0_INIT.s`, `*_SOC_INIT.s`, `FISH_RM_MSGS.h` | `#include`d at UART section and EOF |
| `main.c` | `C_CMSIS_ENABLE/DISABLE_IRQS`, naked 64/32 div + 32x32→64 mul helpers |

## 2. Stock Config Flags (verified in `FISH_RM_CONFIG_#DEFINES.h`)

```
#define   TRUE_EQU_NEG_ONE      ← true flags are -1 (EQUAL/ZEQU/ZLESS/QKEY…)
#define   XON_XOFF              ← live flow control, transition-deduped
#define   ABORT_STOP_TILL_CO    ← ABORT can halt until "CO<CR>" if ERROR_HALT set
#define   EOL_DLE / EOL_NAK     ← ACTIVE: staged for STDLED editor support
                                  (DLE 0x10 after QUIT line, NAK-wrapped error
                                  messages); harmless control chars on dumb
                                  terminals. See FISH_NXP_M0_MAIN_INCLUDES.md.
//#define IO2TP / TOSCT / IOBUFS_DEBUG / SRM   ← all OFF
```

## 3. Findings

### 3.1 🐛 REAL BUG — `DNEGATE` drops the carry when LSW == 0

```asm
POP2t              // MSW
POP2w              // LSW
MVNS t, t          // ~MSW
MVNS w, w          // ~LSW
ADDS w, w, #1      // ~LSW+1 → C=1 iff LSW==0
DPUSH              // carry never added to MSW ✗
```

`d = 0x00000001_00000000` (2³²) → should give `0xFFFFFFFF_00000000`;
yields `0xFFFFFFFE_00000000` (off by 2³²). Affects any negative double with
LSW==0 (e.g. `-4294967296.`), and `DABS`/`DPM` on such values.
`DPLUS` right above it shows the correct idiom (`ADDS`/`ADCS`).

Fix (+1 word, M0-legal — `MOVS` does not clobber C):

```asm
ADDS w, w, #1
MOVS x, #0
ADCS t, t, x       // MSW = ~MSW + carry
```

### 3.2 ⚠️ `TOSCT` (TOS-cache) config is inconsistent — do not enable

Off in stock, marked experimental by the author
("TOS Cache Testing QUERY BACKSPACING OVER INPUT!!!"). Confirmed broken spots:
- `DUP`: `LDR t, [p]` then `TPUSH` — correct only without TOSCT (memory top is
  TOS). Under TOSCT `[p]` is NOS → DUP would push NOS over TOS.
- `PSTORE`, `ROT`, `OVER`, `SWAP`, `DROP`, `TOR` each use *different* ad-hoc
  TOSCT sequences (`LDR t,[p]` before vs after the pop). Not audited as a set.
Recommend: either delete the `#ifdef TOSCT` blocks or complete them as one
consistent contract; until then treat the switch as removed.

### 3.3 ⚠️ Soft dictionary-overflow guards on the `,` path

`ALLOT`/`CCOMMA`/`CREATE` check `DICTSPACE` before allotting, but
`ALIGN32_FF_PAD` (invoked by every `,` via `COMMA_PRIM`) can write up to 3
`0xFF` pad bytes with no bounds check, and `COMMA`'s own test is only
`DICTSPACE 0<`. Worst case a `,` at the exact boundary overruns
`DICTSPACE_END` by up to 7 bytes. Harmless today (kernel leaves guard room
below `FLASH_SPAGE`, enforced by fitcheck) but worth a comment in
`FISH_M0_EQUATES.h` stating the required guard ≥ 8 bytes.

### 3.4 Cosmetic / documentation

- `TXRDY_SUBR`: comment `BCC txRDY_Q // Ready` is backwards (BCC = *not*
  ready, loops). The 812 shift comment "3 = TX BUF RDY" is off by one —
  `LSRS #3` tests bit **2** (TXRDY) which is correct; the 11xx comment has the
  same off-by-one flavor (`LSRS #6` tests bit 5 = THRE ✓). Code right,
  comments wrong.
- `TYPE`: header comment "ADDR must be ALIGNED!" is stale — the body is a
  byte-wise `I CAT EMIT` loop; any alignment works.
- `ABORT`: two consecutive `.word QUIT` (one before the
  `ABORT_STOP_TILL_CO` include, one after) — second is a dead cell.
- `NOOP`/`BLANK` use the "mixed asm hi level test" pattern (DOCOL →
  hand-linked `ASM_*` continuation labels, `LDR i, =ASM_EXIT_x` to resume).
  Works, but fragile and noisy for two words that could be
  `.word DOCON, 0x20`-style trivial (noted in-source for BLANK already).
- `WC_UARTx_NFA` carries an unresolved author note `!!!!!fixx in nxp` —
  the LFA chain is actually consistent (verified against FLASH.s link
  expectations); the note can go.
- `msg_FISH` "(C)2014-2026" — fine, but `FISH_NO_TIMESTAMP` means no build
  date on 16k parts; version provenance is only `fish-git.md`. Consider a
  `__DATE__` stub even in lean builds if bench confusion arises.

### 3.5 Verified-good patterns (worth keeping as templates)

- **Dictionary-full checks** on ALLOT/COMMA/CCOMMA/CREATE/VARALLOT with
  `DICTFULL_ABORT` / typed message + `ABORT`.
- **`ERROR` recovery via `CSDP_SV`**: on error mid-definition, `CURRENT` is
  relinked to the failed word's LFA and `DP` reset — damaged words can't
  wedge the dictionary.
- **XON/XOFF transition dedup** (`FLOW_STATE`): `EXEC`/`QKEY`/`TYPE`/
  `EXPECT` call sites stay belt-and-braces while emitting only on
  transitions. The embedded review comment in `XOFF_SUBR` documents the
  contract (call-site `TXRDY` requirement) — matches the `FSAVE` `XOFF` fix
  already applied (see `FISH_NXP_M0_FLASH.md`).
- **`NUMBER` BASE save/restore** via `BASE_TO_R12`/`BASE_FROM_R12` — uses
  `k (r12)`, which is exactly why the stock ISR needs no r12 handling
  (HW exception frame covers it; `ISR_REGISTER_AUDIT.md` §2).
- **`DELAY`**: saves user `SYST_CSR`, forces tick IRQ on, busy-waits on
  `STICKER`, restores. `MS` reload = 23999 @ 24 MHz → exact 1 ms ✓.
  Contract: never call between `IRQS_SUSPEND`/`IRQS_RESUME`.
- **`FORGET` flash-safety**: refuses targets `< FLASH_SPAGE`
  ("CANT FORGET FISH") and `< FLASH_PPAGE` ("IS FLASH SAVED"), and reclaims
  `UP` for each forgotten `DOVAR` word (FIG memory-leak fix).
- **`FISH_ONLY`/`BYE`** reset paths match the FLASH.s invariants
  (`WC_FISH_PubRel_NFA` ↔ `FPC`/`FPSV` ↔ `CURRENT`/`UP`/`DP`).
- **EXPECT**: full BS/DEL editing with `BELL` at buffer start, tab→space,
  CR handling via `LEAVE`, count byte via `NULLSTRLEN`.
- **`EXEC`** nests `TXRDY+XOFF` per execute — with dedup this is the cheap
  "downloads can't overrun the compiler" mechanism. Sound.

## 4. Interaction with In-flight Work

- `FLASH.s` include position is LFA-load-bearing (`WC_IRQ_NFA` above,
  `POFF`←`FLASH_FORGET_NFA` below). Any reorder must preserve both links.
- `WC_FISH_PubRel_NFA` is the dictionary head that `FISH_ONLY` and
  `FLASH_FORGET`'s RAM-word relink depend on — do not rename without
  updating both.
- The `TASK_NFA` block is commented out with guidance for multitasking
  (must move to RAM) — historical, leave as-is.

## 5. Action Items

- [x] **Fix `DNEGATE` carry** (§3.1) — DONE 2025-10-31: `MOVS x,#0 / ADCS t,t,x`
      added (+4 B; fitcheck OK, 88 B free). Disassembly-verified and
      edge-case emulated: LSW==0 cases (`d=0`, `d=2³²`, min-double) now
      correct; all other results unchanged.
- [ ] Neuter or complete `TOSCT` blocks (§3.2) — prevent accidental enable.
- [ ] Comment sweep per §3.4 (TXRDY/TYPE/ABORT/WC note).
- [ ] Note the ≥8-byte dictionary guard assumption where `DICTSPACE_END`
      is defined (§3.3).
- [ ] Bench-test `-4294967296. D.` / `1 0 DNEGATE` on hardware — add to
      `BENCH_CHECKLIST.md` (build-side verification already done).
