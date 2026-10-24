import java.util.*;
public class Test40_RefMethodeSurcharge {
    static class Item { String h; Item(String h) { this.h = h; } String getHolder() { return h; } String getUrl() { return "u" + h; } }
    public static void main(String[] args) {
        Comparator<Item> base = (a, b) -> a.h.compareTo(b.h);
        Comparator<Item> c = base.thenComparing(Item::getHolder).thenComparing(Item::getUrl);
        List<Item> l = new ArrayList<>(List.of(new Item("b"), new Item("a")));
        l.sort(c);
        System.out.println(l.get(0).h);
    }
}
