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
    Serial.begin(SERIAL_SPEED);
    while (!Serial) {
        {}
    }

#ifdef HW_DISK_LED_ENABLE
    digitalWrite(HW_DISK_LED, LOW);
    pinMode(HW_DISK_LED, OUTPUT);
#endif  // HW_DISK_LED_ENABLE

    // Print banner & info
    Serial.println();
    Serial.println("Zilog Z80 PC emulator");
    Serial.println("Running on ARM M3");
    Serial.print("Version ");
    Serial.println(VERSION);
    Serial.print("Built on ");
    Serial.print(__DATE__);
    Serial.print(" at ");
    Serial.println(__TIME__);
    Serial.print(SYSTEM_MEMORY_SIZE / 1024);
    Serial.print("K bytes");
    Serial.println(" of RAM available");

    Serial.print("\nInitializing SD card...");

    uint8_t cardStatus = card.init(SPI_HALF_SPEED, CS_SD);

    if (!cardStatus) {
        Serial.println("initialization failed.");
        Serial.print("Card status error = ");
        Serial.println(cardStatus);
        return;
    } else {
        Serial.println("SD card detected.");
    }

    // fill PC RAM with 0xCB
    Serial.print("Running PC RAM tests...");
    uint32_t i;
    for (i = 0; i < SYSTEM_MEMORY_SIZE; i++) {
        PC_MEM[i] = 0xcb;
    }

    // verify memory
    bool memTestPass = true;
    for (i = 0; i < SYSTEM_MEMORY_SIZE; i++) {
        if (PC_MEM[i] != 0xcb) {
            memTestPass = false;
            Serial.print(" failed at ");
            Serial.println(i, HEX);
        }
    }

    if (memTestPass == true) {
        Serial.println("Pass");
    }

    // clear memory to 0
    for (i = 0; i < SYSTEM_MEMORY_SIZE; i++) {
        PC_MEM[i] = 0;
    }

    // Reset the CPU
    Z80_Reset();

    // Use the port interfaces we already have
    // to load the system Cold Start Loader
    Serial.println("");
    Serial.println("booting from boot sector...");

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
