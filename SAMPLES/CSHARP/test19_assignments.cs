// test19_assignments.cs - Test TODO 12 : Affectations et operateurs composes
// Compilateur CSCW32 - C# vers ASM 80386 (Windows 32 bits)

using System;

namespace TestAssignments
{
    class Program
    {
        // --- Affectation simple ---
        static void TestSimple()
        {
            int a;
            int b;
            int c;

            a = 10;
            b = 20;
            c = a;
        }

        // --- Affectation avec expression ---
        static void TestExpr()
        {
            int x = 5;
            int y = 3;
            int z;

            z = x + y;           // 8
            z = x * y + 1;       // 16
            z = (x + y) * 2;     // 16
        }

        // --- Operateurs composes += -= *= /= %= ---
        static void TestCompound()
        {
            int a = 10;

            a += 5;              // 15
            a -= 3;              // 12
            a *= 2;              // 24
            a /= 4;             // 6
            a %= 5;              // 1
        }

        // --- Operateurs composes bit a bit &= |= ^= ---
        static void TestBitCompound()
        {
            int flags = 0;

            flags |= 1;         // 1  (set bit 0)
            flags |= 4;         // 5  (set bit 2)
            flags &= 5;         // 5  (mask)
            flags ^= 1;         // 4  (toggle bit 0)
        }

        // --- Operateurs composes decalage <<= >>= ---
        static void TestShiftCompound()
        {
            int v = 1;

            v <<= 4;            // 16
            v >>= 2;            // 4
        }

        // --- Post-increment et post-decrement ---
        static void TestPostIncDec()
        {
            int i = 0;

            i++;                 // 1
            i++;                 // 2
            i--;                 // 1
        }

        // --- Pre-increment et pre-decrement ---
        static void TestPreIncDec()
        {
            int j = 10;

            ++j;                 // 11
            --j;                 // 10
        }

        // --- Affectation avec appel de methode ---
        static void TestMethodCall()
        {
            int x = 42;

            Console.WriteLine(x);
        }

        // --- Affectation chaine ---
        static void TestString()
        {
            string s;

            s = "hello";
        }

        // --- Affectations multiples ---
        static void TestMultiple()
        {
            int a = 1;
            int b = 2;
            int c = 3;

            a = b;
            b = c;
            c = a;
        }

        // --- Expressions comme instructions ---
        static void TestExprStmt()
        {
            int x = 5;

            x + 1;
        }

        // --- Return avec valeur ---
        static int GetValue()
        {
            int r = 42;
            return r;
        }

        // --- Bloc imbrique ---
        static void TestBlock()
        {
            int a = 1;
            {
                int b = 2;
                a = b;
            }
        }

        static void Main(string[] args)
        {
            TestSimple();
            TestExpr();
            TestCompound();
            TestBitCompound();
            TestShiftCompound();
            TestPostIncDec();
            TestPreIncDec();
            TestMethodCall();
            TestString();
            TestMultiple();
            TestBlock();
        }
    }
}
