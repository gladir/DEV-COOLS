// test22_switch.cs - Tests pour le switch/case/default (TODO 15)
using System;

class SwitchTest
{
    static void Main(string[] args)
    {
        // Cas 1 : switch simple avec un seul case
        int x = 1;
        switch (x)
        {
            case 1:
                x = 10;
                break;
        }

        // Cas 2 : switch avec case et default
        int y = 5;
        switch (y)
        {
            case 1:
                y = 10;
                break;
            case 2:
                y = 20;
                break;
            default:
                y = 99;
                break;
        }

        // Cas 3 : switch avec plusieurs case (valeurs multiples)
        int z = 3;
        switch (z)
        {
            case 1:
            case 2:
            case 3:
                z = 100;
                break;
            case 4:
                z = 200;
                break;
            default:
                z = 0;
                break;
        }

        // Cas 4 : switch avec expression
        int a = 2;
        int b = 3;
        switch (a + b)
        {
            case 5:
                a = 50;
                break;
            case 10:
                a = 100;
                break;
        }

        // Cas 5 : switch avec valeur negative
        int n = -1;
        switch (n)
        {
            case -1:
                n = 42;
                break;
            case 0:
                n = 0;
                break;
            case 1:
                n = 1;
                break;
        }

        // Cas 6 : switch avec caractere
        int c = 65;
        switch (c)
        {
            case 65:
                c = 1;
                break;
            case 66:
                c = 2;
                break;
            default:
                c = 0;
                break;
        }

        // Cas 7 : switch seul avec default uniquement
        int d = 99;
        switch (d)
        {
            default:
                d = 0;
                break;
        }

        // Cas 8 : switch avec variable comme expression
        int val = 3;
        int result = 0;
        switch (val)
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

        // Cas 9 : switch imbrique
        int outer = 1;
        int inner = 2;
        switch (outer)
        {
            case 1:
                switch (inner)
                {
                    case 2:
                        inner = 22;
                        break;
                    default:
                        inner = 0;
                        break;
                }
                break;
            default:
                outer = 0;
                break;
        }

        // Cas 10 : switch dans une boucle while
        int i = 0;
        int sum = 0;
        while (i < 3)
        {
            switch (i)
            {
                case 0:
                    sum = sum + 10;
                    break;
                case 1:
                    sum = sum + 20;
                    break;
                case 2:
                    sum = sum + 30;
                    break;
            }
            i = i + 1;
        }

        // Cas 11 : switch dans une boucle for
        int total = 0;
        for (int j = 0; j < 4; j++)
        {
            switch (j)
            {
                case 0:
                    total = total + 1;
                    break;
                case 1:
                    total = total + 2;
                    break;
                default:
                    total = total + 5;
                    break;
            }
        }

        // Cas 12 : switch avec zero
        int w = 0;
        switch (w)
        {
            case 0:
                w = 100;
                break;
            case 1:
                w = 200;
                break;
        }

        // Cas 13 : switch avec grandes valeurs
        int big = 1000;
        switch (big)
        {
            case 100:
                big = 1;
                break;
            case 1000:
                big = 2;
                break;
            case 10000:
                big = 3;
                break;
        }

        // Cas 14 : default au milieu (style C# valide)
        int mid = 7;
        switch (mid)
        {
            case 1:
                mid = 10;
                break;
            default:
                mid = 50;
                break;
            case 7:
                mid = 70;
                break;
        }

        // Cas 15 : switch apres des instructions if/else
        int p = 3;
        if (p > 0)
        {
            switch (p)
            {
                case 1:
                    p = 10;
                    break;
                case 3:
                    p = 30;
                    break;
                default:
                    p = 0;
                    break;
            }
        }
    }
}
