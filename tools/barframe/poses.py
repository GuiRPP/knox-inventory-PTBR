# The winter bar's heroes (2026-10-31, stage 4 of the plan), built from the game's own clips:
#   Knox_BarStool  on a stool at the counter, slumped forward: one hand round the whiskey
#                  bottle standing on the counter, the other on the counter, for good
#   Knox_BarSmoke  on a chair: the game's sitting, its arm with the cigarette from its smoking
#                  clip, the hand going to the mouth now and then
# and bar_poses.txt: each pose as capsules, for the frame's stand-ins (the hero's shadow in
# the light; the mannequin of tools\barframe), and the dead's walk out in the whiteout. Run:
# python poses.py, from this folder.
import os, re, sys, math
import clips
from clips import Clip, mat_mul, invert_rigid, mat_quat

HERE = os.path.dirname(os.path.abspath(__file__))
MOD = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(MOD, "42", "media", "anims_X", "Bob")
POSES = os.path.join(MOD, "42", "media", "knox", "bar_poses.txt")
SCALE = 1.5                  # the skeleton's units to the scene's (1.47 for a standing body)
TICKS_PER_SECOND = 4800

CHAINS = [("Bip01_Pelvis", "Bip01_Neck", 0.135), ("Bip01_Neck", "Bip01_Head", 0.06),
          ("Bip01_L_UpperArm", "Bip01_L_Forearm", 0.05), ("Bip01_L_Forearm", "Bip01_L_Hand", 0.042),
          ("Bip01_R_UpperArm", "Bip01_R_Forearm", 0.05), ("Bip01_R_Forearm", "Bip01_R_Hand", 0.042),
          ("Bip01_L_Thigh", "Bip01_L_Calf", 0.075), ("Bip01_L_Calf", "Bip01_L_Foot", 0.055),
          ("Bip01_R_Thigh", "Bip01_R_Calf", 0.075), ("Bip01_R_Calf", "Bip01_R_Foot", 0.055)]


def rot3(m):
    return [row[:3] for row in m[:3]]


