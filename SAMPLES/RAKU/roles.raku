# roles.raku - role, does, composition, conflit

# Role Printable
role Printable {
    method to_string() {
        return "Printable";
    }
}

# Role Serializable
role Serializable {
    method serialize() {
        say "serialized";
    }
}

# Classe composant un seul role
class Report does Printable {
    has $.title;

    method show() {
        say $.title;
    }
}

# Classe composant deux roles
class DataFile does Printable does Serializable {
    has $.name;

    method info() {
        say $.name;
    }
}

# Instanciation et test
my $r = Report.new(title => "Annual");
$r.show();

my $f = DataFile.new(name => "data.csv");
$f.info();
$f.serialize();

# Test .does
say $f.does(Printable);
say $f.does(Serializable);
