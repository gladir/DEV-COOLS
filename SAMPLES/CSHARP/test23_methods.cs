/* test23_methods.cs : test des methodes statiques (TODO 16) */
/* - declaration static type Nom(params) { corps }            */
/* - parametres [EBP+8], [EBP+12], ...                        */
/* - variables locales [EBP-4], [EBP-8], ...                  */
/* - appel : PUSH args, CALL, ADD ESP,n (cdecl)               */
/* - return expr -> MOV EAX + JMP epilogue                    */
/* - methodes void (pas de valeur de retour)                  */
/* - recursion (appels recursifs)                             */
/* - Main() comme point d entree                              */

using System;

class MathHelper
{
    /* Methode sans parametre */
    static int GetFortyTwo()
    {
        return 42;
    }

    /* Methode avec un parametre */
    static int Double(int x)
    {
        return x * 2;
    }

    /* Methode avec deux parametres */
    static int Add(int a, int b)
    {
        return a + b;
    }

    /* Methode avec trois parametres */
    static int AddThree(int a, int b, int c)
    {
        return a + b + c;
    }

    /* Methode void */
    static void DoNothing()
    {
        int dummy = 0;
    }

    /* Methode void avec parametre */
    static void SetValue(int val)
    {
        int local = val;
    }

    /* Methode avec variable locale */
    static int Square(int n)
    {
        int result = n * n;
        return result;
    }

    /* Methode avec plusieurs variables locales */
    static int Compute(int x, int y)
    {
        int sum = x + y;
        int diff = x - y;
        int prod = sum * diff;
        return prod;
    }

    /* Methode appelant une autre methode */
    static int DoubleAdd(int a, int b)
    {
        int s = Add(a, b);
        return Double(s);
    }

    /* Recursion : factorielle */
    static int Factorial(int n)
    {
        if (n <= 1)
            return 1;
        return n * Factorial(n - 1);
    }

    /* Recursion : fibonacci */
    static int Fibonacci(int n)
    {
        if (n <= 0) return 0;
        if (n == 1) return 1;
        return Fibonacci(n - 1) + Fibonacci(n - 2);
    }

    /* Methode avec return conditionnel */
    static int Abs(int x)
    {
        if (x < 0)
            return -x;
        return x;
    }

    /* Methode avec boucle et return */
    static int SumTo(int n)
    {
        int total = 0;
        int i = 1;
        while (i <= n)
        {
            total = total + i;
            i++;
        }
        return total;
    }

    /* Methode avec switch et return */
    static int DayType(int day)
    {
        switch (day)
        {
            case 1:
            case 7:
                return 0;
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
                return 1;
            default:
                return -1;
        }
    }
}

class Program
{
    static void Main()
    {
        int r1 = MathHelper.GetFortyTwo();
        int r2 = MathHelper.Double(5);
        int r3 = MathHelper.Add(3, 4);
        int r4 = MathHelper.AddThree(1, 2, 3);
        MathHelper.DoNothing();
        int r5 = MathHelper.Square(6);
        int r6 = MathHelper.Compute(10, 3);
        int r7 = MathHelper.DoubleAdd(2, 3);
        int r8 = MathHelper.Factorial(5);
        int r9 = MathHelper.Fibonacci(7);
        int r10 = MathHelper.Abs(-42);
        int r11 = MathHelper.SumTo(10);
        int r12 = MathHelper.DayType(3);
    }
}
