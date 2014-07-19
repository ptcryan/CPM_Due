/****************************************************************************/
/***                                                                      ***/
/*** Copyright (C) 2014 David Ryan (ptcryan)                              ***/
/*** This program is free software; you can redistribute it and/or modify ***/
/*** it under the terms of the GNU General Public License as published by ***/
/*** the Free Software Foundation; either version 3 of the License, or    ***/
/*** (at your option) any later version.                                  ***/
/***                                                                      ***/
/*** This program is distributed in the hope that it will be useful,      ***/
/*** but WITHOUT ANY WARRANTY; without even the implied warranty of       ***/
/*** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the        ***/
/*** GNU General Public License for more details.                         ***/
/***                                                                      ***/
/****************************************************************************/
#include <SPI.h>
#include <SD.h>
#include <stdio.h>
#include <stdlib.h>
#include "Z80em.h"
#include "Z80IO.h"

// set up variables using the SD utility library functions:
Sd2Card card;

void DumpMem(int start, int stop);

// Create the memory space that will emulate RAM
volatile byte PC_MEM[SYSTEM_MEMORY_SIZE];  // Due has 96KB. So 64K is ok!

void setup(void) {
    // setup the serial port for debug purposes
    SerialUSB.begin(SERIAL_SPEED);
    while (!SerialUSB.available()) {
        SerialUSB.println("Press any key to begin.");
        delay(1000);
    }

#ifdef HW_DISK_LED_ENABLE
    digitalWrite(HW_DISK_LED, LOW);
    pinMode(HW_DISK_LED, OUTPUT);
#endif  // HW_DISK_LED_ENABLE

    // Print banner & info
    SerialUSB.println();
    SerialUSB.println("Zilog Z80 PC emulator");
    SerialUSB.println("Running on ARM M3");
    SerialUSB.print("Version ");
    SerialUSB.println(VERSION);
    SerialUSB.print("Built on ");
    SerialUSB.print(__DATE__);
    SerialUSB.print(" at ");
    SerialUSB.println(__TIME__);
    SerialUSB.print(SYSTEM_MEMORY_SIZE / 1024);
    SerialUSB.print("K bytes");
    SerialUSB.println(" of RAM available");

    SerialUSB.print("\nInitializing SD card...");

    uint8_t cardStatus = card.init(SPI_HALF_SPEED, CS_SD);

    if (!cardStatus) {
        SerialUSB.println("initialization failed.");
        SerialUSB.print("Card status error = ");
        SerialUSB.println(cardStatus);
        return;
    } else {
        SerialUSB.println("SD card detected.");
    }

    // fill PC RAM with 0xCB
    SerialUSB.print("Running PC RAM tests...");
    uint32_t i;
    for (i = 0; i < SYSTEM_MEMORY_SIZE; i++) {
        PC_MEM[i] = 0xcb;
    }

    // verify memory
    bool memTestPass = true;
    for (i = 0; i < SYSTEM_MEMORY_SIZE; i++) {
        if (PC_MEM[i] != 0xcb) {
            memTestPass = false;
            SerialUSB.print(" failed at ");
            SerialUSB.println(i, HEX);
        }
    }

    if (memTestPass == true) {
        SerialUSB.println("Pass");
    }

    // clear memory to 0
    for (i = 0; i < SYSTEM_MEMORY_SIZE; i++) {
        PC_MEM[i] = 0;
    }

    // Reset the CPU
    Z80_Reset();

    // Use the port interfaces we already have
    // to load the system Cold Start Loader
    SerialUSB.println("");
    SerialUSB.println("booting from boot sector...");

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
    SerialUSB.println("System stopped.");
    while (1) {}
}

void DumpMem(int start, int stop) {
    for (int i = start; i < stop; i+=16) {
        SerialUSB.print(i, HEX);
        SerialUSB.print(": ");
        for (int j = i; j < i+16; j++) {
            if (PC_MEM[j] < 0x10) {
                SerialUSB.print("0");  // Add leading zero for alignment
            }
            SerialUSB.print(PC_MEM[j], HEX);
            SerialUSB.print(" ");
        }

        SerialUSB.print("| ");
        for (int k = i; k < i+16; k++) {
            if (PC_MEM[k] > 31) {
                SerialUSB.write(PC_MEM[k]);
            } else {
                SerialUSB.print(".");
            }
        }
        SerialUSB.println();
    }
}
