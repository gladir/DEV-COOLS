// test40_calendar.cs - Calendrier gregorien
// Calcule la duree des mois, les annees bissextiles et le jour
// de la semaine via l algorithme de Zeller. Affiche ensuite le
// calendrier complet d un mois (Janvier 2026).
//
// Sortie attendue :
// --- Annees bissextiles ---
// 2000 bissextile
// 2024 bissextile
// 1900 commune
// 2100 commune
// 2400 bissextile
// --- Jours par mois (2024) ---
// 01:31 02:29 03:31 04:30 05:31 06:30 07:31 08:31 09:30 10:31 11:30 12:31
// --- Zeller jour de la semaine ---
// 2026-04-22=Mercredi
// 2000-01-01=Samedi
// 1969-07-20=Dimanche
// --- Calendrier Janvier 2026 ---
// Lu Ma Me Je Ve Sa Di
//           1  2  3  4
//  5  6  7  8  9 10 11
// 12 13 14 15 16 17 18
// 19 20 21 22 23 24 25
// 26 27 28 29 30 31
// Test calendrier OK

using System;

namespace Test40
{
    class Program
    {
        // Regle gregorienne : divisible par 4, sauf si divisible par 100
        // mais pas par 400.
        static bool EstBissextile(int annee)
        {
            if (annee % 400 == 0) return true;
            if (annee % 100 == 0) return false;
            if (annee % 4 == 0) return true;
            return false;
        }

        static int JoursDansMois(int annee, int mois)
        {
            int[] jours = new int[] {
                31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31
            };
            if (mois == 2 && EstBissextile(annee)) return 29;
            return jours[mois - 1];
        }

        // Formule de Zeller. Retourne 0=Lundi ... 6=Dimanche.
        static int Zeller(int jour, int mois, int annee)
        {
            // Janvier et fevrier sont traites comme mois 13 et 14 de l annee precedente
            int m = mois;
            int y = annee;
            if (m < 3)
            {
                m = m + 12;
                y = y - 1;
            }
            int K = y % 100;
            int J = y / 100;
            // Formule : h = (q + 13*(m+1)/5 + K + K/4 + J/4 + 5*J) mod 7
            // h=0 samedi, 1 dimanche, ... 6 vendredi
            int h = (jour + (13 * (m + 1)) / 5 + K + K / 4 + J / 4 + 5 * J) % 7;
            // Conversion vers 0=Lundi ... 6=Dimanche
            // Zeller : sat=0 sun=1 mon=2 tue=3 wed=4 thu=5 fri=6
            // Cible  : mon=0 tue=1 wed=2 thu=3 fri=4 sat=5 sun=6
            int[] conv = new int[] { 5, 6, 0, 1, 2, 3, 4 };
            return conv[h];
        }

        static string NomJour(int idx)
        {
            string[] n = new string[] {
                "Lundi", "Mardi", "Mercredi", "Jeudi",
                "Vendredi", "Samedi", "Dimanche"
            };
            return n[idx];
        }

        static string Pad2(int n)
        {
            if (n < 10) return "0" + n;
            return "" + n;
        }

        static string Pad2Sp(int n)
        {
            if (n < 10) return " " + n;
            return "" + n;
        }

        static void AfficherMois(int annee, int mois)
        {
            Console.WriteLine("Lu Ma Me Je Ve Sa Di");
            int premier = Zeller(1, mois, annee);
            int nb = JoursDansMois(annee, mois);
            string ligne = "";
            // Padding avant le 1er jour
            for (int i = 0; i < premier; i++)
            {
                ligne = ligne + "   ";
            }
            int colonne = premier;
            for (int j = 1; j <= nb; j++)
            {
                ligne = ligne + Pad2Sp(j);
                colonne++;
                if (colonne == 7)
                {
                    Console.WriteLine(ligne);
                    ligne = "";
                    colonne = 0;
                }
                else
                {
                    ligne = ligne + " ";
                }
            }
            if (ligne.Length > 0)
            {
                // Retirer l espace terminal eventuel
                Console.WriteLine(ligne.TrimEnd());
            }
        }

        static void Main()
        {
            Console.WriteLine("--- Annees bissextiles ---");
            int[] annees = new int[] { 2000, 2024, 1900, 2100, 2400 };
            for (int i = 0; i < annees.Length; i++)
            {
                if (EstBissextile(annees[i]))
                {
                    Console.WriteLine(annees[i] + " bissextile");
                }
                else
                {
                    Console.WriteLine(annees[i] + " commune");
                }
            }

            Console.WriteLine("--- Jours par mois (2024) ---");
            string s = "";
            for (int m = 1; m <= 12; m++)
            {
                if (m > 1) s = s + " ";
                s = s + Pad2(m) + ":" + JoursDansMois(2024, m);
            }
            Console.WriteLine(s);

            Console.WriteLine("--- Zeller jour de la semaine ---");
            Console.WriteLine("2026-04-22=" + NomJour(Zeller(22, 4, 2026)));
            Console.WriteLine("2000-01-01=" + NomJour(Zeller(1, 1, 2000)));
            Console.WriteLine("1969-07-20=" + NomJour(Zeller(20, 7, 1969)));

            Console.WriteLine("--- Calendrier Janvier 2026 ---");
            AfficherMois(2026, 1);

            Console.WriteLine("Test calendrier OK");
        }
    }
}
