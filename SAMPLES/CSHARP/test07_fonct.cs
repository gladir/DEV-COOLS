using System;

namespace Test07
{
    class Program
    {
        static int Add(int a, int b)
        {
            return a + b;
        }

        static int Max(int a, int b)
        {
            if (a > b)
            {
                return a;
            }
            return b;
        }

        static void PrintLine(int n)
        {
            Console.WriteLine(n);
        }

        static void Main()
        {
            int r;

            r = Add(3, 7);
            Console.WriteLine(r);

            r = Max(12, 5);
            Console.WriteLine(r);

            r = Max(Add(2, 3), Max(4, 6));
            Console.WriteLine(r);

            PrintLine(42);
        }
    }
}
