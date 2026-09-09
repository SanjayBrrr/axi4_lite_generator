// =============================================================
// tb_axi4_lite_slave.sv - DEBUG VERSION with extra checkpoints
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
        $display("[TB][t=%0t] Reset released", $time);

        $display("[TB][t=%0t] Writing 32'hDEADBEEF to reg0", $time);
        AWADDR  <= 4'h0;
        AWVALID <= 1;
        WDATA   <= 32'hDEADBEEF;
        WSTRB   <= 4'hF;
        WVALID  <= 1;
        BREADY  <= 1;

        wait (AWREADY && WREADY);
        $display("[TB][t=%0t] Address+Data accepted (AWREADY=%0b WREADY=%0b)", $time, AWREADY, WREADY);
        @(posedge ACLK);
        AWVALID <= 0;
        WVALID  <= 0;

        $display("[TB][t=%0t] Waiting for BVALID...", $time);
        wait (BVALID);
        $display("[TB][t=%0t] BVALID seen! BRESP=%0d", $time, BRESP);
        @(posedge ACLK);
        BREADY <= 0;

        $display("[TB][t=%0t] Reading back reg0", $time);
        ARADDR  <= 4'h0;
        ARVALID <= 1;
        RREADY  <= 1;

        wait (ARREADY);
        $display("[TB][t=%0t] Read address accepted", $time);
        @(posedge ACLK);
        ARVALID <= 0;

        wait (RVALID);
        $display("[TB][t=%0t] RVALID seen! RDATA=0x%h", $time, RDATA);
        @(posedge ACLK);

        if (RDATA == 32'hDEADBEEF)
            $display("[TB] PASS: Read back correct value 0x%h", RDATA);
        else
            $display("[TB] FAIL: Expected 0xDEADBEEF, got 0x%h", RDATA);

        repeat (5) @(posedge ACLK);
        $display("[TB] Test complete.");
        $finish;
    end

    initial begin
        #2000;
        $display("[TB] TIMEOUT at t=%0t - simulation did not finish in time.", $time);
        $finish;
    end

endmodule