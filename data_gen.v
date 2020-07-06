`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/07/05 22:00:12
// Design Name: 
// Module Name: data_gen
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


module data_gen(
    input               clk         ,
    input               rst_n       ,
    input               sd_init_done,
    
    //写sd卡接口
    input               wr_busy     ,
    input               wr_req      ,
    output  reg         wr_start_en ,
    output  reg [31:0]  wr_sec_addr ,
    output      [15:0]  wr_data     ,
    
    //读sd卡接口
    input               rd_val_en   ,
    input       [15:0]  rd_val_data ,
    output  reg         rd_start_en ,
    output  reg [31:0]  rd_sec_addr ,
    
    output              error_flag
    );
    
    //reg define
    reg                 sd_init_done_d0     ;       //sd_init_done信号的上升沿采样，第一拍
    reg                 sd_init_done_d1     ;       //sd_init_done信号的上升沿采样，第二拍
    reg                 wr_busy_d0          ;       //wr_busy信号的下降沿采样，第一拍
    reg                 wr_busy_d1          ;       //wr_busy信号的下降沿采样，第二拍
    reg     [15:0]      wr_data_t           ;
    reg     [15:0]      rd_comp_data        ;
    reg     [8:0]       rd_right_cnt        ;
    
    //wire define
    wire                pos_init_done       ;       //sd_init_done信号的上升沿，用于启动写入信号
    wire                neg_wr_busy         ;       //wr_busy信号的下降沿
    
    
    //main code
    
    assign pos_init_done = (~sd_init_done_d1) & sd_init_done_d0;
    assign neg_wr_busy = wr_busy_d1 & (~wr_busy_d0);
    
    assign wr_data = (wr_data_t > 16'd0) ? (wr_data_t - 1'b1) : 16'd0;
    
    assign error_flag = (rd_right_cnt == (9'd256)) ? 1'b0 : 1'b1;
    
    //sd_init_done信号延迟打拍
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sd_init_done_d0 <= 1'b0;
            sd_init_done_d1 <= 1'b0;
        end
        else begin
            sd_init_done_d0 <= sd_init_done;
            sd_init_done_d1 <= sd_init_done_d0;
        end
    end
    
    //sd卡写入信号控制
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_start_en <= 1'b0;
            wr_sec_addr <= 32'd0;
        end
        else begin
            if(pos_init_done) begin
                wr_start_en <= 1'b1;
                wr_sec_addr <= 32'd2000;    //任意一个扇区地址
            end       
            else
                wr_start_en <= 1'b0;
        end
    end
    
    //sd卡写数据
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) 
            wr_data_t <= 16'b0;
        else if(wr_req)
            wr_data_t <= wr_data_t + 16'b1;    
    end
    
    //wr_busy信号延迟打拍
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_busy_d0 <= 1'b0;
            wr_busy_d1 <= 1'b0;
        end
        else begin
            wr_busy_d0 <= wr_busy;
            wr_busy_d1 <= wr_busy_d0;
        end
    end
    
    //sd卡读出信号控制
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_start_en <= 1'b0;
            rd_sec_addr <= 32'd0;
        end
        else begin
            if(neg_wr_busy) begin
                rd_start_en <= 1'b1;
                rd_sec_addr <= 32'd2000;    //任意一个扇区地址
            end       
            else
                rd_start_en <= 1'b0;
        end
    end
    
    //读出错误时给出标志
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_comp_data <= 16'd0;
            rd_right_cnt <= 9'd0;
        end
        else begin
            if(rd_val_en) begin
                rd_comp_data <= rd_comp_data + 16'b1;
                if(rd_val_data == rd_comp_data)
                    rd_right_cnt <= rd_right_cnt + 9'd1;
            end
        end
    end
    
endmodule
