// =============================================================
// tb_axi4_lite_slave.sv
// Expanded testbench: multiple directed test cases
// =============================================================

`timescale 1ns/1ps

module tb_axi4_lite_slave;

    logic ACLK;
    logic ARESETn;

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

    axi4_lite_slave dut (
        .ACLK(ACLK), .ARESETn(ARESETn),
        .AWADDR(AWADDR), .AWVALID(AWVALID), .AWREADY(AWREADY),
        .WDATA(WDATA), .WSTRB(WSTRB), .WVALID(WVALID), .WREADY(WREADY),
        .BRESP(BRESP), .BVALID(BVALID), .BREADY(BREADY),
        .ARADDR(ARADDR), .ARVALID(ARVALID), .ARREADY(ARREADY),
        .RDATA(RDATA), .RRESP(RRESP), .RVALID(RVALID), .RREADY(RREADY)
    );

    initial ACLK = 0;
    always #5 ACLK = ~ACLK;

    // ------------------------------------------------------------
    // Pass/fail bookkeeping
    // ------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;

    // ------------------------------------------------------------
    // Reusable AXI4-Lite write task
    // ------------------------------------------------------------
    task automatic axi_write(input [3:0] addr, input [31:0] data, input [3:0] strb);
        begin
            AWADDR  <= addr;
            AWVALID <= 1;
            WDATA   <= data;
            WSTRB   <= strb;
            WVALID  <= 1;
            BREADY  <= 1;

            wait (AWREADY && WREADY);
            @(posedge ACLK);
            AWVALID <= 0;
            WVALID  <= 0;

            wait (BVALID);
            @(posedge ACLK);
            BREADY <= 0;
        end
    endtask

    // ------------------------------------------------------------
    // Reusable AXI4-Lite read task
    // ------------------------------------------------------------
    task automatic axi_read(input [3:0] addr, output [31:0] data);
        begin
            ARADDR  <= addr;
            ARVALID <= 1;
            RREADY  <= 1;

            wait (ARREADY);
            @(posedge ACLK);
            ARVALID <= 0;

            wait (RVALID);
            data = RDATA;
            @(posedge ACLK);
            RREADY <= 0;
        end
    endtask

    // ------------------------------------------------------------
    // Check helper
    // ------------------------------------------------------------
    task automatic check(input string name, input [31:0] actual, input [31:0] expected);
        begin
            if (actual === expected) begin
                $display("[PASS] %s: got 0x%h", name, actual);
                pass_count++;
            end else begin
                $display("[FAIL] %s: expected 0x%h, got 0x%h", name, expected, actual);
                fail_count++;
            end
        end
    endtask

    // ------------------------------------------------------------
    // Test sequence
    // ------------------------------------------------------------
    logic [31:0] rdata_tmp;

    initial begin
        $dumpfile("tb_axi4_lite_slave.vcd");
        $dumpvars(0, tb_axi4_lite_slave);

        ARESETn = 0;
        AWADDR  = 0; AWVALID = 0;
        WDATA   = 0; WSTRB   = 0; WVALID = 0;
        BREADY  = 0;
        ARADDR  = 0; ARVALID = 0;
        RREADY  = 0;

        repeat (3) @(posedge ACLK);
        ARESETn <= 1;
        @(posedge ACLK);

        // ---- Test 1-4: write & read back each of the 4 registers ----
        $display("\n--- Test: write/read all 4 registers ---");
        axi_write(4'h0, 32'hDEADBEEF, 4'hF);
        axi_read (4'h0, rdata_tmp);
        check("reg0 write/read", rdata_tmp, 32'hDEADBEEF);

        axi_write(4'h4, 32'h12345678, 4'hF);
        axi_read (4'h4, rdata_tmp);
        check("reg1 write/read", rdata_tmp, 32'h12345678);

        axi_write(4'h8, 32'hAABBCCDD, 4'hF);
        axi_read (4'h8, rdata_tmp);
        check("reg2 write/read", rdata_tmp, 32'hAABBCCDD);

        axi_write(4'hC, 32'h11223344, 4'hF);
        axi_read (4'hC, rdata_tmp);
        check("reg3 write/read", rdata_tmp, 32'h11223344);

        // ---- Test 5: partial byte write using WSTRB ----
        // reg0 currently holds 0xDEADBEEF. Write only byte 0 (WSTRB=0001)
        // with 0xFF -> expect only the lowest byte to change: 0xDEADBEFF
        $display("\n--- Test: partial byte write (WSTRB) ---");
        axi_write(4'h0, 32'h000000FF, 4'b0001);
        axi_read (4'h0, rdata_tmp);
        check("reg0 partial byte write", rdata_tmp, 32'hDEADBEFF);

        // ---- Test 6: back-to-back writes, no idle cycles ----
        $display("\n--- Test: back-to-back writes ---");
        axi_write(4'h4, 32'hAAAAAAAA, 4'hF);
        axi_write(4'h8, 32'h55555555, 4'hF);
        axi_read (4'h4, rdata_tmp);
        check("back-to-back reg1", rdata_tmp, 32'hAAAAAAAA);
        axi_read (4'h8, rdata_tmp);
        check("back-to-back reg2", rdata_tmp, 32'h55555555);

        // ---- Test 7: unaligned address (lower 2 bits nonzero) ----
        // addr 0x1 should still map to reg0 since only addr[3:2] is decoded
        $display("\n--- Test: unaligned address maps to same word ---");
        axi_write(4'h0, 32'hCAFEF00D, 4'hF);
        axi_read (4'h1, rdata_tmp); // note: addr 0x1, not 0x0
        check("unaligned addr read maps to reg0", rdata_tmp, 32'hCAFEF00D);

        // ---- Summary ----
        $display("\n=== SUMMARY: %0d passed, %0d failed ===", pass_count, fail_count);

        repeat (5) @(posedge ACLK);
        $finish;
    end

    // Safety timeout
    initial begin
        #2000;
        $display("[TB] TIMEOUT at t=%0t", $time);
        $finish;
    end

endmodule