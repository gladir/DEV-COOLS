using System;

namespace Test10
{
    class Program
    {
        static int Fact(int n)
        {
            if (n <= 1)
            {
                return 1;
            }
            return n * Fact(n - 1);
        }

        static void Main()
        {
            int i;
            int r;

            for (i = 0; i <= 7; i++)
            {
                r = Fact(i);
                Console.WriteLine(r);
            }
        }
    }
}
