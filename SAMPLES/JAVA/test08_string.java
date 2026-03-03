public class test08_string {
    public static void main(String[] args) {
        String s;
        String t;
        String u;

        s = "Bonjour";
        t = " monde";
        u = s + t;
        System.out.println(u);

        System.out.println("Longueur : " + s);

        s = "Java" + " " + "Lite";
        System.out.println(s);

        System.out.println("Entrez un texte :");
        t = Scanner.nextLine();
        System.out.println(t);
    }
}
