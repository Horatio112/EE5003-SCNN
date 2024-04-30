module pe#(
  parameter I_I = 5, //data width of input data
  parameter I_J = 5,
  parameter I_K = 1,
  parameter K_I = 2, //data width of kernel
  parameter K_J = 2,
  parameter K_K = 1,
  parameter K_L = 12,//number of kernel
  parameter BASE_ADDR_WIDTH = 32,
  parameter DEPTH = 32,
  parameter WIDTH = 32,
  parameter i_width = 5,
  parameter j_width = 5,
  parameter k_width = 5,
  parameter l_width = 5,
  parameter WEIGHT_WIDTH = 24, //24*12
  parameter POTENTIAL_WIDTH = 32, //32*12
  parameter WEIGHT_DEPTH = 4, //24*12
  parameter POTENTIAL_DEPTH = 128,
  parameter KERNEL_NUM = 12
)
(
  input clk,
  input rst,
  input start,
  input pool_or_conv, //1->pooling 0->conv
  input read_grant,
  input write_grant,
  input write_en,
  input [31:0]w_data,
  input w_mem_wen,
  input [WEIGHT_WIDTH*K_L-1:0]w_mem_wdata, //write weight memory
  input [$clog2(WEIGHT_DEPTH)-1:0]w_mem_waddr,
  input [K_I-1:0] k_i,//size of kernel
  input [K_J-1:0] k_j,
  input [I_I-1:0] i_i,//size of input data
  input [I_J-1:0] i_j,
  input [BASE_ADDR_WIDTH-1:0] base_addr,
  input [POTENTIAL_WIDTH*K_L-1:0] potential_rdata,
  output[$clog2(POTENTIAL_DEPTH)-1:0] potential_raddr,
  output[$clog2(POTENTIAL_DEPTH)-1:0] potential_waddr,
  output reg [POTENTIAL_WIDTH*K_L-1:0] potential_wdata,
  output reg read_req,
  output reg write_req,
  output reg finish
);

localparam IDLE = 3'b000;
localparam READ_SPIKE = 3'b001;
localparam ADDR_GENE = 3'b010; //generate addr
localparam READ_W_P=3'b011; //read weight and potential
localparam ADD = 3'b100; //add weight to the potential
localparam WRITE_BACK = 3'b101; //update potential

wire fifo_empty;
wire fifo_full;
reg [2:0] cs; //current_state
reg [2:0] ns; //next_state
reg [K_I-1:0] k_i_reg; 
reg [K_J-1:0] k_j_reg;
reg [I_I-1:0] i_i_reg;
reg [I_J-1:0] i_j_reg;
reg [BASE_ADDR_WIDTH-1:0] base_addr_reg;
reg pool_or_conv_reg;
reg [K_I+K_J-1:0] count_onespike; //count the processing times of one spike 
reg read_en_i; // read enable for input 
reg [K_I-1:0] i_cal_times; //times of i direction calulation
reg [K_J-1:0] j_cal_times;
reg [$clog2(WEIGHT_DEPTH)-1:0] k_addr; //weight memory addr
reg [$clog2(POTENTIAL_DEPTH)-1:0] p_addr; //potential memory addr
reg w_mem_ren;//weight memory read enable
wire [WEIGHT_WIDTH*K_L-1:0]w_mem_rdata;
//reg read_en_w;//read enable for weight
wire [WIDTH-1:0] r_data;//read from input fifo
wire [K_I-1:0] a_max;
wire [K_I-1:0] a_min;
wire [K_J-1:0] b_max;
wire [K_J-1:0] b_min;
wire [K_I+K_J-1:0] cal_times;//total cal time for one spike
wire [i_width-1:0] I;// I\J\k\L of input spike
wire [j_width-1:0] J;
wire [k_width-1:0] K;
wire [l_width-1:0] L;

integer i;

assign{I,J,K,L}=r_data[i_width+j_width+k_width+l_width-1:0];

assign a_max=(I+1>=k_i_reg)?k_i_reg-1:I;
assign a_min=(I<=i_i_reg-k_i_reg)?0:k_i_reg-(i_i_reg-I);
assign b_max=(J+1>=k_j_reg)?k_j_reg-1:J;
assign b_min=(J<=i_j_reg-k_j_reg)?0:k_j_reg-(i_j_reg-J);

assign cal_times=pool_or_conv_reg?'b1:((a_max-a_min+1)*(b_max-b_min+1));

always@(posedge clk or negedge rst)
begin
  if(!rst)
  begin
    cs<=IDLE;
  end
  else
  begin
    cs<=ns;
  end
end

always@(*)
begin
  case(cs)
  IDLE:begin
        if(start&&!fifo_empty)
        begin
          ns=READ_SPIKE;
        end 
        else
        begin
          ns=IDLE;
        end
       end  
  READ_SPIKE:begin
        ns=ADDR_GENE;
       end 
  ADDR_GENE:begin
        ns=READ_W_P;
       end
  READ_W_P:begin
          if(read_grant)
            ns=ADD;
          else
            ns=READ_W_P;     
      end   
  ADD:begin
        ns=WRITE_BACK;
       end
  WRITE_BACK:begin
        if(write_grant)
        begin  
          if(count_onespike<cal_times)
          begin
            ns=ADDR_GENE;
          end
          else if(~fifo_empty)
          begin
            ns=READ_SPIKE;
          end
          else
          begin
            ns=IDLE;
          end
        end
        else
        begin
          ns=WRITE_BACK;
        end
       end
   default:ns=IDLE;
   endcase
