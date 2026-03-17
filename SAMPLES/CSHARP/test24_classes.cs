/* test24_classes.cs : test des classes et membres statiques (TODO 17) */
/* - declaration class Nom { membres }                                */
/* - champs statiques : static int/bool/char/string dans .DATA        */
/* - methodes statiques dans les classes                              */
/* - plusieurs classes par fichier                                     */
/* - qualificateurs de visibilite (public, private, internal)         */
/* - acces aux membres par NomClasse.Membre                           */
/* - classe Program avec Main() comme point d entree                  */

using System;

/* Classe utilitaire avec champs et methodes statiques */
class Counter
{
    static int count = 0;
    static int step = 1;

    static void Reset()
    {
        count = 0;
    }

    static void Increment()
    {
        count = count + step;
    }

    static void IncrementBy(int n)
    {
        count = count + n;
    }

    static int GetCount()
    {
        return count;
    }

    static void SetStep(int s)
    {
        step = s;
    }
}

/* Classe avec calculs mathematiques */
public class MathUtils
{
    static int lastResult = 0;

    static int Add(int a, int b)
    {
        lastResult = a + b;
        return lastResult;
    }

    static int Multiply(int a, int b)
    {
        lastResult = a * b;
        return lastResult;
    }

    static int Square(int n)
    {
        return Multiply(n, n);
    }

    static int GetLastResult()
    {
        return lastResult;
    }

    static bool IsPositive(int n)
    {
        if (n > 0)
            return true;
        return false;
    }

    static int Abs(int x)
    {
        if (x < 0)
            return -x;
        return x;
    }
}

/* Classe avec champs statiques de differents types */
internal class Config
{
    static int maxItems = 100;
    static int minItems = 1;
    static bool enabled = true;
    static int version = 3;

    static int GetMax()
    {
        return maxItems;
    }

    static int GetMin()
    {
        return minItems;
    }

    static bool IsEnabled()
    {
        return enabled;
    }

    static void SetMax(int m)
    {
        maxItems = m;
    }
}

/* Classe vide (test de robustesse) */
class EmptyClass
{
}

/* Classe avec une seule methode void */
private class SingleMethod
{
    static void DoNothing()
    {
        int x = 0;
    }
}

/* Classe avec acces inter-classes */
class Calculator
{
    static int Compute(int a, int b)
    {
        int sum = MathUtils.Add(a, b);
        int prod = MathUtils.Multiply(a, b);
        return sum + prod;
    }

    static int DoubleSquare(int n)
    {
        int sq = MathUtils.Square(n);
        return sq + sq;
    }
}

/* Classe Program avec Main() - point d entree */
class Program
{
    static void Main()
    {
        /* Test Counter */
        Counter.Reset();
        Counter.Increment();
        Counter.Increment();
        Counter.IncrementBy(5);
        int c = Counter.GetCount();

        /* Test MathUtils */
        int r1 = MathUtils.Add(10, 20);
        int r2 = MathUtils.Multiply(3, 4);
        int r3 = MathUtils.Square(5);
        int r4 = MathUtils.GetLastResult();
        bool b1 = MathUtils.IsPositive(42);
        bool b2 = MathUtils.IsPositive(-1);
        int r5 = MathUtils.Abs(-7);

        /* Test Config */
        int mx = Config.GetMax();
        int mn = Config.GetMin();
        bool en = Config.IsEnabled();
        Config.SetMax(200);

        /* Test Calculator (acces inter-classes) */
        int r6 = Calculator.Compute(3, 4);
        int r7 = Calculator.DoubleSquare(6);

        /* Test SingleMethod */
        SingleMethod.DoNothing();
    }
}
