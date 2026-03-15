// test19_assignments.cs - Test TODO 12 : Affectations et operateurs composes
using System;

namespace Test19
{
    class Program
    {
        static void Main(string[] args)
        {
            // Affectation simple
            int x = 10;
            int y = 3;

            // Affectation composee +=
            x += 5;

            // Affectation composee -=
            x -= 2;

            // Affectation composee *=
            x *= 4;

            // Affectation composee /=
            x /= 3;

            // Affectation composee %=
            y %= 2;

            // Affectation composee &=
            x &= 15;

            // Affectation composee |=
            x |= 8;

            // Affectation composee ^=
            x ^= 3;

            // Affectation composee <<=
            x <<= 1;

            // Affectation composee >>=
            x >>= 1;

            // Post-increment et decrement
            x++;
            y--;

            // Pre-increment et decrement
            ++x;
            --y;

            // Affectation avec expression
            int z = x + y;
        }
    }
}
