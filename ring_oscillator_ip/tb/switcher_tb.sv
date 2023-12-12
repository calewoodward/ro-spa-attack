//add_tree_tb.sv

module switcher_tb();

logic clk, clk_en, rst, go;

switcher
    #(
        .REG_SIZE(5),
        .PERIOD(10)
    ) DUT
    (
        .clk(clk),
        .rst(rst),
        .go(go)
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
    @(posedge clk);
    rst = 1'b0;
    go = 1'b1;
    @(posedge clk);
    go = 1'b0;
    repeat(50) begin
        @(posedge clk);
        $display("bits=%b",DUT.reg_r);
    end
    clk_en = 1'b0;
end

endmodule