// test33_filewrite.cs - Test des ecritures de fichiers (System.IO)
// Verifie File.WriteAllText, File.AppendAllText et File.Exists
//
// Sortie attendue :
// Cas 1 : ecriture simple
// File exists: True
// Cas 2 : ecrasement
// Cas 3 : append
// Cas 4 : fichier vide
// File exists: True
// Cas 5 : ecriture longue
// Test fichier ecriture OK

using System;
using System.IO;

namespace Test33
{
    class Program
    {
        static void Main()
        {
            string path;
            bool exists;

            // Cas 1 : ecriture simple d un fichier texte
            path = "test_output.txt";
            File.WriteAllText(path, "Hello File IO");
            Console.WriteLine("Cas 1 : ecriture simple");

            // Verifier que le fichier existe
            exists = File.Exists(path);
            Console.Write("File exists: ");
            Console.WriteLine(exists);

            // Cas 2 : ecrasement du fichier
            File.WriteAllText(path, "Overwritten content");
            Console.WriteLine("Cas 2 : ecrasement");

            // Cas 3 : ajout au fichier
            File.AppendAllText(path, " appended");
            Console.WriteLine("Cas 3 : append");

            // Cas 4 : ecriture d un fichier vide
            File.WriteAllText("test_empty.txt", "");
            Console.WriteLine("Cas 4 : fichier vide");
            exists = File.Exists("test_empty.txt");
            Console.Write("File exists: ");
            Console.WriteLine(exists);

            // Cas 5 : ecriture d un contenu plus long
            File.WriteAllText("test_long.txt", "ABCDEFGHIJ");
            Console.WriteLine("Cas 5 : ecriture longue");

            // Nettoyage
            File.Delete(path);
            File.Delete("test_empty.txt");
            File.Delete("test_long.txt");

            Console.WriteLine("Test fichier ecriture OK");
        }
    }
}
