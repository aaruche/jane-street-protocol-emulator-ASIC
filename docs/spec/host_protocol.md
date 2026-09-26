# Host protocol (SPI loader)

> **Status: skeleton.** Owner: **Person 3 (host interface)**. Items marked
> **Proposed** are recommendations; items marked **TO DECIDE** are yours to
> fill in. Finalize this file and get it reviewed by the other two before
> **G0 (Oct 11)**. After that it is the contract for `pe_ctrl`,
> `sw/host/protocol.py`, the cocotb driver, and the HPS tool.
>
> Related: hardware contract in [`block_interfaces.md`](block_interfaces.md)
> §6–7, register list in [diagram 03](../diagrams/03_engine_state_and_regs.svg),
> boundaries in [`../../CLAUDE.md`](../../CLAUDE.md) §3.

Who speaks this protocol:

| Host | Where | When |
|---|---|---|
| cocotb SPI-master driver | simulation | from Week 2 |
| HPS loader tool (C, bit-bangs PIO lines) | DE1-SoC FPGA | from Week 5 (ROADMAP §5.4, S4) |
| Tiny Tapeout demo board (MicroPython) | real silicon | after tape-out |

---

## 1. Physical layer

- SPI **mode 0** (CPOL = 0, CPHA = 0): SCLK idles low; both sides sample on
  the rising edge; the host changes MOSI on the falling edge. **MSB first.**
- Pins: `ui_in[0]` SCLK, `ui_in[1]` CS_N (active low), `ui_in[2]` MOSI,
  `uo_out[0]` MISO.
