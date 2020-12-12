module tlb
#(
    parameter TLBNUM = 16
)
(
    input           clk,

    // search port 0
    input  [              18:0] s0_vpn2,     
    input                       s0_odd_page,     
    input  [               7:0] s0_asid,     
    output                      s0_found,     
    output [$clog2(TLBNUM)-1:0] s0_index,   
    output [              19:0] s0_pfn,     
    output [               2:0] s0_c,     
    output                      s0_d,     
    output                      s0_v, 
 
    // search port 1     
    input  [              18:0] s1_vpn2,     
    input                       s1_odd_page,     
    input  [               7:0] s1_asid,     
    output                      s1_found,     
    output [$clog2(TLBNUM)-1:0] s1_index,      
    output [              19:0] s1_pfn,     
    output [               2:0] s1_c,     
    output                      s1_d,     
    output                      s1_v, 
 
    // write port     
    input                       we,         
    input  [$clog2(TLBNUM)-1:0] w_index,     
    input  [              18:0] w_vpn2,     
    input  [               7:0] w_asid,     
    input                       w_g,     
    input  [              19:0] w_pfn0,     
    input  [               2:0] w_c0,     
    input                       w_d0,
    input                       w_v0,     
    input  [              19:0] w_pfn1,     
    input  [               2:0] w_c1,     
    input                       w_d1,     
    input                       w_v1, 
 
    // read port     
    input  [$clog2(TLBNUM)-1:0] r_index,     
    output [              18:0] r_vpn2,     
    output [               7:0] r_asid,     
    output                      r_g,     
    output [              19:0] r_pfn0,     
    output [               2:0] r_c0,     
    output                      r_d0,     
    output                      r_v0,     
    output [              19:0] r_pfn1,     
    output [               2:0] r_c1,     
    output                      r_d1,     
    output                      r_v1 
);

reg  [      18:0] tlb_vpn2     [TLBNUM-1:0]; 
reg  [       7:0] tlb_asid     [TLBNUM-1:0]; 
reg               tlb_g        [TLBNUM-1:0];

reg  [      19:0] tlb_pfn0     [TLBNUM-1:0]; 
reg  [       2:0] tlb_c0       [TLBNUM-1:0]; 
reg               tlb_d0       [TLBNUM-1:0]; 
reg               tlb_v0       [TLBNUM-1:0];

reg  [      19:0] tlb_pfn1     [TLBNUM-1:0]; 
reg  [       2:0] tlb_c1       [TLBNUM-1:0]; 
reg               tlb_d1       [TLBNUM-1:0]; 
reg               tlb_v1       [TLBNUM-1:0]; 

//Search
wire [15:0] match0;

assign match0[ 0] = (s0_vpn2 == tlb_vpn2[ 0]) && ((s0_asid == tlb_asid[ 0]) || tlb_g[ 0]); 
assign match0[ 1] = (s0_vpn2 == tlb_vpn2[ 1]) && ((s0_asid == tlb_asid[ 1]) || tlb_g[ 1]); 
assign match0[ 2] = (s0_vpn2 == tlb_vpn2[ 2]) && ((s0_asid == tlb_asid[ 2]) || tlb_g[ 2]); 
assign match0[ 3] = (s0_vpn2 == tlb_vpn2[ 3]) && ((s0_asid == tlb_asid[ 3]) || tlb_g[ 3]); 
assign match0[ 4] = (s0_vpn2 == tlb_vpn2[ 4]) && ((s0_asid == tlb_asid[ 4]) || tlb_g[ 4]); 
assign match0[ 5] = (s0_vpn2 == tlb_vpn2[ 5]) && ((s0_asid == tlb_asid[ 5]) || tlb_g[ 5]);
assign match0[ 6] = (s0_vpn2 == tlb_vpn2[ 6]) && ((s0_asid == tlb_asid[ 6]) || tlb_g[ 6]); 
assign match0[ 7] = (s0_vpn2 == tlb_vpn2[ 7]) && ((s0_asid == tlb_asid[ 7]) || tlb_g[ 7]); 
assign match0[ 8] = (s0_vpn2 == tlb_vpn2[ 8]) && ((s0_asid == tlb_asid[ 8]) || tlb_g[ 8]);
assign match0[ 9] = (s0_vpn2 == tlb_vpn2[ 9]) && ((s0_asid == tlb_asid[ 9]) || tlb_g[ 9]); 
assign match0[10] = (s0_vpn2 == tlb_vpn2[10]) && ((s0_asid == tlb_asid[10]) || tlb_g[10]); 
assign match0[11] = (s0_vpn2 == tlb_vpn2[11]) && ((s0_asid == tlb_asid[11]) || tlb_g[11]); 
assign match0[12] = (s0_vpn2 == tlb_vpn2[12]) && ((s0_asid == tlb_asid[12]) || tlb_g[12]); 
assign match0[13] = (s0_vpn2 == tlb_vpn2[13]) && ((s0_asid == tlb_asid[13]) || tlb_g[13]); 
assign match0[14] = (s0_vpn2 == tlb_vpn2[14]) && ((s0_asid == tlb_asid[14]) || tlb_g[14]); 
assign match0[15] = (s0_vpn2 == tlb_vpn2[15]) && ((s0_asid == tlb_asid[15]) || tlb_g[15]);

