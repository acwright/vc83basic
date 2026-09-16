# VDP assessment: vc83basic (ac6502 target)

> An outline, not a plan. The detailed plan for this repository goes in `VDP-PLAN.md`,
> written in a session of its own. Surveyed 2026-09-16 across the whole workspace.
> This is a fork with an `upstream` remote. Keep this file out of anything offered
> upstream.

## The change

The ACE moves from a Pico9918 running stock TMS9918A firmware to the **6502-PICOVDP**
(`6502-PICOVDP/SPEC.md`) on PICO9918 PRO v2.0 hardware, running **BIOS 2.x**. Everything
else stays where it is: COB, DEV, KIM, VCS, PicoCalc, and any ACE whose card cannot be
reflashed (RP2040 pico9918 v1.0–1.3). Those keep the stock firmware and **BIOS 1.x (1.5)**.

- **Legacy** in these documents means TMS9918A + BIOS 1.x. **VDP** means PICOVDP + BIOS 2.x.
- **Compatibility runs one way.** The PICOVDP's legacy submode runs Text and Graphics I
  programs unchanged, so BIOS 1.5 and existing cartridges run on it. Graphics II and
  Multicolor fall back to Graphics I and draw garbage. Register writes above 7 no longer
  alias, so F18A tricks break. Sprites per line are 16 by default, not 4. Nothing written
  for the VDP runs on a TMS9918A.
- **BIOS 2.0 is assumed to be:** BIOS 1.5, plus the NVRAM save slots in
  `6502-BIOS/PLAN.md`, plus the VDP work in `6502-EMULATOR`'s
  `docs/handoff/6502-BIOS.md` (branch `v3-vdp`). Existing jump-table addresses stay put.
  A later BIOS redesign may revise this.

## Decisions already made

- No new repositories.
- **6502-EMULATOR** makes the video card an option (TMS9918A or PICOVDP): one app, one
  site. It also publishes a frozen 2.6.9 web build at a versioned path for the legacy docs.
- **6502-DOCS** is versioned: legacy docs are frozen at `/6502-DOCS/v1/`, and the main
  site is rewritten for the VDP.
- **6502-BIOS** gets a `v1.x` maintenance branch; `main` becomes 2.x.
- **Assembly and C projects** get a VDP include chosen by a build option, not branches.
- **EhBASIC and vc83basic** stay 1.x. **PicoCalc** stays legacy. **The YouTube series**
  teaches the legacy VDP and mentions the new features.

## Order across the workspace

1. **6502-PICOVDP:** firmware proven on the PRO (its Phases 9–11). This gates the
   hardware switch, not the software work.
2. **6502-EMULATOR:** frozen 2.6.9 web build at `/6502-EMULATOR/v2/`.
3. **6502-DOCS:** `v1` branch published at `/6502-DOCS/v1/`, embeds pinned to step 2.
4. **6502-EMULATOR:** `v3-vdp` merged, with the card as an option; tagged 3.x.
5. **6502-BIOS:** `v1.x` cut; 2.0 built on `main`. This can start any time, because the
   `v3-vdp` emulator already runs the PICOVDP.
6. **6502-ASM** sets the VDP include convention. 6502-CRT, 6502-PRG, 6502-BIN and 6502-C
   follow it.
7. The emulator bundles BIOS 2.0. 6502-DOCS `main` is rewritten. 6502-ACE, bastok,
   WIZARDSLAB, 6502-EHBASIC, vc83basic and 6502-ASSEMBLY follow.

---

## This repository's role

VC83 BASIC with an `ac6502` target (`targets/ac6502/`): a cartridge that uses the BIOS
Kernal for I/O and adds `CLS`, `LOCATE`, `COLOR`, `SOUND`, `TIME` and similar statements
(`ac6502_extension.s`). **It stays 1.x by decision.**

## Impact: light, and verification only

- **No direct VDP access.** The video statements `jmp` to `VideoClear`, `VideoSetCursor`
  and `VideoSetColor`. `ac6502_io.s` checks `HW_PRESENT`'s `HW_VID` bit and `IO_MODE`.
- `targets/ac6502/ac6502.inc` is its own 262-line include, written against BIOS 1.5. It
  states: "the addresses do not move between BIOS versions". BIOS 2.0 must keep that
  promise (`6502-BIOS/tests/fixtures/jumptable.json`).

## Work outline

1. **Verify on both platforms** once BIOS 2.0 exists: build `basic_ac6502` and run it in
   the emulator with the TMS9918A card + BIOS 1.5, and with the PICOVDP card + BIOS 2.0.
   Check the video statements, console scrolling and serial console.
2. **Comment only:** `ac6502.inc`'s header could say "BIOS 1.5; runs unchanged on 2.x".
3. **Out of scope for now:** BIOS 2.0's new entries and VDP statements.

## Linked repositories

| Repository | Path | Why |
|---|---|---|
| 6502-BIOS | `~/Developer/Assembly/6502-BIOS` | Jump-table stability in 2.0 is what keeps this working |
| 6502-EMULATOR | `~/Developer/NodeJS/6502-EMULATOR` | Both cards, for verification |
| 6502-EHBASIC | `~/Developer/Assembly/6502-EHBASIC` | The other 1.x BASIC cartridge, in the same position |
