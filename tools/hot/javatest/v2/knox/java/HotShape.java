package knox.java;

/** Its make-up changes in version 2 (a method added): plain Java can't swap that. */
public class HotShape {
    public static String a() {
        return "a" + b();
    }

    public static String b() {
        return "2";
    }
}
