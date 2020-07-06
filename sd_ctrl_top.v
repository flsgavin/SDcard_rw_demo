`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/07/05 23:28:38
// Design Name: 
// Module Name: sd_ctrl_top
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


module sd_ctrl_top(
    input               clk_ref         ,
    input               clk_ref_180deg  ,
    input               rst_n           ,
    //SD卡接口
    input               sd_miso         ,
    output              sd_clk          ,
    output    reg       sd_cs           ,
    output    reg       sd_mosi         ,
    //用户写SD卡接口
    input               wr_start_en     ,
    input   [31:0]      wr_sec_addr     ,
    input   [15:0]      wr_data         ,
    output              wr_busy         ,
    output              wr_req          ,
    //用户读SD卡接口
    input               rd_start_en     ,
    input   [31:0]      rd_sec_addr     ,
    output              rd_busy         ,
    output              rd_val_en       ,
    output  [15:0]      rd_val_data     ,
    
    output              sd_init_done        //sd卡初始化完成信号
    );
    
    //wire define
    wire                init_sd_clk     ;   //初始化sd卡时的低速时钟
    wire                init_sd_cs      ;   //初始化模块SD片选信号
    wire                init_sd_mosi    ;   //初始化模块SD数据输出信号
    wire                wr_sd_cs        ;   //写数据模块SD片选信号
    wire                wr_sd_mosi      ;   //写数据模块SD数据输出信号
    wire                rd_sd_cs        ;   //读数据模块SD片选信号
    wire                rd_sd_mosi      ;   //读数据模块SD数据输出信号
    
    //main code
    
    assign sd_clk = (sd_init_done == 1'b0) ? init_sd_clk : clk_ref_180deg;
    
    //sd卡接口信号选择
    always @(*) begin //不带clk，组合逻辑,实现连线的功能
        //sd卡初始化完成之前，端口信号和初始化模块相连
        if(sd_init_done == 1'b0) begin
            sd_cs = init_sd_cs;
            sd_mosi = init_sd_mosi;
        end
        else if(wr_busy) begin
            sd_cs = wr_sd_cs;
            sd_mosi = wr_sd_mosi;
        end
        else if(rd_busy) begin
            sd_cs = rd_sd_cs;
            sd_mosi = rd_sd_mosi;
        end
        else begin
            sd_cs = 1'b1;   //空闲状态，无效
            sd_mosi = 1'b1;
        end
    end
 
 //SD卡初始化模块例化
 sd_init sd_init_inst(
     .clk_ref       (clk_ref),
     .rst_n         (rst_n),
     
     .sd_miso       (sd_miso),
     .sd_clk        (init_sd_clk),
     .sd_cs         (init_sd_cs),
     .sd_mosi       (init_sd_mosi),
     
     .sd_init_done  (sd_init_done)
     );   
 
 //SD卡写数据模块例化
 sd_write sd_write_inst( 
    .clk_ref        (clk_ref),
    .clk_ref_180deg (clk_ref_180deg),
    .rst_n          (rst_n),
    
    .sd_miso        (sd_miso),
    .sd_cs          (wr_sd_cs),
    .sd_mosi        (wr_sd_mosi),              
    .wr_start_en    (wr_start_en & sd_init_done),
    .wr_sec_addr    (wr_sec_addr),
    .wr_data        (wr_data),
    .wr_busy        (wr_busy),
    .wr_req         (wr_req)
     );
 
  //SD卡读数据模块例化
 sd_read sd_read_inst( 
    .clk_ref        (clk_ref),
    .clk_ref_180deg (clk_ref_180deg),
    .rst_n          (rst_n),
                  
    .sd_miso        (sd_miso),
    .sd_cs          (rd_sd_cs),
    .sd_mosi        (rd_sd_mosi),
                  
    .rd_start_en    (rd_start_en & sd_init_done),
    .rd_sec_addr    (rd_sec_addr),
    .rd_busy        (rd_busy),
    .rd_val_en      (rd_val_en),
    .rd_val_data    (rd_val_data)
     );
 
endmodule
