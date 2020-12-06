module decoder_5_32(
    input  [ 4:0] in,
    output [31:0] out
);

genvar i;
generate for (i=0; i<32; i=i+1) begin : gen_for_dec_5_32
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_6_64(
    input  [ 5:0] in,
    output [63:0] out
);

genvar i;
generate for (i=0; i<64; i=i+1) begin : gen_for_dec_6_64
    assign out[i] = (in == i);
end endgenerate

endmodule

module fifo_buffer #(
    parameter DATA_WIDTH = 32,
    parameter BUFF_DEPTH = 4,
    parameter ADDR_WIDTH = 2
)(
    input                     clk,
    input                     resetn,
    input                     wen,
    input                     ren,
    output                    empty,
    output                    full,
    input  [DATA_WIDTH - 1:0] input_data,
    output [DATA_WIDTH - 1:0] output_data
);
    
reg  [DATA_WIDTH - 1:0] buff [BUFF_DEPTH -1:0];
reg  [ADDR_WIDTH - 1:0] head;
reg  [ADDR_WIDTH - 1:0] tail;
reg  [ADDR_WIDTH - 1:0] count;

wire do_read;
wire do_write;

assign empty        = count == 0;
assign full         = count == (BUFF_DEPTH - 1);
assign do_read      = ren && !empty;
assign do_write     = wen && !full;
assign output_data  = buff[tail];

always @ (posedge clk) begin
    if (!resetn) begin
        count <= 0;
    end else if (do_read && !do_write) begin
        count <= count - 1;
    end else if (do_write && !do_read) begin
        count <= count + 1;
    end
end

always @ (posedge clk) begin
    if (!resetn) begin
        head <= 0;
    end else if (do_write) begin
        if (head == (BUFF_DEPTH - 1)) begin
            head <= 0;
        end else begin
            head <= head + 1;
        end
    end
end

always @ (posedge clk) begin
    if (!resetn) begin
        tail <= 0;
    end else if (do_read) begin
        if (tail == (BUFF_DEPTH - 1)) begin
            tail <= 0;
        end else begin
            tail <= tail + 1;
        end
    end
end

always @ (posedge clk) begin
    if (do_write) begin
        buff[head] <= input_data;
    end
end

endmodule


module fifo_count #(
    parameter BUFF_DEPTH = 4,
    parameter ADDR_WIDTH = 2
)(
    input                     clk,
    input                     resetn,
    input                     wen,
    input                     ren,
    output                    empty,
    output                    full
);
reg  [ADDR_WIDTH - 1:0] count;

wire do_read;
wire do_write;

assign empty        = count == 0;
assign full         = count == (BUFF_DEPTH - 1);
assign do_read      = ren && !empty;
assign do_write     = wen && !full;

always @ (posedge clk) begin
    if (!resetn) begin
        count <= 0;
    end else if (do_read && !do_write) begin
        count <= count - 1;
    end else if (do_write && !do_read) begin
        count <= count + 1;
    end
end

endmodule

module fifo_buffer_valid #(
    parameter DATA_WIDTH = 32,
    parameter BUFF_DEPTH = 4,
    parameter ADDR_WIDTH = 2,
    parameter RLAT_WIDTH = 32
)(
    input                     clk,
    input                     resetn,
    input                     wen,
    input                     ren,
    output                    empty,
    output                    full,
    output                    related_1,
    output                    related_2,
    input  [DATA_WIDTH - 1:0] input_data,
    output [DATA_WIDTH - 1:0] output_data,
    input  [RLAT_WIDTH - 1:0] related_data_1,
    input  [RLAT_WIDTH - 1:0] related_data_2
);
    
reg  [DATA_WIDTH - 1:0] buff    [BUFF_DEPTH -1:0];
reg  [BUFF_DEPTH - 1:0] valid;
wire [BUFF_DEPTH - 1:0] related_vec_1;
wire [BUFF_DEPTH - 1:0] related_vec_2;

reg  [ADDR_WIDTH - 1:0] head;
reg  [ADDR_WIDTH - 1:0] tail;
reg  [ADDR_WIDTH - 1:0] count;

wire do_read;
wire do_write;

assign empty        = count == 0;
assign full         = count == (BUFF_DEPTH - 1);
assign related_1    = |related_vec_1;
assign related_2    = |related_vec_2;
assign do_read      = ren && !empty;
assign do_write     = wen && !full;
assign output_data  = buff[tail];

always @ (posedge clk) begin
    if (!resetn) begin
        count <= 0;
    end else if (do_read && !do_write) begin
        count <= count - 1;
    end else if (do_write && !do_read) begin
        count <= count + 1;
    end
end

always @ (posedge clk) begin
    if (!resetn) begin
        head <= 0;
    end else if (do_write) begin
        if (head == (BUFF_DEPTH - 1)) begin
            head <= 0;
        end else begin
            head <= head + 1;
        end
    end
end

always @ (posedge clk) begin
    if (!resetn) begin
        tail <= 0;
    end else if (do_read) begin
        if (tail == (BUFF_DEPTH - 1)) begin
            tail <= 0;
        end else begin
            tail <= tail + 1;
        end
    end
end

genvar i;
generate for (i = 0; i < BUFF_DEPTH; i = i + 1) begin:gen_buff
    always @ (posedge clk) begin
        if (!resetn) begin
            buff[i]     <= 0;
            valid[i]    <= 0;
        end else if (do_read && tail == i) begin
            buff[i]     <= 0;
            valid[i]    <= 0;
        end else if (do_write && head == i) begin
            buff[i]     <= input_data;
            valid[i]    <= 1;
        end
    end
    assign related_vec_1[i] = 
        valid[i] && related_data_1 == buff[i][RLAT_WIDTH - 1:0];
    assign related_vec_2[i] = 
        valid[i] && related_data_2 == buff[i][RLAT_WIDTH - 1:0];
end endgenerate

endmodule