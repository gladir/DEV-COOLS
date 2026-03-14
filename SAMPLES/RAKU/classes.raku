# classes.raku - class, has, method, new, heritage, .isa

# Classe de base
class Animal {
    has $.name;
    has $.legs;

    method speak() {
        say "...";
    }

    method info() {
        say $.name;
        say $.legs;
    }
}

# Classe derivee (heritage)
class Dog is Animal {
    method speak() {
        say "Woof!";
    }
}

class Cat is Animal {
    method speak() {
        say "Meow!";
    }
}

# Instanciation
my $rex = Dog.new(name => "Rex", legs => 4);
$rex.speak();
$rex.info();
say $rex.name;

my $mimi = Cat.new(name => "Mimi", legs => 4);
$mimi.speak();

# Test .isa
say $rex.isa(Dog);
say $rex.isa(Animal);
