module mod_exp
// T-Flip-Flop with asynchronous CLEAR
    #(
        parameter int KEY_SIZE  = 64,
        parameter int RSA_MOD   = 64
    )
    (
        input   logic                   clk,
        input   logic                   rst,
        input   logic                   go,   
        input   logic [RSA_MOD-1:0]     M,
        input   logic [RSA_MOD-1:0]     N, 
        input   logic [KEY_SIZE-1:0]    d, 
        output  logic                   done,
        output  logic [RSA_MOD-1:0]     R
    );

    typedef enum  {READY, CHECK_EXP, EXP_0, EXP_1, CHECK_DONE} state_t;
    state_t next_state, state_r;

    typedef logic [$clog2(KEY_SIZE):0] count_t;
    count_t count_r, next_count;

    logic [RSA_MOD-1:0]     next_S, S_r, next_N, N_r, next_d, d_r, next_R, R_r;
    logic                   next_done, done_r;

    assign done = done_r;
    assign R    = R_r;

    always_ff @(posedge clk) begin
        state_r         <= next_state;
        count_r         <= next_count;
        d_r             <= next_d;
        N_r             <= next_N;
        R_r             <= next_R;
        S_r             <= next_S;
        done_r          <= next_done;
    end


always_comb begin
        next_state  = state_r;
        next_count  = count_r;
        next_d      = d_r;
        next_R      = R_r;
        next_S      = S_r;
        next_N      = N_r;
        next_done   = done_r;

        case (state_r)
            READY       : begin
                if(go) begin
                    next_d = d;
                    next_R = 1;
                    next_S = M;
                    next_N = N;
                    next_count = KEY_SIZE-1;
                    next_done = 1'b0;
                    next_state = CHECK_EXP;
                end
            end
            CHECK_EXP   : begin
                if(d_r%2==1'b1)
                    next_state = EXP_1;
                else
                    next_state = EXP_0;
                next_d = d_r >> 1;
            end
            EXP_0       : begin
                next_S      = (S_r * S_r) % N_r;
                next_state  = CHECK_DONE;
            end
            EXP_1       : begin
                next_R      = (R_r * S_r) % N_r;
                next_S      = (S_r * S_r) % N_r;
                next_state  = CHECK_DONE;                
            end
            CHECK_DONE   : begin
                if(count_r==0) begin
                    next_state = READY;
                    next_done = 1'b1;
                end
                else begin
                    next_count = count_r - 1'b1;
                    next_state = CHECK_EXP;
                end
            end
            default     : begin
                next_state  = READY;
            end
        endcase
    end
endmodule