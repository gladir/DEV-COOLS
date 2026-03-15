// test24_classes.cs - Test TODO 17 : CLASSES ET MEMBRES STATIQUES
// 15 cas de test : declaration de classes, visibilite, champs statiques,
//   methodes statiques, acces qualifie ClassName.Member, classes multiples.

using System;

namespace Test24
{
    // Cas 1 : classe simple avec methode statique
    class MathHelper
    {
        // Cas 2 : methode statique avec deux parametres
        public static int Add(int a, int b)
        {
            return a + b;
        }

        // Cas 3 : methode statique avec if/else
        public static int Max(int a, int b)
        {
            if (a > b)
            {
                return a;
            }
            return b;
        }

        // Cas 4 : methode statique void
        public static void PrintVal(int x)
        {
            Console.WriteLine(x);
        }

        // Cas 5 : champ statique avec initialisation
        public static int factor = 10;

        // Cas 6 : methode utilisant un champ statique
        public static int Scale(int x)
        {
            return x * factor;
        }
    }

    // Cas 7 : deuxieme classe (classes multiples par fichier)
    class Counter
    {
        // Cas 8 : champ statique compteur
        private static int count = 0;

        // Cas 9 : methode avec modificateur private
        private static int GetValue()
        {
            return count;
        }

        // Cas 10 : methode publique utilisant methode privee
        public static int Get()
        {
            return GetValue();
        }

        // Cas 11 : methode statique avec boucle
        public static int Sum(int n)
        {
            int total;
            int i;
            total = 0;
            i = 1;
            while (i <= n)
            {
                total = total + i;
                i = i + 1;
            }
            return total;
        }
    }

    // Cas 12 : troisieme classe (test classes multiples)
    internal class Utils
    {
        // Cas 13 : methode avec protected (stub de visibilite)
        protected static int Square(int n)
        {
            return n * n;
        }

        // Cas 14 : methode utilisant une autre methode de la meme classe
        public static int SumOfSquares(int a, int b)
        {
            return MathHelper.Add(Square(a), Square(b));
        }
    }

    // Cas 15 : classe Program (point d entree)
    class Program
    {
        static void Main()
        {
            int r;

            // Appel methode via nom qualifie ClassName.Method
            r = MathHelper.Add(3, 7);
            Console.WriteLine(r);

            // Appel methode Max
            r = MathHelper.Max(12, 5);
            Console.WriteLine(r);

            // Appel methode void via nom qualifie
            MathHelper.PrintVal(99);

            // Utilisation champ statique via methode
            r = MathHelper.Scale(5);
            Console.WriteLine(r);

            // Appel methode de la deuxieme classe
            r = Counter.Get();
            Console.WriteLine(r);

            // Appel methode avec boucle
            r = Counter.Sum(10);
            Console.WriteLine(r);

            // Appel methode de la troisieme classe
            r = Utils.SumOfSquares(3, 4);
            Console.WriteLine(r);

            // Appel direct sans qualificateur (meme fichier)
            r = MathHelper.Add(MathHelper.Max(2, 3), MathHelper.Max(4, 6));
            Console.WriteLine(r);
        }
    }
}
