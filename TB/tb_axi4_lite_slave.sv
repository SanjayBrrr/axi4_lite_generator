// =============================================================
// tb_axi4_lite_slave.sv
// Simple directed testbench: write to reg0, then read it back
// =============================================================

`timescale 1ns/1ps

module tb_axi4_lite_slave;

    // ------------------------------------------------------------
    // Clock & reset
    // ------------------------------------------------------------
    logic ACLK;
    logic ARESETn;

    // AXI signals
    logic [3:0]  AWADDR;
    logic        AWVALID;
    logic        AWREADY;

    logic [31:0] WDATA;
    logic [3:0]  WSTRB;
    logic        WVALID;
    logic        WREADY;

    logic [1:0]  BRESP;
    logic        BVALID;
    logic        BREADY;

    logic [3:0]  ARADDR;
    logic        ARVALID;
    logic        ARREADY;

    logic [31:0] RDATA;
    logic [1:0]  RRESP;
    logic        RVALID;
    logic        RREADY;

    // ------------------------------------------------------------
    // Instantiate DUT (Device Under Test)
    // ------------------------------------------------------------
    axi4_lite_slave dut (
        .ACLK(ACLK), .ARESETn(ARESETn),
        .AWADDR(AWADDR), .AWVALID(AWVALID), .AWREADY(AWREADY),
        .WDATA(WDATA), .WSTRB(WSTRB), .WVALID(WVALID), .WREADY(WREADY),
        .BRESP(BRESP), .BVALID(BVALID), .BREADY(BREADY),
        .ARADDR(ARADDR), .ARVALID(ARVALID), .ARREADY(ARREADY),
        .RDATA(RDATA), .RRESP(RRESP), .RVALID(RVALID), .RREADY(RREADY)
    );

    // ------------------------------------------------------------
    // Clock generation: 10ns period (100MHz)
    // ------------------------------------------------------------
    initial ACLK = 0;
    always #5 ACLK = ~ACLK;

    // ------------------------------------------------------------
    // Test sequence
    // ------------------------------------------------------------
    initial begin
        // Dump waveform for viewing in GTKWave / similar
        $dumpfile("tb_axi4_lite_slave.vcd");
        $dumpvars(0, tb_axi4_lite_slave);

        // Initialize all signals
        ARESETn = 0;
        AWADDR  = 0; AWVALID = 0;
        WDATA   = 0; WSTRB   = 0; WVALID = 0;
        BREADY  = 0;
        ARADDR  = 0; ARVALID = 0;
        RREADY  = 0;

        // Hold reset for a few cycles
        repeat (3) @(posedge ACLK);
        ARESETn = 1;
        @(posedge ACLK);

        // ---------------- WRITE to reg0 ----------------
        $display("[TB] Writing 32'hDEADBEEF to reg0 (addr 0x0)");
        AWADDR  = 4'h0;
        AWVALID = 1;
        WDATA   = 32'hDEADBEEF;
        WSTRB   = 4'hF;      // write all 4 bytes
        WVALID  = 1;
        BREADY  = 1;

        // Wait until the slave accepts both address and data
        wait (AWREADY && WREADY);
        @(posedge ACLK);
        AWVALID = 0;
        WVALID  = 0;

        // Wait for write response
        wait (BVALID);
        @(posedge ACLK);
        if (BRESP == 2'b00)
            $display("[TB] Write response OKAY");
        else
            $display("[TB] ERROR: Unexpected write response %0d", BRESP);

        // ---------------- READ back reg0 ----------------
        $display("[TB] Reading back reg0 (addr 0x0)");
        ARADDR  = 4'h0;
        ARVALID = 1;
        RREADY  = 1;

        wait (ARREADY);
        @(posedge ACLK);
        ARVALID = 0;

        wait (RVALID);
        @(posedge ACLK);

        if (RDATA == 32'hDEADBEEF)
            $display("[TB] PASS: Read back correct value 0x%h", RDATA);
        else
            $display("[TB] FAIL: Expected 0xDEADBEEF, got 0x%h", RDATA);

        repeat (5) @(posedge ACLK);
        $display("[TB] Test complete.");
        $finish;
    end

endmodule