{ 14_database.psc - Acces a une base de donnees SQL Server via les objets }
{ Database/DatabaseConnection/RecordSet (2026-09-08, demande explicite).  }
{ Connexion reelle au moteur SQL Server local de ce depot (SQLCMD.EXE/    }
{ master.mdf, le meme moteur que l'Explorateur d'objets SQL Server et les }
{ cmdlets PowerShell dev SqlServer-compatibles) - "Server="/"Database="   }
{ dans la chaine de connexion sont acceptes pour la forme mais ne visent  }
{ qu'une seule base locale (aucun reseau reel, meme portee que Invoke-   }
{ Sqlcmd ailleurs dans ce projet). Table "ClientsDemo" creee pour cet     }
{ exemple - voir SAMPLES\PASCALSCRIPT\README.TXT. }
{ NOTE : chaque instruction tient sur UNE SEULE ligne physique (limite     }
{ reelle de cet interprete - PscExecRange traite une ligne source = une    }
{ instruction complete, pas de continuation multi-ligne) - contrairement   }
{ a la mise en forme multi-ligne de l'exemple original fourni. Idem pour   }
{ le "Begin" du While, place sur SA PROPRE ligne (voir 05_loops.psc) -     }
{ bogue reel et deja documente de cet interprete (voir memoire du         }
{ chantier PSCRIPT) : un "Begin" sur la MEME ligne que "While...Do"        }
{ n'execute jamais que la toute premiere instruction du corps a chaque     }
{ iteration, ce qui aurait bloque indefiniment sur Resultats.Next jamais    }
{ atteint. }

Program LireClients;

Var
  Connexion: DatabaseConnection;
  Resultats: RecordSet;

BEGIN
  Connexion := Database.Connect('Server=MONSERVEUR;Database=MaBase;Trusted_Connection=True;');

  Resultats := Connexion.Query('SELECT * FROM ClientsDemo');

  While not Resultats.Eof do
  Begin
    WriteLn('ID       : ' + Resultats['Id']);
    WriteLn('Nom      : ' + Resultats['Nom']);
    WriteLn('Prenom   : ' + Resultats['Prenom']);
    WriteLn('Telephone: ' + Resultats['Telephone']);
    WriteLn('Email    : ' + Resultats['Email']);
    WriteLn('---------------------------');

    Resultats.Next;
  End;
  Resultats.Close;
  Connexion.Close;
END.
