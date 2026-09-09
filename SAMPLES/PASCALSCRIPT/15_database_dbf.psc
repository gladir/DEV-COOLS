{ 15_database_dbf.psc - Acces direct a un fichier dBASE (.DBF) via les     }
{ objets Database/DatabaseConnection/RecordSet (2026-09-08, demande        }
{ explicite : forme "File=xxx.DBF;..." de Database.Connect). }
{ Contrairement a 14_database.psc (qui vise le moteur SQL Server local via }
{ SQLCMD.EXE/master.mdf), cette forme ouvre REELLEMENT le fichier .DBF     }
{ indique via le meme lecteur dBASE que la Grille de donnees de l'IDE      }
{ (WK_GRID, GridOpen_Dbf/GridCellText) - "Database="/"Trusted_Connection=" }
{ sont acceptes dans la chaine pour la forme mais ne sont pas interpretes. }
{ Portee honnetement disclosee : le texte de Query n'est PAS analyse (ni   }
{ liste de colonnes, ni WHERE/ORDER BY) - une connexion File=... pointe    }
{ deja sur un seul fichier precis, donc Query renvoie toujours TOUTES ses  }
{ colonnes/lignes quel que soit le texte SQL passe. }
{ NOTE : chaque instruction tient sur UNE SEULE ligne physique, et le      }
{ "Begin" du While est sur SA PROPRE ligne - voir 14_database.psc et       }
{ 05_loops.psc pour le detail de ces deux limites reelles de l'interprete. }

Program LireClientsDbf;

Var
  Connexion: DatabaseConnection;
  Resultats: RecordSet;

BEGIN
  Connexion := Database.Connect('File=SAMPLES\DBASE\CLIENTS.DBF;Database=MaBase;Trusted_Connection=True;');

  Resultats := Connexion.Query('SELECT * FROM CLIENTS');

  While not Resultats.Eof do
  Begin
    WriteLn('ID       : ' + Resultats['ID']);
    WriteLn('Nom      : ' + Resultats['NOM']);
    WriteLn('Prenom   : ' + Resultats['PRENOM']);
    WriteLn('---------------------------');

    Resultats.Next;
  End;
  Resultats.Close;
  Connexion.Close;
END.
