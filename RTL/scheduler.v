module scheduler#(
parameter POTENTIAL_WIDTH   = 32,
parameter POTENTIAL_DEPTH   = 728,
parameter I_I = 5, //data width of input data
parameter I_J = 5,
parameter I_L = 5,
parameter K_I = 2, //data width of kernel
parameter K_J = 2,
parameter K_K = 1,
parameter K_L = 12,
parameter POST_WIDTH        = 32
)
(
input                                 clk,
input                                 rst,
input                                 start,
input   [POTENTIAL_WIDTH-1:0]         threhold,
input   [POTENTIAL_WIDTH-1:0]         rest_value,
input   [K_I-1:0]                     k_i,//size of kernel
input   [K_J-1:0]                     k_j,
input   [$clog2(K_L)-1:0]             k_l,
input   [I_I-1:0]                     i_i,//size of input data
input   [I_J-1:0]                     i_j,
input                                 read_grant,
input                                 write_grant,
input                                 post_grant,
input   [POST_WIDTH-1:0]              post_addr,
input   [POTENTIAL_WIDTH*K_L-1:0]     potential_rdata,
output reg [$clog2(POTENTIAL_DEPTH)-1:0] potential_raddr,
output reg [POTENTIAL_WIDTH*K_L-1:0]     potential_wdata,
output reg [$clog2(POTENTIAL_DEPTH)-1:0] potential_waddr,
output reg                               read_req,   
output reg                               write_req,  
output reg [POST_WIDTH-1:0]              post_waddr,  
output reg [POST_WIDTH-1:0]              post_wdata, 
output reg                               post_req
);

parameter IDLE = 3'b000;
parameter READ_SPIKE=3'b001;
parameter WAIT=3'b010;
parameter CHECK_SPIKE=3'b011;
parameter WRITE_POTENTIAL=3'b100;
parameter WRITE_SPIKE=3'b101;

reg [2:0] cs;
reg [2:0] ns;
reg [I_L-1:0] count_kernel;
reg [$clog2(POTENTIAL_DEPTH)-1:0] count_depth;
reg read_grant_reg;
reg [POTENTIAL_WIDTH*K_L-1:0] potential_rdata_reg;
reg [0:0] post_spike_temp [K_L-1:0];
reg spike_empty;

wire [$clog2(POTENTIAL_DEPTH-1)-1:0] neuron_num;//neuron number per output channel
wire [I_I-1:0] i;
wire [I_J-1:0] j;

integer c0;
integer c1;

assign neuron_num=(i_i-k_i+1)*(i_j-k_j+1);
assign i=(potential_raddr-1)%(i_i-k_i+1'b1);
assign j=(potential_raddr-1)/(i_j-k_j+1'b1);

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
    IDLE:ns=start?READ_SPIKE:IDLE;
    READ_SPIKE:ns=read_grant?WAIT:READ_SPIKE;
    WAIT:ns=CHECK_SPIKE;
    //CHECK_SPIKE:ns=(count_kernel==k_l)?IDLE:((potnetial_rdata_reg[(count_kernel+1)*POTENTIAL_WIDTH-1:count_kernel*POTENTIAL_WIDTH]>=threhold))?WRITE_SPIKE:CHECK_SPIKE);
    CHECK_SPIKE:begin
          if(!spike_empty )
            ns=READ_SPIKE;
          else
            ns=WRITE_POTENTIAL;
    end
    WRITE_POTENTIAL:begin
          if(write_grant)
          begin
            ns=WRITE_SPIKE;
          end
          else
          begin
            ns=WRITE_POTENTIAL;
          end
    end
    WRITE_SPIKE:begin
          if((count_kernel==k_l)&&(count_depth==neuron_num)&&(post_grant))
          begin
            ns=IDLE;
          end
          else if((count_kernel==k_l)&&(count_depth<neuron_num)&&(post_grant))
          begin
            ns=READ_SPIKE;
          end
          else
          begin
            ns=WRITE_SPIKE;
          end
    end
    default:ns=IDLE;
  endcase
end

always@(posedge clk or negedge rst)
begin
  if(!rst)
  begin
    potential_raddr<='b0;
    potential_wdata<='b0;
    potential_waddr<='b0;
    read_req       <='b0;
    write_req      <='b0;
    post_waddr     <='b0;
    post_wdata     <='b0;
    count_kernel   <='b0;
    count_depth    <='b0;
    post_req       <='b0;
  end
  else
  begin
    case(ns)
      IDLE:begin
          potential_raddr<='b0;
          potential_wdata<='b0;
          potential_waddr<='b0;
          read_req       <='b0;
          write_req      <='b0;
          post_waddr     <='b0;
          post_wdata     <='b0;
          count_kernel   <='b0;
          count_depth    <='b0;
          post_req       <='b0;
      end
      READ_SPIKE:begin
          read_req<=1'b1;
          write_req<='b0;
          post_req<=1'b0;
      end
      WAIT:begin
          read_req<=1'b0;
          potential_raddr<=potential_raddr+1'b1;
          count_depth<=count_depth+1'b1;
          count_kernel<='b0;
      end
      CHECK_SPIKE:begin
          for(c0=0;c0<K_L;c0=c0+1)
          begin
            if(potential_rdata[((c0+1)*POTENTIAL_WIDTH-1)-:POTENTIAL_WIDTH]>=threhold)
            begin
              potential_wdata[((c0+1)*POTENTIAL_WIDTH-1)-:POTENTIAL_WIDTH]<=rest_value;
              post_spike_temp[c0]<=1'b1;
            end
            else
            begin
              potential_wdata[((c0+1)*POTENTIAL_WIDTH-1)-:POTENTIAL_WIDTH]<=potential_rdata[((c0+1)*POTENTIAL_WIDTH-1)-:POTENTIAL_WIDTH];
              post_spike_temp[c0]<=1'b0;
            end  
          end
      end  
      WRITE_POTENTIAL:begin
          write_req<=1'b1;
          potential_waddr<=potential_raddr-1'b1;
          potential_wdata<=potential_wdata;
          count_kernel<='b0;
        end
      WRITE_SPIKE:begin
          write_req<=1'b0;
          if(count_kernel==0)
          begin
            if(post_spike_temp[count_kernel])
            begin  
              post_req<=1'b1;
              post_waddr<=post_addr;
              post_wdata<={12'b0,i,j,5'b0,count_kernel};
              count_kernel<=count_kernel+1'b1;
            end
            else
            begin
              post_req<=1'b0;
              count_kernel<=count_kernel+1'b1;
            end
          end
          else if(post_grant)
          begin
            if(post_spike_temp[count_kernel])
            begin  
              post_req<=1'b1;
              post_waddr<=post_addr;
              post_wdata<={12'b0,i,j,5'b0,count_kernel};
              count_kernel<=count_kernel+1'b1;
            end
            else
            begin
              post_req<=1'b0;
              count_kernel<=count_kernel+1'b1;
            end
          end
        end
      default:;
      endcase
  end
end

always@(*)
begin
  if(cs==CHECK_SPIKE)
  begin
  for(c1=0;c1<K_L;c1=c1+1)
    spike_empty=spike_empty|post_spike_temp[c1];
  end
  else if(cs==READ_SPIKE)
  begin
    spike_empty=1'b0;
  end
  else
  begin
    spike_empty=spike_empty;
  end
end

always@(posedge clk or negedge rst)
begin
  if(!rst)
    read_grant_reg<='b0;
  else
    read_grant_reg<=read_grant;
end


endmodule