def mul3(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def trans3(a):
    return [[a[j][i] for j in range(3)] for i in range(3)]


def vec(a, b):
    return [b[0] - a[0], b[1] - a[1], b[2] - a[2]]


def length(v):
    return math.sqrt(sum(x * x for x in v))


def norm(v):
    l = length(v)
    return [x / l for x in v]


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def rotation_between(a, b):
    # the shortest turn taking direction a to direction b
    a, b = norm(a), norm(b)
    c = dot(a, b)
    v = cross(a, b)
    k = 1 / (1 + c) if c > -0.9999 else 0
    x, y, z = v
    return [[c + x * x * k, x * y * k - z, x * z * k + y],
            [y * x * k + z, c + y * y * k, y * z * k - x],
            [z * x * k - y, z * y * k + x, c + z * z * k]]


def axis_turn(axis, deg):
    x, y, z = norm(axis)
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    t = 1 - c
    return [[t * x * x + c, t * x * y - s * z, t * x * z + s * y],
            [t * x * y + s * z, t * y * y + c, t * y * z - s * x],
            [t * x * z - s * y, t * y * z + s * x, t * z * z + c]]


class Pose:
    """A clip's bones at one time, each bone's local matrix to change, for one still pose."""

    def __init__(self, clip, t=0):
        self.clip = clip
        self.locals = {b: [row[:] for row in clip.local(b, t)] for b in clip.parent}

    def world(self, bone):
        m = self.locals[bone]
        b = self.clip.parent.get(bone)
        while b:
            m = mat_mul(self.locals[b], m)
            b = self.clip.parent.get(b)
        return m

    def at(self, bone):
        m = self.world(bone)
        return [m[0][3], m[1][3], m[2][3]]

    def turn_world(self, bone, turn):
        # turn a bone (and all under it) by a rotation given in the skeleton's own space
        parent = self.clip.parent[bone]
        pw = rot3(self.world(parent))
        w = mul3(turn, rot3(self.world(bone)))
        l = mul3(trans3(pw), w)
        for i in range(3):
            for j in range(3):
                self.locals[bone][i][j] = l[i][j]

    def reach(self, upper, fore, hand, target, pole):
        # the arm's two bones so that the hand is at target, the elbow towards pole
        s, e, h = self.at(upper), self.at(fore), self.at(hand)
        a, b = length(vec(s, e)), length(vec(e, h))
        to = vec(s, target)
        d = min(length(to), (a + b) * 0.995)
        n = norm(to)
        cos_a = (a * a + d * d - b * b) / (2 * a * d)
        sin_a = math.sqrt(max(0, 1 - cos_a * cos_a))
        side = norm([pole[i] - dot(pole, n) * n[i] for i in range(3)])
        elbow = [s[i] + n[i] * a * cos_a + side[i] * a * sin_a for i in range(3)]
        self.turn_world(upper, rotation_between(vec(s, e), vec(s, elbow)))
        e, h = self.at(fore), self.at(hand)
        self.turn_world(fore, rotation_between(vec(e, h), vec(e, [s[i] + n[i] * d for i in range(3)])))

    def lay_arm(self, side, elbow, towards, fingers, palm):
        # an arm laid out: the elbow at a point, the forearm towards another (scene units, the
        # hero's space), the hand's fingers along the forearm (or the given direction, levelled)
        # and its palm facing the given way (scene directions)
        upper, fore, hand = "Bip01_%s_UpperArm" % side, "Bip01_%s_Forearm" % side, "Bip01_%s_Hand" % side
        s, e = self.at(upper), self.at(fore)
        self.turn_world(upper, rotation_between(vec(s, e), vec(s, scene_to_clip(elbow))))
        e, h = self.at(fore), self.at(hand)
        along = norm(vec(e, scene_to_clip(towards)))
        self.turn_world(fore, rotation_between(vec(e, h), along))
        x = norm(scene_to_clip(fingers)) if fingers else along
        z = norm(scene_to_clip(palm))
        x = norm([x[i] - dot(x, z) * z[i] for i in range(3)])
        # (the skeleton's hands: x the fingers, z the palm, y = z x x)
        want = [[x[i], cross(z, x)[i], z[i]] for i in range(3)]
        self.turn_world(hand, mul3(want, trans3(rot3(self.world(hand)))))


def scene_to_clip(p):
    # a hero's own space in scene units (x its left, y up, z its front) to the skeleton's
    return [p[0] / SCALE, p[1] / SCALE, -p[2] / SCALE]


def clip_to_scene(p):
    return [p[0] * SCALE, p[1] * SCALE, -p[2] * SCALE]


def write_clip(name, base, keys, total):
    """The base clip's file with a new name and the animation given: bone -> [(t, matrix)]."""
    text = base.text
    at = text.rindex(chr(10) + "AnimationSet ") + 1
    out = [text[:at], "AnimationSet " + name + " {\n \n\n"]
    for bone in base.keys:
        k = keys[bone]
        out.append(" Animation {\n  \n  { " + bone + " }\n\n")
        out.append("  AnimationKey S {\n   1;\n   " + str(len(k)) + ";\n")
        for i, (t, m) in enumerate(k):
            end = ";;;" if i == len(k) - 1 else ";;,"
            out.append("   %d;3;1.000000,1.000000,1.000000%s\n" % (t, end))
        out.append("  }\n\n  AnimationKey R {\n   0;\n   " + str(len(k)) + ";\n")
        for i, (t, m) in enumerate(k):
            w, x, y, z = mat_quat(m)
            # (the file's quaternions go with its row vectors: Clip.local)
            end = ";;;" if i == len(k) - 1 else ";;,"
            out.append("   %d;4;%.6f,%.6f,%.6f,%.6f%s\n" % (t, w, -x, -y, -z, end))
        out.append("  }\n\n  AnimationKey T {\n   2;\n   " + str(len(k)) + ";\n")
        for i, (t, m) in enumerate(k):
            end = ";;;" if i == len(k) - 1 else ";;,"
            out.append("   %d;3;%.6f,%.6f,%.6f%s\n" % (t, m[0][3], m[1][3], m[2][3], end))
        out.append("  }\n }\n\n")
    out.append("}\n")
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name + ".x"), "w", encoding="latin-1", newline="\n") as f:
        f.write("".join(out))


def capsules(pose):
    lines = []
    for a, b, r in CHAINS:
        p, q = clip_to_scene(pose.at(a)), clip_to_scene(pose.at(b))
        lines.append("%.4f %.4f %.4f %.4f %.4f %.4f %.4f" % (p[0], p[1], p[2], q[0], q[1], q[2], r))
    # (the head on top of its neck)
    n, h = pose.at("Bip01_Neck"), pose.at("Bip01_Head")
    d = norm(vec(n, h))
    p = clip_to_scene(h)
    q = clip_to_scene([h[i] + d[i] * 0.1 for i in range(3)])
    lines.append("%.4f %.4f %.4f %.4f %.4f %.4f %.4f" % (p[0], p[1], p[2], q[0], q[1], q[2], 0.095))
    return lines


