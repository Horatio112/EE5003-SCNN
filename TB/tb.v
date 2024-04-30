module tb();

  parameter I_I = 5; //data width of input data
  parameter I_J = 5;
  parameter I_K = 1;
  parameter K_I = 2; //data width of kernel
  parameter K_J = 2;
  parameter K_K = 1;
  parameter DEPTH = 32;
  parameter WIDTH = 32;  
  parameter K_L = 12;
  parameter BASE_ADDR_WIDTH = 32;
  parameter i_width = 5;
  parameter j_width = 5;
  parameter k_width = 5;
  parameter l_width = 5;
  parameter WEIGHT_WIDTH = 2; 
  parameter POTENTIAL_WIDTH = 8; 
  parameter WEIGHT_DEPTH = 4; 
  parameter POTENTIAL_DEPTH = 729;
  parameter KERNEL_NUM = 12; 
  parameter NUM_ARB = 6;
  parameter PE_NUM =4;
  parameter POST_WIDTH=32;

  reg clk;
  reg rst;
  reg [PE_NUM-1:0] start;
  reg pool_or_conv;
//  reg read_grant;
//  reg write_grant;
  reg [PE_NUM-1:0] write_en;
  reg [31:0]w_data;
  reg [PE_NUM-1:0] w_mem_wen;
  reg [WEIGHT_WIDTH*K_L-1:0]w_mem_wdata; 
  reg [$clog2(WEIGHT_DEPTH)-1:0]w_mem_waddr;
  reg [K_I-1:0] k_i;//size of kernel
  reg [K_J-1:0] k_j;
  reg [$clog2(K_L)-1:0] k_l;
  reg [I_I-1:0] i_i;//size of input data
  reg [I_J-1:0] i_j;
  reg [BASE_ADDR_WIDTH-1:0] base_addr;
  reg                               potential_read_en;
  reg                               potential_write_en;
  reg [$clog2(POTENTIAL_DEPTH)-1:0] potential_raddr_cluster;
  reg [$clog2(POTENTIAL_DEPTH)-1:0] potential_waddr_cluster;
  reg [POTENTIAL_WIDTH*K_L-1:0]     potential_wdata_cluster;
  reg start_sche;
  reg [POTENTIAL_WIDTH-1:0] threhold;
  reg [POTENTIAL_WIDTH-1:0] rest_value;
  reg post_grant;
  reg [POST_WIDTH-1:0] post_addr;

  wire [PE_NUM-1:0]                 finish;
  wire [POST_WIDTH-1:0]post_waddr;
  wire [POST_WIDTH-1:0]post_wdata;
  wire post_req;

