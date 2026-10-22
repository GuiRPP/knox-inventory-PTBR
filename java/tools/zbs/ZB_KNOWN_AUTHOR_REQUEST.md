# Подпись Knox для ZombieBuddy

Решение автора 19.10.2026: подписываем jar только после того, как автора внесут в список
известных авторов ZombieBuddy. Тогда ZombieBuddy берёт ключ из своего списка
(`authors.json` в репозитории ZombieBuddy) и не ходит за ним в профиль Steam. Если же
ключ берётся из профиля, а профиль не загрузился, подписанный мод блокируется.

## Ключ
- Закрытый: `C:\Users\pielo\Zomboid\tools\keys\knox_zbs.key.pending`. Никуда не выкладывать и не загружать.
- Открытый: `JavaModZBS:8b10f205cfc8b6bc6d55f44410fde965696d43ad7a0de33e6e976ae3e7c83745`

## Как включить подпись (когда внесут)
1. Переименовать `knox_zbs.key.pending` в `knox_zbs.key`.
2. Запустить `build.ps1`: рядом с jar появится `KnoxInventoryJava.jar.zbs`.
3. Проверить в игре, что ZombieBuddy пишет в console.txt: `ZBS verification valid`.

## Текст просьбы
Куда: Issues репозитория https://github.com/zed-0xff/ZombieBuddy или личное сообщение zed_0xff в Steam.

> Hi! I'm the author of Knox Inventory (Workshop 3816775774, a ZombieBuddy Java mod).
> Players asked for a signed jar, and I'd like to sign it with a .zbs. Could you add me
> to ZombieBuddy's known authors (authors.json)? Then the signature doesn't depend on
> my Steam profile loading at game start.
>
> SteamID64: 76561198124465594
> Name: SYNTHETIK
> Key: 8b10f205cfc8b6bc6d55f44410fde965696d43ad7a0de33e6e976ae3e7c83745
>
> Thanks for ZombieBuddy!
