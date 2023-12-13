// Copyright (c) 2020 University of Florida
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// Greg Stitt
// University of Florida

//===================================================================
// Interface Description
// clk  : Clock input
// rst  : Reset input (active high)
// mmio : Memory-mapped I/O interface. See mmio_if.vh and description above.
// dma  : DMA interface. See dma_if.vh and description above.
//===================================================================

`include "cci_mpf_if.vh"

module afu
  (
   input clk,
   input rst,
	 mmio_if.user mmio,
	 dma_if.peripheral dma
   );

   // parameters for FPGA connection via DMA
   localparam int CL_ADDR_WIDTH = $size(t_ccip_clAddr);              // 64-bit address lines
   localparam int CL_DATA_WIDTH = $size(t_ccip_clData);              // 512-bit data lines
   localparam int INPUT_WIDTH = 32;
   localparam int RESULT_WIDTH = 32;
   localparam int INPUTS_PER_CL = CL_DATA_WIDTH / INPUT_WIDTH;       // 16
   localparam int RESULTS_PER_CL = CL_DATA_WIDTH / RESULT_WIDTH;     // 16x 32-bit results per line

   // parameters for ring-oscillator adder
   localparam int  N = 20;
   localparam int  WIDTH=14;

    // each level of depth requires an extra bit of width, and all adders use the same width
   localparam int ADD_WIDTH = WIDTH + $clog2(N);
   
   // pipeline latency is a function of the number of RO adders (N)
   localparam int PIPELINE_LATENCY = $clog2(N);
   
   // following arria10 data sheet for available block ram sizes. 
   // 512 depth with 32-bit inputs was too slow (fifo was filling up).
   // increased to 1024 depth with 20-bit inputs
   localparam int FIFO_DEPTH = 1024;
   localparam int FIFO_WIDTH = 20;
   
   // logic for MMIO
   typedef logic [CL_ADDR_WIDTH:0] count_t;   
   count_t 	num_samples, collect_cycles;
   logic 	ro_go, ro_done, rsa_go, rsa_done;

   // 64-byte (512-bit) virtual memory addresses
   localparam int VIRTUAL_BYTE_ADDR_WIDTH = 64;
   logic [VIRTUAL_BYTE_ADDR_WIDTH-1:0] rd_addr, wr_addr;

   // logic for pipeline IO
   logic 		               fifo_rd_en, fifo_empty;
   logic [FIFO_WIDTH-1:0]     fifo_rd_data;

   //logic for rsa
   localparam KEYSIZE = 1024;
   localparam EXP = 1024'h3ff1de37c6696bf2f7c48165b91f4cc4a8b7f8661c08865313c933fb01ba22ae221192d92c73a9b1d7a854ba935a2a60e07dfca1945c9ce1757a9c468cc2dae6a5188f80d93975f9a98c61f37a364f1d9f657f59b8d32811290182177699066fec28ab6b4d13adf1f3293f670a53e25c99266ccbf54dcbb002c1b83a76360a39;
   localparam MOD = 1024'hb66083d63a94adbc17e7034e49768826e03773064b380c4b8943927cdfe07f8b1e5998022d01d86eeef091939128249ed5699f480da92bc1a8e9aa59d71866797de3133106bda6352692f8ee44f1bab89c32b445e1734dd53c09cba8c0a6c69697f19c093120b006b5c6589896b876d1404a14af3d3afdebb7387440b0c2951f;
   localparam MSG = 1024'h08f27c9f413c6ab89efd5d60956ce56df74078cde3b97722629621fd013d9959eea378235f68255a26db83e3bffacb235ba7f35aeef6c18f50415dacd8fa2e30341c3e909e6c01bcb900c786168ff1c0fb6e386264b296baacc81a98acb6c1bc934b77293865ba8ea5694050dd566087255db25a2f2a2e82fea24860d83559a7;
   
   logic [KEYSIZE-1:0] rsa_mod;
   logic [KEYSIZE-1:0] rsa_exp;
   logic [KEYSIZE-1:0] rsa_msg;
   logic [KEYSIZE-1:0] rsa_out;
   logic               rsa_ready;

   assign rsa_mod = MOD;
   assign rsa_exp = EXP;
   assign rsa_msg = MSG;

   memory_map
     #(
       .ADDR_WIDTH(VIRTUAL_BYTE_ADDR_WIDTH),
       .SIZE_WIDTH(CL_ADDR_WIDTH+1)
       )
     memory_map (.*);

   ro_top
      #(
         .N(N),
         .WIDTH(WIDTH),
         .ADD_WIDTH(ADD_WIDTH),
         .NUM_SAMPLE_WIDTH(CL_ADDR_WIDTH),
         .RESULT_WIDTH(RESULT_WIDTH),
         .FIFO_DEPTH(FIFO_DEPTH),
         .FIFO_WIDTH(FIFO_WIDTH),
         .PIPELINE_LATENCY(PIPELINE_LATENCY)
      ) ro_top
      (
         .clk(clk),
         .afu_rst(rst),
         .go(ro_go),
         //.stop(rsa_done),
         .stop(1'b0),
         .num_samples(num_samples),
         .collect_cycles(collect_cycles),
         .fifo_empty(fifo_empty),
         .fifo_rd_en(fifo_rd_en),
         .fifo_rd_data(fifo_rd_data)
      );

   RSACypher
      #(
         .KEYSIZE(KEYSIZE)
      )
      (
         .indata(rsa_msg),
         .inExp(rsa_exp),
         .inMod(rsa_mod),
         .cypher(rsa_out),
         .clk(clk),
         .ds(rsa_go),
         .reset(rst),
         .ready(rsa_ready)
      );

   // only set rsa_done after rsa_go has been received
   logic rsa_started;
   always_ff @ (posedge clk or posedge rst) begin     
      if (rst) begin
         rsa_started <= 1'b0;
         rsa_done  <= 1'b0;
      end
      else begin
         if (rsa_go)
            rsa_started <= 1'b1;
         else if ((rsa_started==1'b1) && (rsa_ready==1'b1))
            rsa_done <= 1'b1;
      end
   end
   
   // Tracks the number of results in the output buffer to know when to
   // write the buffer to memory (when a full cache line is available).
   logic [$clog2(RESULTS_PER_CL):0] result_count_r;

   // Output buffer to assemble a cache line out of 32-bit results.
   logic [CL_DATA_WIDTH-1:0] output_buffer_r;
   
   // The output buffer is full when it contains RESULT_PER_CL results (i.e.,
   // a full cache line) to write to memory and there isn't currently a write
   // to the DMA (which resets result_count_r). The && !dma.wr_en isn't neeeded
   // but can save a cycle every time there is an output written to memory.
   logic output_buffer_full;
   assign output_buffer_full = (result_count_r == RESULTS_PER_CL) && !dma.wr_en;
   
   // Read from the absorption FIFO when there is data in it, and when the 
   // output buffer is not full.     
   assign fifo_rd_en = !fifo_empty && !output_buffer_full;   
   
   // Pack results into a cache line to write to memory.
   always_ff @ (posedge clk or posedge rst) begin     
      if (rst) begin
	      result_count_r <= '0;
      end
      else begin
	      // Every time the DMA writes a cache line, reset the result count.
         if (dma.wr_en) begin
            // Must be blocking assignment in case fifo_rd_en is also asserted.
            result_count_r = '0;
         end        		 
	 
         // Whenever something is read from the absorption fifo, shift the 
         // output buffer to the right and append the data from the FIFO to 
         // the front of the buffer.
         // After 16 reads from the FIFO, output_buffer_r will contain 16 complete
         // results, all aligned correctly for memory.
         if (fifo_rd_en) begin
            output_buffer_r <= {{(RESULT_WIDTH-FIFO_WIDTH){1'b0}},fifo_rd_data, 
                  output_buffer_r[CL_DATA_WIDTH-1:RESULT_WIDTH]};

            // Track the number of results in the output buffer. There is
            // a full cache line when result_count_r reaches RESULTS_PER_CL.
            result_count_r ++;
         end
      end
   end // always_ff @
      
   // Assign the starting addresses from the memory map.
   assign dma.rd_addr = rd_addr;
   assign dma.wr_addr = wr_addr;
   
   // Use the input size (# of input cache lines) specified by software.
    assign dma.rd_size = num_samples;

   // For every input cache line, we get 16 32-bit inputs. These inputs produce
   // one 64-bit output. We can store 16 outputs in a cache line, so there is
   // one output cache line for every 16 input cache lines.
   assign dma.wr_size = num_samples >> 4;

   // Start both the read and write channels when the MMIO go is received.
   // Note that writes don't actually occur until dma.wr_en is asserted.
   assign dma.rd_go = ro_go;
   assign dma.wr_go = ro_go;

   // read is disabled for this implementation
   assign dma.rd_en = 1'b0;

   // Write to memory when there is a full cache line to write, and when the
   // DMA isn't full.
   assign dma.wr_en = (result_count_r == RESULTS_PER_CL) && !dma.full;

   // Write the data from the output buffer, which stores 2 separate results.
   assign dma.wr_data = output_buffer_r;

   // afu is finished when all data has been transferred back to the cpu
   assign ro_done = dma.wr_done;
            
endmodule




