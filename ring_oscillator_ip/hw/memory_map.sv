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

// Module Name:  memory_map.sv
// Description:  This module implements a memory map for the simple pipeline.
//
//               The memory map provides 4 inputs to the circuit:
//               go         : h0050,
//               rd_addr    : h0052,
//               wr_addr    : h0054,
//               num_samples : h0056
//
//               and provides one output to software:
//               done    : h0058
//
//               rd_addr and wr_addr are both 64-bit virtual byte addresses.
//               num_samples is the number of input cache lines to transfer
//               go starts the AFU and done signals completion.

//==========================================================================
// Parameter Description
// ADDR_WIDTH : The number of bits in the read and write addresses. This will
//              always be 64 since software provides 64-bit virtual addresses,
//              but is parameterized since the HAL abstracts away the platform.
// SIZE_WIDTH : The number of bits in the num_samples signal. This essentially
//              specifies the maximum number of cache lines that can be
//              transferred in a single DMA transfer (2**SIZE_WIDTH).
//==========================================================================

//==========================================================================
// Interface Description (All control signals are active high)
// clk : clk
// rst : rst (asynchronous)
// mmio : the mmio_if interface (see mmio_if.vh or afu.sv for explanation)
// rd_addr : the starting read address for the DMA transfer
// wr_addr : the starting write address for the DMA transfer
// num_samples : the number of input cache lines to transfer
// go      : starts the DMA transfer
// done    : Asserted when the DMA transfer is complete
//==========================================================================

module memory_map
  #(
    parameter int ADDR_WIDTH,
    parameter int SIZE_WIDTH
    )
   (
   input 	                     clk,
   input 	                     rst,  
	
   mmio_if.user mmio,
   output logic [ADDR_WIDTH-1:0] rd_addr, wr_addr,
   output logic [SIZE_WIDTH-1:0] num_samples, collect_cycles,
   output logic                  ro_go,
   output logic                  rsa_go,
   input logic                   done,   
   input logic 	                 rsa_done   
   );

   // =============================================================//   
   // MMIO write code
   // =============================================================//     
   always_ff @(posedge clk or posedge rst) begin 
      if (rst) begin
         go             <= '0;
         rd_addr        <= '0;
         wr_addr        <= '0;	     
         num_samples    <= '0;
         collect_cycles <= '0;
         rsa_go         <= '0;
      end
      else begin
         // ensure go signals cleared on same cycle
	 go       <= '0;
         rsa_go   <= '0;
 	 	 	 
         if (mmio.wr_en == 1'b1) begin
            case (mmio.wr_addr)
               16'h0050: ro_go 	         <= mmio.wr_data[0];
               16'h0052: rd_addr          <= mmio.wr_data[$size(rd_addr)-1:0];
               16'h0054: wr_addr          <= mmio.wr_data[$size(wr_addr)-1:0];
               16'h0056: num_samples      <= mmio.wr_data[$size(num_samples)-1:0];
               16'h0058: collect_cycles   <= mmio.wr_data[$size(collect_cycles)-1:0];
               16'h0072: rsa_go           <= mmio.wr_data[0];
            endcase
         end
      end
   end

   // ============================================================= 
   // MMIO read code
   // ============================================================= 	    
   always_ff @(posedge clk or posedge rst) begin
      if (rst) begin
	      mmio.rd_data <= '0;
      end
      else begin             
         if (mmio.rd_en == 1'b1) begin
	    
	         mmio.rd_data <= '0;
	    
            case (mmio.rd_addr)
               16'h0052: mmio.rd_data[$size(rd_addr)-1:0]         <= rd_addr;
               16'h0054: mmio.rd_data[$size(wr_addr)-1:0]         <= wr_addr;
               16'h0056: mmio.rd_data[$size(num_samples)-1:0]     <= num_samples;     
               16'h0058: mmio.rd_data[$size(collect_cycles)-1:0]  <= collect_cycles;
               16'h0060: mmio.rd_data[0] 		          <= done;
               16'h0074: mmio.rd_data[0]                          <= rsa_done;
               default:  mmio.rd_data 			          <= 64'h0;
            endcase
         end
      end
   end
endmodule
