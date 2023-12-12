module switcher
    #(
        parameter int REG_SIZE          = 64,
        parameter int SWITCH_DURATION   = 100  
    )
    (
        input   logic                   clk,
        input   logic                   rst,
        input   logic                   en
    );

    typedef enum  {START, SWITCH0, SWITCH1, IDLE} state_t;
    state_t next_state, state_r;

    typedef logic [$clog2(SWITCH_DURATION)-1:0] count_t;
    count_t next_count, count_r;

    logic [REG_SIZE-1:0]    next_reg, reg_r;

    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            state_r <= START;
        end
        else begin
            state_r <= next_state;
            count_r <= next_count;
            reg_r   <= next_reg;
        end
    end


always_comb begin
        next_state  = state_r;
        next_count  = count_r;
        next_reg    = reg_r;

        case (state_r)
            START       : begin
                next_reg    = 0;
                next_count = SWITCH_DURATION-1;
                if(en) begin
                    next_state = SWITCH1;
                end
            end
            SWITCH0       : begin
                next_reg    = 0;
                if(!en)
                    next_state = IDLE;
                else if(count_r==0) begin
                    next_count = SWITCH_DURATION-1;
                    next_state = IDLE;
                end
                else begin
                    next_count = count_r - 1'b1;
                    next_state = SWITCH1;
                end
            end
            SWITCH1       : begin
                next_reg    = {(REG_SIZE){1'b1}};
                if(!en)
                    next_state = IDLE;
                else if(count_r==0) begin
                    next_count = SWITCH_DURATION-1;
                    next_state = IDLE;
                end
                else begin
                    next_count = count_r - 1'b1;
                    next_state = SWITCH0;
                end
            end
            IDLE        : begin
                next_reg    = 0;
                if(!en)
                    next_state = IDLE;
                else if(count_r==0) begin
                    next_count = SWITCH_DURATION-1;
                    next_state = SWITCH1;
                end
                else begin
                    next_count = count_r - 1'b1;
                end
            end
            default     : begin                
                next_state  = START;
            end
        endcase
    end
endmodule