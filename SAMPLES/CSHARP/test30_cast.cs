// test30_cast.cs - Test cast, typeof, sizeof (TODO 23)
using System;

namespace TestCast
{
    class Program
    {
        // Cas 1 : cast (int) sur char
        static void TestCastIntFromChar()
        {
            char c;
            c = 'A';
            int x;
            x = (int)c;
            Console.WriteLine(x);
        }

        // Cas 2 : cast (char) sur int
        static void TestCastCharFromInt()
        {
            int x;
            x = 66;
            char c;
            c = (char)x;
            Console.WriteLine(c);
        }

        // Cas 3 : cast (byte) sur int
        static void TestCastByte()
        {
            int x;
            x = 300;
            int b;
            b = (byte)x;
            Console.WriteLine(b);
        }

        // Cas 4 : cast (short) sur int
        static void TestCastShort()
        {
            int x;
            x = 70000;
            int s;
            s = (short)x;
            Console.WriteLine(s);
        }

        // Cas 5 : cast (bool) sur int non-zero
        static void TestCastBoolTrue()
        {
            int x;
            x = 42;
            int b;
            b = (bool)x;
            Console.WriteLine(b);
        }

        // Cas 6 : cast (bool) sur zero
        static void TestCastBoolFalse()
        {
            int x;
            x = 0;
            int b;
            b = (bool)x;
            Console.WriteLine(b);
        }

        // Cas 7 : cast (uint) reinterpretation
        static void TestCastUint()
        {
            int x;
            x = 123;
            int u;
            u = (uint)x;
            Console.WriteLine(u);
        }

        // Cas 8 : sizeof(int)
        static void TestSizeofInt()
        {
            int s;
            s = sizeof(int);
            Console.WriteLine(s);
        }

        // Cas 9 : sizeof(char)
        static void TestSizeofChar()
        {
            int s;
            s = sizeof(char);
            Console.WriteLine(s);
        }

        // Cas 10 : sizeof(bool)
        static void TestSizeofBool()
        {
            int s;
            s = sizeof(bool);
            Console.WriteLine(s);
        }

        // Cas 11 : sizeof(short)
        static void TestSizeofShort()
        {
            int s;
            s = sizeof(short);
            Console.WriteLine(s);
        }

        // Cas 12 : sizeof(double)
        static void TestSizeofDouble()
        {
            int s;
            s = sizeof(double);
            Console.WriteLine(s);
        }

        // Cas 13 : typeof(int) retourne le nom du type
        static void TestTypeofInt()
        {
            string s;
            s = typeof(int);
            Console.WriteLine(s);
        }

        // Cas 14 : typeof(bool)
        static void TestTypeofBool()
        {
            string s;
            s = typeof(bool);
            Console.WriteLine(s);
        }

        // Cas 15 : typeof(string)
        static void TestTypeofString()
        {
            string s;
            s = typeof(string);
            Console.WriteLine(s);
        }

        static void Main()
        {
            TestCastIntFromChar();
            TestCastCharFromInt();
            TestCastByte();
            TestCastShort();
            TestCastBoolTrue();
            TestCastBoolFalse();
            TestCastUint();
            TestSizeofInt();
            TestSizeofChar();
            TestSizeofBool();
            TestSizeofShort();
            TestSizeofDouble();
            TestTypeofInt();
            TestTypeofBool();
            TestTypeofString();
        }
    }
}
