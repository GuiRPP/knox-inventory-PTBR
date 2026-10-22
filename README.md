# Knox Inventory

A Tarkov-style UI overhaul for **Project Zomboid Build 42**: one full-screen
inventory around your live 3D character, grid containers where things take real
space, nested bag windows, surroundings, quick slots, Knox's own fonts, tooltips,
context menus and cursor, a car dashboard - and a main menu that is a night camp
with the heroes of your latest saves by the fire.

**Steam Workshop:** https://steamcommunity.com/sharedfiles/filedetails/?id=3816775774

The Workshop item carries two mods: **Knox Inventory** (0.9.8.7, the release) and
**Knox Inventory 1.0 BETA** (this repository's current work). Enable only one.

## Requirements

- Project Zomboid Build 42
- [ZombieBuddy](https://steamcommunity.com/sharedfiles/filedetails/?id=3619862853) -
  loads the mod's Java part (`KnoxInventoryJava.jar`)

## What is where

| Folder | What |
|---|---|
| `42/` | The mod itself, as the game loads it: `media/lua` (client, shared, server), scripts, textures, models, fonts, sounds, translations |
| `java/` | The Java part: `src/knox/java` (Lua functions and ZombieBuddy patches of game classes), `build.ps1`, Java tools (Lua syntax check, font and icon generators, jar signing) |
| `tools/` | Generators and tests run on the game's own Lua engine: item sizes (`footprint`), sorting (`order`), search, multiplayer (`net`), save guard, dashboard, car radio, UI lint; Workshop packaging and upload |

## Building

1. Put this folder into `%UserProfile%\Zomboid\mods\` (the game loads it from there).
2. Build the Java part with JDK 25 (the game runs on Java 25):
   `powershell -ExecutionPolicy Bypass -File java\build.ps1`
   (the script expects the JDK in `%UserProfile%\Zomboid\tools\jdk-25` and the game in
   Steam's default folder - change the paths at its top if yours differ).
   It writes `42/media/java/client/KnoxInventoryJava.jar`.
3. Start the game with ZombieBuddy enabled and allow the jar when it asks.

Not in the repository: the sounds licensed from Artlist (footsteps of the menu's
hero, the radio's push buttons - see `42/CREDITS.txt`). The mod runs without them;
those sounds are then silent.

## Tests

`powershell -ExecutionPolicy Bypass -File tools\checkall\checkall.ps1` runs them all
(syntax of every Lua file with the game's compiler, stray globals, UI lint and the
offline tests). Each folder of `tools/` also has its own `test.ps1`.

## Addons

Addons, patches and translations are welcome and need no permission - see
[LICENSE.md](LICENSE.md). Make them **require** Knox Inventory rather than copy its
files. Players can change item sizes and stacks without code in
`Zomboid/Lua/knox_overrides.txt`, and turn each part of Knox off on its Modules page.

## License

Source available, not open source: you may make addons, patches and translations,
copy small parts into them, study the code and change it for yourself; you may not
re-upload the mod, present it as yours or sell it. Full terms: [LICENSE.md](LICENSE.md).

---

### Коротко по-русски

Knox Inventory - инвентарь в стиле Tarkov для Project Zomboid B42. Исходники открыты,
чтобы было видно, что делает мод, и чтобы на нём можно было строить своё.
**Можно без спроса:** делать аддоны, патчи совместимости и переводы (они должны
требовать Knox, а не копировать его файлы), брать в них небольшие куски кода, изучать
код, менять его для себя и присылать исправления. **Нельзя без разрешения автора:**
перезаливать мод целиком или большую часть, выдавать за своё, продавать.
Полный текст - [LICENSE.md](LICENSE.md).
