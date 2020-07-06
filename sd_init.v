`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/07/06 00:04:57
// Design Name: 
// Module Name: sd_init
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


module sd_init(
    input               clk_ref     ,
    input               rst_n       ,
    
    input               sd_miso     ,
    output              sd_clk      ,
    output  reg         sd_cs       ,
    output  reg         sd_mosi     ,
    output  reg         sd_init_done
    );
    
//parameter define
//sd卡复位命令
parameter CMD0   = {8'h40, 8'h00, 8'h00, 8'h00, 8'h00, 8'h95};
//接口状态命令
parameter CMD8   = {8'h48, 8'h00, 8'h00, 8'h01, 8'haa, 8'h87};
//告诉SD卡接下来是应用相关命令
parameter CMD55  = {8'h77, 8'h00, 8'h00, 8'h00, 8'h00, 8'hff};
//发送操作寄存器OCR内容命令
parameter ACMD41 = {8'h69, 8'h40, 8'h00, 8'h00, 8'h00, 8'hff};
//时钟分频系数 50M / 250k = 200
parameter DIV_FREQ = 200; 
//上电至少等待74个时钟周期,干脆给5000个哈哈
parameter POWER_ON_NUM = 5000;
//超时时间 100ms 
parameter OVER_TIME_NUM = 25000;
//状态码
parameter st_idle            = 7'b000_0001; //IDLE状态，上电等待sd卡稳定
parameter st_send_cmd0       = 7'b000_0010; //发送软件复位命令
parameter st_wait_cmd0       = 7'b000_0100; //等待sd卡响应
parameter st_send_cmd8       = 7'b000_1000; //发送主设备电压范围
parameter st_send_cmd55      = 7'b001_0000; //告诉SD卡接下来是应用相关命令
parameter st_send_acmd41     = 7'b010_0000; //发送操作寄存器OCR内容
parameter st_init_done       = 7'b100_0000; //SD卡初始化完成

//reg define
reg     [7:0]   cur_state       ;
reg     [7:0]   next_state      ;

reg     [7:0]   div_cnt         ; //分频计数器
reg             div_clk         ; //分频后的时钟
reg     [12:0]  poweron_cnt     ; //上电等待稳定计数器
reg             res_en          ; //接收SD卡返回数据有效信号
reg     [47:0]  res_data        ; //接收SD卡返回数据
reg             res_flag        ; //开始接收返回数据的标志
reg     [5:0]   res_bit_cnt     ; //接收位数据计数器

reg     [5:0]   cmd_bit_cnt     ; //发送指令位计数器
reg     [15:0]  over_time_cnt   ; //超时计数器
reg             over_time_en    ; //超时使能信号

wire            div_clk_180deg  ; //与div_clk反向的时钟

//main code

assign  sd_clk = ~div_clk; //SD_CLK
assign  div_clk_180deg = ~div_clk;

//时钟分频
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        div_clk <= 1'b0;
        div_cnt <= 8'd0;
    end
    else begin
        if(div_cnt == DIV_FREQ/2 - 1'b1) begin
            div_clk <= ~div_clk;
            div_cnt <= 1'b0;
        end
        else
            div_cnt <= div_cnt + 1'b1;
    end
end

//上电等待稳定计数器
always @(posedge div_clk or negedge rst_n) begin
    if(!rst_n)
        poweron_cnt <= 13'd0;
    else if(cur_state == st_idle) begin
        if(poweron_cnt < POWER_ON_NUM)
            poweron_cnt <= poweron_cnt+ 1'b1;
    end
    else
        poweron_cnt <= 13'd0;
end

//接收SD卡返回的响应数据
//在div_clk_180deg上升沿锁存数据
always @(posedge div_clk_180deg or negedge rst_n) begin
    if(!rst_n) begin
        res_en <= 1'b0;
        res_data <= 48'd0;
        res_flag <= 1'b0;
        res_bit_cnt <= 6'd0;
    end
    else begin
        //sd_miso = 0开始接收响应数据
        if(sd_miso == 1'b0 && res_flag == 1'b0) begin
            res_flag <= 1'b1;
            res_data <= {res_data[46:0], sd_miso};
            res_bit_cnt <= res_bit_cnt + 6'd1;
            res_en <= 1'b0;
        end
        else if(res_flag) begin
            //R1返回一个字节，R3 R5返回5个字节
            //这里统一接收6个字节，多出的一个字节为nop（8个时钟周期的延迟）
            res_data <= {res_data[46:0], sd_miso}; //拼接+移位
            res_bit_cnt <= res_bit_cnt + 6'd1;
            if(res_bit_cnt == 6'd47) begin
                res_flag <= 1'b0;
                res_bit_cnt <= 6'd0;
                res_en <= 1'b1;
            end
        end
        else
            res_en <= 1'b0;
    end
end

always @(posedge div_clk or negedge rst_n) begin
    if(!rst_n)
        cur_state <= st_idle;
    else
        cur_state <= next_state;
end

always @(*) begin
    next_state = st_idle;
    case(cur_state)
        st_idle : begin
            //上电至少74个同步时钟
            if(poweron_cnt == POWER_ON_NUM)  //默认状态，上电等待SD卡稳定
                next_state = st_send_cmd0;
            else
                next_state = st_idle;
        end
        st_send_cmd0 : begin            //发送软件复位命令
            if(cmd_bit_cnt == 6'd47)
                next_state = st_wait_cmd0;
            else
                next_state = st_send_cmd0;      
        end
        st_wait_cmd0 : begin                    //等待SD卡响应
            if(res_en) begin                    //SD卡返回响应信号
                if(res_data[47:40] == 8'h01)    //SD卡返回复位成功
                    next_state = st_send_cmd8;
                else
                    next_state = st_idle;
            end
            else if(over_time_en)               //SD卡响应超时
                next_state = st_idle;
            else
                next_state = st_wait_cmd0;
        end
        //发送主设备电压范围，检测SD卡是否满足
        st_send_cmd8 : begin
            if(res_en) begin                    //SD卡返回响应信号
                //返回SD的操作电压，[19:16] = 4'b0001(2.7V-3.6V)
                if(res_data[19:16] == 4'b0001)
                    next_state = st_send_cmd55;
                else
                    next_state = st_idle;
            end
            else
                next_state = st_send_cmd8;
        end
        //告诉SD卡接下来是应用相关命令
        st_send_cmd55 :begin
            if(res_en) begin
                if(res_data[47:40] == 8'h01) //SD卡返回空闲状态
                    next_state = st_send_acmd41;
                else
                    next_state = st_send_cmd55; 
            end
            else
                next_state = st_send_cmd55;
        end 
        st_send_acmd41 : begin
            if(res_en) begin
                if(res_data[47:40] == 8'h00) //初始化完成信号
                    next_state = st_init_done;
                else
                    next_state = st_send_cmd55; //初始化未完成，重新发起
            end
            else
                next_state = st_send_acmd41;
        end
        st_init_done : next_state = st_init_done;
        default : next_state = st_idle;
    endcase           
end

always @(posedge div_clk or negedge rst_n) begin
    if(!rst_n) begin
        sd_cs <= 1'b1;
        sd_mosi <= 1'b1;
        sd_init_done <= 1'b0;
        cmd_bit_cnt <= 6'd0;
        over_time_cnt <= 16'd0;
        over_time_en <= 1'b0;
    end
    else begin
        over_time_en <= 1'b0;
        case(cur_state)
            st_idle : begin
                sd_cs <= 1'b1;
                sd_mosi <= 1'b1;
            end
            st_send_cmd0 : begin        //发送CMD0软件复位命令
                cmd_bit_cnt <= cmd_bit_cnt + 6'd1;
                sd_cs <= 1'b0;
                sd_mosi <= CMD0[6'd47 - cmd_bit_cnt]; //先发送CMD0命令高位,再发低位
                if(cmd_bit_cnt == 6'd47)
                    cmd_bit_cnt <= 6'd0;
            end
            //在接收CMD0响应返回期间，片选CS拉低，进入SPI模式
            st_wait_cmd0 : begin
                sd_mosi <= 1'b1;
                if(res_en)
                    //接收完成之后拉高，进入SPI模式
                    sd_cs = 1'b1;
                over_time_cnt <= over_time_cnt + 1'b1;  //超时计数器开始计数
                //sd卡超时，重新发送软件复位命令
                if(over_time_cnt == OVER_TIME_NUM - 1'b1)
                    over_time_en <= 1'b1;
                if(over_time_en)
                    over_time_cnt <= 16'd0;
            end
            st_send_cmd8 : begin                //发送CMD8
                if(cmd_bit_cnt <= 6'd47) begin
                    cmd_bit_cnt <= cmd_bit_cnt + 6'd1;
                    sd_cs <= 1'b0;
                    sd_mosi <= CMD8[6'd47 - cmd_bit_cnt]; //还是先发高位
                end
                else begin
                    sd_mosi<= 1'b1;
                    if(res_en) begin            //SD卡返回响应信号
                        sd_cs <= 1'b1;
                        cmd_bit_cnt <= 6'd0;
                    end
                end
            end
            st_send_cmd55 : begin               //发送CMD55
                if(cmd_bit_cnt <= 6'd47)begin
                    cmd_bit_cnt <= cmd_bit_cnt + 6'd1;
                    sd_cs <= 1'b0;
                    sd_mosi <= CMD55[6'd47 - cmd_bit_cnt]; //还是先发高位
                end
                else begin
                    sd_mosi<= 1'b1;
                    if(res_en) begin            //SD卡返回响应信号
                        sd_cs <= 1'b1;
                        cmd_bit_cnt <= 6'd0;
                    end
                end
            end
            st_send_acmd41 : begin          //发送ACMD41
                if(cmd_bit_cnt <= 6'd47)begin
                    cmd_bit_cnt <= cmd_bit_cnt + 6'd1;
                    sd_cs <= 1'b0;
                    sd_mosi <= ACMD41[6'd47 - cmd_bit_cnt]; //还是先发高位
                end
                else begin
                    sd_mosi<= 1'b1;
                    if(res_en) begin            //SD卡返回响应信号
                        sd_cs <= 1'b1;
                        cmd_bit_cnt <= 6'd0;
                    end
                end
            end
            st_init_done : begin //初始化完成
                sd_init_done <= 1'b1;
                sd_cs <= 1'b1;
                sd_mosi <= 1'b1;
            end
            default : begin
                sd_cs <= 1'b1;
                sd_mosi <= 1'b1;
            end
        endcase
    end
end
endmodule
