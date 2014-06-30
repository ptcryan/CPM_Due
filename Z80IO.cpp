/*** Z80Em: Portable Z80 emulator *******************************************/
/***                                                                      ***/
/*** Copyright 2014 David Ryan (ptcryan)                                  ***/
/***                                                                      ***/
/***                                Z80IO.c                               ***/
/***                                                                      ***/
/*** This file contains the prototypes for the functions accessing memory ***/
/*** and I/O on a Digix                                                   ***/
/***                                                                      ***/
/****************************************************************************/
#include <SD.h>
#include "Z80em.h"

// #define EMU_DEBUG

extern Sd2Card card;
byte fileBuffer[512];  // file IO buffer. Used for transferring SD data.

extern void DumpMem(int start, int end);

void ReadSDSector(unsigned long SDS, byte *fileBuffer) {
    if (int error = card.readBlock(SDS, fileBuffer) == 0) {
        Serial.print("SD Card read error: ");
        Serial.println(error, HEX);
    }
}

void WriteSDSector(unsigned long SDS, byte *fileBuffer) {
    if (int error = card.writeBlock(SDS, fileBuffer) == 0) {
        Serial.print("SD Card write error: ");
        Serial.println(error, HEX);
    }
}

/****************************************************************************/
/* Input a byte from given I/O port                                         */
/****************************************************************************/
byte Z80_In(byte Port) {
    int conchar;

    switch (Port) {
        case 0x00:  // console status
            if (Serial.available()) {
                return 0xff;    // character ready
            } else {
                return 0x00;    // character not ready
            }
            break;

        case 0x01:  // console read
            while (!Serial.available()) {
                {}  // block until serial port has data
            }
            conchar = Serial.read();
            return (conchar & 0x7F);  // return the character stripping MSB
            break;

        default:
#ifdef EMU_DEBUG
            Serial.print("Unhandled read from port: ");
            Serial.println(Port, HEX);
            return 0;
#endif  // EMU_DEBUG
            {}
    }
}

/****************************************************************************/
/* Output a byte to given I/O port                                          */
/****************************************************************************/
void Z80_Out(byte Port, byte Value) {
    byte temp = 0;
    static int DMAAddr = 0;
    static byte track = 0;
    static byte sector = 0;
    unsigned long TotalOffset;
    unsigned int BlockOffset;
    unsigned long SDBlockNumber;

    switch (Port) {
        case 0x02:  // console ouput
            Serial.write(Value);
            break;

        case 0x10:  // set track
            track = Value;
#ifdef EMU_DEBUG
            Serial.print("T=");
            Serial.println(Value);
#endif  // EMU_DEBUG
            break;

        case 0x12:  // set sector
            sector = Value;
#ifdef EMU_DEBUG
            Serial.print("S=");
            Serial.println(Value);
#endif  // EMU_DEBUG
            break;

        case 0x14:  // DMA low byte
            DMAAddr = (DMAAddr & 0xff00) | Value;
#ifdef EMU_DEBUG
            Serial.print("L=");
            Serial.println(Value, HEX);
#endif  // EMU_DEBUG
            break;

        case 0x15:  // DMA high byte
            DMAAddr = (DMAAddr & 0x00ff) | (Value << 8);
#ifdef EMU_DEBUG
            Serial.print("H=");
            Serial.println(Value, HEX);
#endif  // EMU_DEBUG
            break;

        case 0x16:  // DMA transfer
            // TotalOffset is the offset from track 0 sector 0
            TotalOffset = (track * 0xD00) + (sector * 0x80);
            // BlockOffset is the offset within the given block number
            BlockOffset = TotalOffset % 0x200;
            // SDBlockNumber is the SD block number from the given track & sector
            SDBlockNumber = TotalOffset / 0x200;

            // Read a 512 byte SD block into emulator memory
            ReadSDSector(SDBlockNumber, fileBuffer);

#ifdef EMU_DEBUG
            Serial.print(Value == 1? "RD" : "WR");
            Serial.print(" TRK:"); Serial.print(track);
            Serial.print(" SEC:"); Serial.print(sector);
            Serial.print(" BLK:"); Serial.print(SDBlockNumber);
            Serial.print(" OFS:"); Serial.print(BlockOffset);
            Serial.print(" DMA:0x"); Serial.print(DMAAddr, HEX);
            Serial.println("");
#endif  // EMU_DEBUG

            switch (Value) {
                case 1:  // 1 = read from disk (SD)
                    for (byte i = 0; i < 0x80; i++) {
                        PC_MEM[DMAAddr + i] = fileBuffer[BlockOffset + i];
                    }
                    break;

                case 2:  // 2 = write to disk (SD)
                    for (byte i = 0; i < 0x80; i++) {
                        fileBuffer[BlockOffset + i] = PC_MEM[DMAAddr + i];
                    }
                    WriteSDSector(SDBlockNumber, fileBuffer);   //  write the buffer back to the SD
                    break;

                default:
                    Serial.println("Unknown IO operation requested");
            }
            break;

        default:
#ifdef EMU_DEBUG
            Serial.print("Unhandled write: ");
            Serial.print(Value, HEX);
            Serial.print(" to port: ");
            Serial.println(Port, HEX);
#endif  // EMU_DEBUG
            {}
    }
}

/****************************************************************************/
/* Read a byte from given memory location                                   */
/****************************************************************************/
unsigned Z80_RDMEM(dword A) {
    return PC_MEM[A];
}

/****************************************************************************/
/* Write a byte to given memory location                                    */
/****************************************************************************/
void Z80_WRMEM(dword A, byte V) {
    PC_MEM[A] = V;
}

/****************************************************************************/
/* Just to show you can actually use macros as well                         */
/****************************************************************************/
/*
 extern byte *ReadPage[256];
 extern byte *WritePage[256];
 #define Z80_RDMEM(a) ReadPage[(a)>>8][(a)&0xFF]
 #define Z80_WRMEM(a,v) WritePage[(a)>>8][(a)&0xFF]=v
*/

/****************************************************************************/
/* Z80_RDOP() is identical to Z80_RDMEM() except it is used for reading     */
/* opcodes. In case of system with memory mapped I/O, this function can be  */
/* used to greatly speed up emulation                                       */
/****************************************************************************/
#define Z80_RDOP(A)     Z80_RDMEM(A)

/****************************************************************************/
/* Z80_RDOP_ARG() is identical to Z80_RDOP() except it is used for reading  */
/* opcode arguments. This difference can be used to support systems that    */
/* use different encoding mechanisms for opcodes and opcode arguments       */
/****************************************************************************/
#define Z80_RDOP_ARG(A)     Z80_RDOP(A)

/****************************************************************************/
/* Z80_RDSTACK() is identical to Z80_RDMEM() except it is used for reading  */
/* stack variables. In case of system with memory mapped I/O, this function */
/* can be used to slightly speed up emulation                               */
/****************************************************************************/
#define Z80_RDSTACK(A)      Z80_RDMEM(A)

/****************************************************************************/
/* Z80_WRSTACK() is identical to Z80_WRMEM() except it is used for writing  */
/* stack variables. In case of system with memory mapped I/O, this function */
/* can be used to slightly speed up emulation                               */
/****************************************************************************/
#define Z80_WRSTACK(A, V)    Z80_WRMEM(A, V)

