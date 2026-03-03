using System;

namespace Test04
{
    class Program
    {
        static void Main()
        {
            int  a;
            int  b;
            bool ok;

            a = 10;
            b = 20;

            if (a < b)
            {
                Console.WriteLine("a < b");
            }
            else
            {
                Console.WriteLine("a >= b");
            }

            if (a == 10)
            {
                Console.WriteLine("a est 10");
            }

            if ((a > 0) && (b > 0))
            {
                Console.WriteLine("tous positifs");
            }

            ok = (a != b) || (b == 0);
            Console.WriteLine(ok);

            if (!ok)
            {
                Console.WriteLine("negatif");
            }
            else
            {
                Console.WriteLine("positif");
            }
        }
    }
}
