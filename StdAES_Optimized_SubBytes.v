module StdAES_Optimized_SubBytes(x, y );
   //------------------------------------------------
   
	input [31:0] x;
	output [31:0] y;

SubB U1 (.A(x[7:0]),   .y(y[7:0]));
SubB U2 (.A(x[15:8]),  .y(y[15:8]));
SubB U3 (.A(x[23:16]), .y(y[23:16]));
SubB U4 (.A(x[31:24]), .y(y[31:24]));

endmodule
