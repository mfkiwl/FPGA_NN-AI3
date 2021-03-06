
module Accelerator_FSM(
	input clk,
	input rst,
	//input [15:0] DRAM_DATA,
	input [15:0][15:0] SDRAM_FIFO,
	//input [15:0] BaseAddr_in,
	//input [15:0] total_output_neurons,
	//input [15:0] total_input_neurons,
	input [15:0] databus,
	input DVAL,
	//input accelerator_start, 
	input Enable,
	input busrdwr,
	output [15:0] Inaddress_current,
	output [15:0] Weight_data_current,
	output neuron_done,
	output add_done,
	output Rd_BRAM_current,
	output Wr_BRAM_current,
	output [15:0] out_addr_current,
	output PE_enable,
	output SRAM_read_req_current,
	output FIFO_read_req_current
    );


 
	reg neuron_done_reg ;
	reg PE_enable_reg;
	reg add_done_reg;
	reg SRAM_read_req, Rd_BRAM, Wr_BRAM, FIFO_read_req;
	reg [5:0] Number_of_MAC_done;
	reg [9:0] Number_of_neurons_done;
	reg [15:0] InAddress, WeightAddr, OutputAddress, total_input_neurons, total_output_neurons, BaseInAddress;
	reg [2:0] state;
	reg [4:0] counter_SRAM_read_req;
	reg [3:0] FIFO_read_index;
	reg[4:0] num_of_addition;
	reg[2:0] count_databus;
	reg [15:0] Weight_data;
	parameter IDLE = 3'b000;
	//parameter WAIT = 3'b001;
	//parameter ReadDataBus = 3'b010;
	parameter ReadDataBus = 3'b001;
	parameter WAITFORDVAL = 3'b010;
	parameter Multiplication = 3'b011;
	parameter Addition = 3'b100;
	parameter UpdateCounters = 3'b101;

	
	parameter size_of_PE = 5'h10; /// we have 16 parallel  multipliers


always @ (posedge clk)

begin
if (!rst)
	begin
	state <= IDLE;
	Number_of_MAC_done <= 0;
	Number_of_neurons_done <= 0;
	num_of_addition <=0;
	counter_SRAM_read_req <= 0;
	SRAM_read_req <= 0;
	FIFO_read_req <= 0;
	Rd_BRAM <= 0;
	Wr_BRAM<=0;
	PE_enable_reg <= 0;
	add_done_reg <= 0;
	end


case (state)
IDLE:
begin
if (Enable)
begin
    	state = ReadDataBus;
	//state <= WAIT ;
	neuron_done_reg <=0;
	count_databus <=0;
	Wr_BRAM <= 0;
	Rd_BRAM <= 0;
	FIFO_read_index <= 0;
	FIFO_read_req <= 0;
	SRAM_read_req <= 0;
	
end
else 
begin
	state <= IDLE;
	neuron_done_reg <= 0;
	Wr_BRAM <= 0;
	Rd_BRAM <= 0;
	FIFO_read_index <= 0;
	FIFO_read_req <= 0;
	SRAM_read_req <= 0;
end
end

ReadDataBus:
begin
if(busrdwr)
	begin
		case (count_databus)
			3'b000: 
			begin
				InAddress <= databus;
				BaseInAddress <= databus;
				count_databus <= count_databus+1;
				state <= ReadDataBus;
			end
			3'b001: 
			begin
				WeightAddr <= databus;
				count_databus <= count_databus+1;
				state <= ReadDataBus;
			end
			3'b010: 
			begin
				OutputAddress <= databus -1;
				count_databus <= count_databus+1;
				state <= ReadDataBus;
			end
			3'b011: 
			begin
				total_input_neurons <= databus;
				count_databus <= count_databus+1;
				state <= ReadDataBus;
			end
			3'b100: 
			begin
				total_output_neurons <= databus;
				count_databus <= 0;
				state <= WAITFORDVAL;
				SRAM_read_req <=1;
			end
		endcase
	end
else
begin
	if(count_databus < 3'b101)
		state = ReadDataBus;
end
end


/*WAIT:
begin
if (accelerator_start)
begin
	state <= SetAddress ;
end
else 
begin
	state <= WAIT;
end



end

//////////////////
SetAddress:
begin
    InAddress <= BaseAddr_in;
    state <= WAITFORDVAL;
    neuron_done_reg <= 0;
end
*/

WAITFORDVAL:
begin
	if (DVAL)
	begin
		state <= Multiplication;
		Rd_BRAM <= 1;
		SRAM_read_req <= 0;

	end
	else
	begin
		state <= WAITFORDVAL;
		Rd_BRAM <= 0;
		SRAM_read_req <= 0;
		neuron_done_reg <= 0;
	end
end




Multiplication:
begin
	Rd_BRAM <= 0;
	SRAM_read_req <= 0;
	counter_SRAM_read_req <= counter_SRAM_read_req+1;
	neuron_done_reg <= 0;
	if (counter_SRAM_read_req <17)
	begin
		FIFO_read_req <=1;
		FIFO_read_index <= counter_SRAM_read_req -1;
		Weight_data <= 16'h000 + counter_SRAM_read_req; //SDRAM_FIFO[FIFO_read_index];
		state <= Multiplication;
		neuron_done_reg <= 0;
		PE_enable_reg <= 1;
	end
	else
	begin 
		SRAM_read_req <= 0;
		FIFO_read_req <=0 ;
		counter_SRAM_read_req <= 0;
		FIFO_read_index <= 0;
		state <= Addition;
		InAddress <= InAddress + 16;	
		neuron_done_reg <= 0;
		PE_enable_reg <= 1;
	end
end



Addition:
begin
	Rd_BRAM <= 0;
	state <= UpdateCounters;
	add_done_reg <= 1;
	neuron_done_reg <= 0;
	//num_of_addition <= num_of_addition +1;
	//if (num_of_addition ==5)
	//begin
	//	state <= UpdateCounters;
	//	neuron_done_reg <= 0;
	//	num_of_addition <= 0;
	//	add_done_reg <= 1'b1;
	//end
	//else
	//begin
	//	state <= Addition;
	//	neuron_done_reg <= 0;
	//	add_done_reg <= 0;
	//end
end
	
//////////////


UpdateCounters:
begin
	Number_of_MAC_done <= Number_of_MAC_done +1;
	Wr_BRAM <= 0;
	add_done_reg <= 0;
	if (Number_of_MAC_done == (total_input_neurons/size_of_PE)-1)
	begin
		neuron_done_reg <=1;
		Wr_BRAM <= 1;
		InAddress <= BaseInAddress;
		OutputAddress <= OutputAddress +1;
		Number_of_MAC_done <=0;
		Number_of_neurons_done <= Number_of_neurons_done +1;
		if (Number_of_neurons_done == total_output_neurons -1)
		begin
			Number_of_neurons_done<=0;	
			state <=IDLE;
		end
		else
		begin
			state <= WAITFORDVAL;
			Wr_BRAM <= 0;
		end
	end
	else
		begin
		state <= WAITFORDVAL;
		SRAM_read_req <= 0;

	end
end

endcase
end

assign neuron_done =  neuron_done_reg;
assign add_done = add_done_reg;
assign Inaddress_current= InAddress;
assign Weight_data_current = Weight_data;
assign PE_enable = PE_enable_reg;//(state == Addition | Multiplication);
assign SRAM_read_req_current = SRAM_read_req;
assign FIFO_read_req_current = FIFO_read_req;
assign Rd_BRAM_current = Rd_BRAM;
assign Wr_BRAM_current = Wr_BRAM;
assign out_addr_current = OutputAddress;

endmodule