package knox.java;

import static org.lwjgl.opengl.GL33.*;

import java.nio.ByteBuffer;

import org.lwjgl.BufferUtils;

/**
 * The menu's scenes change by a swipe (the author, 2026-11-02): the old one taken as a picture
 * before the menu's items are drawn over it, the new one read back as it is drawn, both put on
 * the screen side by side, the seam between them soft. Any scene, nothing of theirs to change; the
 * items stay where they are. No state of the game's but what's handed back. Render thread.
 */
public final class KnoxMenuSwipe {
    private static int width, height, oldFbo, oldTex, newFbo, newTex;
    private static boolean failed;
    private static final int[] VIEW = new int[4];
    private static final ByteBuffer MASK = BufferUtils.createByteBuffer(16);
    private static int program, vao, uK, uDir, uSoft, uBlur;
    // how far the scenes dissolve into each other each way, of the screen's width (the author, 2026-11-02:
    // the dark at the seam was no better; a little wider than the 0.06 that read as sharp)
    private static final float SOFT = 0.08f;
    // (the pictures mirrored past their edges: under the seam each has something to show, no streak)
    private static final String VERT = "#version 330 core\nout vec2 vUv;\nvoid main() {\n"
        + "    vec2 p = vec2((gl_VertexID & 1) * 4.0 - 1.0, (gl_VertexID & 2) * 2.0 - 1.0);\n"
        + "    vUv = p * 0.5 + 0.5;\n    gl_Position = vec4(p, 0.0, 1.0);\n}\n";
    private static final String FRAG = "#version 330 core\nin vec2 vUv;\nout vec4 color;\n"
        + "uniform sampler2D uOld;\nuniform sampler2D uNew;\nuniform float uK, uDir, uSoft, uBlur;\n"
        + "vec3 at(float x) {\n"
        + "    float n = uDir * (1.0 - uK);\n"
        + "    float seam = uDir > 0.0 ? n : 1.0 + n;\n"
        + "    float a = smoothstep(-uSoft, uSoft, (x - seam) * uDir);\n"
        + "    return mix(texture(uOld, vec2(x - n + uDir, vUv.y)).rgb, texture(uNew, vec2(x - n, vUv.y)).rgb, a);\n}\n"
        // the motion blur (the author, 2026-11-02): along the way, a pixel's own shift of the samples so they make no bands
        + "void main() {\n"
        + "    vec3 c = vec3(0.0);\n"
        + "    float shift = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));\n"
        + "    for (int i = 0; i < 20; i++) c += at(vUv.x + ((float(i) + shift) / 20.0 - 0.5) * uBlur);\n"
        + "    color = vec4(c / 20.0, 1.0);\n}\n";

    private KnoxMenuSwipe() {
    }

    /** A blit that didn't go (a target it can't be done on): the Lua falls back on the dark. */
    public static boolean failed() {
        return failed;
    }

    /** What's on the target now is one of the scenes: coming (or the one going, if not), kept. */
    public static void take(boolean coming) {
        run(-1f, 0, coming, 0f);
    }

    /**
     * What's on the target now is the other scene, kept too; both go up, the one coming `k` of
     * the way in, 0..1. dir 1: from the right, the old one leaves to the left; -1: the other way.
     * blur: how far the motion blur reaches, of the screen's width.
     */
    public static void draw(float k, int dir, boolean coming, float blur) {
        run(k, dir, coming, blur);
    }

