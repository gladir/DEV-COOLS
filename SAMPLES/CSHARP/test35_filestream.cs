// test35_filestream.cs - Lecture et ecriture de fichiers (flux)
// Exemple complexe utilisant StreamWriter, StreamReader,
// File.WriteAllLines, File.ReadAllLines et les flux binaires
// BinaryWriter / BinaryReader.
//
// Sortie attendue :
// --- Ecriture ligne par ligne ---
// 5 lignes ecrites
// --- Lecture ligne par ligne ---
// 1: Ligne une
// 2: Ligne deux
// 3: Ligne trois
// 4: Ligne quatre
// 5: Ligne cinq
// --- Lecture tableau ---
// Total lignes: 5
// --- Binaire ---
// int=123 double=3.14 chaine=ok
// Test fichier flux OK

using System;
using System.IO;

namespace Test35
{
    class Program
    {
        static void EcrireLignes(string path)
        {
            using (StreamWriter sw = new StreamWriter(path))
            {
                sw.WriteLine("Ligne une");
                sw.WriteLine("Ligne deux");
                sw.WriteLine("Ligne trois");
                sw.WriteLine("Ligne quatre");
                sw.WriteLine("Ligne cinq");
            }
            Console.WriteLine("5 lignes ecrites");
        }

        static void LireLignes(string path)
        {
            using (StreamReader sr = new StreamReader(path))
            {
                int num = 1;
                string line;
                while ((line = sr.ReadLine()) != null)
                {
                    Console.WriteLine(num + ": " + line);
                    num++;
                }
            }
        }

        static void LireTableau(string path)
        {
            string[] lignes = File.ReadAllLines(path);
            Console.WriteLine("Total lignes: " + lignes.Length);
        }

        static void TestBinaire(string path)
        {
            using (BinaryWriter bw = new BinaryWriter(File.Open(path, FileMode.Create)))
            {
                bw.Write(123);
                bw.Write(3.14);
                bw.Write("ok");
            }
            int i;
            double d;
            string s;
            using (BinaryReader br = new BinaryReader(File.Open(path, FileMode.Open)))
            {
                i = br.ReadInt32();
                d = br.ReadDouble();
                s = br.ReadString();
            }
            Console.WriteLine("int=" + i + " double=" + d + " chaine=" + s);
        }

        static void Main()
        {
            string txt = "test35_text.txt";
            string bin = "test35_bin.dat";

            Console.WriteLine("--- Ecriture ligne par ligne ---");
            EcrireLignes(txt);

            Console.WriteLine("--- Lecture ligne par ligne ---");
            LireLignes(txt);

            Console.WriteLine("--- Lecture tableau ---");
            LireTableau(txt);

            Console.WriteLine("--- Binaire ---");
            TestBinaire(bin);

            File.Delete(txt);
            File.Delete(bin);

            Console.WriteLine("Test fichier flux OK");
        }
    }
}
