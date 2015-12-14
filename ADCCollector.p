// Developed by Youngtae Jo in Kangwon National University (April-2014)
// Modified by Suyash Kumar at Duke University (sk317)

// This program collects ADC from AIN0 with certain sampling rate.
// The collected data are stored into PRU shared memory(buffer) first.
// The host program(ADCCollector.c) will read the stored ADC data
// This program uses double buffering technique. 
// The host program can recognize the buffer status by buffer status variable
// 0 means empty, 1 means first buffer is ready, 2 means second buffer is ready.
// When each buffer is ready, host program read ADC data from the buffer.


.origin 0 // offset of the start of the code in PRU memory
.entrypoint START // program entry point, used by debugger only

#include "ADCCollector.hp"

#define BUFF_SIZE 0x00000FA0 //Total buff size: 4kbyte(Each buffer has 2kbyte: 500 piece of data)
#define HALF_SIZE BUFF_SIZE / 2

#define SAMPLING_RATE 2000000 //Sampling rate(560 khz)
//#define DELAY_NANO_SECONDS (1000000000 / SAMPLING_RATE) //Delay by sampling rate
#define DELAY_NANO_SECONDS 10
//#define DELAY_MICRO_SECONDS (1000000 / SAMPLING_RATE)
#define CLOCK 200000000 // PRU is always clocked at 200MHz
#define CLOCKS_PER_LOOP 2 // loop contains two instructions, one clock each
//#define DELAYCOUNT (DELAY_NANO_SECONDS/1000) * CLOCK / CLOCKS_PER_LOOP / 1000 / 1000 * 3
#define DELAYCOUNT (CLOCK * DELAY_NANO_SECONDS / 1000000000)/2
.macro DELAY
    //MOV r10, 1
    DELAY:
       //SUB r10, r10, 1
       //QBNE DELAY, r10, 0
.endm

.macro READADC
    //Initialize buffer status (0: empty, 1: first buffer is ready, 2: second buffer is ready)
    MOV r2, 0
    SBCO r2, CONST_PRUSHAREDRAM, 0, 4 

    INITV:
        MOV r5, 0 //Shared RAM address of ADC Saving position 
        MOV r6, BUFF_SIZE  //Counting variable 

    READ:
        //Read ADC from FIFO0DATA
        MOV r2, 0x44E0D100 
        LBBO r3, r2, 0, 4 
        //Add address counting
        ADD r5, r5, 4
        //Write ADC to PRU Shared RAM
        SBCO r3, CONST_PRUSHAREDRAM, r5, 4 

        DELAY
        
        SUB r6, r6, 4
        MOV r2, HALF_SIZE
        QBEQ CHBUFFSTATUS1, r6, r2 //If first buffer is ready
        QBEQ CHBUFFSTATUS2, r6, 0 //If second buffer is ready
        QBA READ

    //Change buffer status to 1
    CHBUFFSTATUS1:
        MOV r2, 1 
        SBCO r2, CONST_PRUSHAREDRAM, 0, 4
        QBA READ

    //Change buffer status to 2
    CHBUFFSTATUS2:
        MOV r2, 2
        SBCO r2, CONST_PRUSHAREDRAM, 0, 4
        QBA INITV

    //Send event to host program
    MOV r31.b0, PRU0_ARM_INTERRUPT+16 
    HALT
.endm

// Starting point
START:
    // Enable OCP master port
    LBCO r0, CONST_PRUCFG, 4, 4
    CLR r0, r0, 4
    SBCO r0, CONST_PRUCFG, 4, 4

    //C28 will point to 0x00012000 (PRU shared RAM)
    MOV r0, 0x00000120
    MOV r1, CTPPR_0
    ST32 r0, r1

    //Init ADC CTRL register
    MOV r2, 0x44E0D040
    MOV r3, 0x00000005
    SBBO r3, r2, 0, 4

    //Enable ADC STEPCONFIG 1
    MOV r2, 0x44E0D054
    MOV r3, 0x00000002
    SBBO r3, r2, 0, 4

    //Init ADC STEPCONFIG 1
    MOV r2, 0x44E0D064
    MOV r3, 0x00000001 //continuous mode
    SBBO r3, r2, 0, 4

    //Read ADC and FIFOCOUNT
    READADC