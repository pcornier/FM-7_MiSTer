//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
  //Master input clock
  input         CLK_50M,

  //Async reset from top-level module.
  //Can be used as initial reset.
  input         RESET,

  //Must be passed to hps_io module
  inout  [48:0] HPS_BUS,

  //Base video clock. Usually equals to CLK_SYS.
  output        CLK_VIDEO,

  //Multiple resolutions are supported using different CE_PIXEL rates.
  //Must be based on CLK_VIDEO
  output        CE_PIXEL,

  //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
  //if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
  output [12:0] VIDEO_ARX,
  output [12:0] VIDEO_ARY,

  output  [7:0] VGA_R,
  output  [7:0] VGA_G,
  output  [7:0] VGA_B,
  output        VGA_HS,
  output        VGA_VS,
  output        VGA_DE,    // = ~(VBlank | HBlank)
  output        VGA_F1,
  output [1:0]  VGA_SL,
  output        VGA_SCALER, // Force VGA scaler
  output        VGA_DISABLE, // analog out is off

  input  [11:0] HDMI_WIDTH,
  input  [11:0] HDMI_HEIGHT,
  output        HDMI_FREEZE,

`ifdef MISTER_FB
  // Use framebuffer in DDRAM
  // FB_FORMAT:
  //    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
  //    [3]   : 0=16bits 565 1=16bits 1555
  //    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
  //
  // FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
  output        FB_EN,
  output  [4:0] FB_FORMAT,
  output [11:0] FB_WIDTH,
  output [11:0] FB_HEIGHT,
  output [31:0] FB_BASE,
  output [13:0] FB_STRIDE,
  input         FB_VBL,
  input         FB_LL,
  output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
  // Palette control for 8bit modes.
  // Ignored for other video modes.
  output        FB_PAL_CLK,
  output  [7:0] FB_PAL_ADDR,
  output [23:0] FB_PAL_DOUT,
  input  [23:0] FB_PAL_DIN,
  output        FB_PAL_WR,
`endif
`endif

  output        LED_USER,  // 1 - ON, 0 - OFF.

  // b[1]: 0 - LED status is system status OR'd with b[0]
  //       1 - LED status is controled solely by b[0]
  // hint: supply 2'b00 to let the system control the LED.
  output  [1:0] LED_POWER,
  output  [1:0] LED_DISK,

  // I/O board button press simulation (active high)
  // b[1]: user button
  // b[0]: osd button
  output  [1:0] BUTTONS,

  input         CLK_AUDIO, // 24.576 MHz
  output [15:0] AUDIO_L,
  output [15:0] AUDIO_R,
  output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
  output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

  //ADC
  inout   [3:0] ADC_BUS,

  //SD-SPI
  output        SD_SCK,
  output        SD_MOSI,
  input         SD_MISO,
  output        SD_CS,
  input         SD_CD,

  //High latency DDR3 RAM interface
  //Use for non-critical time purposes
  output        DDRAM_CLK,
  input         DDRAM_BUSY,
  output  [7:0] DDRAM_BURSTCNT,
  output [28:0] DDRAM_ADDR,
  input  [63:0] DDRAM_DOUT,
  input         DDRAM_DOUT_READY,
  output        DDRAM_RD,
  output [63:0] DDRAM_DIN,
  output  [7:0] DDRAM_BE,
  output        DDRAM_WE,

  //SDRAM interface with lower latency
  output        SDRAM_CLK,
  output        SDRAM_CKE,
  output [12:0] SDRAM_A,
  output  [1:0] SDRAM_BA,
  inout  [15:0] SDRAM_DQ,
  output        SDRAM_DQML,
  output        SDRAM_DQMH,
  output        SDRAM_nCS,
  output        SDRAM_nCAS,
  output        SDRAM_nRAS,
  output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
  //Secondary SDRAM
  //Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
  input         SDRAM2_EN,
  output        SDRAM2_CLK,
  output [12:0] SDRAM2_A,
  output  [1:0] SDRAM2_BA,
  inout  [15:0] SDRAM2_DQ,
  output        SDRAM2_nCS,
  output        SDRAM2_nCAS,
  output        SDRAM2_nRAS,
  output        SDRAM2_nWE,
`endif

  input         UART_CTS,
  output        UART_RTS,
  input         UART_RXD,
  output        UART_TXD,
  output        UART_DTR,
  input         UART_DSR,

  // Open-drain User port.
  // 0 - D+/RX
  // 1 - D-/TX
  // 2..6 - USR2..USR6
  // Set USER_OUT to 1 to read from USER_IN.
  input   [6:0] USER_IN,
  output  [6:0] USER_OUT,

  input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
// assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;

