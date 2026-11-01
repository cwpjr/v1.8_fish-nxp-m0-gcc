# FISH_NXP_M0_MAIN_INCLUDES.h — Code Review

Date: 2025-10-31
Scope: the master include chain for `FISH_NXP_M0_Forth_GNU.S` (30 lines) +
the two config layers it pulls in (`FISH_RM_CONFIG_#DEFINES.h`,
`FISH_M0_EQUATES.h`, `io_NXP_M0+_header.h`, `FISH_AUTHOR.h`).
Build context: stock defconfig (see `FISH_NXP_M0_Forth_GNU.md` §2).

---

## 1. Include Order Is Load-Bearing

| # | Include | Role | Why this position |
|---|---|---|---|
| 1 | `FISH_AUTHOR.h` | Bare labels (author/copyright/team/contact), **no section directive, no bytes** | Attaches at the start of this object's `.text` contribution → "begins the .sym file". Zero image cost. |
| 2 | `io_NXP_M0+_header.h` | LPC81x register equates (`PINASSIGN*`, `UART0_STAT`, `USART0_RXDAT/TXDAT/BRG/CFG`, `DEVICE_ID_81x`, …) | Pure `.equ` — position-independent; IAR-origin port. |
| 3 | `FISH_ARM_CORTEX_M_REGS.h` | VM register aliases (t,n,w,x,y,i,r,p,ra,rb,k) | Must precede ALL code (macros and every .s use these names). |
| 4 | `FISH_NXP_M0_MACROS.h` | VM instruction set (reviewed: `FISH_NXP_M0_MACROS.md`) | Must follow REGS, precede all code. |
| 5 | `FISH_RM_CONFIG_#DEFINES.h` | **Feature flags** (see §2) | Must precede EQUATES and all code with `#ifdef` feature tests. |
| 6 | `FISH_M0_EQUATES.h` | Clock/flash/RAM **values** (`SYSTEMCLOCK`, `FLASH_*`, `IAPCALL`) keyed off Makefile `ASM_DEFINES` | Consumes Makefile chip defines; must follow them logically. |
| 7 | `FISH_NXP_M0_SLIB.s` | Static-library `:NONAME`s (inner interpreter, QUIT/INTERPRET…) | **First code include → stable low CFA addresses** across dictionary edits (verified: `DOCOL` @ `0x684`, kernel after). |
| 8 | `FISH_NXP_M0_COLD.s` | Reset/warm/ISR (see `ISR_REGISTER_AUDIT.md`) | After SLIB; before MEMMAP (uses its labels via cross-include resolution — order-tolerant). |
| 9 | `FISH_NXP_M0_MEMMAP.s` | `FISH_Ram_MemMap` NOLOAD RAM section | Link-order independent (own section; see linker fix in `ISR_REGISTER_AUDIT.md` §5). |

**Not included here** (included directly by `FISH_NXP_M0_Forth_GNU.S` at
specific points): `FISH_NXP_M0_FLASH.s` (mid-file — LFA-chain position
matters), `*_UART0_INIT.s` / `*_SOC_INIT.s` (chip-conditional),
`FISH_RM_MSGS.h` (EOF).

## 2. The Effective Two-Layer Config System

```
Makefile ASM_DEFINES  (chip/wordset)     FISH_RM_CONFIG_#DEFINES.h  (features)
  NXP_M0_812                               TRUE_EQU_NEG_ONE
  FISH_PubRel_WORDSET                      XON_XOFF
  NXP_M0_81x_IRC12_24MHZ                   ABORT_STOP_TILL_CO
  NXP_M0_016kFlash_1KWrite                 EOL_DLE          ┐ staged for STDLED
  NXP_M0_004kRam                           EOL_NAK          ┘ editor support
  FISH_NO_TIMESTAMP / FISH_LEAN_WORDSET
```

No overlaps between layers ✓. **Correction to the kernel review**
(`FISH_NXP_M0_Forth_GNU.md` §2, now amended): `EOL_DLE`/`EOL_NAK` ARE active
in stock — my earlier flag list sampled only the flags under discussion.

### EOL_DLE / EOL_NAK status (per author: intentional staging)
- Active by design; the *supporting* side (STDLED editor integration) is not
  in this tree yet. On a dumb terminal the emitted bytes are non-printing
  control chars — harmless.
- Wired points: `QUIT` emits DLE (0x10) after each interpreted line
  (`SLIB.s` 482–485, 551), signon carries `msg_SIGNON_DLE`
  (`Forth_GNU.S` 115), and 12 error messages in `FISH_RM_MSGS.h` are
  NAK-wrapped (0x15 … SPACE-NAK terminator) for editor error highlighting.
- If a bench terminal ever shows artifacts: comment the two defines in one
  place (config header) — no other file needs touching ✓ good layering.

## 3. Findings

### 3.1 Dead config flag
`#define FISH_STM32F4_Peripheral_Register_ADDRS` — **zero references**
anywhere in this tree (grep-verified). Vestigial from the shared STM32
config. Removal candidate (keep the STM32 port's own copy).

### 3.2 Config-header tail is clipboard archaeology
21 near-identical pasted blocks of
`STM32F4_DEBUG Configuration Assembly Preprocessor Section:` (all comments,
~60% of the file). Harmless to the build, actively confusing to readers.
Trim to one documented example per historic configuration.

### 3.3 Filename hazards (managed, but fragile)
- `FISH_RM_CONFIG_#DEFINES.h` — the `#` forces a backslash escape in the
  Makefile (`FISH_RM_CONFIG_\#DEFINES.h` ✓ already correct) and quoting in
  every shell/python tool that touches it. Rename candidate:
  `FISH_RM_CONFIG_DEFINES.h` (3 touch points: this include line, Makefile
  `FORTH_INCLUDES`, and any tool references).
- `io_NXP_M0+_header.h` — the `+` is legal but annoys URLs/some globs. Low
  priority.

### 3.4 Vestigial IAR-isms (comment-only)
"generic IAR stuff", IAR install-path comment, `$FISH_M0_MEMMAP.s`—style
references, and the "COPY OF Assembler Preproccesor Defined Symbols" framing
— in the GNU flow the Makefile *is* the defined-symbols section. Reword to
§2's two-layer description when next edited.

### 3.5 Verified-good
- **`USE_CMAIN` warning honored**: the header's "this define must keep
  RESET!!!" — `USE_CMAIN` is commented out and the build confirmed the
  COLD.s `USE_CMAIN` paths compile out. The RESET vector path is intact.
- **Layering respected**: no feature flag appears in Makefile `ASM_DEFINES`,
  no chip define in the config header — the two-layer split is clean.
- **`FISH_AUTHOR.h` trick is free**: labels with no bytes = provenance in
  every `.sym`/`.map` at zero image cost.

## 4. Action Items

- [ ] Delete `FISH_STM32F4_Peripheral_Register_ADDRS` from the NXP config
      copy (§3.1) — zero-reference.
- [ ] Collapse the 21 STM32F4_DEBUG comment blocks to one (§3.2).
- [ ] Consider the `#`-free rename of the config header (§3.3) — low risk,
      3 touch points.
- [ ] Reword IAR-era comments per §2 when the file is next touched (§3.4).
- [ ] When STDLED editor lands: bench-verify DLE/NAK framing against it
      (§2); until then leave both defines ON.

## 5. Build Impact

None — this review changes nothing. Current image: 15,272 B, 88 B free
(`fish_check_fit`, stock defconfig). All §4 items are comment/dead-flag
cleanups with zero image effect (except the rename, which is a build-system
change only).
