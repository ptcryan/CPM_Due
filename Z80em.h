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
#ifndef Z80EM_H_
#define Z80EM_H_

#include "Arduino.h"

#define VERSION "R2014-07-06"

// #define HW_DIGIX                   // Enable if this is DigiX hardware
#define HW_DUE                     // Enable if this is Due hardware

#define HW_DISK_LED_ENABLE         // Enable for disk LED

#ifdef HW_DIGIX
#define CS_SD 4                    // The DigiX built in SD CS
#else  // Due
#define CS_SD 53                   // The Due CS pin
#ifdef HW_DISK_LED_ENABLE
#define HW_DISK_LED 13             // Use the 'L' LED for disk activity
#endif  // HW_DISK_LED_ENABLE
#endif  // !HW_DIGIX

#define SYSTEM_MEMORY_SIZE 65536   // Size of emulator RAM
#define SERIAL_SPEED 19200         // Console port baud rate
#define LED_DISK 13                // LED pin for disk activity

extern volatile byte PC_MEM[];     // Size of RAM for this system

void setup(void);
void loop(void);

#endif  // Z80EM_H_
