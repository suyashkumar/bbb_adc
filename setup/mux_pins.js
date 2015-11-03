/*
Sets the proper pin mux mode (6) for reading the following
digital inputs from PRU0's R31

Bit	Pin	
0	P9_31
1	P9_29
2	P9_30
3	P9_28
4	P9_42
5	P9_27
6	P9_41
7	P9_25

@author Suyash Kumar 
*/
var b = require('bonescript');


pins = ["P9_31","P9_29","P9_30"];
//setPins(pins,b);
b.pinMode("P9_29", b.INPUT, 6, 'pullup', 'fast', printStatus);
b.getPinMode("P9_29", printPinMux);

function setPins(pins, b){
	for (i=0; i<pins.length; i++){
		console.log(pins[i])
		b.pinMode(pins[i], b.INPUT, 6, 'pullup', 'fast', printStatus);
		b.getPinMode(pins[i], printPinMux);
				
	}	
}

function printStatus(x) {
    console.log('value = ' + x.value);
    console.log('err = ' + x.err);
}
function printPinMux(x) {
    console.log('mux = ' + x.mux);
    console.log('pullup = ' + x.pullup);
    console.log('slew = ' + x.slew);
    console.log('options = ' + x.options.join(','));
    console.log('err = ' + x.err);
}
