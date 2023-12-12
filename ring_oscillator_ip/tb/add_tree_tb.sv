//add_tree_tb.sv

module add_tree_tb();

localparam WIDTH = 6;
localparam N = 5;

logic [WIDTH-1:0]               in [N-1:0];
logic [WIDTH+$clog2(N)-1:0] add_tree_result;

logic clk, clk_en, en, rst, add_tree_valid_in, add_tree_valid_out;

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
        .add_tree_valid_in(add_tree_valid_in),
        .add_tree_result(add_tree_result),
        .add_tree_valid_out(add_tree_valid_out)
    );

initial begin
    clk = 1'b0;
    clk_en = 1'b1;
    while(clk_en) begin
        #10
        clk <= ~clk;
    end
end

initial begin
    rst <= 1'b1;
    en <= 1'b0;
    in <= '{6'h1, 6'h2, 6'h3, 6'h4, 6'h5};//, 6'h6, 6'h7, 6'h8};
    add_tree_valid_in <= 1'b0;

    repeat(2) begin
        @(posedge clk);
    end

    rst <= 1'b0;
    en <= 1'b1;
    add_tree_valid_in <= 1'b1;
    @(posedge clk);
    $display("-----------------------------------------------");
    $display("valid_in=%b\nin={%d,%d,%d,%d,%d}",add_tree_valid_in,in[0],in[1],in[2],in[3],in[4]);
    $display("valid = %b, output=%d",add_tree_valid_out, add_tree_result);
    
    in <= '{6'h1, 6'h2, 6'h3, 6'h4, 6'h6};
    @(posedge clk);
    $display("-----------------------------------------------");
    $display("valid_in  =%b\nin={%d,%d,%d,%d,%d}",add_tree_valid_in,in[0],in[1],in[2],in[3],in[4]);
    $display("valid_out = %b, output=%d",add_tree_valid_out, add_tree_result);


    in <= '{6'h1, 6'h2, 6'h3, 6'h5, 6'h6};
    @(posedge clk);
    $display("-----------------------------------------------");
    $display("valid_in  =%b\nin={%d,%d,%d,%d,%d}",add_tree_valid_in,in[0],in[1],in[2],in[3],in[4]);
    $display("valid = %b, output=%d",add_tree_valid_out, add_tree_result);

    in <= '{6'h1, 6'h2, 6'h4, 6'h5, 6'h6};
    @(posedge clk);
    $display("-----------------------------------------------");
    $display("valid_in  =%b\nin={%d,%d,%d,%d,%d}",add_tree_valid_in,in[0],in[1],in[2],in[3],in[4]);
    $display("valid = %b, output=%d",add_tree_valid_out, add_tree_result);
    
    in <= '{6'h1, 6'h3, 6'h4, 6'h5, 6'h6};
    @(posedge clk);
    $display("-----------------------------------------------");
    $display("valid_in  =%b\nin={%d,%d,%d,%d,%d}",add_tree_valid_in,in[0],in[1],in[2],in[3],in[4]);
    $display("valid = %b, output=%d",add_tree_valid_out, add_tree_result);

    in <= '{6'h2, 6'h3, 6'h4, 6'h5, 6'h6};
    @(posedge clk);
    $display("-----------------------------------------------");
    $display("valid_in  =%b\nin={%d,%d,%d,%d,%d}",add_tree_valid_in,in[0],in[1],in[2],in[3],in[4]);
    $display("valid = %b, output=%d",add_tree_valid_out, add_tree_result);


    in <= '{6'h2, 6'h3, 6'h4, 6'h5, 6'h7};
    @(posedge clk);
    $display("-----------------------------------------------");
    $display("valid_in  =%b\nin={%d,%d,%d,%d,%d}",add_tree_valid_in,in[0],in[1],in[2],in[3],in[4]);
    $display("valid = %b, output=%d",add_tree_valid_out, add_tree_result);
    
    in <= '{6'h2, 6'h3, 6'h4, 6'h6, 6'h7};
    @(posedge clk);
    $display("-----------------------------------------------");
    $display("valid_in  =%b\nin={%d,%d,%d,%d,%d}",add_tree_valid_in,in[0],in[1],in[2],in[3],in[4]);
    $display("valid = %b, output=%d",add_tree_valid_out, add_tree_result);
    
    in <= '{6'h2, 6'h3, 6'h5, 6'h6, 6'h7};
    @(posedge clk);
    $display("-----------------------------------------------");
    $display("valid_in  =%b\nin={%d,%d,%d,%d,%d}",add_tree_valid_in,in[0],in[1],in[2],in[3],in[4]);
    $display("valid = %b, output=%d",add_tree_valid_out, add_tree_result);

    in <= '{6'h2, 6'h4, 6'h5, 6'h6, 6'h7};
    @(posedge clk);
    $display("-----------------------------------------------");
    $display("valid_in  =%b\nin={%d,%d,%d,%d,%d}",add_tree_valid_in,in[0],in[1],in[2],in[3],in[4]);
    $display("valid = %b, output=%d",add_tree_valid_out, add_tree_result);    

    in <= '{6'h3, 6'h4, 6'h5, 6'h6, 6'h7};
    @(posedge clk);
    $display("-----------------------------------------------");
    $display("valid_in  =%b\nin={%d,%d,%d,%d,%d}",add_tree_valid_in,in[0],in[1],in[2],in[3],in[4]);
    $display("valid = %b, output=%d",add_tree_valid_out, add_tree_result);
    add_tree_valid_in <= 1'b0;
    repeat(10) begin
        @(posedge clk);
        $display("-----------------------------------------------");
        $display("valid_in  =%b\nin={%d,%d,%d,%d,%d}",add_tree_valid_in,in[0],in[1],in[2],in[3],in[4]);
        $display("valid = %b, output=%d",add_tree_valid_out, add_tree_result);
    end
    clk_en <= 1'b0;
end

endmodule