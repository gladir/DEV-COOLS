// test14_emitter.cs - Test de l emetteur ASM 80386 (TODO 07)
// Verifie que le fichier .asm est genere correctement
// avec en-tete, segment .DATA, segment .CODE, point d entree

using System;

namespace Test14
{
    class EmitterTest
    {
        static void Main(string[] args)
        {
            int x;
            int y;
            string msg;
            bool ok;

            x = 42;
            y = x + 10;
            msg = "Test emitter";
            ok = true;

            Console.WriteLine("Emitter test OK");
            Console.WriteLine(msg);
        }
    }
}
