// test27_strings.cs - Test des operations sur les chaines (TODO 20)
using System;

namespace TestStrings
{
    class Program
    {
        static void Main()
        {
            // Cas 1 : declaration et affectation de chaine
            string s1;
            s1 = "Hello";

            // Cas 2 : concatenation de deux chaines
            string s2;
            s2 = "Hello" + " World";

            // Cas 3 : concatenation avec variable chaine
            string s3;
            s3 = s1 + " World";

            // Cas 4 : concatenation mixte chaine + entier
            int x;
            x = 42;
            string s4;
            s4 = "Valeur=" + x;

            // Cas 5 : concatenation mixte entier + chaine
            string s5;
            s5 = x + " est la reponse";

            // Cas 6 : propriete Length sur chaine
            string s6;
            s6 = "Bonjour";
            int len;
            len = s6.Length;

            // Cas 7 : comparaison de chaines avec ==
            string a;
            string b;
            a = "test";
            b = "test";
            bool eq;
            eq = (a == b);

            // Cas 8 : comparaison de chaines avec !=
            string c;
            c = "autre";
            bool neq;
            neq = (a != c);

            // Cas 9 : concatenation avec +=
            string s7;
            s7 = "Hello";
            s7 += " World";

            // Cas 10 : chaine vide
            string empty;
            empty = "";

            // Cas 11 : concatenation multiple
            string s8;
            s8 = "A" + "B" + "C";

            // Cas 12 : affectation de Console.ReadLine (type string)
            // string input;
            // input = Console.ReadLine();

            // Cas 13 : chaine dans un if
            string s9;
            s9 = "oui";
            if (s9 == "oui")
            {
                s9 = "confirme";
            }

            // Cas 14 : chaine dans une boucle
            string s10;
            s10 = "";
            int i;
            for (i = 0; i < 3; i++)
            {
                s10 += "x";
            }

            // Cas 15 : comparaison avec litteral
            bool check;
            check = (s1 == "Hello");
        }
    }
}