def stool_clip():
    base = Clip("Bob_SatChair_1hand")
    pose = Pose(base)
    # slumped forward over the counter: the spine goes after its front, the skeleton's -z
    # (deeper, the elbows out over the counter's edge: the hand round the bottle at the
    # shoulder's height read as an arm held up before the face - the author, 2026-11-01)
    side = [1, 0, 0]
    pose.turn_world("Bip01_Spine", axis_turn(side, -26))
    pose.turn_world("Bip01_Spine1", axis_turn(side, -24))
    # the arms folded on the counter: the elbows on its edge, the forearms flat on its top, the
    # left hand palm down before the body, the right round the bottle's side (the elbows went
    # out sideways and the hands hung off the edge - the author, 2026-11-01)
    pose.lay_arm("R", HERO_R_ELBOW, HERO_R_TOWARDS, [0, 0, 1], [1, 0, 0])
    pose.lay_arm("L", HERO_L_ELBOW, HERO_L_TOWARDS, None, [0, -1, 0])
    keys = {}
    for bone in base.keys:
        m = pose.locals[bone]
        keys[bone] = [(0, m), (3200, m)]
    write_clip("Knox_BarStool", base, keys, 3200)
    return pose


# The one asleep at the counter stirs with the mouse over him (the author, 2026-11-02): wakes for a
# moment and hiccups, swats at nothing and knocks the bottle off, his breath catches and his head
# rolls to its other side. His rest: the head on side "a" (the clip above) or "b" (rolled), the
# right hand round the bottle or, once it is gone, empty on the counter. Each stir is a clip from
# one rest to the next (KnoxMenuSceneBar.lua: STIR). Redone the same day after the author's video
# ("crooked, not our level"): no longer a few poses the game draws straight lines between, but a
# pose 30 times a second off smooth curves - the head late after the body and heavy, a drunk's
# sway, the hiccup a jolt; the swat a path of the hand, the bottle knocked where the hand meets
# it. sheet.py draws them.
SIDE = [1, 0, 0]
FPS = 30


def head_axis(pose):
    # the head's long axis (a Biped bone's x runs along it), the skeleton's space
    m = pose.world("Bip01_Head")
    return [m[0][0], m[1][0], m[2][0]]


ROLL_B = 32                                  # degrees the head is rolled on side "b"


def curve(keys):
    """t -> value through keys (t, value[, slope]): a smooth cubic, still at the ends and where
    it turns back (never past a key), else the slope through its neighbours or the one given."""
    ts = [k[0] for k in keys]
    vs = [k[1] for k in keys]
    n = len(keys)
    m = []
    for i in range(n):
        if len(keys[i]) > 2:
            m.append(keys[i][2])
        elif i == 0 or i == n - 1:
            m.append(0.0)
        else:
            a = (vs[i] - vs[i - 1]) / (ts[i] - ts[i - 1])
            b = (vs[i + 1] - vs[i]) / (ts[i + 1] - ts[i])
            m.append(0.0 if a * b <= 0 else math.copysign(min(abs(a + b) / 2, 3 * min(abs(a), abs(b))), a))

    def at(t):
        if t <= ts[0]:
            return vs[0]
        if t >= ts[-1]:
            return vs[-1]
        i = 0
        while ts[i + 1] < t:
            i += 1
        h = ts[i + 1] - ts[i]
        s = (t - ts[i]) / h
        return ((2 * s ** 3 - 3 * s ** 2 + 1) * vs[i] + (s ** 3 - 2 * s ** 2 + s) * h * m[i]
                + (-2 * s ** 3 + 3 * s ** 2) * vs[i + 1] + (s ** 3 - s ** 2) * h * m[i + 1])
    return at


def path(keys):
    """t -> point through keys (t, [x, y, z]): curve() on each axis."""
    axes = [curve([(k[0], k[1][i]) for k in keys]) for i in range(3)]
    return lambda t: [a(t) for a in axes]


def wobble(t, amount, rate, phase=0.0):
    # a drunk's slow sway: two slow waves, never quite repeating
    return amount * (0.7 * math.sin(2 * math.pi * rate * t + phase) + 0.3 * math.sin(2 * math.pi * rate * 2.3 * t + phase * 1.7))


def window(t, a, b, c, d):
    # 0 before a, up to 1 by b, 1 till c, down to 0 by d (smoothly)
    if t <= a or t >= d:
        return 0.0
    if t < b:
        s = (t - a) / (b - a)
    elif t > c:
        s = (d - t) / (d - c)
    else:
        return 1.0
    return s * s * (3 - 2 * s)


