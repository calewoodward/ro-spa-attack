module ro_tb();

localparam int  N                   = 20;
localparam int  WIDTH               = 14;
localparam int  ADD_WIDTH           = WIDTH+$clog2(N);

localparam int  NUM_SAMPLE_WIDTH    = 16;
localparam int  RESULT_WIDTH        = 32;
localparam int  FIFO_DEPTH          = 512;
localparam int  FIFO_WIDTH          = 20;
localparam int  PIPELINE_LATENCY    = $clog2(N);
localparam int  REG_SIZE            = 20;
localparam int  SWITCH_DURATION     = 10;

logic clk, clk_en, rst, go, stop, fifo_empty, fifo_rd_en;
logic [NUM_SAMPLE_WIDTH-1:0]    num_samples;
logic [NUM_SAMPLE_WIDTH-1:0]    collect_cycles;
logic [FIFO_WIDTH-1:0]        fifo_rd_data;

   ro_top
      #(
         .N(N),
         .WIDTH(WIDTH),
         .ADD_WIDTH(ADD_WIDTH),
         .NUM_SAMPLE_WIDTH(NUM_SAMPLE_WIDTH),
         .RESULT_WIDTH(RESULT_WIDTH),
         .FIFO_DEPTH(FIFO_DEPTH),
         .FIFO_WIDTH(FIFO_WIDTH),
         .PIPELINE_LATENCY(PIPELINE_LATENCY),
         .REG_SIZE(REG_SIZE),
         .SWITCH_DURATION(SWITCH_DURATION)
      ) ro_top
      (
         .clk(clk),
         .afu_rst(rst),
         .go(go),
         .stop(1'b0),
         .num_samples(num_samples),
         .collect_cycles(collect_cycles),
         .fifo_empty(fifo_empty),
         .fifo_rd_en(fifo_rd_en),
         .fifo_rd_data(fifo_rd_data)
      );

initial begin
    clk = 1'b0;
    clk_en = 1'b1;
    while(clk_en) begin
        #10
        clk = ~clk;
    end
end

initial begin
    rst = 1'b1;
    go  = 1'b0;
    num_samples = 16'd20;
    collect_cycles = 1;
    fifo_rd_en  = 1'b0;
    repeat(3) begin
        @(posedge clk);
    end
    rst = 1'b0;
    go  = 1'b1;
    @(posedge clk);
    go = 1'b0;
    repeat((num_samples*PIPELINE_LATENCY)/2) begin
        @(posedge clk);
        fifo_rd_en = 1'b0;
        if(!fifo_empty) begin
            fifo_rd_en = 1'b1;
            $display("fifo data = %d", fifo_rd_data);
        end
    end
    collect_cycles = 10;
    $display("changing cycles");
    repeat(200) begin
        @(posedge clk);
        fifo_rd_en = 1'b0;
        if(!fifo_empty) begin
            fifo_rd_en = 1'b1;
            $display("fifo data = %d", fifo_rd_data);
        end
    end
    $display("test complete");
    clk_en = 1'b0;
end

endmodule