`define CP0_BADV_ADDR       8'b01000000
`define CP0_COUNT_ADDR      8'b01001000
`define CP0_COMP_ADDR       8'b01011000
`define CP0_STATUS_ADDR     8'b01100000
`define CP0_CAUSE_ADDR      8'b01101000
`define CP0_EPC_ADDR        8'b01110000
`define CP0_CONFIG_ADDR     8'b10000000

`define CP0_ENTRYHI_ADDR    8'b01010000
`define CP0_ENTRYLO0_ADDR   8'b00010000
`define CP0_ENTRYLO1_ADDR   8'b00011000
`define CP0_INDEX_ADDR      8'b00000000

module cp0(
    input         clk,
    input         rst, 
    input         wb_ex,
    input         wb_bd,
    input         ws_eret,
    input  [4:0]  wb_excode,
    input  [31:0] wb_pc,
    input  [31:0] wb_badvaddr,
    input  [5:0]  ext_int_in,   

    input  [ 7:0] cp0_addr,
    output [31:0] cp0_rdata,
   
    input         mtc0_we,       
    input  [31:0] cp0_wdata,   

    output [31:0] cp0_status,
    output [31:0] cp0_cause,
    output [31:0] cp0_epc,
    output [31:0] cp0_badvaddr,
    output [31:0] cp0_count,
    output [31:0] cp0_compare,

    //lab14
    //instruction
    input         tlbp,
    input         tlbr,
    input         tlbwi,
    //reg
    output [31:0] cp0_entryhi,
    output [31:0] cp0_entrylo0,
    output [31:0] cp0_entrylo1,
    output [31:0] cp0_index,
    //search-tlbp
    input         s1_found,
    input [ 3:0]  s1_index,
    //read port
    input [              18:0] r_vpn2,     
    input [               7:0] r_asid,     
    input                      r_g,     
    input [              19:0] r_pfn0,     
    input [               2:0] r_c0,     
    input                      r_d0,     
    input                      r_v0,     
    input [              19:0] r_pfn1,     
    input [               2:0] r_c1,     
    input                      r_d1,     
    input                      r_v1    
    );


//CP0_STATUS
wire cp0_status_bev;
assign cp0_status_bev = 1'b1;

reg [7:0] cp0_status_im;
always @(posedge clk) begin
    if (mtc0_we && cp0_addr == `CP0_STATUS_ADDR)
        cp0_status_im <= cp0_wdata[15:8];
end

reg cp0_status_exl;
always @(posedge clk) begin
    if(rst)
        cp0_status_exl <= 1'b0;
    else if(wb_ex)
        cp0_status_exl <= 1'b1;
    else if(ws_eret)
        cp0_status_exl <= 1'b0;
    else if(mtc0_we && cp0_addr == `CP0_STATUS_ADDR)
        cp0_status_exl <= cp0_wdata[1];
end

reg cp0_status_ie;
always @(posedge clk) begin
    if(rst)
        cp0_status_ie <= 1'b0;
    else if(mtc0_we && cp0_addr == `CP0_STATUS_ADDR)
        cp0_status_ie <= cp0_wdata[0];
end

assign cp0_status = 
{
    9'b0,               //31:23
    cp0_status_bev,     //22:22
    6'b0,               //21:16
    cp0_status_im,      //15:8
    6'b0,     //7:2
    cp0_status_exl,     //1:1
    cp0_status_ie       //0:0
};

//CP0_CAUSE
reg cp0_cause_bd;
always @(posedge clk) begin
    if(rst)
        cp0_cause_bd <= 1'b0;
    else if(wb_ex && !cp0_status_exl)
        cp0_cause_bd <= wb_bd;
end

reg cp0_cause_ti;
wire count_eq_compare;
assign count_eq_compare = (cp0_count == cp0_compare);