def orient_hand(pose, side, fingers, palm):
    # the hand's fingers and palm towards the given ways (scene directions, the hero's space)
    hand = "Bip01_%s_Hand" % side
    x = norm(scene_to_clip(fingers))
    z = norm(scene_to_clip(palm))
    z = norm([z[i] - dot(x, z) * x[i] for i in range(3)])
    want = [[x[i], cross(z, x)[i], z[i]] for i in range(3)]
    pose.turn_world(hand, mul3(want, trans3(rot3(pose.world(hand)))))


def hand_frame(pose, side="R"):
    # (where a hand is and its ways, scene: the wrist, the elbow, the fingers, the palm)
    m = pose.world("Bip01_%s_Hand" % side)
    return (clip_to_scene(pose.at("Bip01_%s_Hand" % side)), clip_to_scene(pose.at("Bip01_%s_Forearm" % side)),
            clip_to_scene([m[i][0] for i in range(3)]), clip_to_scene([m[i][2] for i in range(3)]))


def clip_forward():
    # the hero's front, the skeleton's space
    return scene_to_clip([0, 0, 1])


def bone_axis(pose, bone):
    # a bone's own long axis, the skeleton's space
    m = pose.world(bone)
    return [m[0][0], m[1][0], m[2][0]]


def sleeper_pose(side="a", empty=False, lift=0.0, chest=0.0, neck=0.0, head_up=0.0, yaw=0.0, tilt=0.0,
                 roll=None, shrug=0.0, shrug_r=0.0, twist=0.0, hand=None):
    """The one at the counter. lift 0..1 sits him up off the counter, chest bends the upper back
    up more (degrees), neck and head_up lift the face (degrees), yaw turns it and tilt leans it
    to a side, roll overrides the side's roll (degrees); shrug lifts both shoulders and shrug_r
    the right one, twist turns the chest; hand: (wrist, elbow, fingers, palm), scene, the hero's
    space - the right hand there (the elbow towards that point) instead of on the counter."""
    pose = Pose(sleeper_base())
    pose.turn_world("Bip01_Spine", axis_turn(SIDE, -26 + 17 * lift))
    pose.turn_world("Bip01_Spine1", axis_turn(SIDE, -24 + 15 * lift + chest))
    if twist:
        pose.turn_world("Bip01_Spine1", axis_turn(bone_axis(pose, "Bip01_Spine1"), twist))
    for bone, k in (("Bip01_L_Clavicle", -shrug), ("Bip01_R_Clavicle", shrug + shrug_r)):
        if k:
            pose.turn_world(bone, axis_turn(clip_forward(), k))
    if neck:
        pose.turn_world("Bip01_Neck", axis_turn(SIDE, neck))
    r = (ROLL_B if side == "b" else 0) if roll is None else roll
    if r:
        pose.turn_world("Bip01_Head", axis_turn(head_axis(pose), r))
    if head_up:
        pose.turn_world("Bip01_Head", axis_turn(SIDE, head_up))
    if yaw:
        pose.turn_world("Bip01_Head", axis_turn(head_axis(pose), yaw))
    if tilt:
        pose.turn_world("Bip01_Head", axis_turn(clip_forward(), tilt))
    if hand:
        wrist, elbow, fingers, palm = hand[:4]
        s = pose.at("Bip01_R_UpperArm")
        if len(hand) > 4 and hand[4] == "aim":
            # (the upper arm at the elbow, the forearm at the wrist: what an elbow on its own
            # smooth path makes - a reach near a straight arm flicks the elbow round)
            e = pose.at("Bip01_R_Forearm")
            pose.turn_world("Bip01_R_UpperArm", rotation_between(vec(s, e), vec(s, scene_to_clip(elbow))))
            e, h = pose.at("Bip01_R_Forearm"), pose.at("Bip01_R_Hand")
            pose.turn_world("Bip01_R_Forearm", rotation_between(vec(e, h), vec(e, scene_to_clip(wrist))))
        else:
            pose.reach("Bip01_R_UpperArm", "Bip01_R_Forearm", "Bip01_R_Hand", scene_to_clip(wrist), vec(s, scene_to_clip(elbow)))
        orient_hand(pose, "R", fingers, palm)
    elif empty:
        pose.lay_arm("R", HERO_R_ELBOW, HERO_RE_TOWARDS, None, [0, -1, 0])
    else:
        pose.lay_arm("R", HERO_R_ELBOW, HERO_R_TOWARDS, [0, 0, 1], [1, 0, 0])
    pose.lay_arm("L", HERO_L_ELBOW, HERO_L_TOWARDS, None, [0, -1, 0])
    return pose


