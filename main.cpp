#include <verilated.h>
#include <stdio.h>
#include "Vtop.h"
#include <time.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/select.h>
#include <termios.h>
#include <string.h>

vluint64_t elapsedtime = 0; 
double sc_time_stamp() {return elapsedtime;}

int kbhit();
int getch();
void set_conio_terminal_mode();

int main(int argc, char** argv, char** env)
{
	Verilated::commandArgs(argc, argv);
	Verilated::traceEverOn(true);
	Verilated::debug();

	Vtop* top = new Vtop;

        top->clock = 0;
        top->reset = 0;

        printf("Simulation Start:\n\n");

        set_conio_terminal_mode();

	while (1)
	{
                if (top->serial_output != '\0' && top->clock) {
                        write(1, &(top->serial_output), 1);
                }
		elapsedtime++;
                top->clock = !top->clock;
		top->eval();

                if (kbhit()) {
                        top->serial_input = getch();
                        if (top->serial_input == '`') {
                                break;
                        }
                        top->irq = 1;
                }

                if (top->irq_ack) {
                        top->irq = 0;
                        top->serial_input = 0;
                }
	}

	top->final();

	delete top;

	exit(0);
}

// Copyright for the following code belongs to Alnitak, from this thread:
// https://stackoverflow.com/questions/448944/c-non-blocking-keyboard-input

struct termios orig_termios;

void reset_terminal_mode()
{
    tcsetattr(0, TCSANOW, &orig_termios);
}

void set_conio_terminal_mode()
{
    struct termios new_termios;

    /* take two copies - one for now, one for later */
    tcgetattr(0, &orig_termios);
    memcpy(&new_termios, &orig_termios, sizeof(new_termios));

    /* register cleanup handler, and set the new terminal mode */
    atexit(reset_terminal_mode);
    cfmakeraw(&new_termios);
    tcsetattr(0, TCSANOW, &new_termios);
}

int kbhit()
{
    struct timeval tv = { 0L, 0L };
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(0, &fds);
    return select(1, &fds, NULL, NULL, &tv) > 0;
}

int getch()
{
    int r;
    unsigned char c;
    if ((r = read(0, &c, sizeof(c))) < 0) {
        return r;
    } else {
        return c;
    }
}
