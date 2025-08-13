module SubB (A, y);
				  
input  [7:0] A;
output [7:0] y;

wire [7:0] 	x;
wire [7:0] 	s;
assign x[7:0] = A[7:0];

   //------------------------------------------------
  // GF_MULINV_8 u3 (.x(x[31:24]), .y(s[31:24]));
   //GF_MULINV_8 u2 (.x(x[23:16]), .y(s[23:16]));
   //GF_MULINV_8 u1 (.x(x[15: 8]), .y(s[15: 8]));
   GF_MULINV_8 u0 (.x(x[ 7: 0]), .y(s[ 7: 0]));
 
  // assign y = {mat_at(s[31:24]), mat_at(s[23:16]), 
	//       mat_at(s[15: 8]), mat_at(s[ 7: 0])};
    
assign y = {mat_at(s[ 7: 0])};

   //------------------------------------------------ Affine matrix
   function [7:0] mat_at;
      input [7:0] x;
      begin
	 mat_at[0] = ~(x[7] ^ x[6] ^ x[5] ^ x[4] ^ x[0]);
	 mat_at[1] = ~(x[7] ^ x[6] ^ x[5] ^ x[1] ^ x[0]);
	 mat_at[2] =   x[7] ^ x[6] ^ x[2] ^ x[1] ^ x[0];
	 mat_at[3] =   x[7] ^ x[3] ^ x[2] ^ x[1] ^ x[0];
	 mat_at[4] =   x[4] ^ x[3] ^ x[2] ^ x[1] ^ x[0];
	 mat_at[5] = ~(x[5] ^ x[4] ^ x[3] ^ x[2] ^ x[1]);
	 mat_at[6] = ~(x[6] ^ x[5] ^ x[4] ^ x[3] ^ x[2]);
	 mat_at[7] =   x[7] ^ x[6] ^ x[5] ^ x[4] ^ x[3];
      end
   endfunction


endmodule

