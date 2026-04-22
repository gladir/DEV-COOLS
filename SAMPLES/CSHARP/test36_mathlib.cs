// test36_mathlib.cs - Fonctions mathematiques avancees
// Utilisation de la classe System.Math : constantes PI et E,
// puissances, racines, logarithmes, fonctions trigonometriques,
// arrondis, valeur absolue, min/max.
//
// Sortie attendue :
// --- Constantes ---
// PI=3.14
// E=2.72
// --- Puissances et racines ---
// 2^10=1024
// sqrt(144)=12
// cbrt(27)=3
// --- Logarithmes ---
// log(e)=1
// log10(1000)=3
// log2(8)=3
// --- Trigonometrie ---
// sin(0)=0
// cos(0)=1
// tan(PI/4)=1
// --- Arrondis ---
// floor(3.7)=3
// ceil(3.2)=4
// round(2.5)=2
// round(3.5)=4
// abs(-42)=42
// --- Min / Max ---
// min(3,7)=3
// max(3,7)=7
// Test math OK

using System;
using System.Globalization;

namespace Test36
{
    class Program
    {
        static string F2(double v)
        {
            // Deux decimales pour afficher PI et E
            return v.ToString("F2", CultureInfo.InvariantCulture);
        }

        static string I(double v)
        {
            // Pour valeurs entieres (resultat exact attendu)
            return ((long)Math.Round(v)).ToString(CultureInfo.InvariantCulture);
        }

        static void Main()
        {
            Console.WriteLine("--- Constantes ---");
            Console.WriteLine("PI=" + F2(Math.PI));
            Console.WriteLine("E=" + F2(Math.E));

            Console.WriteLine("--- Puissances et racines ---");
            Console.WriteLine("2^10=" + I(Math.Pow(2, 10)));
            Console.WriteLine("sqrt(144)=" + I(Math.Sqrt(144)));
            Console.WriteLine("cbrt(27)=" + I(Math.Cbrt(27)));

            Console.WriteLine("--- Logarithmes ---");
            Console.WriteLine("log(e)=" + I(Math.Log(Math.E)));
            Console.WriteLine("log10(1000)=" + I(Math.Log10(1000)));
            Console.WriteLine("log2(8)=" + I(Math.Log2(8)));

            Console.WriteLine("--- Trigonometrie ---");
            Console.WriteLine("sin(0)=" + I(Math.Sin(0)));
            Console.WriteLine("cos(0)=" + I(Math.Cos(0)));
            Console.WriteLine("tan(PI/4)=" + I(Math.Round(Math.Tan(Math.PI / 4))));

            Console.WriteLine("--- Arrondis ---");
            Console.WriteLine("floor(3.7)=" + I(Math.Floor(3.7)));
            Console.WriteLine("ceil(3.2)=" + I(Math.Ceiling(3.2)));
            // Round suit l arrondi banquier par defaut
            Console.WriteLine("round(2.5)=" + I(Math.Round(2.5)));
            Console.WriteLine("round(3.5)=" + I(Math.Round(3.5)));
            Console.WriteLine("abs(-42)=" + Math.Abs(-42));

            Console.WriteLine("--- Min / Max ---");
            Console.WriteLine("min(3,7)=" + Math.Min(3, 7));
            Console.WriteLine("max(3,7)=" + Math.Max(3, 7));

            Console.WriteLine("Test math OK");
        }
    }
}
