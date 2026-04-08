int a = 1;
int b = 1;
int c;

void fork();

int init()
{
        for (unsigned int i = 0; i < 32; i++) {
                c = a + b;
                a = b;
                b = c;
        }

        return 0;
}

int handle_interrupt(int mcause, int syscall)
{
        return mcause;
}

void fork()
{
        
}
