public class Test02_Classes {
    static int counter = 0;
    int id;
    String name;
    Test02_Classes(String name) { this.name = name; id = ++counter; }
    static abstract class Animal {
        protected String nm;
        Animal(String nm) { this.nm = nm; }
        abstract String sound();
        public String toString() { return nm + " says " + sound(); }
    }
    static class Dog extends Animal {
        Dog() { super("Dog"); }
        String sound() { return "woof"; }
    }
    static class Cat extends Animal {
        Cat() { super("Cat"); }
        String sound() { return "meow"; }
    }
    enum Color { RED, GREEN, BLUE; Color next() { return values()[(ordinal() + 1) % values().length]; } }
    enum Planet {
        MERCURY(3.303e+23, 2.4397e6), EARTH(5.976e+24, 6.37814e6);
        private final double mass, radius;
        Planet(double mass, double radius) { this.mass = mass; this.radius = radius; }
        double surfaceGravity() { return 6.67300E-11 * mass / (radius * radius); }
    }
    public static void main(String[] args) {
        Test02_Classes a = new Test02_Classes("x"), b = new Test02_Classes("y");
        System.out.println(a.id + " " + b.id + " " + a.name);
        Animal[] zoo = { new Dog(), new Cat() };
        for (Animal an : zoo) System.out.println(an);
        Color c = Color.RED;
        for (int i = 0; i < 4; i++) { System.out.println(c); c = c.next(); }
        System.out.println(Color.valueOf("GREEN").ordinal());
        for (Planet p : Planet.values()) System.out.printf("%s %.2f%n", p, p.surfaceGravity());
        switch (c) {
            case RED: System.out.println("r"); break;
            case GREEN: System.out.println("g"); break;
            default: System.out.println("other");
        }
        String s = "hello";
        switch (s) {
            case "hi": System.out.println(1); break;
            case "hello": System.out.println(2);
            case "x": System.out.println(3); break;
            default: System.out.println(4);
        }
        int x = 7;
        x <<= 2; x ^= 5; x >>>= 1;
        System.out.println(x);
        long big = 1L << 40;
        System.out.println(big + " " + (big >> 3) + " " + (int) big);
        double d = 10 / 4.0;
        System.out.println(d + " " + (int) d + " " + (float) d + " " + 7 % 3 + " " + -7 / 2);
        System.out.println(Integer.MAX_VALUE + 1);
        System.out.println((char) ('a' + 2));
        System.out.println("" + 1 + 2 + 'c' + 1.5f + true + null);
        label:
        for (int i = 0; i < 5; i++) {
            for (int j = 0; j < 5; j++) {
                if (j == 3) continue label;
                if (i == 3) break label;
                System.out.print(i * j + " ");
            }
        }
        System.out.println();
        try {
            int[] z = new int[2];
            z[5] = 1;
        } catch (ArrayIndexOutOfBoundsException e) {
            System.out.println("caught " + e.getMessage());
        } finally {
            System.out.println("finally");
        }
        System.out.println(tryit());
    }
    static int tryit() {
        try { return 1; } finally { System.out.println("in finally"); }
    }
}
