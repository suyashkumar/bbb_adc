// Developed by Youngtae Jo in Kangwon National University (April-2014)
// Modified by Suyash Kumar at Duke University (sk317) to fix timing bugs,
// increase acquisition speed by setting ADC_CLKDIV, and more. 

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

#define GPIO1 0x4804c000
#define GPIO_CLEARDATAOUT 0x190
#define GPIO_SETDATAOUT 0x194
//TODO: Figure out how to make this more parametric. e.g. actually use the
//      params below or have dynamically set and assembled by C code.           
#define SAMPLING_RATE 2000000 //Sampling rate(560 khz)
//#define DELAY_NANO_SECONDS (1000000000 / SAMPLING_RATE) //Delay by sampling rate
#define DELAY_NANO_SECONDS 2000
#define DELAY_MICRO_SECONDS (1000000 / SAMPLING_RATE)
#define CLOCK 200000000 // PRU is always clocked at 200MHz
#define CLOCKS_PER_LOOP 2 // loop contains two instructions, one clock each
//#define DELAYCOUNT (DELAY_NANO_SECONDS/1000) * CLOCK / CLOCKS_PER_LOOP / 1000 / 1000 * 3
#define DELAYCOUNT (CLOCK * DELAY_NANO_SECONDS / 1000000000)/2
// Set ADC_CLKDIV
//    MOV ADDR,ADC_TSC
//    MOV VALUE,0x00000000   //the 24MHz-clock rate is divided by VALUE+1 to yield ADC_CLOCK 
//    SBBO VALUE,ADDR,0x4C,4 //important to write all 4 bytes even though only the first 2 count - if this is not done, the change doesnt take effect for some reason  
.macro DELAY
    //MOV r10, 1
    DELAY:
      // SUB r10, r10, 1
       //QBNE DELAY, r10, 0
.endm

.macro READADC
    //Initialize buffer status (0: empty, 1: first buffer is ready, 2: second buffer is ready)
    MOV r2, 0
    SBCO r2, CONST_PRUSHAREDRAM, 0, 4  // Load 0 into first 4 bytes at shared ram mem address.
    
    INITV:
        MOV r5, 0 // Offset (shared ram saving position)
        MOV r6, BUFF_SIZE  // Counts how much of total buffer used 
        MOV r2, 0 // put 0 in r2

    READ:
        //Read ADC from FIFO0DATA 
        ADD r5, r5, 4 // update offset from CONST_PRUSHAREDRAM
        SBCO r31.b0, CONST_PRUSHAREDRAM, r5, 4 // Write ADC value to offset location in shared RAM 
        SUB r6, r6, 4 // Subtract 4 bytes from buffer size counter 
        QBNE READ, r6, r2 // Branch to READ if r6!=0 

     MOV r2, 1 
     SBCO r2, CONST_PRUSHAREDRAM, 0, 4 // Write 1 to the first 4 bytes of shared mem
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
