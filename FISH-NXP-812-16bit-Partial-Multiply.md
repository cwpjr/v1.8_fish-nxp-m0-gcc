# FISH-NXP-812 — `U*` from 16-bit partial products (and inline `U/`, direct `*`)

Target: LPC812, Cortex-M0+, 24 MHz. Status: **proposal, no code changed.**
This is independent of the 16-bit threading proposal
(`FISH-NXP-812-16bit-Threading.md`) and can ship before it, after it, or without it.

---

## 1. Summary

Keep FISH's **32-bit cells**. Inside the `U*` primitive, split each operand
into 16-bit halves. Each 16×16 product fits exactly in a 32-bit register,
which is the "16-bit with 32-bit intermediates" idea applied where it pays off.
Four `MULS` instructions plus carry handling replace the C shift-add loop.
Also do two related cleanups: move the `U/` loop into the primitive, and
make `*` a single `MULS`.

| | Today | Proposed |
|---|---|---|
| `U*` 32×32→64 | `BL` C loop, 1 round per multiplier bit (up to 32), IRQs off | 4 `MULS`, no loop, no C, IRQs untouched |
| `*` | `M* DROP` → `ABS`/`XOR`/`U*`/`DPM` (hi-level) | `MULS` (one instruction) |
| `U/` 64÷32 | `BL` C loop, 32 rounds, IRQs off | same loop inline, no C, IRQs untouched |
| Net size | — | **≈ −20 B** |

## 2. Why not 16-bit cells instead

With 16-bit cells, doubles become 32-bit, so `U*` would be one `MULS` and `D+`
one `ADDS`. That saves roughly 200 B of double-precision code. But every
address becomes a double: RAM `0x1000xxxx`, peripherals `0x4004xxxx`,
GPIO `0xA000xxxx`, NVIC/SysTick `0xE000xxxx`. That includes all 36 kernel
`STRVA` stores, 25 RAM `DOCON`s, every `@`/`!`, the baud maths from 24 MHz,
and the IAP blocks. **Rejected.** This proposal gets the arithmetic
benefit without changing the cell size.

## 3. Current Implementation (measured)

| Word | Where | Size | Path |
|---|---|---:|---|
| `USTAR` (`:NONAME`, internal `U*`) | `SLIB.s` 1179 | 44 B | `BL C_CMSIS_DISABLE_IRQS; BL c_32by32to64mul; BL C_CMSIS_ENABLE_IRQS` |
| `c_32by32to64mul` | `main.c` 64 | 32 B | naked asm shift-add, loops **until the multiplier (TOS) is 0** |
| `USLASH` (internal `U/`) | `SLIB.s` 1204 | 46 B | same IRQ-off / `BL` wrapper around `c_64by32div` |
| `c_64by32div` | `main.c` 31 | 40 B | naked asm restoring division, 32 rounds, `push {r4,r5}` |
| `*` (`STAR`) | `Forth_GNU.S` 3560 | 16 B | `DOCOL M* DROP SEMIS` |
| `M*` | `Forth_GNU.S` 3508 | 44 B | `2DUP XOR >R ABS SWAP ABS U* R> D+-` |

Callers:
- `U*` is used by `PNUMBER` (×2, multiplier = `BASE`) and `M*`, so also by `*`.
- `U/` is used by `MSMOD` (×2, for number output via `#`) and `M/`, so also by `/`, `MOD` and `/MOD`.

### 3.1 Problems today
1. **Interrupt latency.** For a full 32-bit multiplier, `U*` keeps IRQs off for
   about 330 cycles (≈14 µs @ 24 MHz). `U/` keeps them off for about 300+ cycles on every call.
2. **Nest-safety.** `C_CMSIS_ENABLE_IRQS` enables unconditionally
   (`main.md` §2.1, `FISH_NXP_M0_FLASH.md` §3.2). If `U*`/`U/` runs inside an
   IRQ-off window, interrupts come back on early. `FLASHWRITE` had to be restructured because of this.
3. **`*` is slow.** A single-cell `*` runs a hi-level `M*` (sign handling, `ABS`×2,
   `XOR`, `>R`/`R>`, `D+-`) plus the C loop, to produce a result that one
   `MULS` gives directly.
4. The interrupt disable isn't actually needed. Its comment says "IRQ's and c
   routines share cstack", but the helpers only do balanced `push`/`pop` on MSP,
   and exception entry stacks below them. The proposed code doesn't touch `sp` at all.