_base = []


def sleeper_base():
    # (read once: some hundreds of poses are made from it)
    if not _base:
        _base.append(Clip("Bob_SatChair_1hand"))
    return _base[0]


def keyed(name, frames):
    """A clip through poses at times (s): [(t, pose)]; written as the game's file."""
    base = frames[0][1].clip
    total = int(round(frames[-1][0] * TICKS_PER_SECOND))
    keys = {b: [(int(round(t * TICKS_PER_SECOND)), p.locals[b]) for t, p in frames] for b in base.keys}
    write_clip(name, base, keys, total)
    return total


def sampled(name, seconds, at):
    """A clip of the poses at(t), FPS a second, from 0 to seconds."""
    n = int(round(seconds * FPS))
    return keyed(name, [(i / FPS, at(i / FPS)) for i in range(n + 1)])


def head_tilt(pose):
    # degrees the head's long axis leans off the vertical (0: upright)
    d = norm(clip_to_scene(head_axis(pose)))
    return round(math.degrees(math.acos(max(-1, min(1, d[1])))), 1)


WAKE_LEN, WAKE_HIC = 3.7, 1.62
SHIFT_LEN, SHIFT_CATCH, SHIFT_SMACK = 2.5, 0.5, 0.86
SWAT_LEN, SWAT_HIT = 1.9, 1.06


def wake_at(side, empty):
    """Lifts his head off his arms - the body first, the heavy head after it - and looks about
    blearily, swaying; hiccups (a small catch up in the chest and shoulders, the head barely with
    it - a jolt with the head knocked back was too sharp, the author 2026-11-02);
    nods off once and catches himself, then sinks back down, the head last and flopping on."""
    h = WAKE_HIC
    lift = curve([(0, 0), (0.35, 0.03), (1.05, 0.40), (h - 0.05, 0.42), (h + 0.06, 0.432), (h + 0.32, 0.415),
                  (2.35, 0.38), (2.55, 0.33), (2.75, 0.35), (3.25, 0.0, -0.9), (3.4, 0.025), (3.7, 0)])
    chest = curve([(0, 0), (0.3, 1.5), (h - 0.04, 2), (h + 0.05, 3.8), (h + 0.32, 1.8), (3.0, 0.5), (3.7, 0)])
    shrug = curve([(0, 0), (0.9, 3), (h - 0.04, 3), (h + 0.05, 5.5), (h + 0.32, 2.8), (2.6, 2), (3.2, 0), (3.7, 0)])
    neck = curve([(0, 0), (0.45, 1), (1.15, 13), (h - 0.04, 14), (h + 0.06, 14.8), (h + 0.36, 13.5), (2.35, 11),
                  (2.55, 3), (2.72, 10), (3.3, 0, -12), (3.48, 1.5), (3.7, 0)])
    head = curve([(0, 0), (0.6, 1), (1.3, 12), (h - 0.04, 13), (h + 0.07, 13.8), (h + 0.4, 11.5), (2.35, 10),
                  (2.58, -1), (2.78, 9), (3.05, 6), (3.36, -4, -10), (3.52, 1.5), (3.7, 0)])
    r0 = ROLL_B if side == "b" else 0
    roll = curve([(0, r0), (0.5, r0), (1.3, r0 * 0.35), (2.6, r0 * 0.35), (3.3, r0), (3.7, r0)])

    def at(t):
        w = window(t, 0.8, 1.3, 2.6, 3.1)
        return sleeper_pose(side, empty, lift=lift(t), chest=chest(t), neck=neck(t), head_up=head(t),
                            yaw=wobble(t, 6 * w, 0.42, 0.6), tilt=wobble(t, 4.5 * w, 0.31, 2.1),
                            roll=roll(t), shrug=shrug(t), twist=wobble(t, 2.5 * w, 0.27, 1.0))
    return at


