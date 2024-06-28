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

always @(posedge clk)   begin
    if(!rst_n)  data_in <= 0;
    else if(valid_in && ready_in)   data_in <= {$random}%2**(DATA_WD-1)-1; 
    else data_in <= data_in;
end

always @(posedge clk)   begin
    if(!rst_n)  data_insert <= {$random}%2**(DATA_WD-1)-1; 
    else if(valid_insert && ready_insert)   data_insert <= {$random}%2**(DATA_WD-1)-1; 
    else data_insert <= data_insert;
end

reg [9:0]count1;
always @(posedge clk )  begin
    if(!rst_n)  count1 <= 0; 
    else if(count1 == 1023)   count1 <= count1; 
    else count1 <= count1 + 1;
end

// 测试burst无气泡,clk = 16 ---> 22时 valid_in = 1,ready_out = 1;
// 周期在 100 -- 116时 测试反压 ready_out 拉高再拉低再拉高
always @(posedge clk )  begin
    if(!rst_n)  begin
            valid_in <= 0; 
            keep_in <= 0;
            last_in <= 0;
            ready_out <= 1;
    end
    else if(count1 > 15 &&  count1 < 22)   begin
            valid_in <= 1; 
            keep_in <= 4'b1111;
            last_in <= 0;
            ready_out <= 1;
    end
    else if(count1 == 22)   begin
            valid_in <= 1;
            keep_in <= 4'b1100;
            last_in <= 1;
            ready_out <= 1;
    end 
    else if(count1 > 99 && count1 < 108)    begin
            keep_in <= 4'b1111;
            last_in <= 0;
            if(ready_out)   valid_in <= 1;
            else            valid_in <= valid_in;
    end
    else  if(count1 == 108)begin
            valid_in <= 1;
            keep_in <= 4'b1000;
            last_in <= 1;
    end
    else  begin
            valid_in <= 0;
            keep_in <= 0;
            last_in <= 0;
            ready_out <= 1;
    end
end

// clk=104--105  ready_out=0 验证反压
always @(posedge clk)   begin
    if(!rst_n)    ready_out <= 1;
    else if(count1 > 103 && count1 < 106)   ready_out <= 0;
    else ready_out <= 1;
end

always @(posedge clk )  begin
    if(!rst_n)  begin
            valid_insert <= 0; 
            keep_insert <= 0;
            byte_insert_cnt <= 0;
    end
    else if(count1 == 13)   begin        // 验证head data 在data_in之前到来
            valid_insert <= 1; 
            keep_insert <= 4'b0111;
            byte_insert_cnt <= 3'd3;
    end
    else if(count1 == 100)  begin           // head与data_in一起到来
            valid_insert <= 1; 
            keep_insert <= 4'b0011;
            byte_insert_cnt <= 3'd2;
    end
    else    begin
            valid_insert <= 0; 
            keep_insert <= 0;
            byte_insert_cnt <= 0;
    end
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
