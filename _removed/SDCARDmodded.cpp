/*
Modded by Rui Alves (supertechman.blogspot.com) for use with the 
SPI library - it makes it easy to interface in case you have other
SPI devices (namely you can use the SPI library and then use any
SS (CS) pin you want instead of being stuck with D10. 22.02.2011;

References (mod): 
http://alumni.cs.ucr.edu/~amitra/sdcard/Additional/sdcard_appnote_foust.pdf

Usage:        unsigned char error = SDCARDmodded.readblock(unsigned long n, port);
              unsigned char error = SDCARDmodded.writeblock(unsigned long n, port);

			  where "port" is the SDI SS port.

**************************ORIGINAL CODE COMMENTS: *****************************
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
#include <Arduino.h>
#include "SDCARDmodded.h"
#include "SPI.h"

extern volatile byte buffer[512];				//caller defines buffer

unsigned char SDCARDclass::SD_reset(int port)
{ 
 unsigned char response;
 unsigned int retry = 0;

 pinMode(10, OUTPUT);									//SPI lib requirement, even if you don't use it
 pinMode(port, OUTPUT);
 
/*setupSPI with SPI.h*/
 SPI.begin();
 SPI.setDataMode(SPI_MODE0);
 SPI.setBitOrder(MSBFIRST);
 SPI.setClockDivider(SPI_CLOCK_DIV64);

/* After power up (including hot insertion, i.e. inserting a card when the bus is operating) the SD Card
enters the idle state. In case of SD host, CMD0 is not necessary. In case of SPI host, CMD0 shall be
the first command to send the card to SPI mode.*/ 

	do
		{
			response = SD_sendCommand(0, 0, port);		//send 'reset & go idle' command
			if(++retry>254)return 1; 
		} while(response != 0x01);

/*CMD1 is not recommended because it may be difficult for the host to distinguish between MultiMediaCard 
and SD Memory Card. but we will never use a MMC card so take easy route
For the Thick (2.1 mm) SD Memory Card - CMD1 (SEND_OP_COND) is valid*/

	retry=0;
	do
		{
			response = SD_sendCommand(1, 0, port);		//activate card's initialization process
			if(++retry>254) return 2;  
		} while(response);

//CRC disabled in SPI mode so we will keep it that way.

	retry = 0;
	do
		{  
			response = SD_sendCommand(16, 512, port);	//set block size to 512
			if(++retry>10) return 8;					//time out  
		} while (response);

return 0;

}//end of SD_reset function

unsigned char SDCARDclass::readblock(unsigned long Rstartblock, int port)
{
unsigned char response, saveDDRB;
unsigned int i, retry=0;

	response = SD_reset(port);							// reset the sd card   
	SPI.setClockDivider(SPI_CLOCK_DIV4);				//use fast speed for read block
	
	if (response != 0 ) return response;				//board wont reset return error
		

	do
		{
			response = SD_sendCommand(17, Rstartblock<<9, port);//read a Block command
			//block address converted to starting address of 512 byte Block	
			if(++retry>10) return 3;

		}while (response);

	digitalWrite(port, LOW);								//selectSDCARD	
	retry = 0;
/*Read and write commands have data transfers associated with them. Data is being transmitted or
received via data tokens. All data bytes are transmitted MSB first.
First byte: Start Block
1 1 1 1 1 1 1 0
Bytes 2-513 (depends on the data block length): User data; Last two bytes: 16 bit CRC.*/

	while(SPI.transfer(0xff) != 0xfe){						//wait for start block token 0xfe  
		if(retry++ > 600) return 4;							//end time out for token
	}														//end receive token

	for(i=0; i<512; i++)									//read 512 bytes
		buffer[i] = SPI.transfer(0xff);
		SPI.transfer(0xff);									//receive incoming CRC (16-bit), CRC is ignored here
		SPI.transfer(0xff);
		SPI.transfer(0xff);									//extra 8 clock pulses

digitalWrite(port,HIGH);									//deselectSDCARD

return 0;
}															//end of read block