wire [15:0] match1;
assign match1[ 0] = (s1_vpn2 == tlb_vpn2[ 0]) && ((s1_asid == tlb_asid[ 0]) || tlb_g[ 0]); 
assign match1[ 1] = (s1_vpn2 == tlb_vpn2[ 1]) && ((s1_asid == tlb_asid[ 1]) || tlb_g[ 1]); 
assign match1[ 2] = (s1_vpn2 == tlb_vpn2[ 2]) && ((s1_asid == tlb_asid[ 2]) || tlb_g[ 2]); 
assign match1[ 3] = (s1_vpn2 == tlb_vpn2[ 3]) && ((s1_asid == tlb_asid[ 3]) || tlb_g[ 3]); 
assign match1[ 4] = (s1_vpn2 == tlb_vpn2[ 4]) && ((s1_asid == tlb_asid[ 4]) || tlb_g[ 4]); 
assign match1[ 5] = (s1_vpn2 == tlb_vpn2[ 5]) && ((s1_asid == tlb_asid[ 5]) || tlb_g[ 5]);
assign match1[ 6] = (s1_vpn2 == tlb_vpn2[ 6]) && ((s1_asid == tlb_asid[ 6]) || tlb_g[ 6]); 
assign match1[ 7] = (s1_vpn2 == tlb_vpn2[ 7]) && ((s1_asid == tlb_asid[ 7]) || tlb_g[ 7]); 
assign match1[ 8] = (s1_vpn2 == tlb_vpn2[ 8]) && ((s1_asid == tlb_asid[ 8]) || tlb_g[ 8]);
assign match1[ 9] = (s1_vpn2 == tlb_vpn2[ 9]) && ((s1_asid == tlb_asid[ 9]) || tlb_g[ 9]); 
assign match1[10] = (s1_vpn2 == tlb_vpn2[10]) && ((s1_asid == tlb_asid[10]) || tlb_g[10]); 
assign match1[11] = (s1_vpn2 == tlb_vpn2[11]) && ((s1_asid == tlb_asid[11]) || tlb_g[11]); 
assign match1[12] = (s1_vpn2 == tlb_vpn2[12]) && ((s1_asid == tlb_asid[12]) || tlb_g[12]); 
assign match1[13] = (s1_vpn2 == tlb_vpn2[13]) && ((s1_asid == tlb_asid[13]) || tlb_g[13]); 
assign match1[14] = (s1_vpn2 == tlb_vpn2[14]) && ((s1_asid == tlb_asid[14]) || tlb_g[14]); 
assign match1[15] = (s1_vpn2 == tlb_vpn2[15]) && ((s1_asid == tlb_asid[15]) || tlb_g[15]);

assign s0_found = match0 ? 1'b1 : 1'b0;
assign s1_found = match1 ? 1'b1 : 1'b0;

