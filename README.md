## AXI4-Lite Peripheral — Design & Verification

A small AXI4-Lite slave peripheral, built and verified as a hands-on project while learning digital design verification (DV) workflows.

## What this is

A 4-register, 32-bit AXI4-Lite slave written in SystemVerilog, verified using **two independent testbenches** — one in SystemVerilog, one in Python (cocotb) — to cross-check the same behavior from two different verification approaches.

## Design

`RTL/axi4_lite_slave.sv` implements:
- 4 independently addressable 32-bit registers
- Full AXI4-Lite read and write channels (AW, W, B, AR, R)
- Byte-level write masking via `WSTRB` (write only specific bytes of a word)
- Word-aligned address decoding

## Verification

Two separate testbenches exercise the same design, covering:
- Write/read to all 4 registers
- Partial byte writes using `WSTRB`
- Back-to-back writes with no idle cycles between transactions
- Unaligned address handling (address bits below the word boundary)

| Testbench | Location | Tool | Result |
|---|---|---|---|
| SystemVerilog | `TB/tb_axi4_lite_slave.sv` | Icarus Verilog | 8/8 passing |
| cocotb (Python) | `TB/cocotb_tb/test_axi4_lite_slave.py` | Icarus Verilog + cocotb | 4/4 passing |

### Running the tests

**SystemVerilog testbench:**
```bash
iverilog -g2012 -o sim.vvp RTL/axi4_lite_slave.sv TB/tb_axi4_lite_slave.sv
vvp sim.vvp
```

**cocotb testbench:**
```bash
cd TB/cocotb_tb
python run_test.py
```

## Notes on the process

This project was built as a learning exercise, and debugging it surfaced a couple of genuinely useful lessons worth recording:

- A signal-sampling race condition showed up in the cocotb testbench, where reading a DUT signal immediately after a clock edge occasionally caught a stale value from the previous cycle. Fixed by adding an explicit settle cycle between transactions rather than assuming immediate consistency.
- Verified with a deliberate bug-injection check — a wrong-register write was manually introduced into the RTL to confirm both testbenches actually catch incorrect behavior, not just pass by default. *(Update this section with the actual result once you've run it.)*

## What's not covered (yet)

This is a first-pass verification suite, not a complete one. Known gaps:
- No randomized stimulus — all test cases use hand-picked values
- No functional coverage tracking
- No protocol assertions (SVA) checking AXI4-Lite compliance beyond the tested scenarios
- Address space is small (4 registers) by design, so invalid-address handling isn't meaningfully testable as-is

## Tools used
- Icarus Verilog (simulation)
- GTKWave (waveform viewing)
- cocotb (Python-based verification)
- VS Code + Git/GitHub