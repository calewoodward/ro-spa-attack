module mod_exp_tb();
    localparam int KEY_SIZE  = 64;
    localparam int RSA_MOD   = 64;
    logic                   clk;
    logic                   clk_en;
    logic                   rst;
    logic                   go;   
    logic [RSA_MOD-1:0]     M; 
    logic [RSA_MOD-1:0]     N; 
    logic [KEY_SIZE-1:0]    d; 
    logic                   done;
    logic [RSA_MOD-1:0]     R;

    initial begin
        clk = 1'b0;
        clk_en = 1'b1;
        while(clk_en) begin
            #10
            clk = ~clk;
        end
    end

    mod_exp DUT(.*);

    initial begin
    rst = 1'b1;
    go  = 1'b0;
    //M = 512'h1ffffffffffffffffffff003031300d060960864801650304020105000420f75db0d45d3189d910fc5d782745578c59481accf6f7cbf5e79bdecbe5233399;
    //N = 512'h91b06f65a203bebb1cfa1b065cb2142e3771d113024a902f0829be8effe539ff6caa7c4b7f87e1913481e8c4f88a3f3e27a853179119aa029fe00e4c45a6b5cb;
    //d = 512'hffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000;
    M = 64'b1001100001010011011001110110111000001101011100010011100100000001;
    N = 64'b0111110100011001101101001110101100010001001001100101000110100110;
    d = 64'b0000000000000000000000000000000000000000000000010000000000000001;
    
    repeat(3) begin
        @(posedge clk);
    end
    rst = 1'b0;
    go  = 1'b1;
    @(posedge clk);
    go = 1'b0;
    repeat(100)
        @(posedge clk);
    while(done==1'b0) begin
        @(posedge clk);
    end
    $display("Output= %b",R);
    clk_en = 1'b0;
end    



endmodule