/* fetchdecode.sv
 * This module forms the first stage of the cpu, a combination of the fetch and
 * decode stages of a 5-stage pipeline. It interacts with Block Memory to fetch
 * instructions, and of course the next stage, execute. To the execute phase,
 * this phase passes the fetched instruction as well as the register data. 
 *
 * This phase also expects values in return from both EX and MEM/WB. From EX,
 * it expects the NVZ values of the current instruction. From MEM/WB, it
 * expects a few signals to describe if and how writeback should be done.
 *
 * @input iWriteBack is whether or not to write back data.
 * @input iWriteBackReg is the register to write back to.
 * @input iWriteBackData is the data to write.
 * @input iNVZ is the output of the flag register in the EX phase.
 * @output oInstrAddr is the address of the instruction to fetch. AKA the PC.
 * @output oData1 is the contents of the first source register.
 * @output oData2 is the contents of the second source register.
 * @output oImm is the sign-extended immediate value
 */
module fetchdecode(iclk, irst_n, iWriteReg, iWriteRegAddr, iWriteRegData,
	iMemtoReg, iBustoReg, iNVZ, oData1, oData2, oImm, oWriteReg, oWriteRegAddr,
	oMemtoReg, oBustoReg, oMemRead, oMemWrite, oBusWrite, oOpcode, oALUSrc, oSr1, oSr2);

localparam Branch = 5'b01000;
localparam BranchRegister = 5'b01001;
localparam ImmL = 5'b01000;
localparam ImmH = 5'b01001;
localparam Load = 5'b01010;
localparam Store = 5'b01011;
localparam DbLoad = 5'b01100;
localparam DbStore = 5'b01101;

input iclk, irst_n;

reg [15:0] PC;

// BMem interface
wire [23:0] instr;
wire [15:0] instrAddr;

// Writeback, from MEM/WB phase
input iWriteReg;
input iMemtoReg;
input iBustoReg;
input [3:0] iWriteRegAddr;
input [15:0] iWriteRegData;

// Condition codes, from EX phase
input [2:0] iNVZ;

// Register Data
output reg [15:0] oData1, oData2;

output reg [4:0] oOpcode;

// Register Imm
output reg [15:0] oImm;

output reg [3:0] oSr1, oSr2;

output reg oMemtoReg;
output reg oBustoReg;
output reg oMemRead;
output reg oMemWrite;
output reg oBusWrite;
output reg oALUSrc;

// WriteBack registers for execute stage
output reg oWriteReg;
output reg [3:0] oWriteRegAddr;

// Instruction components. Immediate is not used here.
wire [4:0] opcode = instr[4:0];
wire [3:0] sr1 = instr[12:9];
wire [3:0] sr2 = instr[16:13];
wire [2:0] condition = instr[23:21];

// Register File
reg [15:0] registers [15:0];

// Evaluate condition result based on NVZ and current code.
wire conditionResult;
wire branch = opcode == Branch;
CCodeEval cce(.C(condition), .NVZ(iNVZ), .cond_true(conditionResult));

// Instruction memory
wire [15:0] branchAddr = PC + {instr[20:13], {8{instr[13]}}} + 1;
wire [15:0] next_PC = branch ? branchAddr: PC + 1;
rom imem(.address(next_PC), .clk(iclk), .q(instr));

// PC register
always @(posedge iclk or negedge irst_n)
	if (!irst_n) begin
		PC <= 0;
		oImm <= 0;
		oData1 <= 0;
		oData2 <= 0;
		oOpcode <= 0;
	end
	else begin
		PC <= next_PC;
		oImm <= (opcode == ImmL) ? {{8{1'b0}}, instr[20:13]} : ((opcode == ImmH) ? {instr[20:13], {8{1'b0}}} : 16'h0);
		oData1 <= registers[sr1];
		oData2 <= registers[sr2];
		oOpcode <= opcode;
		oSr1 <= sr1;
		oSr2 <= sr2;
	end

assign oInstrAddr = PC;

always @(posedge iclk or negedge irst_n)
	if(!irst_n) 
	begin
		oWriteReg <= 0;
		oWriteRegAddr <= 0;
		oMemtoReg <= 0;
		oBustoReg <= 0;
		oBusWrite <= 0;
		oMemRead <= 0;
		oMemWrite <= 0;
		oALUSrc <= 0;
	end
	else 
	begin
		oWriteReg <= (opcode == Store) ? 0 : 1;
		oWriteRegAddr <= (opcode == Store) ? 0 : instr[8:5];
		oMemtoReg <= (opcode == Load) ? 1 : 0;
		oBustoReg <= (opcode == DbLoad) ? 1 : 0;
		oBusWrite <= (opcode == DbStore) ? 1 : 0; 
		oMemRead <= (opcode == Load) ? 1 : 0;
		oMemWrite <= (opcode == Store) ? 1 : 0;
		case(opcode)
			Load: oALUSrc <= 1;
			Store: oALUSrc <= 1;
			DbLoad: oALUSrc <= 1;
			DbStore: oALUSrc <= 1;
			default: oALUSrc <= 0;	
		endcase
	end

always @(posedge iclk or negedge irst_n)
	if (!irst_n)
		registers <= '{default:0};
	else 
	begin
		if (iWriteReg | iMemtoReg | iBustoReg)
			registers[iWriteRegAddr] <= iWriteRegData;
	end

endmodule