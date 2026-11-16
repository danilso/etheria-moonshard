# Этерия: Осколок Луны

Сюжетная RPG для Windows Command Prompt, написанная на Batch. Создайте героя, исследуйте Этерию, решайте загадки и сражайтесь, чтобы доставить лунный осколок к алтарю до рассвета.

## Возможности

- Три класса: Воин, Маг и Вор с разными боевыми особенностями.
- Несколько локаций, побочных заданий, загадок и сюжетных развилок.
- Пошаговые бои: атака, защита, классовые умения и отступление.
- Ограничение по времени: отдых и некоторые действия приближают рассвет.
- Сохранение и продолжение через `savegame.cfg`.
- Цветной текст, эффект печати и ASCII-анимации.

## Запуск

Нужны Windows 10/11, `cmd.exe` и Windows PowerShell. Запустите `etheria-moonshard.bat` двойным щелчком или из Command Prompt. Игра сохраняет прогресс в `savegame.cfg` рядом с файлом; сохранения исключены из Git.

## Управление

Выбирайте действие по номеру. Во время боя можно атаковать, защищаться, применять способность класса или отступить. В меню есть статус героя, заметки и сохранение.

## Реализация

Основная логика написана на Windows Batch. В конец файла встроен PowerShell-код для вывода сцен и анимаций. При вызове Batch извлекает PowerShell-фрагмент из собственного файла и запускает его через `Invoke-Expression` с параметром `-ExecutionPolicy Bypass`, действующим только для этого процесса. Внешние библиотеки не требуются.

## Структура

```text
etheria-moonshard/
├── etheria-moonshard.bat
├── README.md
├── .gitattributes
└── .gitignore
```

## Лицензия

Лицензия не указана. Все права остаются у автора проекта.

---

# Etheria: Moon Shard

A story-driven RPG for Windows Command Prompt, written in Batch. Create a hero, explore Etheria, solve riddles, and deliver a lunar shard to the altar before dawn.

## Features

- Three character classes with distinct combat traits.
- Multiple locations, side quests, riddles, and story branches.
- Turn-based combat with attacks, defense, class abilities, and escape attempts.
- Time management, save and continue, colored text, typewriter effect, and ASCII animations.

## Run

Requires Windows 10 or 11, Command Prompt, and Windows PowerShell. Run `etheria-moonshard.bat` by double-clicking it or from Command Prompt. The game writes `savegame.cfg` beside the file; saves are excluded from Git.

## Implementation

The game logic is written in Windows Batch. An embedded PowerShell section renders scenes and animations. The Batch file extracts that section from itself and invokes it with `Invoke-Expression` and process-scoped `-ExecutionPolicy Bypass`. No external libraries are required.

## License

No license is declared.