assign AUDIO_S = 0;
// assign AUDIO_L = 0;
// assign AUDIO_R = 0;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[122:121];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v"
localparam CONF_STR = {
  "FM-7;;",
  "-;",
  "F1,t77,Load Tape;",
  "O[8],Tape Rewind;",
  "O[9],Tape Audio,Off,On;",
  "O[11:10],BootROM,Basic,1,2,3;",
  "-;",
  "O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
  "O[2],TV Mode,NTSC,PAL;",
  "O[4:3],Noise,White,Red,Green,Blue;",
  "-;",
  "T[0],Reset;",
  "R[0],Reset and close OSD;",
  "v,0;",
  "V,v",`BUILD_DATE
};

wire forced_scandoubler;
wire   [1:0] buttons;
wire [127:0] status;
wire  [10:0] ps2_key;
wire direct_video;

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [15:0] ioctl_dout;

wire [31:0] joy1, joy2;

hps_io #(.CONF_STR(CONF_STR),.WIDE(1)) hps_io
(
  .clk_sys(clk_sys),
  .HPS_BUS(HPS_BUS),
  .EXT_BUS(),
  .gamma_bus(),
  .direct_video(direct_video),

  .forced_scandoubler(forced_scandoubler),

  .ioctl_download(ioctl_download),
  .ioctl_wr(ioctl_wr),
  .ioctl_addr(ioctl_addr),
  .ioctl_dout(ioctl_dout),
  .ioctl_index(ioctl_index),

  .joystick_0(joy1),
  .joystick_1(joy2),

  .buttons(buttons),
  .status(status),
  .status_menumask({ direct_video }),

  .ps2_key(ps2_key)
);

///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys, locked, _2MHz;
pll pll
(
  .refclk(CLK_50M),
  .rst(0),
  .outclk_0(clk_sys),
  .outclk_1(_2MHz),
  .locked(locked)
);

wire reset = RESET | status[0] | buttons[1];

reg old_ioctl_download;
always @(posedge clk_sys)
  old_ioctl_download <= ioctl_download;

wire [2:0] grb;

assign VGA_R[7] = grb[1];
assign VGA_G[7] = grb[2];
assign VGA_B[7] = grb[0];

wire HBlank;
wire HSync;
wire VBlank;
wire VSync;
wire ce_pix;
wire [7:0] video;

wire RESETn = ~reset;
wire CLKSYS = clk_sys;
wire cin;
wire motor;
wire [15:0] sdram_data;
wire [24:0] sdram_addr;
wire need_more_byte;
wire sdram_ready;
wire rewind = (old_ioctl_download & ~ioctl_download) | status[8];
wire SVIDEOCLK;
wire [13:0] audio_out;
wire buzzer;
wire [7:0] relay_snd;

wire [15:0] cin_audio = { 1'b0, cin & motor & status[9], 13'b0 };
wire [15:0] core_audio =  { 1'b0, audio_out, 13'b0 };
wire [15:0] buz_audio = { 1'b0, buzzer, 13'b0 };
wire [15:0] relay_audio = { 1'b0, (status[9] ? relay_snd : 8'd0), 7'b0 };

assign AUDIO_L = cin_audio + core_audio + buz_audio + relay_audio;
assign AUDIO_R = cin_audio + core_audio + buz_audio + relay_audio;

core u_core(
  .RESETn      ( RESETn        ),
  .CLKSYS      ( CLKSYS        ),
  .HBLANK      ( HBlank        ),
  .VBLANK      ( VBlank        ),
  .VSync       ( VSync         ),
  .HSync       ( HSync         ),
  .grb         ( grb           ),
  .ps2_key     ( ps2_key       ),
  .SVIDEOCLK   ( SVIDEOCLK     ),
  .ce_pix      ( ce_pix        ),
  .audio_out   ( audio_out     ),
  .buzzer      ( buzzer        ),
  // tape
  .cin         ( cin           ),
  .motor       ( motor         ),
  .bootrom_sel ( status[11:10] )
);


t77_decode u_t77_decode(
  .CLKSYS     ( CLKSYS         ),
  .start      ( motor          ),
  .data       ( sdram_data     ),
  .data_stb   ( sdram_ready    ),
  .sdram_addr ( sdram_addr     ),
  .sdram_rd   ( need_more_byte ),
  .sout       ( cin            ),
  .rewind     ( rewind         )
);


sdram u_sdram(
  .*,
  .init  ( ~locked                                  ),
  .clk   ( CLKSYS                                   ),
  .wtbt  ( 2'b11                                    ),
  .addr  ( ioctl_download ? ioctl_addr : sdram_addr ),
  .dout  ( sdram_data                               ),
  .din   ( ioctl_dout                               ),
  .we    ( ioctl_wr                                 ),
  .rd    ( need_more_byte                           ),
  .ready ( sdram_ready                              )
);

pcm pcm(
  .CLKSYS         ( CLKSYS    ),
  .motor          ( motor     ),
  .unsigned_audio ( relay_snd )
);

assign CLK_VIDEO = clk_sys;
assign CE_PIXEL = ce_pix;// SVIDEOCLK;
assign VGA_DE = ~(HBlank | VBlank);
assign VGA_HS = HSync;
assign VGA_VS = VSync;


assign LED_USER    = cin;

endmodule
