// test18_operators.cs - Test TODO 11 : Operateurs et precedence
// Compilateur CSCW32 - C# vers ASM 80386 (Windows 32 bits)

using System;

namespace TestOperators
{
    class Program
    {
        // --- Arithmetique ---
        static void TestArith()
        {
            int a = 10;
            int b = 3;
            int r;

            r = a + b;           // 13
            r = a - b;           // 7
            r = a * b;           // 30
            r = a / b;           // 3
            r = a % b;           // 1
            r = 2 + 3 * 4;      // 14 (precedence)
            r = (2 + 3) * 4;    // 20 (parentheses)
            r = 100 / 10 / 2;   // 5 (gauche a droite)
            r = 10 - 3 - 2;     // 5 (gauche a droite)
        }

        // --- Comparaison ---
        static void TestCompare()
        {
            int x = 5;
            int y = 10;
            bool t;

            t = (x == 5);       // true
            t = (x != y);       // true
            t = (x < y);        // true
            t = (x <= 5);       // true
            t = (y > x);        // true
            t = (y >= 10);      // true
            t = (x == y);       // false
            t = (x > y);        // false
        }

        // --- Logique court-circuit ---
        static void TestLogic()
        {
            bool a = true;
            bool b = false;
            bool r;

            r = a && a;          // true
            r = a && b;          // false
            r = b && a;          // false (court-circuit)
            r = a || b;          // true
            r = b || a;          // true
            r = b || b;          // false
            r = !a;              // false
            r = !b;              // true
        }

        // --- Bit a bit ---
        static void TestBitwise()
        {
            int a = 0xFF;
            int b = 0x0F;
            int r;

            r = a & b;           // 0x0F (AND)
            r = a | b;           // 0xFF (OR)
            r = a ^ b;           // 0xF0 (XOR)
            r = ~0;              // -1 (NOT)
            r = 1 << 4;          // 16
            r = 256 >> 4;        // 16
            r = 0xFF & 0x0F | 0xF0;  // precedence & > |
        }

        // --- Expressions complexes ---
        static void TestComplex()
        {
            int a = 2;
            int b = 3;
            int c = 4;
            int r;

            r = a + b * c;           // 14
            r = a * b + c;           // 10
            r = (a + b) * (c - 1);   // 15
            r = a * b * c;           // 24
            r = a + b + c;           // 9
            r = 1 + 2 + 3 + 4;      // 10
            r = 10 % 3 + 1;         // 2
        }

        // --- Comparaisons et logique combinees ---
        static void TestCombined()
        {
            int x = 5;
            int y = 10;
            bool r;

            r = (x > 0) && (x < 10);     // true
            r = (x > 10) || (y > 5);      // true
            r = (x == 5) && (y == 10);    // true
            r = (x != 5) || (y != 10);    // false
            r = !(x > y);                 // true
        }

        // --- Null-coalescing ---
        static void TestNullCoalesce()
        {
            int a = 0;
            int b = 42;
            int r;

            r = a;
            r = b;
        }

        // --- Decalages et masques ---
        static void TestShiftMask()
        {
            int flags = 0;
            int mask = 1 << 3;    // bit 3 = 8
            int r;

            r = flags | mask;     // set bit 3
            r = r & ~mask;        // clear bit 3
            r = (flags >> 2) & 1; // test bit 2
        }

        static void Main(string[] args)
        {
            TestArith();
            TestCompare();
            TestLogic();
            TestBitwise();
            TestComplex();
            TestCombined();
            TestNullCoalesce();
            TestShiftMask();
        }
    }
}
