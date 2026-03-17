using System;

namespace Test11
{
    class Program
    {
        static void Main()
        {
            const int    MAX_VAL = 100;
            const int    MIN_VAL = -50;
            const int    HEX_VAL = 0xFF;
            const bool   FLAG    = true;
            const char   LETTER  = 'A';
            const string GREETING = "Hello";

            int a;
            int b;
            bool ok;
            char c;
            string s;

            a  = 42;
            b  = 0xAB;
            ok = true;
            c  = '\n';
            s  = "Bonjour le monde";

            Console.WriteLine(a);
            Console.WriteLine(b);
            Console.WriteLine(ok);
            Console.WriteLine(c);
            Console.WriteLine(s);

            Console.WriteLine("Constante MAX_VAL :");
            Console.WriteLine(MAX_VAL);
            Console.WriteLine("Constante MIN_VAL :");
            Console.WriteLine(MIN_VAL);

            a = 3;
            b = a + MAX_VAL;
            Console.WriteLine(b);

            ok = false;
            Console.WriteLine(ok);

            Console.WriteLine("null test");
            s = null;

            Console.WriteLine("Escaped: \t tab \n newline \\ backslash");
            Console.WriteLine(@"Verbatim: c:\path\to\file");
        }
    }
}