    private static void run(float k, int dir, boolean coming, float blur) {
        if (failed) return;
        // (no OpenGL 3.3, a Mac: not one call of it, the state given back included - 2026-11-10)
        if (KnoxBarLua.glTooOld()) {
            fail("OpenGL 3.3 is not there");
            return;
        }
        int draw =glGetInteger(GL_DRAW_FRAMEBUFFER_BINDING), read = glGetInteger(GL_READ_FRAMEBUFFER_BINDING);
        glGetIntegerv(GL_VIEWPORT, VIEW);
        int x = VIEW[0], y = VIEW[1], w = VIEW[2], h = VIEW[3];
        if (w <= 0 || h <= 0) return;   // (the window minimised)
        boolean scissor = glIsEnabled(GL_SCISSOR_TEST), srgb = glIsEnabled(GL_FRAMEBUFFER_SRGB);
        boolean blend = glIsEnabled(GL_BLEND), depth = glIsEnabled(GL_DEPTH_TEST), cull = glIsEnabled(GL_CULL_FACE);
        boolean stencil = glIsEnabled(GL_STENCIL_TEST), alpha = glIsEnabled(org.lwjgl.opengl.GL11.GL_ALPHA_TEST);
        int usedProgram = glGetInteger(GL_CURRENT_PROGRAM), usedVao = glGetInteger(GL_VERTEX_ARRAY_BINDING);
        int active = glGetInteger(GL_ACTIVE_TEXTURE);
        glGetBooleanv(GL_COLOR_WRITEMASK, MASK);
        try {
            while (glGetError() != GL_NO_ERROR) {
                // (not ours)
            }
            glDisable(GL_SCISSOR_TEST);
            glDisable(GL_FRAMEBUFFER_SRGB);
            glColorMask(true, true, true, true);
            if (w != width || h != height || oldFbo == 0) build(w, h);
            copy(draw, coming ? newFbo : oldFbo, x, y, w, h, 0, 0);
            if (k >= 0f) {
                glBindFramebuffer(GL_DRAW_FRAMEBUFFER, draw);
                glBindFramebuffer(GL_READ_FRAMEBUFFER, read);
                glDisable(GL_BLEND);
                glDisable(GL_DEPTH_TEST);
                glDisable(GL_CULL_FACE);
                glDisable(GL_STENCIL_TEST);
                glDisable(org.lwjgl.opengl.GL11.GL_ALPHA_TEST);
                if (program == 0) buildProgram();
                glUseProgram(program);
                glBindVertexArray(vao);
                glActiveTexture(GL_TEXTURE14);
                glBindTexture(GL_TEXTURE_2D, oldTex);
                glActiveTexture(GL_TEXTURE15);
                glBindTexture(GL_TEXTURE_2D, newTex);
                glUniform1f(uK, k);
                glUniform1f(uDir, dir);
                glUniform1f(uBlur, blur);
                // (none at the very ends: each picture whole on the screen)
                glUniform1f(uSoft, Math.max(0.0001f, SOFT * Math.min(1f, Math.min(k, 1f - k) * 5f)));
                glDrawArrays(GL_TRIANGLES, 0, 3);
                glBindTexture(GL_TEXTURE_2D, 0);
                glActiveTexture(GL_TEXTURE14);
                glBindTexture(GL_TEXTURE_2D, 0);
            }
            if (glGetError() != GL_NO_ERROR) fail("a blit refused");
        } catch (Throwable t) {
            fail(String.valueOf(t));
        }
        glActiveTexture(active);
        glUseProgram(usedProgram);
        glBindVertexArray(usedVao);
        if (blend) glEnable(GL_BLEND);
        if (depth) glEnable(GL_DEPTH_TEST);
        if (cull) glEnable(GL_CULL_FACE);
        if (stencil) glEnable(GL_STENCIL_TEST);
        if (alpha) glEnable(org.lwjgl.opengl.GL11.GL_ALPHA_TEST);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, draw);
        glBindFramebuffer(GL_READ_FRAMEBUFFER, read);
        glColorMask(MASK.get(0) != 0, MASK.get(1) != 0, MASK.get(2) != 0, MASK.get(3) != 0);
        if (scissor) glEnable(GL_SCISSOR_TEST);
        if (srgb) glEnable(GL_FRAMEBUFFER_SRGB);
    }

    private static void fail(String why) {
        failed = true;
        System.out.println("[Knox] the menu's swipe: " + why);
    }

    private static void copy(int from, int to, int x, int y, int w, int h, int toX, int toY) {
        glBindFramebuffer(GL_READ_FRAMEBUFFER, from);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, to);
        glBlitFramebuffer(x, y, x + w, y + h, toX, toY, toX + w, toY + h, GL_COLOR_BUFFER_BIT, GL_NEAREST);
    }

    private static int shader(int type, String text) {
        int s = glCreateShader(type);
        glShaderSource(s, text);
        glCompileShader(s);
        if (glGetShaderi(s, GL_COMPILE_STATUS) == 0) throw new IllegalStateException(glGetShaderInfoLog(s));
        return s;
    }

    private static void buildProgram() {
        int v = shader(GL_VERTEX_SHADER, VERT), f = shader(GL_FRAGMENT_SHADER, FRAG);
        int p = glCreateProgram();
        glAttachShader(p, v);
        glAttachShader(p, f);
        glLinkProgram(p);
        glDeleteShader(v);
        glDeleteShader(f);
        if (glGetProgrami(p, GL_LINK_STATUS) == 0) throw new IllegalStateException(glGetProgramInfoLog(p));
        // (points made from gl_VertexID, the game's context a compatibility one: with no array enabled
        // a draw may draw nothing on AMD and Intel under Mesa - as KnoxBarFrame's noMeshVao)
        int buffer = glGetInteger(GL_ARRAY_BUFFER_BINDING);
        vao = glGenVertexArrays();
        glBindVertexArray(vao);
        glBindBuffer(GL_ARRAY_BUFFER, glGenBuffers());
        glBufferData(GL_ARRAY_BUFFER, 12L, GL_STATIC_DRAW);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 1, GL_FLOAT, false, 0, 0);
        glBindBuffer(GL_ARRAY_BUFFER, buffer);
        glUseProgram(p);
        glUniform1i(glGetUniformLocation(p, "uOld"), 14);
        glUniform1i(glGetUniformLocation(p, "uNew"), 15);
        uK = glGetUniformLocation(p, "uK");
        uDir = glGetUniformLocation(p, "uDir");
        uSoft = glGetUniformLocation(p, "uSoft");
        uBlur = glGetUniformLocation(p, "uBlur");
        program = p;
    }

    private static void build(int w, int h) {
        free();
        width = w;
        height = h;
        oldTex = picture(w, h);
        oldFbo = target(oldTex);
        newTex = picture(w, h);
        newFbo = target(newTex);
    }

    private static int picture(int w, int h) {
        int active = glGetInteger(GL_TEXTURE_BINDING_2D);
        int tex = glGenTextures();
        glBindTexture(GL_TEXTURE_2D, tex);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, (ByteBuffer) null);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_MIRRORED_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glBindTexture(GL_TEXTURE_2D, active);
        return tex;
    }

    private static int target(int tex) {
        int fbo = glGenFramebuffers();
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, fbo);
        glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex, 0);
        if (glCheckFramebufferStatus(GL_DRAW_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) throw new IllegalStateException("target not complete");
        return fbo;
    }

    /** The pictures off the video card: the swipe is over. */
    public static void free() {
        if (oldFbo != 0) glDeleteFramebuffers(oldFbo);
        if (newFbo != 0) glDeleteFramebuffers(newFbo);
        if (oldTex != 0) glDeleteTextures(oldTex);
        if (newTex != 0) glDeleteTextures(newTex);
        oldFbo = newFbo = oldTex = newTex = 0;
        width = height = 0;
    }
}
