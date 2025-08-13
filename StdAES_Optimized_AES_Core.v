//================================================ AES_Core
module StdAES_Optimized_AES_Core (din, dout, sel);

   //------------------------------------------------
   input  [127:0] din;
   input  [  1:0] sel;
   output [127:0] dout;
   
   //------------------------------------------------
   wire [31:0] st0, st1, st2, st3, // state
               sb0, sb1, sb2, sb3, // SubBytes
               sr0, sr1, sr2, sr3, // ShiftRows
               sc0, sc1, sc2, sc3, // MixColumns
               sk0, sk1, sk2, sk3; // AddRoundKey

   //------------------------------------------------
   // din -> state
   assign st0 = din[127:96];
   assign st1 = din[ 95:64];
   assign st2 = din[ 63:32];
   assign st3 = din[ 31: 0];

   // SubBytes
   // StdAES_Optimized_SubBytes SB0 (st0, sb0);
   // StdAES_Optimized_SubBytes SB1 (st1, sb1);
   // StdAES_Optimized_SubBytes SB2 (st2, sb2);
   // StdAES_Optimized_SubBytes SB3 (st3, sb3);

   // ShiftRows
   assign sr0 = {st0[31:24], st1[23:16], st2[15: 8], st3[ 7: 0]};
   assign sr1 = {st1[31:24], st2[23:16], st3[15: 8], st0[ 7: 0]};
   assign sr2 = {st2[31:24], st3[23:16], st0[15: 8], st1[ 7: 0]};
   assign sr3 = {st3[31:24], st0[23:16], st1[15: 8], st2[ 7: 0]};

   // MixColumns
   StdAES_Optimized_MixColumns MC0 (sr0, sc0);
   StdAES_Optimized_MixColumns MC1 (sr1, sc1);
   StdAES_Optimized_MixColumns MC2 (sr2, sc2);
   StdAES_Optimized_MixColumns MC3 (sr3, sc3);

   // AddRoundKey -- 00: first round; 10: last round; 1/11: other rounds
   assign sk0 = (sel == 2'b00) ? din[127:96] : (sel == 2'b10) ? sr0 : sc0 ;
   assign sk1 = (sel == 2'b00) ? din[ 95:64] : (sel == 2'b10) ? sr1 : sc1 ;
   assign sk2 = (sel == 2'b00) ? din[ 63:32] : (sel == 2'b10) ? sr2 : sc2 ;
   assign sk3 = (sel == 2'b00) ? din[ 31: 0] : (sel == 2'b10) ? sr3 : sc3 ;

   assign dout = kin ^ {sk0, sk1, sk2, sk3};

endmodule // AES_Core

