// =============================================================
// axi4_lite_slave.sv
// A minimal AXI4-Lite slave with 4 x 32-bit read/write registers
// =============================================================

module axi4_lite_slave #(
    parameter ADDR_WIDTH = 4,   // enough to address 4 registers (16 bytes)
    parameter DATA_WIDTH = 32
)(
    input  logic                    ACLK,
    input  logic                    ARESETn,

    // ---------------- Write Address Channel ----------------
    input  logic [ADDR_WIDTH-1:0]   AWADDR,
    input  logic                    AWVALID,
    output logic                    AWREADY,

    // ---------------- Write Data Channel --------------------
    input  logic [DATA_WIDTH-1:0]   WDATA,
    input  logic [(DATA_WIDTH/8)-1:0] WSTRB,
    input  logic                    WVALID,
    output logic                    WREADY,

    // ---------------- Write Response Channel -----------------
    output logic [1:0]              BRESP,
    output logic                    BVALID,
    input  logic                    BREADY,

    // ---------------- Read Address Channel --------------------
    input  logic [ADDR_WIDTH-1:0]   ARADDR,
    input  logic                    ARVALID,
    output logic                    ARREADY,

    // ---------------- Read Data Channel -------------------------
    output logic [DATA_WIDTH-1:0]   RDATA,
    output logic [1:0]              RRESP,
    output logic                    RVALID,
    input  logic                    RREADY
);

    // ------------------------------------------------------------
    // Internal registers (4 x 32-bit)
    // ------------------------------------------------------------
    logic [DATA_WIDTH-1:0] reg0, reg1, reg2, reg3;

    // Latched write address (captured when AWVALID & AWREADY fire)
    logic [ADDR_WIDTH-1:0] awaddr_latched;

    // ------------------------------------------------------------
    // Write Address Channel: accept address when both valid+ready
    // ------------------------------------------------------------
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            AWREADY        <= 1'b0;
            awaddr_latched <= '0;
        end else begin
            if (~AWREADY && AWVALID && WVALID) begin
                AWREADY        <= 1'b1;
                awaddr_latched <= AWADDR;
            end else begin
                AWREADY <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------
    // Write Data Channel: accept data alongside address handshake
    // ------------------------------------------------------------
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            WREADY <= 1'b0;
        end else begin
            if (~WREADY && WVALID && AWVALID) begin
                WREADY <= 1'b1;
            end else begin
                WREADY <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------
    // Register write logic (on the handshake, using byte strobes)
    // ------------------------------------------------------------
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            reg0 <= '0;
            reg1 <= '0;
            reg2 <= '0;
            reg3 <= '0;
        end else if (AWREADY && AWVALID && WREADY && WVALID) begin
            case (awaddr_latched[ADDR_WIDTH-1:2]) // word-aligned index
                2'd0: for (int i = 0; i < DATA_WIDTH/8; i++)
                          if (WSTRB[i]) reg0[i*8 +: 8] <= WDATA[i*8 +: 8];
                2'd1: for (int i = 0; i < DATA_WIDTH/8; i++)
                          if (WSTRB[i]) reg1[i*8 +: 8] <= WDATA[i*8 +: 8];
                2'd2: for (int i = 0; i < DATA_WIDTH/8; i++)
                          if (WSTRB[i]) reg2[i*8 +: 8] <= WDATA[i*8 +: 8];
                2'd3: for (int i = 0; i < DATA_WIDTH/8; i++)
                          if (WSTRB[i]) reg3[i*8 +: 8] <= WDATA[i*8 +: 8];
                default: ; // no-op for out-of-range address
            endcase
        end
    end

    // ------------------------------------------------------------
    // Write Response Channel: always respond OKAY after a write
    // ------------------------------------------------------------
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            BVALID <= 1'b0;
            BRESP  <= 2'b00;
        end else begin
            if (AWREADY && AWVALID && WREADY && WVALID && ~BVALID) begin
                BVALID <= 1'b1;
                BRESP  <= 2'b00; // OKAY
            end else if (BVALID && BREADY) begin
                BVALID <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------
    // Read Address Channel: accept address when ARVALID asserted
    // ------------------------------------------------------------
    logic [ADDR_WIDTH-1:0] araddr_latched;

    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            ARREADY        <= 1'b0;
            araddr_latched <= '0;
        end else begin
            if (~ARREADY && ARVALID) begin
                ARREADY        <= 1'b1;
                araddr_latched <= ARADDR;
            end else begin
                ARREADY <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------
    // Read Data Channel: return register value after address accepted
    // ------------------------------------------------------------
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            RVALID <= 1'b0;
            RDATA  <= '0;
            RRESP  <= 2'b00;
        end else begin
            if (ARREADY && ARVALID && ~RVALID) begin
                RVALID <= 1'b1;
                RRESP  <= 2'b00; // OKAY
                case (araddr_latched[ADDR_WIDTH-1:2])
                    2'd0: RDATA <= reg0;
                    2'd1: RDATA <= reg1;
                    2'd2: RDATA <= reg2;
                    2'd3: RDATA <= reg3;
                    default: RDATA <= '0;
                endcase
            end else if (RVALID && RREADY) begin
                RVALID <= 1'b0;
            end
        end
    end

endmodule