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

// Module Name:  afu.sv
// Project:      simple pipeline
// Description:  This AFU implements a simple pipeline that streams 32-bit
//               unsigned integers from an input array, with each cache line
//               providing 16 inputs. The pipeline multiplies the 8 pairs of
//               inputs from each input cache line, and sums all the products
//               to get a 64-bit result that is written to an output array.
//               All multiplications and additions should provide 64-bit
//               outputs, which means that the multiplications retain all
//               precision (due to their 32-bit inputs), but the adds due not
//               include carrys.
//
//               Since each output is 64 bits, the AFU must generate 8 outputs
//               before writing a cache line to memory (512 bits). The AFU
//               uses output buffering to pack 8 separate 64-bit outputs into
//               a single 512-bit buffer that is then written to memory.
//
//               Although the AFU could be extended to support any number of
//               inputs and/or outputs, software ensures that the number of
//               inputs is a multiple of 16, so the AFU doesn't have to consider
//               the situation of ending without 8 results in the buffer to
//               write to memory (i.e. an incomplete cache line on the final
//               transfer.

//               The AFU uses MMIO to receive the starting read adress, 
//               starting write address, num_samples (# of input cache lines), 
//               and a go signal. The AFU asserts a MMIO done signal to tell 
//               software that the DMA that all results have been written to
//               memory.
//
//               This example assumes the user is familiar with the
//               dma_loopback and dma_loop_uclk training modules.

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

   // parameters for power switcher
   localparam int REG_SIZE = 8192;
   localparam int SWITCH_DURATION = 100;

   // parameters for mod_exp
   localparam int KEY_SIZE = 64;

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
   logic 	go, done, switcher_en, rsa_go;

   // 64-byte (512-bit) virtual memory addresses
   localparam int VIRTUAL_BYTE_ADDR_WIDTH = 64;
   logic [VIRTUAL_BYTE_ADDR_WIDTH-1:0] rd_addr, wr_addr;

   // logic for pipeline IO
   logic 		               fifo_rd_en, fifo_empty;
   logic [FIFO_WIDTH-1:0]     fifo_rd_data;

   //logic for mod_exp
   logic [KEY_SIZE-1:0] rsa_M;
   logic [KEY_SIZE-1:0] rsa_N;
   logic [KEY_SIZE-1:0] rsa_d;
   logic [KEY_SIZE-1:0] rsa_R;
   logic                rsa_done;

   assign rsa_M = 1024'hfffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000;
   assign rsa_N = 1024'hfffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000;
   assign rsa_d = 1024'hfffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff00000000;

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
         .go(go),
         .stop(1'b0),
         .num_samples(num_samples),
         .collect_cycles(collect_cycles),
         .fifo_empty(fifo_empty),
         .fifo_rd_en(fifo_rd_en),
         .fifo_rd_data(fifo_rd_data)
      );

   switcher 
      #(
         .REG_SIZE(REG_SIZE), 
         .SWITCH_DURATION(SWITCH_DURATION)
      ) switcher 
      (
         .clk(clk),
         .rst(rst),
         .en(switcher_en)
      );
  
   mod_exp
      #(
         .KEY_SIZE(KEY_SIZE),
         .RSA_MOD(KEY_SIZE)
      ) mod_exp
      (
         .clk(clk),
         .rst(rst),
         .go(rsa_go),
         .M(rsa_M),
         .N(rsa_N), 
         .d(rsa_d), 
         .done(rsa_done),
         .R(rsa_R)
      );
   
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
   assign dma.rd_go = go;
   assign dma.wr_go = go;

   // Read from the DMA when there is data available (!dma.empty) and when
   // there is still space in the absorption FIFO to absorb the result in the
   // case of a stall. Without an absorption FIFO, the condition would 
   // likely be: !dma.empty && !stalled
   //assign dma.rd_en = !dma.empty && !fifo_almost_full;
   assign dma.rd_en = 1'b0;
   // Write to memory when there is a full cache line to write, and when the
   // DMA isn't full.
   assign dma.wr_en = (result_count_r == RESULTS_PER_CL) && !dma.full;

   // Write the data from the output buffer, which stores 2 separate results.
   assign dma.wr_data = output_buffer_r;

   assign done = dma.wr_done;// || rsa_done;
            
endmodule




