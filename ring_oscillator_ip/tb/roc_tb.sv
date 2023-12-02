//add_tree_tb.sv

module roc_tb();

logic clk, clk_en, rst, en, valid_in;

ro_controller DUT
    (
        .clk(clk),
        .rst(rst),
        .en(en),
        .valid_in(valid_in)
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
    repeat(20) begin
        @(posedge clk);
        $display("rst=%b en =%b val=%b",rst,en,valid_in);
    end
    clk_en = 1'b0;
end

endmodule