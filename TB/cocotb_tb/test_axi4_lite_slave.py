"""
Cocotb testbench for axi4_lite_slave
Mirrors the same test cases from the SystemVerilog testbench,
now written in Python.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


async def axi_write(dut, addr, data, strb=0xF):
    """Perform one AXI4-Lite write transaction."""
    dut.AWADDR.value = addr
    dut.AWVALID.value = 1
    dut.WDATA.value = data
    dut.WSTRB.value = strb
    dut.WVALID.value = 1
    dut.BREADY.value = 1

    while not (dut.AWREADY.value and dut.WREADY.value):
        await RisingEdge(dut.ACLK)

    await RisingEdge(dut.ACLK)
    dut.AWVALID.value = 0
    dut.WVALID.value = 0

    while not dut.BVALID.value:
        await RisingEdge(dut.ACLK)

    await RisingEdge(dut.ACLK)
    dut.BREADY.value = 0

    # Extra buffer cycle: let AWREADY/WREADY fully settle back to 0
    # before the next transaction begins.
    await RisingEdge(dut.ACLK)


async def axi_read(dut, addr):
    """Perform one AXI4-Lite read transaction. Returns the data read."""
    dut.ARADDR.value = addr
    dut.ARVALID.value = 1
    dut.RREADY.value = 1

    while not dut.ARREADY.value:
        await RisingEdge(dut.ACLK)

    await RisingEdge(dut.ACLK)
    dut.ARVALID.value = 0

    while not dut.RVALID.value:
        await RisingEdge(dut.ACLK)

    data = dut.RDATA.value
    await RisingEdge(dut.ACLK)
    dut.RREADY.value = 0

    # Extra buffer cycle: let ARREADY fully settle back to 0
    await RisingEdge(dut.ACLK)

    return data


async def reset_dut(dut):
    """Apply reset for a few clock cycles."""
    dut.ARESETn.value = 0
    dut.AWADDR.value = 0
    dut.AWVALID.value = 0
    dut.WDATA.value = 0
    dut.WSTRB.value = 0
    dut.WVALID.value = 0
    dut.BREADY.value = 0
    dut.ARADDR.value = 0
    dut.ARVALID.value = 0
    dut.RREADY.value = 0

    for _ in range(3):
        await RisingEdge(dut.ACLK)
    dut.ARESETn.value = 1
    await RisingEdge(dut.ACLK)


@cocotb.test()
async def test_all_registers(dut):
    """Write and read back all 4 registers."""
    clk_task = cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())
    await reset_dut(dut)

    test_vectors = [
        (0x0, 0xDEADBEEF),
        (0x4, 0x12345678),
        (0x8, 0xAABBCCDD),
        (0xC, 0x11223344),
    ]

    for addr, data in test_vectors:
        await axi_write(dut, addr, data)
        result = await axi_read(dut, addr)
        assert result == data, f"addr 0x{addr:X}: expected 0x{data:X}, got 0x{int(result):X}"
        dut._log.info(f"PASS: addr 0x{addr:X} -> 0x{int(result):X}")

    clk_task.cancel()


@cocotb.test()
async def test_partial_byte_write(dut):
    """Write only one byte using WSTRB and confirm the rest is preserved."""
    clk_task = cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())
    await reset_dut(dut)

    await axi_write(dut, 0x0, 0xDEADBEEF, strb=0xF)
    await axi_write(dut, 0x0, 0x000000FF, strb=0b0001)
    result = await axi_read(dut, 0x0)

    expected = 0xDEADBEFF
    assert result == expected, f"expected 0x{expected:X}, got 0x{int(result):X}"
    dut._log.info(f"PASS: partial byte write -> 0x{int(result):X}")

    clk_task.cancel()


@cocotb.test()
async def test_back_to_back_writes(dut):
    """Two writes with no idle cycles in between."""
    clk_task = cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())
    await reset_dut(dut)

    await axi_write(dut, 0x4, 0xAAAAAAAA)
    await axi_write(dut, 0x8, 0x55555555)

    r1 = await axi_read(dut, 0x4)
    r2 = await axi_read(dut, 0x8)

    assert r1 == 0xAAAAAAAA, f"reg1: got 0x{int(r1):X}"
    assert r2 == 0x55555555, f"reg2: got 0x{int(r2):X}"
    dut._log.info("PASS: back-to-back writes")

    clk_task.cancel()


@cocotb.test()
async def test_unaligned_address(dut):
    """Address with nonzero low bits should still map to the same word."""
    clk_task = cocotb.start_soon(Clock(dut.ACLK, 10, unit="ns").start())
    await reset_dut(dut)

    await axi_write(dut, 0x0, 0xCAFEF00D)
    result = await axi_read(dut, 0x1)

    assert result == 0xCAFEF00D, f"expected 0xCAFEF00D, got 0x{int(result):X}"
    dut._log.info(f"PASS: unaligned address read -> 0x{int(result):X}")

    clk_task.cancel()