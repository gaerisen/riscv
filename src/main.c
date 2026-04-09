int i;

void halt();
extern void ecall(unsigned int);

void init()
{
        i = 32;
        ecall(i);
        halt();
}

void handle_interrupt()
{

}

void halt()
{
        while (1);
}
