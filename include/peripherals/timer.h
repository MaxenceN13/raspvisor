#pragma once

#include "peripherals/base.h"

#define TIMER_CS (PBASE + 0x00003000) // Control/Status
#define TIMER_CLO (PBASE + 0x00003004) // Counter Lower 32 bits
#define TIMER_CHI (PBASE + 0x00003008) // Counter Higher 32 bits
#define TIMER_C0 (PBASE + 0x0000300C) // Start value for the counter
#define TIMER_C1 (PBASE + 0x00003010) // End value for the counter, when reached, an interrupt is generated and the counter is reset to the value in C0
#define TIMER_C2 (PBASE + 0x00003014) // Define the delay between interrupts
#define TIMER_C3 (PBASE + 0x00003018) // Tick counter, usually defined at big value and decremented by 1 each tick, 
                                      // when it reaches 0, an interrupt is generated and the counter is reset to the value in C0

#define TIMER_CS_M0 (1 << 0)
#define TIMER_CS_M1 (1 << 1)
#define TIMER_CS_M2 (1 << 2)
#define TIMER_CS_M3 (1 << 3)