always @(posedge clk) begin
    if(rst)
        cp0_cause_ti <= 1'b0;
    else if(mtc0_we && cp0_addr == `CP0_COMP_ADDR)
        cp0_cause_ti <= 1'b0;
    else if(count_eq_compare)
        cp0_cause_ti <= 1'b1;
end

reg [7:0]cp0_cause_ip;
always @(posedge clk) begin
    if(rst)
        cp0_cause_ip[7:2] <= 6'b0;
    else begin
        cp0_cause_ip[7] <= ext_int_in[5] | cp0_cause_ti;
        cp0_cause_ip[6 : 2] <= ext_int_in[4:0];
    end
end

always @(posedge clk) begin
    if(rst)
        cp0_cause_ip[1:0] <= 2'b0;
    else if(mtc0_we && cp0_addr == `CP0_CAUSE_ADDR)
        cp0_cause_ip[1:0] <= cp0_wdata[9:8];
end

reg [4:0] cp0_cause_excode;
always @(posedge clk) begin
    if(rst)
        cp0_cause_excode <= 5'b0;
    else if(wb_ex)
        cp0_cause_excode <= wb_excode;
end

assign cp0_cause = 
{
    cp0_cause_bd,       //31:31
    cp0_cause_ti,       //30:30
    14'b0,              //29:16
    cp0_cause_ip,       //15:8
    1'b0,               //7:7
    cp0_cause_excode,   //6:2
    2'b0       //1:0
};

//EPC
reg [31:0] c0_epc;
always @(posedge clk) begin
    if(wb_ex && !cp0_status_exl)
        c0_epc <= wb_bd ? wb_pc - 32'h4 : wb_pc;
    else if(mtc0_we && cp0_addr == `CP0_EPC_ADDR)
        c0_epc <= cp0_wdata;
end

assign cp0_epc = c0_epc;

//BADVADDR
reg [31:0] c0_badvaddr;
always @(posedge clk) begin
    if(wb_ex && ((wb_excode == 5'h04) || (wb_excode == 5'h05)))
        c0_badvaddr <= wb_badvaddr;
end

assign cp0_badvaddr = c0_badvaddr;

//COUNT
reg tick;
always @(posedge clk) begin
    if(rst)
        tick <= 1'b0;
    else
        tick <= ~tick;
end

reg [31:0] c0_count;
always @(posedge clk) begin
    if(rst)
        c0_count <= 32'b0;
    else if(mtc0_we && cp0_addr == `CP0_COUNT_ADDR)
        c0_count <= cp0_wdata;
    else if(tick)
        c0_count <= c0_count + 1'b1;
end

assign cp0_count = c0_count;

//COMPARE
reg [31:0]c0_compare;
always @(posedge clk) begin
    if(mtc0_we && cp0_addr == `CP0_COMP_ADDR)
        c0_compare <= cp0_wdata;
end

assign cp0_compare = c0_compare;

assign cp0_rdata = 
    (cp0_addr == `CP0_STATUS_ADDR)? cp0_status :
    (cp0_addr == `CP0_CAUSE_ADDR)? cp0_cause :
    (cp0_addr == `CP0_EPC_ADDR)? cp0_epc :
    (cp0_addr == `CP0_BADV_ADDR)? cp0_badvaddr :
    (cp0_addr == `CP0_COUNT_ADDR)? cp0_count :
    (cp0_addr == `CP0_COMP_ADDR)? cp0_compare :
    (cp0_addr == `CP0_ENTRYHI_ADDR)? cp0_entryhi :
    (cp0_addr == `CP0_ENTRYLO0_ADDR)? cp0_entrylo0 :
    (cp0_addr == `CP0_ENTRYLO1_ADDR)? cp0_entrylo1 :
    (cp0_addr == `CP0_INDEX_ADDR)? cp0_index :
    32'b0;

//lab14
//ENTRYHI
reg [18:0] entry_hi_vpn2;
always @(posedge clk) begin
    if(mtc0_we && cp0_addr == `CP0_ENTRYHI_ADDR)
        entry_hi_vpn2 <= cp0_wdata[31:13];
    else if(tlbr)
        entry_hi_vpn2 <= r_vpn2;
end

