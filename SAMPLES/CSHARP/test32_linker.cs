// test32_linker.cs - Test TODO 25 : Generation PE/COFF
// Cas 01 : Hello World basique
// Cas 02 : Variable entiere
// Cas 03 : Affichage entier
// Cas 04 : Chaine litterale
// Cas 05 : Condition if/else
// Cas 06 : Boucle while
// Cas 07 : Boucle for
// Cas 08 : Methode statique
// Cas 09 : Methode avec retour
// Cas 10 : Appel de methode
// Cas 11 : Operateurs arithmetiques
// Cas 12 : Comparaisons
// Cas 13 : Concatenation chaine
// Cas 14 : Cast et sizeof
// Cas 15 : Tableau et longueur

using System;

namespace TestLinker
{
    class Program
    {
        static int Add(int a, int b)
        {
            return a + b;
        }

        static int Factorial(int n)
        {
            if (n <= 1)
                return 1;
            return n * Factorial(n - 1);
        }

        static void PrintResult(string label, int value)
        {
            Console.Write(label);
            Console.Write(": ");
            Console.WriteLine(value);
        }

        static void Main()
        {
            // Cas 01 : Hello World
            Console.WriteLine("Hello PE World!");
            // Cas 02 : Variable entiere
            int x = 42;
            // Cas 03 : Affichage entier
            Console.WriteLine(x);
            // Cas 04 : Chaine litterale
            string msg = "Test linker OK";
            Console.WriteLine(msg);
            // Cas 05 : Condition
            if (x > 10)
                Console.WriteLine("x > 10");
            else
                Console.WriteLine("x <= 10");
            // Cas 06 : Boucle while
            int i = 0;
            while (i < 3)
            {
                Console.WriteLine(i);
                i = i + 1;
            }
            // Cas 07 : Boucle for
            for (int j = 0; j < 3; j = j + 1)
            {
                Console.WriteLine(j);
            }
            // Cas 08-10 : Methodes
            int sum = Add(10, 20);
            PrintResult("Sum", sum);
            // Cas 11 : Arithmetique
            int calc = (x + 8) * 2 - 10;
            Console.WriteLine(calc);
            // Cas 12 : Comparaisons
            bool cmp = (x == 42);
            Console.WriteLine(cmp);
            // Cas 13 : Concatenation
            string hello = "Hello" + " " + "World";
            Console.WriteLine(hello);
            // Cas 14 : Cast et sizeof
            int sz = sizeof(int);
            Console.WriteLine(sz);
            // Cas 15 : Factorial
            int fact = Factorial(5);
            PrintResult("5!", fact);
        }
    }
}
