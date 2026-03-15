// test25_namespaces.cs - Test TODO 18 : ESPACES DE NOMS (namespace)
// 15 cas de test : namespace simple, namespace imbrique, using,
//   noms qualifies Namespace.Classe.Methode, classes multiples
//   dans un namespace, namespaces multiples.

using System;

// Cas 1 : namespace simple
namespace MyApp
{
    // Cas 2 : classe dans un namespace
    class Calculator
    {
        // Cas 3 : methode statique dans classe dans namespace
        public static int Add(int a, int b)
        {
            return a + b;
        }

        // Cas 4 : methode statique avec condition
        public static int Abs(int x)
        {
            if (x < 0)
            {
                return 0 - x;
            }
            return x;
        }

        // Cas 5 : champ statique dans namespace
        public static int version = 1;
    }

    // Cas 6 : deuxieme classe dans le meme namespace
    class Formatter
    {
        // Cas 7 : methode utilisant une autre classe du meme namespace
        public static int FormatResult(int a, int b)
        {
            int sum;
            sum = Calculator.Add(a, b);
            return sum;
        }

        // Cas 8 : methode avec boucle
        public static int Repeat(int val, int times)
        {
            int result;
            int i;
            result = 0;
            i = 0;
            while (i < times)
            {
                result = result + val;
                i = i + 1;
            }
            return result;
        }
    }

    // Cas 9 : classe avec visibilite internal
    internal class Helper
    {
        // Cas 10 : methode private dans classe internal
        private static int Double(int x)
        {
            return x + x;
        }

        // Cas 11 : methode publique appelant methode privee
        public static int Quadruple(int x)
        {
            return Double(Double(x));
        }
    }

    // Cas 12 : classe Program (point d entree) dans namespace
    class Program
    {
        // Cas 13 : Main dans un namespace
        static void Main()
        {
            int r;

            // Cas 14 : appel qualifie inter-classes dans namespace
            r = Calculator.Add(10, 20);
            Console.WriteLine(r);

            r = Calculator.Abs(0 - 15);
            Console.WriteLine(r);

            r = Formatter.FormatResult(3, 7);
            Console.WriteLine(r);

            r = Formatter.Repeat(5, 4);
            Console.WriteLine(r);

            r = Helper.Quadruple(3);
            Console.WriteLine(r);

            // Cas 15 : appel avec nom pleinement qualifie Namespace.Classe.Methode
            r = MyApp.Calculator.Add(100, 200);
            Console.WriteLine(r);
        }
    }
}
