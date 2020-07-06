`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/07/05 23:08:46
// Design Name: 
// Module Name: led_alarm
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


module led_alarm #(parameter  L_TIME = 25'd25_000_000 //led闪烁时间
    )(  
        //sys clock & rst 
        input           clk         ,
        input           rst_n       ,
        //led interface
        output  [3:0]   led         ,
        //user interface
        input           error_flag  
    );
    
    reg             led_t   ;
    reg     [24:0]  led_cnt ;
    
    //main code
    assign  led = {3'b000, led_t};
    
    //错误时led闪烁，否则常亮
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            led_cnt <= 25'd0;
            led_t <= 1'b0;
        end
        else begin
            if(error_flag) begin
                if(led_cnt == L_TIME -1'b1) begin
                    led_cnt <= 25'd0;
                    led_t <= ~led_t;
                end
                else 
                    led_cnt <= led_cnt + 25'd1;
            end
            else begin
                led_t <= 1'b1;
            end
        end
    end
endmodule
