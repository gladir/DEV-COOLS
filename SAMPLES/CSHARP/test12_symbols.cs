using System;

namespace Test12
{
    class Calculator
    {
        static int Add(int a, int b)
        {
            int result;
            result = a + b;
            return result;
        }

        static int Subtract(int a, int b)
        {
            return a - b;
        }

        static bool IsPositive(int n)
        {
            return n > 0;
        }

        static void PrintResult(string label, int value)
        {
            Console.Write(label);
            Console.Write(": ");
            Console.WriteLine(value);
        }

        static void Main()
        {
            const int BASE = 100;
            const string TITLE = "Calculator Test";

            int x;
            int y;
            int sum;
            bool ok;
            string msg;

            x = 42;
            y = 58;
            sum = Add(x, y);
            ok = IsPositive(sum);

            Console.WriteLine(TITLE);
            PrintResult("Sum", sum);
            PrintResult("Diff", Subtract(x, y));

            Console.WriteLine(ok);
            Console.WriteLine(BASE);

            msg = "Done";
            Console.WriteLine(msg);
        }
    }
}
