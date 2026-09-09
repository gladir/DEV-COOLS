# dbi_sqlserver.pl - Acces a une base de donnees SQL Server via le style
# DBI (2026-09-08, demande explicite) : DBI->connect / $dbh->prepare /
# $sth->execute / $sth->fetchrow_hashref / $client->{Champ}.
#
# Connexion reelle au moteur SQL Server local de ce depot (SQLCMD.EXE /
# master.mdf), le meme moteur que l'Explorateur d'objets SQL Server, les
# cmdlets PowerShell dev SqlServer-compatibles et la forme SQL Server de
# Database.Connect en PascalScript (14_database.psc) - le DSN/utilisateur/
# mot de passe ne sont pas interpretes au-dela de cette forme (une seule
# base locale, aucun reseau reel). Table "ClientsDemo" deja creee pour
# l'exemple PascalScript equivalent - voir SAMPLES\PASCALSCRIPT\README.TXT.
#
# Portee honnetement disclosee (voir le commentaire d'en-tete du bloc DBI
# dans DEVENV.PAS) : fetchrow_array/fetchall_arrayref, les parametres lies,
# les transactions et $DBI::errstr/$sth->errstr ne sont PAS implementes -
# seules les 6 methodes utilisees ci-dessous le sont. L'idiome Perl
# "... or die $DBI::errstr" n'est pas evalue par ce moteur (aucun support
# du mot "or"/"and" au niveau expression) - remplace ici par un test
# explicite "if (!$dbh) { die ... }" comme instruction separee. De meme,
# q{...} multi-ligne n'est pas supporte - le SQL tient sur une seule ligne
# physique, comme toute instruction de ce moteur Perl.

use strict;
use warnings;

my $serveur = 'MONSERVEUR';
my $base = 'MaBase';
my $user = 'mon_user';
my $password = 'mon_mot_de_passe';

my $dsn = "DBI:ODBC:Driver={ODBC Driver 18 for SQL Server};Server=$serveur;Database=$base;";

my $dbh = DBI->connect($dsn, $user, $password, {RaiseError => 1, AutoCommit => 1});
if (!$dbh) { die "Impossible de se connecter au serveur SQL Server.\n"; }

my $sql = "SELECT Id, Nom, Prenom, Telephone, Email FROM ClientsDemo ORDER BY Nom, Prenom";
my $sth = $dbh->prepare($sql);
$sth->execute();

while (my $client = $sth->fetchrow_hashref()) {
    print "ID       : $client->{ID}\n";
    print "Nom      : $client->{NOM}\n";
    print "Prenom   : $client->{PRENOM}\n";
    print "Telephone: $client->{TELEPHONE}\n";
    print "Courriel : $client->{EMAIL}\n";
    print "-----------------------------\n";
}

$sth->finish();
$dbh->disconnect();
