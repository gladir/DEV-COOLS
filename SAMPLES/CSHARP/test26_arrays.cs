// test26_arrays.cs - Test TODO 19 : TABLEAUX
// 15 cas de test : declaration, acces, initialisation, boucles,
//   propriete Length, passage a methode, types multiples.

using System;

namespace TestArrays
{
    class ArrayHelper
    {
        // Cas 7 : methode prenant un tableau en parametre
        public static int Sum(int[] data, int count)
        {
            int total;
            int i;
            total = 0;
            for (i = 0; i < count; i++)
            {
                total = total + data[i];
            }
            return total;
        }

        // Cas 8 : methode retournant une somme partielle
        public static int SumFirst(int[] data, int n)
        {
            int s;
            int i;
            s = 0;
            for (i = 0; i < n; i++)
            {
                s = s + data[i];
            }
            return s;
        }
    }

    class Program
    {
        static void Main()
        {
            // Cas 1 : declaration et allocation de tableau int[]
            int[] arr = new int[5];
            int i;
            int sum;

            // Cas 2 : initialisation element par element
            arr[0] = 10;
            arr[1] = 20;
            arr[2] = 30;
            arr[3] = 40;
            arr[4] = 50;

            // Cas 3 : acces en lecture avec boucle for
            sum = 0;
            for (i = 0; i < 5; i++)
            {
                sum = sum + arr[i];
            }
            Console.WriteLine(sum);

            // Cas 4 : acces individuel en lecture
            Console.WriteLine(arr[0]);
            Console.WriteLine(arr[4]);

            // Cas 5 : modification d un element
            arr[2] = 99;
            Console.WriteLine(arr[2]);

            // Cas 6 : propriete Length
            Console.WriteLine(arr.Length);

            // Cas 9 : tableau dans expression arithmetique
            int result;
            result = arr[0] + arr[1];
            Console.WriteLine(result);

            // Cas 10 : tableau avec index variable
            int idx;
            idx = 3;
            Console.WriteLine(arr[idx]);

            // Cas 11 : tableau bool[]
            bool[] flags = new bool[3];
            flags[0] = true;
            flags[1] = false;
            flags[2] = true;

            // Cas 12 : acces au tableau bool
            if (flags[0])
            {
                Console.WriteLine(1);
            }

            // Cas 13 : second tableau int dans le meme scope
            int[] arr2 = new int[3];
            arr2[0] = 100;
            arr2[1] = 200;
            arr2[2] = 300;
            Console.WriteLine(arr2[1]);

            // Cas 14 : passage de tableau a methode
            int total;
            total = ArrayHelper.Sum(arr, 5);
            Console.WriteLine(total);

            // Cas 15 : boucle while avec index tableau
            i = 0;
            sum = 0;
            while (i < 3)
            {
                sum = sum + arr2[i];
                i = i + 1;
            }
            Console.WriteLine(sum);
        }
    }
}