assign s0_index = ({4{match0 == 16'b0000000000000001}} & 4'd0)
                | ({4{match0 == 16'b0000000000000010}} & 4'd1)
                | ({4{match0 == 16'b0000000000000100}} & 4'd2)
                | ({4{match0 == 16'b0000000000001000}} & 4'd3)
                | ({4{match0 == 16'b0000000000010000}} & 4'd4)
                | ({4{match0 == 16'b0000000000100000}} & 4'd5)
                | ({4{match0 == 16'b0000000001000000}} & 4'd6)
                | ({4{match0 == 16'b0000000010000000}} & 4'd7)
                | ({4{match0 == 16'b0000000100000000}} & 4'd8)
                | ({4{match0 == 16'b0000001000000000}} & 4'd9)
                | ({4{match0 == 16'b0000010000000000}} & 4'd10)
                | ({4{match0 == 16'b0000100000000000}} & 4'd11)
                | ({4{match0 == 16'b0001000000000000}} & 4'd12)
                | ({4{match0 == 16'b0010000000000000}} & 4'd13)
                | ({4{match0 == 16'b0100000000000000}} & 4'd14)
                | ({4{match0 == 16'b1000000000000000}} & 4'd15);

assign s0_pfn = s0_odd_page ? tlb_pfn1[s0_index] : tlb_pfn0[s0_index];
assign s0_c = s0_odd_page ? tlb_c1[s0_index] : tlb_c0[s0_index];
assign s0_d = s0_odd_page ? tlb_d1[s0_index] : tlb_d0[s0_index];
assign s0_v = s0_odd_page ? tlb_v1[s0_index] : tlb_v0[s0_index];

assign s1_index = ({4{match1 == 16'b0000000000000001}} & 4'd0)
                | ({4{match1 == 16'b0000000000000010}} & 4'd1)
                | ({4{match1 == 16'b0000000000000100}} & 4'd2)
                | ({4{match1 == 16'b0000000000001000}} & 4'd3)
                | ({4{match1 == 16'b0000000000010000}} & 4'd4)
                | ({4{match1 == 16'b0000000000100000}} & 4'd5)
                | ({4{match1 == 16'b0000000001000000}} & 4'd6)
                | ({4{match1 == 16'b0000000010000000}} & 4'd7)
                | ({4{match1 == 16'b0000000100000000}} & 4'd8)
                | ({4{match1 == 16'b0000001000000000}} & 4'd9)
                | ({4{match1 == 16'b0000010000000000}} & 4'd10)
                | ({4{match1 == 16'b0000100000000000}} & 4'd11)
                | ({4{match1 == 16'b0001000000000000}} & 4'd12)
                | ({4{match1 == 16'b0010000000000000}} & 4'd13)
                | ({4{match1 == 16'b0100000000000000}} & 4'd14)
                | ({4{match1 == 16'b1000000000000000}} & 4'd15);

assign s1_pfn = s1_odd_page ? tlb_pfn1[s1_index] : tlb_pfn0[s1_index];
assign s1_c = s1_odd_page ? tlb_c1[s1_index] : tlb_c0[s1_index];
assign s1_d = s1_odd_page ? tlb_d1[s1_index] : tlb_d0[s1_index];
assign s1_v = s1_odd_page ? tlb_v1[s1_index] : tlb_v0[s1_index];

//Read
assign r_vpn2 = tlb_vpn2[r_index];
assign r_asid = tlb_asid[r_index];
assign r_g    = tlb_g[r_index];

assign r_pfn0 = tlb_pfn0[r_index];
assign r_c0   = tlb_c0[r_index];
assign r_d0   = tlb_d0[r_index];
assign r_v0   = tlb_v0[r_index];

assign r_pfn1 = tlb_pfn1[r_index];
assign r_c1   = tlb_c1[r_index];
assign r_d1   = tlb_d1[r_index];
assign r_v1   = tlb_v1[r_index];

//Write
always @(posedge clk) begin
    if (we) begin
        tlb_vpn2[w_index] <= w_vpn2;
        tlb_asid[w_index] <= w_asid;    
        tlb_g[w_index]    <= w_g;

        tlb_pfn0[w_index] <= w_pfn0;
        tlb_c0[w_index]   <= w_c0;
        tlb_d0[w_index]   <= w_d0;
        tlb_v0[w_index]   <= w_v0;

        tlb_pfn1[w_index] <= w_pfn1;
        tlb_c1[w_index]   <= w_c1;
        tlb_d1[w_index]   <= w_d1;
        tlb_v1[w_index]   <= w_v1;
    end
end

endmodule