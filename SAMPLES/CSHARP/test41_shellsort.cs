// test41_shellsort.cs - Tri Shell-Metzner
// Implementation classique du tri de Shell (aussi appele
// Shell-Metzner) avec la suite de pas h = n/2, n/4 ... 1.
// Teste sur un tableau d entiers desordonne et verifie que
// le resultat est trie.
//
// Sortie attendue :
// --- Tableau initial ---
// 64 34 25 12 22 11 90 50 77 30 45 5
// --- Passes ---
// Pas 6: 64 34 25 12 22 5 90 50 77 30 45 11
// Pas 3: 12 22 5 30 34 11 64 45 25 90 50 77
// Pas 1: 5 11 12 22 25 30 34 45 50 64 77 90
// --- Tableau trie ---
// 5 11 12 22 25 30 34 45 50 64 77 90
// Tri verifie=True
// Test tri Shell-Metzner OK

using System;

namespace Test41
{
    class Program
    {
        static string Joindre(int[] tab)
        {
            string s = "";
            for (int i = 0; i < tab.Length; i++)
            {
                if (i > 0) s = s + " ";
                s = s + tab[i];
            }
            return s;
        }

        // Tri de Shell-Metzner : insertion avec pas decroissants.
        // Affiche l etat du tableau apres chaque pas.
        static void ShellMetzner(int[] tab)
        {
            int n = tab.Length;
            int pas = n / 2;
            while (pas > 0)
            {
                for (int i = pas; i < n; i++)
                {
                    int temp = tab[i];
                    int j = i;
                    while (j >= pas && tab[j - pas] > temp)
                    {
                        tab[j] = tab[j - pas];
                        j = j - pas;
                    }
                    tab[j] = temp;
                }
                Console.WriteLine("Pas " + pas + ": " + Joindre(tab));
                pas = pas / 2;
            }
        }

        static bool EstTrie(int[] tab)
        {
            for (int i = 1; i < tab.Length; i++)
            {
                if (tab[i - 1] > tab[i]) return false;
            }
            return true;
        }

        static void Main()
        {
            int[] tab = new int[] {
                64, 34, 25, 12, 22, 11, 90, 50, 77, 30, 45, 5
            };

            Console.WriteLine("--- Tableau initial ---");
            Console.WriteLine(Joindre(tab));

            Console.WriteLine("--- Passes ---");
            ShellMetzner(tab);

            Console.WriteLine("--- Tableau trie ---");
            Console.WriteLine(Joindre(tab));
            Console.WriteLine("Tri verifie=" + EstTrie(tab));

            Console.WriteLine("Test tri Shell-Metzner OK");
        }
    }
}
