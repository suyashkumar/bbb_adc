/*
ADCCollector.c 
A wrapper program that launches a program on a PRU to collect samples from the 
ADC's AIN0 and put them in memory where this wrapper program can successively 
grab them and save them to disk. 
Usage: 
@author Suyash Kumar
@author Youngtae Jo
Based on work done by Youngtae Jo. 
*/
/******************************************************************************
* Include Files                                                               *
******************************************************************************/
// Standard header files
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <string.h>
#include <time.h>

// Driver header file
#include <pruss/prussdrv.h>
#include <pruss/pruss_intc_mapping.h>

/******************************************************************************
* Local Macro Declarations                                                    * 
******************************************************************************/
#define PRU_NUM 	0 
#define OFFSET_SHAREDRAM 2048		//equivalent with 0x00002000
#define PRUSS0_SHARED_DATARAM    4
#define SAMPLING_RATE 16000 //16khz
#define BUFF_LENGTH SAMPLING_RATE
#define PRU_SHARED_BUFF_SIZE 1000
#define CNT_ONE_SEC SAMPLING_RATE / PRU_SHARED_BUFF_SIZE

/******************************************************************************
* Functions declarations                                                      * 
******************************************************************************/
static int enable_adc();
static int enable_pru();
void print_err(char* input);
//static unsigned int ProcessingADC1(unsigned int value);

/******************************************************************************
* Global variable Declarations                                                * 
******************************************************************************/
static void *sharedMem;
static unsigned int *sharedMem_int;

/******************************************************************************
* Main                                                                        * 
******************************************************************************/
int main (int argc, char* argv[])
{
	FILE *fp_out;
    unsigned int ret;
    tpruss_intc_initdata pruss_intc_initdata = PRUSS_INTC_INITDATA;
	int i = 0; 
	
	int sampling_period = 0;

	if(argc <= 2){
	    print_err("\nError: not enough arguments supplied");
		printf("\e[0;32mUsage: ADCCollector [num seconds] [output file]\e[0m\n\n");
		return 0;
	}
	sampling_period = atoi(argv[1]);

	enable_pru(); // Enable PRU
	enable_adc(); // Enable ADC
	
	/* Initializing PRU */
    prussdrv_init();
    ret = prussdrv_open(PRU_EVTOUT_0);
    if (ret){
        print_err("ERROR: prussdrv_open open failed\n");
        return (ret);
    }
    prussdrv_pruintc_init(&pruss_intc_initdata);
    printf("\tINFO: Initializing.\r\n");
    prussdrv_map_prumem(PRUSS0_SHARED_DATARAM, &sharedMem); // sharedMem points to proper loc now
    sharedMem_int = (unsigned int*) sharedMem; // cast to int*
	
	/* Open save file */
	fp_out = fopen(argv[2], "w");
	if(fp_out == NULL){
		print_err("\tERROR: Output file open failed\n");
		return 0;
	}

	/* Executing PRU. */
        printf("\tSampling started for %d seconds\n", sampling_period);
        printf("\tCollecting");
        prussdrv_exec_program (PRU_NUM, "./ADCCollector.bin"); 
	/* Read ADC */

		while(1){
			if(sharedMem_int[OFFSET_SHAREDRAM] == 1) { 
				printf("\nGOT DATA\n");
				for(i=0; i<PRU_SHARED_BUFF_SIZE; i++){
					fprintf(fp_out, "%d\n", sharedMem_int[OFFSET_SHAREDRAM + i + 1]);
				} 
				break;
			} 
	        }

        //TODO: fix this second/sample counting to be right



	fclose(fp_out);
    printf("\tINFO: PRU completed transfer.\r\n");
    prussdrv_pru_clear_event (PRU_EVTOUT_0, PRU0_ARM_INTERRUPT);

    /* Disable PRU*/
    prussdrv_pru_disable(PRU_NUM);
    prussdrv_exit();

    return(0);
}

/*****************************************************************************
* Local Function Definitions                                                 *
*****************************************************************************/
/* Enable ADC */
static int enable_adc()
{
	FILE *ain;

	ain = fopen("/sys/devices/bone_capemgr.9/slots", "w");
	if(!ain){
		print_err("\tERROR: /sys/devices/bone_capemgr.9/slots open failed\n");
		return -1;
	}
	fseek(ain, 0, SEEK_SET);
	fprintf(ain, "cape-bone-iio");
	fclose(ain);
	return 0;
}

/* Enable PRU */
static int enable_pru()
{
		FILE *ain;
		ain = fopen("/sys/devices/bone_capemgr.9/slots", "w");
		if(!ain){
			print_err("\tERROR: /sys/devices/bone_capemgr.9/slots open failed\n");
			return -1;
		}
		fseek(ain, 0, SEEK_SET);
		fprintf(ain, "BB-BONE-PRU-01");
		fclose(ain);
		return 0;
}
/*
print_err()
Prints message (input) to screen in red font using terminal color codes. 
@param char* input: input string that describes the error
*/
void print_err(char* input){
    printf("\e[1;31m%s\e[0m\n",input);
}