- Timing the host must meet: see the table in
  [`block_interfaces.md` §6](block_interfaces.md#host-timing-requirements)
  (SCLK ≤ clk/8, CS_N setup ≥ 8 clk, …). Copy the final numbers here once
  simulation confirms them.
- **Known limitation:** `uo_out` pins cannot be tri-stated on Tiny Tapeout, so
  MISO is always driven (0 when CS_N is high). This chip cannot share an SPI
  bus with other devices.

## 2. Framing (Proposed)

- **One command per frame.** A frame is CS_N low → bytes → CS_N high. The first
  MOSI byte is the command; the rest are its arguments or data.
- **The first MISO byte of every frame is STATUS** (§4), sent while the host
  clocks in the command byte. Every transaction therefore doubles as a status
  poll, which is useful for the host's polling loop.
- **Abort rule:** CS_N high at any point ends the frame. A partial byte is
  discarded, and an incomplete command has no effect (e.g. WRITE_IMEM with a
  `hi` byte but no `lo` byte writes nothing).

## 3. Commands

**TO DECIDE: command byte values.** Guidance: **don't use 0x00 or 0xFF.** A
floating or stuck MOSI line reads as all-zeros or all-ones; if those are
illegal commands, a wiring fault shows up as `BAD_CMD` instead of silently
doing something.

**TO DECIDE: turnaround byte for reads.** The table below proposes one dummy
byte between the address and the first data byte of READ_REG / READ_IMEM.
- **With it:** `pe_ctrl` has a whole byte-time to fetch the data and can
  register it, which makes the logic simple and timing-safe. It costs one extra
  byte per read.
- **Without it:** `pe_ctrl` must compute `tx_byte` combinationally from
  `rx_byte` in the same cycle, through the register or imem read mux. That is
  legal (one clock domain) but a longer path. Pick one and write down why.

In the table, `x` = don't care; `hiN/loN` = bytes of the 16-bit instruction at
address `addr + N`.

| Command | Code | MOSI | MISO | Notes |
|---|---|---|---|---|
| WRITE_IMEM | `0x??` | cmd, addr, hi0, lo0, hi1, lo1, … | STATUS, x, x, … | **Proposed:** auto-increment, so a whole program loads in one frame. Writes happen on each `lo`. Rejected while running (§5). |
| READ_IMEM | `0x??` | cmd, addr, dummy, dummy, … | STATUS, x, x, hi0, lo0, hi1, … | Auto-increment. Only valid while halted (shared read port). |
| WRITE_REG | `0x??` | cmd, reg, value | STATUS, x, x | Register addresses from diagram 03 |
| READ_REG | `0x??` | cmd, reg, dummy, dummy | STATUS, x, x, value | |
| PUSH_TX | `0x??` | cmd, b0, b1, … | STATUS, x, … | Each byte → TX FIFO |
| POP_RX | `0x??` | cmd, dummy, dummy, … | STATUS, d0, d1, … | No turnaround needed: the show-ahead RX FIFO already presents `d0`. Each byte handed out is popped. |

**TO DECIDE:**
- Does auto-increment wrap at `IMEM_DEPTH`, or stop?
- How does the host know how many bytes to pop? Read `FIFO_LVL` first, or use
  an `RX_NONEMPTY` bit in STATUS (§4), or both.

## 4. Register bit layouts (TO DECIDE)

The register list and addresses are in
[diagram 03](../diagrams/03_engine_state_and_regs.svg). Choose the bit positions
here, then update the diagram to match.

**STATUS (0x01, R)**, also sent as MISO byte 0 of every frame.
Proposed contents (8 bits, positions TBD): `RUNNING`, `HALTED`, `TIMEOUT`,
`ATTN`, `ERR` (any ERROR bit set), `TX_FULL`, `RX_NONEMPTY`, spare.

| Bit | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---|---|---|---|---|---|---|---|---|
| Name | | | | | | | | |

**CTRL (0x00, W)**: write-1 pulses; the bits don't stay set.
Contents: `RUN`, `HALT`, `STEP`, `SOFT_RESET`.
**Proposed:** if RUN and HALT are both written in one byte, HALT wins.

| Bit | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---|---|---|---|---|---|---|---|---|
| Name | | | | | | | | |

**ERROR (0x05, R / W1C)**: stays set until the host writes 1 to that bit.
Contents: `WR_WHILE_RUN`, `BAD_CMD`, `TX_OVERFLOW`, `RX_UNDERFLOW`, and possibly
`RD_WHILE_RUN` (see §5).

| Bit | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---|---|---|---|---|---|---|---|---|
| Name | | | | | | | | |

## 5. Errors and corner cases (Proposed)

| Situation | Behavior | ERROR bit |
|---|---|---|
| Unknown command byte | Rest of frame ignored | `BAD_CMD` |
| CS_N high mid-command | Command has no effect | none |
| WRITE_IMEM while running | No write happens | `WR_WHILE_RUN` |
| READ_IMEM while running | **TO DECIDE:** return 0x00s? | `RD_WHILE_RUN`? |
| "W (halted)" register written while running | Write ignored | `WR_WHILE_RUN` |
| PUSH_TX while TX FIFO full | Byte dropped | `TX_OVERFLOW` |
| POP_RX while RX FIFO empty | Returns 0x00 | `RX_UNDERFLOW` |
| STEP while running | **TO DECIDE:** ignored? | |
| SOFT_RESET | PC = START_PC. **TO DECIDE:** does it also clear the FIFOs, TIMEOUT, ATTN, ERROR? | |
| Reading or writing an unused register address (0x06–07, >0x0F) | **TO DECIDE:** read 0x00 / ignore write? | `BAD_CMD`? |

## 6. Worked example (TODO for Person 3)

Once §3–4 are decided, write the complete byte sequence for loading and running
the UART TX example from [`isa_v0_strawman.md`](isa_v0_strawman.md): halt,
set CLKDIV, pin bases, SHIFT_CFG, WRITE_IMEM the 9 words in one frame,
READ_IMEM to verify, RUN, PUSH_TX "Hi", poll STATUS. This example becomes the
first test in `sw/host/protocol.py` and the G1 top-level test.

## 7. Open questions (tick off before G0)

- [ ] Command byte values chosen (no 0x00 / 0xFF)
- [ ] Turnaround byte for reads: yes / no, with the reason written in §3
- [ ] Auto-increment behavior at the end of imem
- [ ] STATUS, CTRL and ERROR bit positions filled in (and diagram 03 updated)
- [ ] All TO DECIDE rows in §5 resolved
- [ ] Host timing numbers confirmed by the `pe_host_spi` simulation and copied into §1
- [ ] Worked example (§6) written
- [ ] Reviewed by Person 1 and Person 2
