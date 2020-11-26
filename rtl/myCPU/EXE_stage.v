`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // from ms
    input                          ms_inst_unable,
    // data sram interface
    // output        data_sram_en   ,
    // output [ 3:0] data_sram_wen  ,
    // output [31:0] data_sram_addr ,
    // output [31:0] data_sram_wdata,
    output          data_sram_req,
    output          data_sram_wr,
    output  [ 1:0]  data_sram_size,
    output  [31:0]  data_sram_wdata,
    output  [ 3:0]  data_sram_wstrb,
    output  [31:0]  data_sram_addr,
    input           data_sram_addr_ok,
    input   [31:0]  data_sram_rdata,
    input           data_sram_data_ok,
    output          es_data_waiting, 

    //block
    output                          es_inst_mfc0_o ,

    // forword & block from es
    output [`ES_FWD_BLK_BUS_WD -1:0] es_fwd_blk_bus,    

    //exception
    input                           ws_ex        ,
    input                           ms_ex        ,
    input                           ms_eret      ,
    input                           ws_eret
);

reg         es_valid      ;
wire        es_ready_go   ;

reg  [31:0] reg_LO;
reg  [31:0] reg_HI;
wire        reg_LO_we;
wire        reg_HI_we;
wire [31:0] reg_LO_wdata;
wire [31:0] reg_HI_wdata;
wire [31:0] reg_LO_rdata;
wire [31:0] reg_HI_rdata;
wire [7:0]  es_cp0_addr;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire        es_inst_lb     ;
wire        es_inst_lbu    ;
wire        es_inst_lh     ;
wire        es_inst_lhu    ;
wire        es_inst_lw     ;
wire        es_inst_lwl    ;
wire        es_inst_lwr    ;
wire        es_inst_sb     ;
wire        es_inst_sh     ;
wire        es_inst_sw     ;
wire        es_inst_swl    ;
wire        es_inst_swr    ;
wire        es_inst_div    ;
wire        es_inst_divu   ;
wire        es_inst_mult   ;
wire        es_inst_multu  ;
wire        es_inst_mfhi   ;
wire        es_inst_mthi   ;
wire        es_inst_mflo   ;
wire        es_inst_mtlo   ;
wire [11:0] es_alu_op     ;
wire        es_load_op    ;
wire        es_src1_is_sa ;  
wire        es_src1_is_pc ;
wire        es_src2_is_imm; 
wire        es_src2_is_8  ;
wire        es_gr_we      ;
wire        es_mem_we     ;
wire        es_mem_re     ;
wire [ 4:0] es_dest       ;
wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;

wire [4:0] es_excode;
wire [31:0] es_badvaddr;

wire    es_ex;
wire    es_bd;
wire    es_inst_eret;
wire    es_inst_syscall;  
wire    es_inst_mfc0;
wire    es_inst_mtc0;
wire    no_store;  
assign no_store = ms_ex | ws_ex | es_ex | ms_eret | ws_eret;
// assign no_store = ms_ex | ws_ex | es_ex;

wire [4:0] ds_to_es_excode;
wire [31:0] ds_to_es_badvaddr;


assign {
    fs_to_ds_ex  ,    //210:210
    overflow_inst,    //209:209
    ds_to_es_excode,  //208:204
    ds_to_es_badvaddr, //203:172
    es_cp0_addr    ,  //171:164
    ds_to_es_ex    ,  //163:163
    ds_to_es_bd    ,  //162:162
    es_inst_eret   ,  //161:161
    es_inst_syscall,  //160:160
    es_inst_mfc0   ,  //159:159
    es_inst_mtc0   ,  //158:158
    es_inst_lb     ,  //157:157
    es_inst_lbu    ,  //156:156
    es_inst_lh     ,  //155:155
    es_inst_lhu    ,  //154:154
    es_inst_lw     ,  //153:153
    es_inst_lwl    ,  //152:152
    es_inst_lwr    ,  //151:151
    es_inst_sb     ,  //150:150
    es_inst_sh     ,  //149:149
    es_inst_sw     ,  //148:148
    es_inst_swl    ,  //147:147
    es_inst_swr    ,  //146:146
    es_inst_div    ,  //145:145
    es_inst_divu   ,  //144:144
    es_inst_mult   ,  //143:143
    es_inst_multu  ,  //142:142
    es_inst_mthi   ,  //141:141
    es_inst_mfhi   ,  //140:140
    es_inst_mtlo   ,  //139:139
    es_inst_mflo   ,  //138:138
    es_alu_op      ,  //137:126
    es_load_op     ,  //125:125
    es_src1_is_sa  ,  //124:124
    es_src1_is_pc  ,  //123:123
    es_src2_is_imm ,  //122:122
    es_src2_is_uimm,  //121:121
    es_src2_is_8   ,  //120:120
    es_gr_we       ,  //119:119
    es_mem_we      ,  //118:118
    es_mem_re      ,  //117:117
    es_dest        ,  //116:112
    es_imm         ,  //111:96
    es_rs_value    ,  //95 :64
    es_rt_value    ,  //63 :32
    es_pc             //31 :0
} = ds_to_es_bus_r;

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;
wire [31:0] es_exe_result;

