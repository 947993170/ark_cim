/*-------------------------------------------------------------------------
 AES (128-bit, StdAES_Optimized, encryption)
 
 File name   : StdAES_Optimized.v
 Version     : 1.0
 Created     : 06/02/2018
 Last update : 
 Desgined by : Kwen-Siong Chong
 
 Copyright (C) 2018 NTU  

 Some general information
 (1) Inputs: CLK, RSTn, EN, Kin, Din, KDrdy - 300 signals
 (2) Outputs: Dout, Kvd, Dvd, BSY - 131 signals
 (3) It takes 12 clock cycles to complete an encryption process
 (4) Kin and Din must be sampled together to perform the encryption process
 -------------------------------------------------------------------------*/
//`timescale 1 ns/1 ps 
module StdAES_Optimized
(
    //inputs
    input wire         CLK   , 
    input wire         RSTn  ,
    input wire         EN    , 
    input wire [127:0] Din   , 
    input wire         KDrdy ,   
    input wire [  7:0] RIO_00,
    input wire [  7:0] RIO_01,
    input wire [  7:0] RIO_02,
    input wire [  7:0] RIO_03,
    input wire [  7:0] RIO_04,
    input wire [  7:0] RIO_05,
    input wire [  7:0] RIO_06,
    input wire [  7:0] RIO_07,
    input wire [  7:0] RIO_10,
    input wire [  7:0] RIO_11,
    input wire [  7:0] RIO_12,
    input wire [  7:0] RIO_13,
    input wire [  7:0] RIO_14,
    input wire [  7:0] RIO_15,

    //outputs
    output wire [127:0] Dout          , 
    output reg          Kvld          , 
    output reg          Dvld          , 
    output reg          BSY           ,
    output wire [  2:0] DEMUX_ADD_00  ,
    output wire [  2:0] DEMUX_ADD_01  ,
    output wire [  2:0] DEMUX_ADD_02  ,
    output wire [  2:0] DEMUX_ADD_03  ,
    output wire [  2:0] DEMUX_ADD_04  ,
    output wire [  2:0] DEMUX_ADD_05  ,
    output wire [  2:0] DEMUX_ADD_06  ,           
    output wire [  2:0] DEMUX_ADD_07  ,
    output wire [  2:0] DEMUX_ADD_08  ,
    output wire [  2:0] DEMUX_ADD_09  ,
    output wire [  2:0] DEMUX_ADD_10  ,
    output wire [  2:0] DEMUX_ADD_11  ,
    output wire [  2:0] DEMUX_ADD_12  ,
    output wire [  2:0] DEMUX_ADD_13  ,
    output wire [  2:0] DEMUX_ADD_14  ,
    output wire [  2:0] DEMUX_ADD_15  ,
    output wire [  5:0] RWL_DEC_ADD_00,
    output wire [  5:0] RWL_DEC_ADD_01,
    output wire [  5:0] RWL_DEC_ADD_02,
    output wire [  5:0] RWL_DEC_ADD_03,
    output wire [  5:0] RWL_DEC_ADD_04,
    output wire [  5:0] RWL_DEC_ADD_05,
    output wire [  5:0] RWL_DEC_ADD_06,
    output wire [  5:0] RWL_DEC_ADD_07,
    output wire [  5:0] RWL_DEC_ADD_08,
    output wire [  5:0] RWL_DEC_ADD_09,
    output wire [  5:0] RWL_DEC_ADD_10,
    output wire [  5:0] RWL_DEC_ADD_11,
    output wire [  5:0] RWL_DEC_ADD_12,
    output wire [  5:0] RWL_DEC_ADD_13,
    output wire [  5:0] RWL_DEC_ADD_14,
    output wire [  5:0] RWL_DEC_ADD_15,
    output wire [ 15:0] IN
);

   //--Outputs declaration 
   output wire [127:0] Dout;  // Data output
   output reg          Kvld;  // Key  output valid
   output reg          Dvld;  // Data output valid 
   output reg          BSY;   // Busy signal

   output wire [ 2:0]  DEMUX_ADD_00;
   output wire [ 2:0]  DEMUX_ADD_01;
   output wire [ 2:0]  DEMUX_ADD_02;
   output wire [ 2:0]  DEMUX_ADD_03;
 
   output wire [ 2:0]  DEMUX_ADD_04;
   output wire [ 2:0]  DEMUX_ADD_05;
   output wire [ 2:0]  DEMUX_ADD_06;
   output wire [ 2:0]  DEMUX_ADD_07;
 
   output wire [ 2:0]  DEMUX_ADD_08;
   output wire [ 2:0]  DEMUX_ADD_09;
   output wire [ 2:0]  DEMUX_ADD_10;
   output wire [ 2:0]  DEMUX_ADD_11;
 
   output wire [ 2:0]  DEMUX_ADD_12;
   output wire [ 2:0]  DEMUX_ADD_13;
   output wire [ 2:0]  DEMUX_ADD_14;
   output wire [ 2:0]  DEMUX_ADD_15;

   output wire [ 5:0]  RWL_DEC_ADD_00;
   output wire [ 5:0]  RWL_DEC_ADD_01;
   output wire [ 5:0]  RWL_DEC_ADD_02;
   output wire [ 5:0]  RWL_DEC_ADD_03;
 
   output wire [ 5:0]  RWL_DEC_ADD_04;
   output wire [ 5:0]  RWL_DEC_ADD_05;
   output wire [ 5:0]  RWL_DEC_ADD_06;
   output wire [ 5:0]  RWL_DEC_ADD_07;
 
   output wire [ 5:0]  RWL_DEC_ADD_08;
   output wire [ 5:0]  RWL_DEC_ADD_09;
   output wire [ 5:0]  RWL_DEC_ADD_10;
   output wire [ 5:0]  RWL_DEC_ADD_11;
 
   output wire [ 5:0]  RWL_DEC_ADD_12;
   output wire [ 5:0]  RWL_DEC_ADD_13;
   output wire [ 5:0]  RWL_DEC_ADD_14;
   output wire [ 5:0]  RWL_DEC_ADD_15;
 

   //--Intermediate register signals declartion
   reg [127:0]    dat, rkey; 
   reg [127:0]    dat_dff;
   reg [3:0]      dcnt; //Counter
   reg [7:0]      rcon;
   reg [1:0]      sel;  // Indicate first, final round
   reg [3:0]      rcnt;
   
   wire [  7:0] sbox_result_00;
   wire [  7:0] sbox_result_01;
   wire [  7:0] sbox_result_02;
   wire [  7:0] sbox_result_03;

   wire [  7:0] sbox_result_04;
   wire [  7:0] sbox_result_05;
   wire [  7:0] sbox_result_06;
   wire [  7:0] sbox_result_07;

   wire [  7:0] sbox_result_08;
   wire [  7:0] sbox_result_09;
   wire [  7:0] sbox_result_10;
   wire [  7:0] sbox_result_11;

   wire [  7:0] sbox_result_12;
   wire [  7:0] sbox_result_13;
   wire [  7:0] sbox_result_14;
   wire [  7:0] sbox_result_15;

   reg [  7:0] sbox_addr_00;
   reg [  7:0] sbox_addr_01;
   reg [  7:0] sbox_addr_02;
   reg [  7:0] sbox_addr_03;

   reg [  7:0] sbox_addr_04;
   reg [  7:0] sbox_addr_05;
   reg [  7:0] sbox_addr_06;
   reg [  7:0] sbox_addr_07;

   reg [  7:0] sbox_addr_08;
   reg [  7:0] sbox_addr_09;
   reg [  7:0] sbox_addr_10;
   reg [  7:0] sbox_addr_11;

   reg [  7:0] sbox_addr_12;
   reg [  7:0] sbox_addr_13;
   reg [  7:0] sbox_addr_14;
   reg [  7:0] sbox_addr_15;

  //--Intermediate wire signals declartion    
   wire [127:0]   dat_next, rkey_next;
   wire           rst;

   //------------------------------------------------

   assign rst = ~RSTn;
     
    always @(posedge CLK or posedge rst) begin
        if (rst)     
            Dvld <=  0;
        else if (EN) 
            Dvld <=  (sel == 2'b10);
    end

    always @(posedge CLK or posedge rst) begin
        if (rst) 	   
            Kvld <=  0;
        else if (EN) 
            if (KDrdy) 
                Kvld <=  1;
            else  
                Kvld <=  0;              
    end
 
   always @(posedge CLK or posedge rst) begin
      if (rst) BSY <=  0;
      else if (EN) 
              if (KDrdy)
                   BSY <=  1;
              else if (dcnt == 0)
                        BSY <=  0;
                    else
                        BSY <=  BSY;
   end


   
   StdAES_Optimized_AES_Core aes_core 
     (.din((sel == 'd0) ? dat_dff : dat),  .dout(dat_next),  .kin(rkey), .sel(sel));

   StdAES_Optimized_KeyExpantion keyexpantion 
     (.kin(rkey), .kout(rkey_next), .rcon(rcon));

    // Counter to control the AES operation
    always @(posedge CLK or posedge rst) begin
        if (rst) 
            dcnt <=  4'hf;
        else if (EN) begin
            if (KDrdy) 
                dcnt <=  10;
            else if (dcnt < 12) 
                dcnt <=  dcnt - 1;
        end
    end
 
// Indicate the final round
    always @(posedge CLK or posedge rst) begin
        if (rst)     
            sel <=  0;
        else if (EN) 
            if (KDrdy)
                sel <=  0; //first round
            else if (dcnt == 1)
                sel <=  2; //last round
            else
                sel <=  1; //other rounds
   end

   always @(*) begin
      {
         sbox_addr_15,
         sbox_addr_14,
         sbox_addr_13,
         sbox_addr_12,
         sbox_addr_11,
         sbox_addr_10,
         sbox_addr_09,
         sbox_addr_08,
         sbox_addr_07,
         sbox_addr_06,
         sbox_addr_05,
         sbox_addr_04,
         sbox_addr_03,
         sbox_addr_02,
         sbox_addr_01,
         sbox_addr_00
      } =  dat_next;      
   end


   always @(*)  
	 if (rst) dat =  128'h55555555555555555555555555555555;
     else if (EN) 
         if (KDrdy) begin
            dat = Din;
         end else if (dcnt < 11)  begin
            dat =  {
               sbox_result_15,
               sbox_result_14,
               sbox_result_13,
               sbox_result_12,
               sbox_result_11,
               sbox_result_10,
               sbox_result_09,
               sbox_result_08,
               sbox_result_07,
               sbox_result_06,
               sbox_result_05,
               sbox_result_04,
               sbox_result_03,
               sbox_result_02,
               sbox_result_01,
               sbox_result_00
            };  
         end
 
   always @(posedge CLK) begin
      dat_dff <= dat;
   end

    //Critical Flip-flops - No Need to Reset   
    always @(posedge CLK) begin
        if (EN) begin
            if (KDrdy) begin                               
                rkey <=  Kin;
            end
        else if ((dcnt < 11) && (dcnt != 0)) begin                                           
                rkey <=  rkey_next;
        end
    end
  
    assign Dout = dat_next;


    assign DEMUX_ADD_00 = {1'b0,sbox_addr_00[7:6]};
    assign DEMUX_ADD_01 = {1'b0,sbox_addr_01[7:6]};
    assign DEMUX_ADD_02 = {1'b0,sbox_addr_02[7:6]};
    assign DEMUX_ADD_03 = {1'b0,sbox_addr_03[7:6]};
    assign DEMUX_ADD_04 = {1'b0,sbox_addr_04[7:6]};
    assign DEMUX_ADD_05 = {1'b0,sbox_addr_05[7:6]};
    assign DEMUX_ADD_06 = {1'b0,sbox_addr_06[7:6]};
    assign DEMUX_ADD_07 = {1'b0,sbox_addr_07[7:6]};
    assign DEMUX_ADD_08 = {1'b0,sbox_addr_08[7:6]};
    assign DEMUX_ADD_09 = {1'b0,sbox_addr_09[7:6]};
    assign DEMUX_ADD_10 = {1'b0,sbox_addr_10[7:6]};
    assign DEMUX_ADD_11 = {1'b0,sbox_addr_11[7:6]};
    assign DEMUX_ADD_12 = {1'b0,sbox_addr_12[7:6]};
    assign DEMUX_ADD_13 = {1'b0,sbox_addr_13[7:6]};
    assign DEMUX_ADD_14 = {1'b0,sbox_addr_14[7:6]};
    assign DEMUX_ADD_15 = {1'b0,sbox_addr_15[7:6]};

    assign RWL_DEC_ADD_00 = sbox_addr_00[5:0];
    assign RWL_DEC_ADD_01 = sbox_addr_01[5:0];
    assign RWL_DEC_ADD_02 = sbox_addr_02[5:0];
    assign RWL_DEC_ADD_03 = sbox_addr_03[5:0];
    assign RWL_DEC_ADD_04 = sbox_addr_04[5:0];
    assign RWL_DEC_ADD_05 = sbox_addr_05[5:0];
    assign RWL_DEC_ADD_06 = sbox_addr_06[5:0];
    assign RWL_DEC_ADD_07 = sbox_addr_07[5:0];
    assign RWL_DEC_ADD_08 = sbox_addr_08[5:0];
    assign RWL_DEC_ADD_09 = sbox_addr_09[5:0];
    assign RWL_DEC_ADD_10 = sbox_addr_10[5:0];
    assign RWL_DEC_ADD_11 = sbox_addr_11[5:0];
    assign RWL_DEC_ADD_12 = sbox_addr_12[5:0];
    assign RWL_DEC_ADD_13 = sbox_addr_13[5:0];
    assign RWL_DEC_ADD_14 = sbox_addr_14[5:0];
    assign RWL_DEC_ADD_15 = sbox_addr_15[5:0];



endmodule // AES_Composite_enc


















 

