#ifndef _Z80EM_H
#define _Z80EM_H

#include "arduino.h"
#include "Z80.h"

void setup(void);
void loop(void);

extern volatile byte PC_MEM[];	// Size of RAM for this system

#endif  // _Z80EM_H