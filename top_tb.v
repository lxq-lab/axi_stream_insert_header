`timescale 1ns / 1ps
module top_tb(

    );

    parameter DATA_WD = 32;
    parameter DATA_BYTE_WD = DATA_WD / 8;
    parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD);
    
    reg                                     clk;
    reg                                     rst_n;
    
    // Data_in通道端口
    reg                                     valid_in;
    reg         [DATA_WD-1:0]               data_in;
    reg         [DATA_BYTE_WD-1:0]          keep_in;
    reg                                     last_in;
    wire                                    ready_in;
    
    // Data_out通道端口
    wire        [DATA_WD-1:0]               data_out;
    wire                                    valid_out;
    wire        [DATA_BYTE_WD-1:0]          keep_out;
    wire                                    last_out;
    reg                                     ready_out;
    
    // Head_insert 通道端口
    reg                                     valid_insert;
    reg         [DATA_WD-1:0]               data_insert;
    reg         [DATA_BYTE_WD-1:0]          keep_insert;
    reg         [BYTE_CNT_WD:0]             byte_insert_cnt;
    wire                                    ready_insert;
    
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
    
    // 时钟和复位
    initial     begin
            clk = 1;    rst_n = 0;
        #10 rst_n = 1;
    end
   
    always  #5 clk = ~clk;

    /////////////////////////////////// Data_in通道的随机激励 ////////////////////////////////
    
    // 随机拉高valid_in
    reg         [DATA_BYTE_WD-1:0]      valid_random;
    always@(posedge clk)    begin
        valid_random = {$random}%10;
        if(ready_in)    begin
            repeat (valid_random) @(posedge clk);
            valid_in <= 0;
            repeat (1) @(posedge clk);
            valid_in <= 1;
        end
        else    begin                       // 握手失败时valid_in要保持不变
            valid_in <= valid_in;
        end
    end
    
    // 随机拉高 ready_out
    reg     [DATA_BYTE_WD-1:0]      ready_out_random;
    always@(posedge clk)    begin
         ready_out_random = $random % 10;
         repeat (ready_out_random) @(posedge clk);
         ready_out <= 0;
         repeat (1) @(posedge clk);
         ready_out <= 1;
    end
    
    reg         [DATA_BYTE_WD-1:0]      burst_trans_cnt;            // 一次突发传输传递几个数据（在20个以内）
    reg                                 start_burst;                // 开始突发传输的标志
    reg         [DATA_BYTE_WD-1:0]      trans_cnt;                  //  已经传输的个数
    
    always@(posedge clk)    begin
        if(!rst_n)      burst_trans_cnt <= 0;
        else if((trans_cnt == 0) && ready_in && valid_in)   burst_trans_cnt <= {$random}%20;     // 开启burst传输，加载一次burst_trans_cnt
        else            burst_trans_cnt <= burst_trans_cnt;
    end
    
    // 随机产生last_data的keep
    reg         [BYTE_CNT_WD:0]         last_keep_cnt;
    always @(posedge clk)   begin   
        if(!rst_n)      last_keep_cnt <= 0;
        else if(trans_cnt == 0)     last_keep_cnt <= {$random}%4;
        else            last_keep_cnt <= last_keep_cnt;
    end
    
    always @(posedge clk)   begin
        if(!rst_n)  begin
            data_in <= 0;
            last_in <= 0;
            trans_cnt <= 0;    
            keep_in <= 4'b1111;
            start_burst <= 0;  
        end
        else if(ready_in && valid_in)   begin                       // 握手成功
            trans_cnt <= trans_cnt + 1;     
            if(trans_cnt == burst_trans_cnt + 1)  begin             // 最后一个data_in
                    data_in <= {$random}%2**(DATA_WD-1)-1;  
                    keep_in <= 4'b1111 << (4 - last_keep_cnt);
                    last_in <= 1;
                    start_burst <= 1;  
            end
            else if(start_burst)    begin                              // 一次burst传输完成后
                    data_in <= 0;  
                    last_in <= 0;
                    keep_in <= 4'b1111;
                    trans_cnt <= 0;
                    start_burst <= 0;      
            end
            else    begin
                    data_in <= {$random}%2**(DATA_WD-1)-1; 
                    keep_in <= 4'b1111;
                    last_in <= 0;
                    start_burst <= 0;      
            end
        end
        else    begin                       // 握手失败，下游不能接收数据，所有数据保持不变
            data_in <= data_in;
            keep_in <= keep_in;
            last_in <= last_in; 
            trans_cnt <= trans_cnt; 
            start_burst <= start_burst;     
        end
    end
      
    ///////////////////////////////  Head_inset 通道的激励 ///////////////////////// 
    
    reg         [DATA_BYTE_WD-1:0]      insert_valid_random;
    always@(posedge clk)    begin
        insert_valid_random = {$random}%10;
        if(ready_insert)    begin
            repeat (insert_valid_random) @(posedge clk);
            valid_insert <= 0;
            repeat (1) @(posedge clk);
            valid_insert <= 1;
        end
        else    begin                           // 握手失败时valid_insert要保持不变
            valid_insert <= valid_insert;
        end
    end
    
    // 随机产生byte_insert_cnt 
    always @(posedge clk)   begin
        if(!rst_n)  begin
            data_insert <= {$random}%2**(DATA_WD-1)-1;
            keep_insert <= 4'b0111;
            byte_insert_cnt <= 1;
        end
        else if(valid_insert && ready_insert)   begin       // 握手成功，换新值
            data_insert <= {$random}%2**(DATA_WD-1)-1;
            keep_insert <= 4'b0011;
            byte_insert_cnt <= 2;
        end
        else    begin               // 握手失败，保持不变
            data_insert <= data_insert; 
            keep_insert <= keep_insert;
            byte_insert_cnt <= byte_insert_cnt;
        end     
    end
    
endmodule
