# The game's animation clips (media/anims_X/Bob/*.x, text) read and put together for the winter
# bar's heroes (2026-10-31): a clip for sitting and smoking the game hasn't got as one - the
# game layers two at run time - and the bones' places for the frame's stand-ins: a hero's
# shadow in the light and the harness's mannequin (tools\barframe, without the game).
import math, re, os

GAME = r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\media\anims_X\Bob"


def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def quat_mat(q):
    w, x, y, z = q
    return [[1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y), 0],
            [2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x), 0],
            [2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y), 0],
            [0, 0, 0, 1]]


def invert_rigid(m):
    # (rotation and translation only: what the skeleton's local matrices are)
    r = [[m[j][i] for j in range(3)] for i in range(3)]
    t = [-sum(r[i][k] * m[k][3] for k in range(3)) for i in range(3)]
    return [r[0] + [t[0]], r[1] + [t[1]], r[2] + [t[2]], [0, 0, 0, 1]]


def mat_quat(m):
    tr = m[0][0] + m[1][1] + m[2][2]
    if tr > 0:
        s = math.sqrt(tr + 1) * 2
        return ((0.25 * s), (m[2][1] - m[1][2]) / s, (m[0][2] - m[2][0]) / s, (m[1][0] - m[0][1]) / s)
    if m[0][0] > m[1][1] and m[0][0] > m[2][2]:
        s = math.sqrt(1 + m[0][0] - m[1][1] - m[2][2]) * 2
        return ((m[2][1] - m[1][2]) / s, 0.25 * s, (m[0][1] + m[1][0]) / s, (m[0][2] + m[2][0]) / s)
    if m[1][1] > m[2][2]:
        s = math.sqrt(1 + m[1][1] - m[0][0] - m[2][2]) * 2
        return ((m[0][2] - m[2][0]) / s, (m[0][1] + m[1][0]) / s, 0.25 * s, (m[1][2] + m[2][1]) / s)
    s = math.sqrt(1 + m[2][2] - m[0][0] - m[1][1]) * 2
    return ((m[1][0] - m[0][1]) / s, (m[0][2] + m[2][0]) / s, (m[1][2] + m[2][1]) / s, 0.25 * s)


class Clip:
    def __init__(self, name):
        self.name = name
        self.path = os.path.join(GAME, name + ".x")
        text = open(self.path, encoding="latin-1").read()
        self.text = text
        self.parent, self.rest = {}, {}
        self.keys = {}
        self.read_frames(text)
        self.read_anim(text)
        self.ticks = max(max(k[0] for k in v[c]) for v in self.keys.values() for c in "SRT" if v.get(c))

    def read_frames(self, text):
        stack = []
        depth = 0
        body = text[text.index(chr(10) + "Frame "):text.rindex(chr(10) + "AnimationSet ")]
        for m in re.finditer(r"Frame (\w+) \{|FrameTransformMatrix \{\s*([^}]*?)\}|Mesh [^{]*\{|\{|\}", body):
            s = m.group(0)
            if s.startswith("Frame ") and m.group(1):
                self.parent[m.group(1)] = stack[-1][0] if stack else None
                stack.append((m.group(1), depth))
                depth += 1
            elif s.startswith("FrameTransformMatrix"):
                v = [float(x) for x in re.findall(r"-?\d+\.\d+(?:e-?\d+)?", m.group(2))]
                self.rest[stack[-1][0]] = [[v[j * 4 + i] for j in range(4)] for i in range(4)]
                # (the matching closing brace was eaten with it)
            elif s == "}":
                depth -= 1
                if stack and stack[-1][1] == depth:
                    stack.pop()
            else:
                depth += 1

    def read_anim(self, text):
        at = text.rindex(chr(10) + "AnimationSet ") + 1
        self.anim_header = text[at:text.index("{", at) + 1]
        for block in re.finditer(r"Animation \{\s*\{ (\w+) \}(.*?)\n \}", text[at:], re.S):
            bone = block.group(1)
            entry = {}
            for key in re.finditer(r"AnimationKey (\w+) \{\s*\d+;\s*\d+;\s*(.*?)\s*\}", block.group(2), re.S):
                out = []
                for k in re.finditer(r"(\d+);(\d+);([-\d.,e]+);;", key.group(2)):
                    out.append((int(k.group(1)), [float(x) for x in k.group(3).split(",")]))
                entry[key.group(1)] = out
            self.keys[bone] = entry

    @staticmethod
    def sample(keys, t):
        if t <= keys[0][0]:
            return keys[0][1]
        for i in range(1, len(keys)):
            if t <= keys[i][0]:
                a, b = keys[i - 1], keys[i]
                k = (t - a[0]) / max(1, b[0] - a[0])
                va, vb = a[1], b[1]
                if len(va) == 4 and sum(x * y for x, y in zip(va, vb)) < 0:
                    vb = [-x for x in vb]
                v = [x + (y - x) * k for x, y in zip(va, vb)]
                if len(v) == 4:
                    l = math.sqrt(sum(x * x for x in v))
                    v = [x / l for x in v]
                return v
        return keys[-1][1]

    def local(self, bone, t):
        e = self.keys.get(bone)
        if not e or "R" not in e:
            return self.rest.get(bone) or [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
        # (the file's quaternions go with its row vectors: the other way round for columns)
        q = self.sample(e["R"], t)
        r = quat_mat((q[0], -q[1], -q[2], -q[3]))
        p = self.sample(e["T"], t)
        r[0][3], r[1][3], r[2][3] = p[0], p[1], p[2]
        return r

    def world(self, bone, t):
        m = self.local(bone, t)
        b = self.parent.get(bone)
        while b:
            m = mat_mul(self.local(b, t), m)
            b = self.parent.get(b)
        return m

    def at(self, bone, t):
        m = self.world(bone, t)
        return (m[0][3], m[1][3], m[2][3])


if __name__ == "__main__":
    # how the numbers read: a standing body's joints
    c = Clip("Bob_Idle")
    print("ticks", c.ticks, "bones", len(c.keys))
    for b in ("Bip01", "Bip01_Pelvis", "Bip01_Head", "Bip01_HeadNub", "Bip01_L_Foot", "Bip01_R_Hand", "Bip01_L_Hand", "Bip01_Prop1", "Bip01_Prop2"):
        print(b, [round(x, 3) for x in c.at(b, 0)])
    # is rest the same as the keys?
    b = "Bip01_L_UpperArm"
    print("rest", [[round(x, 3) for x in r] for r in c.rest[b]])
    print("key ", [[round(x, 3) for x in r] for r in c.local(b, 0)])
    s = Clip("Bob_SatChair_1hand")
    print("sat ticks", s.ticks)
    for b in ("Bip01", "Bip01_Pelvis", "Bip01_Head", "Bip01_HeadNub", "Bip01_L_Foot", "Bip01_R_Foot", "Bip01_R_Hand", "Bip01_L_Hand", "Bip01_Prop1", "Bip01_L_Thigh", "Bip01_L_Calf"):
        print(b, [round(x, 3) for x in s.at(b, 0)])
    k = Clip("Bob_IdleSmoke")
    print("smoke ticks", k.ticks)
    for t in range(0, k.ticks + 1, max(1, k.ticks // 10)):
        print(t, "L", [round(x, 2) for x in k.at("Bip01_L_Hand", t)], "R", [round(x, 2) for x in k.at("Bip01_R_Hand", t)], "P2", [round(x, 2) for x in k.at("Bip01_Prop2", t)], "head", [round(x, 2) for x in k.at("Bip01_Head", t)])