**Correction to my earlier estimate:** the multiply loop stops early when the
multiplier runs out of set bits. `PNUMBER` passes `BASE` (10 → 4 rounds), so
number parsing only speeds up about 2×, not 8×. The big gains are for full-width
multipliers (`M*`, `*`, baud and timer maths).

## 4. Proposed Code

Register map (`FISH_ARM_CORTEX_M_REGS.h`): t=r0, n=r1, w=r2, x=r3, y=r4, with
i/r/p (r5–r7) preserved. ARMv6-M `MULS` only works on low registers, and
`t n w x y` are exactly five, which is enough. The stock `DOCOL_ISR` saves r4–r7
(`COLD.s`), so using `y` inside a primitive with IRQs enabled is safe, as
`XLOOP` already does.

### 4.1 `USTAR` — `( u1 u2 -- ud=<LSW MSW> )`

```
a = ah:al (t)   b = bh:bl (n)
a*b = hh<<32 + (lh+hl)<<16 + ll      ll=al*bl lh=al*bh hl=ah*bl hh=ah*bh
```

```asm
.balign 4, 255
USTAR:
	.word	.+5
.section .text, "ax", %progbits
	POP2t                 // a
	POP2n                 // b
	LSRS	x, t, #16     // ah
	LSRS	y, n, #16     // bh
	UXTH	t, t          // al
	UXTH	n, n          // bl
	MOVS	w, t
	MULS	w, n, w       // w = ll = al*bl
	MULS	t, y, t       // t = lh = bh*al
	MULS	n, x, n       // n = hl = ah*bl
	MULS	y, x, y       // y = hh = ah*bh
	MOVS	x, #0         // (MOVS imm leaves C alone)
	ADDS	t, t, n       // mid = lh+hl, C = bit 32 of mid
	ADCS	x, x, x       // x = carry
	LSLS	x, x, #16
	ADDS	y, y, x       // hh += carry<<16
	LSLS	n, t, #16     // mid<<16
	LSRS	t, t, #16     // mid>>16
	ADDS	w, w, n       // LSW = ll + (mid<<16), C out
	ADCS	y, y, t       // MSW = hh + (mid>>16) + C
	MOV	t, y
	DPUSH                 // ( LSW MSW ), same output contract as today
```

19 core instructions (38 B). There's no carry-out of the MSW, because
`(2³²−1)² < 2⁶⁴`. No branches, so the timing doesn't depend on the data.

**Optional fast path** (+6 B): if `(a|b) >> 16 == 0`, then `MULS` gives the result
and MSW = 0. That saves about 12 cycles. It's not worth it unless profiling shows `U*` is hot.

### 4.2 `*` (`STAR`) — `( n1 n2 -- n3 )`

```asm
STAR:
	.word	.+5
.section .text, "ax", %progbits
	POP2t
	POP2n
	MULS	t, n, t
	TPUSH
```

