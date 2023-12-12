// ro.sv
// Cale Woodward
// Single stage ring oscillator with counter for estimating power consumption

module tflipflop
// T-Flip-Flop with asynchronous CLEAR
    (
        input   logic   clk, 
        input   logic   rst, 
        input   logic   t,
        output  logic   q
    );

    always_ff @(posedge clk or posedge rst) begin
        if(rst)     q <= 1'b0;
        else if(t)  begin
            q <= ~q;
        end
    end
    
endmodule


module and2x1
// 2-input AND gate
    (
        input   logic in0,
        input   logic in1,
        output  logic out
    );

    assign out = (in0 && in1) ? 1'b1 : 1'b0;

endmodule

module inv1x1
// 1-input inverter
    (
        input   logic in,
        output  logic out
    );

    assign out = ~in;
endmodule

module add
    #(
        parameter ADD_WIDTH = 19
    )
    (
        input   logic [ADD_WIDTH-1:0] in1, 
        input   logic [ADD_WIDTH-1:0] in2,
        output  logic [ADD_WIDTH-1:0] out
    );

    assign out = in1 + in2;

endmodule

module add_tree
// Parameterized & pipelined add tree for N elements with WIDTH bits
// Also handles case where N is not a power of 2
    #(
        parameter N = 20,
        parameter WIDTH = 14,
        parameter ADD_WIDTH = 19
    )
    (
        input   logic                       clk,
        input   logic                       en,
        input   logic                       rst,
        input   logic [WIDTH-1:0]           in[N],
        input   logic                       add_tree_valid_in,
        output  logic [ADD_WIDTH-1:0]       add_tree_result,
        output  logic                       add_tree_valid_out
    );

    // depth is a function of width
    localparam DEPTH = $clog2(N);
    // for add tree, we need num inputs to be a power of 2
    localparam N_POW = 2**$clog2(N);
    
    // register to hold expanded input array
    logic [ADD_WIDTH-1:0]   in_r[N_POW];
    // wires and registers to hold pipeline stage outputs
    logic [ADD_WIDTH-1:0]   stage  [DEPTH][N_POW/2];
    logic [ADD_WIDTH-1:0]   stage_r[DEPTH][N_POW/2];
    // delay for valid_out (extra delay cycle for registered inputs)
    logic [0:DEPTH]         valid_r;    

    // structural generation of pipelined add tree
    genvar row, col;
    generate
        for (row=0; row<DEPTH; row=row+1) begin : stage_rows
            for (col=0; col<(N_POW/(2**(row+1))); col=col+1) begin : stage_columns
                // first stage connects to the input register
                if(row==0) begin
                    add #(.ADD_WIDTH(ADD_WIDTH)) U_ADD
                    (
                        .in1(in_r[2*col]),
                        .in2(in_r[2*col+1]),
                        .out(stage[0][col])
                    );
                end
                // subsequent stages connect in series
                else begin
                    add #(.ADD_WIDTH(ADD_WIDTH)) U_ADD
                    (
                        .in1(stage_r[row-1][2*col]),
                        .in2(stage_r[row-1][2*col+1]),
                        .out(stage[row][col])
                    );
                end
            end
        end
    endgenerate

    // sequential logic
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            // only need to clear the valid register on reset to save fanout
            valid_r             <= {($size(valid_r)){1'b0}};
            add_tree_valid_out  <= 1'b0;
        end
        else if(en) begin
            // register inputs, padding with zeroes up to ADD_WIDTH and N_POW elements
            for(int i=0; i<N_POW; i=i+1) begin
                if(i<N)
                    in_r[i] <= {{($size(in_r[i])-$size(in[i])){1'b0}},in[i]};
                else
                    in_r[i] <= {ADD_WIDTH{1'b0}};
            end
            // register output from adders at each stage
            stage_r <= stage;
            // register valid in signal on the delay chain
            valid_r[0] <= add_tree_valid_in;
            // move valid signal along delay chain
            for(int i=1; i<=DEPTH; i=i+1) begin
                valid_r[i] <= valid_r[i-1];
            end
            // assign output from final stage
            add_tree_result <= stage[DEPTH-1][0];
            add_tree_valid_out <= valid_r[DEPTH-1];
        end
    end

endmodule

module ro_counter
// Single-stage ring oscillator with enable signal. When enabled, the RO begins incrementing a 
// WIDTH-bit counter implemented from WIDTH number of TFFs
    #(
        parameter WIDTH=14
    )
    (
    input   logic               en,
    input   logic               rst, 
    output  logic   [WIDTH-1:0] roc_out
    );

    // logic to handle the intermediary signals
    logic and_out;
    logic inv_out;
    // array for the series of tff, where the output Q from one tff connects to the input clock of the next tff
    logic [WIDTH:0] tff_out;

    and2x1 AND(
        .in0(en),
        .in1(inv_out),
        .out(and_out)
    );

    inv1x1 INV(
        .in(and_out),
        .out(inv_out)
    );

    // connect first tff_out to the output of the inverter
    assign tff_out[0] = inv_out;

    // generate N-bit counter from tff
    genvar i;
    generate
        for (i=1; i<=WIDTH; i=i+1) begin : tff_counter
            tflipflop U_TFF
            (
                .clk(tff_out[i-1]),
                .rst(rst),
                .t(1'b1),
                .q(tff_out[i])
            );
        end
    endgenerate

    // connect count to tff outputs
    assign roc_out[WIDTH-1:0] = tff_out[WIDTH:1];

endmodule

module ro_controller
// take num samples as input. generate num_sample cycles of ro collections upon go. stop on stop.
// must respond to stop/go signals on same cycle they are received
// output done when finished
    #(
        parameter NUM_SAMPLE_WIDTH = 10
    )
    (
     input  logic                           clk,
     input  logic                           rst,
     input  logic                           go,
     input  logic                           stop,
     input  logic   [NUM_SAMPLE_WIDTH-1:0]  num_samples,
     input  logic   [NUM_SAMPLE_WIDTH-1:0]  collect_cycles,
     output logic                           add_tree_rst,
     output logic                           roc_rst,
     output logic                           roc_en,
     output logic                           roc_valid
    );

    typedef enum  {START, CLEAR, COLLECT, READ, DONE} state_t;
    state_t next_state, state_r;

    typedef logic [NUM_SAMPLE_WIDTH-1:0] count_t;
    count_t next_sample_count, sample_count_r, next_collect_count, collect_count_r;

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            state_r         <= START;
        end
        else begin
            state_r         <= next_state;
            sample_count_r  <= next_sample_count;
            collect_count_r <= next_collect_count;
        end
    end

    always_comb begin
        add_tree_rst        <= 1'b0;
        roc_rst             <= 1'b0;
        roc_en              <= 1'b0;
        roc_valid           <= 1'b0;
        next_state          = state_r;
        next_sample_count   = sample_count_r;
        next_collect_count  = collect_count_r;

        case (state_r)
            START   : begin
                if(go) begin
                    next_sample_count   = num_samples;
                    add_tree_rst        <= 1'b1;
                    next_state          = CLEAR;
                end
            end
            CLEAR   : begin
                roc_rst             <= 1'b1;
                next_collect_count  = collect_cycles;
                if(stop)
                    next_state  = DONE;
                else 
                    next_state  = COLLECT;
            end
            COLLECT  : begin
                roc_en              <= 1'b1;
                next_collect_count  = collect_count_r - 1'b1;
                if(stop)
                    next_state  = DONE;
                else if((collect_count_r <= 1))
                    next_state  = READ;
            end
            READ    : begin
                roc_valid   <= 1'b1;
                next_sample_count  = sample_count_r - 1'b1;
                if((stop) || (sample_count_r+1 <= 1))
                    next_state  = DONE;
                else
                    next_state  = CLEAR;
            end
            DONE    : begin
                if(!go)
                    next_state  = START;
            end
            default : begin
                next_state  = START;
            end
        endcase
    end
endmodule

module ro_adder
// Implements N instances of ro_counters and sums them with a pipelined add tree
    #(
        parameter N = 20,
        parameter WIDTH=14,
        parameter ADD_WIDTH = 19
    )
    (
        input   logic                           clk,
        input   logic                           add_tree_rst,
        input   logic                           roc_en,
        input   logic                           roc_rst,
        input   logic                           roc_valid,
        output  logic [ADD_WIDTH-1:0]           add_tree_result,
        output  logic                           add_tree_valid_out
    );

    // WIDTH-bit array of N elements to hold ro_counter outputs
    logic [WIDTH-1:0] roc_out[N];

    // generate N ro_counters
    genvar i;
    generate
        for (i=0; i<N; i=i+1) begin : ro_counter
            ro_counter 
                #(
                    .WIDTH(WIDTH)
                ) U_RO_COUNTER
                (
                    .en(roc_en),
                    .rst(roc_rst),
                    .roc_out(roc_out[i])
                );
        end
    endgenerate

    // add tree
    add_tree
        #(
            .N(N),
            .WIDTH(WIDTH),
            .ADD_WIDTH(ADD_WIDTH)
        ) U_ADD_TREE
        (
            .clk(clk),
            .en(1'b1),
            .rst(add_tree_rst),
            .in(roc_out),
            .add_tree_valid_in(roc_valid),
            .add_tree_result(add_tree_result),
            .add_tree_valid_out(add_tree_valid_out)
        );

endmodule

// module sanity
//     #(
//         parameter RESULT_WIDTH = 32
//     )
//     (
//         input  logic                        clk,
//         input  logic                        rst,
//         input  logic                        go,
//         output logic                        valid,
//         output logic [RESULT_WIDTH-1:0]     count
//     );

//     typedef enum  {S_START, S_COUNT} state_t;
//     state_t next_state, state_r;

//     typedef logic [RESULT_WIDTH-1:0] count_t;
//     count_t next_count, count_r;

//     logic next_valid;

//     always_ff @(posedge clk or posedge rst) begin
//         if(rst) begin  
//             state_r         <= S_START;
//             count_r         <= 0;
//             count           <= 0;
//             valid           <= 1'b0;
//         end
//         else begin
//             state_r         <= next_state;
//             count_r         <= next_count;
//             count           <= next_count;
//             valid           <= next_valid;
//         end
//     end

//     always_comb begin
//         next_state          = state_r;
//         next_count          = count_r;
//         next_valid          = 1'b0;

//         case (state_r)
//             S_START   : begin
//                 next_count          = 0;
//                 if(go) begin
//                     next_state      = S_COUNT;
//                 end
//             end
//             S_COUNT   : begin
//                 next_count  = count_r + 1'b1;
//                 next_valid  = 1'b1;
//             end
//             default : begin
//                 next_state  = S_START;
//             end
//         endcase
//     end
// endmodule

module ro_top
    #(
        parameter N                 = 20,
        parameter WIDTH             = 14,
        parameter ADD_WIDTH         = 19,
        parameter NUM_SAMPLE_WIDTH  = 10,
        parameter RESULT_WIDTH      = 32,
        parameter FIFO_DEPTH        = 1024,
        parameter FIFO_WIDTH        = 20,
        parameter PIPELINE_LATENCY  = 5
    )
    (
        input  logic                        clk,
        input  logic                        afu_rst,
        input  logic                        go,
        input  logic                        stop,
        input  logic [NUM_SAMPLE_WIDTH-1:0] num_samples,
        input  logic [NUM_SAMPLE_WIDTH-1:0] collect_cycles,
        input  logic                        fifo_rd_en,
        output logic                        fifo_empty,
        output logic [FIFO_WIDTH-1:0]       fifo_rd_data
    );

    logic                           roc_en;
    logic                           roc_rst;
    logic                           roc_valid;
    logic                           add_tree_rst;
    logic                           add_tree_valid_out;
    logic   [WIDTH+$clog2(N)-1:0]   add_tree_result;
    logic   [FIFO_WIDTH-1:0]        fifo_wr_data;

    ro_controller
        #(
            .NUM_SAMPLE_WIDTH(NUM_SAMPLE_WIDTH)
        ) ro_controller
        (
            .clk(clk),
            .rst(afu_rst),
            .go(go),
            .stop(stop),
            .num_samples(num_samples),
            .collect_cycles(collect_cycles),
            .roc_rst(roc_rst),
            .roc_en(roc_en),
            .add_tree_rst(add_tree_rst),
            .roc_valid(roc_valid)
        );

    ro_adder 
        #(
            .N(N),
            .WIDTH(WIDTH),
            .ADD_WIDTH(ADD_WIDTH)
        ) ro_adder
        (
            .clk(clk),
            .roc_en(roc_en),
            .roc_rst(roc_rst),
            .add_tree_rst(add_tree_rst),
            .roc_valid(roc_valid),
            .add_tree_result(add_tree_result),
            .add_tree_valid_out(add_tree_valid_out)
        );

    // pad fifo write data with 0's if needed
    assign fifo_wr_data[FIFO_WIDTH-1:ADD_WIDTH] = {(FIFO_WIDTH-ADD_WIDTH){1'b0}};
    assign fifo_wr_data[ADD_WIDTH-1:0] = add_tree_result;

    fifo 
        #(
            .WIDTH(FIFO_WIDTH),
            .DEPTH(FIFO_DEPTH),
            // This leaves enough space to absorb the entire contents of the
            // pipeline when there is a stall.
            .ALMOST_FULL_COUNT(FIFO_DEPTH-PIPELINE_LATENCY)
        ) result_fifo 
        (
            .clk(clk),
            .rst(afu_rst),
            .rd_en(fifo_rd_en),
            .wr_en(add_tree_valid_out),
            .empty(fifo_empty),
            .full(),
            .almost_full(),
            .count(),
            .space(),
            .wr_data(fifo_wr_data),
            .rd_data(fifo_rd_data)
        );

endmodule