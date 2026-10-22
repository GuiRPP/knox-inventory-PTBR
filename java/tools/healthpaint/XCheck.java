import java.util.EnumSet;

import jassimp.AiBone;
import jassimp.AiMesh;
import jassimp.AiPostProcessSteps;
import jassimp.AiScene;
import jassimp.Jassimp;

/**
 * Loads .x files with the game's own importer (assimp, jassimp64.dll from the game
 * folder) and prints what it finds: meshes, vertices, faces, bones and their weights.
 * A model the importer refuses here is refused in the game too.
 *   java -cp projectzomboid.jar XCheck.java <gameDir> file.x ...
 */
public class XCheck {
    public static void main(String[] a) throws Exception {
        // (the library loads by its own loader, from -Djava.library.path=<gameDir>: a
        // System.load from this source-launched class binds it to the wrong class loader)
        for (int i = 1; i < a.length; i++) {
            AiScene s = Jassimp.importFile(a[i], EnumSet.of(AiPostProcessSteps.TRIANGULATE));
            if (s == null) { System.out.println("FAIL " + a[i] + ": " + Jassimp.getErrorString()); continue; }
            System.out.println(a[i]);
            for (AiMesh m : s.getMeshes()) {
                int w = 0;
                for (AiBone b : m.getBones()) w += b.getNumWeights();
                System.out.printf("  mesh %s: %d vertices, %d faces, %d bones, %d weights, uv %d%n",
                    m.getName(), m.getNumVertices(), m.getNumFaces(), m.getBones().size(), w, m.getNumUVComponents(0));
                StringBuilder sb = new StringBuilder("  bones:");
                for (AiBone b : m.getBones()) sb.append(' ').append(b.getName()).append('(').append(b.getNumWeights()).append(')');
                System.out.println(sb);
            }
            System.out.println("  animations: " + s.getAnimations().size());
        }
    }
}
