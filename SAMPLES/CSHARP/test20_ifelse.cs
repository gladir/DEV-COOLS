using System;

namespace Test20
{
    class Program
    {
        static void Main()
        {
            int x;
            int y;
            int z;

            x = 10;
            y = 20;

            // 1. if simple avec accolades
            if (x < y)
            {
                z = 1;
            }

            // 2. if/else avec accolades
            if (x > y)
            {
                z = 2;
            }
            else
            {
                z = 3;
            }

            // 3. if sans accolades (une seule instruction)
            if (x == 10)
                z = 4;

            // 4. if/else sans accolades
            if (x != 10)
                z = 5;
            else
                z = 6;

            // 5. else if imbrique
            if (x == 1)
            {
                z = 10;
            }
            else if (x == 10)
            {
                z = 20;
            }
            else
            {
                z = 30;
            }

            // 6. else if multiple
            if (x < 0)
            {
                z = 100;
            }
            else if (x == 0)
            {
                z = 200;
            }
            else if (x > 100)
            {
                z = 300;
            }
            else
            {
                z = 400;
            }

            // 7. if avec expression complexe (&&)
            if ((x > 0) && (y > 0))
            {
                z = 500;
            }

            // 8. if avec expression complexe (||)
            if ((x == 0) || (y == 20))
            {
                z = 600;
            }

            // 9. if avec negation (!)
            bool flag;
            flag = true;
            if (!flag)
            {
                z = 700;
            }

            // 10. if imbriques (nested)
            if (x > 0)
            {
                if (y > 0)
                {
                    z = 800;
                }
            }

            // 11. if avec bloc et portee locale
            if (x == 10)
            {
                int local;
                local = 42;
                z = local;
            }

            // 12. if/else avec appel de methode
            if (x < y)
            {
                Console.WriteLine("x < y");
            }
            else
            {
                Console.WriteLine("x >= y");
            }

            // 13. else if sans accolades
            if (x == 1)
                z = 1000;
            else if (x == 10)
                z = 2000;
            else
                z = 3000;
        }
    }
}
