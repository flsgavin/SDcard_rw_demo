`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/07/06 01:59:03
// Design Name: 
// Module Name: sd_read
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


module sd_read(
    input               clk_ref         ,
    input               clk_ref_180deg  ,
    input               rst_n           ,
    //SD���ӿ�
    input               sd_miso         ,
    output      reg     sd_cs           ,
    output      reg     sd_mosi         ,
    //�û����ӿ�
    input               rd_start_en     ,       //��ʼ��SD�������ź�
    input       [31:0]  rd_sec_addr     ,       
    output      reg     rd_busy         ,       //������æ�ź�
    output      reg     rd_val_en       ,       //��������Ч�ź�
    output  reg [15:0]  rd_val_data             //������
    );
    
//reg define
reg                 rd_en_d0            ;
reg                 rd_en_d1            ;
reg                 res_en              ;
reg     [7:0]       res_data            ;  //д���ݷ���R1,8bit
reg                 res_flag            ;
reg     [5:0]       res_bit_cnt         ;

reg                 rx_en_t             ;   //����SD������ʹ���ź�
reg     [15:0]      rx_data_t           ;   //����SD������
reg                 rx_flag             ;       
reg     [3:0]       rx_bit_cnt          ;   //��������λ������
reg     [8:0]       rx_data_cnt         ;   //�������ݸ���������
reg                 rx_finish_en        ;   //�������ʹ���ź�

reg     [3:0]       rd_ctrl_cnt         ;
reg     [47:0]      cmd_rd              ;   //������
reg     [5:0]       cmd_bit_cnt         ;
reg                 rd_data_flag        ;

//wire defibe 
wire                pos_rd_en           ;   //��ʼ��SD�������ź�������

//main code
assign pos_rd_en = (~rd_en_d1) & rd_en_d0;


//rd_start_en�ź��ӳٴ���
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        rd_en_d0 <= 1'b0;
        rd_en_d1 <= 1'b0;
    end
    else begin
        rd_en_d0 <= rd_start_en;
        rd_en_d1 <= rd_en_d0;
    end
end

//����SD�����ص���Ӧ����
always @(posedge clk_ref_180deg or negedge rst_n) begin
    if(!rst_n) begin
        res_en <= 1'b0;
        res_data <= 8'd0;
        res_flag <= 1'b0;
        res_bit_cnt <= 6'd0;
    end
    else begin
        //sd_miso = 0 ��ʼ������Ӧ����
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


//����SD����Ч����
always @(posedge clk_ref_180deg or negedge rst_n) begin
    if(!rst_n) begin
        rx_en_t <= 1'b0;
        rx_data_t <= 16'd0;
        rx_flag <= 1'b0;
        rx_bit_cnt <= 4'd0;
        rx_data_cnt <= 9'd0;
        rx_finish_en <= 1'b0;
    end
    else begin
        rx_en_t <= 1'b0;
        rx_finish_en <= 1'b0;
        //����ͷ0xfe (1111_1110),��˼��0Ϊ������ʼλ, sd_miso == 1'b0
        if(rd_data_flag && sd_miso == 1'b0 && rx_flag == 1'b0)
            rx_flag <= 1'b1;
        else if(rx_flag) begin
            rx_bit_cnt <= rx_bit_cnt + 4'd1;
            rx_data_t <= {rx_data_t[14:0], sd_miso};
            if(rx_bit_cnt == 4'd15) begin
                rx_data_cnt <= rx_data_cnt + 9'd1;
                //����BLOCKΪ512�ֽ� = 256 * 16bit
                if(rx_data_cnt <= 9'd255)
                    rx_en_t <= 1'b1;
                else if(rx_data_cnt == 9'd257) begin    //2 byte CRC
                    rx_flag <= 1'b0;
                    rx_finish_en <= 1'b1;
                    rx_data_cnt <= 9'd0;
                    rx_bit_cnt <= 4'd0;
                end
            end
        end
        else
            rx_data_t <= 16'd0;
    end
end

//�Ĵ������������Ч�źź�����
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        rd_val_en <= 1'b0;
        rd_val_data <= 16'd0;
    end
    else begin
        if(rx_en_t) begin
            rd_val_en <= 1'b1;
            rd_val_data <= rx_data_t;
        end
        else
            rd_val_en <= 1'b0;
    end
end

//������
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        sd_cs <= 1'b1;
        sd_mosi <= 1'b1;
        rd_ctrl_cnt <= 4'd0;
        cmd_rd <= 48'd0;
        cmd_bit_cnt <= 6'd0;
        rd_busy <= 1'd0;
        rd_data_flag <= 1'b0;
    end
    else begin
        case(rd_ctrl_cnt)
            4'd0 : begin
                rd_busy <= 1'b0;
                sd_cs <= 1'b1;
                sd_mosi <= 1'b1;
                if(pos_rd_en) begin
                    cmd_rd <= {8'h51, rd_sec_addr, 8'hff};  //CMD17
                    rd_ctrl_cnt <= rd_ctrl_cnt + 4'd1;      //���Ƽ�������һ
                    rd_busy <= 1'b1;                        //���߶�æ�ź�
                end
            end
            4'd1 : begin
                if(cmd_bit_cnt <= 6'd47) begin
                    cmd_bit_cnt <= cmd_bit_cnt + 6'd1;      //��λ���Ͷ�����
                    sd_cs <= 1'b0;
                    sd_mosi <= cmd_rd[6'd47 - cmd_bit_cnt]; //�ȷ����ֽ�                    
                end
                else begin
                    sd_mosi <= 1'b1;
                    if(res_en) begin                        //SD����Ӧ
                        rd_ctrl_cnt <= rd_ctrl_cnt + 4'd1;
                        cmd_bit_cnt <= 6'd0;
                    end
                end
            end
            4'd2 : begin
                //����rd_data_flag�źţ�׼����������
                rd_data_flag <= 1'b1;
                if(rx_finish_en) begin                      //���ݽ������
                    rd_ctrl_cnt <=  rd_ctrl_cnt + 4'd1;  
                    rd_data_flag <= 1'b0;
                    sd_cs <= 1'b1;   
                end
            end
            default : begin
                //�������״̬������Ƭѡ�źţ��ȴ�8��ʱ������
                sd_cs <= 1'b1;
                rd_ctrl_cnt <=  rd_ctrl_cnt + 4'd1;  
            end
        endcase
    end
end

endmodule
