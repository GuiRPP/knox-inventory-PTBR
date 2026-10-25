# The texts of the news pictures per language as "key<TAB>value" lines (read by Lua with readfile:
# LuaRun cuts non-ASCII in a source's string literals). Item names are the game's own.
import sys, os, re, json
mod, out = sys.argv[1], sys.argv[2]
game = r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\media\lua\shared\Translate"
mine = {"RU": {"TG.TacticalPack": "Тактический рюкзак 3-Day", "TG.Vest": "Плитник", "TG.Knife": "Тактический нож"},
        "EN": {"TG.TacticalPack": "3-Day Assault Pack", "TG.Vest": "Plate Carrier", "TG.Knife": "Tactical Knife"}}
extra = {"RU": {"q_bag": "рюкзак", "p_name": "Сумки покомпактнее", "imp_name": "# name = Tactical Gear: компактно",
                "imp_bad": "TG.Knife = абракадабра"},
         "EN": {"q_bag": "backpack", "p_name": "Compact bags", "imp_name": "# name = Tactical Gear: compact",
                "imp_bad": "TG.Knife = gibberish"}}
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "items.lua"), encoding="utf-8").read()
fts = re.findall(r'\{"([^"]+)", "', src)
for lang in ("RU", "EN"):
    tr = json.load(open(os.path.join(mod, "42", "media", "lua", "shared", "Translate", lang, "IG_UI.json"), encoding="utf-8"))
    names = json.load(open(os.path.join(game, lang, "ItemName.json"), encoding="utf-8"))
    L = [k + "\t" + v.replace("\n", " ") for k, v in tr.items()]
    for ft in fts:
        L.append("item:" + ft + "\t" + (mine[lang].get(ft) or names.get(ft) or ft))
    for k, v in extra[lang].items():
        L.append("x:" + k + "\t" + v)
    open(os.path.join(out, "strings_%s.txt" % lang.lower()), "w", encoding="utf-8").write("\n".join(L) + "\n")
    print(lang, len(L))