def shift_at(side, empty):
    """The snore catches (the breath held, a jolt in the chest), he smacks his lips (the head works
    a little), lifts it just off his arm, rolls it over to its other cheek and lets it down; the
    breath goes out of him."""
    c, k = SHIFT_CATCH, SHIFT_SMACK
    chest = curve([(0, 0), (c - 0.05, 3.5), (c + 0.04, 6), (c + 0.18, 3), (1.3, 2.5), (1.9, -2.5), (2.5, 0)])
    shrug = curve([(0, 0), (c - 0.05, 1.5), (c + 0.04, 5), (c + 0.2, 1.5), (1.9, -1), (2.5, 0)])
    head = curve([(0, 0), (c, 0), (c + 0.05, 4), (c + 0.18, 1), (k, 0.5), (k + 0.07, 2.5), (k + 0.14, 0.5),
                  (k + 0.21, 2.2), (k + 0.3, 1), (1.45, 9), (1.85, 1.5, -12), (2.0, -1.5), (2.2, 0.4), (2.5, 0)])
    lift = curve([(0, 0), (1.1, 0.01), (1.45, 0.07), (1.85, 0.01), (2.5, 0)])
    r0, r1 = (0, ROLL_B) if side == "a" else (ROLL_B, 0)
    d = r1 - r0
    roll = curve([(0, r0), (1.1, r0), (1.45, r0 + d * 0.45), (1.82, r1 + d * 0.08), (2.1, r1), (2.5, r1)])
    yaw = curve([(0, 0), (k, 0), (k + 0.08, 1.5), (k + 0.17, -1.2), (k + 0.26, 0.6), (k + 0.4, 0), (2.5, 0)])

    def at(t):
        return sleeper_pose(side, empty, lift=lift(t), chest=chest(t), head_up=head(t), yaw=yaw(t),
                            roll=roll(t), shrug=shrug(t))
    return at


def swat_at(side, bottle):
    """Swats at something by his ear in his sleep: lets go of the bottle, the hand drifts up and
    out to his right, then comes in fast, leaning after it - the hand into the bottle's shoulder
    (SWAT_HIT), the arm still bent - and drops flat on the counter beside it, where it stays (the
    rest without the bottle)."""
    hold, empty = sleeper_pose(side, False), sleeper_pose(side, True)
    w0, e0, f0, p0 = hand_frame(hold)
    w1, e1, f1, p1 = hand_frame(empty)
    hit = SWAT_HIT
    # (the fingers along the bottle's side at its shoulder's height, the wrist short of it: at
    # arm's length the elbow would flick)
    contact = [bottle[0] - WHISKEY_R - 0.03, bottle[1] + 0.16, bottle[2] - 0.13]
    wrist_keys = [(0, w0), (0.3, [w0[0] - 0.02, w0[1] + 0.045, w0[2] - 0.05]), (0.72, [-0.2, w0[1] + 0.15, 0.38]),
                  (0.9, [-0.215, w0[1] + 0.165, 0.385]), (hit, contact), (hit + 0.13, [w1[0] + 0.01, w1[1] + 0.055, w1[2] - 0.03]),
                  (hit + 0.26, w1), (hit + 0.34, [w1[0], w1[1] + 0.01, w1[2]]), (hit + 0.46, w1), (SWAT_LEN, w1)]
    fingers = path([(0, f0), (0.3, [f0[0] - 0.1, f0[1] + 0.2, f0[2]]), (0.72, [0.15, 0.55, 1]), (0.9, [0.1, 0.6, 1]),
                    (hit, [0.3, -0.05, 1]), (hit + 0.26, f1), (SWAT_LEN, f1)])
    palm = path([(0, p0), (0.3, [0.8, -0.4, 0]), (0.72, [1, 0.1, -0.15]), (0.9, [1, 0.15, -0.1]), (hit, [1, -0.15, 0]),
                 (hit + 0.13, [0.6, -0.8, 0]), (hit + 0.26, p1), (SWAT_LEN, p1)])
    lift = curve([(0, 0), (0.6, 0.08), (0.9, 0.09), (hit, -0.06), (hit + 0.24, -0.01), (hit + 0.36, 0.015), (SWAT_LEN, 0)])
    head = curve([(0, 0), (0.45, 4), (0.85, 7), (hit, 4), (hit + 0.2, -2.5), (hit + 0.36, 1), (SWAT_LEN, 0)])
    yaw = curve([(0, 0), (0.5, -5), (0.9, -7), (hit + 0.1, -3), (hit + 0.45, 0), (SWAT_LEN, 0)])
    shrug_r = curve([(0, 0), (0.75, 5), (0.9, 5.5), (hit, 3), (hit + 0.26, 0), (SWAT_LEN, 0)])
    twist = curve([(0, 0), (0.85, -4), (hit + 0.05, 4), (hit + 0.4, 0), (SWAT_LEN, 0)])

    def body(t):
        return dict(lift=lift(t), head_up=head(t), yaw=yaw(t), shrug_r=shrug_r(t), twist=twist(t))
    # the elbow at each of the wrist's keys as a reach would bend it (outwards and down), then
    # on its own smooth path between them
    elbow_keys = []
    for t, w in wrist_keys:
        if t == 0:
            elbow_keys.append((t, e0))
        elif t >= hit + 0.26:
            elbow_keys.append((t, e1))
        else:
            p = sleeper_pose(side, True, hand=(w, [w[0] - 0.12, w[1] - 0.2, w[2] - 0.05], fingers(t), palm(t)), **body(t))
            elbow_keys.append((t, clip_to_scene(p.at("Bip01_R_Forearm"))))
    wrist, elbow = path(wrist_keys), path(elbow_keys)

    def at(t):
        if t <= 0:
            return hold
        return sleeper_pose(side, True, hand=(wrist(t), elbow(t), fingers(t), palm(t), "aim"), **body(t))
    return at


