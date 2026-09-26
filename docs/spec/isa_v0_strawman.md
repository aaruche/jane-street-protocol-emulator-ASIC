# ISA v0: strawman (provisional)

> **Status: strawman for discussion.** It exists so the diagrams in
> [`../diagrams/`](../diagrams/) have something concrete to show. Student A owns the
> real spec and replaces this file with `isa.md` at gate **G0 (Oct 11)**. Every
> number here is open to change within the boundaries in
> [`../../CLAUDE.md`](../../CLAUDE.md) §3.

## Machine model

Single-cycle, unpipelined (decision D1). One instruction executes per **engine
cycle**. An engine cycle is one core clock when `CLKDIV = 1`; otherwise the engine
advances only on the clock enable from a 16-bit integer divider, as in RP2040
PIO. Unless noted, every instruction takes **1 engine cycle + its delay field**.

| State | Width | Reset value | Written by |
|---|---|---|---|
| `PC` | 7 (for 128 words) | `START_PC` | engine; host via soft reset |
| `X`, `Y` | 16 | 0 | `SET`, `CTRL XHI/YHI`, `MOV`, `OUT`, `JMP X--/Y--`, `WAIT` timeout (Y) |
| `OSR` + shift count | 8 + 4 | 0, empty | `PULL`, `MOV`; consumed by `OUT` |
| `ISR` + shift count | 8 + 4 | 0, empty | `IN`, `MOV`; drained by `PUSH` |
| `DLY` | 3 | 0 | delay field (internal) |
| `TIMEOUT` flag | 1 | 0 | `WAIT` with timeout; cleared by `JMP TIMEOUT` when taken |
| `PINS`, `PINDIRS` | 13 each | 0, 0 (all inputs) | `SET`, `OUT`, `MOV` |

## Instruction format (16 bits)

```
 15   13 12   10 9                                 0
+-------+-------+-----------------------------------+
|  op   | delay |               args                |
+-------+-------+-----------------------------------+
```

`delay` = 0–7 extra engine cycles **after** the instruction completes (pins
hold their values). Longer waits use `JMP X--` loops (16-bit X).

| op | Mnemonic | args `[9:0]` | Semantics | Cycles |
|---|---|---|---|---|
| `000` | `JMP cond, addr` | `[9:7]` cond, `[6:0]` addr | Conditions: always, `!X`, `X--`, `!Y`, `Y--`, `PIN` (JMP_PIN high), `TIMEOUT`, `!OSRE`. `X--`/`Y--` test for non-zero, then decrement | 1 |
| `001` | `WAIT pol, pin [, to]` | `[9]` pol, `[8]` timeout-enable, `[7:4]` pin index | Stall until `pin == pol`. With timeout: Y decrements every stalled cycle; at 0 the instruction completes and sets `TIMEOUT` | 1 + stall |
| `010` | `IN src, n` | `[9:8]` src (PINS from `IN_BASE`, X, Y, NULL), `[3:0]` n (0 = 8) | Shift n bits into ISR | 1 |
| `011` | `OUT dst, n` | `[9:8]` dst (PINS from `OUT_BASE`, PINDIRS, X, Y), `[3:0]` n | Shift n bits out of OSR | 1 |
| `100` | `PUSH` / `PULL` | `[9]` 0 = PUSH, 1 = PULL; `[8]` block | PUSH: ISR → RX FIFO. PULL: TX FIFO → OSR. Blocking stalls on full/empty | 1 + stall |
| `101` | `MOV dst, op(src)` | `[9:7]` dst, `[6:4]` src, `[3:2]` op | dst: PINS, X, Y, ISR, OSR, PINDIRS. src: PINS, X, Y, ISR, OSR, NULL, STATUS, TIMESTAMP. op: none / invert / bit-reverse | 1 |
| `110` | `SET dst, imm8` | `[9:8]` dst (PINS from `SET_BASE`, PINDIRS, X, Y), `[7:0]` imm | X/Y are zero-extended | 1 |
| `111` | `CTRL sub, imm8` | `[9:8]` sub, `[7:0]` imm | `HALT`, `ATTN code` (raise ATTN, code readable by host), `XHI imm` (X[15:8] = imm), `YHI imm` | 1 |

