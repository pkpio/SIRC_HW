`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Author 			:	Praveen Kumar Pendyala
// 
// Create Date		:  17:33:15 06/03/2013 
// Modify Date		:	06/05/2013
// Module Name		:  serialTransmitReceive 
// Project Name	: 	SIRC_HW
// Target Devices	: 	Xilinx Vertix 5, XUPV5 110T
// Tool versions	: 	13.2 ISE
// Description		: 
//	This module takes care of all the serial transmit receive protocals required
//	to be followed for the current PUF. It just needs challenges and a ExStart signal to start execution
//////////////////////////////////////////////////////////////////////////////////

module serialTransmitReceive(
	input		wire			clk,
	input		wire [127:0]	challengeA,
	input		wire [127:0]	challengeB,
	
	//Execution start - Starts the serial transmit, wait, execute and serial receive on issuing this signal in that order
	input		wire			ExStart,
	
	//Asserted when the above process has been completed
	output	wire			ExDone,
	
	output	wire [127:0]	responseUp,
	output	wire [127:0]	responseUpNot,
	output	wire [127:0]	responseDown,
	output	wire [127:0]	responseDownNot,
	
	
	//Connections to PUF pins
	output		wire	PH1,			//Phase clock 1
	output		wire	PH2,			//Phase clock 2

	//Notation :: SO = Serial Output, SI = Serial Input, CA	= Challenge A, CB =	Challege B
	input		wire	SO_not_Up,
	input		wire	SO_Up,
	input		wire	SO_not_Down,
	input		wire 	SO_Down,
	
	//We may not use these outputs but they are given in scanchain
	input		wire	CAout,
	input		wire	CBout,
	
	output		wire	CA_SI,
	output		wire 	CB_SI,
	output		wire	OutEn,				//Assert this to take outputs serially
	output		wire	Ph_En,				//Assert this to give inputs serially
	output		wire 	Trig,					//Trigger - On asserting this the output generation starts
	
	//We may not use these inputs too
	output		wire	SO_not_Up_In,		//Input of upper scan chain for Serial out not
	output		wire	SO_Up_In,			//Input of upper scan chain for Serial out
	output		wire	SO_not_Down_In,		//Input of lower scan chain for Serial out not
	output		wire	SO_Down_In			//Input of lower scan chain for Serial out
	);
	
	//FSM states
	localparam IDLE = 0;		//Waiting
	localparam SEND = 1;		//Sending data to PUF serially. Starts after waiting for 5 clocks initially
	localparam EXECUTE = 2;	//Signals data execution to PUF
	localparam RECEIVE = 3;	//Receiving data from PUF serially

	//State register
	reg [1:0] currState;
	
	//Entire process complete indicator register (for ExDone) and regs for responses (since ports are required to be NETs)
	reg ExDoneReg;
	reg [127:0]	responseUpReg;
	reg [127:0]	responseUpNotReg;
	reg [127:0]	responseDownReg;
	reg [127:0]	responseDownNotReg;
		
	//Other PUF required variables
	//Phase delayed clocks
	reg PH1Reg;
	reg PH2Reg;
	
	//Enable signals and trigger for execution on inputs
	reg inputEn;
	reg outputEn;
	reg TrigReg;

	//Variables for execution
	reg [7:0] currBit;	//Current bit number (out of 128) that is currently being transmitted or received
	reg [1:0] clkCount;	//Used for generating phase delayed clocks PH1 and PH2
	reg [3:0] waitBeforeTrigCount;
	
	//We don't need to use these registers
	reg	CAoutReg;
	reg	CBoutReg;
	
	
	initial begin
		currBit <= 0;
		clkCount <= 0;
		inputEn <= 0;
		outputEn <= 0;
		TrigReg <= 0;
		currState <= IDLE;
	end
	
	//Generating the two delayed clocks
	always @(posedge clk) begin
		//Generating phase delayed clocks PH1 and PH2 from Clk
		clkCount <= clkCount+1;
		case(clkCount)
			0: begin
				PH1Reg <= 1;
				PH2Reg <= 0;
			end
			1: begin
				PH1Reg <= 0;
				PH2Reg <= 0;
			end
			2: begin
				PH1Reg <= 0;
				PH2Reg <= 1;
			end
			3: begin
				PH1Reg <= 0;
				PH2Reg <= 0;
			end
		endcase
	end
	
	//posedge of PH1 occurs once a clock cycle of both PH1 and PH2 is over. So we use this as a main clock
	always @(posedge PH1Reg) begin
		case(currState)
			IDLE: begin
				currBit <= 0;
				inputEn <= 0;
				outputEn <= 0;
				TrigReg <= 0;
				if(ExStart) begin
					currState <= SEND;
					inputEn <= 1;
					currBit <= 0;
					ExDoneReg <= 0;
				end
			end
			
			SEND: begin
				//Keep sending inputs till 128 bits are counted
				if(currBit <= 127) begin
					currBit <= currBit+1;
				end
				else begin
					//Stop sending and change state to execute
					inputEn <= 0;
					currState <= EXECUTE;
					waitBeforeTrigCount <= 0;
				end
			end
			
			EXECUTE: begin
				if(waitBeforeTrigCount <= 5) begin
					//Do nothing for 5 clock cycles before issuing a trigger
					waitBeforeTrigCount <= waitBeforeTrigCount+1;
				end
				else if(waitBeforeTrigCount == 6) begin
					//Issueing a trigger in the 6th CC
					TrigReg <= 1;
					waitBeforeTrigCount <= 7;					
				end
				else if(waitBeforeTrigCount == 7) begin
					//Wait for another CC after trigger low (we are not sure if execution occurs of posedge or negedge of trig)and put it in RECEIVE state
					TrigReg <= 0;
					waitBeforeTrigCount <= 8;
				end
				else if(waitBeforeTrigCount == 8) begin
					currState <= RECEIVE;
					outputEn <= 1;
					currBit <= 0;
				end
			end
			
			RECEIVE: begin
				if(currBit <= 127) begin
					responseUpReg[currBit] <= SO_Up;
					responseUpNotReg[currBit] <= SO_not_Up;
					responseDownReg[currBit] <= SO_Down;
					responseDownNotReg[currBit] <= SO_not_Down;
					
					//We also get Challenge reads but we ignore them
					CAoutReg	<= CAout;
					CBoutReg	<= CBout;
					
					currBit <= currBit+1;
				end
				else begin
					//Stop receiving and change state to IDLE
					outputEn <= 0;
					currState <= IDLE;
					ExDoneReg <= 1;
				end
			end
		endcase
	end
	
	//Assign regs to their corresponding Nets of the ports
	assign ExDone = ExDoneReg;
	assign responseUp = responseUpReg;
	assign responseUpNot = responseUpNotReg;
	assign responseDown = responseDownReg;
	assign responseDownNot = responseDownNotReg;
	assign CA_SI = challengeA[currBit]; 
	assign CB_SI = challengeB[currBit];
	assign PH1 = PH1Reg;
	assign PH2 = PH2Reg;
	assign Trig = TrigReg;
	
endmodule