//  wire read_req;
//  wire write_req;

  always #10 clk=~clk;

  initial begin
    clk             =0;
    rst             =0;
    start           =0;
    start_sche      =0;
    pool_or_conv    =0;
    write_en        =0;
    w_data          =0;
    w_mem_wen       =0;      
    w_mem_wdata     =0;  
    w_mem_waddr     =0;
    k_i             =0;
    k_j             =0;
    k_l             =0;
    i_i             =0;
    i_j             =0;
    threhold        =0;
    rest_value      =0;
    post_grant      =0;
    post_addr       =0;
    base_addr       =0;
    potential_read_en=0;
    potential_write_en=0;
    potential_raddr_cluster=0;
    potential_waddr_cluster=0;
    potential_wdata_cluster=0;    
    #15 //write weight
    rst             =1;
    w_mem_wen       =4'b1111;
    w_mem_waddr      =0;
    w_mem_wdata      ={12{2'b00}};
    #20
    w_mem_waddr      =1;
    w_mem_wdata      ={12{2'b01}};
    #20
    w_mem_waddr      =2;
    w_mem_wdata      ={12{2'b10}};
    #20
    w_mem_waddr      =3;
    w_mem_wdata      ={12{2'b11}};

    #20 //write input 
    w_mem_wen       ='b0;
    write_en        =4'b1111;
    w_data          =32'b00_00000_00000_00001_00001_00000_00000; //i_j_k_l
    #20
    w_data          =32'b00_00000_00000_00000_00001_00000_00000;
    #20
    w_data          =32'b00_00000_00000_00001_00000_00000_00000;
    #20
    w_data          =32'b00_00000_00000_00000_00000_00000_00000;//left up cornor
    #20
    w_data          =32'b00_00000_00000_11011_00000_00000_00000;
    #20
    w_data          =32'b00_00000_00000_11011_00001_00000_00000;
    #20
    w_data          =32'b00_00000_00000_11010_00000_00000_00000;
    #20
    w_data          =32'b00_00000_00000_11010_00001_00000_00000;//right up cornor
    #20
    w_data          =32'b00_00000_00000_00000_11011_00000_00000;
    #20
    w_data          =32'b00_00000_00000_00000_11010_00000_00000;
    #20
    w_data          =32'b00_00000_00000_00001_11011_00000_00000;
    #20
    w_data          =32'b00_00000_00000_00001_11010_00000_00000;//left bottom cornor
    #20
    w_data          =32'b00_00000_00000_11011_11011_00000_00000;
    #20
    w_data          =32'b00_00000_00000_11011_11010_00000_00000;
    #20
    w_data          =32'b00_00000_00000_11010_11011_00000_00000;
    #20
    w_data          =32'b00_00000_00000_11010_11010_00000_00000;//right up cornor
/*    #20 // for test pooloing
    w_data          =32'b00_00000_00000_00110_10000_00000_00000; //(6,16) -> (3,8) -> 115
    #20
    w_data          =32'b00_00000_00000_10010_01110_00000_00000; //(18,14) -> (9:7) -> 107
    #20
    w_data          =32'b00_00000_00000_01010_01000_00000_00000; //(10,8) -> (5:4) -> 61
    #20
    w_data          =32'b00_00000_00000_10001_01101_00000_00000; //(17,13) -> (8,6) -> 92
*/  
    #20
    write_en        =0;
    #20
    k_i             =2;
    k_j             =2;
    i_i             =28;
    i_j             =28; 
    k_l             =12;
    start           =4'b0001;
    threhold        =5;
    rest_value      =1;
    post_grant      =1;
    post_addr       =6;

    //pool_or_conv    =1;
    #20
    start           =4'b0011;
    #20
    start           =4'b0111;
    #20
    start           =4'b1111;
    #5000
    start_sche      =1;
    #10000
    $finish;
  end
  always@(posedge clk)
    $fsdbDumpMDA(cluster_inst.pe_inst[0].pe_inst.fifo1.mem,0,32);
//  always@(posedge clk)
//    $fsdbDumpMDA(cluster_inst.pe_inst[1].pe_inst.fifo1.mem,0,32);
//  always@(posedge clk)
//    $fsdbDumpMDA(cluster_inst.pe_inst[2].pe_inst.fifo1.mem,0,32);
//  always@(posedge clk)
//    $fsdbDumpMDA(cluster_inst.pe_inst[3].pe_inst.fifo1.mem,0,32);

  always@(posedge clk)
    $fsdbDumpMDA(cluster_inst.potential_inst.p_mem.ram,0,729);
  
  always@(posedge clk)
    $fsdbDumpMDA(cluster_inst.pe_inst[0].pe_inst.weight_mem.ram,0,128);
//  always@(posedge clk)
//    $fsdbDumpMDA(cluster_inst.pe_inst[1].pe_inst.weight_mem.ram,0,128);
//  always@(posedge clk)
//    $fsdbDumpMDA(cluster_inst.pe_inst[2].pe_inst.weight_mem.ram,0,128);
//  always@(posedge clk)
//    $fsdbDumpMDA(cluster_inst.pe_inst[3].pe_inst.weight_mem.ram,0,128);
 
  always@(posedge clk)
    $fsdbDumpMDA(cluster_inst.potential_inst.flag,0,729);






cluster#(
.I_I              (I_I            ), //data width of input data
.I_J              (I_J            ),
.I_K              (I_K            ),
.K_I              (K_I            ), //data width of kernel
.K_J              (K_J            ),
.K_K              (K_K            ),
.DEPTH            (DEPTH          ),
.WIDTH            (WIDTH          ),
.i_width          (i_width        ),
.j_width          (j_width        ),
.k_width          (k_width        ),
.l_width          (l_width        ),
.WEIGHT_WIDTH     (WEIGHT_WIDTH   ), //24*12
.POTENTIAL_WIDTH  (POTENTIAL_WIDTH), //32*12
.WEIGHT_DEPTH     (WEIGHT_DEPTH   ), //24*12
.POTENTIAL_DEPTH  (POTENTIAL_DEPTH),
.KERNEL_NUM       (KERNEL_NUM     ),
.NUM_ARB          (NUM_ARB),
.PE_NUM           (PE_NUM),
.POST_WIDTH       (POST_WIDTH)
)
cluster_inst
(
.potential_read_en (potential_read_en),
.potential_write_en(potential_write_en),
.potential_raddr_cluster  (potential_raddr_cluster),
.potential_waddr_cluster  (potential_waddr_cluster), 
.potential_wdata_cluster  (potential_wdata_cluster),
.clk               (clk),
.rst               (rst),
.start             (start),
.start_sche        (start_sche),
.threhold          (threhold),
.rest_value        (rest_value),
.pool_or_conv      (pool_or_conv),
.write_en          (write_en),
.w_data            (w_data),
.w_mem_wen         (w_mem_wen),
.w_mem_wdata       (w_mem_wdata),
.w_mem_waddr       (w_mem_waddr),
.k_i               (k_i),//size of kernel
.k_j               (k_j),
.k_l               (k_l),
.i_i               (i_i),//size of input data
.i_j               (i_j),
.base_addr         (base_addr),
.post_grant        (post_grant),
.post_addr         (post_addr),
.post_waddr        (post_waddr),
.post_wdata        (post_wdata),
.finish            (finish),
.post_req          (post_req)
);

initial begin
  $fsdbDumpfile("tb.fsdb");
  $fsdbDumpvars();  
  end

endmodule
