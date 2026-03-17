// test16_vardecl.cs - Test TODO 09 : variables et declarations
// Verifie les declarations de variables locales, statiques,
// parametres, initialisations et declarations multiples.

using System;

namespace TestVarDecl
{
    class VarTest
    {
        // Champs statiques de classe (segment .DATA)
        static int counter = 0;
        static bool flag = true;
        static string message = "hello";
        static int total;
        static char separator = ';';

        // Methode avec parametres et variables locales
        static int Add(int a, int b)
        {
            int result = 0;
            result = a;
            return result;
        }

        // Methode avec declarations multiples
        static void Display(string text)
        {
            int x, y, z;
            bool ok = true;
            char ch = 'A';
            string label = "value";
            Console.WriteLine(text);
        }

        // Methode avec differents types
        static void TypeTest()
        {
            int a = 10;
            uint b = 20;
            long c = 30;
            short d = 40;
            byte e = 50;
            sbyte f = -1;
            bool g = false;
            char h = 'X';
            double i = 0;
            float j = 0;
            string k = "test";
            int neg = -42;
        }

        // Point d entree principal
        static void Main(string[] args)
        {
            // Variables locales avec initialisation
            int x = 10;
            int y = 20;
            int z = 0;
            bool ok = true;
            char c = 'A';
            string s = "world";

            // Declarations multiples
            int a, b;

            // Utilisation de null
            string empty = null;

            // Variable sans init
            int count;

            Console.WriteLine("Variable declarations test");
            Console.WriteLine(s);
        }
    }
}
