extern int num;
int i;

void halt();
extern void ecall(unsigned int);

void init()
{
        i = num;
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
