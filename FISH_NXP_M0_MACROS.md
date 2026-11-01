# FISH_NXP_M0_MACROS.h — Code Review

Date: 2025-10-31
Scope: all 28 `.macro` definitions — the VM's instruction set: inner
interpreter (`NEXT`/`NEXT1`), parameter-stack ops, return-stack ops, and
execution-stream fetches. 158 lines, zero parameters (all fixed-register).
Build context: stock defconfig (see `FISH_NXP_M0_Forth_GNU.md` §2).

---

## 1. Why this file matters

Every register convention the VM obeys is defined *here and nowhere else*.
The macros are the single point of ISA abstraction — "Beauty is you can put
any ISA in a macro and no prob till referenced!" (file header). Corollary:
any inconsistency here is invisible at call sites and breaks everything at
once. Usage census across `COLD.s` / `FLASH.s` / `Forth_GNU.S` / `SLIB.s`:

```
NEXT 61×   TPUSH 55×   POP2t 48×   POP2n 27×   POP2w 18×   DPUSH 16×
POP2x 5×   NEXT1 4×    POPp2w 4×   POPr2i 4×   PUSHi2r 3×  LIT2t 2× …
```

## 2. Inventory & Contracts

### 2.1 Inner interpreter
| Macro | Expansion | Clobbers | Notes |
|---|---|---|---|
| `NEXT` | `LDM i!, {w}` + `NEXT1` | i, w, x, **lr** | fetch cfa → w, then NEXT1 |
| `NEXT1` (stock) | `LDM w!, {x}; BLX x` | w, x, **lr** | w lands on cfa+4 (pfa) for DOCOL; BLX is why lr never survives a word |
| `NEXT1` (`ss` debug) | `LDR x,=ssNEXT1; BX x` | x | ssNEXT1 ends `MOV pc, x` — **no lr clobber**. Debug vs stock lr contract differs; only matters to code that assumed lr lives across NEXT (nothing does — ISR stacks EXC_RETURN regardless, see `ISR_REGISTER_AUDIT.md`) |

### 2.2 Parameter stack (`p` = r7), pre-decrement / post-increment
`PUSHt/n/w/x/i` · `POP2t/n/w/x/i` · `NDPOP2t/w/x` (peek, no bump) ·
`TPUSH` = PUSHt+NEXT · `DPUSH` = PUSHw+TPUSH.
Design note in header: M0 has only STMia/LDMia, so "push" is
`SUBS p,p,#4; STR` and "pop" is `LDR; ADDS p,p,#4` — chosen so `I` (and all
pop users) get post-increment semantics. Consistent everywhere ✓.

### 2.3 Return stack (`r` = r6), same convention
`PUSHt2r` `PUSHi2r` `PUSHn2r` `PUSHw2r` · `POPr2i` `POPr2t`.
`PUSHi2r`/`POPr2i` are the DOCOL/SEMIS mechanism (audited in
`ISR_REGISTER_AUDIT.md` §2).

### 2.4 Execution-stream fetches
`LIT2t` (`LDM i!,{t}` — LIT primitive), `POPp2w` (`LDM p!,{w}` — EXEC setup).
Comments ("as in xeq token at ToS setup…") are cryptic but the uses check out.

## 3. Findings

### 3.1 ⚠️ `TOSCT` is modeled in exactly ONE macro — root cause
`POP2t` (line 55) is the only macro with `#ifndef TOSCT`; every other macro
silently assumes **TOS lives in memory at `[p]` as well as in `t`**. That is
the real reason the word-level `TOSCT` blocks are inconsistent
(`FISH_NXP_M0_Forth_GNU.md` §3.2): the caching contract was never decided at
the abstraction layer where it belongs. If TOSCT is ever wanted, the
decision table is:

| Macro | non-TOSCT (current) | TOSCT would need |
|---|---|---|
| `POP2t` | `LDR t,[p]; ADDS p,#4` | `ADDS p,#4` ✓ (already) |
| `TPUSH`/`PUSHt` | `STR t,[p]` (memory mirror) | keep (DUP relies on it) or redefine DUP |
| `PUSHn/w/x` | unchanged | unchanged |
| `NDPOP2t` | `LDR t,[p]` | **no-op** (t already valid) |

Until someone owns that table, treat TOSCT as removed (action item already
logged in the kernel review).

### 3.2 ⚠️ Every PUSH/POP sets flags — contract: never consume flags across a stack macro
`SUBS/ADDS` are the only 16-bit M0 encodings, so flag clobbering is
unavoidable — but it means `POP2x; BEQ …` would branch on `p+4`, not on the
loaded value (LDR sets no flags). **Audited: zero live instances** (no
conditional branch directly follows any stack macro in the four .s/.S
files). Keep it that way; one line in the file header would freeze the rule.

### 3.3 Dead / vestigial
- `PUSHi`, `NDPOP2x` — 0 uses anywhere.
- `POP2p`/`POP2PC` — commented-out stubs (IAR-era), remove or label "idea".
- Comment typos: `PUSHi` "pore increment"; `PUSHn2r` says "push t to r"
  (pushes **n**).

### 3.4 Verified-good
- **Single-abstraction-point pays off**: the COLD/FLASH/kernel code contains
  almost no raw stack manipulation outside these macros; the ISR audit and
  the DOCOL/SEMIS balance proofs were possible because of it.
- **`NEXT1` w=cfa+4 invariant** is exactly what DOCOL needs (`MOV i, w`) —
  documented in both places, consistent.
- **No parametric macros** → no argument-substitution or
  register-allocation surprises at 250+ expansion sites.
- `LTORG` discipline: macro file emits no code/literals itself; every user
  handles its own `.ltorg` — no hidden pool-placement coupling.

## 4. Action Items

- [ ] Add header line: "Stack macros clobber flags (SUBS/ADDS). Never
      consume flags set before a PUSH/POP; set them after." (§3.2)
- [ ] Delete `PUSHi`, `NDPOP2x`, and the `POP2p`/`POP2PC` stubs (§3.3).
- [ ] Fix `PUSHn2r`/`PUSHi` comment typos (§3.3).
- [ ] If TOSCT is formally abandoned: strip the `#ifndef TOSCT` in `POP2t`
      too, closing §3.1 (paired with kernel review §3.2 action item).

## 5. Build Impact

No code change in this review — header-only analysis; current image
unchanged (15,272 B, 88 B free per `fish_check_fit`). The §4 cleanups are
comment/dead-code only and would not alter the image; the TOSCT strip
would not either (config off).
