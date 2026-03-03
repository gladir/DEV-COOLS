using System;

namespace Test08
{
    class Program
    {
        static void Main()
        {
            string s1;
            string s2;
            string s3;

            s1 = "Bonjour";
            s2 = " monde";
            s3 = s1 + s2;
            Console.WriteLine(s3);

            s3 = "Valeur : " + "42";
            Console.WriteLine(s3);

            Console.WriteLine("Entrez votre nom :");
            s1 = Console.ReadLine();
            s2 = "Salut, " + s1;
            Console.WriteLine(s2);
        }
    }
}
