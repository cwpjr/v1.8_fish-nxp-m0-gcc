# FISH_NXP_M0_FLASH.s — Review & Fix Log

Date: 2025-10-31
Scope: `FLASH_SAVE` / `FLASH_FORGET` / `FLASH_SCAN` and support words
Forth-level dictionary persistence via the NXP **IAP ROM API** (`0x1FFF1FF1`).

---

## 1. Architecture

| Piece | Role |
|---|---|
| `FLASH_SAVE` | If `LATEST ≥ DBASE` (words in RAM), relocates each word's RAM references to flash-relative (`RWORD`/`TOFA`), then copies the dictionary page to flash via IAP. |
| `RWORD` | Thread walker: skips `LIT` args, `PDOTQ` strings, `DOCON`/`DOVAR` bodies, `CREATE_DOES_GOTO` payloads; relocates any remaining cell `> DBASE`. |
| `TOFA` | `addr → flash addr`: `(addr & (FLASH_WR_SIZE-1)) + FPA`. |
| `FLASHPREP` / `FLASHESEC` / `FLASHCRTF` | IAP commands 50 / 52 / 51 (prepare / erase / copy). Sector = `FPA >> 10` in the 1K config. `t`=cmd block and `n`=result block land in r0/r1 — exactly the IAP argument registers. |
| `FLASH_FORGET` | Erases all pages `FLASH_SPAGE..FLASH_PPAGE`, resets dictionary pointers (`FISH_ONLY`) or relinks RAM words onto the flash chain. |
| `FLASH_SCAN` | Boot-time: pages whose first cell == `SYSCLK` magic get linked (`CURRENT_SV`←[fpa+8], `UP_SV`←[fpa+12]); bad pages are auto-erased via `ASSUREPAGE`. |

## 2. Config Cross-Check (stock: LPC812, 16K flash / 1K write, 24 MHz IRC) ✓

- `FLASH_WR_SIZE=0x400`, `FLASH_SPAGE=0x3C00`, `FLASH_PPAGE=0x4000`
  → sector `FPA>>10` max = 15, valid for the 16-sector LPC812 ✓
- Erase/copy clock param `SYSTEMCLOCK/1000` = 24000 kHz ✓
- IAP entry `0x1FFF1FF1` ✓ for LPC8xx
- IRQs masked around erase/write ✓
- Page-bound loop never dereferences the reserved `FLASH_PPAGE` ✓

## 3. Findings & Fixes Applied

### 3.1 🐛 FIXED — `FSAVE` opened with `XON` ("Stop Downloads")
`XON_XOFF` flow control is live in the stock config, and `XON` *resumes* host
transmission — the opposite of the intent. `FLASH_FORGET` already opened with
`XOFF` correctly. Fix: `FSAVE` now opens with `XOFF`; the closing `XON` in
`FS_EXIT` was already correct.

### 3.2 ⚠️ FIXED — IAP result codes never checked
`FLASHRET[0]` (IAP status, 0 = `CMD_SUCCESS`) was ignored; a failed
erase/write surfaced only as a "bad page" next boot. Fix: added two
`:NONAME` words and wired them into the save path:

```forth
FLRET      ( -- addr )   \ DOCON FLASHRET — IAP result block address
FLASHQERR  ( -- )        \ if [FLASHRET] != 0: CR ." FLASH IAP ERR " .H CR
```

`FLASHWRITE` runs `FLASHQERR` after the erase and after the copy, with the
checks OUTSIDE the IRQ-off windows (second-pass fix, 2025-10-31: the error
path prints, and `DOTHEX → DIG → MSMOD → USLASH → C_CMSIS_ENABLE_IRQS`
would have re-enabled interrupts mid-window — `C_CMSIS_ENABLE_IRQS` is not
nest-safe, see `main.md` §2.1; split follows the author's ASSUREPAGE
pattern):

```
CMSIS_DISABLE_IRQS FLASHPREP FLASHESEC CMSIS_ENABLE_IRQS FLASHQERR
CMSIS_DISABLE_IRQS FLASHPREP FLASHCRTF CMSIS_ENABLE_IRQS FLASHQERR
```

Notes:
- Checker prints-and-continues (non-fatal by design); UART output is
  poll-driven (`TXRDY_SUBR`), safe inside the IRQ-off window.
- `:NONAME` words have no NFA → dictionary header chain unchanged.
- `RWORD` skips `DOCON` bodies, so `FLRET`'s RAM address constant survives
  `FLASH_SAVE` relocation untouched. ✓
- `FLASHQERR` body references only kernel CFAs (< `DBASE`) → no relocation. ✓
- Erase paths in `FLASH_FORGET`/`ASSUREPAGE` intentionally left unchecked
  (report-only kept minimal); add `FLASHQERR` there if desired.

### 3.3 ✅ Stale comment removed — `TOFA` 4K-mask review block
The code had already been fixed to mask with `FLASH_WR_SIZE-1`; the obsolete
`/* Code Review … hard-codes 0x0FFF … */` block above it was deleted.

## 4. Open Items (not changed)

- **RWORD relocation heuristic**: "any cell > `DBASE` is a RAM address" will
  corrupt large *data* constants not guarded by `LIT`/`RLIT`/`DOCON`.
  Documented rule for savable words: only address-bearing cells may exceed
  `DBASE`. A future hardening could tag data tables explicitly.
- **`FLASHCMD`/`FLASHRET` overallocation** (`FISH_NXP_M0_MEMMAP.s`):
  `.space (4 * (4*5))` = 80 B for a 20 B command block. Harmless; tidy to
  `.space (4*5)` / `.space (4*4)` when convenient.
- **`ASSUREPAGE` stack juggling** (leaves 2 items to offset `FSNEXT`'s `DROP`)
  works but is fragile — per-line stack-effect comments recommended.

## 5. Build & Verify (post-fix, stock defconfig)

```
arm-none-eabi-gcc 13.2.1, -mcpu=cortex-m0plus -mthumb
text 15284 / 16384   data 0   bss 0   (incl. window split + msg_CO terminator)
fitcheck: OK — image end 0x3BB4, 76 B free before FLASH_SPAGE 0x3C00
```

| Check | Result |
|---|---|
| `FSAVE` first cell | `0x29A8` = `XOFF` ✓ (was `XON` `0x29C4`) |
| `FLRET` @ `0x3120` | `DOCON, 0x10000BF4(FLASHRET)` ✓ |
| `FLASHQERR` @ `0x3128` | `DOCOL, FLRET, AT, ZBRAN→FQE_OK, CR, PDOTQ len=14 "FLASH IAP ERR ", FLRET, AT, DOTHEX, CR, SEMIS` ✓ |
| Branch offset `0x2C` | lands exactly on `FQE_OK` (`0x3138+0x2C=0x3164`) ✓ |
| `FLASHWRITE` @ `0x3168` | `FLASHQERR` CFA (`0x3128`) present after erase and after copy ✓ |
| All linker ASSERTs | PASS |

Not yet hardware-tested: exercise `FLASH_SAVE` with a forced IAP failure
(e.g., write-protected/reserved page) to see the `FLASH IAP ERR` report on
the console — see `BENCH_CHECKLIST.md`.
