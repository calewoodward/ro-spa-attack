//add_tree_tb.sv

module add_tree_tb();

localparam WIDTH = 6;
localparam N = 5;

logic [WIDTH-1:0]               in [N-1:0];
logic [WIDTH+$clog2(N)-1:0] out;

logic clk, clk_en, en, rst, valid_in, valid_out;

add_tree
    #(
        .WIDTH(WIDTH),
        .N(N)
    ) DUT
    (
        .clk(clk),
        .en(en),
        .rst(rst),
        .in(in),
        .valid_in(valid_in),
        .out(out),
        .valid_out(valid_out)
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
    en = 1'b0;
    in = '{6'h1, 6'h2, 6'h3, 6'h4, 6'h5};//, 6'h6, 6'h7, 6'h8};
    valid_in = 1'b0;
    $display("in1=%d\nin2=%d\nin3=%d\nin4=%d\n",in[0],in[1],in[2],in[3]);

    repeat(2) begin
        @(posedge clk);
    end
    rst = 1'b0;
    en = 1'b1;
    valid_in = 1'b1;
    @(posedge clk);
    valid_in = 1'b0;
    repeat(10) begin
        @(posedge clk);
    end
    $display("output=%d",out);
    clk_en = 1'b0;
end

endmodule