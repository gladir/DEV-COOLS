using System;

namespace Test06
{
    class Program
    {
        static void Main()
        {
            int i;
            int j;
            int prod;

            for (i = 1; i <= 5; i++)
            {
                Console.WriteLine(i);
            }

            for (i = 1; i <= 3; i++)
            {
                for (j = 1; j <= 3; j++)
                {
                    prod = i * j;
                    Console.WriteLine(prod);
                }
            }
        }
    }
}
