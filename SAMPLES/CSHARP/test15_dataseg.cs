// test15_dataseg.cs - Test TODO 08 : segment de donnees et statiques
// Verifie que les variables statiques et les chaines sont
// correctement ajoutees dans le segment .DATA

using System;

namespace TestDataSeg
{
    class DataTest
    {
        static int counter;
        static bool flag;
        static string message;
        static int total;
        static char separator;

        static void Main(string[] args)
        {
            // Chaines de test (ajoutees au StrLitTab)
            Console.WriteLine("Data segment test");
            Console.WriteLine("Hello World");
            Console.WriteLine("Testing static vars");
            Console.WriteLine("Counter value");
            Console.WriteLine("Flag status");
            Console.WriteLine("Done");

            // Variables locales
            int x = 10;
            int y = 20;
            bool ok = true;
        }
    }
}
