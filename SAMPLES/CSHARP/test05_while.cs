using System;

namespace Test05
{
    class Program
    {
        static void Main()
        {
            int i;
            int sum;

            i   = 0;
            sum = 0;

            while (i < 10)
            {
                sum += i;
                i++;
            }
            Console.WriteLine(sum);

            i = 0;
            while (i < 20)
            {
                if (i == 7)
                {
                    break;
                }
                if ((i % 2) == 0)
                {
                    i++;
                    continue;
                }
                Console.WriteLine(i);
                i++;
            }
        }
    }
}
