`timescale 1ns/1ps
module StdAES_Optimized_tb;
    reg CLK;
    reg RSTn;
    reg EN;
    reg [127:0] Din;
    reg KDrdy;

    // RIO ports modeled as an array
    reg [7:0] RIO [0:15];

    wire [127:0] Dout;
    wire Kvld, Dvld, BSY;
    wire [2:0] DEMUX_ADD_00, DEMUX_ADD_01, DEMUX_ADD_02, DEMUX_ADD_03;
    wire [2:0] DEMUX_ADD_04, DEMUX_ADD_05, DEMUX_ADD_06, DEMUX_ADD_07;
    wire [2:0] DEMUX_ADD_08, DEMUX_ADD_09, DEMUX_ADD_10, DEMUX_ADD_11;
    wire [2:0] DEMUX_ADD_12, DEMUX_ADD_13, DEMUX_ADD_14, DEMUX_ADD_15;
    wire [5:0] RWL_DEC_ADD_00, RWL_DEC_ADD_01, RWL_DEC_ADD_02, RWL_DEC_ADD_03;
    wire [5:0] RWL_DEC_ADD_04, RWL_DEC_ADD_05, RWL_DEC_ADD_06, RWL_DEC_ADD_07;
    wire [5:0] RWL_DEC_ADD_08, RWL_DEC_ADD_09, RWL_DEC_ADD_10, RWL_DEC_ADD_11;
    wire [5:0] RWL_DEC_ADD_12, RWL_DEC_ADD_13, RWL_DEC_ADD_14, RWL_DEC_ADD_15;
    wire [15:0] IN;

    StdAES_Optimized dut(
        .CLK(CLK), .RSTn(RSTn), .EN(EN), .Din(Din), .KDrdy(KDrdy),
        .RIO_00(RIO[0]), .RIO_01(RIO[1]), .RIO_02(RIO[2]), .RIO_03(RIO[3]),
        .RIO_04(RIO[4]), .RIO_05(RIO[5]), .RIO_06(RIO[6]), .RIO_07(RIO[7]),
        .RIO_08(RIO[8]), .RIO_09(RIO[9]), .RIO_10(RIO[10]), .RIO_11(RIO[11]),
        .RIO_12(RIO[12]), .RIO_13(RIO[13]), .RIO_14(RIO[14]), .RIO_15(RIO[15]),
        .Dout(Dout), .Kvld(Kvld), .Dvld(Dvld), .BSY(BSY),
        .DEMUX_ADD_00(DEMUX_ADD_00), .DEMUX_ADD_01(DEMUX_ADD_01), .DEMUX_ADD_02(DEMUX_ADD_02), .DEMUX_ADD_03(DEMUX_ADD_03),
        .DEMUX_ADD_04(DEMUX_ADD_04), .DEMUX_ADD_05(DEMUX_ADD_05), .DEMUX_ADD_06(DEMUX_ADD_06), .DEMUX_ADD_07(DEMUX_ADD_07),
        .DEMUX_ADD_08(DEMUX_ADD_08), .DEMUX_ADD_09(DEMUX_ADD_09), .DEMUX_ADD_10(DEMUX_ADD_10), .DEMUX_ADD_11(DEMUX_ADD_11),
        .DEMUX_ADD_12(DEMUX_ADD_12), .DEMUX_ADD_13(DEMUX_ADD_13), .DEMUX_ADD_14(DEMUX_ADD_14), .DEMUX_ADD_15(DEMUX_ADD_15),
        .RWL_DEC_ADD_00(RWL_DEC_ADD_00), .RWL_DEC_ADD_01(RWL_DEC_ADD_01), .RWL_DEC_ADD_02(RWL_DEC_ADD_02), .RWL_DEC_ADD_03(RWL_DEC_ADD_03),
        .RWL_DEC_ADD_04(RWL_DEC_ADD_04), .RWL_DEC_ADD_05(RWL_DEC_ADD_05), .RWL_DEC_ADD_06(RWL_DEC_ADD_06), .RWL_DEC_ADD_07(RWL_DEC_ADD_07),
        .RWL_DEC_ADD_08(RWL_DEC_ADD_08), .RWL_DEC_ADD_09(RWL_DEC_ADD_09), .RWL_DEC_ADD_10(RWL_DEC_ADD_10), .RWL_DEC_ADD_11(RWL_DEC_ADD_11),
        .RWL_DEC_ADD_12(RWL_DEC_ADD_12), .RWL_DEC_ADD_13(RWL_DEC_ADD_13), .RWL_DEC_ADD_14(RWL_DEC_ADD_14), .RWL_DEC_ADD_15(RWL_DEC_ADD_15),
        .IN(IN)
    );

    // Clock generation
    initial begin
        CLK = 0;
        forever #5 CLK = ~CLK;
    end

    // S-box table stored in RAM
    reg [7:0] sbox_mem [0:255];
    initial begin
        $readmemh("sbox.mem", sbox_mem);
    end

    // Initial key and address storage
    reg [127:0] key = 128'h000102030405060708090a0b0c0d0e0f;
    reg [7:0] addr_reg [0:15];
    reg [3:0] cycle_cnt;
    reg lookup_phase;
    integer i;

    function [7:0] key_byte;
        input integer idx;
        begin
            key_byte = key[127 - idx*8 -: 8];
        end
    endfunction

    initial begin
        RSTn = 0; EN = 0; KDrdy = 0; cycle_cnt = 0; lookup_phase = 0;
        for (i = 0; i < 16; i = i + 1) begin
            RIO[i] = 0;
            addr_reg[i] = 0;
        end
        Din  = 128'h00112233445566778899aabbccddeeff;
        #20; RSTn = 1; EN = 1; KDrdy = 1;
        #10; KDrdy = 0;
    end

    // Drive RIO with AddRoundKey and then S-box result (1-cycle RAM delay)
    integer j;
    always @(posedge CLK) begin
        if (!RSTn) begin
            cycle_cnt <= 0;
            lookup_phase <= 0;
        end else if (cycle_cnt < 8) begin
            RIO[2*cycle_cnt]   <= IN[15:8] ^ key_byte(2*cycle_cnt);
            RIO[2*cycle_cnt+1] <= IN[7:0]  ^ key_byte(2*cycle_cnt+1);
            addr_reg[2*cycle_cnt]   <= IN[15:8] ^ key_byte(2*cycle_cnt);
            addr_reg[2*cycle_cnt+1] <= IN[7:0]  ^ key_byte(2*cycle_cnt+1);
            cycle_cnt <= cycle_cnt + 1;
            if (cycle_cnt == 7)
                lookup_phase <= 1;
        end else if (lookup_phase) begin
            for (j = 0; j < 16; j = j + 1)
                RIO[j] <= sbox_mem[addr_reg[j]];
            lookup_phase <= 0;
        end
    end

    // Simple runtime control
    initial begin
        for (i = 0; i < 8; i = i + 1) begin
            @(posedge CLK);
            $display("cycle %0d IN=%h", i, IN);
        end
        @(posedge CLK); // lookup phase
        @(posedge CLK); // output phase
        $finish;
    end
endmodule

