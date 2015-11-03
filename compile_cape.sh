#!/bin/bash
dtc -O dtb -o test-00A0.dtbo -b 0 -@ test.dts 
cp test-00A0.dtbo /lib/firmware
./setup.sh
