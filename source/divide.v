// megafunction wizard: %LPM_DIVIDE%
// GENERATION: STANDARD
// VERSION: WM1.0
// MODULE: lpm_divide 

// ============================================================
// File Name: divide.v
// Megafunction Name(s):
// 			lpm_divide
// ============================================================
// ************************************************************
// THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
//
// 6.0 Build 178 04/27/2006 SJ Full Version
// ************************************************************


//Copyright (C) 1991-2006 Altera Corporation
//Your use of Altera Corporation's design tools, logic functions 
//and other software and tools, and its AMPP partner logic 
//functions, and any output files any of the foregoing 
//(including device programming or simulation files), and any 
//associated documentation or information are expressly subject 
//to the terms and conditions of the Altera Program License 
//Subscription Agreement, Altera MegaCore Function License 
//Agreement, or other applicable license agreement, including, 
//without limitation, that your use is for the sole purpose of 
//programming logic devices manufactured by Altera and sold by 
//Altera or its authorized distributors.  Please refer to the 
//applicable agreement for further details.


// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module divide (
	denom,
	numer,
	quotient,
	remain);

	input	[31:0]  denom;
	input	[31:0]  numer;
	output	[31:0]  quotient;
	output	[31:0]  remain;

	wire [31:0] sub_wire0;
	wire [31:0] sub_wire1;
	wire [31:0] quotient = sub_wire0[31:0];
	wire [31:0] remain = sub_wire1[31:0];
    
    // this takes 2200 LUTs on iCE40
    assign sub_wire0 = denom / numer;
    assign sub_wire1 = denom % numer;
/*
	lpm_divide	lpm_divide_component (
				.denom (denom),
				.numer (numer),
				.quotient (sub_wire0),
				.remain (sub_wire1),
				.aclr (1'b0),
				.clken (1'b1),
				.clock (1'b0));
	defparam
		lpm_divide_component.lpm_drepresentation = "SIGNED",
		lpm_divide_component.lpm_hint = "LPM_REMAINDERPOSITIVE=FALSE",
		lpm_divide_component.lpm_nrepresentation = "SIGNED",
		lpm_divide_component.lpm_type = "LPM_DIVIDE",
		lpm_divide_component.lpm_widthd = 32,
		lpm_divide_component.lpm_widthn = 32;
*/

endmodule

// ============================================================
// CNX file retrieval info
// ============================================================
// Retrieval info: PRIVATE: PRIVATE_LPM_REMAINDERPOSITIVE STRING "FALSE"
// Retrieval info: PRIVATE: PRIVATE_MAXIMIZE_SPEED NUMERIC "-1"
// Retrieval info: PRIVATE: USING_PIPELINE NUMERIC "0"
// Retrieval info: PRIVATE: VERSION_NUMBER NUMERIC "2"
// Retrieval info: CONSTANT: LPM_DREPRESENTATION STRING "SIGNED"
// Retrieval info: CONSTANT: LPM_HINT STRING "LPM_REMAINDERPOSITIVE=FALSE"
// Retrieval info: CONSTANT: LPM_NREPRESENTATION STRING "SIGNED"
// Retrieval info: CONSTANT: LPM_TYPE STRING "LPM_DIVIDE"
// Retrieval info: CONSTANT: LPM_WIDTHD NUMERIC "32"
// Retrieval info: CONSTANT: LPM_WIDTHN NUMERIC "32"
// Retrieval info: USED_PORT: denom 0 0 32 0 INPUT NODEFVAL denom[31..0]
// Retrieval info: USED_PORT: numer 0 0 32 0 INPUT NODEFVAL numer[31..0]
// Retrieval info: USED_PORT: quotient 0 0 32 0 OUTPUT NODEFVAL quotient[31..0]
// Retrieval info: USED_PORT: remain 0 0 32 0 OUTPUT NODEFVAL remain[31..0]
// Retrieval info: CONNECT: @numer 0 0 32 0 numer 0 0 32 0
// Retrieval info: CONNECT: @denom 0 0 32 0 denom 0 0 32 0
// Retrieval info: CONNECT: quotient 0 0 32 0 @quotient 0 0 32 0
// Retrieval info: CONNECT: remain 0 0 32 0 @remain 0 0 32 0
// Retrieval info: LIBRARY: lpm lpm.lpm_components.all
// Retrieval info: GEN_FILE: TYPE_NORMAL divide.v TRUE
// Retrieval info: GEN_FILE: TYPE_NORMAL divide.inc FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL divide.cmp FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL divide.bsf FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL divide_inst.v TRUE
// Retrieval info: GEN_FILE: TYPE_NORMAL divide_bb.v TRUE
