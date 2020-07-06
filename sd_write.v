`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/07/06 01:57:53
// Design Name: 
// Module Name: sd_write
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


module sd_write(
    input               clk_ref         ,
    input               clk_ref_180deg  ,
    input               rst_n           ,
    //SD卡接口
    input               sd_miso         ,
    output      reg     sd_cs           ,
    output      reg     sd_mosi         ,
    //用户写接口
    input               wr_start_en     ,
    input       [31:0]  wr_sec_addr     ,
    input       [15:0]  wr_data         ,
    output      reg     wr_busy         ,
    output      reg     wr_req   
    );
    
parameter   HEAD_BYTE = 8'hfe;  //数据头

//reg define
reg                 wr_en_d0            ;
reg                 wr_en_d1            ;
reg                 res_en              ;
reg     [7:0]       res_data            ;  //写数据返回R1,8bit
reg                 res_flag            ;
reg     [5:0]       res_bit_cnt         ;

reg     [3:0]       wr_ctrl_cnt         ;
reg     [47:0]      cmd_wr              ;   //写命令
reg     [5:0]       cmd_bit_cnt         ;   //写命令位计数器
reg     [3:0]       bit_cnt             ;   //写数据位计数器
reg     [8:0]       data_cnt            ;   //写入数据数量
reg     [15:0]      wr_data_t           ;
reg                 detect_done_flag    ;
reg     [7:0]       detect_data         ;

//wire define
wire                pos_wr_en           ;

//main code

assign pos_wr_en = (~wr_en_d1) & wr_en_d0;

//wr_start_en信号延迟打拍
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        wr_en_d0 <= 1'b0;
        wr_en_d1 <= 1'b0;
    end
    else begin
        wr_en_d0 <= wr_start_en;
        wr_en_d1 <= wr_en_d0;
    end
end

//接收SD卡返回的响应数据
always @(posedge clk_ref_180deg or negedge rst_n) begin
    if(!rst_n) begin
        res_en <= 1'b0;
        res_data <= 8'd0;
        res_flag <= 1'b0;
        res_bit_cnt <= 6'd0;
    end
    else begin
        //sd_miso = 0 开始接收响应数据
        if(sd_miso == 1'b0 && res_flag == 1'b0) begin
            res_flag <= 1'b1;
            res_data <= {res_data[6:0], sd_miso}; //6??
            res_bit_cnt <= res_bit_cnt + 1'b1;
            res_en <= 1'b0;
        end
        else if(res_flag) begin
            res_data <= {res_data[6:0], sd_miso};
            res_bit_cnt <= res_bit_cnt + 6'd1;
            if(res_bit_cnt == 6'd7) begin
                res_flag <= 1'b0;
                res_bit_cnt <= 6'd0;
                res_en <= 1'b1;
            end
        end
        else
            res_en <= 1'b0;
    end
end 

//写完数据后检测SD卡是否空闲
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n)
        detect_data <= 8'd0;
    else if(detect_done_flag)
        detect_data <= {detect_data[6:0], sd_miso};
    else
        detect_data <= 8'd0;
end

//SD卡写入数据
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        sd_cs <= 1'b1;
        sd_mosi <= 1'b1;
        wr_ctrl_cnt <= 4'd0;
        wr_busy <= 1'b0;
        cmd_wr <= 48'd0;
        cmd_bit_cnt <= 6'd0;
        bit_cnt <= 4'd0;
        wr_data_t <= 16'd0;
        data_cnt <= 9'd0;
        wr_req <= 1'b0;
        detect_done_flag <= 1'b0;
    end
    else begin
        wr_req <= 1'b0;
        case(wr_ctrl_cnt)
            4'd0 : begin
                wr_busy <= 1'b0;
                sd_cs <= 1'b1;
                sd_mosi <= 1'b1;
                if(pos_wr_en) begin
                    cmd_wr <= {8'h58, wr_sec_addr, 8'hff};  //CMD24
                    wr_ctrl_cnt <= wr_ctrl_cnt + 1'b1;
                    //开始写入数据，拉高写忙信号
                    wr_busy <= 1'b1;
                end
            end
            4'd1 : begin
                if(cmd_bit_cnt <= 6'd47) begin
                    cmd_bit_cnt <= cmd_bit_cnt + 6'd1;
                    sd_cs <= 1'b0;
                    sd_mosi <= cmd_wr[6'd47 - cmd_bit_cnt]; //先发高字节
                end
                else begin
                    sd_mosi <= 1'b1;
                    if(res_en) begin        //SD卡响应
                        wr_ctrl_cnt <= wr_ctrl_cnt + 4'd1;  //控制计数器加一
                        cmd_bit_cnt <= 6'd0;
                        bit_cnt <= 4'd1;        //此时已消耗一个时钟周期
                    end
                end
            end
            4'd2 : begin
                bit_cnt <= bit_cnt + 4'd1;
                //bit_cnt 0~7 等待8个时钟周期
                //bit_cnt 8~15 写入命令头8'hfe
                if(bit_cnt >= 4'd8 && bit_cnt <= 4'd15) begin
                    sd_mosi <= HEAD_BYTE[4'd15 - bit_cnt];  //先发高字节
                    if(bit_cnt == 4'd14)
                        wr_req <= 1'b1;             //提前拉高写数据请求信号
                    else if(bit_cnt == 4'd15)
                        wr_ctrl_cnt <= wr_ctrl_cnt + 4'd1; //控制计数器加一
                end                
            end
            4'd3 : begin                        //写入数据
                bit_cnt <= bit_cnt + 4'd1;
                if(bit_cnt == 4'd0) begin       //上一个step溢出后为0
                    sd_mosi <= wr_data[4'd15-bit_cnt];  //先发送数据高位
                    wr_data_t <= wr_data;        //暂存数据,防止后面变化
                end
                else
                    sd_mosi <= wr_data_t[4'd15 - bit_cnt];
                if((bit_cnt == 4'd14) && (data_cnt <= 9'd255))  //data_cnt用于记录发送了多少个16bit
                    wr_req <= 1'b1; 
                if(bit_cnt == 4'd15) begin
                    data_cnt <= data_cnt + 9'd1;
                    //写入单个BLOCK共512Byte， 256 * 16bit
                    if(data_cnt == 9'd255) begin
                        data_cnt <= 9'd0;
                        //写入数据完成，控制计数器加一
                        wr_ctrl_cnt <= wr_ctrl_cnt + 4'd1;
                    end
                end
            end
            //写入2字节CRC，SPI模式可直接写入0xff
            4'd4 : begin
                bit_cnt <= bit_cnt + 4'd1;
                sd_mosi <= 1'b1;
                //CRC写入完成，控制计数器加一
                if(bit_cnt == 4'd15)
                    wr_ctrl_cnt <= wr_ctrl_cnt + 4'd1;
            end
            //SD卡响应
            4'd5 : begin
                if(res_en)
                    wr_ctrl_cnt <= wr_ctrl_cnt + 4'd1;
            end
            //等待写完成
            4'd6 : begin
                detect_done_flag <= 1'b1;
                //detect_data = 0xff时，SD卡写入完成，进入空闲状态
                if(detect_data == 8'hff) begin
                    wr_ctrl_cnt <= wr_ctrl_cnt + 4'd1;
                    detect_done_flag <= 1'b0;
                end
            end
            default : begin
                //进入空闲状态后，拉高片选信号，等待8个时钟周期
                sd_cs <= 1'b1;
                wr_ctrl_cnt = wr_ctrl_cnt + 4'd1;
            end
        endcase
    end    
end
endmodule
