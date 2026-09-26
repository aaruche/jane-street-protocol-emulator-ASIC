# Architecture diagrams (v0, provisional)

Block diagrams of the protocol emulator, drawn in [Excalidraw](https://excalidraw.com).
They follow the boundaries in [`../../CLAUDE.md`](../../CLAUDE.md) §3 and the
strawman ISA in [`../spec/isa_v0_strawman.md`](../spec/isa_v0_strawman.md).
**Update them when the real ISA spec is frozen at G0 (Oct 11).**

| # | Diagram | Shows |
|---|---|---|
| 01 | [Chip top level](01_chip_top.svg) | TT pads → SPI loader → control regs → imem / FIFOs → engine → pin block |
| 02 | [Engine datapath](02_engine_datapath.svg) | Single-cycle loop PC → imem mux → decode → execute → next-PC; stall and condition logic |
| 03 | [Engine state and register map](03_engine_state_and_regs.svg) | Instruction format, architectural registers, host-visible registers, host SPI commands |
| 04 | [Pin routing and multiplexers](04_pin_routing.svg) | Per-pin value / OE / open-drain muxes, 2-FF input sync, pin-space base + count mapping |
| 05 | [Verification and remote lab](05_test_and_lab_setup.svg) | cocotb environment, formal, CI, and the DE1-SoC HPS remote test chain |

## Files

- `NN_name.excalidraw`: **source of truth**. Edit these.
- `NN_name.svg`: rendered preview so GitHub shows the diagram. It is regenerated
  from the `.excalidraw` file and must not be edited by hand.

## How to edit

1. Open the `.excalidraw` file at [excalidraw.com](https://excalidraw.com)
   (menu → *Open*), or in VS Code with the *Excalidraw* extension
   (`pomdtr.excalidraw-editor`), which edits `.excalidraw` files in place.
2. Keep the colour legend consistent: blue = host interface, violet = program
   memory, yellow = engine / control, green = registers, teal = FIFOs,
   red = pin logic, grey = pads / infrastructure, cream = notes.
3. Save the `.excalidraw` file, then export the SVG (*Export image → SVG*,
   background on) over the matching `.svg`.
4. Commit both files together, in the same commit as the spec or RTL change
   that motivated the edit.