unsigned char SDCARDclass::writeblock(unsigned long Wstartblock, int port)
{
unsigned char response, saveDDRB;
unsigned int i, retry=0;

	response = SD_reset(port);								// reset the sd card
	SPI.setClockDivider(SPI_CLOCK_DIV4);					//use fast speed for write block
	
	if (response != 0 ) return response;					//board wont reset return error

	do
		{
			response = SD_sendCommand(24, Wstartblock<<9, port); //write a Block command
			if(++retry>10) return 5;						//time out

		}while (response);

	digitalWrite(port, LOW);								//selectSDCARD
	SPI.transfer(0xfe);										//Send start block token 0xfe (0x11111110)
	for(i=0; i<512; i++)									//send 512 bytes data
		SPI.transfer(buffer[i]);
	SPI.transfer(0xff);										//transmit dummy CRC (16-bit), CRC is ignored here
	SPI.transfer(0xff);

	response = SPI.transfer(0xff);
/*Every data block written to the card will be acknowledged by a data response token. It is one byte long
and has the following format:
x x x 0 Status 1
The meaning of the status bits is defined as follows:
010 - Data accepted.
101 - Data rejected due to a CRC error.
110 - Data Rejected due to a Write Error*/
	if( (response & 0x1f) != 0x05) 
		{   
			digitalWrite(port, HIGH);
			return 6;
		}
/*Every data block has a prefix of \u2019Start Block\u2019 token (one byte).
After a data block has been received, the card will respond with a data-response token. If the data block
has been received without errors, it will be programmed. As long as the card is busy programming, a
continuous stream of busy tokens will be sent to the host (effectively holding the DataOut line low).*/
	while(!SPI.transfer(0xff))								//wait for SD card to complete writing and get idle
	if(retry++ > 60000)
		{
			digitalWrite(port, HIGH);
			return 7;
		}

digitalWrite(port, HIGH);
return 0;
}															//end of write a block of data

unsigned char SDCARDclass::SD_sendCommand(unsigned char cmd, unsigned long arg, int port)
{
  /*The response token is sent by the card after every command with the exception of SEND_STATUS
commands. It is one byte long, and the MSB is always set to zero. The other bits are error indications,
an error being signaled by a 1. The structure of the R1 format is given in Figure 7-9. The meaning of the
flags is defined as following:
In idle state: The card is in idle state and running the initializing process.
Erase reset: An erase sequence was cleared before executing because an out of erase sequence
command was received.
Illegal command: An illegal command code was detected.
Communication CRC error: The CRC check of the last command failed.
Erase sequence error: An error in the sequence of erase commands occurred.
Address error: A misaligned address that did not match the block length was used in the command.
Parameter error: The command\u2019s argument (e.g. address, block length) was outside the allowed*/
unsigned char response, retry=0, i;
	
	for(i=0; i<10; i++)											//presend calls
		SPI.transfer(0xff);										//need wakeup calls
	digitalWrite(port, LOW);									//selectSDCARD
	//SPI.transfer(0xff);  //wakeup call
	SPI.transfer(cmd | 0x40);									//send command, first two bits always '01'
	SPI.transfer(arg>>24);
	SPI.transfer(arg>>16);
	SPI.transfer(arg>>8);
	SPI.transfer(arg);
	SPI.transfer(0x95);											//crc does not matter except for cmd0

while((response = SPI.transfer(0xff)) == 0xff)					//wait response
   if(retry++ > 254) break; //time out error

//deselectSDCARD  //set the SS to 1 to deselect the sd card, it's done by the sketch
digitalWrite(port, HIGH);
return response; //return state
}

//SPI_transmit function left as legacy but not really used if we are using the SPI lib
/*
unsigned char SDCARDclass::SPI_transmit(unsigned char data)
{
// Start transmission
SPDR = data;
// Wait for transmission complete
while(!(SPSR & (1<<SPIF)));
data = SPDR;
return(data);
}
*/
SDCARDclass SDCARDmodded;
