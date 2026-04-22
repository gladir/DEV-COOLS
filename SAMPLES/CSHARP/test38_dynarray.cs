// test38_dynarray.cs - Tableau dynamique
// Illustre List<T> : Add, Insert, RemoveAt, IndexOf, Contains,
// Sort, Reverse, iteration via foreach. Compare egalement avec
// la reallocation manuelle d un tableau classique (redim).
//
// Sortie attendue :
// --- List<int> de base ---
// Count=5
// 10 20 30 40 50
// --- Insertion et suppression ---
// Apres Insert(2,99): 10 20 99 30 40 50
// Apres RemoveAt(0): 20 99 30 40 50
// IndexOf(99)=1
// Contains(42)=False
// --- Tri et inverse ---
// Tri: 20 30 40 50 99
// Reverse: 99 50 40 30 20
// --- Iteration foreach ---
// Somme=239
// --- Redim manuel d un tableau ---
// Avant: 3
// Apres: 6
// 1 2 3 4 5 6
// Test tableau dynamique OK

using System;
using System.Collections.Generic;

namespace Test38
{
    class Program
    {
        static string Joindre(List<int> liste)
        {
            string s = "";
            for (int i = 0; i < liste.Count; i++)
            {
                if (i > 0) s = s + " ";
                s = s + liste[i];
            }
            return s;
        }

        static string JoindreTab(int[] tab)
        {
            string s = "";
            for (int i = 0; i < tab.Length; i++)
            {
                if (i > 0) s = s + " ";
                s = s + tab[i];
            }
            return s;
        }

        // Redimensionne un tableau en copiant les elements
        static int[] Redim(int[] src, int nouvelleTaille)
        {
            int[] dst = new int[nouvelleTaille];
            int n = src.Length;
            if (nouvelleTaille < n) n = nouvelleTaille;
            for (int i = 0; i < n; i++)
            {
                dst[i] = src[i];
            }
            return dst;
        }

        static void Main()
        {
            List<int> liste = new List<int>();
            liste.Add(10);
            liste.Add(20);
            liste.Add(30);
            liste.Add(40);
            liste.Add(50);

            Console.WriteLine("--- List<int> de base ---");
            Console.WriteLine("Count=" + liste.Count);
            Console.WriteLine(Joindre(liste));

            Console.WriteLine("--- Insertion et suppression ---");
            liste.Insert(2, 99);
            Console.WriteLine("Apres Insert(2,99): " + Joindre(liste));
            liste.RemoveAt(0);
            Console.WriteLine("Apres RemoveAt(0): " + Joindre(liste));
            Console.WriteLine("IndexOf(99)=" + liste.IndexOf(99));
            Console.WriteLine("Contains(42)=" + liste.Contains(42));

            Console.WriteLine("--- Tri et inverse ---");
            liste.Sort();
            Console.WriteLine("Tri: " + Joindre(liste));
            liste.Reverse();
            Console.WriteLine("Reverse: " + Joindre(liste));

            Console.WriteLine("--- Iteration foreach ---");
            int somme = 0;
            foreach (int v in liste)
            {
                somme = somme + v;
            }
            Console.WriteLine("Somme=" + somme);

            Console.WriteLine("--- Redim manuel d un tableau ---");
            int[] tab = new int[] { 1, 2, 3 };
            Console.WriteLine("Avant: " + tab.Length);
            tab = Redim(tab, 6);
            tab[3] = 4;
            tab[4] = 5;
            tab[5] = 6;
            Console.WriteLine("Apres: " + tab.Length);
            Console.WriteLine(JoindreTab(tab));

            Console.WriteLine("Test tableau dynamique OK");
        }
    }
}
