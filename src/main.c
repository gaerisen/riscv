int a = 1;
int b = 1;
int c;

int main()
{

        for (unsigned int i = 0; i < 32; i++) {
                c = a + b;
                a = b;
                b = c;
        }

        return 0;
}
