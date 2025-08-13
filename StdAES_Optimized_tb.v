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
    wire [2:0] DEMUX_ADD [0:15]; 
    wire [5:0] RWL_DEC_ADD [0:15];
    wire [15:0] IN;


    StdAES_Optimized dut(
        .CLK(CLK), .RSTn(RSTn), .EN(EN), .Din(Din), .KDrdy(KDrdy),
        .RIO_00(RIO[0]), .RIO_01(RIO[1]), .RIO_02(RIO[2]), .RIO_03(RIO[3]),
        .RIO_04(RIO[4]), .RIO_05(RIO[5]), .RIO_06(RIO[6]), .RIO_07(RIO[7]),
        .RIO_08(RIO[8]), .RIO_09(RIO[9]), .RIO_10(RIO[10]), .RIO_11(RIO[11]),
        .RIO_12(RIO[12]), .RIO_13(RIO[13]), .RIO_14(RIO[14]), .RIO_15(RIO[15]),
        .Dout(Dout), .Kvld(Kvld), .Dvld(Dvld), .BSY(BSY),
        .DEMUX_ADD_00(DEMUX_ADD[0]), .DEMUX_ADD_01(DEMUX_ADD[1]), .DEMUX_ADD_02(DEMUX_ADD[2]), .DEMUX_ADD_03(DEMUX_ADD[3]),
        .DEMUX_ADD_04(DEMUX_ADD[4]), .DEMUX_ADD_05(DEMUX_ADD[5]), .DEMUX_ADD_06(DEMUX_ADD[6]), .DEMUX_ADD_07(DEMUX_ADD[7]),
        .DEMUX_ADD_08(DEMUX_ADD[8]), .DEMUX_ADD_09(DEMUX_ADD[9]), .DEMUX_ADD_10(DEMUX_ADD[10]), .DEMUX_ADD_11(DEMUX_ADD[11]),
        .DEMUX_ADD_12(DEMUX_ADD[12]), .DEMUX_ADD_13(DEMUX_ADD[13]), .DEMUX_ADD_14(DEMUX_ADD[14]), .DEMUX_ADD_15(DEMUX_ADD[15]),
        .RWL_DEC_ADD_00(RWL_DEC_ADD[ 0]), .RWL_DEC_ADD_01(RWL_DEC_ADD[ 1]), .RWL_DEC_ADD_02(RWL_DEC_ADD[ 2]), .RWL_DEC_ADD_03(RWL_DEC_ADD[ 3]),
        .RWL_DEC_ADD_04(RWL_DEC_ADD[ 4]), .RWL_DEC_ADD_05(RWL_DEC_ADD[ 5]), .RWL_DEC_ADD_06(RWL_DEC_ADD[ 6]), .RWL_DEC_ADD_07(RWL_DEC_ADD[ 7]),
        .RWL_DEC_ADD_08(RWL_DEC_ADD[ 8]), .RWL_DEC_ADD_09(RWL_DEC_ADD[ 9]), .RWL_DEC_ADD_10(RWL_DEC_ADD[10]), .RWL_DEC_ADD_11(RWL_DEC_ADD[11]),
        .RWL_DEC_ADD_12(RWL_DEC_ADD[12]), .RWL_DEC_ADD_13(RWL_DEC_ADD[13]), .RWL_DEC_ADD_14(RWL_DEC_ADD[14]), .RWL_DEC_ADD_15(RWL_DEC_ADD[15]),
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
        $readmemh("../../../../ark_cim.srcs/sim_1/new/sbox.mem", sbox_mem);
    end

    // Round keys and address storage
    reg [127:0] round_keys [0:10];
    reg [3:0]  round_cnt;
    reg [7:0]  addr_reg [0:15];
    reg [3:0]  cycle_cnt;
    reg        lookup_phase;
    integer i;

    // Select a byte from the current round key
    function [7:0] key_byte;
        input integer idx;
        begin
            key_byte = round_keys[round_cnt][127 - idx*8 -: 8];
        end
    endfunction

    initial begin
        // Pre-expanded AES-128 round keys
        round_keys[0]  = 128'h000102030405060708090a0b0c0d0e0f;
        round_keys[1]  = 128'hd6aa74fdd2af72fadaa678f1d6ab76fe;
        round_keys[2]  = 128'hb692cf0b643dbdf1be9bc5006830b3fe;
        round_keys[3]  = 128'hb6ff744ed2c2c9bf6c590cbf0469bf41;
        round_keys[4]  = 128'h47f7f7bc95353e03f96c32bcfd058dfd;
        round_keys[5]  = 128'h3caaa3e8a99f9deb50f3af57adf622aa;
        round_keys[6]  = 128'h5e390f7df7a69296a7553dc10aa31f6b;
        round_keys[7]  = 128'h14f9701ae35fe28c440adf4d4ea9c026;
        round_keys[8]  = 128'h47438735a41c65b9e016baf4aebf7ad2;
        round_keys[9]  = 128'h549932d1f08557681093ed9cbe2c974e;
        round_keys[10] = 128'h13111d7fe3944a17f307a78b4d2b30c5;

        RSTn = 0; EN = 0; KDrdy = 0; cycle_cnt = 0; lookup_phase = 0; round_cnt = 0;
        for (i = 0; i < 16; i = i + 1) begin
            RIO[i] = 0;
            addr_reg[i] = 0;
        end
        Din  = 128'h00112233445566778899aabbccddeeff;
        #20; RSTn = 1; EN = 1; KDrdy = 1;
        #10; KDrdy = 0;
    end

    // Drive RIO with AddRoundKey and then S-box result (1-cycle RAM delay)
    integer i;
    integer j;

    always @(posedge CLK) begin
        if (!RSTn) begin
            cycle_cnt   <= 0;
            lookup_phase <= 0;
            round_cnt   <= 0;
        end else if (cycle_cnt < 8) begin
            for (i=0;i<8;i=i+1) begin
                RIO[2*i]   <= { (key_byte(0))[i], (key_byte(2))[i], (key_byte(4))[i], (key_byte(6))[i],
                                (key_byte(8))[i], (key_byte(10))[i], (key_byte(12))[i], (key_byte(14))[i] }
                              ^ {8{IN[i+8]}};
                RIO[2*i+1] <= { (key_byte(1))[i], (key_byte(3))[i], (key_byte(5))[i], (key_byte(7))[i],
                                (key_byte(9))[i], (key_byte(11))[i], (key_byte(13))[i], (key_byte(15))[i] }
                              ^ {8{IN[i]}};
            end
            cycle_cnt <= cycle_cnt + 1;
            if (cycle_cnt == 7)
                lookup_phase <= 1;
        end else if (lookup_phase) begin
            for (j = 0; j < 16; j = j + 1)
                RIO[j] <= sbox_mem[{DEMUX_ADD[j],RWL_DEC_ADD[j]}];
            lookup_phase <= 0;
            cycle_cnt   <= 0;
            if (round_cnt < 10)
                round_cnt <= round_cnt + 1;
        end
    end

    // Simple runtime control: wait for output valid
    initial begin
        @(posedge Dvld);
        $display("ciphertext=%h", Dout);
        $finish;
    end
endmodule
