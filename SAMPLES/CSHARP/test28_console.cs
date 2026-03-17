// test28_console.cs - Test des entrees/sorties Console (TODO 21)
using System;

namespace TestConsole
{
    class Program
    {
        static void Main()
        {
            // Cas 1 : Console.WriteLine avec string
            Console.WriteLine("Bonjour le monde");

            // Cas 2 : Console.WriteLine avec int
            int x;
            x = 42;
            Console.WriteLine(x);

            // Cas 3 : Console.WriteLine avec bool
            bool b;
            b = true;
            Console.WriteLine(b);

            // Cas 4 : Console.WriteLine avec char
            char c;
            c = 'A';
            Console.WriteLine(c);

            // Cas 5 : Console.WriteLine sans argument (ligne vide)
            Console.WriteLine();

            // Cas 6 : Console.Write avec string (pas de saut de ligne)
            Console.Write("Hello ");
            Console.Write("World");
            Console.WriteLine();

            // Cas 7 : Console.Write avec int
            Console.Write(123);
            Console.WriteLine();

            // Cas 8 : Console.Write avec bool
            Console.Write(false);
            Console.WriteLine();

            // Cas 9 : Console.Write avec char
            Console.Write('Z');
            Console.WriteLine();

            // Cas 10 : Console.WriteLine avec expression string concatenee
            string s1;
            s1 = "Hello" + " World";
            Console.WriteLine(s1);

            // Cas 11 : Console.WriteLine avec expression entiere
            int y;
            y = 10 + 20;
            Console.WriteLine(y);

            // Cas 12 : Console.WriteLine avec expression booleenne
            bool r;
            r = (x == 42);
            Console.WriteLine(r);

            // Cas 13 : Console.ReadLine (commenté pour test non-interactif)
            // string input;
            // input = Console.ReadLine();
            // Console.WriteLine(input);

            // Cas 14 : Console.WriteLine avec concatenation mixte
            Console.WriteLine("x = " + x);

            // Cas 15 : Console.Write suivi de valeurs differentes
            Console.Write("Resultat: ");
            Console.Write(y);
            Console.Write(" ok");
            Console.WriteLine();
        }
    }
}
