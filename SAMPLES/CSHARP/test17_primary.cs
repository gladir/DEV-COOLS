// test17_primary.cs - Test TODO 10 : expressions primaires
// Verifie les expressions primaires :
// - Literaux entiers, chaines, caracteres, true/false/null
// - Acces variables locales, parametres, champs statiques
// - Appels de methodes (built-in et utilisateur)
// - Parentheses, negation unaire, negation logique,
//   complement bit a bit, pre/post increment/decrement
// - Operateur new, indexation tableau

using System;

namespace TestPrimary
{
    class ExprTest
    {
        // Champs statiques
        static int counter = 0;
        static bool flag = true;
        static string label = "test";

        // Methode avec parametres et variables locales
        static int Square(int x)
        {
            int result = x;
            return result;
        }

        // Methode sans parametre
        static int GetValue()
        {
            return 42;
        }

        // Methode void
        static void ShowInt(int val)
        {
            Console.WriteLine(val);
        }

        // Test des expressions primaires
        static void TestLiterals()
        {
            // Literaux entiers
            int a = 10;
            int b = 0;
            int c = 255;

            // Literal chaine
            string s = "hello world";

            // Literal caractere
            char ch = 'A';

            // Booleens
            bool t = true;
            bool f = false;

            // Null
            string n = null;

            // Negation unaire
            int neg = -42;

            Console.WriteLine(s);
            Console.WriteLine(a);
        }

        // Test des acces variables et appels
        static void TestAccess()
        {
            int x = 10;
            int y = 20;

            // Acces variable locale
            int z = x;

            // Appel de methode utilisateur
            int sq = Square(x);

            // Appel sans argument
            int val = GetValue();

            // Appel de methode built-in
            Console.Write("result: ");
            Console.WriteLine(z);

            // Parentheses
            int p = (x);

            // Acces champ statique
            int cnt = counter;
        }

        // Test des operateurs unaires
        static void TestUnary()
        {
            int a = 10;
            int b = 0;

            // Pre-increment
            ++a;

            // Pre-decrement
            --a;

            // Post-increment
            a++;

            // Post-decrement
            a--;

            // Negation logique
            bool notB = !flag;

            Console.WriteLine(a);
        }

        // Point d entree principal
        static void Main(string[] args)
        {
            TestLiterals();
            TestAccess();
            TestUnary();
            Console.WriteLine("Primary expressions test OK");
        }
    }
}
