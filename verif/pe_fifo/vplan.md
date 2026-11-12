# Verification plan: `pe_fifo`

> **Status: template.** Two rows (F1, F2) are filled in as worked examples;
> the rest is yours (ladder step 1, see [`../README.md`](../README.md)).
>
> Source of truth: [`docs/spec/block_interfaces.md` §1](../../docs/spec/block_interfaces.md#1-pe_fifo-show-ahead-synchronous-fifo).
> Every rule in its **Behavior** table, its output rules and its test/formal
> checklists should become at least one row below. If a rule is ambiguous,
> fix the spec first and note it under "Spec issues found".

## 1. Requirements → checks → coverage → tests

How to write a row:
- **Requirement:** one testable sentence, quoted or paraphrased from the spec.
- **Check:** *where* a failure would be detected. SB = scoreboard (reference
  model compare); SVA = assertion in `sva/`; FV = formal proof in
  `formal/pe_fifo.sby`. Name the specific assertion or comparison.
- **Coverage:** the covergroup bin or `cover property` that proves the
  situation actually happened. A check with no coverage can pass vacuously.
- **Test:** the UVM test(s) that should hit the coverage.

| ID | Requirement | Check | Coverage | Test(s) | Status |
|---|---|---|---|---|---|
| F1 | After reset (`rst_n = 0` at a clock edge): `level = 0`, `empty = 1`, `full = 0`, `overflow = 0`, `underflow = 0`. | **SB:** after every reset the model is cleared and every output is compared on the next cycle. **SVA:** `a_reset_values`: `!rst_n \|=> (level == 0 && empty && !full && !overflow && !underflow)` | `c_reset_while_nonempty`: `cover property` for reset asserted while `level > 0` (reset mid-traffic, not only at time 0) | `fifo_reset_test`; random reset injection in `fifo_random_test` | ☐ |
| F2 | A push when full is rejected: contents unchanged, and `overflow` is 1 for exactly the next cycle. This also holds when a pop happens in the same cycle (no pass-through). | **SB:** the model ignores the push when its own count is `DEPTH`; later pops prove the contents were not corrupted. **SVA:** `a_overflow_cause`: `overflow \|-> $past(push && full)`, and `a_overflow_pulse`: `disable iff (!rst_n) (push && full) \|=> overflow` (without the `disable iff`, a push while full in a cycle where reset is asserted would fire it falsely, because reset forces `overflow` to 0) | Cross of op × state: bins `<push, full>` and `<push+pop, full>` | `fifo_fill_overflow_test`, `fifo_random_test` | ☐ |
| F3 | | | | | ☐ |
| … | | | | | |

Hints for the remaining rows (one row each, or more):
- Accepted push / accepted pop updates `level` by ±1.
- Push + pop together, neither full nor empty: `level` unchanged, order kept.
- Push + pop together when empty: push accepted, pop ignored, `underflow`
  pulses.
- Pop when empty is ignored and `underflow` pulses for one cycle.
- `pop_data` shows the head entry whenever `!empty` (show-ahead), before any
  pop.
- `full == (level == DEPTH)`, `empty == (level == 0)`, never both.
- `level` stays within `0..DEPTH`.
- Data ordering: bytes come out in the order they were accepted.
- Pointer wrap-around works (more than `DEPTH` pushes in total).
- `full` / `empty` / `level` depend only on registered state, never on
  this cycle's `push` / `pop`.

## 2. Coverage model

Write the covergroups here first (names, coverpoints, bins, crosses), then
implement them in `uvm/fifo_coverage.sv`. Suggested targets:

| Covergroup / coverpoint | Bins | Goal |
|---|---|---|
| `level` | each value 0 … `DEPTH` | 100% |
| op × state cross | op ∈ {none, push, pop, push+pop} × state ∈ {empty, mid, full} | 100% (12 bins) |
| events | overflow seen, underflow seen | both hit |
| wrap | write pointer wrapped ≥ 2 times | hit |
| … | | |

## 3. Formal plan (ladder step 5)

List each property you will prove in `formal/pe_fifo.sby`, its assumptions,
and the result (bounded to depth N, or unbounded with k-induction).

| Property | Assumptions | Result |
|---|---|---|
| | | |

## 4. Tests

| Test class | Sequence(s) | Purpose |
|---|---|---|
| `fifo_reset_test` | | |
| `fifo_fill_overflow_test` | | |
| `fifo_random_test` | | |
| … | | |

## 5. Spec issues found

Anything in `block_interfaces.md` that was ambiguous or wrong, and how it was
resolved.

## 6. Results

Run log: [`results/README.md`](results/README.md). Sign-off: `signoff.md`
(written at step 8).
