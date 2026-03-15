# test_classes.raku - TODO 19 test: classes et objets
class Dog {
    has $.name;
    has $.age;
    method bark() {
        say "Woof!";
    }
    method info() {
        say "Dog";
    }
}
my $d = Dog.new(name => "Rex", age => 5);
$d.bark();
$d.info();
say $d.name;
say "done";
