module ALU (
	input [15:0]a,
	input [15:0]b,
	input [4:0]ctrl,
	output [15:0]out,
	output ovfl
);

wire ovfl_temp;
reg [15:0]out_temp;

wire [15:0]out_addsub;

assign out = out_temp;
assign sub = ctrl == 5'h1;

always begin
	out_temp = 16'b0;
	ovfl = 0;

	case (ctrl)
		5'h0,
		5'h1: begin
			out_temp = out_addsub;
			ovfl = ovfl_temp;
		end
		5'h2: out_temp = a & b;
		5'h3: out_temp = a | b;
		5'h4: out_temp = a ^ b;
		5'h5: out_temp = a << b[3:0];
		5'h6: out_temp = a >>> b[3:0];
		5'h8: out_temp = {a[15:8], b[7:0]};
		5'h9: out_temp = {b[7:0], a[7:0]};
	endcase
end


ADDSUB U_ADDSUB(
	.a(a),
	.b(sub ? -b : b),
	.sum(out_addsub),
	.ovl(ovfl_temp)
);

endmodule