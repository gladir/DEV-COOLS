// test29_goto.cs - Test goto, break, continue, return (TODO 22)
using System;

namespace TestGoto
{
    class Program
    {
        // Cas 1 : goto simple (saut en avant)
        static void TestGotoForward()
        {
            int x;
            x = 1;
            goto skip;
            x = 999;
        skip:
            Console.WriteLine(x);
        }

        // Cas 2 : goto avec label en arriere (boucle manuelle)
        static void TestGotoBackward()
        {
            int i;
            i = 0;
        top:
            i = i + 1;
            if (i < 5)
                goto top;
            Console.WriteLine(i);
        }

        // Cas 3 : goto avec plusieurs labels
        static void TestGotoMultiLabel()
        {
            int n;
            n = 2;
            if (n == 1)
                goto label_a;
            if (n == 2)
                goto label_b;
            goto label_c;
        label_a:
            Console.WriteLine("A");
            goto done;
        label_b:
            Console.WriteLine("B");
            goto done;
        label_c:
            Console.WriteLine("C");
        done:
            Console.WriteLine("fin");
        }

        // Cas 4 : break dans boucle while
        static void TestBreakWhile()
        {
            int i;
            i = 0;
            while (i < 100)
            {
                if (i == 3)
                    break;
                i = i + 1;
            }
            Console.WriteLine(i);
        }

        // Cas 5 : continue dans boucle for
        static void TestContinueFor()
        {
            int sum;
            sum = 0;
            for (int i = 0; i < 10; i++)
            {
                if (i == 5)
                    continue;
                sum = sum + 1;
            }
            Console.WriteLine(sum);
        }

        // Cas 6 : break dans boucle for
        static void TestBreakFor()
        {
            int last;
            last = 0;
            for (int i = 1; i <= 10; i++)
            {
                if (i == 6)
                    break;
                last = i;
            }
            Console.WriteLine(last);
        }

        // Cas 7 : break dans switch
        static void TestBreakSwitch()
        {
            int x;
            x = 2;
            switch (x)
            {
                case 1:
                    Console.WriteLine("un");
                    break;
                case 2:
                    Console.WriteLine("deux");
                    break;
                default:
                    Console.WriteLine("autre");
                    break;
            }
        }

        // Cas 8 : return avec valeur entiere
        static int TestReturnInt()
        {
            return 42;
        }

        // Cas 9 : return void (implicite)
        static void TestReturnVoid()
        {
            Console.WriteLine("avant return");
            return;
        }

        // Cas 10 : return conditionnel
        static int TestReturnCond(int n)
        {
            if (n > 0)
                return 1;
            return 0;
        }

        // Cas 11 : continue dans boucle while
        static void TestContinueWhile()
        {
            int i;
            int count;
            i = 0;
            count = 0;
            while (i < 5)
            {
                i = i + 1;
                if (i == 3)
                    continue;
                count = count + 1;
            }
            Console.WriteLine(count);
        }

        // Cas 12 : break dans do-while
        static void TestBreakDoWhile()
        {
            int i;
            i = 0;
            do
            {
                if (i == 4)
                    break;
                i = i + 1;
            } while (i < 100);
            Console.WriteLine(i);
        }

        // Cas 13 : goto dans une methode avec boucle
        static void TestGotoWithLoop()
        {
            int x;
            x = 0;
            for (int i = 0; i < 3; i++)
            {
                x = x + 1;
            }
            goto end;
            x = 999;
        end:
            Console.WriteLine(x);
        }

        // Cas 14 : return dans boucle
        static int TestReturnInLoop()
        {
            for (int i = 0; i < 10; i++)
            {
                if (i == 7)
                    return i;
            }
            return 0;
        }

        // Cas 15 : combinaison goto et break
        static void TestGotoAndBreak()
        {
            int x;
            x = 0;
            while (x < 10)
            {
                x = x + 1;
                if (x == 5)
                    break;
            }
            goto finale;
            x = 999;
        finale:
            Console.WriteLine(x);
        }

        static void Main()
        {
            TestGotoForward();
            TestGotoBackward();
            TestGotoMultiLabel();
            TestBreakWhile();
            TestContinueFor();
            TestBreakFor();
            TestBreakSwitch();
            int r;
            r = TestReturnInt();
            Console.WriteLine(r);
            TestReturnVoid();
            int c;
            c = TestReturnCond(5);
            Console.WriteLine(c);
            TestContinueWhile();
            TestBreakDoWhile();
            TestGotoWithLoop();
            int v;
            v = TestReturnInLoop();
            Console.WriteLine(v);
            TestGotoAndBreak();
        }
    }
}
