`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/07/05 21:32:24
// Design Name: 
// Module Name: top_sd_rw
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module top_sd_rw(
    input       sys_clk,
    input       sys_rst_n,
    
    // sd卡接口
    input           sd_miso,
    output          sd_clk,
    output          sd_cs,
    output          sd_mosi,
    
    //LED
    output  [3:0]   led
    );
    
    //wire define
    wire            clk_ref         ;
    wire            clk_ref_180deg  ;
    wire            rst_n           ;
    wire            locked          ;
    
    wire            wr_start_en     ;
    wire    [31:0]  wr_sec_addr     ;
    wire    [15:0]  wr_data         ;
    wire            rd_start_en     ;
    wire    [31:0]  rd_sec_addr     ;
    wire            error_flag      ;
    
    wire            wr_busy         ;
    wire            wr_req          ;
    wire            rd_busy         ;
    wire            rd_val_en       ;
    wire    [15:0]  rd_val_data     ;
    wire            sd_init_done    ;
    
//    wire            sys_rst_n       ;
    //***************************
    //** main code
    //***************************
    
assign  rst_n = ~sys_rst_n & locked;

//时钟向导例化
clk_wiz_0   clk_siz_0_inst(
    .reset          (1'b0),
    .clk_in1        (sys_clk),
    .clk_out1       (clk_ref),
    .clk_out2       (clk_ref_180deg),
    .locked         (locked)
    );
    
sd_ctrl_top sd_ctrl_top_ins(
    .clk_ref         (clk_ref),
    .clk_ref_180deg  (clk_ref_180deg),
    .rst_n           (rst_n),
                    
    .sd_miso         (sd_miso),
    .sd_clk          (sd_clk),
    .sd_cs           (sd_cs),
    .sd_mosi         (sd_mosi),
                   
    .wr_start_en     (wr_start_en),
    .wr_sec_addr     (wr_sec_addr),
    .wr_data         (wr_data),
    .wr_busy         (wr_busy),
    .wr_req          (wr_req),
                    
    .rd_start_en     (rd_start_en),
    .rd_sec_addr     (rd_sec_addr),
    .rd_busy         (rd_busy),
    .rd_val_en       (rd_val_en),
    .rd_val_data     (rd_val_data),
                   
    .sd_init_done    (sd_init_done)
    );
    
led_alarm #(
    .L_TIME         (25'd25_000_000)
    )
    led_alarm_inst(
    .clk        (clk_ref),
    .rst_n      (rst_n),
    .led        (led),
    .error_flag (error_flag)   
    );

data_gen data_gen_inst(
    .clk            (clk_ref),    
    .rst_n          (rst_n),
    .sd_init_done   (sd_init_done),
                    
    .wr_busy        (wr_busy),
    .wr_req         (wr_req),
    .wr_start_en    (wr_start_en),
    .wr_sec_addr    (wr_sec_addr),
    .wr_data        (wr_data),
                    
    .rd_val_en      (rd_val_en),
    .rd_val_data    (rd_val_data),
    .rd_start_en    (rd_start_en),
    .rd_sec_addr    (rd_sec_addr),
                    
    .error_flag     (error_flag)
    );   
endmodule
