# FISH_M0_EQUATES.h — Code Review

Date: 2025-10-31
Scope: all clock/flash/RAM/stack `.equ` values (164 lines). The
**value layer** of the two-layer config (Makefile `ASM_DEFINES` selects;
this file assigns numbers — see `FISH_NXP_M0_MAIN_INCLUDES.md` §2).
Build context: stock = `NXP_M0_81x_IRC12_24MHZ` + `NXP_M0_016kFlash_1KWrite`
+ `NXP_M0_004kRam`.

---

## 1. Stock Resolution (verified end-to-end)

| Equate | Stock value | Cross-check |
|---|---|---|
| `SYSTEMCLOCK` | 24,000,000 | matches PLL ×2 of IRC12 in `SoCinit`; `SYSCLOCK` set from it ✓ |
| `FLASH_WR_SIZE` | `0x400` (1K) | LPC812 sector size ✓; drives `TOFA` mask & IAP copy length ✓ |
| `FLASH_SPAGE` | `0x3C00` (legacy 1K dict) | Makefile `FLASH_SPAGE_HEX` in sync ✓ fitcheck enforces ✓ |
| `FLASH_PPAGE` | `0x4000` | one-past-end of 16K ✓ never dereferenced (loop bound) ✓ |
| `RAM_START/END` | `0x10000000/0x10001000` | linker script `RAM` region identical ✓ |
| `PINIT/RINIT/BOTTOM_RSTACK` | `0xFF0/0xF70/0xEF0` | match COLD literal pool & MEMMAP layout ✓ |
| `STACKSIZE` | 128 B per FISH stack | PROJECT_MAP documents the C-stack 0xA0 rationale ✓ |
| `IAPCALL` | `0x1FFF1FF1` | correct LPC8xx IAP entry ✓ |
| `XON/XOFF_CHAR` | 17/19 | …and `0x11` is the pattern-fill low byte — the `FLOW_STATE` collision (MEMMAP §3.2) |
| `IOBUFSIZE/MAXWORDLEN` | 96/31 | `IN` byte-store safe (<256, SLIB §4); QUERY uses `IOBUFSIZE-2` ✓ |
| `ALL_UNINITRAM_*` | `0xD40..0xEEC` | `DBAUD/UBAUD` +8; free pool 420 B; aligns with linker `_estack` ASSERT ✓ |

## 2. Config Matrix Notes

- Clock variants: XRC10_50M / IRC12_48M / IRC12_12M / IRC12_24M — only one
  should be defined; nothing guards against zero-or-two being defined
  (a `#if !defined(...)` fallback error directive would be a nice guard).
- Flash variants: 64K/4K-write, 32K/4K-write, 16K/1K-write — each carries
  its own `FLASH_SPAGE/PPAGE`; the 16K variant's `FISH_DICT_2K/3K/4K`
  selector is clean (`.equ` can't nest in `#ifndef` — the in-file comment
  about this is correct and worth keeping).
- **Sync contract**: Makefile `FLASH_SPAGE_HEX` must equal the resolved
  `FLASH_SPAGE`. fitcheck makes a mismatch a *build failure*, so the
  contract is enforced ✓ (verified this session: header comment says to
  keep them in sync, and they are).

## 3. Findings

### 3.1 UM quotations are the spec — good
The UM10398 IAP RAM-usage block (§26.4.7-9) is quoted in place; the
"top 32 bytes" requirement is exactly the MEMMAP §3.3 param-stack overlap
contract. The stale IAR menu paths around it ("IAR PROJECT->LINKER->…")
no longer apply — GNU linker script carries those decisions now.

### 3.2 ⚠️ `DBAUD` comment: ".bss zeroing out one word past WARNING"
This flag says an old IAR `.bss` zeroing once clobbered `DBAUD`. In the GNU
build `.bss` is empty and `DBAUD` lives outside any zeroed region ✓ — the
warning is satisfied by construction, but the comment should say *why* it's
now safe (region is `%nobits` + outside `.bss`), else it reads as open risk.

### 3.3 Cosmetic
- Commented `BOTTOM_IAPSTACK`/`TOP_IAPSTACK` block: superseded by the
  linker `.stack` reservation (0xA0) — delete or mark superseded.
- "RECALCULATE IF ANY NEW _SV'S ADDED" — in the GNU flow this is automatic
  via the linker ASSERT; comment can be retired.

## 4. Action Items

- [ ] Add a one-line `#if` guard: exactly one clock config and one flash
      config must be defined (§2) — assembler `#error` is supported by cpp.
- [ ] Refresh the three stale comments (§3.2/§3.3).
- [ ] No numeric changes — every stock value cross-verified this session.

**Last file reviewed: `FISH_M0_EQUATES.h`** (prior:
`FISH_NXP_M0_812_UART0_INIT.s`).
