// test23_methods.cs - Test TODO 16 : METHODES STATIQUES
// 14 cas de test : declarations, parametres, return, appels,
//   recursion, void, valeur de retour, appels imbriques.

using System;

namespace Test23
{
    class Program
    {
        // Cas 1 : methode void sans parametres
        static void Hello()
        {
            Console.WriteLine(42);
        }

        // Cas 2 : methode int avec un parametre
        static int Double(int x)
        {
            return x + x;
        }

        // Cas 3 : methode int avec deux parametres
        static int Add(int a, int b)
        {
            return a + b;
        }

        // Cas 4 : methode avec if/else et return
        static int Max(int a, int b)
        {
            if (a > b)
            {
                return a;
            }
            return b;
        }

        // Cas 5 : methode avec calcul local
        static int Square(int n)
        {
            int result;
            result = n * n;
            return result;
        }

        // Cas 6 : methode void avec parametre
        static void PrintValue(int val)
        {
            Console.WriteLine(val);
        }

        // Cas 7 : methode avec boucle
        static int Factorial(int n)
        {
            int result;
            int i;
            result = 1;
            i = 1;
            while (i <= n)
            {
                result = result * i;
                i = i + 1;
            }
            return result;
        }

        // Cas 8 : methode bool
        static bool IsPositive(int x)
        {
            if (x > 0)
            {
                return 1;
            }
            return 0;
        }

        // Cas 9 : methode avec trois parametres
        static int Clamp(int val, int lo, int hi)
        {
            if (val < lo)
            {
                return lo;
            }
            if (val > hi)
            {
                return hi;
            }
            return val;
        }

        // Cas 10 : methode recursive (fibonacci)
        static int Fib(int n)
        {
            if (n <= 1)
            {
                return n;
            }
            return Add(Fib(n - 1), Fib(n - 2));
        }

        // Cas 11 : methode avec variable statique
        static int counter = 0;

        // Cas 12 : methode avec expression composee
        static int Expr(int a, int b, int c)
        {
            return a * b + c;
        }

        // Cas 13 : methode appelant d autres methodes
        static int Chain(int x)
        {
            return Double(Add(x, 1));
        }

        // Cas 14 : Main - point d entree
        static void Main()
        {
            int r;

            // Appel void sans params
            Hello();

            // Appel avec retour int
            r = Double(5);
            Console.WriteLine(r);

            // Appel avec deux params
            r = Add(3, 7);
            Console.WriteLine(r);

            // Appel avec if/return
            r = Max(12, 5);
            Console.WriteLine(r);

            // Appel avec calcul local
            r = Square(6);
            Console.WriteLine(r);

            // Appel void avec param
            PrintValue(99);

            // Appel avec boucle
            r = Factorial(5);
            Console.WriteLine(r);

            // Appel avec 3 params
            r = Clamp(50, 0, 100);
            Console.WriteLine(r);

            // Appel imbrique
            r = Max(Add(2, 3), Max(4, 6));
            Console.WriteLine(r);

            // Appel recursif
            r = Fib(7);
            Console.WriteLine(r);

            // Expression composee
            r = Expr(2, 3, 4);
            Console.WriteLine(r);

            // Chaine d appels
            r = Chain(4);
            Console.WriteLine(r);
        }
    }
}
