# startup_lpc812_gnu.S — Code Review

Date: 2025-10-31
Scope: GNU vector table + reset/default handlers (93 lines).
Build context: stock defconfig; image **not yet hardware-tested**
(statically verified only — no LPC812 emulator).

---

## 1. Structure

- `__vector_table` @ `0x00`: `_estack`, `Reset_Handler`, NMI, HardFault,
  MemManage/BusFault/UsageFault (slots 4–6 don't exist on ARMv6-M — harmless
  fill), **slot 7 = checksum** (see §2), SVC, DebugMon, PendSV,
  **SysTick → `FM0_SYSTICK_ISR`** ✓ (ties into `ISR_REGISTER_AUDIT.md`),
  then 32 × `Default_Handler` (LPC812 has exactly 32 peripheral IRQs;
  section size `0xC0` = 48 vectors ✓ matches objdump).
- `Reset_Handler`: classic `.data` copy / `.bss` zero loops (both empty in
  stock — `data=0 bss=0`, loops are no-ops), then `bx FM0_COLD` ✓
  (disassembly-verified: `bx 0x9F9`).
- `HardFault_Handler`: writes `0x05FA0004` to `AIRCR` = VECTKEY|SYSRESETREQ
  → **immediate chip reset**. This is the deliberate "hard fault = reset"
  policy the `MYBAUD` persistence mechanism is built around ✓.
- `Default_Handler`: `b .` spin. NMI/peripheral IRQs with no handler park
  here — defensible for this system (no peripheral IRQs are ever enabled
  in stock; SysTick is the only live one).

## 2. 🐛 FIXED — Missing LPC boot-ROM vector checksum (release blocker)

Slot 7 (`0x1C`) was `0`. NXP boot ROMs (LPC81x, UM10801) accept flash as
"valid user code" only if **the sum of the first 8 vectors is 0**; otherwise
the part enters UART ISP after reset — a dead-looking terminal. Never caught
because the IAR flow computed it via ielftool and this image was never
bench-booted.

Fix (link-time, no post-processing): startup stores
`.word __vector_checksum`; `lpc812_gnu.ld` computes:

```ld
__vector_checksum = 0 - (_estack + (Reset_Handler + 1) + (NMI_Handler + 1)
                       + (HardFault_Handler + 1) + (MemManage_Handler + 1)
                       + (BusFault_Handler + 1) + (UsageFault_Handler + 1));
```

The `+1` per handler is required: `ld` strips the Thumb bit from function
symbols in arithmetic, but the stored table words are odd (same idiom as
NXP's own managed linker scripts). First attempt without `+1`s produced
sum=6 — caught by verification below.

**Verified**: `sum(vectors[0..7]) & 0xFFFFFFFF == 0` on `build/gcc/fish.hex`
(`vector[7] = 0xEFFE8F96`); image size unchanged (fitcheck OK, 76 B free).

## 3. Findings

### 3.1 Notes (no action)
- `.data`/`.bss` loops retained per `PORTING_PLAN.md` §5 — FISH's RAM map is
  `%nobits` and `FM0_COLD` pattern-fills it; loops are zero-trip in stock.
  If C code ever adds real `.data`, both this handler AND the COLD fill
  order must be re-thought (COLD would overwrite initialized data) — one
  comment line here would save that future surprise.
- `Default_Handler` spin vs reset: NMI/peripheral faults park forever
  instead of resetting like HardFault. Deliberate debugging aid (PC visible
  in debugger); keep, documented.
- MemManage/BusFault/UsageFault handlers on an ARMv6-M table are inert;
  they only feed the checksum sum. Could be zeroed, but keeping them costs
  nothing and matches the NXP formula.

## 4. Action Items

- [x] Vector checksum via `__vector_checksum` (§2) — DONE, verified on hex.
- [ ] Add the `.data`-vs-COLD-fill contract comment (§3.1) when convenient.
- [ ] First bench boot: confirm the part runs flash (not ISP) — the
      checksum fix exists precisely to make this pass; see
      `BENCH_CHECKLIST.md` §C.

**Last file reviewed: `startup_lpc812_gnu.S`** (prior: `FISH_NXP_M0_SLIB.s`).
