"""
Runner script for the cocotb testbench.
Run this with: python run_test.py
(No Makefile/GNU Make required - uses cocotb's built-in Python runner.)
"""

from cocotb_tools.runner import get_runner
import os
import sys

def main():
    sim = "icarus"
    proj_path = os.path.dirname(os.path.abspath(__file__))

    # Path to the RTL file, relative to this script's location
    sources = [os.path.join(proj_path, "..", "..", "RTL", "axi4_lite_slave.sv")]

    sys.path.insert(0, proj_path)
    os.environ["PYTHONPATH"] = proj_path + os.pathsep + os.environ.get("PYTHONPATH", "")

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="axi4_lite_slave",
        build_args=["-g2012"],  # SystemVerilog support, same flag we used manually
        timescale=("1ns", "1ps"),
    )

    runner.test(
        hdl_toplevel="axi4_lite_slave",
        test_module="test_axi4_lite_slave",
        test_dir=proj_path,
        extra_env={"PYTHONPATH": proj_path},
    )

if __name__ == "__main__":
    main()