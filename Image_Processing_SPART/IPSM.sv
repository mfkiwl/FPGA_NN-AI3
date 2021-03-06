// ============================================================================
// Copyright (c) 2013 by Terasic Technologies Inc.
// ============================================================================
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development 
//   Kits made by Terasic.  Other use of this code, including the selling 
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use 
//   or functionality of this code.
//
// ============================================================================
//           
//  Terasic Technologies Inc
//  9F., No.176, Sec.2, Gongdao 5th Rd, East Dist, Hsinchu City, 30070. Taiwan
//  
//  
//                     web: http://www.terasic.com/  
//                     email: support@terasic.com
//
// ============================================================================
//Date:  Thu Jul 11 11:26:45 2013
// ============================================================================

module IPSM(

	//////////// CLOCK //////////
	input 		          		CLOCK2_50,
	input 		          		CLOCK_50,
    input DLY_RST_1, DLY_RST_2,
	input auto_start,

    //User inputs
    input start_key, exposure_key,
	input exposure_sw, zoom_sw,

    // CPU interface
	input enable,
	output ccd_done,
	// DMEM interface
	output dmem_wren,
	output [6:0] dmem_wraddr,
	output [255:0] dmem_wrdata,

	//////////// GPIO_1, GPIO_1 connect to D5M - 5M Pixel Camera //////////
	input 		    [11:0]		D5M_D,
	input 		          		D5M_FVAL,
	input 		          		D5M_LVAL,
	input 		          		D5M_PIXLCLK,
	output		          		D5M_SCLK,
	inout 		          		D5M_SDATA
);


//=======================================================
//  REG/WIRE declarations
// //=======================================================
// wire						    DLY_RST_0;
// wire						    DLY_RST_1;
// wire						    DLY_RST_2;
// wire						    DLY_RST_3;
// wire						    DLY_RST_4;

// Pipeline stages
reg		        [11:0]			rCCD_DATA;
reg								rCCD_LVAL;
reg								rCCD_FVAL;

wire		    [11:0]			mCCD_DATA;
wire							mCCD_DVAL;
wire	        [15:0]			X_Cont;
wire	        [15:0]			Y_Cont;
wire	        [31:0]			Frame_Cont;

wire	        [11:0]			gCCD_DATA;
wire							gCCD_DVAL;
wire            [10:0]           X_Gray;
wire            [10:0]           Y_Gray;

wire	        [7:0]			sCCD_DATA;
wire							sCCD_DVAL;
//=======================================================
//  Structural coding
//=======================================================
//D5M read 
always@(posedge D5M_PIXLCLK)
begin
	rCCD_DATA	<=	D5M_D;
	rCCD_LVAL	<=	D5M_LVAL;
	rCCD_FVAL	<=	D5M_FVAL;
end

/// Image Capture Pipeline ///
//D5M image capture
CCD_Capture	u3 (
    .iCLK(~D5M_PIXLCLK),
    .iRST(DLY_RST_2),

    .iSTART(auto_start|start_key),
    .iEND(1'b0),
    .iFVAL(rCCD_FVAL),
    .iLVAL(rCCD_LVAL),
    .iDATA(rCCD_DATA),

    .oDATA(mCCD_DATA),
    .oDVAL(mCCD_DVAL),
    .oX_Cont(X_Cont),
    .oY_Cont(Y_Cont),
    .oFrame_Cont(Frame_Cont)
);

//D5M raw date convert to grayscale data
RAW2GRAY u4 (	
    .iCLK(D5M_PIXLCLK),
    .iRST(DLY_RST_1),

    .iDATA(mCCD_DATA),
    .iDVAL(mCCD_DVAL),
    .iX_Cont(X_Cont),
    .iY_Cont(Y_Cont),

    .oDATA(gCCD_DATA),
    .oDVAL(gCCD_DVAL),
    .oX(X_Gray),
    .oY(Y_Gray)
);

//D5M sample image down to 28x28 image
CropDown u5 (
	.iCLK(D5M_PIXLCLK), 
	.iRST(DLY_RST_1),

	.iDVAL(gCCD_DVAL), 
	.iDATA(~gCCD_DATA), 
	.iX(X_Gray[10:1]),
	.iY(Y_Gray[10:1]),
    
	.oDATA(sCCD_DATA),
	.oDVAL(sCCD_DVAL)
);

/// End Image Capture Pipeline ///

// Control image capture and storage	
Img_Proc_FSM FSM (
	.pxlclk(D5M_PIXLCLK),
	.rst_n(DLY_RST_1),

	// CPU interface
	.iCCD_enable(enable),
	.oCCD_done(ccd_done),

	// User control
	.iCCD_start(start_key),
	
	// Pipeline interface
	.iFVAL(rCCD_FVAL),
	.iDVAL(sCCD_DVAL),
	.iDATA({8'h0, sCCD_DATA}),

	// Bmem 256-bit write port
	.oDmem_wren(dmem_wren),
	.oDmem_addr(dmem_wraddr),
	.oDmem_data(dmem_wrdata),
	.state(),
	.frame_val()
);

//D5M I2C control
I2C_CCD_Config u8 (	
    //	Host Side
    .iCLK(CLOCK2_50),
    .iRST_N(DLY_RST_2),
    .iEXPOSURE_ADJ(exposure_key),
    .iEXPOSURE_DEC_p(exposure_sw),
    .iZOOM_MODE_SW(zoom_sw),
    //	I2C Side
    .I2C_SCLK(D5M_SCLK),
    .I2C_SDAT(D5M_SDATA)
);

endmodule
