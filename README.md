# axi_stream_insert_header
本项目主要考察使用AXI-Stream协议传输数据流，上游模块发送数据给下游模块，下游模块没有接收能力时，可以对上游模块进行反压，避免数据流失。
每一个模块都有至少一个AXI-Stream master接口和AXI-Stream slave接口，例如：A--->B--->C，B模块对于A来说是slave,对于B来说是master
本项目要实现的axi_stream_insert_header模块，具有两个slave接口和一个master接口。

Head_insert_data通道：
      1. valid_insert 和 ready_insert 同时拉高时才能接收有效的Head
      2. 因为一次burst传输，只有第一拍data_in前面能插入Head_inset,所以ready_insert在成功握手后拉低，直到本次burst传输完成后拉高。
      3. 该通道的握手要在data_in通道握手之前或者同时握手。
      4. 一次burst中，后面的data要插入前一个data没有传输完的字节。
Data_in 通道：
      1. valid_in 与 ready_in 同时拉高 ----> 接收data,keep_in,last_in
      2. ready_in 与 下游模块的ready_out 和 本模块的接收能力有关，本模块在一个周期中能处理完data_in，所以ready_in就只与ready_out有关了。
      3. 握手接收到的有效data，与Head_insert合并处理，得到data_out，并将data_out放入buf中，等待Data_out通道发送给下游模块。
Data_out 通道：
      1. valid_out 与 ready_out 同时拉高 -----> 发送数据
      2. 握手失败时 valid_out,data_out等数据要保持不变。
