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

#include "arduino.h"
#include "Z80.h"

void setup(void);
void loop(void);

extern volatile byte PC_MEM[];  // Size of RAM for this system

#endif  // Z80EM_H_
