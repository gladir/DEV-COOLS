using System;

namespace Test22
{
    class Program
    {
        static void Main()
        {
            int x;
            int result;

            // 1. switch simple avec un seul case
            x = 1;
            switch (x)
            {
                case 1:
                    result = 10;
                    break;
            }

            // 2. switch avec plusieurs cases
            x = 2;
            switch (x)
            {
                case 1:
                    result = 10;
                    break;
                case 2:
                    result = 20;
                    break;
                case 3:
                    result = 30;
                    break;
            }

            // 3. switch avec default
            x = 99;
            switch (x)
            {
                case 1:
                    result = 10;
                    break;
                default:
                    result = -1;
                    break;
            }

            // 4. switch avec case multiples (case 1: case 2:)
            x = 2;
            switch (x)
            {
                case 1:
                case 2:
                    result = 100;
                    break;
                case 3:
                    result = 200;
                    break;
            }

            // 5. switch avec valeurs negatives
            x = -1;
            switch (x)
            {
                case -1:
                    result = 1;
                    break;
                case 0:
                    result = 0;
                    break;
                case 1:
                    result = -1;
                    break;
            }

            // 6. switch avec expression
            x = 3;
            switch (x + 1)
            {
                case 4:
                    result = 40;
                    break;
                default:
                    result = 0;
                    break;
            }

            // 7. switch avec case et default au milieu
            x = 5;
            switch (x)
            {
                case 1:
                    result = 10;
                    break;
                case 5:
                    result = 50;
                    break;
                default:
                    result = 0;
                    break;
            }

            // 8. switch avec case char
            x = 65;
            switch (x)
            {
                case 65:
                    result = 1;
                    break;
                case 66:
                    result = 2;
                    break;
            }

            // 9. switch avec zéro
            x = 0;
            switch (x)
            {
                case 0:
                    result = 100;
                    break;
                case 1:
                    result = 200;
                    break;
            }

            // 10. switch avec instructions multiples dans un case
            x = 2;
            switch (x)
            {
                case 1:
                    result = 1;
                    x = 10;
                    break;
                case 2:
                    result = 2;
                    x = 20;
                    break;
            }

            // 11. switch avec grandes valeurs
            x = 1000;
            switch (x)
            {
                case 100:
                    result = 1;
                    break;
                case 1000:
                    result = 10;
                    break;
                default:
                    result = 0;
                    break;
            }

            // 12. switch avec variable modifiee dans case
            x = 3;
            result = 0;
            switch (x)
            {
                case 1:
                    result = result + 1;
                    break;
                case 2:
                    result = result + 2;
                    break;
                case 3:
                    result = result + 3;
                    break;
                default:
                    result = result + 99;
                    break;
            }
        }
    }
}
