using System;

namespace Test09
{
    class Program
    {
        static void Main()
        {
            int[] arr = new int[5];
            int   i;
            int   sum;

            arr[0] = 10;
            arr[1] = 20;
            arr[2] = 30;
            arr[3] = 40;
            arr[4] = 50;

            sum = 0;
            for (i = 0; i < 5; i++)
            {
                sum += arr[i];
            }
            Console.WriteLine(sum);

            for (i = 0; i < 5; i++)
            {
                Console.WriteLine(arr[i]);
            }
        }
    }
}