def sleeper_clips(bottle):
    """The rests and the stirs; bottle: where the whiskey stands (scene, the hero's space)."""
    out = {}
    codes = [("a", False), ("b", False), ("a", True), ("b", True)]
    name = {("a", False): "", ("b", False): "B", ("a", True): "E", ("b", True): "EB"}
    for side, empty in codes:
        n = name[(side, empty)]
        rest = sleeper_pose(side, empty)
        if n:
            keyed("Knox_BarStool" + n, [(0, rest), (0.6667, rest)])
        out["Knox_BarWake" + (n or "A")] = sampled("Knox_BarWake" + (n or "A"), WAKE_LEN, wake_at(side, empty))
        out["Knox_BarShift" + (n or "A")] = sampled("Knox_BarShift" + (n or "A"), SHIFT_LEN, shift_at(side, empty))
    for side in ("a", "b"):
        out["Knox_BarSwat" + side.upper()] = sampled("Knox_BarSwat" + side.upper(), SWAT_LEN, swat_at(side, bottle))
    w = wake_at("a", False)
    print("head tilt: rest", head_tilt(sleeper_pose()), "woken", head_tilt(w(2.0)), "hiccup", head_tilt(w(WAKE_HIC + 0.05)))
    print("times: wake %.2f hiccup %.2f, shift %.2f catch %.2f smack %.2f, swat %.2f hit %.2f" %
          (WAKE_LEN, WAKE_HIC, SHIFT_LEN, SHIFT_CATCH, SHIFT_SMACK, SWAT_LEN, SWAT_HIT))
    return out


def smoke_clip():
    base = Clip("Bob_SatChair")
    smoke = Clip("Bob_IdleSmoke")
    arm = [b for b in smoke.keys if b.startswith("Bip01_L_") and not any(s in b for s in ("Thigh", "Calf", "Foot", "Toe"))]
    still = Pose(base)
    # the game's own clip takes 3 s; then the hand lies a while
    rest = 26000
    total = smoke.ticks + rest
    times = sorted(set(k[0] for k in smoke.keys["Bip01_L_Forearm"]["R"]))
    step = max(1, (times[1] - times[0]) if len(times) > 1 else 160)
    times = list(range(0, smoke.ticks + 1, max(step, 240)))
    keys = {b: [(0, still.locals[b]), (total, still.locals[b])] for b in base.keys}
    for b in arm:
        if b not in base.keys:
            continue
        keys[b] = [(t, smoke.local(b, t)) for t in times] + [(total, smoke.local(b, smoke.ticks))]
    # the cigarette follows the hand: as far from it as in the game's clip
    prop_keys = []
    for t in times + [total]:
        st = min(t, smoke.ticks)
        offset = mat_mul(invert_rigid(smoke.world("Bip01_L_Hand", st)), smoke.world("Bip01_Prop2", st))
        # the hand in this clip: the sitting chest, the smoking arm
        chain = []
        b = "Bip01_L_Hand"
        while b:
            chain.append(b)
            b = base.parent.get(b)
        w = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
        for bone in reversed(chain):
            l = smoke.local(bone, st) if bone in arm else still.locals[bone]
            w = mat_mul(w, l)
        root = still.world("Bip01")
        prop_keys.append((t, mat_mul(invert_rigid(root), mat_mul(w, offset))))
    keys["Bip01_Prop2"] = prop_keys
    write_clip("Knox_BarSmoke", base, keys, total)
    return still, total


