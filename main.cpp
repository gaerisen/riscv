#include <verilated.h>
#include <stdio.h>
#include "Vtop.h"
#include <time.h>

vluint64_t elapsedtime = 0; 
double sc_time_stamp() {return elapsedtime;}

int main(int argc, char** argv, char** env)
{
	Verilated::commandArgs(argc, argv);
	Verilated::traceEverOn(true);
	Verilated::debug();

	Vtop* top = new Vtop;

	while (elapsedtime < 50000)
	{
		elapsedtime++;
		top->eval();
	}

	top->final();

	delete top;

	exit(0);
}
