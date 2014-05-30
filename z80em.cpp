#include <SPI.h>
#include <SD.h>
#include <stdio.h>
#include <stdlib.h>
#include "Z80em.h"
#include "Z80IO.h"

// set up variables using the SD utility library functions:
Sd2Card card;

extern int Z80_Trap;

// change this to match your SD shield or module;
const int chipSelect = 4;

void DumpMem(int start, int stop);

#define SYSTEM_MEMORY_SIZE 65536

// Create the memory space that will emulate RAM
volatile byte PC_MEM[SYSTEM_MEMORY_SIZE];  // The Due has 96KB total so there's room for 64K!

void setup(void) {
  // setup the serial port for debug purposes
  Serial.begin(19200);
  while (!Serial) {
    {}
  }

  // Print banner & info
  Serial.println();
  Serial.println("Zilog Z80 PC emulator");
  Serial.println("Running on ARM M3");
  Serial.print("Built on ");
  Serial.print(__DATE__);
  Serial.print(" at ");
  Serial.println(__TIME__);
  Serial.print(SYSTEM_MEMORY_SIZE / 1024);
  Serial.print("K bytes");
  Serial.println(" of RAM available");

  Serial.print("\nInitializing SD card...");
  // On the Ethernet Shield, CS is pin 4. It's set as an output by default.
  // Note that even if it's not used as the CS pin, the hardware SS pin
  // (10 on most Arduino boards, 53 on the Mega) must be left as an output
  // or the SD library functions will not work.
  pinMode(10, OUTPUT);     // change this to 53 on a mega

  if (!card.init(SPI_HALF_SPEED, chipSelect)) {
    Serial.println("initialization failed.");
    return;
  } else {
    Serial.println("SD card detected.");
  }

  // fill PC RAM with 0xCB
  Serial.print("Initializing PC RAM...");
  uint32_t i;
  for (i = 0; i < SYSTEM_MEMORY_SIZE; i++) {
    PC_MEM[i] = 0xcb;
  }
  Serial.println("Done");

  // verify memory
  Serial.print("Verifying RAM...");
  bool memTestPass = true;
  for (i = 0; i < SYSTEM_MEMORY_SIZE; i++) {
    if (PC_MEM[i] != 0xcb) {
      memTestPass = false;
      Serial.print("Memory test failed at ");
      Serial.println(i, HEX);
      break;
    }
  }

  if (memTestPass == true) {
    Serial.println("Pass");
  }

  // Reset the CPU
  Z80_Reset();
  // Serial.println("Printing Registers");
  // Z80_RegisterDump();

  // Use the port interfaces we already have
  // to load the system Cold Start Loader
  Serial.println("");
  Serial.println("booting...");

  // The ipl is located on track 0 sector 0 of disk
  Z80_Out(0x10, 0);  // track=0
  Z80_Out(0x12, 0);  // sector=0
  Z80_Out(0x14, 0x00);  // DMA low addr=00
  Z80_Out(0x15, 0x20);  // DMA high addr=20
  Z80_Out(0x16, 1);  // read sector into RAM

  // set PC to beginning of ipl
  Z80_Regs Regs;
  Z80_GetRegs(&Regs);
  Regs.PC.D = 0x2000;
  Z80_SetRegs(&Regs);

  // Start the CPU
  Z80();
}

void loop(void) {
  Serial.println("System stopped.");
  while (1) {}
}

void DumpMem(int start, int stop) {
  for (int i = start; i < stop; i+=16) {
    Serial.print(i, HEX);
    Serial.print(": ");
    for (int j = i; j < i+16; j++) {
      if (PC_MEM[j] < 0x10) {
        Serial.print("0");  // Add leading zero for alignment
      }
      Serial.print(PC_MEM[j], HEX);
      Serial.print(" ");
    }
    Serial.print("| ");
    for (int k = i; k < i+16; k++) {
      if (PC_MEM[k] > 31) {
        Serial.write(PC_MEM[k]);
      } else {
        Serial.print(".");
      }
    }
    Serial.println();
  }
}
