/* 

Modded by Rui Alves (supertechman.blogspot.com) for use with the 
SPI library - it makes it easy to interface in case you have other
SPI devices (namely you can use the SPI library and then use any
SS (CS) pin you want instead of being stuck with D10. 22.02.2011

References (mod): 
http://alumni.cs.ucr.edu/~amitra/sdcard/Additional/sdcard_appnote_foust.pdf

Usage:        unsigned char error = SDCARDmodded.readblock(unsigned long n, port);
              unsigned char error = SDCARDmodded.writeblock(unsigned long n, port);

			  where "port" is the SDI SS port.

				*****ORIGINAL CODE COMMENTS: ********
Card type: Ver2.00 or later Standard SD Memory Card
             256 MB, 1.0 and 2.0 GB cards purchased from 2008 work well.
   Usage:  Must have global variable. 
              unsigned char buffer[512];
           Function calls.
              unsigned char error = SDCARD.readblock(unsigned long n);
              unsigned char error = SDCARD.writeblock(unsigned long n);
            error is 0 for correct operation
            read copies the 512 bytes from sector n to buffer.
            write copies the 512 bytes from buffer to the sector n.
   References: SD Specifications. Part 1. Physical Layer Simplified Specification
               Version 2.00 September 25, 2006 SD Group.
               http://www.sdcard.org
   Code examples:  http://www.sensor-networks.org/index.php?page=0827727742
                   http://www.avrfreaks.net   search "sd card"
   Operation:  The code reads/writes direct to the sectors on the sd card.
               It does not use a FAT. If a 2GB card has been formatted the
               partition(sector 0), boot (around sector 135), FAT's(around sectors 100-600)
			   and the root directory(around 600-700) can be written over.
			   The data in files(above sector 700) can also be written over.
               The card can be reformated, but be aware that if the partition(sector 0)
               has been written over formating with windows XP and 7 will not restore it.
			   It will put the boot sector at 0 which can confuse some programs.
			   I have found that my cannon digital camera will restore the partition
			   and boot to the origional factory conditions.
               
   Timing:  readblock or writeblock takes 16 msec.
   Improvement: Could initialize so that can use version 1 sd and hc sd.
                Instead of CMD1 need to use CMD8, CMD58 and CMD41.
*/
#ifndef SDCARD_h
#define SDCARD_h

#include "Arduino.h"

class SDCARDclass
{
public:
unsigned char readblock(unsigned long Rstartblock, int port);
unsigned char writeblock(unsigned long Wstartblock, int port);

private:
unsigned char SD_reset(int port);
unsigned char SD_sendCommand(unsigned char cmd, unsigned long arg, int port);
unsigned char SPI_transmit(unsigned char data);
};

 extern SDCARDclass SDCARDmodded;

#endif
