`include "mycpu.h"

module if_stage(
    input                           clk            ,
    input                           reset          ,
    // allwoin
    input                           ds_allowin     ,
    output                          fs_allowin     ,
    // from pfs
    input                           pfs_to_fs_valid,
    input  [`PFS_TO_FS_BUS_WD -1:0] pfs_to_fs_bus  ,
    // to ds
    output                          fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0]  fs_to_ds_bus   ,

    // to pfs
    output          fs_inst_unable,
    output          fs_valid_o,

    // inst_ram interface
    input   [31:0]  inst_sram_rdata,
    input           inst_sram_data_ok,
    output          fs_inst_waiting, 

    //exception
    input           ws_eret,
    input           ws_ex,
    input [31:0]    cp0_epc
);

reg         fs_valid;
wire        fs_ready_go;
reg  [`PFS_TO_FS_BUS_WD -1:0] pfs_to_fs_bus_r;

wire        pfs_to_fs_inst_ok;
wire [31:0] pfs_to_fs_inst;
wire [31:0] fs_pc;
assign {
    pfs_to_fs_inst_ok,
    pfs_to_fs_inst,
    fs_pc
} = pfs_to_fs_bus_r;

wire fs_ex;
wire [31:0] fs_badvaddr;

// ram
reg         fs_inst_buff_valid;
reg  [31:0] fs_inst_buff;
wire        fs_inst_ok;
wire [31:0] fs_inst;

assign fs_to_ds_bus = {
    fs_ex,       //96:96
    fs_badvaddr, //95:64  
    fs_inst,     //63:32
    fs_pc        //31:0
};


// IF stage
assign fs_ready_go    = fs_inst_ok;
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go && !ws_eret && !ws_ex;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end else if (ws_ex || ws_eret) begin
        fs_valid <= 1'b0;
    end else if (fs_allowin) begin
        fs_valid <= pfs_to_fs_valid;
    end

    if (pfs_to_fs_valid && fs_allowin) begin
        pfs_to_fs_bus_r <= pfs_to_fs_bus;
    end
end

// ram
always @ (posedge clk) begin
    if (reset) begin
        fs_inst_buff_valid  <= 1'b0;
        fs_inst_buff        <= 32'h0;
    end else if (!fs_inst_buff_valid && fs_valid && inst_sram_data_ok && !ds_allowin) begin
        fs_inst_buff_valid  <= 1'b1;
        fs_inst_buff        <= inst_sram_rdata;
    end else if (ds_allowin || ws_eret || ws_ex) begin
        fs_inst_buff_valid  <= 1'b0;
        fs_inst_buff        <= 32'h0;
    end
end

assign fs_inst_ok = pfs_to_fs_inst_ok || fs_inst_buff_valid || (fs_valid && inst_sram_data_ok);
assign fs_inst = 
    pfs_to_fs_inst_ok ?     pfs_to_fs_inst  :
    fs_inst_buff_valid ?    fs_inst_buff    :
    inst_sram_rdata;

assign fs_valid_o = fs_valid;

assign fs_inst_waiting  = fs_valid && !fs_inst_ok;
assign fs_inst_unable   = !fs_valid || fs_inst_buff_valid || pfs_to_fs_inst_ok;

// lab9
// instruction fetch exceptions are handled here
wire addr_error;
assign addr_error = (fs_pc[1:0] != 2'b0);
assign fs_ex = fs_valid && addr_error;
assign fs_badvaddr = fs_pc;

endmodule
