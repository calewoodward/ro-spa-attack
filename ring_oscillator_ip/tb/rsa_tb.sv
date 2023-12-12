//rsa_tb.sv

module rsa_tb();

localparam KEYSIZE = 1024;
localparam EXP = 1024'h3ff1de37c6696bf2f7c48165b91f4cc4a8b7f8661c08865313c933fb01ba22ae221192d92c73a9b1d7a854ba935a2a60e07dfca1945c9ce1757a9c468cc2dae6a5188f80d93975f9a98c61f37a364f1d9f657f59b8d32811290182177699066fec28ab6b4d13adf1f3293f670a53e25c99266ccbf54dcbb002c1b83a76360a39;
localparam MOD = 1024'hb66083d63a94adbc17e7034e49768826e03773064b380c4b8943927cdfe07f8b1e5998022d01d86eeef091939128249ed5699f480da92bc1a8e9aa59d71866797de3133106bda6352692f8ee44f1bab89c32b445e1734dd53c09cba8c0a6c69697f19c093120b006b5c6589896b876d1404a14af3d3afdebb7387440b0c2951f;
localparam MSG = 1024'h08f27c9f413c6ab89efd5d60956ce56df74078cde3b97722629621fd013d9959eea378235f68255a26db83e3bffacb235ba7f35aeef6c18f50415dacd8fa2e30341c3e909e6c01bcb900c786168ff1c0fb6e386264b296baacc81a98acb6c1bc934b77293865ba8ea5694050dd566087255db25a2f2a2e82fea24860d83559a7;

logic [KEYSIZE-1:0]     indata;
logic [KEYSIZE-1:0]     inExp;
logic [KEYSIZE-1:0]     inMod;
logic [KEYSIZE-1:0]     cypher;
logic                   clk;
logic                   ds;
logic                   reset;
logic                   ready;

logic clk_en;

RSACypher #(.KEYSIZE(KEYSIZE)) DUT (.*);

initial begin
    clk = 1'b0;
    clk_en = 1'b1;
    while(clk_en) begin
        #1
        clk <= ~clk;
    end
end

initial begin
    reset   <= 1'b1;
    ds      <= 1'b0;
    indata  <= MSG;
    inExp   <= EXP;
    inMod   <= MOD;

    repeat(2) begin
        @(posedge clk);
    end

    reset   <= 1'b0;
    ds      <= 1'b1;
    @(posedge clk);
    ds      <= 1'b0;
    @(posedge clk);
    @(posedge clk);
    while(ready==1'b0) begin
        @(posedge clk);
    end
    $display("Result=%h",cypher);
    clk_en  <= 1'b0;
end

endmodule