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
   #(
        parameter N = 20,
        parameter WIDTH=14
   ) 
  (
   input clk,
   input rst,
	 mmio_if.user mmio,
	 dma_if.peripheral dma
   );

   localparam int CL_ADDR_WIDTH = $size(t_ccip_clAddr);
   localparam int CL_DATA_WIDTH = $size(t_ccip_clData); 
   localparam int INPUT_WIDTH = 32;
   localparam int RESULT_WIDTH = 32;
   localparam int INPUTS_PER_CL = CL_DATA_WIDTH / INPUT_WIDTH;   // 16
   localparam int RESULTS_PER_CL = CL_DATA_WIDTH / RESULT_WIDTH; // 16
   
   // Normally I would make this a function of the number of inputs, but since
   // the pipeline is hardcoded for a specific number of inputs in this example,
   // this will suffice.
   localparam int PIPELINE_LATENCY = $clog2(N);
   
   // 512 is the shallowest a block RAM can be in the Arria 10, so there's no 
   // point in making it smaller unless using MLABs instead.
   localparam int FIFO_DEPTH = 512;
            
   // I want to just use dma.count_t, but apparently
   // either SV or Modelsim doesn't support that. Similarly, I can't
   // just do dma.SIZE_WIDTH without getting errors or warnings about
   // "constant expression cannot contain a hierarchical identifier" in
   // some tools. Declaring a function within the interface works just fine in
   // some tools, but in Quartus I get an error about too many ports in the
   // module instantiation.
   typedef logic [CL_ADDR_WIDTH:0] count_t;   
   count_t 	num_samples;
   logic 	go;
   logic 	done;

   // Software provides 64-bit virtual byte addresses.
   // Again, this constant would ideally get read from the DMA interface if
   // there was widespread tool support.
   localparam int VIRTUAL_BYTE_ADDR_WIDTH = 64;
   logic [VIRTUAL_BYTE_ADDR_WIDTH-1:0] rd_addr, wr_addr;

   // Instantiate the memory map, which provides the starting read/write
   // 64-bit virtual byte addresses, an input size (in cache lines), and a
   // go signal. It also sends a done signal back to software.
   memory_map
     #(
       .ADDR_WIDTH(VIRTUAL_BYTE_ADDR_WIDTH),
       .SIZE_WIDTH(CL_ADDR_WIDTH+1)
       )
     memory_map (.*);

   // logic for pipeline IO
   logic 		               fifo_rd_en, fifo_empty;
   logic [RESULT_WIDTH-1:0]   fifo_rd_data;

   ro_top
      #(
         .N(N),
         .WIDTH(WIDTH),
         .NUM_SAMPLE_WIDTH(CL_ADDR_WIDTH),
         .RESULT_WIDTH(RESULT_WIDTH),
         .FIFO_DEPTH(FIFO_DEPTH),
         .PIPELINE_LATENCY(PIPELINE_LATENCY)
      ) ro_top
      (
         .clk(clk),
         .afu_rst(rst),
         .go(go),
         .num_samples(num_samples),
         .fifo_empty(fifo_empty),
         .fifo_rd_en(fifo_rd_en),
         .fifo_rd_data(fifo_rd_data)
      );


   // padd fifo with zeroes as needed
   //assign fifo_wr_data = {{($size(fifo_wr_data)-$size(add_tree_result)){1'b0}},add_tree_result};
   //assign fifo_wr_data = {{($size(fifo_wr_data)-3){1'b0}},3'b111};
   // collect outputs in FIFO
   /*fifo 
     #(
       .WIDTH(RESULT_WIDTH),
       .DEPTH(FIFO_DEPTH),
       // This leaves enough space to absorb the entire contents of the
       // pipeline when there is a stall.
       .ALMOST_FULL_COUNT(FIFO_DEPTH-PIPELINE_LATENCY)
       )
   absorption_fifo 
     (
      .clk(clk),
      .rst(rst),
      .rd_en(fifo_rd_en),
      .wr_en(add_tree_valid_out),
      .empty(fifo_empty),
      .full(), // Not used in an absorption FIFO.
      .almost_full(fifo_almost_full),
      .count(),
      .space(),
      .wr_data(fifo_wr_data),
      .rd_data(fifo_rd_data)
      );
*/

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
            output_buffer_r <= {fifo_rd_data, 
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
   assign dma.wr_size = num_samples >> 3;

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

   // The AFU is done when the DMA is done writing all results.
   assign done = dma.wr_done;
            
endmodule