wire    es_wait_mem;                    // TODO
wire    es_res_from_mem;

reg         es_addr_ok_r;
wire        es_addr_ok;

reg         es_data_buff_valid;
reg  [31:0] es_data_buff;
wire        es_data_ok;
wire [31:0] es_data;

wire        es_data_sram_data_ok;

assign es_res_from_mem  = es_load_op;
assign es_res_from_LO   = es_inst_mflo;
assign es_res_from_HI   = es_inst_mfhi;

assign es_exe_result = 
    es_res_from_LO  ? reg_LO_rdata  :
    es_res_from_HI  ? reg_HI_rdata  :
    es_inst_mtc0    ? es_rt_value   :
    es_alu_result;

assign es_to_ms_bus = {
    es_data_ok      ,  //162:162
    es_data         ,  //161:130
    es_excode       ,  //129:125
    es_badvaddr     ,  //124:93
    es_cp0_addr     ,  //92:85
    es_ex           ,  //84:84
    es_bd           ,  //83:83
    es_inst_eret    ,  //82:82
    es_inst_syscall ,  //81:81
    es_inst_mfc0    ,  //80:80
    es_inst_mtc0    ,  //79:79
    es_inst_lb      ,  //78:78
    es_inst_lbu     ,  //77:77
    es_inst_lh      ,  //76:76
    es_inst_lhu     ,  //75:75
    es_inst_lw      ,  //74:74
    es_inst_lwl     ,  //73:73
    es_inst_lwr     ,  //72:72
    es_wait_mem     ,  //71:71
    es_res_from_mem ,  //70:70
    es_gr_we        ,  //69:69
    es_dest         ,  //68:64
    es_exe_result   ,  //63:32
    es_pc              //31:0
};

wire [ 3:0] es_fwd_valid;
wire [ 4:0] es_rf_dest;
wire [31:0] es_rf_data;
wire        es_blk_valid;

assign es_fwd_blk_bus = {
    es_fwd_valid,   // 41:38
    es_rf_dest,     // 37:33
    es_rf_data,     // 32:1
    es_blk_valid    // 0:0
};

