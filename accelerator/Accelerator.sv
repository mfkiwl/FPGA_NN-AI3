
module Accelerator (
	input clk,
	input reset,
	input [15:0] [15:0] SDRAM_FIFO_in,
	input [15:0] data_bus,
	input [15:0][15:0] BRAM_data,
	input busrdwr,
	input CPUEnable,
	input DVAL,
	output [15:0] BRAM_Addr_In,
	output [15:0] output_neuron,
	output [15:0] out_addr_current,
	output Rd_BRAM_current,
	//output Wr_BRAM_current,
	output SRAM_RdReq,
	output cpu_neuron_done
);

wire [15:0] Weight_data_current;
Accelerator_FSM FSM1(
	.clk(clk), 
	.rst(reset),
	.SDRAM_FIFO(SDRAM_FIFO_in), 
	.databus(data_bus), 
	.DVAL(DVAL),
	.Enable(CPUEnable),
	.busrdwr(busrdwr),
	.Inaddress_current(BRAM_Addr_In),
	.Weight_data_current(Weight_data_current),
	.neuron_done(neuron_done),
	.Rd_BRAM_current(Rd_BRAM_current),
	//.Wr_BRAM_current(Wr_BRAM_current),
	.out_addr_current(out_addr_current),
	.PE_enable(PE_enable),
	.SRAM_read_req_current(SRAM_RdReq),
	.add_done(add_done)
);


wire [15:0] accum_sum, partial_sum;
parallel_mult pm0(.clk(clk), .rst (reset), .input_neuron(BRAM_data), .weight_bits(Weight_data_current), .en(PE_enable), .FinalOut(partial_sum));
accumulation_register ar0(.clk(clk), .reset(reset), .partial_sum(partial_sum), .add_done(add_done), .neuron_done(neuron_done), .new_sum(accum_sum));
relu relu0(.clk(clk), .rst(reset), .neuron_done(neuron_done), .neuron(accum_sum), .out(output_neuron), .cpu_neuron_done(cpu_neuron_done));


endmodule
