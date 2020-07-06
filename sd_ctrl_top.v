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
    //SD���ӿ�
    input               sd_miso         ,
    output              sd_clk          ,
    output    reg       sd_cs           ,
    output    reg       sd_mosi         ,
    //�û�дSD���ӿ�
    input               wr_start_en     ,
    input   [31:0]      wr_sec_addr     ,
    input   [15:0]      wr_data         ,
    output              wr_busy         ,
    output              wr_req          ,
    //�û���SD���ӿ�
    input               rd_start_en     ,
    input   [31:0]      rd_sec_addr     ,
    output              rd_busy         ,
    output              rd_val_en       ,
    output  [15:0]      rd_val_data     ,
    
    output              sd_init_done        //sd����ʼ������ź�
    );
    
    //wire define
    wire                init_sd_clk     ;   //��ʼ��sd��ʱ�ĵ���ʱ��
    wire                init_sd_cs      ;   //��ʼ��ģ��SDƬѡ�ź�
    wire                init_sd_mosi    ;   //��ʼ��ģ��SD��������ź�
    wire                wr_sd_cs        ;   //д����ģ��SDƬѡ�ź�
    wire                wr_sd_mosi      ;   //д����ģ��SD��������ź�
    wire                rd_sd_cs        ;   //������ģ��SDƬѡ�ź�
    wire                rd_sd_mosi      ;   //������ģ��SD��������ź�
    
    //main code
    
    assign sd_clk = (sd_init_done == 1'b0) ? init_sd_clk : clk_ref_180deg;
    
    //sd���ӿ��ź�ѡ��
    always @(*) begin //����clk������߼�,ʵ�����ߵĹ���
        //sd����ʼ�����֮ǰ���˿��źźͳ�ʼ��ģ������
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
            sd_cs = 1'b1;   //����״̬����Ч
            sd_mosi = 1'b1;
        end
    end
 
 //SD����ʼ��ģ������
 sd_init sd_init_inst(
     .clk_ref       (clk_ref),
     .rst_n         (rst_n),
     
     .sd_miso       (sd_miso),
     .sd_clk        (init_sd_clk),
     .sd_cs         (init_sd_cs),
     .sd_mosi       (init_sd_mosi),
     
     .sd_init_done  (sd_init_done)
     );   
 
 //SD��д����ģ������
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
 
  //SD��������ģ������
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
