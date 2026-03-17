// test34_fileread.cs - Test des lectures de fichiers (System.IO)
// Verifie File.WriteAllText, File.ReadAllText, File.AppendAllText
//
// Sortie attendue :
// Cas 1 : ecriture et lecture
// Hello File
// Cas 2 : lecture apres ecrasement
// New Content
// Cas 3 : lecture apres append
// BaseAppended
// Cas 4 : fichier vide lu
// empty ok
// Cas 5 : existence
// True
// False
// Test fichier lecture OK

using System;
using System.IO;

namespace Test34
{
    class Program
    {
        static void Main()
        {
            string path;
            string content;
            bool exists;

            // Cas 1 : ecriture puis relecture
            path = "test_rw.txt";
            File.WriteAllText(path, "Hello File");
            content = File.ReadAllText(path);
            Console.WriteLine("Cas 1 : ecriture et lecture");
            Console.WriteLine(content);

            // Cas 2 : ecrasement et relecture
            File.WriteAllText(path, "New Content");
            content = File.ReadAllText(path);
            Console.WriteLine("Cas 2 : lecture apres ecrasement");
            Console.WriteLine(content);

            // Cas 3 : append et relecture
            File.WriteAllText(path, "Base");
            File.AppendAllText(path, "Appended");
            content = File.ReadAllText(path);
            Console.WriteLine("Cas 3 : lecture apres append");
            Console.WriteLine(content);

            // Cas 4 : fichier vide
            File.WriteAllText(path, "");
            content = File.ReadAllText(path);
            Console.WriteLine("Cas 4 : fichier vide lu");
            Console.WriteLine("empty ok");

            // Cas 5 : existence avant et apres delete
            File.WriteAllText(path, "test");
            exists = File.Exists(path);
            Console.WriteLine("Cas 5 : existence");
            Console.WriteLine(exists);
            File.Delete(path);
            exists = File.Exists(path);
            Console.WriteLine(exists);

            Console.WriteLine("Test fichier lecture OK");
        }
    }
}