assign es_alu_src1 = es_src1_is_sa  ? {27'b0, es_imm[10:6]} : 
                     es_src1_is_pc  ? es_pc[31:0] :
                                      es_rs_value;
assign es_alu_src2 = es_src2_is_imm  ? {{16{es_imm[15]}}, es_imm[15:0]} : 
                     es_src2_is_uimm ? {{16{1'b0      }}, es_imm[15:0]} :
                     es_src2_is_8    ? 32'd8 :
                                      es_rt_value;

wire overflow;

alu u_alu(
    .alu_op     (es_alu_op    ),
    .alu_src1   (es_alu_src1  ),
    .alu_src2   (es_alu_src2  ),
    .alu_result (es_alu_result),
    .overflow   (overflow)
    );

// Mult & Multu
wire [31:0] mult_src1;
wire [31:0] mult_src2;
wire [63:0] unsigned_mult_res;
wire [63:0] signed_mult_res;

assign mult_src1 = es_rs_value;
assign mult_src2 = es_rt_value;

assign unsigned_mult_res = mult_src1 * mult_src2;
assign signed_mult_res   = $signed(mult_src1) * $signed(mult_src2);

// Div & Divu
wire [31:0] divider_dividend;
wire [31:0] divider_divisor;
wire [63:0] unsigned_divider_res;
wire [63:0] signed_divider_res;

assign divider_dividend = es_rs_value;
assign divider_divisor  = es_rt_value;

wire unsigned_dividend_tready;
wire unsigned_dividend_tvalid;
wire unsigned_divisor_tready;
wire unsigned_divisor_tvalid;
wire unsigned_dout_tvalid;

wire signed_dividend_tready;
wire signed_dividend_tvalid;
wire signed_divisor_tready;
wire signed_divisor_tvalid;
wire signed_dout_tvalid;

unsigned_divider u_unsigned_divider (
    .aclk                   (clk),
    .s_axis_dividend_tdata  (divider_dividend),
    .s_axis_dividend_tready (unsigned_dividend_tready),
    .s_axis_dividend_tvalid (unsigned_dividend_tvalid),
    .s_axis_divisor_tdata   (divider_divisor),
    .s_axis_divisor_tready  (unsigned_divisor_tready),
    .s_axis_divisor_tvalid  (unsigned_divisor_tvalid),
    .m_axis_dout_tdata      (unsigned_divider_res),
    .m_axis_dout_tvalid     (unsigned_dout_tvalid)
);

signed_divider u_signed_divider (
    .aclk                   (clk),
    .s_axis_dividend_tdata  (divider_dividend),
    .s_axis_dividend_tready (signed_dividend_tready),
    .s_axis_dividend_tvalid (signed_dividend_tvalid),
    .s_axis_divisor_tdata   (divider_divisor),
    .s_axis_divisor_tready  (signed_divisor_tready),
    .s_axis_divisor_tvalid  (signed_divisor_tvalid),
    .m_axis_dout_tdata      (signed_divider_res),
    .m_axis_dout_tvalid     (signed_dout_tvalid)
);

// Divider status control
reg  unsigned_dividend_sent;
reg  unsigned_divisor_sent;
reg  unsigned_divider_done;

assign unsigned_dividend_tvalid = es_valid && es_inst_divu && !unsigned_dividend_sent;
assign unsigned_divisor_tvalid = es_valid && es_inst_divu && !unsigned_divisor_sent;

always @ (posedge clk) begin
    if (reset) begin
        unsigned_dividend_sent <= 1'b0;
    end else if (unsigned_dividend_tready && unsigned_dividend_tvalid) begin
        unsigned_dividend_sent <= 1'b1;
    end else if (es_ready_go && ms_allowin) begin
        unsigned_dividend_sent <= 1'b0;
    end
    
    if (reset) begin
        unsigned_divisor_sent <= 1'b0;
    end else if (unsigned_divisor_tready && unsigned_divisor_tvalid) begin
        unsigned_divisor_sent <= 1'b1;
    end else if (es_ready_go && ms_allowin) begin
        unsigned_divisor_sent <= 1'b0;
    end

    if (reset) begin
        unsigned_divider_done <= 1'b0;
    end else if (es_ready_go && !ms_allowin) begin
        unsigned_divider_done <= 1'b1;
    end else if (ms_allowin) begin
        unsigned_divider_done <= 1'b0;
    end
end

reg  signed_dividend_sent;
reg  signed_divisor_sent;
reg  signed_divider_done;

assign signed_dividend_tvalid = es_valid && es_inst_div && !signed_dividend_sent;
assign signed_divisor_tvalid = es_valid && es_inst_div && !signed_divisor_sent;

always @ (posedge clk) begin
    if (reset) begin
        signed_dividend_sent <= 1'b0;
    end else if (signed_dividend_tready && signed_dividend_tvalid) begin
        signed_dividend_sent <= 1'b1;
    end else if (es_ready_go && ms_allowin) begin
        signed_dividend_sent <= 1'b0;
    end
    
    if (reset) begin
        signed_divisor_sent <= 1'b0;
    end else if (signed_divisor_tready && signed_divisor_tvalid) begin
        signed_divisor_sent <= 1'b1;
    end else if (es_ready_go && ms_allowin) begin
        signed_divisor_sent <= 1'b0;
    end

    if (reset) begin
        signed_divider_done <= 1'b0;
    end else if (es_ready_go && !ms_allowin) begin
        signed_divider_done <= 1'b1;
    end else if (ms_allowin) begin
        signed_divider_done <= 1'b0;
    end
end


// LO & HI
always @ (posedge clk) begin
    if (reg_LO_we) begin
        reg_LO <= reg_LO_wdata;
    end
    if (reg_HI_we) begin
        reg_HI <= reg_HI_wdata;
    end
end

assign reg_LO_we = es_valid && !no_store && (
    es_inst_mtlo || es_inst_mult || es_inst_multu ||
    (es_inst_div  && signed_dout_tvalid)          ||
    (es_inst_divu && unsigned_dout_tvalid)
);
assign reg_HI_we = es_valid && !no_store && (
    es_inst_mthi || es_inst_mult || es_inst_multu ||
    (es_inst_div  && signed_dout_tvalid)          ||
    (es_inst_divu && unsigned_dout_tvalid)
);

assign reg_LO_wdata =
    es_inst_mult    ? signed_mult_res       [31:0]  :
    es_inst_multu   ? unsigned_mult_res     [31:0]  :
    es_inst_div     ? signed_divider_res    [63:32] :
    es_inst_divu    ? unsigned_divider_res  [63:32] :
    es_rs_value;

assign reg_HI_wdata =
    es_inst_mult    ? signed_mult_res       [63:32] :
    es_inst_multu   ? unsigned_mult_res     [63:32] :
    es_inst_div     ? signed_divider_res    [31:0]  :
    es_inst_divu    ? unsigned_divider_res  [31:0]  :
    es_rs_value;

assign reg_LO_rdata = reg_LO;
assign reg_HI_rdata = reg_HI;

// MEM
wire [ 1:0] st_addr;

wire [31:0] st_data;
wire [31:0] swl_data;
wire [31:0] swr_data;

wire [ 3:0] st_strb;
wire [ 3:0] sw_strb;
wire [ 3:0] sh_strb;
wire [ 3:0] sb_strb;
wire [ 3:0] swl_strb;
wire [ 3:0] swr_strb;

wire [ 1:0] lwl_swl_size;
wire [ 1:0] lwr_swr_size;


assign st_addr = es_alu_result[1:0];

assign st_data = 
    ( {32{es_inst_sb }} & {4{ es_rt_value[ 7:0] }} ) |
    ( {32{es_inst_sh }} & {2{ es_rt_value[15:0] }} ) |
    ( {32{es_inst_sw }} & es_rt_value              ) |
    ( {32{es_inst_swl}} & swl_data                 ) |
    ( {32{es_inst_swr}} & swr_data                 );

assign swl_data = 
    ( {32{st_addr == 2'b00}} & {24'b0, es_rt_value[31:24]} ) |
    ( {32{st_addr == 2'b01}} & {16'b0, es_rt_value[31:16]} ) |
    ( {32{st_addr == 2'b10}} & { 8'b0, es_rt_value[31: 8]} ) |
    ( {32{st_addr == 2'b11}} &         es_rt_value[31: 0]  );

assign swr_data = 
    ( {32{st_addr == 2'b00}} &  es_rt_value[31: 0]         ) |
    ( {32{st_addr == 2'b01}} & {es_rt_value[23: 0],  8'b0} ) |
    ( {32{st_addr == 2'b10}} & {es_rt_value[15: 0], 16'b0} ) |
    ( {32{st_addr == 2'b11}} & {es_rt_value[ 7: 0], 24'b0} );

assign st_strb = 
    ( {4{es_inst_sb }} & sb_strb    ) |
    ( {4{es_inst_sh }} & sh_strb    ) |
    ( {4{es_inst_sw }} & sw_strb    ) |
    ( {4{es_inst_swl}} & swl_strb  ) |
    ( {4{es_inst_swr}} & swr_strb );

assign sb_strb = 
    ( {4{st_addr == 2'b00}} & 4'b0001 ) |
    ( {4{st_addr == 2'b01}} & 4'b0010 ) |
    ( {4{st_addr == 2'b10}} & 4'b0100 ) |
    ( {4{st_addr == 2'b11}} & 4'b1000 );

assign sh_strb = 
    ( {4{st_addr == 2'b00}} & 4'b0011 ) |
    ( {4{st_addr == 2'b10}} & 4'b1100 );

assign sw_strb = 4'b1111;

assign swl_strb = 
    ( {4{st_addr == 2'b00}} & 4'b0001 ) |
    ( {4{st_addr == 2'b01}} & 4'b0011 ) |
    ( {4{st_addr == 2'b10}} & 4'b0111 ) |
    ( {4{st_addr == 2'b11}} & 4'b1111 );

assign swr_strb = 
    ( {4{st_addr == 2'b00}} & 4'b1111 ) |
    ( {4{st_addr == 2'b01}} & 4'b1110 ) |
    ( {4{st_addr == 2'b10}} & 4'b1100 ) |
    ( {4{st_addr == 2'b11}} & 4'b1000 );

assign lwl_swl_size =
    ( {2{st_addr == 2'h0}} & 2'h0 ) |
    ( {2{st_addr == 2'h1}} & 2'h1 ) |
    ( {2{st_addr == 2'h2}} & 2'h2 ) |
    ( {2{st_addr == 2'h3}} & 2'h2 );

assign lwr_swr_size =
    ( {2{st_addr == 2'h0}} & 2'h2 ) |
    ( {2{st_addr == 2'h1}} & 2'h2 ) |
    ( {2{st_addr == 2'h2}} & 2'h1 ) |
    ( {2{st_addr == 2'h3}} & 2'h0 );

// SRAM

assign data_sram_req = 
    es_valid &&
    // ms_allowin &&
    !es_addr_ok_r && 
    (es_mem_we || es_mem_re) && !no_store;
assign data_sram_wr     = es_mem_we;
assign data_sram_size   =
    ( {2{es_inst_lw || es_inst_sw}}                 & 2'h2          ) |
    ( {2{es_inst_lh || es_inst_lhu || es_inst_sh}}  & 2'h1          ) |
    ( {2{es_inst_lb || es_inst_lbu || es_inst_sb}}  & 2'h0          ) |
    ( {2{es_inst_lwl || es_inst_swl}}               & lwl_swl_size  ) |
    ( {2{es_inst_lwr || es_inst_swr}}               & lwr_swr_size  );
assign data_sram_addr   =
    (es_inst_lwl || es_inst_swl) ? {es_alu_result[31:2], 2'b0} : es_alu_result[31:0];

assign es_data_waiting = es_valid && es_addr_ok && !es_data_ok;

assign es_data_sram_data_ok = data_sram_data_ok && ms_inst_unable;

assign data_sram_wdata  = st_data;
assign data_sram_wstrb  = st_strb;

always @ (posedge clk) begin
    if (reset) begin
        es_addr_ok_r <= 1'b0;
    end else if (data_sram_req && data_sram_addr_ok && !ms_allowin) begin
        es_addr_ok_r <= 1'b1;
    end else if (ms_allowin) begin
        es_addr_ok_r <= 1'b0;
    end
end
assign es_addr_ok   = (data_sram_req && data_sram_addr_ok) || es_addr_ok_r;

always @ (posedge clk) begin
    if (reset) begin
        es_data_buff_valid  <= 1'b0;
        es_data_buff        <= 32'h0;
    end else if (ms_allowin || no_store) begin
        es_data_buff_valid  <= 1'b0;
        es_data_buff        <= 32'h0;
    end else if (es_addr_ok && es_data_sram_data_ok && !ms_allowin) begin
        es_data_buff_valid  <= 1'b1;
        es_data_buff        <= data_sram_rdata;
    end
end
assign es_data_ok   = es_data_buff_valid || (es_addr_ok && es_data_sram_data_ok);
assign es_data =
    es_data_buff_valid ?    es_data_buff :
    data_sram_rdata;

assign es_wait_mem = es_valid && es_addr_ok;

// Block & Forward
assign es_fwd_valid = {4{ es_valid && es_gr_we && !es_res_from_mem }};
assign es_rf_dest   = es_dest;
assign es_rf_data   = es_exe_result;

assign es_blk_valid = es_valid && es_res_from_mem && !ws_eret && !ws_ex;

// Pipeline
assign es_ready_go    = 
    (es_inst_div  && !ws_eret && !ws_ex) ? signed_dout_tvalid || signed_divider_done :
    (es_inst_divu && !ws_eret && !ws_ex) ? unsigned_dout_tvalid || unsigned_divider_done :
    (es_mem_we || es_mem_re            ) ? es_addr_ok || es_ex:
    1'b1;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go && !ws_eret && !ws_ex;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end else if (ws_ex || ws_eret) begin
        es_valid <= 1'b0;
    end else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign es_inst_mfc0_o = es_valid && es_inst_mfc0;

wire overflow_ex;
wire mem_ex;

wire load_ex;
wire store_ex;

assign overflow_ex = overflow && overflow_inst;

assign load_ex = (es_inst_lw && (st_addr != 2'b00)) || ((es_inst_lh || es_inst_lhu) && (st_addr[0] != 1'b0));
assign store_ex = (es_inst_sw && (st_addr != 2'b00)) || (es_inst_sh && (st_addr[0] != 1'b0));
assign mem_ex = load_ex || store_ex;


assign es_ex = (overflow_ex | mem_ex | ds_to_es_ex) & es_valid;
assign es_bd = ds_to_es_bd;
assign es_badvaddr = (fs_to_ds_ex) ? ds_to_es_badvaddr : es_alu_result;
assign es_excode = (ds_to_es_ex)? ds_to_es_excode :
                    (overflow_ex)? `EX_OV :
                    (load_ex)? `EX_ADEL :
                    (store_ex)? `EX_ADES :
                    ds_to_es_excode;



endmodule