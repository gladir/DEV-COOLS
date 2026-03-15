// test13_types.cs - Test du systeme de types (TODO 06)
// Tous les types primitifs C# supportes

using System;

namespace Test13
{
    class TypeDemo
    {
        static void Main()
        {
            // Types entiers
            int a;
            uint b;
            long c;
            short d;
            ushort e;
            byte f;
            sbyte g;

            // Types flottants (stubs entiers)
            float h;
            double i;
            decimal j;

            // Types speciaux
            bool ok;
            char ch;
            string msg;
            object obj;

            // Affectations
            a = 42;
            b = 100;
            c = 1000;
            d = 10;
            e = 20;
            f = 255;
            g = -1;
            h = 3;
            i = 6;
            j = 9;
            ok = true;
            ch = 'A';
            msg = "Hello Types";
            obj = null;

            // Conversions implicites (widening)
            a = f;         // byte -> int OK
            a = g;         // sbyte -> int OK
            a = d;         // short -> int OK
            a = e;         // ushort -> int OK
            c = a;         // int -> long OK

            Console.WriteLine(a);
            Console.WriteLine(ok);
            Console.WriteLine(ch);
            Console.WriteLine(msg);
        }
    }
}
