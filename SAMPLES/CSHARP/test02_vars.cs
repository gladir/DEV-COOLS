using System;

namespace Test02
{
    class Program
    {
        static void Main()
        {
            int  a;
            int  b;
            bool ok;
            char c;

            a  = 10;
            b  = 3;
            ok = true;
            c  = 'A';

            Console.WriteLine(a);
            Console.WriteLine(b);
            Console.WriteLine(ok);
            Console.WriteLine(c);

            a = a + b;
            Console.WriteLine(a);

            ok = false;
            Console.WriteLine(ok);
        }
    }
}
