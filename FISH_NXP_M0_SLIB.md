# FISH_NXP_M0_SLIB.s — Code Review

Date: 2025-10-31
Scope: the static `:NONAME` library — 1,290 lines, placed FIRST of the code
includes so library CFAs pin to stable low addresses (verified: `DOCOL`
@ `0x684`). Contains the inner-interpreter primitives, outer interpreter,
compiler security words, branch/loop runtimes, number conversion, dictionary
search, BASE save/restore, SV init, and the C-math call sites.
Build context: stock defconfig (see `FISH_NXP_M0_Forth_GNU.md` §2).

---

## 1. What's Here (and who consumes it)

| Group | Words | Consumers |
|---|---|---|
| VM cores | `DOCOL` `SEMIS` `DOCON` `DOVAR` `LIT` `RLIT` `GOTO` `CREATE_DOES_GOTO` | every threaded word |
| Outer interp | `QUIT` `INTERPRET` `QUERY` `DFIND` `PFIND` `NUMBER`(kernel) | COLD→WARM→QUIT |
| Compiler | `COMP` `BACK` `QCOMP` `QEXEC` `QPAIR` `QCSP` `SCSP` `QSTACK` `SEMIC_CREATE` `CSDP_SV` | colon/compiler words in kernel |
| Branch/loop | `BRAN` `ZBRAN` `XDO` `XLOOP` `XPLOOP` | IF/DO/LOOP family |
| Math | `PM` `DPM` `USTAR` `USLASH` `MSMOD` `PNUMBER` `NUMBERSUFFIX` | kernel math & NUMBER |
| Misc | `PDOTQ` `DOTBASE` `DOTSBASE` `TRAVERSE` `TOGGLE` `TIB_CHAR_SCAN` `IF_EOL_SEND_XOFF` `BSOUT` `BELL` `SPSTO` `RPSTO` `DICTSPACE` `VARSPACE` `STRVA` `BASE_TO_R12` `BASE_FROM_R12` `SIGNON` `WARM` `FWARM`+`SV_INIT_VALUES` | kernel/FLASH.s |

## 2. 🐛 Confirmed Defect — `CREATE_DOES_GOTO` reads `t`, needs `w`

Mechanism (per author): FISH's compiled-DOCOL for `DOES>` words — `DOES`
writes `CREATE_DOES_GOTO` into the created word's cfa, giving DOCOL
semantics + PFA push without a threaded call. Sound design; one wrong
register in the GNU implementation.

Evidence: the definition exists only in the two GNU ports' SLIBs
(NXP M0 and STM32F407 — byte-identical code, both with w-based `NEXT1`);
the IAR-original SLIB is not in this repo, so the t-convention origin is
unverifiable here, but under *this* tree's `NEXT1` (`LDM w!, {x}; BLX x`)
no execution path (NEXT / EXEC / ssNEXT1 / DOCOL_ISR) ever loads the cfa
into `t`. The STM32F407 port carries the same flaw — `<BUILDS/DOES>` is
broken (or never exercised) on both GNU ports.

```asm
CREATE_DOES_GOTO:           // entered via NEXT1: LDM w!,{x}; BLX x
	PUSHi2r                 // OK (fudged DOCOL)
	LDR	i, [t, #4]      // ✗ t is TOS — garbage for this purpose
	ADDS	t, t, #8        // ✗ same
	PUSHt
	NEXT
```

`NEXT1` leaves **w = cfa+4** and never touches `t`. The DOES> layout (built by
`DOES` in the kernel) is `[cfa]=CREATE_DOES_GOTO, [cfa+4]=does-thread,
[cfa+8]=params…`, so the correct derivations are `goto = [w]` and
`real pfa = w+4`. This code reads `[t+4]`/`t+8` — user data → garbage IP.

Proposed fix (same size, uses the live convention):

```asm
	PUSHi2r
	LDR	i, [w]          // goto address = [cfa+4]
	ADDS	w, w, #4        // real PFA = cfa+8
	PUSHw
	NEXT
```

Bench test after fixing: `: CON2 <BUILDS , DOES> @ ;  42 CON2 FOO  FOO .`
→ expect `42`. (Note `RWORD` in FLASH.s already has the matching
`CREATE_DOES_GOTO` relocation case, so saved DOES> words would follow.)

## 3. Positional Coupling — `SV_INIT_VALUES` ↔ MEMMAP order

`FWARM` block-copies **14 words** from flash table `SV_INIT_VALUES` to
`END_RAMVARSPACE_SV_START` (= `NBASE`), relying on MEMMAP declaration order
`NBASE IN OUT CSTATE | INITSO INITRO INITTIB UP DP | CSDP FENCE CURRENT
PROMPT ERROR_HALT`. Verified correct against `FISH_NXP_M0_MEMMAP.s` and the
`fish.sym` addresses — **but the coupling is invisible**: reordering either
file silently corrupts the system. The `LDR w, =14` count is hand-maintained.

- ✅ Table contents checked: `DEFAULT_BASE, IN=1, OUT=0, CSTATE=0, PINIT,
  RINIT, TIB, RAMVARSPACE, ORIG, CSDP=0, FENCE=0, CURRENT=WC_FISH_PubRel_NFA,
  PROMPT=msg_MY_OK, ERROR_HALT=0` — all consistent with COLD/EQUATES.
