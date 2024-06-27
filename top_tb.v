`timescale 1ns / 1ps

module top_tb(

    );

parameter DATA_WD = 32;
parameter DATA_BYTE_WD = DATA_WD / 8;
parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD);

reg clk,rst_n;
reg valid_in;
reg [31:0]data_in;
reg [3:0]keep_in;
reg last_in;
wire ready_in;

wire [31:0]data_out;
wire valid_out;
wire [3:0]keep_out;
wire last_out;
reg  ready_out;

reg valid_insert;
reg [31:0]data_insert;
reg [3:0]keep_insert;
reg [2:0]byte_insert_cnt;
wire ready_insert;

initial     begin
        clk = 1;    rst_n = 0;
    #10 rst_n = 1;
end

always #5 clk = ~clk;

initial begin
          data_in = 32'h0;    valid_in = 0;   keep_in = 0;        last_in = 0;    ready_out = 1;
         
    // burst传输6个data_in数据之后拉低valid_in，burst期间下游ready_out一直为1,验证burst无气泡传输
    #10   data_in = 32'h11111111;    valid_in = 1;   keep_in = 4'b1111;  last_in = 0; ready_out = 1;
    #10   data_in = 32'h22222222;    valid_in = 1;   keep_in = 4'b1111;  last_in = 0; ready_out = 1;
    #10   data_in = 32'h33333333;    valid_in = 1;   keep_in = 4'b1111;  last_in = 0; ready_out = 1;
    #10   data_in = 32'h44444444;    valid_in = 1;   keep_in = 4'b1111;  last_in = 0; ready_out = 1;
    #10   data_in = 32'h55555555;    valid_in = 1;   keep_in = 4'b1111;  last_in = 0; ready_out = 1;
    #10   data_in = 32'h66666666;    valid_in = 1;   keep_in = 4'b1111;  last_in = 1; ready_out = 1;
    #10   data_in = 32'h66666666;    valid_in = 0;   keep_in = 4'b0000;  last_in = 0; ready_out = 1;
    #10   data_in = 32'h77777777;    valid_in = 0;   keep_in = 4'b0000;  last_in = 0; ready_out = 1;
    
    // burst传输过程中来自下游的ready_out拉低两个周期再拉高，进行反压验证
    #100  data_in = 32'h11111111;    valid_in = 1;   keep_in = 4'b1111;  last_in = 0; ready_out = 1;
    #10   data_in = 32'h22222222;    valid_in = 1;   keep_in = 4'b1111;  last_in = 0; ready_out = 1;
    #10   data_in = 32'h33333333;    valid_in = 1;   keep_in = 4'b1111;  last_in = 0; ready_out = 1;
    #10   data_in = 32'h44444444;    valid_in = 1;   keep_in = 4'b1111;  last_in = 0; ready_out = 1;
    #10   data_in = 32'h44444444;    valid_in = 1;   keep_in = 4'b1111;  last_in = 0; ready_out = 0;
    #10   data_in = 32'h44444444;    valid_in = 1;   keep_in = 4'b1111;  last_in = 0; ready_out = 0;
    #10   data_in = 32'h44444444;    valid_in = 1;   keep_in = 4'b1111;  last_in = 0; ready_out = 1;
    #10   data_in = 32'h55555555;    valid_in = 1;   keep_in = 4'b1111;  last_in = 0; ready_out = 1;
    #10   data_in = 32'h66666666;    valid_in = 1;   keep_in = 4'b1111;  last_in = 0; ready_out = 1;
    #10   data_in = 32'h77777777;    valid_in = 1;   keep_in = 4'b1100;  last_in = 1; ready_out = 1;
    #10   data_in = 32'h88888888;    valid_in = 0;   keep_in = 4'b0000;  last_in = 0; ready_out = 1;

end

initial begin
        valid_insert=0;   data_insert=0;  keep_insert=0;  byte_insert_cnt=0;
    #10  valid_insert=1;   data_insert=32'hffffff;  keep_insert=4'b0111;  byte_insert_cnt=3'd3;        //head_insert与data_in同时到来
    #10  valid_insert=0;   data_insert=32'd0;  keep_insert=4'd0;  byte_insert_cnt=3'd0;  
    #150 valid_insert=1;   data_insert=32'hffff;  keep_insert=4'b0011;  byte_insert_cnt=3'd2;         // head_insert在data_in之前到来
    #10  valid_insert=0;   data_insert=32'd0;  keep_insert=4'd0;  byte_insert_cnt=3'd0;
end

axi_stream_insert_header #(
     .DATA_WD (DATA_WD),
     .DATA_BYTE_WD(DATA_BYTE_WD),
     .BYTE_CNT_WD (BYTE_CNT_WD)
) axi_stream_insert_header_U1 (
            .clk                    (   clk             ),
            .rst_n                  (   rst_n           ),   
            .valid_in               (   valid_in        ),
            .data_in                (   data_in         ),
            .keep_in                (   keep_in         ),
            .last_in                (   last_in         ),
            .ready_in               (   ready_in        ),
            .valid_out              (   valid_out       ),
            .data_out               (   data_out        ),
            .keep_out               (   keep_out        ),
            .last_out               (   last_out        ),
            .ready_out              (   ready_out       ),
            .valid_insert           (   valid_insert    ),
            .data_insert            (   data_insert     ),
            .keep_insert            (   keep_insert     ),
            .byte_insert_cnt        (   byte_insert_cnt ),
            .ready_insert           (   ready_insert    )    
);

endmodule