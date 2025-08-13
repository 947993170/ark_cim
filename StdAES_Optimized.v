//`timescale 1 ns/1 ps
module StdAES_Optimized
(
    // inputs
    input  wire         CLK,
    input  wire         RSTn,
    input  wire         EN,
    input  wire [127:0] Din,
    input  wire         KDrdy,

    input  wire [7:0]   RIO_00,
    input  wire [7:0]   RIO_01,
    input  wire [7:0]   RIO_02,
    input  wire [7:0]   RIO_03,
    input  wire [7:0]   RIO_04,
    input  wire [7:0]   RIO_05,
    input  wire [7:0]   RIO_06,
    input  wire [7:0]   RIO_07,
    input  wire [7:0]   RIO_08,
    input  wire [7:0]   RIO_09,
    input  wire [7:0]   RIO_10,
    input  wire [7:0]   RIO_11,
    input  wire [7:0]   RIO_12,
    input  wire [7:0]   RIO_13,
    input  wire [7:0]   RIO_14,
    input  wire [7:0]   RIO_15,

    // outputs
    output wire [127:0] Dout,
    output reg          Kvld,
    output reg          Dvld,
    output reg          BSY,

    output wire [2:0]   DEMUX_ADD_00,
    output wire [2:0]   DEMUX_ADD_01,
    output wire [2:0]   DEMUX_ADD_02,
    output wire [2:0]   DEMUX_ADD_03,
    output wire [2:0]   DEMUX_ADD_04,
    output wire [2:0]   DEMUX_ADD_05,
    output wire [2:0]   DEMUX_ADD_06,
    output wire [2:0]   DEMUX_ADD_07,
    output wire [2:0]   DEMUX_ADD_08,
    output wire [2:0]   DEMUX_ADD_09,
    output wire [2:0]   DEMUX_ADD_10,
    output wire [2:0]   DEMUX_ADD_11,
    output wire [2:0]   DEMUX_ADD_12,
    output wire [2:0]   DEMUX_ADD_13,
    output wire [2:0]   DEMUX_ADD_14,
    output wire [2:0]   DEMUX_ADD_15,

    output wire [5:0]   RWL_DEC_ADD_00,
    output wire [5:0]   RWL_DEC_ADD_01,
    output wire [5:0]   RWL_DEC_ADD_02,
    output wire [5:0]   RWL_DEC_ADD_03,
    output wire [5:0]   RWL_DEC_ADD_04,
    output wire [5:0]   RWL_DEC_ADD_05,
    output wire [5:0]   RWL_DEC_ADD_06,
    output wire [5:0]   RWL_DEC_ADD_07,
    output wire [5:0]   RWL_DEC_ADD_08,
    output wire [5:0]   RWL_DEC_ADD_09,
    output wire [5:0]   RWL_DEC_ADD_10,
    output wire [5:0]   RWL_DEC_ADD_11,
    output wire [5:0]   RWL_DEC_ADD_12,
    output wire [5:0]   RWL_DEC_ADD_13,
    output wire [5:0]   RWL_DEC_ADD_14,
    output wire [5:0]   RWL_DEC_ADD_15,

    output wire [15:0]  IN
);

    // -------------------------------------------------
    // internal regs/wires (保留原有)
    // -------------------------------------------------
    wire        rst = ~RSTn;

    reg [127:0] dat;
    reg [127:0] dat_dff;
    reg [3:0]   dcnt;
    reg [1:0]   sel;

    // sbox result wires (保持为 wire，下面用寄存器回连)
    wire [7:0] sbox_result_00, sbox_result_01, sbox_result_02, sbox_result_03;
    wire [7:0] sbox_result_04, sbox_result_05, sbox_result_06, sbox_result_07;
    wire [7:0] sbox_result_08, sbox_result_09, sbox_result_10, sbox_result_11;
    wire [7:0] sbox_result_12, sbox_result_13, sbox_result_14, sbox_result_15;

    // -------------------------------------------------
    // 原有 Dvld/Kvld/BSY/counter/sel 逻辑（未改动）
    // -------------------------------------------------
    always @(posedge CLK or posedge rst) begin
        if (rst)       Dvld <= 1'b0;
        else if (EN)   Dvld <= (sel == 2'b10);
    end

    always @(posedge CLK or posedge rst) begin
        if (rst)       Kvld <= 1'b0;
        else if (EN)   Kvld <= KDrdy ? 1'b1 : 1'b0;
    end

    always @(posedge CLK or posedge rst) begin
        if (rst) begin
            BSY <= 1'b0;
        end else if (EN) begin
            if (KDrdy)            BSY <= 1'b1;
            else if (dcnt == 4'd0) BSY <= 1'b0;
            else                   BSY <= BSY;
        end
    end

    // AES 核
    wire [127:0] dat_next;
    StdAES_Optimized_AES_Core aes_core (
        .din ( (sel == 2'd0) ? dat_dff : dat ),
        .dout(dat_next),
        .sel ( sel )
    );

    // 轮次计数与 sel 控制
    always @(posedge CLK or posedge rst) begin
        if (rst) begin
            dcnt <= 4'd0;
            sel  <= 2'd0;
        end else if (EN) begin
            if (KDrdy) begin
                dcnt <= 4'd10;
                sel  <= 2'd0;
            end else if (state_q == ST_LOOKUP) begin
                if (grp_idx_q == 4'd0) begin
                    sel <= 2'd1;
                end else begin
                    if (dcnt > 0)
                        dcnt <= dcnt - 4'd1;
                    sel <= (dcnt == 4'd2) ? 2'd2 : 2'd1;
                end
            end
        end
    end

    // dat 在 ST_LOOKUP 时更新，dat_dff 延迟一拍
    always @(posedge CLK or posedge rst) begin
        if (rst) begin
            dat <= 128'h5555_5555_5555_5555_5555_5555_5555_5555;
        end else if (EN) begin
            if (KDrdy) begin
                dat <= Din;
            end else if (state_q == ST_LOOKUP) begin
                dat <= {
                    sbox_result_15, sbox_result_14, sbox_result_13, sbox_result_12,
                    sbox_result_11, sbox_result_10, sbox_result_09, sbox_result_08,
                    sbox_result_07, sbox_result_06, sbox_result_05, sbox_result_04,
                    sbox_result_03, sbox_result_02, sbox_result_01, sbox_result_00
                };
            end
        end
    end

    always @(posedge CLK) begin
        if (EN)
            dat_dff <= dat;
    end

    assign Dout = dat_next;

    // =================================================
    // 下面是：三段式状态机（读→查）整合
    // =================================================

    // 将 RIO 规范成顺序信号（若你有 RIO_08/09，请映射替换掉 8'h00）
    wire [7:0] rio_00 = RIO_00;
    wire [7:0] rio_01 = RIO_01;
    wire [7:0] rio_02 = RIO_02;
    wire [7:0] rio_03 = RIO_03;
    wire [7:0] rio_04 = RIO_04;
    wire [7:0] rio_05 = RIO_05;
    wire [7:0] rio_06 = RIO_06;
    wire [7:0] rio_07 = RIO_07;
    wire [7:0] rio_08 = RIO_08;   // TODO: 若存在 RIO_08，请改为 RIO_08
    wire [7:0] rio_09 = RIO_09;   // TODO: 若存在 RIO_09，请改为 RIO_09
    wire [7:0] rio_10 = RIO_10;
    wire [7:0] rio_11 = RIO_11;
    wire [7:0] rio_12 = RIO_12;
    wire [7:0] rio_13 = RIO_13;
    wire [7:0] rio_14 = RIO_14;
    wire [7:0] rio_15 = RIO_15;

    // FSM 参数
    localparam integer NUM_GROUPS   = 11;
    localparam         IN_MSB_FIRST = 1'b1;

    // 状态编码
    localparam [1:0] ST_IDLE   = 2'd0;
    localparam [1:0] ST_READ   = 2'd1;  // 8 cycles
    localparam [1:0] ST_LOOKUP = 2'd2;  // 1 cycle
    localparam [1:0] ST_OUT    = 2'd3;  // 1 cycle

    reg [1:0] state_q, state_d;
    reg [3:0] grp_idx_q, grp_idx_d;   // 0..10
    reg [3:0] read_cnt_q, read_cnt_d; // 0..7

    // ark 寄存器：8 拍采集 bit7..0
    reg [7:0] ark_q_00, ark_q_01, ark_q_02, ark_q_03;
    reg [7:0] ark_q_04, ark_q_05, ark_q_06, ark_q_07;
    reg [7:0] ark_q_08, ark_q_09, ark_q_10, ark_q_11;
    reg [7:0] ark_q_12, ark_q_13, ark_q_14, ark_q_15;

    // 查表结果寄存
    reg [7:0] sbox_q_00, sbox_q_01, sbox_q_02, sbox_q_03;
    reg [7:0] sbox_q_04, sbox_q_05, sbox_q_06, sbox_q_07;
    reg [7:0] sbox_q_08, sbox_q_09, sbox_q_10, sbox_q_11;
    reg [7:0] sbox_q_12, sbox_q_13, sbox_q_14, sbox_q_15;

    // 地址寄存输出
    reg [2:0] demux_q_00, demux_q_01, demux_q_02, demux_q_03;
    reg [2:0] demux_q_04, demux_q_05, demux_q_06, demux_q_07;
    reg [2:0] demux_q_08, demux_q_09, demux_q_10, demux_q_11;
    reg [2:0] demux_q_12, demux_q_13, demux_q_14, demux_q_15;

    reg [5:0] rwl_q_00, rwl_q_01, rwl_q_02, rwl_q_03;
    reg [5:0] rwl_q_04, rwl_q_05, rwl_q_06, rwl_q_07;
    reg [5:0] rwl_q_08, rwl_q_09, rwl_q_10, rwl_q_11;
    reg [5:0] rwl_q_12, rwl_q_13, rwl_q_14, rwl_q_15;

    // IN 寄存
    reg [15:0] IN_q;

    // group 配置函数（无 initial）
    function [2:0] get_demux_code;
        input [3:0] g;
    begin
        case (g)
            4'd0, 4'd4, 4'd8  : get_demux_code = 3'b111;
            4'd1, 4'd5, 4'd9  : get_demux_code = 3'b110;
            4'd2, 4'd6, 4'd10 : get_demux_code = 3'b101;
            4'd3, 4'd7        : get_demux_code = 3'b100;
            default           : get_demux_code = 3'b000;
        endcase
    end
    endfunction

    function [5:0] get_row_code;
        input [3:0] g;
    begin
        case (g)
            4'd0,4'd1,4'd2,4'd3   : get_row_code = 6'h00;
            4'd4,4'd5,4'd6,4'd7   : get_row_code = 6'h01;
            4'd8,4'd9,4'd10       : get_row_code = 6'h02;
            default               : get_row_code = 6'h00;
        endcase
    end
    endfunction

    function use_datnext;
        input [3:0] g;
    begin
        use_datnext = (g != 4'd0);
    end
    endfunction

    function [15:0] pick_2b;
        input [127:0] data128;
        input [3:0]   idx;      // 0..7
    begin
        if (IN_MSB_FIRST == 1'b1) pick_2b = data128[127 - (idx*16) -: 16];
        else                      pick_2b = data128[(idx*16) +: 16];
    end
    endfunction

    wire [127:0] src128 = use_datnext(grp_idx_q) ? dat_next : Din;

    // 状态寄存
    always @(posedge CLK or posedge rst) begin
        if (rst) begin
            state_q    <= ST_IDLE;
            grp_idx_q  <= 4'd0;
            read_cnt_q <= 4'd0;
        end else if (EN) begin
            state_q    <= state_d;
            grp_idx_q  <= grp_idx_d;
            read_cnt_q <= read_cnt_d;
        end
    end

    // 次态组合
    always @* begin
        state_d    = state_q;
        grp_idx_d  = grp_idx_q;
        read_cnt_d = read_cnt_q;

        case (state_q)
            ST_IDLE: begin
                if (EN && KDrdy) begin
                    grp_idx_d  = 4'd0;
                    read_cnt_d = 4'd0;
                    state_d    = ST_READ;
                end
            end

            ST_READ: begin
                if (read_cnt_q == 4'd7) begin
                    read_cnt_d = 4'd0;
                    state_d    = ST_LOOKUP;
                end else begin
                    read_cnt_d = read_cnt_q + 4'd1;
                end
            end

            ST_LOOKUP: begin
                if (grp_idx_q == 4'd10) begin
                    state_d = ST_OUT;
                end else begin
                    grp_idx_d = grp_idx_q + 4'd1;
                    state_d   = ST_READ;
                end
            end

            ST_OUT: begin
                state_d = ST_IDLE;
            end

            default: state_d = ST_IDLE;
        endcase
    end

    // 时序输出与数据路径
    always @(posedge CLK or posedge rst) begin
        if (rst) begin
            IN_q <= 16'h0000;

            demux_q_00 <= 3'b000; rwl_q_00 <= 6'h00;
            demux_q_01 <= 3'b000; rwl_q_01 <= 6'h00;
            demux_q_02 <= 3'b000; rwl_q_02 <= 6'h00;
            demux_q_03 <= 3'b000; rwl_q_03 <= 6'h00;
            demux_q_04 <= 3'b000; rwl_q_04 <= 6'h00;
            demux_q_05 <= 3'b000; rwl_q_05 <= 6'h00;
            demux_q_06 <= 3'b000; rwl_q_06 <= 6'h00;
            demux_q_07 <= 3'b000; rwl_q_07 <= 6'h00;
            demux_q_08 <= 3'b000; rwl_q_08 <= 6'h00;
            demux_q_09 <= 3'b000; rwl_q_09 <= 6'h00;
            demux_q_10 <= 3'b000; rwl_q_10 <= 6'h00;
            demux_q_11 <= 3'b000; rwl_q_11 <= 6'h00;
            demux_q_12 <= 3'b000; rwl_q_12 <= 6'h00;
            demux_q_13 <= 3'b000; rwl_q_13 <= 6'h00;
            demux_q_14 <= 3'b000; rwl_q_14 <= 6'h00;
            demux_q_15 <= 3'b000; rwl_q_15 <= 6'h00;

            ark_q_00 <= 8'h00; ark_q_01 <= 8'h00; ark_q_02 <= 8'h00; ark_q_03 <= 8'h00;
            ark_q_04 <= 8'h00; ark_q_05 <= 8'h00; ark_q_06 <= 8'h00; ark_q_07 <= 8'h00;
            ark_q_08 <= 8'h00; ark_q_09 <= 8'h00; ark_q_10 <= 8'h00; ark_q_11 <= 8'h00;
            ark_q_12 <= 8'h00; ark_q_13 <= 8'h00; ark_q_14 <= 8'h00; ark_q_15 <= 8'h00;

            sbox_q_00 <= 8'h00; sbox_q_01 <= 8'h00; sbox_q_02 <= 8'h00; sbox_q_03 <= 8'h00;
            sbox_q_04 <= 8'h00; sbox_q_05 <= 8'h00; sbox_q_06 <= 8'h00; sbox_q_07 <= 8'h00;
            sbox_q_08 <= 8'h00; sbox_q_09 <= 8'h00; sbox_q_10 <= 8'h00; sbox_q_11 <= 8'h00;
            sbox_q_12 <= 8'h00; sbox_q_13 <= 8'h00; sbox_q_14 <= 8'h00; sbox_q_15 <= 8'h00;

        end else if (EN) begin
            // 保持（避免隐式锁存）
            IN_q <= IN_q;

            demux_q_00 <= demux_q_00; rwl_q_00 <= rwl_q_00;
            demux_q_01 <= demux_q_01; rwl_q_01 <= rwl_q_01;
            demux_q_02 <= demux_q_02; rwl_q_02 <= rwl_q_02;
            demux_q_03 <= demux_q_03; rwl_q_03 <= rwl_q_03;
            demux_q_04 <= demux_q_04; rwl_q_04 <= rwl_q_04;
            demux_q_05 <= demux_q_05; rwl_q_05 <= rwl_q_05;
            demux_q_06 <= demux_q_06; rwl_q_06 <= rwl_q_06;
            demux_q_07 <= demux_q_07; rwl_q_07 <= rwl_q_07;
            demux_q_08 <= demux_q_08; rwl_q_08 <= rwl_q_08;
            demux_q_09 <= demux_q_09; rwl_q_09 <= rwl_q_09;
            demux_q_10 <= demux_q_10; rwl_q_10 <= rwl_q_10;
            demux_q_11 <= demux_q_11; rwl_q_11 <= rwl_q_11;
            demux_q_12 <= demux_q_12; rwl_q_12 <= rwl_q_12;
            demux_q_13 <= demux_q_13; rwl_q_13 <= rwl_q_13;
            demux_q_14 <= demux_q_14; rwl_q_14 <= rwl_q_14;
            demux_q_15 <= demux_q_15; rwl_q_15 <= rwl_q_15;

            ark_q_00 <= ark_q_00; ark_q_01 <= ark_q_01; ark_q_02 <= ark_q_02; ark_q_03 <= ark_q_03;
            ark_q_04 <= ark_q_04; ark_q_05 <= ark_q_05; ark_q_06 <= ark_q_06; ark_q_07 <= ark_q_07;
            ark_q_08 <= ark_q_08; ark_q_09 <= ark_q_09; ark_q_10 <= ark_q_10; ark_q_11 <= ark_q_11;
            ark_q_12 <= ark_q_12; ark_q_13 <= ark_q_13; ark_q_14 <= ark_q_14; ark_q_15 <= ark_q_15;

            sbox_q_00 <= sbox_q_00; sbox_q_01 <= sbox_q_01; sbox_q_02 <= sbox_q_02; sbox_q_03 <= sbox_q_03;
            sbox_q_04 <= sbox_q_04; sbox_q_05 <= sbox_q_05; sbox_q_06 <= sbox_q_06; sbox_q_07 <= sbox_q_07;
            sbox_q_08 <= sbox_q_08; sbox_q_09 <= sbox_q_09; sbox_q_10 <= sbox_q_10; sbox_q_11 <= sbox_q_11;
            sbox_q_12 <= sbox_q_12; sbox_q_13 <= sbox_q_13; sbox_q_14 <= sbox_q_14; sbox_q_15 <= sbox_q_15;

            case (state_q)
                ST_READ: begin
                    // 组固定地址
                    demux_q_00 <= get_demux_code(grp_idx_q); rwl_q_00 <= get_row_code(grp_idx_q);
                    demux_q_01 <= get_demux_code(grp_idx_q); rwl_q_01 <= get_row_code(grp_idx_q);
                    demux_q_02 <= get_demux_code(grp_idx_q); rwl_q_02 <= get_row_code(grp_idx_q);
                    demux_q_03 <= get_demux_code(grp_idx_q); rwl_q_03 <= get_row_code(grp_idx_q);
                    demux_q_04 <= get_demux_code(grp_idx_q); rwl_q_04 <= get_row_code(grp_idx_q);
                    demux_q_05 <= get_demux_code(grp_idx_q); rwl_q_05 <= get_row_code(grp_idx_q);
                    demux_q_06 <= get_demux_code(grp_idx_q); rwl_q_06 <= get_row_code(grp_idx_q);
                    demux_q_07 <= get_demux_code(grp_idx_q); rwl_q_07 <= get_row_code(grp_idx_q);
                    demux_q_08 <= get_demux_code(grp_idx_q); rwl_q_08 <= get_row_code(grp_idx_q);
                    demux_q_09 <= get_demux_code(grp_idx_q); rwl_q_09 <= get_row_code(grp_idx_q);
                    demux_q_10 <= get_demux_code(grp_idx_q); rwl_q_10 <= get_row_code(grp_idx_q);
                    demux_q_11 <= get_demux_code(grp_idx_q); rwl_q_11 <= get_row_code(grp_idx_q);
                    demux_q_12 <= get_demux_code(grp_idx_q); rwl_q_12 <= get_row_code(grp_idx_q);
                    demux_q_13 <= get_demux_code(grp_idx_q); rwl_q_13 <= get_row_code(grp_idx_q);
                    demux_q_14 <= get_demux_code(grp_idx_q); rwl_q_14 <= get_row_code(grp_idx_q);
                    demux_q_15 <= get_demux_code(grp_idx_q); rwl_q_15 <= get_row_code(grp_idx_q);

                    // IN 两字节
                    IN_q <= pick_2b(src128, read_cnt_q);

                    // 采样当前位面（bit = 7-read_cnt_q）
                    case (read_cnt_q)
                        4'd0: begin
                            ark_q_00 <= {rio_07[7],rio_06[7],rio_05[7],rio_04[7],rio_03[7],rio_02[7],rio_01[7],rio_00[7]};
                            ark_q_01 <= {rio_15[7],rio_14[7],rio_13[7],rio_12[7],rio_11[7],rio_10[7],rio_09[7],rio_08[7]};
                        end
                        4'd1: begin
                            ark_q_02 <= {rio_07[6],rio_06[6],rio_05[6],rio_04[6],rio_03[6],rio_02[6],rio_01[6],rio_00[6]};
                            ark_q_03 <= {rio_15[6],rio_14[6],rio_13[6],rio_12[6],rio_11[6],rio_10[6],rio_09[6],rio_08[6]};
                        end
                        4'd2: begin
                            ark_q_04 <= {rio_07[5],rio_06[5],rio_05[5],rio_04[5],rio_03[5],rio_02[5],rio_01[5],rio_00[5]};
                            ark_q_05 <= {rio_15[5],rio_14[5],rio_13[5],rio_12[5],rio_11[5],rio_10[5],rio_09[5],rio_08[5]};
                        end
                        4'd3: begin
                            ark_q_06 <= {rio_07[4],rio_06[4],rio_05[4],rio_04[4],rio_03[4],rio_02[4],rio_01[4],rio_00[4]};
                            ark_q_07 <= {rio_15[4],rio_14[4],rio_13[4],rio_12[4],rio_11[4],rio_10[4],rio_09[4],rio_08[4]};
                        end
                        4'd4: begin
                            ark_q_08 <= {rio_07[3],rio_06[3],rio_05[3],rio_04[3],rio_03[3],rio_02[3],rio_01[3],rio_00[3]};
                            ark_q_09 <= {rio_15[3],rio_14[3],rio_13[3],rio_12[3],rio_11[3],rio_10[3],rio_09[3],rio_08[3]};
                        end
                        4'd5: begin
                            ark_q_10 <= {rio_07[2],rio_06[2],rio_05[2],rio_04[2],rio_03[2],rio_02[2],rio_01[2],rio_00[2]};
                            ark_q_11 <= {rio_15[2],rio_14[2],rio_13[2],rio_12[2],rio_11[2],rio_10[2],rio_09[2],rio_08[2]};
                        end
                        4'd6: begin
                            ark_q_12 <= {rio_07[1],rio_06[1],rio_05[1],rio_04[1],rio_03[1],rio_02[1],rio_01[1],rio_00[1]};
                            ark_q_13 <= {rio_15[1],rio_14[1],rio_13[1],rio_12[1],rio_11[1],rio_10[1],rio_09[1],rio_08[1]};
                        end
                        4'd7: begin
                            ark_q_14 <= {rio_07[0],rio_06[0],rio_05[0],rio_04[0],rio_03[0],rio_02[0],rio_01[0],rio_00[0]};
                            ark_q_15 <= {rio_15[0],rio_14[0],rio_13[0],rio_12[0],rio_11[0],rio_10[0],rio_09[0],rio_08[0]};
                        end
                        default: ;
                    endcase
                end

                ST_LOOKUP: begin
                    // 地址 = {1'b0, ark[7:6]} & ark[5:0]
                    demux_q_00 <= {1'b0, ark_q_00[7:6]}; rwl_q_00 <= ark_q_00[5:0];
                    demux_q_01 <= {1'b0, ark_q_01[7:6]}; rwl_q_01 <= ark_q_01[5:0];
                    demux_q_02 <= {1'b0, ark_q_02[7:6]}; rwl_q_02 <= ark_q_02[5:0];
                    demux_q_03 <= {1'b0, ark_q_03[7:6]}; rwl_q_03 <= ark_q_03[5:0];
                    demux_q_04 <= {1'b0, ark_q_04[7:6]}; rwl_q_04 <= ark_q_04[5:0];
                    demux_q_05 <= {1'b0, ark_q_05[7:6]}; rwl_q_05 <= ark_q_05[5:0];
                    demux_q_06 <= {1'b0, ark_q_06[7:6]}; rwl_q_06 <= ark_q_06[5:0];
                    demux_q_07 <= {1'b0, ark_q_07[7:6]}; rwl_q_07 <= ark_q_07[5:0];
                    demux_q_08 <= {1'b0, ark_q_08[7:6]}; rwl_q_08 <= ark_q_08[5:0];
                    demux_q_09 <= {1'b0, ark_q_09[7:6]}; rwl_q_09 <= ark_q_09[5:0];
                    demux_q_10 <= {1'b0, ark_q_10[7:6]}; rwl_q_10 <= ark_q_10[5:0];
                    demux_q_11 <= {1'b0, ark_q_11[7:6]}; rwl_q_11 <= ark_q_11[5:0];
                    demux_q_12 <= {1'b0, ark_q_12[7:6]}; rwl_q_12 <= ark_q_12[5:0];
                    demux_q_13 <= {1'b0, ark_q_13[7:6]}; rwl_q_13 <= ark_q_13[5:0];
                    demux_q_14 <= {1'b0, ark_q_14[7:6]}; rwl_q_14 <= ark_q_14[5:0];
                    demux_q_15 <= {1'b0, ark_q_15[7:6]}; rwl_q_15 <= ark_q_15[5:0];

                    // 读取 RIO 结果
                    sbox_q_00 <= rio_00; sbox_q_01 <= rio_01; sbox_q_02 <= rio_02; sbox_q_03 <= rio_03;
                    sbox_q_04 <= rio_04; sbox_q_05 <= rio_05; sbox_q_06 <= rio_06; sbox_q_07 <= rio_07;
                    sbox_q_08 <= rio_08; sbox_q_09 <= rio_09; sbox_q_10 <= rio_10; sbox_q_11 <= rio_11;
                    sbox_q_12 <= rio_12; sbox_q_13 <= rio_13; sbox_q_14 <= rio_14; sbox_q_15 <= rio_15;
                end

                default: begin
                    IN_q <= 16'h0000;
                end
            endcase
        end
    end

    // 端口输出
    assign IN = IN_q;

    assign DEMUX_ADD_00 = demux_q_00; assign RWL_DEC_ADD_00 = rwl_q_00;
    assign DEMUX_ADD_01 = demux_q_01; assign RWL_DEC_ADD_01 = rwl_q_01;
    assign DEMUX_ADD_02 = demux_q_02; assign RWL_DEC_ADD_02 = rwl_q_02;
    assign DEMUX_ADD_03 = demux_q_03; assign RWL_DEC_ADD_03 = rwl_q_03;
    assign DEMUX_ADD_04 = demux_q_04; assign RWL_DEC_ADD_04 = rwl_q_04;
    assign DEMUX_ADD_05 = demux_q_05; assign RWL_DEC_ADD_05 = rwl_q_05;
    assign DEMUX_ADD_06 = demux_q_06; assign RWL_DEC_ADD_06 = rwl_q_06;
    assign DEMUX_ADD_07 = demux_q_07; assign RWL_DEC_ADD_07 = rwl_q_07;
    assign DEMUX_ADD_08 = demux_q_08; assign RWL_DEC_ADD_08 = rwl_q_08;
    assign DEMUX_ADD_09 = demux_q_09; assign RWL_DEC_ADD_09 = rwl_q_09;
    assign DEMUX_ADD_10 = demux_q_10; assign RWL_DEC_ADD_10 = rwl_q_10;
    assign DEMUX_ADD_11 = demux_q_11; assign RWL_DEC_ADD_11 = rwl_q_11;
    assign DEMUX_ADD_12 = demux_q_12; assign RWL_DEC_ADD_12 = rwl_q_12;
    assign DEMUX_ADD_13 = demux_q_13; assign RWL_DEC_ADD_13 = rwl_q_13;
    assign DEMUX_ADD_14 = demux_q_14; assign RWL_DEC_ADD_14 = rwl_q_14;
    assign DEMUX_ADD_15 = demux_q_15; assign RWL_DEC_ADD_15 = rwl_q_15;

    // 用寄存器回连到原 wire sbox_result_*（供原有 dat 组合逻辑使用）
    assign sbox_result_00 = sbox_q_00;
    assign sbox_result_01 = sbox_q_01;
    assign sbox_result_02 = sbox_q_02;
    assign sbox_result_03 = sbox_q_03;
    assign sbox_result_04 = sbox_q_04;
    assign sbox_result_05 = sbox_q_05;
    assign sbox_result_06 = sbox_q_06;
    assign sbox_result_07 = sbox_q_07;
    assign sbox_result_08 = sbox_q_08;
    assign sbox_result_09 = sbox_q_09;
    assign sbox_result_10 = sbox_q_10;
    assign sbox_result_11 = sbox_q_11;
    assign sbox_result_12 = sbox_q_12;
    assign sbox_result_13 = sbox_q_13;
    assign sbox_result_14 = sbox_q_14;
    assign sbox_result_15 = sbox_q_15;

endmodule