- ⚠️ `FLOW_STATE` is **not** in the table → boots as `0x11` (= `XON_CHAR`)
  under the COLD pattern fill — the already-logged MEMMAP §3.2 item; this is
  where its fix lands (add a 15th word + bump the count — but the table ends
  at `ERROR_HALT`; `FLOW_STATE` lives before `STICKER`, outside the copied
  range, so it needs its own one-cell init in `FWARM`, not table extension).

## 4. Verified-Good

- **`PFIND`**: length pre-compare masks smudge/immediate bits (`0x3F`),
  per-char compare with `0x80` end-bit handling, `0xFF` pad skipping,
  4-align before LFA fetch, `0` LFA terminates. The length pre-check is what
  makes the end-bit shortcut sound — no false-match path found. Uses
  `rb (r11)`/`k (r12)`: consistent with the ISR contract (r12 HW-saved;
  stock ISR thread touches neither) — this file is exactly where the
  `ISR_REGISTER_AUDIT.md` §4 "ra/rb shuttle" contract applies if an ISR ever
  runs compiling/searching words.
- **Branch math**: `BRAN1` target = `i_at_offset_cell + offset`; `BACK`
  emits `target − HERE`; `ENDIF` emits `HERE − addr` — mutually consistent ✓.
- **`XLOOP`/`XPLOOP`/`LEAVE`**: shared `XLOO1`, index==limit pretest,
  limit=index LEAVE semantics, 8-byte r-stack cleanup ✓.
- **`INTERPRET` precedence**: `len-byte < STATE(0xC0)` split of
  compile-vs-execute, with immediate (`0xC0`+) executed while compiling ✓.
- **`QUIT`**: prompt gating (`STATE==0` ∧ `PROMPT≠0`), base echoed in
  decimal, DLE emitted pre-CR under `EOL_DLE` (matches the STDLED staging
  note in `FISH_NXP_M0_MAIN_INCLUDES.md` §2) ✓.
- **`PDOTQ`↔`DOTQ` agreement**: runtime `COUNT PLUS ALIGNED` skip matches
  compile-time `CAT ONEP ALIGNED ALLOT_PRIM` ✓.
- **`BASE_TO_R12`/`BASE_FROM_R12`**: confirm r12 = BASE register — explains
  the COLD.s exception dumps ("R12 = DICTSPACE_START…" was mid-PFIND/NUMBER
  state) and why the stock ISR needs no r12 handling (HW frame) ✓.
- **C-math ABI** (`main.c` naked routines): `USLASH` pops divisor→t(r0),
  MSW→x(r3), LSW→w(r2) — precisely AAPCS `(int, long long)` = r0 + r2:r3
  with r1 skipped for 8-byte alignment. Not an accident; undocumented here —
  one comment line would save the next reader. `USTAR` r0/r1 → r0:r1 ✓.
  Div-by-zero returns `-1 -1` (`DZERO`) per Forth tradition ✓; the
  "dividend_hi < divisor" U/ rule is comment-only but satisfied by
  construction at all call sites (DIG/MSMOD baud math) ✓.
- **`TIB_CHAR_SCAN`**: byte-store of IN is safe only because
  `IOBUFSIZE (96) < 256` — noted so a future bigger TIB upgrades it to STR.
- **`QSTACK`** checks underflow only (p above INITSO) — fig-standard; no
  depth check. Fine, documented here so nobody "fixes" the wrong half.

## 5. Cosmetic Sweep Candidates

`STRVA` comment ("GET FROM [w]" — reads via `i`), `NUMBERSUFFIX` stale
`// =0x20`, "In IAR branch target MUST BE ON Next LINE" (gas handles
`LABEL-.`), assorted typos (`Iinitial`, `converte`, `lentgth`, `striong`,
`MUSTE BE`, `traditoional`). Batch with the kernel §3.4 sweep.

## 6. Action Items

- [x] **Fix `CREATE_DOES_GOTO`** (§2) — DONE 2025-10-31, both GNU ports
      (`FISH_NXP_M0_SLIB.s`, `FISH_STM32F4_SLIB.s`): `w`-based
      (`LDR i,[w] / ADDS w,#4 / PUSHw`). Size-neutral; M0 fitcheck OK
      (88 B free), STM32F4 fitcheck OK. Disassembly-verified both.
      REMAINING: bench `DOES>` test on hardware:
      `: CON2 <BUILDS , DOES> @ ;  42 CON2 FOO  FOO .` → `42`,
      then `FORGET FOO`. Add to `BENCH_CHECKLIST.md`.
- [ ] Init `FLOW_STATE` (one cell) in `FWARM` — completes MEMMAP §3.2.
- [ ] Comment the AAPCS register mapping at the `USLASH`/`USTAR` call sites
      (§4, C-math bullet).
- [ ] Guard-comment the `SV_INIT_VALUES`/MEMMAP positional coupling + the
      hand-maintained 14 (§3).
- [ ] Cosmetic sweep (§5).

## 7. Build Impact

None yet (review only). The §2 fix is size-neutral (same instruction count);
§3.2's FWARM cell adds 4 B flash. Current image: 15,272 B / 88 B free.
**Last file reviewed: `FISH_NXP_M0_SLIB.s`** (prior: `FISH_NXP_M0_MEMMAP.s`
— align fix applied & verified).