# the hero's arms on the counter, in scene units from the hero's place (x its left, z its
# front; the counter's top 1.1 m, its near edge 0.43 m before the hero): the elbows just on the
# edge, each forearm towards its point; the right hand's palm against the whiskey bottle
# (KnoxMenuSceneBar.lua kb_whiskey: put where main() prints it)
U = 1 / 1.22
HERO_Y = 0.20                                # how high its hips are lifted onto the stool
TOP = 1.1 * U - HERO_Y
HERO_R_ELBOW = [-0.16, TOP + 0.04, 0.37]
HERO_R_TOWARDS = [-0.08, TOP + 0.035, 0.62]
HERO_L_ELBOW = [0.19, TOP + 0.04, 0.36]
HERO_L_TOWARDS = [-0.03, TOP + 0.03, 0.50]
# (the right hand empty, the bottle gone: laid flat as the left, palm down, a little out)
HERO_RE_TOWARDS = [-0.12, TOP + 0.03, 0.58]
WHISKEY_R = 0.0432 * U                       # the bottle's radius (MenuGen)

# The dead out in the whiteout (KnoxBarFrame's walkers, 2026-10-31): the game's zombie walks,
# as frames of capsules, kept walking on the spot
ZOMBIE = os.path.join(os.path.dirname(clips.GAME), "Zombie")
WALK_FRAMES = 16


class Frame:
    """A clip's bones at one time, its root's mean put at 0 so the body walks on the spot."""

    def __init__(self, clip, t, root):
        self.clip, self.t, self.root = clip, t, root

    def at(self, bone):
        p = self.clip.at(bone, self.t)
        return [p[0] - self.root[0], p[1], p[2] - self.root[2]]


def walk_frames(name):
    keep = clips.GAME
    clips.GAME = ZOMBIE
    clip = Clip(name)
    clips.GAME = keep
    n = 32
    roots = [clip.at("Bip01", clip.ticks * i / n) for i in range(n)]
    root = [sum(r[0] for r in roots) / n, 0, sum(r[2] for r in roots) / n]
    short = name.replace("Zombie_Walk", "zwalk")
    lines = []
    for i in range(WALK_FRAMES):
        lines.append("pose " + short)
        lines += capsules(Frame(clip, clip.ticks * i / WALK_FRAMES, root))
    # the ground it covers: a planted foot goes back under the body as far as the body goes on,
    # each foot once a cycle
    stride = 0
    for foot in ("Bip01_L_Foot", "Bip01_R_Foot"):
        zs = [clip.at(foot, clip.ticks * i / n)[2] for i in range(n)]
        stride += (max(zs) - min(zs)) * SCALE
    seconds = clip.ticks / TICKS_PER_SECOND
    lines.append("cycle %s %.4f %.4f" % (short, seconds, stride / seconds))
    return lines


def main():
    lines = ["# Written by tools\\barframe\\poses.py. A pose, then its capsules from the hero's place,",
             "# x its left, y up, z its front, scene units: ax ay az bx by bz radius"]
    stool = stool_clip()
    hand = stool.world("Bip01_R_Hand")
    palm = clip_to_scene([hand[i][2] for i in range(3)])
    fingers = clip_to_scene([hand[i][0] for i in range(3)])
    at = clip_to_scene(stool.at("Bip01_R_Hand"))
    # (the bottle's middle: past the wrist along the fingers, its radius off the palm)
    bottle = [at[i] + norm(fingers)[i] * 0.07 + norm(palm)[i] * (WHISKEY_R + 0.025) for i in range(3)]
    print("stool: head", [round(x, 2) for x in clip_to_scene(stool.at("Bip01_Head"))],
          "R hand", [round(x, 2) for x in at], "L hand", [round(x, 2) for x in clip_to_scene(stool.at("Bip01_L_Hand"))])
    print("kb_whiskey from the hero, metres: x %.3f z %.3f" % (bottle[0] / U, bottle[2] / U))
    # (the bottle's middle; its foot on the counter)
    sleeper_clips([bottle[0], TOP, bottle[2]])
    lines.append("pose stool")
    lines += capsules(stool)
    still, total = smoke_clip()
    lines.append("pose smoke")
    lines += capsules(still)
    idle = Pose(Clip("Bob_Idle"))
    lines.append("pose stand")
    lines += capsules(idle)
    # the backpack of the one about to go
    lines.append("0.0 0.75 -0.14 0.0 1.1 -0.15 0.14")
    lines += walk_frames("Zombie_Walk2")
    lines += walk_frames("Zombie_Walk3")
    with open(POSES, "w", encoding="ascii", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("smoke clip length", total, "ticks =", round(total / TICKS_PER_SECOND, 1), "s at speed 1")


if __name__ == "__main__":
    main()
