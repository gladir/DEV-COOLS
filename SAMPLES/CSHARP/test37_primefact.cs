// test37_primefact.cs - Nombres premiers et factorielles
// Combine deux classiques : generation des premiers via crible
// d Eratosthene et test de primalite, puis calcul de factorielles
// en version iterative et recursive (retour en long pour eviter
// le debordement sur 20!).
//
// Sortie attendue :
// --- Crible Eratosthene (<=30) ---
// 2 3 5 7 11 13 17 19 23 29
// --- Test primalite ---
// 2 premier
// 17 premier
// 25 non premier
// 97 premier
// --- Factorielles iteratives ---
// 0!=1
// 1!=1
// 5!=120
// 10!=3628800
// 15!=1307674368000
// 20!=2432902008176640000
// --- Factorielles recursives ---
// 0!=1
// 5!=120
// 10!=3628800
// Test premiers et factorielles OK

using System;

namespace Test37
{
    class Program
    {
        // Crible d Eratosthene : retourne le tableau des premiers <= n
        static int[] Crible(int n)
        {
            bool[] composite = new bool[n + 1];
            int count = 0;
            for (int i = 2; i <= n; i++)
            {
                if (!composite[i])
                {
                    count++;
                    for (long j = (long)i * i; j <= n; j += i)
                    {
                        composite[j] = true;
                    }
                }
            }
            int[] primes = new int[count];
            int k = 0;
            for (int i = 2; i <= n; i++)
            {
                if (!composite[i])
                {
                    primes[k] = i;
                    k++;
                }
            }
            return primes;
        }

        // Test de primalite par divisions d essai
        static bool EstPremier(int n)
        {
            if (n < 2) return false;
            if (n == 2) return true;
            if (n % 2 == 0) return false;
            for (int i = 3; (long)i * i <= n; i += 2)
            {
                if (n % i == 0) return false;
            }
            return true;
        }

        // Factorielle iterative
        static long FactIter(int n)
        {
            long r = 1;
            for (int i = 2; i <= n; i++)
            {
                r = r * i;
            }
            return r;
        }

        // Factorielle recursive
        static long FactRec(int n)
        {
            if (n <= 1) return 1;
            return n * FactRec(n - 1);
        }

        static void Main()
        {
            Console.WriteLine("--- Crible Eratosthene (<=30) ---");
            int[] primes = Crible(30);
            string ligne = "";
            for (int i = 0; i < primes.Length; i++)
            {
                if (i > 0) ligne = ligne + " ";
                ligne = ligne + primes[i];
            }
            Console.WriteLine(ligne);

            Console.WriteLine("--- Test primalite ---");
            int[] tests = new int[] { 2, 17, 25, 97 };
            for (int i = 0; i < tests.Length; i++)
            {
                int n = tests[i];
                if (EstPremier(n))
                {
                    Console.WriteLine(n + " premier");
                }
                else
                {
                    Console.WriteLine(n + " non premier");
                }
            }

            Console.WriteLine("--- Factorielles iteratives ---");
            int[] fs = new int[] { 0, 1, 5, 10, 15, 20 };
            for (int i = 0; i < fs.Length; i++)
            {
                Console.WriteLine(fs[i] + "!=" + FactIter(fs[i]));
            }

            Console.WriteLine("--- Factorielles recursives ---");
            int[] rs = new int[] { 0, 5, 10 };
            for (int i = 0; i < rs.Length; i++)
            {
                Console.WriteLine(rs[i] + "!=" + FactRec(rs[i]));
            }

            Console.WriteLine("Test premiers et factorielles OK");
        }
    }
}
