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
    //SD���ӿ�
    input               sd_miso         ,
    output      reg     sd_cs           ,
    output      reg     sd_mosi         ,
    //�û�д�ӿ�
    input               wr_start_en     ,
    input       [31:0]  wr_sec_addr     ,
    input       [15:0]  wr_data         ,
    output      reg     wr_busy         ,
    output      reg     wr_req   
    );
    
parameter   HEAD_BYTE = 8'hfe;  //����ͷ

//reg define
reg                 wr_en_d0            ;
reg                 wr_en_d1            ;
reg                 res_en              ;
reg     [7:0]       res_data            ;  //д���ݷ���R1,8bit
reg                 res_flag            ;
reg     [5:0]       res_bit_cnt         ;

reg     [3:0]       wr_ctrl_cnt         ;
reg     [47:0]      cmd_wr              ;   //д����
reg     [5:0]       cmd_bit_cnt         ;   //д����λ������
reg     [3:0]       bit_cnt             ;   //д����λ������
reg     [8:0]       data_cnt            ;   //д����������
reg     [15:0]      wr_data_t           ;
reg                 detect_done_flag    ;
reg     [7:0]       detect_data         ;

//wire define
wire                pos_wr_en           ;

//main code

assign pos_wr_en = (~wr_en_d1) & wr_en_d0;

//wr_start_en�ź��ӳٴ���
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

//д�����ݺ���SD���Ƿ����
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n)
        detect_data <= 8'd0;
    else if(detect_done_flag)
        detect_data <= {detect_data[6:0], sd_miso};
    else
        detect_data <= 8'd0;
end

//SD��д������
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
                    //��ʼд�����ݣ�����дæ�ź�
                    wr_busy <= 1'b1;
                end
            end
            4'd1 : begin
                if(cmd_bit_cnt <= 6'd47) begin
                    cmd_bit_cnt <= cmd_bit_cnt + 6'd1;
                    sd_cs <= 1'b0;
                    sd_mosi <= cmd_wr[6'd47 - cmd_bit_cnt]; //�ȷ����ֽ�
                end
                else begin
                    sd_mosi <= 1'b1;
                    if(res_en) begin        //SD����Ӧ
                        wr_ctrl_cnt <= wr_ctrl_cnt + 4'd1;  //���Ƽ�������һ
                        cmd_bit_cnt <= 6'd0;
                        bit_cnt <= 4'd1;        //��ʱ������һ��ʱ������
                    end
                end
            end
            4'd2 : begin
                bit_cnt <= bit_cnt + 4'd1;
                //bit_cnt 0~7 �ȴ�8��ʱ������
                //bit_cnt 8~15 д������ͷ8'hfe
                if(bit_cnt >= 4'd8 && bit_cnt <= 4'd15) begin
                    sd_mosi <= HEAD_BYTE[4'd15 - bit_cnt];  //�ȷ����ֽ�
                    if(bit_cnt == 4'd14)
                        wr_req <= 1'b1;             //��ǰ����д���������ź�
                    else if(bit_cnt == 4'd15)
                        wr_ctrl_cnt <= wr_ctrl_cnt + 4'd1; //���Ƽ�������һ
                end                
            end
            4'd3 : begin                        //д������
                bit_cnt <= bit_cnt + 4'd1;
                if(bit_cnt == 4'd0) begin       //��һ��step�����Ϊ0
                    sd_mosi <= wr_data[4'd15-bit_cnt];  //�ȷ������ݸ�λ
                    wr_data_t <= wr_data;        //�ݴ�����,��ֹ����仯
                end
                else
                    sd_mosi <= wr_data_t[4'd15 - bit_cnt];
                if((bit_cnt == 4'd14) && (data_cnt <= 9'd255))  //data_cnt���ڼ�¼�����˶��ٸ�16bit
                    wr_req <= 1'b1; 
                if(bit_cnt == 4'd15) begin
                    data_cnt <= data_cnt + 9'd1;
                    //д�뵥��BLOCK��512Byte�� 256 * 16bit
                    if(data_cnt == 9'd255) begin
                        data_cnt <= 9'd0;
                        //д��������ɣ����Ƽ�������һ
                        wr_ctrl_cnt <= wr_ctrl_cnt + 4'd1;
                    end
                end
            end
            //д��2�ֽ�CRC��SPIģʽ��ֱ��д��0xff
            4'd4 : begin
                bit_cnt <= bit_cnt + 4'd1;
                sd_mosi <= 1'b1;
                //CRCд����ɣ����Ƽ�������һ
                if(bit_cnt == 4'd15)
                    wr_ctrl_cnt <= wr_ctrl_cnt + 4'd1;
            end
            //SD����Ӧ
            4'd5 : begin
                if(res_en)
                    wr_ctrl_cnt <= wr_ctrl_cnt + 4'd1;
            end
            //�ȴ�д���
            4'd6 : begin
                detect_done_flag <= 1'b1;
                //detect_data = 0xffʱ��SD��д����ɣ��������״̬
                if(detect_data == 8'hff) begin
                    wr_ctrl_cnt <= wr_ctrl_cnt + 4'd1;
                    detect_done_flag <= 1'b0;
                end
            end
            default : begin
                //�������״̬������Ƭѡ�źţ��ȴ�8��ʱ������
                sd_cs <= 1'b1;
                wr_ctrl_cnt = wr_ctrl_cnt + 4'd1;
            end
        endcase
    end    
end
endmodule