The low 32 bits of a product are the same for signed and unsigned inputs
(two's complement). So this matches `M* DROP` bit for bit, including
overflow wrap. `M*`, `*/` and other double-result words keep using `U*`.

### 4.3 `USLASH` — `( uLSW uMSW u32 -- u32REM u32QUO )`, loop moved inline

This is the same algorithm as `c_64by32div`, which was verified bit for bit
against 50k random cases. It keeps the same contract: the caller ensures
divisor ≠ 0 (`DZERO` handles it), divisor < 2³¹, and dividend_hi < divisor.

```asm
	POP2t                 // divisor
	POP2x                 // dividend HI  -> becomes remainder
	POP2w                 // dividend LO
	CMP	t, #0
	BEQ	DZERO
	MOVS	n, #0         // quotient
	MOVS	y, #32
1:	LSLS	w, w, #1      // C = next dividend bit
	ADCS	x, x, x       // rem = rem<<1 | bit
	BCS	2f            // safety net (outside envelope)
	CMP	x, t
	BCC	3f
2:	SUBS	x, x, t
	LSLS	n, n, #1
	ADDS	n, n, #1
	B	4f
3:	LSLS	n, n, #1
4:	SUBS	y, y, #1
	BNE	1b
	MOV	w, x          // remainder
	MOV	t, n          // quotient
	DPUSH                 // ( rem quo ), same as today
```

Splitting into 16-bit halves doesn't help division, because the M0+ has no
divide instruction. The gain here is removing the `BL`s and the IRQ-off window.
It runs at the same speed as today.

## 5. Size and Speed

| Item | Today | Proposed | Δ |
|---|---:|---:|---:|
| `USTAR` + `c_32by32to64mul` | 44 + 32 | 66 + 0 | −10 B |
| `USLASH` + `c_64by32div` | 46 + 40 | 66 + 0 | −20 B |
| `STAR` | 16 | 24 | +8 B |
| **Total** | | | **≈ −22 B** |

`C_CMSIS_DISABLE/ENABLE_IRQS` stay, because the Forth words at `Forth_GNU.S`
4881/4897 still use them.

Cycle estimates at 24 MHz assume the single-cycle multiplier (§7). They
include primitive overhead (pops, `DPUSH`, `NEXT`).

| Operation | Today | Proposed | Gain |
|---|---:|---:|---:|
| `U*`, multiplier = `BASE` (PNUMBER) | ~70 | ~37 | ~2× |
| `U*`, full 32-bit multiplier | ~350 | ~37 | ~9× |
| `*` (hi-level `M*` + `U*`) | ~250–500 | ~15 | ~15–30× |
| `U/` (`#`, `.`, `/`, `MOD`) | ~330 | ~300 | ~1.1× |
| Worst-case IRQ-off time from math | ~14 µs | **0** | — |

## 6. Verification

1. **Host model.** Write a Python model of the §4.1 instruction sequence with
   32-bit wrap and carry flags, and compare it with `a*b` over 10⁶ random pairs
   plus edge cases: `0`, `1`, `0xFFFF`, `0x10000`, `0x7FFFFFFF`,
   `0x80000000`, `0xFFFFFFFF`, and pairs that make `lh+hl` carry (e.g.
   `0xFFFFFFFF²`). For `USLASH`, reuse the existing 50k-case harness.
2. **Build.** Compare `make size` and the symbol sizes with §5. All linker ASSERTs must pass.
3. **On target** (`USTAR`/`USLASH` are `:NONAME`, so test them through public words):
   ```forth
   12345 6789 * .              \ 83810205
   -7 3 * .                    \ -21
   65535 65535 M* D.           \ 4294836225
   65536 65536 M* D.           \ 4294967296   (mid-carry into MSW)
   -1 -1 M* D.                 \ 1
   -2147483648 -1 M* D.        \ 2147483648
   100000 100000 M* D.         \ 10000000000
   1000000 7 / . 1000000 7 MOD .   \ 142857 1
   HEX FFFFFFFF U. DECIMAL 123456789 .   \ number in/out round-trip
   ```
4. **Interrupts.** With SysTick running, a `BEGIN 65535 65535 M* 2DROP AGAIN`-style
   stress loop should show the SysTick counter (`STCTR`) advancing without jitter
   from math. Run `FLASH_SAVE` with an IAP error forced to check that
   `FLASHQERR` printing no longer re-enables IRQs early.

## 7. Open Questions

- **Multiplier speed.** I believe the LPC81x datasheet lists a single-cycle
  multiplier, but please confirm against your copy of the datasheet or user
  manual. If it's the 32-cycle iterative option, four `MULS` cost about 128
  cycles. That's still faster than the loop for wide multipliers but slower
  for `BASE`-sized ones. In that case, add the §4.1 fast path.
- Should `UM*`/`UM/MOD` be exposed under their DPANS94 names now that the
  primitives are self-contained? Today they are `:NONAME`.
- After this change, `main.c` would only contain the IRQ wrappers (and
  `main` under `USE_CMAIN`). Is it worth folding those into asm too?

## 8. Implementation Steps

| Step | Work | Exit check |
|---|---|---|
| 1 | Host model + edge-case test for §4.1 | ✅ Done: 1,000,121 cases (121 edge pairs + 10⁶ random), 0 mismatches. Max `hh + carry<<16` = `0xFFFF0001`, so `ADDS y,y,x` can't overflow. |
| 2 | Replace `USTAR` body. Delete `c_32by32to64mul` | §6 multiply tests on target |
| 3 | `STAR` → `MULS` primitive | `*` tests; `WORDS`/number output unchanged |
| 4 | Inline `USLASH` loop. Delete `c_64by32div` | division and number-output tests |
| 5 | Interrupt stress + forced IAP-error check | no IRQ-off windows from math |
