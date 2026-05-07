// Hello-world probe for the Java flow.
//
// Exercised via JDK 11+'s single-file source-code launcher (JEP 330):
// `java tests/java/Hello.java` compiles and runs this file in one step,
// so no explicit `javac` build is needed. If the JDK install was
// incomplete, the launcher would fail and the harness would flag the
// flow broken.

public class Hello {
    public static void main(String[] args) {
        System.out.println("Hello, world!");
    }
}
