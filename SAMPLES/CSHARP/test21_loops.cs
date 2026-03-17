using System;

namespace Test21
{
    class Program
    {
        static void Main()
        {
            int i;
            int sum;
            int n;
            int count;

            // 1. while simple
            sum = 0;
            i = 1;
            while (i <= 10)
            {
                sum = sum + i;
                i++;
            }

            // 2. while sans accolades
            i = 0;
            while (i < 5)
                i++;

            // 3. while avec condition complexe
            i = 0;
            n = 100;
            while ((i < 10) && (n > 0))
            {
                i++;
                n = n - 10;
            }

            // 4. do-while simple
            i = 0;
            do
            {
                i++;
            } while (i < 5);

            // 5. do-while sans accolades
            i = 0;
            do
                i++;
            while (i < 3);

            // 6. for simple
            sum = 0;
            for (int j = 0; j < 10; j++)
            {
                sum = sum + j;
            }

            // 7. for sans accolades
            sum = 0;
            for (int k = 1; k <= 5; k++)
                sum = sum + k;

            // 8. for avec variable existante
            sum = 0;
            for (i = 0; i < 10; i++)
            {
                sum = sum + i;
            }

            // 9. boucles imbriquees
            sum = 0;
            for (int a = 0; a < 3; a++)
            {
                for (int b = 0; b < 3; b++)
                {
                    sum = sum + 1;
                }
            }

            // 10. while avec break
            i = 0;
            while (i < 100)
            {
                if (i == 10)
                    break;
                i++;
            }

            // 11. for avec break
            sum = 0;
            for (i = 0; i < 100; i++)
            {
                if (i >= 5)
                    break;
                sum = sum + i;
            }

            // 12. while avec continue
            sum = 0;
            i = 0;
            while (i < 10)
            {
                i++;
                if (i == 5)
                    continue;
                sum = sum + i;
            }

            // 13. for avec continue
            sum = 0;
            for (i = 0; i < 10; i++)
            {
                if (i == 3)
                    continue;
                sum = sum + i;
            }

            // 14. while imbrique dans for
            for (i = 0; i < 3; i++)
            {
                count = 0;
                while (count < 2)
                {
                    count++;
                }
            }

            // 15. do-while avec break
            i = 0;
            do
            {
                if (i == 5)
                    break;
                i++;
            } while (i < 100);
        }
    }
}
