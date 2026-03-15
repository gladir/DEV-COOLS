// test31_runtime.cs - Test TODO 24 : Runtime minimal Win32
// Verifie que les routines runtime sont emises correctement
// dans le fichier assembleur genere.

using System;

namespace TestRuntime
{
    class Program
    {
        // Test 1 : affichage entier via PRINTINT
        static void TestPrintInt()
        {
            int x = 42;
            Console.WriteLine(x);
        }

        // Test 2 : affichage chaine via PRINTSTR
        static void TestPrintStr()
        {
            string s = "Hello Runtime";
            Console.WriteLine(s);
        }

        // Test 3 : affichage booleen via PRINTBOOL
        static void TestPrintBool()
        {
            bool b = true;
            Console.WriteLine(b);
        }

        // Test 4 : affichage caractere via PRINTCHAR
        static void TestPrintChar()
        {
            char c = 'A';
            Console.WriteLine(c);
        }

        // Test 5 : affichage CRLF seul
        static void TestPrintCRLF()
        {
            Console.WriteLine();
        }

        // Test 6 : concatenation chaines via STRCAT
        static void TestStrCat()
        {
            string a = "Hello";
            string b = " World";
            string c = a + b;
            Console.WriteLine(c);
        }

        // Test 7 : longueur chaine via STRLEN
        static void TestStrLen()
        {
            string s = "ABCDE";
            int len = s.Length;
            Console.WriteLine(len);
        }

        // Test 8 : conversion entier -> chaine via NUMTOSTR + PRINTINT
        static void TestNumToStr()
        {
            int n = -123;
            Console.WriteLine(n);
        }

        // Test 9 : affichage de zero
        static void TestZero()
        {
            int z = 0;
            Console.WriteLine(z);
        }

        // Test 10 : affichage de false
        static void TestFalse()
        {
            bool f = false;
            Console.WriteLine(f);
        }

        // Test 11 : affichage de chaine vide
        static void TestEmptyStr()
        {
            string e = "";
            Console.WriteLine(e);
        }

        // Test 12 : addition chaine avec entier (int -> str)
        static void TestMixed()
        {
            string s = "Value=";
            int v = 99;
            Console.Write(s);
            Console.WriteLine(v);
        }

        // Test 13 : cast + affichage
        static void TestCastPrint()
        {
            int x = 65;
            char c = (char)x;
            Console.WriteLine(c);
        }

        // Test 14 : sizeof + affichage
        static void TestSizeofPrint()
        {
            int sz = sizeof(int);
            Console.WriteLine(sz);
        }

        // Test 15 : multiple appels Console
        static void TestMultiple()
        {
            Console.Write("A=");
            Console.Write(1);
            Console.Write(" B=");
            Console.Write(2);
            Console.WriteLine();
        }

        static void Main()
        {
            TestPrintInt();
            TestPrintStr();
            TestPrintBool();
            TestPrintChar();
            TestPrintCRLF();
            TestStrCat();
            TestStrLen();
            TestNumToStr();
            TestZero();
            TestFalse();
            TestEmptyStr();
            TestMixed();
            TestCastPrint();
            TestSizeofPrint();
            TestMultiple();
        }
    }
}
