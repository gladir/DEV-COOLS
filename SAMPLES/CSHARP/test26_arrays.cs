using System;

namespace TestArrays
{
    class Program
    {
        static void Main()
        {
            // Cas 1 : Declaration et allocation int[]
            int[] arr = new int[5];

            // Cas 2 : Initialisation element par element
            arr[0] = 10;
            arr[1] = 20;
            arr[2] = 30;
            arr[3] = 40;
            arr[4] = 50;

            // Cas 3 : Lecture d elements
            int x = arr[0];
            int y = arr[4];

            // Cas 4 : Somme des elements avec boucle
            int sum = 0;
            int i;
            for (i = 0; i < 5; i++)
            {
                sum += arr[i];
            }
            Console.WriteLine(sum);

            // Cas 5 : Affichage de chaque element
            for (i = 0; i < 5; i++)
            {
                Console.WriteLine(arr[i]);
            }

            // Cas 6 : Propriete Length
            int len = arr.Length;
            Console.WriteLine(len);

            // Cas 7 : Utilisation de Length dans une boucle
            for (i = 0; i < arr.Length; i++)
            {
                Console.WriteLine(arr[i]);
            }

            // Cas 8 : Second tableau
            int[] b = new int[3];
            b[0] = 100;
            b[1] = 200;
            b[2] = 300;

            // Cas 9 : Longueur du second tableau
            Console.WriteLine(b.Length);

            // Cas 10 : Tableau bool[]
            bool[] flags = new bool[4];
            flags[0] = true;
            flags[1] = false;
            flags[2] = true;
            flags[3] = false;

            // Cas 11 : Tableau char[]
            char[] ch = new char[3];
            ch[0] = 'A';
            ch[1] = 'B';
            ch[2] = 'C';

            // Cas 12 : Modification d un element
            arr[2] = 99;
            Console.WriteLine(arr[2]);

            // Cas 13 : Acces via expression d index
            int idx = 3;
            Console.WriteLine(arr[idx]);

            // Cas 14 : Affectation entre elements
            arr[0] = arr[4];
            Console.WriteLine(arr[0]);

            // Cas 15 : Tableau vide (taille 0)
            int[] empty = new int[0];
        }
    }
}