reg [7:0] entry_hi_asid;
always @(posedge clk) begin
    if(mtc0_we && cp0_addr == `CP0_ENTRYHI_ADDR)
        entry_hi_asid <= cp0_wdata[7:0];
    else if(tlbr)
        entry_hi_asid <= r_asid;
end

assign cp0_entryhi = 
{
    entry_hi_vpn2,       //31:13
    5'b0,                //12:8
    entry_hi_asid        //7:0
};

//ENTRYLO0
reg [19:0] entrylo0_pfn;
always @(posedge clk) begin
    if(mtc0_we && cp0_addr == `CP0_ENTRYLO0_ADDR)
        entrylo0_pfn <= cp0_wdata[25:6];
    else if(tlbr)
        entrylo0_pfn <= r_pfn0;   
end

reg [2:0] entrylo0_c;
always @(posedge clk) begin
    if(mtc0_we && cp0_addr == `CP0_ENTRYLO0_ADDR)
        entrylo0_c <= cp0_wdata[5:3];
    else if(tlbr)
        entrylo0_c <= r_c0;   
end

reg entrylo0_d;
always @(posedge clk) begin
    if(mtc0_we && cp0_addr == `CP0_ENTRYLO0_ADDR)
        entrylo0_d <= cp0_wdata[2];
    else if(tlbr)
        entrylo0_d <= r_d0;   
end

reg entrylo0_v;
always @(posedge clk) begin
    if(mtc0_we && cp0_addr == `CP0_ENTRYLO0_ADDR)
        entrylo0_v <= cp0_wdata[1];
    else if(tlbr)
        entrylo0_v <= r_v0;   
end

reg entrylo0_g;
always @(posedge clk) begin
    if(mtc0_we && cp0_addr == `CP0_ENTRYLO0_ADDR)
        entrylo0_g <= cp0_wdata[0];
    else if(tlbr)
        entrylo0_g <= r_g;   
end

assign cp0_entrylo0 =
{
    6'b0,               //31:26
    entrylo0_pfn,       //25:6
    entrylo0_c,         //5:3
    entrylo0_d,         //2:2
    entrylo0_v,         //1:1
    entrylo0_g          //0:0
};



//ENTRYLO1
reg [19:0] entrylo1_pfn;
always @(posedge clk) begin
    if(mtc0_we && cp0_addr == `CP0_ENTRYLO1_ADDR)
        entrylo1_pfn <= cp0_wdata[25:6];
    else if(tlbr)
        entrylo1_pfn <= r_pfn1;   
end

reg [2:0] entrylo1_c;
always @(posedge clk) begin
    if(mtc0_we && cp0_addr == `CP0_ENTRYLO1_ADDR)
        entrylo1_c <= cp0_wdata[5:3];
    else if(tlbr)
        entrylo1_c <= r_c1;   
end

reg entrylo1_d;
always @(posedge clk) begin
    if(mtc0_we && cp0_addr == `CP0_ENTRYLO1_ADDR)
        entrylo1_d <= cp0_wdata[2];
    else if(tlbr)
        entrylo1_d <= r_d1;   
end

reg entrylo1_v;
always @(posedge clk) begin
    if(mtc0_we && cp0_addr == `CP0_ENTRYLO1_ADDR)
        entrylo1_v <= cp0_wdata[1];
    else if(tlbr)
        entrylo1_v <= r_v1;   
end

reg entrylo1_g;
always @(posedge clk) begin
    if(mtc0_we && cp0_addr == `CP0_ENTRYLO1_ADDR)
        entrylo1_g <= cp0_wdata[0];
    else if(tlbr)
        entrylo1_g <= r_g;   
end

assign cp0_entrylo1 =
{
    6'b0,               //31:26
    entrylo1_pfn,       //25:6
    entrylo1_c,         //5:3
    entrylo1_d,         //2:2
    entrylo1_v,         //1:1
    entrylo1_g          //0:0
};

//INDEX
reg index_p;
always @(posedge clk) begin
    if(rst)
        index_p <= 1'b0;
    else if (tlbp)
        index_p <= !(s1_found);
end

reg [3:0] index_index;
always @(posedge clk) begin
    if(rst)
        index_index <= 4'b0;
    else if(mtc0_we && cp0_addr == `CP0_INDEX_ADDR)
        index_index <= cp0_wdata[3:0];
    else if(tlbp) begin
        index_index <= s1_index;
    end
end

assign cp0_index = 
{
    index_p,        //31:31
    27'b0,          //30:4
    index_index     //3:0
};

endmodule