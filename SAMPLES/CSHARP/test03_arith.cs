using System;

namespace Test03
{
    class Program
    {
        static void Main()
        {
            int a;
            int b;
            int r;

            a = 20;
            b = 6;

            r = a + b;
            Console.WriteLine(r);

            r = a - b;
            Console.WriteLine(r);

            r = a * b;
            Console.WriteLine(r);

            r = a / b;
            Console.WriteLine(r);

            r = a % b;
            Console.WriteLine(r);

            a += 4;
            Console.WriteLine(a);

            a -= 2;
            Console.WriteLine(a);

            a *= 3;
            Console.WriteLine(a);

            a /= 2;
            Console.WriteLine(a);

            a++;
            Console.WriteLine(a);

            b--;
            Console.WriteLine(b);
        }
    }
}
