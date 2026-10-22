import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.MessageDigest;
import java.security.SecureRandom;

import zb.org.bouncycastle.crypto.params.Ed25519PrivateKeyParameters;
import zb.org.bouncycastle.crypto.params.Ed25519PublicKeyParameters;
import zb.org.bouncycastle.crypto.signers.Ed25519Signer;

/**
 * Signs KnoxInventoryJava.jar for ZombieBuddy (players asked for a signed jar:
 * ZombieBuddy warns about unsigned Java mods - 2026-10-19).
 *
 * ZombieBuddy (ZBSVerifier) looks for "<jar>.zbs" next to the jar:
 *     ZBS
 *     SteamID64:<the Workshop item's uploader>
 *     Signature:<Ed25519 of "ZBS:<SteamID64>:<sha256 of the jar, lowercase hex>", 128 hex>
 * and checks it with the public key the author put on their Steam profile, in
 * the summary: "JavaModZBS:<64 hex>".
 *
 *   java -cp ZombieBuddy.jar;. KnoxSign keygen <private key file>
 *       a new key pair; the private key (hex) goes into the file, which must
 *       never be uploaded; the public key is printed - for the Steam profile
 *   java -cp ZombieBuddy.jar;. KnoxSign sign <private key file> <jar> <SteamID64>
 *       writes <jar>.zbs
 */
public class KnoxSign {

    public static void main(String[] args) throws Exception {
        if (args.length >= 2 && "keygen".equals(args[0])) {
            keygen(Paths.get(args[1]));
        } else if (args.length >= 4 && "sign".equals(args[0])) {
            sign(Paths.get(args[1]), Paths.get(args[2]), args[3]);
        } else {
            System.err.println("usage: keygen <key file> | sign <key file> <jar> <SteamID64>");
            System.exit(2);
        }
    }

    static void keygen(Path keyFile) throws IOException {
        if (Files.exists(keyFile)) {
            System.err.println("key file exists, not overwritten: " + keyFile);
            System.exit(1);
        }
        Ed25519PrivateKeyParameters priv = new Ed25519PrivateKeyParameters(new SecureRandom());
        Files.createDirectories(keyFile.toAbsolutePath().getParent());
        Files.write(keyFile, (hex(priv.getEncoded()) + "\n").getBytes(StandardCharsets.UTF_8));
        System.out.println("JavaModZBS:" + hex(priv.generatePublicKey().getEncoded()));
    }

    static void sign(Path keyFile, Path jar, String steamId) throws Exception {
        if (!steamId.matches("\\d{17}")) throw new IllegalArgumentException("SteamID64 must be 17 digits");
        byte[] raw = unhex(new String(Files.readAllBytes(keyFile), StandardCharsets.UTF_8).trim());
        Ed25519PrivateKeyParameters priv = new Ed25519PrivateKeyParameters(raw, 0);
        String hash = hex(MessageDigest.getInstance("SHA-256").digest(Files.readAllBytes(jar)));
        byte[] msg = ("ZBS:" + steamId + ":" + hash).getBytes(StandardCharsets.UTF_8);
        Ed25519Signer signer = new Ed25519Signer();
        signer.init(true, priv);
        signer.update(msg, 0, msg.length);
        byte[] sig = signer.generateSignature();
        // check it the way ZombieBuddy will
        Ed25519PublicKeyParameters pub = priv.generatePublicKey();
        Ed25519Signer check = new Ed25519Signer();
        check.init(false, pub);
        check.update(msg, 0, msg.length);
        if (!check.verifySignature(sig)) throw new IllegalStateException("signature does not verify");
        Path zbs = jar.resolveSibling(jar.getFileName().toString() + ".zbs");
        String text = "ZBS\nSteamID64:" + steamId + "\nSignature:" + hex(sig) + "\n";
        Files.write(zbs, text.getBytes(StandardCharsets.UTF_8));
        System.out.println("signed " + jar.getFileName() + " (sha256 " + hash + "), key JavaModZBS:" + hex(pub.getEncoded()));
    }

    static String hex(byte[] b) {
        StringBuilder s = new StringBuilder();
        for (byte x : b) s.append(String.format("%02x", x & 0xff));
        return s.toString();
    }

    static byte[] unhex(String h) {
        byte[] out = new byte[h.length() / 2];
        for (int i = 0; i < out.length; i++) out[i] = (byte) Integer.parseInt(h.substring(i * 2, i * 2 + 2), 16);
        return out;
    }
}
