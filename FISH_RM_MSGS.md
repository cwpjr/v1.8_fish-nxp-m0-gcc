# FISH_RM_MSGS.h + FISH_CO_MSGS.h — Code Review

Date: 2025-10-31
Scope: the null-terminated message table (12 error messages + `msg_RUN`,
`msg_cr`, lean-gated `msg_uvspace`/`msg_dictspace`) and the CO-halt message.
Consumed via `LIT, msg_x, NULLSTRLEN, TYPE`. `msg_RUN` is the exception:
a **counted** string (`3, "RUN "`) used with `PFIND` by `ABORT`.
Build context: `EOL_NAK` **ON** (STDLED staging — see
`FISH_NXP_M0_MAIN_INCLUDES.md` §2).

---

## 1. Fixes Applied (this review)

### 🐛 1.1 `#else` (EOL_NAK-off) branches lacked the null terminator
All 12 error messages: the `EOL_NAK` branch ends `0x15, 0x00`, but the
`#else` branch ended at `.ascii` with **no `.byte 0`** — `NULLSTRLEN`
would run into the next message and print garbage in any EOL_NAK-off build.
Stock (NAK on) unaffected. Fixed: `.byte 0` added to all 12 `#else`
branches. Image size unchanged (inactive branches).

### 🐛 1.2 `msg_CO` (FISH_CO_MSGS.h) had no terminator at all
Active in stock (`ABORT_STOP_TILL_CO` defined), though reached only when
`ERROR_HALT` is set (`EHON`). Would print a garbage tail (the trailing
`.word QUIT` bytes) before the null. Fixed: `.byte 0` added (+1 B,
absorbed by alignment padding → +4 B image: 15,272 → 15,284, fitcheck OK,
76 B free).

## 2. Verified-Good

- **`msg_RUN`** (counted, "ALIGN THIS ONE FOR PFIND" honored): `ABORT`'s
  `LIT, msg_RUN, LATEST, PFIND` works because PFIND masks the count with
  `0x3F` (3 = "RUN") and the trailing space is inert padding; a dict word
  `RUN`'s smudged last char compares equal via PFIND's `0x80`-fold ✓.
  Documented rule: `msg_RUN` must stay counted and 4-aligned.
- **EOL_NAK framing** is uniform across all 12 messages (text … `0x15`,
  `0x00`) — the STDLED highlight contract is consistent; toggling
  `EOL_NAK` now (post-fix) changes only framing, never correctness.
- **Lean gating**: `msg_uvspace`/`msg_dictspace` drop with
  `FISH_LEAN_WORDSET` together with their only callers (`.VS`/`.DS`) — no
  dangling references (link-verified: 0 undefined symbols).
- Message style (leading/trailing spaces) matches the TYPE/CR output
  conventions used by QUIT/ERROR.

## 3. Notes

- `msg_questionmark` (" ? ") appears unused (grep: no references outside
  this file) — 4 B; remove when bytes get tight (76 B free today).
- `msg_cr` (" \<CR\> ") is used only by the `IO2TP` `CR` variant — dead in
  stock; same "when tight" bucket.
- The duplicated "DC8 '?'…" header comments (here and in
  `FISH_NXP_M0_Forth_GNU.S`) document the `.ascii` vs counted-string
  convention — keep one copy, link the other.

## 4. Action Items

- [x] Null terminators in all `#else` branches + `msg_CO` (§1).
- [ ] Optional: drop `msg_questionmark`, gate `msg_cr` under `IO2TP`
      (§3) — defer until dictionary space pressure justifies it.

**Last file reviewed: `FISH_RM_MSGS.h` / `FISH_CO_MSGS.h`** (prior:
`FISH_M0_EQUATES.h`).
