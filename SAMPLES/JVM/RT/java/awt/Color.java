package java.awt;
public class Color implements java.io.Serializable {
    public static final Color white = new Color(255, 255, 255);
    public static final Color WHITE = white;
    public static final Color lightGray = new Color(192, 192, 192);
    public static final Color LIGHT_GRAY = lightGray;
    public static final Color gray = new Color(128, 128, 128);
    public static final Color GRAY = gray;
    public static final Color darkGray = new Color(64, 64, 64);
    public static final Color DARK_GRAY = darkGray;
    public static final Color black = new Color(0, 0, 0);
    public static final Color BLACK = black;
    public static final Color red = new Color(255, 0, 0);
    public static final Color RED = red;
    public static final Color pink = new Color(255, 175, 175);
    public static final Color PINK = pink;
    public static final Color orange = new Color(255, 200, 0);
    public static final Color ORANGE = orange;
    public static final Color yellow = new Color(255, 255, 0);
    public static final Color YELLOW = yellow;
    public static final Color green = new Color(0, 255, 0);
    public static final Color GREEN = green;
    public static final Color magenta = new Color(255, 0, 255);
    public static final Color MAGENTA = magenta;
    public static final Color cyan = new Color(0, 255, 255);
    public static final Color CYAN = cyan;
    public static final Color blue = new Color(0, 0, 255);
    public static final Color BLUE = blue;
    int value;
    public Color(int r, int g, int b) { this(r, g, b, 255); }
    public Color(int r, int g, int b, int a) {
        value = ((a & 0xFF) << 24) | ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF);
        testColorValueRange(r, g, b, a);
    }
    public Color(int rgb) { value = 0xff000000 | rgb; }
    public Color(int rgba, boolean hasalpha) { value = hasalpha ? rgba : (0xff000000 | rgba); }
    public Color(float r, float g, float b) { this((int) (r * 255 + 0.5), (int) (g * 255 + 0.5), (int) (b * 255 + 0.5)); }
    public Color(float r, float g, float b, float a) { this((int) (r * 255 + 0.5), (int) (g * 255 + 0.5), (int) (b * 255 + 0.5), (int) (a * 255 + 0.5)); }
    private static void testColorValueRange(int r, int g, int b, int a) {
        boolean rangeError = false;
        String badComponentString = "";
        if (a < 0 || a > 255) { rangeError = true; badComponentString += " Alpha"; }
        if (r < 0 || r > 255) { rangeError = true; badComponentString += " Red"; }
        if (g < 0 || g > 255) { rangeError = true; badComponentString += " Green"; }
        if (b < 0 || b > 255) { rangeError = true; badComponentString += " Blue"; }
        if (rangeError) throw new IllegalArgumentException("Color parameter outside of expected range:" + badComponentString);
    }
    public int getRed() { return (value >> 16) & 0xFF; }
    public int getGreen() { return (value >> 8) & 0xFF; }
    public int getBlue() { return value & 0xFF; }
    public int getAlpha() { return (value >> 24) & 0xff; }
    public int getRGB() { return value; }
    public Color brighter() {
        int r = getRed(), g = getGreen(), b = getBlue();
        int i = (int) (1.0 / (1.0 - 0.7));
        if (r == 0 && g == 0 && b == 0) return new Color(i, i, i);
        if (r > 0 && r < i) r = i;
        if (g > 0 && g < i) g = i;
        if (b > 0 && b < i) b = i;
        return new Color(Math.min((int) (r / 0.7), 255), Math.min((int) (g / 0.7), 255), Math.min((int) (b / 0.7), 255));
    }
    public Color darker() { return new Color(Math.max((int) (getRed() * 0.7), 0), Math.max((int) (getGreen() * 0.7), 0), Math.max((int) (getBlue() * 0.7), 0)); }
    public int hashCode() { return value; }
    public boolean equals(Object obj) { return obj instanceof Color && ((Color) obj).value == this.value; }
    public String toString() { return getClass().getName() + "[r=" + getRed() + ",g=" + getGreen() + ",b=" + getBlue() + "]"; }
    public static Color decode(String nm) throws NumberFormatException { int i = Integer.decode(nm); return new Color((i >> 16) & 0xFF, (i >> 8) & 0xFF, i & 0xFF); }
    public static int HSBtoRGB(float hue, float saturation, float brightness) {
        int r = 0, g = 0, b = 0;
        if (saturation == 0) { r = g = b = (int) (brightness * 255.0f + 0.5f); }
        else {
            float h = (hue - (float) Math.floor(hue)) * 6.0f;
            float f = h - (float) Math.floor(h);
            float p = brightness * (1.0f - saturation);
            float q = brightness * (1.0f - saturation * f);
            float t = brightness * (1.0f - (saturation * (1.0f - f)));
            switch ((int) h) {
                case 0: r = (int) (brightness * 255.0f + 0.5f); g = (int) (t * 255.0f + 0.5f); b = (int) (p * 255.0f + 0.5f); break;
                case 1: r = (int) (q * 255.0f + 0.5f); g = (int) (brightness * 255.0f + 0.5f); b = (int) (p * 255.0f + 0.5f); break;
                case 2: r = (int) (p * 255.0f + 0.5f); g = (int) (brightness * 255.0f + 0.5f); b = (int) (t * 255.0f + 0.5f); break;
                case 3: r = (int) (p * 255.0f + 0.5f); g = (int) (q * 255.0f + 0.5f); b = (int) (brightness * 255.0f + 0.5f); break;
                case 4: r = (int) (t * 255.0f + 0.5f); g = (int) (p * 255.0f + 0.5f); b = (int) (brightness * 255.0f + 0.5f); break;
                case 5: r = (int) (brightness * 255.0f + 0.5f); g = (int) (p * 255.0f + 0.5f); b = (int) (q * 255.0f + 0.5f); break;
            }
        }
        return 0xff000000 | (r << 16) | (g << 8) | (b << 0);
    }
    public static float[] RGBtoHSB(int r, int g, int b, float[] hsbvals) {
        float hue, saturation, brightness;
        if (hsbvals == null) hsbvals = new float[3];
        int cmax = (r > g) ? r : g;
        if (b > cmax) cmax = b;
        int cmin = (r < g) ? r : g;
        if (b < cmin) cmin = b;
        brightness = ((float) cmax) / 255.0f;
        if (cmax != 0) saturation = ((float) (cmax - cmin)) / ((float) cmax); else saturation = 0;
        if (saturation == 0) hue = 0;
        else {
            float redc = ((float) (cmax - r)) / ((float) (cmax - cmin));
            float greenc = ((float) (cmax - g)) / ((float) (cmax - cmin));
            float bluec = ((float) (cmax - b)) / ((float) (cmax - cmin));
            if (r == cmax) hue = bluec - greenc;
            else if (g == cmax) hue = 2.0f + redc - bluec;
            else hue = 4.0f + greenc - redc;
            hue = hue / 6.0f;
            if (hue < 0) hue = hue + 1.0f;
        }
        hsbvals[0] = hue; hsbvals[1] = saturation; hsbvals[2] = brightness;
        return hsbvals;
    }
    public static Color getHSBColor(float h, float s, float b) { return new Color(HSBtoRGB(h, s, b)); }
}
