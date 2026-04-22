// test39_tripleloop.cs - Triples boucles imbriquees
// Trois exemples qui manipulent des boucles a trois niveaux :
//   1. Remplissage et affichage d un cube 3x3x3
//   2. Recherche des triplets pythagoriciens (a<=b<=c<=20)
//   3. Somme triple SUM i*j*k pour i,j,k de 1 a 5
//
// Sortie attendue :
// --- Cube 3D 3x3x3 ---
// Couche 0
// 0 1 2
// 3 4 5
// 6 7 8
// Couche 1
// 9 10 11
// 12 13 14
// 15 16 17
// Couche 2
// 18 19 20
// 21 22 23
// 24 25 26
// Somme totale=351
// --- Triplets pythagoriciens (c<=20) ---
// 3 4 5
// 5 12 13
// 6 8 10
// 8 15 17
// 9 12 15
// 12 16 20
// Total=6
// --- Somme triple ---
// S=3375
// Test triples boucles OK

using System;

namespace Test39
{
    class Program
    {
        static void Cube()
        {
            const int N = 3;
            int[,,] cube = new int[N, N, N];
            int v = 0;
            // Remplissage
            for (int z = 0; z < N; z++)
            {
                for (int y = 0; y < N; y++)
                {
                    for (int x = 0; x < N; x++)
                    {
                        cube[z, y, x] = v;
                        v++;
                    }
                }
            }
            // Affichage et somme
            int somme = 0;
            for (int z = 0; z < N; z++)
            {
                Console.WriteLine("Couche " + z);
                for (int y = 0; y < N; y++)
                {
                    string ligne = "";
                    for (int x = 0; x < N; x++)
                    {
                        if (x > 0) ligne = ligne + " ";
                        ligne = ligne + cube[z, y, x];
                        somme = somme + cube[z, y, x];
                    }
                    Console.WriteLine(ligne);
                }
            }
            Console.WriteLine("Somme totale=" + somme);
        }

        static void Pythagore()
        {
            int total = 0;
            for (int a = 1; a <= 20; a++)
            {
                for (int b = a; b <= 20; b++)
                {
                    for (int c = b; c <= 20; c++)
                    {
                        if (a * a + b * b == c * c)
                        {
                            Console.WriteLine(a + " " + b + " " + c);
                            total++;
                        }
                    }
                }
            }
            Console.WriteLine("Total=" + total);
        }

        static void SommeTriple()
        {
            int s = 0;
            for (int i = 1; i <= 5; i++)
            {
                for (int j = 1; j <= 5; j++)
                {
                    for (int k = 1; k <= 5; k++)
                    {
                        s = s + i * j * k;
                    }
                }
            }
            Console.WriteLine("S=" + s);
        }

        static void Main()
        {
            Console.WriteLine("--- Cube 3D 3x3x3 ---");
            Cube();
            Console.WriteLine("--- Triplets pythagoriciens (c<=20) ---");
            Pythagore();
            Console.WriteLine("--- Somme triple ---");
            SommeTriple();
            Console.WriteLine("Test triples boucles OK");
        }
    }
}