end

always@(posedge clk or negedge rst)
begin
  if(!rst)
  begin
    count_onespike<='b0;
    read_en_i<='b0;
    i_cal_times<='b0;
    j_cal_times<='b0;
    read_req<=1'b0;
    write_req<=1'b0;
    w_mem_ren<=1'b0;
    k_addr<='b0;
    p_addr<='b0;
    k_i_reg<='b0;
    k_j_reg<='b0;
    i_i_reg<='b0;
    i_j_reg<='b0;
    base_addr_reg<='b0;
    pool_or_conv_reg<='b0;
    potential_wdata<='b0;
   end
  else
  begin
    case(ns)
      IDLE:begin
            count_onespike<='b0;
            read_en_i<='b0;
            i_cal_times<='b0;
            j_cal_times<='b0;
            read_req<=1'b0;
            write_req<=1'b0;
            w_mem_ren<=1'b0;
            k_addr<='b0;
            p_addr<='b0;
            potential_wdata<='b0;
            base_addr_reg<='b0;
            pool_or_conv_reg<='b0;
      end
      READ_SPIKE:begin
            k_i_reg<=k_i;
            k_j_reg<=k_j;
            i_i_reg<=i_i;
            i_j_reg<=i_j;
            base_addr_reg<=base_addr;
            pool_or_conv_reg<=pool_or_conv;
            read_en_i<=1'b1;
            read_req<=1'b0;
            count_onespike<='b0;
            i_cal_times<='b0;
            j_cal_times<='b0;
            write_req<=1'b0;
      end
      ADDR_GENE:begin
            read_req<=1'b0;
            read_en_i<=1'b0;
            write_req<=1'b0;
            if(!pool_or_conv_reg)
            begin
              w_mem_ren<=1'b1;
              if(i_cal_times==0&&j_cal_times==0)
              begin
                k_addr<=a_min+b_min*k_i_reg;
                p_addr<=(I-a_min)+(J-b_min)*(i_i_reg-k_i_reg+1)+base_addr_reg;
              end
              else
              begin
                k_addr<=a_min+i_cal_times+(b_min+j_cal_times)*k_i_reg;
                p_addr<=(I-a_min-i_cal_times)+(J-b_min-j_cal_times)*(i_i_reg-k_i_reg+1)+base_addr_reg;
              end
            end
            else
            begin
              w_mem_ren<=1'b1;
              //p_addr<=(I>>$clog2(k_i_reg))+(J>>$clog2(k_j_reg))*(i_i_reg>>$clog2(k_i_reg))+base_addr_reg;   $clog2(value) value need to be a constant? 
              p_addr<=(I/k_i_reg)+(J/k_j_reg)*(i_i_reg/k_i_reg)+base_addr_reg; 
            end
      end
      READ_W_P:begin
            read_req<=1'b1;    
      end
      ADD:begin
            read_req<=1'b0;
            w_mem_ren<=1'b0;
            count_onespike<=count_onespike+1;
            if(i_cal_times<a_max-a_min)
            begin 
              i_cal_times<=i_cal_times+1;
            end
            else if(i_cal_times==a_max-a_min)
            begin
              j_cal_times<=j_cal_times+1;
              i_cal_times<=0;
            end
      end
      WRITE_BACK:begin
            write_req<=1'b1;
            if(!pool_or_conv_reg)
            begin
              for(i=0;i<K_L;i=i+1)
              begin
                potential_wdata[((i+1)*POTENTIAL_WIDTH-1)-:POTENTIAL_WIDTH]<=potential_rdata[((i+1)*POTENTIAL_WIDTH-1)-:POTENTIAL_WIDTH]+w_mem_rdata[((i+1)*WEIGHT_WIDTH-1)-:WEIGHT_WIDTH];
              end
            end
            else
            begin
              for(i=0;i<K_L;i=i+1)
              begin
                potential_wdata[((i+1)*POTENTIAL_WIDTH-1)-:POTENTIAL_WIDTH]<=potential_rdata[((i+1)*POTENTIAL_WIDTH-1)-:POTENTIAL_WIDTH]+1;//when doing pooling, we consider filter[1 1;1 1] but not [0.25 0.25;0.25 0.25], so when generate output spikes for pooling, the threshold is 4  
              end
            end  
      end
    default:;
    endcase
  end
end 

assign potential_raddr=read_req?p_addr:'b0;
assign potential_waddr=write_req?p_addr:'b0;

always@(posedge clk or negedge rst)
begin
  if(!rst)
  begin
    finish<='b0;
  end
  else if((cs==WRITE_BACK)&&(ns==IDLE))
  begin
    finish<='b1;
  end
  else
  begin
    finish<='b0;
  end
end

input_fifo#(
.DEPTH (DEPTH),
.WIDTH (WIDTH))
fifo1(
.clk     (clk),
.rst     (rst),
.write_en(write_en),
.read_en (read_en_i),
.w_data  (w_data),
.r_data  (r_data),
.full    (fifo_full),
.empty   (fifo_empty)
);

mem#(
.WIDTH (WEIGHT_WIDTH*K_L),
.DEPTH (WEIGHT_DEPTH))
weight_mem
(
.clk         (clk),
.rst         (rst),
.write_en    (w_mem_wen),
.write_addr  (w_mem_waddr),
.write_data  (w_mem_wdata),
.read_en     (w_mem_ren),
.read_addr   (k_addr),
.read_data   (w_mem_rdata)
);

endmodule 
