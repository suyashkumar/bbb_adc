#!/bin/bash 
# Sets up pinmuxes needed to acquire from PRU r31
# by loading a cape
SLOTS=/sys/devices/bone_capemgr.*/slots
PINS=/sys/kernel/debug/pinctrl/44e10800.pinmux/pins 
echo test > $SLOTS
cat $SLOTS
echo BB-BONE-PRU-01 >/sys/devices/bone_capemgr.9/slots
