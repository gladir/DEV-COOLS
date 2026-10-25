import java.util.*;

public class Test18_Scelle {
    sealed interface Shape permits Circle, Square, Rect {}
    record Circle(double r) implements Shape {}
    record Square(double s) implements Shape {}
    record Rect(double w, double h) implements Shape {}

    sealed interface Expr {}
    record Num(int v) implements Expr {}
    record Add(Expr l, Expr r) implements Expr {}
    record Mul(Expr l, Expr r) implements Expr {}
    record Neg(Expr e) implements Expr {}

    sealed static abstract class Animal permits Dog, Cat {}
    static final class Dog extends Animal {}
    static non-sealed class Cat extends Animal {}
    static class Lion extends Cat {}

    enum Color { RED, GREEN, BLUE }
    sealed interface Opt<T> permits Some, None {}
    record Some<T>(T v) implements Opt<T> {}
    record None<T>() implements Opt<T> {}
    record Pair(Shape a, Shape b) {}

    static double area(Shape s) {
        return switch (s) {
            case Circle c -> Math.PI * c.r() * c.r();
            case Square q -> q.s() * q.s();
            case Rect(double w, double h) -> w * h;
        };
    }
    static int eval(Expr e) {
        return switch (e) {
            case Num n -> n.v();
            case Add(Expr l, Expr r) -> eval(l) + eval(r);
            case Mul(Num(var a), Num(var b)) -> a * b;
            case Mul(Expr l, Expr r) -> eval(l) * eval(r);
            case Neg(var x) -> -eval(x);
        };
    }
    static String animal(Animal a) {
        switch (a) {
            case Dog d -> { return "dog"; }
            case Cat c -> { return "cat"; }
        }
    }
    static String color(Color c) {
        return switch (c) { case RED -> "r"; case GREEN -> "g"; case BLUE -> "b"; };
    }
    static <T> String opt(Opt<T> o) {
        return switch (o) { case Some<T>(var v) -> "some " + v; case None<T> n -> "none"; };
    }
    static String pair(Pair p) {
        return switch (p) {
            case Pair(Circle a, Shape b) -> "c*";
            case Pair(Square a, Circle b) -> "sc";
            case Pair(Square a, Square b) -> "ss";
            case Pair(Square a, Rect b) -> "sr";
            case Pair(Rect a, Shape b) -> "r*";
        };
    }
    static String obj(Object o) {
        return switch (o) {
            case null -> "null";
            case String s when s.length() > 3 -> "long " + s;
            case String s -> "str " + s;
            case Integer i -> "int " + i;
            default -> "other";
        };
    }
    public static void main(String[] args) {
        System.out.println(area(new Circle(1)) + " " + area(new Square(2)) + " " + area(new Rect(2, 3)));
        System.out.println(eval(new Add(new Num(2), new Mul(new Num(3), new Neg(new Num(4))))) + " " + eval(new Mul(new Num(5), new Num(6))));
        System.out.println(animal(new Dog()) + animal(new Lion()));
        System.out.println(color(Color.GREEN) + opt(new Some<>(5)) + opt(new None<String>()));
        System.out.println(pair(new Pair(new Square(1), new Rect(1, 1))) + pair(new Pair(new Rect(1,1), new Circle(1))));
        System.out.println(obj(null) + obj("abcd") + obj("ab") + obj(7) + obj(1.5));
        for (Class<?> c : new Class<?>[]{Shape.class, Animal.class, Expr.class, Dog.class})
            System.out.println(c.getSimpleName() + " " + c.isSealed() + " " + (c.isSealed() ? Arrays.stream(c.getPermittedSubclasses()).map(Class::getSimpleName).toList() : ""));
    }
}
