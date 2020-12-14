`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata,

    //block
    output          ws_inst_mfc0_o,
    output [4:0]    ws_rf_dest    ,
    //exception
    output          ws_ex_o       ,
    output          ws_eret       ,
    output          ws_after_tlb  ,
    output [31:0]   cp0_epc       ,
    output [31:0]   after_tlb_pc  ,
    output [31:0]   cp0_status    ,
    output [31:0]   cp0_cause     ,
    output [31:0]   cp0_entryhi   ,

    //lab14

    //tlb-write
    output                       we,        
    output  [               3:0] w_index,     
    output  [              18:0] w_vpn2,     
    output  [               7:0] w_asid,     
    output                       w_g,     
    output  [              19:0] w_pfn0,     
    output  [               2:0] w_c0,     
    output                       w_d0,
    output                       w_v0,     
    output  [              19:0] w_pfn1,     
    output  [               2:0] w_c1,     
    output                       w_d1,     
    output                       w_v1,

    //tlb-write
    output  [               3:0] r_index,     
    input  [              18:0] r_vpn2,     
    input  [               7:0] r_asid,     
    input                       r_g,     
    input  [              19:0] r_pfn0,     
    input  [               2:0] r_c0,     
    input                       r_d0,
    input                       r_v0,     
    input  [              19:0] r_pfn1,     
    input  [               2:0] r_c1,     
    input                       r_d1,     
    input                       r_v1
    
);

reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire [ 3:0] ws_gr_strb;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;

wire        ws_ex;
wire        ws_bd;
wire        ws_inst_eret;
wire        ws_inst_syscall;  
wire        ws_inst_mtc0;
wire [7:0]  cp0_addr;
wire [4:0]  ws_excode;
wire [31:0] ws_badvaddr;

wire [3:0] ws_s1_index;
wire       ws_s1_found;  

assign {
    ws_s1_index     ,  //132:129
    ws_s1_found     ,  //128:128
    ws_after_tlb    ,  //127:127
    ws_inst_tlbp    ,  //126:126
    ws_inst_tlbr    ,  //125:125
    ws_inst_tlbwi   ,  //124:124
    ws_excode       ,  //123:119
    ws_badvaddr     ,  //118:87
    cp0_addr        ,  //86:79
    ws_ex           ,  //78:78
    ws_bd           ,  //77:77
    ws_inst_eret    ,  //76:76
    ws_inst_syscall ,  //75:75
    ws_inst_mfc0    ,  //74:74
    ws_inst_mtc0    ,  //73:73
    ws_gr_strb,         //72:69
    ws_dest,            //68:64
    ws_final_result,    //63:32
    ws_pc               //31:0
} = ms_to_ws_bus_r;



wire [ 3:0] rf_we;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {
    rf_we,      //40:37
    rf_waddr,   //36:32
    rf_wdata    //31:0
};

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end


//lab8


wire [5:0]      ext_int_in;
wire [31:0]     cp0_rdata;
wire            cp0_we;
wire [31:0]     cp0_wdata;


wire [31:0]     ws_cp0_epc;
wire [31:0]     ws_cp0_status;
wire [31:0]     ws_cp0_cause;

//valid
assign ws_inst_mfc0_o = ws_valid && ws_inst_mfc0;
assign ws_rf_dest = ws_valid ? ws_dest : 5'b0;

assign ws_ex_o = ws_valid && ws_ex;
assign cp0_epc = {32{ws_valid}} & ws_cp0_epc;
assign cp0_cause = {32{ws_valid}} & ws_cp0_cause;
assign cp0_status = {32{ws_valid}} & ws_cp0_status;


//init
assign ext_int_in = 6'b0;
assign ws_eret = ws_inst_eret && ws_valid;

assign after_tlb_pc = ws_pc;

// TODO
assign rf_we    = {4{ ws_valid & ~ws_ex }} & ws_gr_strb;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_inst_mfc0 ? cp0_rdata :
                  ws_final_result;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = rf_we;
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = rf_wdata;

assign cp0_we = ws_inst_mtc0 && ws_valid && !ws_ex;
assign cp0_wdata = ws_final_result;


//lab14
// wire [31:0] cp0_entryhi;
wire [31:0] cp0_entrylo0;
wire [31:0] cp0_entrylo1;
wire [31:0] cp0_index;

// write port
// wire                       we;        
// wire  [               3:0] w_index;     
// wire  [              18:0] w_vpn2;     
// wire  [               7:0] w_asid;     
// wire                       w_g;     
// wire  [              19:0] w_pfn0;     
// wire  [               2:0] w_c0;     
// wire                       w_d0;
// wire                       w_v0;     
// wire  [              19:0] w_pfn1;     
// wire  [               2:0] w_c1;     
// wire                       w_d1;     
// wire                       w_v1;

assign we           = ws_inst_tlbwi;
// ENTRYHI
assign w_index      = cp0_index[3:0];
assign w_vpn2       = cp0_entryhi[31:13];
assign w_asid       = cp0_entryhi[7:0];
assign w_g          = cp0_entrylo0[0] & cp0_entrylo1[0];
// ENTRYLO0
assign w_pfn0       = cp0_entrylo0[25:6];
assign w_c0         = cp0_entrylo0[5:3];
assign w_d0         = cp0_entrylo0[2];
assign w_v0         = cp0_entrylo0[1];
// ENTRYLO1
assign w_pfn1       = cp0_entrylo1[25:6];
assign w_c1         = cp0_entrylo1[5:3];
assign w_d1         = cp0_entrylo1[2];
assign w_v1         = cp0_entrylo1[1];  

// read port
// wire  [               3:0] r_index;     
// wire  [              18:0] r_vpn2;     
// wire  [               7:0] r_asid;     
// wire                       r_g;     
// wire  [              19:0] r_pfn0;     
// wire  [               2:0] r_c0;     
// wire                       r_d0;
// wire                       r_v0;     
// wire  [              19:0] r_pfn1;     
// wire  [               2:0] r_c1;     
// wire                       r_d1;     
// wire                       r_v1;

assign r_index = cp0_index[3:0];

//search block
assign ws_entryhi_block = ws_valid && ws_inst_mtc0 && (cp0_addr == 8'b01010000);

cp0 u_cp0(
    .clk                (clk),
    .rst                (reset),
    
    .wb_ex              (ws_ex && !ws_after_tlb),
    .wb_bd              (ws_bd),
    .wb_excode          (ws_excode),
    .wb_pc              (ws_pc),
    .wb_badvaddr        (ws_badvaddr),
    .ws_eret            (ws_eret),
    .ext_int_in         (ext_int_in),

    .cp0_addr           (cp0_addr),
    .cp0_rdata          (cp0_rdata),
    .mtc0_we            (cp0_we),
    .cp0_wdata          (cp0_wdata),
  
    .cp0_epc            (ws_cp0_epc),  
    .cp0_status         (ws_cp0_status),
    .cp0_cause          (ws_cp0_cause),


    .cp0_entryhi        (cp0_entryhi),
    .cp0_entrylo0       (cp0_entrylo0),
    .cp0_entrylo1       (cp0_entrylo1),
    .cp0_index          (cp0_index),
      
    .tlbp               (ws_inst_tlbp),
    .tlbr               (ws_inst_tlbr),
    .tlbwi              (ws_inst_tlbwi),

    .s1_found           (ws_s1_found),
    .s1_index           (ws_s1_index),

    .r_vpn2             (r_vpn2),
    .r_asid             (r_asid),
    .r_g                (r_g),
    .r_pfn0             (r_pfn0),
    .r_c0               (r_c0),
    .r_d0               (r_d0),
    .r_v0               (r_v0),
    .r_pfn1             (r_pfn1),
    .r_c1               (r_c1),
    .r_d1               (r_d1),
    .r_v1               (r_v1)
);



endmodule
