//////////////////////////////////////////////////////////////////////////////////
// 
// Author 			:	Praveen Kumar Pendyala
// **Modified the code from HW example for SIRC from MSR written bu Ken Eguro
//
// Create Date		:  05/27/13
// Modify Date		:	06/05/13
// Module Name		:  simpleTestModuleOne 
// Project Name	: 	SIRC_HW
// Target Devices	: 	Xilinx Vertix 5, XUPV5 110T
// Tool versions	: 	13.2 ISE
//
// Description: 
//	This module receives 32 bytes of challenges A, B from PC by reading memory, Loads them into 16 8-bit registers, sends the 32 bit response back to PC by writing back to memory
//
//	Bugs :
//	- While writing back to memory the first element is written twice (i.e., to memory addresses 0 and 1). Temporarily fix by writing 1 extra bit and also reading 1 extra but in software.
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps
`default_nettype none

//This module demonstrates how a user can read from the parameter register file,
//	read from the input memory buffer, and write to the output memory buffer.
//We also show the basics of how the user's circuit should interact with
// userRunValue and userRunClear.
module simpleTestModuleOne #(
	//************ Input and output block memory parameters
	//The user's circuit communicates with the input and output memories as N-byte chunks
	//This should be some power of 2 >= 1.
	parameter INMEM_BYTE_WIDTH = 1,
	parameter OUTMEM_BYTE_WIDTH = 1,
	
	//How many N-byte words does the user's circuit use?
	parameter INMEM_ADDRESS_WIDTH = 17,
	parameter OUTMEM_ADDRESS_WIDTH = 13
)(
	input		wire 					clk,
	input		wire 					reset,
																														//A user application can only check the status of the run register and reset it to zero
	input		wire 					userRunValue,																//Read run register value
	output	reg					userRunClear,																//Reset run register
	
	//Parameter register file connections
	output 	reg															register32CmdReq,					//Parameter register handshaking request signal - assert to perform read or write
	input		wire 															register32CmdAck,					//Parameter register handshaking acknowledgment signal - when the req and ack ar both true fore 1 clock cycle, the request has been accepted
	output 	wire 		[31:0]											register32WriteData,				//Parameter register write data
	output 	reg		[7:0]												register32Address,				//Parameter register address
	output	wire 															register32WriteEn,				//When we put in a request command, are we doing a read or write?
	input 	wire 															register32ReadDataValid,		//After a read request is accepted, this line indicates that the read has returned and that the data is ready
	input 	wire 		[31:0]											register32ReadData,				//Parameter register read data

	//Input memory connections
	output 	reg															inputMemoryReadReq,				//Input memory handshaking request signal - assert to begin a read request
	input		wire 															inputMemoryReadAck,				//Input memory handshaking acknowledgement signal - when the req and ack are both true for 1 clock cycle, the request has been accepted
	output	reg		[(INMEM_ADDRESS_WIDTH - 1):0] 			inputMemoryReadAdd,				//Input memory read address - can be set the same cycle that the req line is asserted
	input 	wire 															inputMemoryReadDataValid,		//After a read request is accepted, this line indicates that the read has returned and that the data is ready
	input		wire 		[((INMEM_BYTE_WIDTH * 8) - 1):0] 		inputMemoryReadData,				//Input memory read data
	
	//Output memory connections
	output 	reg															outputMemoryWriteReq,			//Output memory handshaking request signal - assert to begin a write request
	input 	wire 															outputMemoryWriteAck,			//Output memory handshaking acknowledgement signal - when the req and ack are both true for 1 clock cycle, the request has been accepted
	output	reg		[(OUTMEM_ADDRESS_WIDTH - 1):0] 			outputMemoryWriteAdd,			//Output memory write address - can be set the same cycle that the req line is asserted
	output	reg		[((OUTMEM_BYTE_WIDTH * 8) - 1):0]		outputMemoryWriteData,			//Output memory write data
	output 	wire 		[(OUTMEM_BYTE_WIDTH - 1):0]				outputMemoryWriteByteMask,		//Allows byte-wise writes when multibyte words are used - each of the OUTMEM_USER_BYTE_WIDTH line can be 0 (do not write byte) or 1 (write byte)

	//8 optional LEDs for visual feedback & debugging
	output	reg 		[7:0]												LED,
	
	//Connection to the PUF pins
	input		wire	PH1,			//Phase clock 1
	input		wire	PH2,			//Phase clock 2

	//Notation :: SO = Serial Output, SI = Serial Input, CA	= Challenge A, CB =	Challege B
	output		wire	SO_not_Up,
	output		wire	SO_Up,
	output		wire	SO_not_Down,
	output		wire 	SO_Down,
	
	//We may not use these outputs but they are given in scanchain
	output		wire	CAout,
	output		wire	CBout,
	
	input		wire	CA_SI,
	input		wire 	CB_SI,
	input		wire	OutEn,				//Assert this to take outputs serially
	input		wire	Ph_En,				//Assert this to give inputs serially
	input		wire 	Trig,					//Trigger - On asserting this the output generation starts
	
	//We may not use these inputs too
	input		wire	SO_not_Up_In,		//Input of upper scan chain for Serial out not
	input		wire	SO_Up_In,			//Input of upper scan chain for Serial out
	input		wire	SO_not_Down_In,		//Input of lower scan chain for Serial out not
	input		wire	SO_Down_In			//Input of lower scan chain for Serial out
);
	//FSM states
	localparam  IDLE = 0;							// Waiting
	localparam  READING_IN_PARAMETERS = 1;	// Get values from the reg32 parameters
	localparam  READ = 2;							// Run (read from input, compute and write to output)
	localparam  WAIT_READ = 3;
	localparam  COMPUTE = 4;
	localparam  WRITE = 5;

	//Signal declarations
	//State registers
	reg [2:0] currState;
	
	//Challenge and Response holding registers as 2D matrices
	reg	[7:0]	challengeA [0:15];
	reg	[7:0]	challengeB [0:15];
	reg	[7:0]	responseTop [0:15];
	reg 	[7:0]	responseBottom [0:15];
	reg	[7:0]	responseTopNot [0:15];
	reg 	[7:0]	responseBottomNot [0:15];

	//Challenge and Response holding variables as a single dimensional 128 bit arrays
	//Above ofcourse can be avoided by appropriate conditions while reading inputs or sending outputs
	//We use this because verilog doesn't support passing multidimensional arrays to other modules
	wire [127:0]	challengeAReg;
	wire [127:0] 	challengeBReg;
	wire [127:0]	responseTopReg;
	wire [127:0]	responseBottomReg;
	wire [127:0]	responseTopNotReg;
	wire [127:0]	responseBottomNotReg;
	
	//Flattening 2D arrays to 1D
	//Endianness has been adjusted in other modules and/or while building reponse 2D array
	assign challengeAReg = {
		challengeA[15],challengeA[14],challengeA[13],challengeA[12],challengeA[11],challengeA[10],challengeA[9],challengeA[8],
		challengeA[7],challengeA[6],challengeA[5],challengeA[4],challengeA[3],challengeA[2],challengeA[1],challengeA[0]};
	assign challengeBReg = {
		challengeB[15],challengeB[14],challengeB[13],challengeB[12],challengeB[11],challengeB[10],challengeB[9],challengeB[8],
		challengeB[7],challengeB[6],challengeB[5],challengeB[4],challengeB[3],challengeB[2],challengeB[1],challengeB[0]};

	//Counter
	reg paramCount;
	
	//Message parameters
	reg [31:0] length;
	reg [31:0] multiplier;

	wire [31:0] lengthMinus1;
	assign lengthMinus1 = length - 1;

	// We don't write to the register file and we only write whole bytes to the output memory
	assign register32WriteData = 32'd0;
	assign register32WriteEn = 0;
	assign outputMemoryWriteByteMask = {OUTMEM_BYTE_WIDTH{1'b1}};
	
	//Variables for execution
	reg inputDone;
	reg [5:0] memCount;	//Will be used while reading from memory to 128 bit challenge regs. Similarly while writing back from response regs
	reg [4:0] regCount;
	reg [7:0] bitCount;
	
	//PUF execution variables
	reg PUFExStart;
	wire PUFExDone;


	initial begin
		currState = IDLE;
		length = 0;
		
		userRunClear = 0;
		
		register32Address = 0;
		
		inputMemoryReadReq = 0;
		inputMemoryReadAdd = 0;
	
		outputMemoryWriteReq = 0;
		outputMemoryWriteAdd = 0;
		outputMemoryWriteData = 0;
		
		paramCount = 0;
		
		inputDone = 0;
	end
	
	//Endianness has been adjusted in other modules and/or while building challenge 1D array
	always @(*) begin
		{
		responseTop[15],responseTop[14],responseTop[13],responseTop[12],responseTop[11],responseTop[10],responseTop[9],responseTop[8],
		responseTop[7],responseTop[6],responseTop[5],responseTop[4],responseTop[3],responseTop[2],responseTop[1],responseTop[0]} <= responseTopReg;
		{
		responseTopNot[15],responseTopNot[14],responseTopNot[13],responseTopNot[12],responseTopNot[11],responseTopNot[10],responseTopNot[9],responseTopNot[8],
		responseTopNot[7],responseTopNot[6],responseTopNot[5],responseTopNot[4],responseTopNot[3],responseTopNot[2],responseTopNot[1],responseTopNot[0]} <= responseTopNotReg;
		{
		responseBottom[15],responseBottom[14],responseBottom[13],responseBottom[12],responseBottom[11],responseBottom[10],responseBottom[9],responseBottom[8],
		responseBottom[7],responseBottom[6],responseBottom[5],responseBottom[4],responseBottom[3],responseBottom[2],responseBottom[1],responseBottom[0]} <= responseBottomReg;
		{
		responseBottomNot[15],responseBottomNot[14],responseBottomNot[13],responseBottomNot[12],responseBottomNot[11],responseBottomNot[10],responseBottomNot[9],responseBottomNot[8],
		responseBottomNot[7],responseBottomNot[6],responseBottomNot[5],responseBottomNot[4],responseBottomNot[3],responseBottomNot[2],responseBottomNot[1],responseBottomNot[0]} <= responseBottomNotReg;
	end

	always @(posedge clk) begin
		if(reset) begin
			currState <= IDLE;
			length <= 0;
			
			userRunClear <= 0;
			
			register32Address <= 0;
			
			inputMemoryReadReq <= 0;
			inputMemoryReadAdd <= 0;
			
			outputMemoryWriteReq <= 0;
			outputMemoryWriteAdd <= 0;
			outputMemoryWriteData <= 0;
			
			paramCount <= 0;
			
			inputDone <= 0;
			
		end
		else begin
			case(currState)
				IDLE: begin
					//Stop trying to clear the userRunRegister
					userRunClear <= 0;
					inputMemoryReadReq <= 0;
					LED <= 8'b00000000;
					
					//Wait till the run register goes high
					if(userRunValue == 1 && userRunClear != 1) begin
						//Start reading from the register file
						currState <= READING_IN_PARAMETERS;
						register32Address <= 0;
						register32CmdReq <= 1;
						paramCount <= 0;
					end
				end
				READING_IN_PARAMETERS: begin
					//We need to read 2 values from the parameter register file.
					//If the register file accepted the read, increment the address
					if(register32CmdAck == 1 && register32CmdReq == 1) begin
						register32Address <= register32Address + 1;
					end
					
					//If we just accepted a read from address 1, stop requesting reads
					if(register32CmdAck == 1 && register32Address == 8'd1)begin
						register32CmdReq <= 0;
					end
	
					//If a read came back, shift in the value from the register file
					if(register32ReadDataValid) begin
							length <= multiplier;
							multiplier <= register32ReadData;
							paramCount <= 1;
							
							//The above block act as a shift register for length and multiplier (though not required) params
							if(paramCount == 1)begin
								//Start requesting input data and execution
								currState <= READ;
								inputMemoryReadReq <= 1;
								inputMemoryReadAdd <= 0;
								outputMemoryWriteAdd <= 0;
								inputDone <= 0;
								memCount <= 0;
							end
					end
				end
				READ: begin
					//Read for length of length obtained from params
					if(inputDone == 0) begin
						inputMemoryReadReq <= 1;
					end
					else begin
						inputMemoryReadReq <= 0;
					end
					
					//If the input memory accepted the last read, we can increment the address
					if(inputMemoryReadReq == 1 && inputMemoryReadAck == 1 && inputMemoryReadAdd != lengthMinus1[(INMEM_ADDRESS_WIDTH - 1):0])begin
						inputMemoryReadAdd <= inputMemoryReadAdd + 1;
						currState <= WAIT_READ;
					end
					else if(inputMemoryReadReq == 1 && inputMemoryReadAck == 1 && inputMemoryReadAdd == lengthMinus1[(INMEM_ADDRESS_WIDTH - 1):0])begin
						inputDone <= 1;
						LED[0] <= 1;
						currState <= WAIT_READ;
					end	
				end
				
				WAIT_READ: begin
					if (inputMemoryReadDataValid == 1) begin

						if(memCount <= 15) begin
							challengeA[memCount] <= inputMemoryReadData;
							memCount <= memCount+1;
							currState <= READ;
						end
						else if(memCount <= 31) begin
							challengeB[memCount-16] <= inputMemoryReadData;
							memCount <= memCount+1;
							currState <= READ;
						end
						else begin
							currState <= COMPUTE;
							regCount <= 0;
							bitCount <= 0;
						end	
					end				
				end
				
				COMPUTE: begin
					/*if(regCount <= 15) begin
						responseTop[regCount] <= challengeA[regCount] | challengeB[regCount];
						responseBottom[regCount] <= challengeA[regCount] & challengeB[regCount];
						regCount <= regCount+1;
					end
					else begin
						currState <= WRITE;
						memCount <= 0;
						outputMemoryWriteAdd <= 0;
					end*/
					
					PUFExStart <= 1;
					if(PUFExDone == 1) begin
						currState <= WRITE;
						memCount <= 0;
						outputMemoryWriteAdd <= 0;
					end
					
				end
				
				WRITE: begin
					outputMemoryWriteReq <= 1;
						
					if(outputMemoryWriteAdd <= 15) begin
						outputMemoryWriteData <= responseTop[outputMemoryWriteAdd];
					end
					else if(outputMemoryWriteAdd <= 31) begin
						outputMemoryWriteData <= responseBottom[outputMemoryWriteAdd-16];
					end

					//If we just wrote a value to the output memory this cycle, increment the address
					//NOTE : Due to bug described above we write on bit more by using length instead of lengthMinus1
					if(outputMemoryWriteReq == 1  && outputMemoryWriteAck == 1 && outputMemoryWriteAdd != length[(OUTMEM_ADDRESS_WIDTH - 1):0]) begin
						outputMemoryWriteAdd <= outputMemoryWriteAdd + 1;
						memCount <= memCount+1;
						currState <= WRITE;
					end	

					//Stop writing and go back to IDLE state if writing reached length of data
					if(outputMemoryWriteReq == 1  && outputMemoryWriteAck == 1 && outputMemoryWriteAdd == length[(OUTMEM_ADDRESS_WIDTH - 1):0]) begin
						outputMemoryWriteReq <= 0;
						currState <= IDLE;
						userRunClear <= 1;
					end				
				end				
				
			endcase
		end
   end
	
	//Serial transmit receive module
	serialTransmitReceive str(
		.clk(clk),
		.challengeA(challengeAReg),
		.challengeB(challengeBReg),
		.ExStart(PUFExStart),
		.ExDone(PUFExDone),
		.responseUp(responseTopReg),
		.responseUpNot(responseTopNotReg),
		.responseDown(responseBottomReg),
		.responseDownNot(responseBottomNotReg)
	);
	
endmodule
