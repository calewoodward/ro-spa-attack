// Greg Stitt
// University of Florida

#ifndef __CONFIG_H__
#define __CONFIG_H__

//=============================================================
// Configuration settings

// When simulating, there is a loop that does nothing but wait for the DMA 
// to finish. This constant "polling" is very inefficient and can slow down 
// the CPU. Defining this flag causes the processor to periodically sleep
// during this polling.
// NOTE: For execution on the FPGA, comment this out.
//#define SLEEP_WHILE_WAITING

// The number of milliseconds to sleep when SLEEP_WHILE_WAITING is defined.
const unsigned SLEEP_MS = 10;


//=============================================================
// AFU MMIO Addresses

enum MmioAddr {
  
  MMIO_GO=0x0050,
  MMIO_RD_ADDR=0x0052,
  MMIO_WR_ADDR=0x0054,
  MMIO_NUM_SAMPLES=0x0056,
  MMIO_COLLECT_CYCLES=0x0058,
  MMIO_DONE=0x0060,
  MMIO_SWITCHER_EN=0x0070,
  MMIO_RSA_GO=0x0072
  // MMIO_M=0x0060,
  // MMIO_N=0x0062,
  // MMIO_D=0x0064
};



#endif
