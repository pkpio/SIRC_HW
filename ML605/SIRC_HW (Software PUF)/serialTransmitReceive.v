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
	output	wire [127:0]	responseDownNot
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
	reg PH1;
	reg PH2;
	
	//Enable signals and trigger for execution on inputs
	reg inputEn;
	reg outputEn;
	reg Trig;
	
	//Input write and output read variables of PUF
	//Notation :: SO = Serial Output, SI = Serial Input, CA	= Challenge A, CB =	Challege B
	wire	SO_not_Up;
	wire	SO_Up;
	wire	SO_not_Down;
	wire	SO_Down;
	wire	CA_SI;
	wire	CB_SI;
	
	//Other input read and output write variables of PUF which we may not be using
	wire	CAout;				//Output of challenge A
	wire	CBout;				//Output of challenge B
	wire	SO_not_Up_In;		//Input of upper scan chain for Serial out not
	wire	SO_Up_In;			//Input of upper scan chain for Serial out
	wire	SO_not_Down_In;		//Input of lower scan chain for Serial out not
	wire	SO_Down_In;			//Input of lower scan chain for Serial out

	
	//Variables for execution
	reg [7:0] currBit;	//Current bit number (out of 128) that is currently being transmitted or received
	reg [1:0] clkCount;	//Used for generating phase delayed clocks PH1 and PH2
	reg [3:0] waitBeforeTrigCount;
	
	initial begin
		currBit <= 0;
		clkCount <= 0;
		inputEn <= 0;
		outputEn <= 0;
		Trig <= 0;
		currState <= IDLE;
	end
	
	//Generating the two delayed clocks
	always @(posedge clk) begin
		//Generating phase delayed clocks PH1 and PH2 from Clk
		clkCount <= clkCount+1;
		case(clkCount)
			0: begin
				PH1 <= 1;
				PH2 <= 0;
			end
			1: begin
				PH1 <= 0;
				PH2 <= 0;
			end
			2: begin
				PH1 <= 0;
				PH2 <= 1;
			end
			3: begin
				PH1 <= 0;
				PH2 <= 0;
			end
		endcase
	end
	
	//posedge of PH1 occurs once a clock cycle of both PH1 and PH2 is over. So we use this as a main clock
	always @(posedge PH1) begin
		case(currState)
			IDLE: begin
				currBit <= 0;
				inputEn <= 0;
				outputEn <= 0;
				Trig <= 0;
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
					Trig <= 1;
					waitBeforeTrigCount <= 7;					
				end
				else if(waitBeforeTrigCount == 7) begin
					//Wait for another CC after trigger low (we are not sure if execution occurs of posedge or negedge of trig)and put it in RECEIVE state
					Trig <= 0;
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
	
	//PUF software module
	PUF pufInstance1(
		.PH1(PH1),
		.PH2(PH2),
		.SO_not_Up(SO_not_Up),
		.SO_Up(SO_Up),
		.SO_not_Down(SO_not_Down),
		.SO_Down(SO_Down),
		.CAout(CAout),
		.CBout(CBout),
		.CA_SI(CA_SI),
		.CB_SI(CB_SI),
		.OutEn(outputEn),
		.Ph_En(inputEn),
		.Trig(Trig),
		.SO_not_Up_In(SO_not_Up_In),
		.SO_Up_In(SO_Up_In),
		.SO_not_Down_In(SO_not_Down_In),
		.SO_Down_In(SO_Down_In)
	);
	

endmodule
