# test_roles.raku - TODO 20 test: roles (role, does)

# Role simple avec attribut et methode
role Greet {
    has $.greeting;
    method greet() {
        say "Hello!";
    }
}

# Role avec methode requise (stub)
role Printable {
    method to-string;
}

# Classe composant un role
class Person does Greet {
    has $.name;
    method info() {
        say "Person";
    }
}

# Classe composant plusieurs roles
class Document does Greet does Printable {
    has $.title;
    method to-string() {
        say "Doc";
    }
}

# Instanciation et appel de methodes du role
my $p = Person.new(name => "Alice");
$p.greet();
$p.info();
say $p.name;

my $d = Document.new(title => "Test");
$d.greet();
$d.to-string();
say $d.title;

# Test .does()
say $p.does(Greet);
say $d.does(Printable);

say "done";
