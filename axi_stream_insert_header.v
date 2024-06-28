module axi_stream_insert_header #(
    parameter DATA_WD = 32,
    parameter DATA_BYTE_WD = DATA_WD / 8,
    parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD)
) (
    input clk,
    input rst_n,
    // AXI Stream input original data
    input valid_in,
    input [DATA_WD-1 : 0] data_in,
    input [DATA_BYTE_WD-1 : 0] keep_in,
    input last_in,
    output  ready_in,
    // AXI Stream output with header inserted
    output reg valid_out,
    output reg [DATA_WD-1 : 0] data_out,
    output reg [DATA_BYTE_WD-1 : 0] keep_out,
    output reg last_out,
    input ready_out,
    // The header to be inserted to AXI Stream input
    input valid_insert,
    input [DATA_WD-1 : 0] data_insert,
    input [DATA_BYTE_WD-1 : 0] keep_insert,
    input [BYTE_CNT_WD-1 : 0] byte_insert_cnt,
    output reg ready_insert
);

reg [31:0]data_out_buf,data_insert_buf,data_in_buf;
reg [3:0]keep_insert_buf,keep_in_buf,last_keep;
reg valid_out_buf,last_in_buf;
reg [2:0]byte_insert_cnt_buf;
reg burst_start,burst_continue,next_last;

assign ready_in = ready_out;    //上游模块ready与下游模块ready和本模块数据处理能力有关，本模块数据处理没有延时，相当于可以一直处理数据

// AXI Stream Head_data通道，握手接收head data
always @(posedge clk)   begin
    if(!rst_n)  begin
        ready_insert <= 1;
        keep_insert_buf <= 0;
        data_insert_buf <= 0;
        byte_insert_cnt_buf <= 0;
    end
    else if(valid_insert && ready_insert)   begin       // 握手成功，拉低ready_insert,等待这次burst传输完成
        ready_insert <= 0;
        data_insert_buf <= data_insert;
        keep_insert_buf <= keep_insert;
        byte_insert_cnt_buf <= byte_insert_cnt;
    end
    else if(last_out)   begin                       // 这次burst传输完成，拉高ready_insert
        ready_insert <= 1;
        data_insert_buf <= 0;
        keep_insert_buf <= 0;
        byte_insert_cnt_buf <= 0;
    end
    else    begin
        ready_insert <= ready_insert;
        data_insert_buf <= data_insert_buf;
        keep_insert_buf <= keep_insert_buf;
        byte_insert_cnt_buf <= byte_insert_cnt_buf;
    end
end

// 开启一次burst传输的标志
always @(posedge clk)   begin
    if(!rst_n)    burst_start <= 0;
    else if(valid_in && ready_in)   burst_start <= 1;
    else if(last_out)   burst_start <= 0;
    else    burst_start <= burst_start;
end

// AXI Stream data 握手接收 data_in和这个通道的其他数据到buf中。并将head data插入到data_in中，生成有效的data_out
always @(posedge clk)   begin
    if(!rst_n)    begin
        data_out_buf <= 0;
        valid_out_buf <= 0;
        data_in_buf <= 0;
        last_in_buf <= 0;
        keep_in_buf <= 0;
        burst_continue <= 0;            // 一次burst传输中被反压之后继续开始传输data的标志
    end
    else if(valid_in && ready_in && ~burst_start &&  ready_insert)  begin       // head与data通道同时开始握手
        data_out_buf <= (data_insert << 32 - byte_insert_cnt * 8) | (data_in >> byte_insert_cnt * 8);
        valid_out_buf <= 1;
        data_in_buf <= data_in; 
        last_in_buf <= last_in;
        keep_in_buf <= keep_in;
        burst_continue <= 0;
    end
    else if(valid_in && ready_in && ~burst_start && ~ready_insert)  begin       // data在head到来之后到来，burst的第一次握手成功
        data_out_buf <= (data_insert_buf << 32 - byte_insert_cnt_buf * 8) | (data_in >> byte_insert_cnt_buf * 8);
        valid_out_buf <= 1;
        data_in_buf <= data_in; 
        last_in_buf <= last_in;
        keep_in_buf <= keep_in;
        burst_continue <= 0;
    end
    else if(valid_in && ready_in && burst_start && burst_continue)  begin     // 被反压之后的第一次握手
        data_out_buf <= data_out_buf;
        valid_out_buf <= 1;
        data_in_buf <= data_in; 
        last_in_buf <= last_in;
        keep_in_buf <= keep_in;
        burst_continue <= 0;
    end
    else if(valid_in && ready_in && burst_start && ~burst_continue)    begin    // 正常握手
        data_out_buf <= (data_in_buf << 32 - byte_insert_cnt_buf * 8) | (data_in >> byte_insert_cnt_buf * 8);
        valid_out_buf <= 1;
        data_in_buf <= data_in;
        last_in_buf <= last_in;
        keep_in_buf <= keep_in;
        burst_continue <= 0;
    end
    else    begin                           // 握手失败---->不接收数据
        data_out_buf <= data_out_buf;
        valid_out_buf <= 0;
        data_in_buf <= data_in_buf;
        last_in_buf <= last_in_buf;
        keep_in_buf <= keep_in_buf;
        burst_continue <= 1;
    end
end


// AXI Stream data_out通道握手 -----> 本模块的valid_out 和 来自下游的ready_out
always  @(posedge clk)   begin
    if(!rst_n)  begin
        data_out <= 0;
        valid_out <= 0;
        last_out <= 0;
        keep_out <= 0; 
        next_last <= 0;  
        last_keep <= 0;    
    end
    else if(valid_out_buf && ready_out && ~next_last) begin        // data_out_buf中的数据有效，且握手成功
        data_out <=  data_out_buf;
        valid_out <= valid_out_buf;
        if(last_in_buf) begin
            if( (keep_in_buf & keep_insert_buf) == 0) begin               //  一次burst的最后一次传输 1000 & 0011 = 0
                last_out <= 1;
                next_last <= 0;
                last_keep <= 0;
                keep_out <= (keep_insert_buf << 4 - byte_insert_cnt_buf) | (keep_in_buf >> byte_insert_cnt_buf);    //1000 0011 ----> 1110
            end
            else    begin                                   // keep_in = 1100 insert = 0111 ,最后一次传不完，还要传一次
                last_out <= 0;
                last_keep <= (keep_in_buf & keep_insert_buf) << 4 - byte_insert_cnt_buf;    // 1110 0011 ----> last_keep = 1000
                next_last <= 1;
                keep_out <= 4'b1111; 
            end
        end 
        else    begin                                  
            last_out <= 0;
            next_last <= 0;
            last_keep <= 0;
            keep_out <= 4'b1111; 
        end         
    end
    else if(valid_out && ready_out && next_last)    begin      // 一次burst的最后一次传输
        data_out <=  data_in_buf << 32 - byte_insert_cnt_buf * 8;
        valid_out <= 1;
        last_out <= 1;
        next_last <= 0;
        keep_out <= last_keep;
    end
    else    begin                       // data通道未握手时输出的data_out和valid_out保持不变
        data_out <= data_out;
        valid_out <= 0;
        last_out <= 0;
        last_keep <= last_keep;
        next_last <= next_last;
        keep_out <= 4'd0;
    end    
end

endmodule
