module ro_tb();

logic clk, clk_en, go, add_tree_valid_out;
logic [3-1:0] num_samples;
logic [16+$clog2(8)-1:0]  add_tree_result;

ro_top 
    #(
      .N(8),
      .WIDTH(16),
      .NUM_SAMPLE_WIDTH(3),
      .RESULT_WIDTH(8)
    ) DUT
    (
        .clk(clk),
        .go(go),
        .num_samples(num_samples),
        .add_tree_result(add_tree_result),
        .add_tree_valid_out(add_tree_valid_out)
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
    go = 1'b1;
    num_samples = 3'b111;
    repeat(100) begin
        @(posedge clk);
        $display("valid=%b result =%d", add_tree_valid_out, add_tree_result);
    end
    clk_en = 1'b0;
end

endmodule