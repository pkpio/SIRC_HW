`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 
// Author 			:	Praveen Kumar Pendyala
// 
// Create Date		:  21:03:15 05/24/2013 
// Modify Date		:	06/05/2013
// Module Name		:  PUF 
// Project Name	: 	SIRC_HW
// Target Devices	: 	Xilinx Vertix 5, XUPV5 110T
// Tool versions	: 	13.2 ISE
// Description		: 
//	This module is a software model which follows the actual PUF timing diagrams
//	
//	Bugs : Not sure with which module this bug has to be associated with.
// - On first run after programming board. All the responses are 0's ! It works fine from
//	  the second onwards giving the expected results though
//////////////////////////////////////////////////////////////////////////////////

module PUF(
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
	
	
	//Other execution variables
	reg	[6:0] CurrChallengeBit;		//Bit (out of 128) that is currently being received
	reg	[6:0] CurrResponseBit;		//Bit (out of 128) that is currently being sent
	
	//Internal 128 bit buffers
	reg	[127:0]	Input_A_buff;
	reg	[127:0]	Input_B_buff;
	reg	[127:0]	Output_top_buff;
	reg	[127:0]	Output_bottom_buff;
	//Top not and bottom not are ignored
	
	//Some assignments
	assign SO_not_Up 	=  !SO_Up;
	assign SO_not_Down 	=  !SO_Down;
	
	initial begin
		CurrChallengeBit = 0;
		CurrResponseBit =	0;
	end
	
	always @(posedge PH1) begin
		if(Ph_En) begin
			Input_A_buff[CurrChallengeBit] <= CA_SI;
			Input_B_buff[CurrChallengeBit] <= CB_SI;
			CurrChallengeBit <= CurrChallengeBit+1;
		end
		
		if(OutEn) begin
			CurrResponseBit <=	CurrResponseBit+1;
		end
				
	end
	
	assign SO_Up 	= Output_top_buff[CurrResponseBit];
	assign SO_Down = Output_bottom_buff[CurrResponseBit];
	
	always @(posedge  Trig) begin
		Output_top_buff <= Input_A_buff | Input_B_buff;
		Output_bottom_buff <= Input_A_buff & Input_B_buff;
	end
	
endmodule
	