A 16-bit constant takes two instructions: `SET X, lo` then `CTRL XHI, hi`.

## Pin space (16 logical indices)

| Index | Read (`IN`, `WAIT`, `JMP PIN`, `MOV src PINS`) | Write (`SET`, `OUT`, `MOV dst PINS`) |
|---|---|---|
| 0–7 | `P0`–`P7` (`uio_in`, synchronized) | `P0`–`P7` (`uio_out` / `uio_oe`) |
| 8–12 | `IN0`–`IN4` (`ui_in[7:3]`, synchronized) | `OUT0`–`OUT4` (`uo_out[7:3]`, always driven) |
| 13–15 | read as 0 | ignored |

Base + count pin groups wrap modulo 16 and are configured by the host while
halted: `OUT_BASE/OUT_CNT`, `SET_BASE/SET_CNT`, `IN_BASE`, `JMP_PIN`.

**Open-drain:** for each `P` pin with its `OD_MASK` bit set, `uio_out = 0` and
`uio_oe = ~value`. Writing 0 drives low; writing 1 releases the line to the
pull-up. It can never drive 1.

## Timing rules (to be confirmed in `isa.md`)

- **Pin update:** outputs written by an instruction are registered at the end of
  its engine cycle and appear on the pad at the next core clock edge.
- **Input sample:** pin reads see the pad value delayed by the 2-FF synchronizer
  (2 core clocks). Firmware timing tables must include this latency.
- **Stall:** during a stall, nothing architecturally visible changes except `Y`
  when a WAIT timeout is enabled. The delay field starts only after the stall
  ends.

## Example: UART TX, 8N1 (8 engine cycles per bit)

Configuration: `SET_BASE = OUT_BASE = 0` (P0 = TX), `SET_CNT = OUT_CNT = 1`,
`CLKDIV = f_clk / (8 × baud)`, OSR shifts LSB first.

```
        SET  PINDIRS, 1
        SET  PINS, 1          ; line idles high
loop:   PULL block            ; wait for the host to push a byte
        SET  X, 7             ; 8 data bits
        SET  PINS, 0   [7]    ; start bit            = 8 cycles
bit:    OUT  PINS, 1   [6]    ; data bit (6+1) + JMP = 8 cycles
        JMP  X--, bit
        SET  PINS, 1   [6]    ; stop bit (6+1) + JMP + PULL + SET >= 8 cycles
        JMP  loop
```

## Where we differ from RP2040 PIO / TI PRU (novelty candidates)

1. **WAIT with timeout** (`TIMEOUT` flag + `JMP TIMEOUT`), which gives robust I2C
   clock stretching and stuck-bus recovery. PIO's WAIT can hang forever.
2. **Hardware open-drain pins** (`OD_MASK`). PIO emulates these with pindirs
   tricks.
3. **16-bit X/Y loop counters**, so slow protocols (I2C 100 kHz, PS/2) don't
   need huge clock dividers.
4. **Host debugger:** halt, single-step, PC readback and imem readback over the
   loader.
5. **Logic-analyzer / sniffer firmware:** `MOV ISR, PINS` + `PUSH`, optionally
   with `TIMESTAMP`. This turns the chip into a protocol sniffer with no extra
   hardware.

## Open questions for A (resolve at G0)

- Keep the clock divider, or rely only on X/Y loops? The divider makes
  firmware portable across baud rates.
- Side-set (PIO-style: toggle a clock pin in the same instruction as data)? It
  would make SPI 2× faster, but it costs delay-field bits.
- Is a 3-bit delay field enough, and is `IMEM_DEPTH = 128` needed (7-bit
  addresses)?
- Autopush/autopull: skip for v1?
- Exact semantics of `MOV src STATUS` and `TIMESTAMP` width.
