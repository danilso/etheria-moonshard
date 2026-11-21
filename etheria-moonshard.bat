@echo off
:: ETHERIA_TEST=1 - режим автотестов (CI): без смены кодовой страницы, ожиданий и эффектов
if not "%ETHERIA_TEST%"=="1" chcp 65001 >nul
setlocal enabledelayedexpansion
title Этерия - Осколок Луны
set "SELF=%~f0"

:: =========================================================
:: ANSI-ЦВЕТА
:: =========================================================
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "reset=!ESC![0m"
set "red=!ESC![91m"
set "green=!ESC![92m"
set "yellow=!ESC![93m"
set "blue=!ESC![94m"
set "magenta=!ESC![95m"
set "cyan=!ESC![96m"
set "white=!ESC![97m"
set "gray=!ESC![90m"

set "VERSION=1.1"
:: Сохранения лежат рядом с игрой, а не в текущей папке консоли.
set "BASEDIR=%~dp0"
set "SAVE=!BASEDIR!savegame.cfg"
set "PROG=!BASEDIR!etheria-progress.cfg"
:: Задержка печатающей машинки в мс (0 = мгновенно). Любая клавиша пропускает набор.
set "tw_delay=18"
set "ps_mode=type"
set "nofx=0"
set "force_instant=0"

:: Параметры запуска: --instant, --no-fx, --help
:ARGS
if "%~1"=="" goto ARGS_DONE
if /i "%~1"=="--instant" set "force_instant=1"
if /i "%~1"=="--no-fx" set "nofx=1"
if /i "%~1"=="--help" goto USAGE
if /i "%~1"=="/?" goto USAGE
shift
goto ARGS
:ARGS_DONE

:: Без PowerShell игра работает в упрощённом режиме: без анимаций и печати.
where powershell >nul 2>&1 || set "nofx=1"
if "!ETHERIA_TEST!"=="1" set "nofx=1"

call :INIT_RIDDLES
call :INIT_STATE
call :LOAD_PROGRESS
if "!force_instant!"=="1" set "tw_delay=0"
goto SPLASH

:USAGE
echo.
echo   Этерия: Осколок Луны v!VERSION!
echo.
echo   etheria-moonshard.bat [--instant] [--no-fx]
echo.
echo     --instant   текст появляется сразу, без эффекта печати
echo     --no-fx     без PowerShell: без анимаций и печатающей машинки
echo     --help      эта справка
echo.
exit /b 0


:: =========================================================
:: ЗАСТАВКА: РАДУЖНЫЙ ЗАГОЛОВОК И ИДУЩИЙ ЧЕЛОВЕЧЕК
:: =========================================================
:SPLASH
cls
echo.
call :BANNER 0
for /l %%f in (1,1,3) do (
    <nul set /p "=!ESC![6A"
    call :BANNER %%f
)
echo.
set "walk_end=wave"
call :ANIM_WALK
echo.
echo !gray!  [нажмите любую клавишу]!reset!
pause >nul
goto MAIN_MENU

:BANNER
set /a "rb_shift=%~1"
set "rb_text=  ##### ##### #   # ##### ####  ###  ### "
call :RAINBOW
set /a rb_shift+=1
set "rb_text=  #       #   #   # #     #   #  #  #   #"
call :RAINBOW
set /a rb_shift+=1
set "rb_text=  ####    #   ##### ####  ####   #  #####"
call :RAINBOW
set /a rb_shift+=1
set "rb_text=  #       #   #   # #     #  #   #  #   #"
call :RAINBOW
set /a rb_shift+=1
set "rb_text=  #####   #   #   # ##### #   # ### #   #"
call :RAINBOW
set /a rb_shift+=1
set "rb_text=      О С К О Л О К    Л У Н Ы"
call :RAINBOW
goto :eof

:: Печатает rb_text радужными цветами. rb_shift сдвигает палитру.
:RAINBOW
set "rb_i=0"
:RB_LOOP
set "rb_ch=!rb_text:~%rb_i%,1!"
if not defined rb_ch goto RB_END
set /a "rb_k=(rb_i+rb_shift)%%6+1"
for /f "tokens=%rb_k%" %%c in ("91 93 92 96 94 95") do set "rb_code=%%c"
<nul set /p "=!ESC![!rb_code!m!rb_ch!"
set /a rb_i+=1
goto RB_LOOP
:RB_END
echo !reset!
goto :eof


:: =========================================================
:: ГЛАВНОЕ МЕНЮ
:: =========================================================
:MAIN_MENU
cls
echo.
set /a "rb_shift=%random% %% 6"
set "rb_text=  ======== ЭТЕРИЯ: ОСКОЛОК ЛУНЫ ========"
call :RAINBOW
echo !gray!                                        v!VERSION!!reset!
call :COUNT_ENDINGS
call :SAVE_INFO
echo.
echo   [1] Новая игра
if defined sv_info (
    echo   [2] Продолжить !gray!- !sv_info!!reset!
) else (
    echo   !gray![2] Продолжить - сохранений нет!reset!
)
echo   [3] Летопись концовок !gray!- открыто !e_cnt! из 8!reset!
echo   [4] Как играть
echo   [5] Скорость текста !gray!- !speed_name!!reset!
echo   [6] Выйти
echo.
call :CHOOSE /c 123456 /n /m "  Ваш выбор: "
if errorlevel 6 goto END_GAME
if errorlevel 5 goto SPEED_MENU
if errorlevel 4 goto HOW_TO_PLAY
if errorlevel 3 goto CHRONICLE
if errorlevel 2 goto LOAD_GAME
goto NEW_GAME

:SAVE_INFO
set "sv_info="
set "sv_name="
set "sv_class="
set "sv_hours="
set "speed_name=обычная"
if "!tw_delay!"=="0" set "speed_name=мгновенно"
if "!tw_delay!"=="8" set "speed_name=быстро"
if "!tw_delay!"=="35" set "speed_name=медленно"
if not exist "!SAVE!" goto :eof
for /f "usebackq tokens=1* delims=:" %%a in ("!SAVE!") do (
    if /i "%%a"=="player_name"  set "sv_name=%%b"
    if /i "%%a"=="player_class" set "sv_class=%%b"
    if /i "%%a"=="hours"        set "sv_hours=%%b"
)
if defined sv_name set "sv_info=!sv_name!, !sv_class!, до рассвета !sv_hours! ч."
goto :eof

:SPEED_MENU
if "!tw_delay!"=="0" (set "tw_delay=8") else if "!tw_delay!"=="8" (set "tw_delay=18") else if "!tw_delay!"=="18" (set "tw_delay=35") else (set "tw_delay=0")
call :SAVE_PROGRESS
goto MAIN_MENU

:HOW_TO_PLAY
cls
echo.
echo !blue!===============================================!reset!
echo   КАК ИГРАТЬ
echo !blue!===============================================!reset!
echo.
echo   !yellow!Цель.!reset! Донести Осколок Луны до алтаря на вершине Шпиля,
echo   пока не взошло солнце. У вас 20 HP и 7 часов.
echo.
echo   !yellow!Время.!reset! Каждый поход в район и попытка открыть Врата
echo   стоят 1 час. Отдых у фонтана: +6 HP за 1 час.
echo   Если часы кончатся раньше финала, Этерия проиграет.
echo.
echo   !yellow!Задания.!reset! Все три необязательны, но дают преимущества:
echo     Таверна       - ключ от Врат, без него придётся отвечать на загадки
echo     Восток        - Амулет Света: -1 к входящему урону и лучший финал
echo     Библиотека    - слабость Тени: +2 урона по боссу
echo.
echo   !yellow!Бой.!reset! Атака, защита (урон вдвое меньше), особый приём
echo   класса раз в 3 хода и побег, если он возможен.
echo   Каждый четвёртый ход Тень бьёт в полную силу - закройтесь.
echo.
echo   !yellow!Управление.!reset! Цифры выбирают пункт меню. Любая клавиша
echo   во время печати текста показывает его целиком.
echo.
echo   !gray!Подсказка: в Летописи концовок есть намёки на все 8 исходов.!reset!
call :PAUSE
goto MAIN_MENU

:CHRONICLE
cls
echo.
echo !blue!===============================================!reset!
echo   ЛЕТОПИСЬ КОНЦОВОК
echo !blue!===============================================!reset!
echo.
call :COUNT_ENDINGS
for /l %%i in (1,1,8) do (
    call :ENDING_META %%i
    if "!e%%i!"=="1" (
        echo   !green![%%i] !em_name!!reset!
    ) else (
        echo   !gray![%%i] ???  - !em_hint!!reset!
    )
)
echo.
echo   Открыто: !yellow!!e_cnt! из 8!reset!
if !e_cnt! EQU 8 echo   !magenta!Летопись завершена. Этерия помнит все ваши пути.!reset!
call :PAUSE
goto MAIN_MENU

:: Название и подсказка для концовки по номеру
:ENDING_META
set "em_name="
set "em_hint="
if "%~1"=="1" (set "em_name=Рассвет Этерии"        & set "em_hint=свет нужно встретить светом")
if "%~1"=="2" (set "em_name=Охотник на теней"      & set "em_hint=иногда лучший ответ - клинок")
if "%~1"=="3" (set "em_name=Рассвет дорогой ценой" & set "em_hint=алтарь без защиты требует сил")
if "%~1"=="4" (set "em_name=Пепел и свобода"       & set "em_hint=что, если осколок не достанется никому?")
if "%~1"=="5" (set "em_name=Король Теней"          & set "em_hint=Тень предлагает сделку")
if "%~1"=="6" (set "em_name=Сожжённый светом"      & set "em_hint=алтарь не прощает слабых")
if "%~1"=="7" (set "em_name=Тьма победила"         & set "em_hint=не каждый бой кончается победой")
if "%~1"=="8" (set "em_name=Слишком поздно"        & set "em_hint=время тоже враг")
goto :eof

:COUNT_ENDINGS
set "e_cnt=0"
for /l %%i in (1,1,8) do if "!e%%i!"=="1" set /a e_cnt+=1
goto :eof

:LOAD_PROGRESS
for /l %%i in (1,1,8) do set "e%%i=0"
if not exist "!PROG!" goto :eof
for /f "usebackq tokens=1* delims=:" %%a in ("!PROG!") do (
    if /i "%%a"=="speed" set "tw_delay=%%b"
    for /l %%i in (1,1,8) do if /i "%%a"=="e%%i" if "%%b"=="1" set "e%%i=1"
)
set /a "tw_delay=tw_delay" 2>nul
if !tw_delay! LSS 0 set "tw_delay=18"
if !tw_delay! GTR 100 set "tw_delay=18"
goto :eof

:SAVE_PROGRESS
(
    echo speed:!tw_delay!
    for /l %%i in (1,1,8) do echo e%%i:!e%%i!
) > "!PROG!" 2>nul
goto :eof

:NEW_GAME
call :INIT_STATE
goto CHARACTER_CREATION

:LOAD_GAME
if not exist "!SAVE!" (
    echo.
    echo !red!  Сохранение не найдено.!reset!
    call :WAIT 2
    goto MAIN_MENU
)
call :INIT_STATE
for /f "usebackq tokens=1* delims=:" %%a in ("!SAVE!") do (
    if /i "%%a"=="player_name"  set "player_name=%%b"
    if /i "%%a"=="player_class" set "player_class=%%b"
    if /i "%%a"=="hp"           set "hp=%%b"
    if /i "%%a"=="hours"        set "hours=%%b"
    if /i "%%a"=="q_tavern"     set "q_tavern=%%b"
    if /i "%%a"=="q_east"       set "q_east=%%b"
    if /i "%%a"=="q_lib"        set "q_lib=%%b"
    if /i "%%a"=="has_key"      set "has_key=%%b"
    if /i "%%a"=="has_amulet"   set "has_amulet=%%b"
    if /i "%%a"=="knows_weak"   set "knows_weak=%%b"
)
call :VALIDATE_STATE
set "tw=С возвращением, !player_name!. Осколок всё ещё тёплый у вас в ладони."
call :TWC
call :WAIT 1
goto HUB

:: Защита от повреждённого или отредактированного сохранения
:VALIDATE_STATE
if not defined player_name set "player_name=Странник"
if not "!player_class!"=="Маг" if not "!player_class!"=="Вор" set "player_class=Воин"
set /a "hp=hp" 2>nul
set /a "hours=hours" 2>nul
if !hp! LSS 1 set "hp=1"
if !hp! GTR !maxhp! set "hp=!maxhp!"
if !hours! LSS 1 set "hours=1"
if !hours! GTR 7 set "hours=7"
for %%v in (q_tavern q_east q_lib has_key has_amulet knows_weak) do (
    if not "!%%v!"=="1" set "%%v=0"
)
goto :eof


:: =========================================================
:: СОЗДАНИЕ ПЕРСОНАЖА И ВСТУПЛЕНИЕ
:: =========================================================
:CHARACTER_CREATION
cls
echo.
echo !blue!===============================================!reset!
echo   СОЗДАНИЕ ПЕРСОНАЖА
echo !blue!===============================================!reset!
echo.
set "player_name="
set /p "player_name=  Как вас зовут, путник? "
if not defined player_name set "player_name=Странник"
echo.
echo   Выберите класс:
echo   [1] Воин - получает на 1 урон меньше, бьёт сильно и стабильно
echo       приём: Сокрушающий удар
echo   [2] Маг  - слабее в ближнем бою, но мощный Огненный шар
echo   [3] Вор  - крит-удары, Удар в спину оглушает врага
echo.
call :CHOOSE /c 123 /n /m "  Ваш выбор: "
set "cc=%errorlevel%"
set "player_class=Воин"
if !cc! GEQ 2 set "player_class=Маг"
if !cc! GEQ 3 set "player_class=Вор"

:INTRO
cls
echo.
set "tw=Ночь. Этерия спит, но небо над городом темнеет, будто на звёзды пролили чернила."
call :TW
echo.
set "tw=В тёмном переулке чья-то рука хватает вас за рукав. Это старый картограф Орин, и пальцы у него холодные как лёд."
call :TW
echo.
set "tw=Слушай внимательно, !player_name!. Тень проснулась. Она идёт за этим."
call :TWY
echo.
set "tw=Он вкладывает вам в ладонь осколок лунного камня. Камень тёплый и пульсирует, как маленькое сердце."
call :TW
echo.
set "tw=Отнеси его на алтарь Шпиля до рассвета. В таверне тебя ждёт человек с ключом. Пароль для него: Рассвет. Запомни его, второго раза я не повторю."
call :TWY
echo.
set "tw=Глаза Орина гаснут. На стене переулка проступает длинная тень, и она двигается сама по себе."
call :TW
echo.
set "tw=Цель: донести осколок до алтаря на вершине Шпиля. До рассвета осталось !hours! часов."
call :TWC
call :PAUSE
goto HUB


:: =========================================================
:: ПЛОЩАДЬ - ГЛАВНЫЙ ХАБ
:: =========================================================
:HUB
set "current_location=Площадь Этерии"
cls
call :HUD
echo.
if !hours! LEQ 2 echo !red!  Небо на востоке уже бледнеет. Времени почти не осталось.!reset!
set "m1="
set "m2="
set "m3="
if "!q_tavern!"=="1" set "m1= !green![выполнено]!reset!"
if "!q_east!"=="1" set "m2= !green![выполнено]!reset!"
if "!q_lib!"=="1" set "m3= !green![выполнено]!reset!"
echo   Куда пойдёте?
echo.
echo   [1] Таверна «Ржавый якорь»!m1!
echo   [2] Восточный квартал: там кто-то стережёт амулет!m2!
echo   [3] Старая библиотека: загадки Хранителя!m3!
echo   [4] Врата Шпиля - туда лучше идти подготовленным
echo   [5] Отдохнуть у фонтана: +6 HP, минус 1 час
echo   [6] Меню: статус и сохранение
echo.
call :CHOOSE /c 123456 /n /m "  Ваш выбор: "
if errorlevel 6 goto PAUSE_MENU
if errorlevel 5 goto REST
if errorlevel 4 goto GATE
if errorlevel 3 goto LIBRARY
if errorlevel 2 goto EAST
goto TAVERN

:REST
if !hp! GEQ !maxhp! (
    set "tw=Вы и так полны сил. Тратить драгоценный час на отдых незачем."
    call :TWC
    call :PAUSE
    goto HUB
)
set /a hp+=6
if !hp! GTR !maxhp! set "hp=!maxhp!"
set /a hours-=1
set "tw=Вы умываетесь ледяной водой из фонтана. Силы возвращаются, но время утекает сквозь пальцы."
call :TW
if !hours! LEQ 0 goto END_LATE
call :PAUSE
goto HUB

:PAUSE_MENU
cls
call :HUD
echo.
echo   [1] Статус и заметки
echo   [2] Сохранить игру
echo   [3] В главное меню без сохранения
echo   [4] Назад
echo.
call :CHOOSE /c 1234 /n /m "  Ваш выбор: "
if errorlevel 4 goto HUB
if errorlevel 3 goto MAIN_MENU
if errorlevel 2 goto SAVE_GAME
goto VIEW_STATUS

:VIEW_STATUS
cls
echo.
echo !blue!===============================================!reset!
echo   СТАТУС И ЗАМЕТКИ
echo !blue!===============================================!reset!
echo.
echo   Имя:    !white!!player_name!!reset!
echo   Класс:  !white!!player_class!!reset!
echo   HP:     !hp!/!maxhp!
echo   Время до рассвета: !hours! ч.
echo.
echo   Инвентарь:
echo     - Осколок Луны
if "!has_key!"=="1" echo     - Ключ от Врат Шпиля
if "!has_amulet!"=="1" echo     - Амулет Света: враги бьют вас на 1 слабее
if "!knows_weak!"=="1" echo     - Знание: слабость Тени, +2 урона по Тени
echo.
set "s1=!red!не выполнено!reset!"
set "s2=!red!не выполнено!reset!"
set "s3=!red!не выполнено!reset!"
if "!q_tavern!"=="1" set "s1=!green!выполнено!reset!"
if "!q_east!"=="1" set "s2=!green!выполнено!reset!"
if "!q_lib!"=="1" set "s3=!green!выполнено!reset!"
echo   Задания:
echo     Человек в таверне: !s1!
echo     Страж в восточном квартале: !s2!
echo     Загадки Хранителя: !s3!
echo.
echo   Заметки:
echo     - Орин велел донести осколок до алтаря до рассвета.
if not "!q_tavern!"=="1" echo     - Пароль для человека в таверне назвал Орин. Вспомните его.
if "!has_key!"=="1" echo     - Ключ откроет Врата Шпиля без загадок.
if not "!has_key!"=="1" echo     - Без ключа Врата потребуют ответить на две загадки.
if not "!knows_weak!"=="1" echo     - Хранитель библиотеки знает, куда бить Тень.
if not "!has_amulet!"=="1" echo     - Говорят, только свет Амулета гонит Тень от алтаря.
if !hours! LEQ 2 echo     !red!- Рассвет близко. Пора идти к Вратам.!reset!
call :PAUSE
goto PAUSE_MENU

:SAVE_GAME
(
    echo player_name:!player_name!
    echo player_class:!player_class!
    echo hp:!hp!
    echo hours:!hours!
    echo q_tavern:!q_tavern!
    echo q_east:!q_east!
    echo q_lib:!q_lib!
    echo has_key:!has_key!
    echo has_amulet:!has_amulet!
    echo knows_weak:!knows_weak!
) > "!SAVE!" 2>nul || (
    echo.
    echo !red!  Не удалось записать сохранение. Проверьте права на папку игры.!reset!
    call :WAIT 3
    goto PAUSE_MENU
)
echo.
echo !green!  Прогресс сохранён: savegame.cfg рядом с игрой.!reset!
call :WAIT 2
goto PAUSE_MENU


:: =========================================================
:: КВЕСТ 1: ТАВЕРНА (ПАРОЛЬ)
:: =========================================================
:TAVERN
if "!q_tavern!"=="1" (
    set "tw=Таверна почти опустела. Только огонь трещит в камине, а хозяин протирает кружку и не смотрит на вас."
    call :TW
    call :PAUSE
    goto HUB
)
set "current_location=Таверна Ржавый якорь"
set /a hours-=1
if !hours! LEQ 0 goto END_LATE
cls
call :HUD
echo.
set "walk_end="
call :ANIM_WALK
echo.
set "tw=Дверь таверны распахивается с протяжным скрипом. Внутри пахнет дымом и пивом, а в самом тёмном углу сидит человек в капюшоне и вертит на цепочке ключ."
call :TW
if "!player_class!"=="Воин" set "tw=Рука сама ложится на рукоять меча. Этот человек ждёт именно вас."
if "!player_class!"=="Маг" set "tw=Воздух вокруг незнакомца дрожит. Ключ пропитан старой магией."
if "!player_class!"=="Вор" set "tw=Вы оцениваете замок на цепочке и пути отхода быстрее, чем успеваете моргнуть."
call :TWC
echo.
set "tw=Незнакомец поднимает голову. Из-под капюшона блестят глаза. Пароль."
call :TWY

:TAV_ASK
echo.
echo   [1] «Рассвет»
echo   [2] «Луна»
echo   [3] «Тень»
echo   [4] Не отвечать и действовать по-своему: минус 1 час
echo.
call :CHOOSE /c 1234 /n /m "  Ваш ответ: "
if errorlevel 4 goto TAV_OWN
if errorlevel 3 goto TAV_WRONG
if errorlevel 2 goto TAV_WRONG
goto TAV_OK

:TAV_WRONG
set "tw=Неверно. Незнакомец вскакивает, и нож рассекает вам плечо."
call :TWR
set "dmg=3"
call :HURT
if !hp! LEQ 0 goto END_DEAD
set "tw=Ещё раз. И подумайте получше."
call :TWY
goto TAV_ASK

:TAV_OK
set "tw=Верно. Орин не ошибался в людях."
call :TWY
set "has_key=1"
set "q_tavern=1"
set "tw=Он бросает вам ключ с выгравированным шпилем. Это ключ от Врат. И ещё: в восточном квартале бродит Страж Тени. На нём Амулет Света. А в старой библиотеке живёт Хранитель, он знает слабость самой Тени."
call :TWY
echo.
set "tw=Получен предмет: Ключ от Врат Шпиля."
call :TWC
call :PAUSE
goto HUB

:TAV_OWN
set /a hours-=1
if !hours! LEQ 0 goto END_LATE
if "!player_class!"=="Воин" set "tw=Вы выбиваете табурет из-под незнакомца и прижимаете клинок к его горлу. Через минуту он сам отдаёт ключ, ворча сквозь зубы."
if "!player_class!"=="Маг" set "tw=Вы шепчете слово, и разум незнакомца раскрывается, как кошелёк. Вы находите в нём и пароль, и тайник, где он прячет ключ. На всё уходит целый час."
if "!player_class!"=="Вор" set "tw=Пока незнакомец ломает голову над вашим молчанием, ваши пальцы уже расстёгивают цепочку. Тихо и чисто, но среди толпы быстро не получается."
call :TW
set "has_key=1"
set "q_tavern=1"
set "tw=Уходя, вы слышите шёпот посетителей: в восточном квартале Страж Тени носит Амулет Света, а в старой библиотеке живёт Хранитель загадок."
call :TWY
echo.
set "tw=Получен предмет: Ключ от Врат Шпиля."
call :TWC
call :PAUSE
goto HUB


:: =========================================================
:: КВЕСТ 2: ВОСТОЧНЫЙ КВАРТАЛ (СТРАЖ ТЕНИ, БОЙ)
:: =========================================================
:EAST
if "!q_east!"=="1" (
    set "tw=Переулки пусты. Только ветер перебирает мусор и шепчет что-то на старом языке."
    call :TW
    call :PAUSE
    goto HUB
)
set "current_location=Восточный квартал"
set /a hours-=1
if !hours! LEQ 0 goto END_LATE
cls
call :HUD
echo.
set "walk_end="
call :ANIM_WALK
echo.
set "tw=Восточный квартал замер. Окна заколочены, а из подворотни тянет могильным холодом."
call :TW
set "tw=Из тени выходит Страж Тени, дым в ржавых доспехах. На его груди светится золотой амулет."
call :TW
set "tw=Назад. Или станешь тенью."
call :TWR
echo.
echo   [1] Сразиться
echo   [2] Обойти сзади
echo   [3] Применить особый навык класса: минус 1 час
echo.
call :CHOOSE /c 123 /n /m "  Ваш выбор: "
if errorlevel 3 goto EAST_SKILL
if errorlevel 2 goto EAST_SNEAK

:EAST_FIGHT
set "en_name=Страж Тени"
set "en_type=guard"
set "en_hp=14"
set "en_max=14"
set "en_min=2"
set "en_rng=2"
set "can_flee=1"
call :FIGHT
if "!fight_res!"=="dead" goto END_DEAD
if "!fight_res!"=="flee" goto EAST_FLED
echo.
set "tw=Последний удар рвёт доспехи, и Страж рассыпается пеплом."
call :TW
goto EAST_WIN

:EAST_FLED
set /a hours-=1
set "tw=Вы отступаете в переулок. Страж не преследует, но время потеряно, а на его груди всё так же светится амулет."
call :TW
if !hours! LEQ 0 goto END_LATE
call :PAUSE
goto HUB

:EAST_SNEAK
if "!player_class!"=="Вор" (
    set "tw=Вы растворяетесь в тенях лучше самой тени. Один неслышный шаг, одно движение пальцев, и амулет уже у вас."
    call :TW
    goto EAST_WIN
)
set /a hours-=1
if !hours! LEQ 0 goto END_LATE
set "dmg=3"
set "tw=Вы крадётесь, но каждый шаг гремит, как колокол. Вы всё-таки добираетесь до амулета, потеряв и время, и немного крови."
call :TW
call :HURT
if !hp! LEQ 0 goto END_DEAD
goto EAST_WIN

:EAST_SKILL
set /a hours-=1
if !hours! LEQ 0 goto END_LATE
if "!player_class!"=="Воин" set "tw=Вы издаёте боевой клич. Страж вздрагивает и отступает, а вы одним движением срываете амулет."
if "!player_class!"=="Маг" set "tw=Вы вызываете вспышку чистого света. Страж воет и рассыпается, не успев поднять руку."
if "!player_class!"=="Вор" set "tw=Дымовая шашка скрывает вас, и когда дым рассеивается, амулет уже висит на вашем поясе, а Страж топчется на месте."
call :TW
goto EAST_WIN

:EAST_WIN
set "has_amulet=1"
set "q_east=1"
echo.
set "tw=Получен предмет: Амулет Света. Он тёплый на ощупь, и тьма вокруг будто робко отступает. Теперь враги бьют вас слабее."
call :TWC
call :PAUSE
goto HUB


:: =========================================================
:: КВЕСТ 3: БИБЛИОТЕКА (ТРИ ЗАГАДКИ)
:: =========================================================
:LIBRARY
if "!q_lib!"=="1" (
    set "tw=Хранитель дремлет в кресле среди пыльных страниц. Всё, что мог, он уже рассказал."
    call :TW
    call :PAUSE
    goto HUB
)
set "current_location=Старая библиотека"
set /a hours-=1
if !hours! LEQ 0 goto END_LATE
cls
call :HUD
echo.
set "walk_end="
call :ANIM_WALK
echo.
set "tw=Старая библиотека пахнет пылью и забытыми именами. Между стеллажами парит призрачный Хранитель, и вместо глаз у него две свечи."
call :TW
set "tw=Живые давно сюда не заходили. Ответь на три загадки, и я открою тебе то, что книги знают про Тень. Двух верных ответов хватит."
call :TWY
set "wis=0"
set "lib_n=0"

:LIB_LOOP
set /a lib_n+=1
echo.
echo !gray!  Загадка !lib_n! из 3!reset!
call :ASK_RIDDLE
if "!rid_ok!"=="1" (
    set /a wis+=1
    set "tw=Верно."
    call :TWY
) else (
    set "tw=Нет. Правильный ответ: !rans!."
    call :TWR
)
if !lib_n! LSS 3 goto LIB_LOOP
if !wis! LSS 2 goto LIB_FAIL
set "knows_weak=1"
set "q_lib=1"
echo.
set "tw=Хранитель улыбается. Тень повторяет того, кто на неё смотрит, и потому боится собственного лица. Теперь вы знаете, куда бить."
call :TWY
set "tw=Получено знание: слабость Тени. Ваши удары по ней сильнее на 2."
call :TWC
if !wis! EQU 3 (
    set /a hp+=4
    if !hp! GTR !maxhp! set "hp=!maxhp!"
    set "tw=За безупречные ответы Хранитель дарит вам глоток лунного света. Раны затягиваются, +4 HP."
    call :TWC
)
call :PAUSE
goto HUB

:LIB_FAIL
set "tw=Хранитель качает головой. Ты ещё не готов. Приходи, когда наберёшься ума."
call :TWY
call :PAUSE
goto HUB


:: =========================================================
:: ВРАТА ШПИЛЯ (КЛЮЧ ИЛИ ЗАГАДКИ)
:: =========================================================
:GATE
set "current_location=Врата Шпиля"
set /a hours-=1
if !hours! LEQ 0 goto END_LATE
cls
call :HUD
echo.
set "walk_end="
call :ANIM_WALK
echo.
set "tw=У подножия Шпиля стоят Врата из чёрного камня. На них проступает лицо, высеченное из тени, и оно открывает рот."
call :TW
set "gate_need=2"
set "gate_bonus=0"
if "!has_key!"=="1" goto GATE_CHOICE
set "tw=Ключа у тебя нет. Тогда докажи, что достоин. Ответь верно на две загадки. За каждую ошибку заплатишь болью."
call :TWY
goto GATE_LOOP

:GATE_CHOICE
set "tw=Ключ на твоём поясе подходит. Но я люблю умных гостей. Хочешь ответить на загадку?"
call :TWY
echo.
echo   [1] Открыть ключом
echo   [2] Ответить на загадку и получить благословение Врат: +5 HP
echo.
call :CHOOSE /c 12 /n /m "  Ваш выбор: "
if errorlevel 2 goto GATE_BONUS
goto GATE_OPEN

:GATE_BONUS
set "gate_bonus=1"
set "gate_need=1"

:GATE_LOOP
echo.
call :ASK_RIDDLE
if "!rid_ok!"=="1" goto GATE_RIGHT

:GATE_WRONG
set "tw=Неверно. Эхо удара прокатывается по камню и бьёт вас в грудь."
call :TWR
set "dmg=3"
call :HURT
if !hp! LEQ 0 goto END_DEAD
goto GATE_LOOP

:GATE_RIGHT
set /a gate_need-=1
if !gate_need! GTR 0 (
    set "tw=Верно. Но этого мало. Ещё одна."
    call :TWY
    goto GATE_LOOP
)
set "tw=Верно. Лицо на вратах усмехается, и камень бесшумно расходится."
call :TWY
if not "!gate_bonus!"=="1" goto FINALE
set /a hp+=5
if !hp! GTR !maxhp! set "hp=!maxhp!"
set "tw=Врата дарят вам тёплое благословение. Раны затягиваются, +5 HP."
call :TWC
goto FINALE

:GATE_OPEN
set "tw=Ключ ложится в замочную скважину, и по камню бежит золотая трещина. Врата распахиваются."
call :TWC


:: =========================================================
:: ФИНАЛ: ВЕРШИНА ШПИЛЯ
:: =========================================================
:FINALE
call :PAUSE
set "current_location=Вершина Шпиля"
cls
call :HUD
echo.
set "tw=Вы поднимаетесь по бесконечной лестнице. На вершине стоит алтарь, а над ним дышит пустота."
call :TW
set "tw=Из пустоты поднимается Тень. У неё ваше лицо."
call :TW
if "!player_class!"=="Воин" set "tw=Ваш меч дрожит, но вы не опускаете его."
if "!player_class!"=="Маг" set "tw=Магия вокруг вас гудит, как натянутая струна."
if "!player_class!"=="Вор" set "tw=Вы ищете путь к отступлению и понимаете, что его нет."
call :TWC
if "!has_amulet!"=="1" (
    set "tw=Амулет на вашей груди вспыхивает, и Тень отшатывается на шаг."
    call :TWC
)
if "!knows_weak!"=="1" (
    set "tw=Вы видите её слабое место так ясно, будто оно подсвечено."
    call :TWC
)
echo.
set "tw=Ты принёс мне осколок. Как мило. Отдай его, и я оставлю город в покое. Или умри, сжимая камень."
call :TWR
echo.
echo   [1] Положить осколок на алтарь
echo   [2] Отдать осколок Тени
echo   [3] Разбить осколок
echo   [4] Сразиться с Тенью
echo.
call :CHOOSE /c 1234 /n /m "  Ваш выбор: "
if errorlevel 4 goto END_FIGHT
if errorlevel 3 goto END_ASHES
if errorlevel 2 goto END_DARK

:END_ALTAR
if "!has_amulet!"=="1" goto END_BEST
if !hp! GEQ 10 goto END_PYRRHIC
goto END_BURN

:END_FIGHT
set "en_name=Тень"
set "en_type=boss"
set "en_hp=30"
set "en_max=30"
set "en_min=3"
set "en_rng=3"
set "can_flee=0"
call :FIGHT
if "!fight_res!"=="dead" goto END_DEAD
cls
echo.
set "tw=Последний удар разрывает Тень на тысячу чёрных нитей. Они гаснут одна за другой, и тишина падает на Шпиль, как снег."
call :TWC
set "tw=Осколок остаётся на алтаре, тёплый и целый. Рассвет придёт сам, и вам не придётся отдавать за него ничего, кроме усталости."
call :TW
set "ending=Охотник на теней"
set "ending_id=2"
goto THE_END

:END_BEST
cls
echo.
set "tw=Осколок ложится на алтарь, и амулет на вашей груди вспыхивает ему в ответ. Свет поднимается столбом до самых звёзд."
call :TWC
set "tw=Тень кричит вашим голосом и тает, как дым на ветру."
call :TW
set "tw=Первый луч рассвета касается Шпиля. Этерия просыпается, не зная, кто её спас."
call :TW
set "ending=Рассвет Этерии"
set "ending_id=1"
goto THE_END

:END_PYRRHIC
cls
echo.
set "tw=Осколок ложится на алтарь, но света не хватает. Тень цепляется за вас когтями из дыма, и вы платите за рассвет почти всем, что у вас было."
call :TW
set "tw=Вы выживаете. Город тоже. Но вы больше никогда не будете спать спокойно."
call :TW
set "hp=2"
set "ending=Рассвет дорогой ценой"
set "ending_id=3"
goto THE_END

:END_BURN
cls
echo.
set "tw=Осколок вспыхивает, но у вас слишком мало сил, чтобы удержать свет. Он обжигает вас изнутри."
call :TWR
set "tw=Алтарь гаснет. Тень улыбается вашим лицом."
call :TW
set "hp=0"
set "end_bad=1"
set "ending=Сожжённый светом"
set "ending_id=6"
goto THE_END

:END_DARK
cls
echo.
set "tw=Вы протягиваете осколок. Тень берёт его почти нежно. Тьма сворачивается у вас в груди, и вы вдруг понимаете, что больше не боитесь ночи."
call :TW
set "tw=Этерия никогда не увидит рассвета, зато у неё появится новый властелин."
call :TWR
set "ending=Король Теней"
set "ending_id=5"
goto THE_END

:END_ASHES
cls
echo.
set "tw=Вы с размаху бьёте осколком об алтарь. Камень разлетается лунной пылью. Тень воет, но и свет гаснет."
call :TW
set "tw=Рассвет всё равно приходит, серый и тихий, без магии. Этерия станет обычным городом. Возможно, так даже лучше."
call :TW
set "ending=Пепел и свобода"
set "ending_id=4"
goto THE_END

:END_DEAD
cls
echo.
set "tw=Тьма смыкается над вами. Последнее, что вы слышите, тихий смех Тени."
call :TWR
set "hp=0"
set "end_bad=1"
set "ending=Тьма победила"
set "ending_id=7"
goto THE_END

:END_LATE
cls
echo.
set "tw=Первый луч касается Шпиля, и Тень улыбается. Ей больше нечего бояться: вы опоздали."
call :TWR
set "end_bad=1"
set "ending=Слишком поздно"
set "ending_id=8"
goto THE_END

:THE_END
echo.
echo !yellow!===============================================!reset!
if "!end_bad!"=="1" (
    echo !red!  КОНЦОВКА: !ending!!reset!
) else (
    set "rb_shift=0"
    set "rb_text=  КОНЦОВКА: !ending!"
    call :RAINBOW
)
echo !yellow!===============================================!reset!
echo.
set "e_new=0"
for %%i in (!ending_id!) do if not "!e%%i!"=="1" (
    set "e_new=1"
    set "e%%i=1"
)
if "!e_new!"=="1" call :SAVE_PROGRESS
call :COUNT_ENDINGS
echo   Исход !ending_id! из 8. Осталось часов: !hours!, HP: !hp!/!maxhp!
if "!e_new!"=="1" (
    echo   !magenta!Новая запись в Летописи концовок: открыто !e_cnt! из 8.!reset!
) else (
    echo   !gray!Эта концовка уже есть в Летописи: открыто !e_cnt! из 8.!reset!
)
if !e_cnt! EQU 8 if "!e_new!"=="1" echo   !yellow!Вы открыли все исходы Этерии. Спасибо за игру.!reset!
:: В режиме автотестов игра завершается сразу после исхода
if "!ETHERIA_TEST!"=="1" exit /b 0
echo.
echo   [1] Сыграть заново
echo   [2] В главное меню
echo.
call :CHOOSE /c 12 /n /m "  Ваш выбор: "
if errorlevel 2 goto MAIN_MENU
goto NEW_GAME

:END_GAME
echo.
echo   До встречи, !player_name!.
call :WAIT 2
endlocal
exit /b 0


:: =========================================================
:: БОЕВАЯ СИСТЕМА
:: Вход: en_name, en_type (guard или boss), en_hp, en_max, en_min, en_rng, can_flee
:: Выход: fight_res = win, dead или flee
:: =========================================================
:FIGHT
call :SET_CLASS_ID
set "cd=0"
set "en_stun=0"
set "round=0"
set "fight_res="

:FIGHT_ROUND
set /a round+=1
cls
call :HUD
echo.
call :ENEMY_BAR
set "enemy=!en_type!"
set "pact=idle"
set "eact=idle"
set "result=none"
set "pdmg=0"
set "edmg=0"
set "pblock=0"
set "crit=0"
call :SCENE
echo.
echo   Раунд !round!. Ваш ход:
echo   [1] Атака
echo   [2] Защита: урон по вам вдвое меньше
if !cd! LEQ 0 (
    echo   [3] Особый приём: !sp_name! - готов
) else (
    echo   [3] Особый приём: !sp_name! - будет готов через !cd! ход.
)
if "!can_flee!"=="1" (
    echo   [4] Бежать: шанс !flee_pct! из 100, при провале враг бьёт без защиты
) else (
    echo   [4] Бежать некуда
)
echo.

:FIGHT_ASK
call :CHOOSE /c 1234 /n /m "  Ваш выбор: "
set "ch=%errorlevel%"
set "pact=attack"
if !ch! GEQ 2 set "pact=block"
if !ch! GEQ 3 set "pact=special"
if !ch! GEQ 4 set "pact=flee"
if "!pact!"=="special" if !cd! GTR 0 (
    echo !red!  Приём ещё не готов.!reset!
    goto FIGHT_ASK
)
if "!pact!"=="flee" if not "!can_flee!"=="1" (
    echo !red!  Бежать некуда.!reset!
    goto FIGHT_ASK
)

set "cr=100"
if "!pact!"=="attack" goto ACT_ATTACK
if "!pact!"=="block" goto ACT_BLOCK
if "!pact!"=="special" goto ACT_SPECIAL
goto ACT_FLEE

:ACT_ATTACK
set /a "pdmg=pa_min + (%random% %% pa_rng)"
if "!class_id!"=="thief" set /a "cr=%random% %% 100"
if !cr! LSS 30 set /a "pdmg*=2"
if !cr! LSS 30 set "crit=1"
goto PLAYER_DONE

:ACT_BLOCK
set "pblock=1"
if !cd! GTR 0 set /a cd-=1
goto PLAYER_DONE

:ACT_SPECIAL
set "cd=3"
if "!class_id!"=="warrior" set /a "pdmg=6 + (%random% %% 4)"
if "!class_id!"=="mage" set /a "pdmg=6 + (%random% %% 3)"
if "!class_id!"=="thief" set /a "pdmg=5 + (%random% %% 2)"
if "!class_id!"=="thief" set "en_stun=1"
goto PLAYER_DONE

:ACT_FLEE
set /a "fr=%random% %% 100"
set "pact=flee_fail"
if !fr! LSS !flee_pct! set "pact=flee_ok"

:PLAYER_DONE
if !pdmg! GTR 0 if "!en_type!"=="boss" if "!knows_weak!"=="1" set /a pdmg+=2
set /a en_hp-=pdmg
if !en_hp! LSS 0 set "en_hp=0"
if !en_hp! LEQ 0 goto ROUND_WIN
if "!pact!"=="flee_ok" goto ROUND_FLED
if "!en_stun!"=="1" goto ENEMY_STUNNED

set /a "edmg=en_min + (%random% %% en_rng)"
set /a "rm=round %% 4"
if "!en_type!"=="boss" if !rm! EQU 0 set /a edmg+=3
if "!pblock!"=="1" set /a "edmg=edmg/2"
set "dmg=!edmg!"
call :CALC_DMG
set "edmg=!dmg!"
set "eact=attack"
goto ROUND_RESOLVE

:ENEMY_STUNNED
set "en_stun=0"
set "eact=stun"
set "edmg=0"

:ROUND_RESOLVE
set /a "hp_after=hp-edmg"
set "result=none"
if !hp_after! LEQ 0 set "result=lose"
call :SCENE
call :LOG_PLAYER
call :LOG_ENEMY
set "hp=!hp_after!"
if !hp! LSS 0 set "hp=0"
if "!result!"=="lose" (
    echo !red!  Вы падаете на колени.!reset!
    call :PAUSE
    set "fight_res=dead"
    goto :eof
)
if !cd! GTR 0 set /a cd-=1
call :PAUSE
goto FIGHT_ROUND

:ROUND_WIN
set "eact=none"
set "result=win"
call :SCENE
call :LOG_PLAYER
echo !green!  !en_name! повержен.!reset!
call :PAUSE
set "fight_res=win"
goto :eof

:ROUND_FLED
set "eact=none"
set "result=flee"
call :SCENE
echo !yellow!  Вам удалось сбежать.!reset!
call :PAUSE
set "fight_res=flee"
goto :eof

:LOG_PLAYER
if "!pact!"=="attack" if not "!crit!"=="1" echo !green!  Вы бьёте и наносите !pdmg! урона.!reset!
if "!pact!"=="attack" if "!crit!"=="1" echo !yellow!  Критический удар. Вы наносите !pdmg! урона.!reset!
if "!pact!"=="block" echo !cyan!  Вы закрываетесь и готовитесь к удару.!reset!
if "!pact!"=="special" echo !magenta!  !sp_name!. Вы наносите !pdmg! урона.!reset!
if "!pact!"=="flee_fail" echo !red!  Сбежать не удалось.!reset!
goto :eof

:LOG_ENEMY
if "!eact!"=="stun" echo !cyan!  !en_name! оглушён и пропускает ход.!reset!
if "!eact!"=="attack" if "!pblock!"=="1" echo !cyan!  Блок смягчает удар: !en_name! наносит !edmg! урона.!reset!
if "!eact!"=="attack" if not "!pblock!"=="1" echo !red!  !en_name! бьёт вас на !edmg! урона.!reset!
if "!eact!"=="attack" if "!en_type!"=="boss" if !rm! EQU 0 echo !red!  Тень обрушивает тьму всей силой.!reset!
goto :eof

:ENEMY_BAR
set /a "eb=(en_hp*20+en_max-1)/en_max"
set "ebar="
for /l %%i in (1,1,20) do if %%i LEQ !eb! (set "ebar=!ebar!#") else (set "ebar=!ebar!-")
echo   !red!!en_name!!reset!  HP: !red![!ebar!]!reset! !en_hp!/!en_max!
goto :eof

:SET_CLASS_ID
set "class_id=warrior"
set "pa_min=3"
set "pa_rng=3"
set "flee_pct=40"
set "sp_name=Сокрушающий удар"
if "!player_class!"=="Маг" (
    set "class_id=mage"
    set "pa_min=2"
    set "pa_rng=3"
    set "flee_pct=50"
    set "sp_name=Огненный шар"
)
if "!player_class!"=="Вор" (
    set "class_id=thief"
    set "pa_min=2"
    set "pa_rng=4"
    set "flee_pct=75"
    set "sp_name=Удар в спину"
)
goto :eof


:: =========================================================
:: ЗАГАДКИ
:: =========================================================
:INIT_RIDDLES
set "r1_q=Я не живая, но расту. У меня нет лёгких, но мне нужен воздух. Вода - моя смерть. Что я?"
set "r1_1=Ветер"
set "r1_2=Огонь"
set "r1_3=Тень"
set "r1_ok=2"
set "r2_q=Без рта я кричу, без ушей слышу и повторяю чужие слова. Кто я?"
set "r2_1=Эхо"
set "r2_2=Ворон"
set "r2_3=Колокол"
set "r2_ok=1"
set "r3_q=Я иду за тобой весь день, но исчезаю во тьме. Что я?"
set "r3_1=Память"
set "r3_2=Эхо"
set "r3_3=Тень"
set "r3_ok=3"
set "r4_q=Чем больше из неё берёшь, тем больше она становится. Что это?"
set "r4_1=Яма"
set "r4_2=Гора"
set "r4_3=Колодец"
set "r4_ok=1"
set "r5_q=Что можно разбить, даже не прикоснувшись?"
set "r5_1=Тишину"
set "r5_2=Стекло"
set "r5_3=Меч"
set "r5_ok=1"
set "r6_q=Оно съедает всё: птиц, зверей, траву и деревья. Грызёт железо, перемалывает сталь, сносит города. Что это?"
set "r6_1=Огонь"
set "r6_2=Ржавчина"
set "r6_3=Время"
set "r6_ok=3"
set "r7_q=У меня есть города, но нет домов. Есть горы, но нет деревьев. Есть вода, но нет рыб. Что я?"
set "r7_1=Книга"
set "r7_2=Сон"
set "r7_3=Карта"
set "r7_ok=3"
set "r8_q=Утром я хожу на четырёх ногах, днём на двух, а вечером на трёх. Кто я?"
set "r8_1=Паук"
set "r8_2=Человек"
set "r8_3=Часы"
set "r8_ok=2"
goto :eof

:PICK_RIDDLE
set /a riddle_count+=1
if !riddle_count! GTR 8 (
    set "riddles_used=,"
    set "riddle_count=1"
)
:PICK_LOOP
set /a "rid=%random% %% 8 + 1"
if not "!riddles_used:,%rid%,=!"=="!riddles_used!" goto PICK_LOOP
set "riddles_used=!riddles_used!%rid%,"
goto :eof

:: Задаёт случайную загадку. Результат: rid_ok (1 или 0), rans (верный ответ)
:ASK_RIDDLE
call :PICK_RIDDLE
for %%i in (!rid!) do (
    set "tw=!r%%i_q!"
    set "ra1=!r%%i_1!"
    set "ra2=!r%%i_2!"
    set "ra3=!r%%i_3!"
    set "rok=!r%%i_ok!"
)
call :TWY
echo.
echo   [1] !ra1!
echo   [2] !ra2!
echo   [3] !ra3!
echo.
call :CHOOSE /c 123 /n /m "  Ваш ответ: "
set "pick=%errorlevel%"
set "rid_ok=0"
if "!pick!"=="!rok!" set "rid_ok=1"
for %%k in (!rok!) do set "rans=!ra%%k!"
goto :eof


:: =========================================================
:: ПОДПРОГРАММЫ
:: =========================================================
:INIT_STATE
set "player_name=Странник"
set "player_class=Воин"
set "maxhp=20"
set "hp=20"
set "hours=7"
set "q_tavern=0"
set "q_east=0"
set "q_lib=0"
set "has_key=0"
set "has_amulet=0"
set "knows_weak=0"
set "gate_bonus=0"
set "end_bad=0"
set "riddles_used=,"
set "riddle_count=0"
set "current_location=Площадь Этерии"
goto :eof

:HUD
set "hp_col=!green!"
if !hp! LEQ 12 set "hp_col=!yellow!"
if !hp! LEQ 6 set "hp_col=!red!"
set "bar="
for /l %%i in (1,1,20) do if %%i LEQ !hp! (set "bar=!bar!#") else (set "bar=!bar!-")
echo !blue!===============================================================!reset!
echo  !yellow!!player_name!!reset! / !magenta!!player_class!!reset!   HP: !hp_col![!bar!] !hp!/!maxhp!!reset!   До рассвета: !cyan!!hours! ч.!reset!
echo  Локация: !cyan!!current_location!!reset!
echo !blue!===============================================================!reset!
goto :eof

:: Урон dmg после защиты: Воин -1, Амулет Света -1
:CALC_DMG
if "!player_class!"=="Воин" if !dmg! GTR 1 set /a dmg-=1
if "!has_amulet!"=="1" if !dmg! GTR 1 set /a dmg-=1
goto :eof

:HURT
call :CALC_DMG
set /a hp-=dmg
if !hp! LSS 0 set "hp=0"
echo !red!  -!dmg! HP, осталось !hp!!reset!
goto :eof

:: Обёртка над choice: при ошибке ввода (код 255) спрашивает снова,
:: а в режиме автотестов завершает игру, когда записанный ввод кончился
:CHOOSE
choice %*
set "ch_rc=!errorlevel!"
if !ch_rc! EQU 255 if "!ETHERIA_TEST!"=="1" exit
if !ch_rc! EQU 255 goto CHOOSE
exit /b !ch_rc!

:WAIT
if "!ETHERIA_TEST!"=="1" goto :eof
timeout /t %~1 /nobreak >nul
goto :eof

:PAUSE
echo.
echo !gray!  [нажмите любую клавишу]!reset!
pause >nul
goto :eof


:: =========================================================
:: АНИМАЦИИ И ПЕЧАТАЮЩАЯ МАШИНКА (PowerShell внизу файла)
:: =========================================================
:ANIM_WALK
if "!nofx!"=="1" goto :eof
set "ps_mode=walk"
call :PSRUN
set "ps_mode=type"
goto :eof

:SCENE
if "!nofx!"=="1" goto :eof
call :SET_CLASS_ID
set "ps_mode=scene"
call :PSRUN
set "ps_mode=type"
goto :eof

:: Печатающая машинка. Текст берётся из переменной tw.
:TW
set "tw_color=!reset!"
goto TYPE_RUN
:TWY
set "tw_color=!yellow!"
goto TYPE_RUN
:TWR
set "tw_color=!red!"
goto TYPE_RUN
:TWC
set "tw_color=!cyan!"
:TYPE_RUN
:: Мгновенный режим и режим без PowerShell печатают строку сразу
set "tw_fast=0"
if "!nofx!"=="1" set "tw_fast=1"
if "!tw_delay!"=="0" set "tw_fast=1"
if "!tw_fast!"=="1" (
    echo   !tw_color!!tw!!reset!
    goto :eof
)
<nul set /p "=!tw_color!"
set "ps_mode=type"
call :PSRUN
<nul set /p "=!reset!"
goto :eof

:PSRUN
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText($env:SELF,[Text.Encoding]::UTF8); Invoke-Expression $s.Substring($s.LastIndexOf('#PSBEGIN'))"
goto :eof

exit /b 0

#PSBEGIN
$enc = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = $enc
$mode = $env:ps_mode
if (-not $mode) { $mode = 'type' }
$ESC = [string][char]27

# ---------------- спрайты ----------------
$P = @{
    stand  = @('   O   ', '  /|\  ', '  / \  ')
    walk1  = @('   O   ', '  /|\  ', '  /\   ')
    walk2  = @('   O   ', '  /|\  ', '   /\  ')
    up     = @('  \O/  ', '   |   ', '  / \  ')
    windup = @('   O  / ', '  /|\/  ', '  / \   ')
    strike = @('   O     ', '  /|\--->', '  / \    ')
    guard  = @('   O   ', '  [|]  ', '  / \  ')
    hurt   = @('  >O<  ', '  /|\  ', '  / \  ')
    dead   = @('         ', ' O====\_ ')
    none   = @()
}
$E = @{
    none  = @{ stand = @(); attack = @(); hurt = @(); stun = @(); dead = @() }
    guard = @{
        stand  = @('  ___  ', ' [o_o] ', ' /###\ ', '  | |  ')
        attack = @('  ___  ', ' [>_<] ', '<=###\ ', '  | |  ')
        hurt   = @('  ___  ', ' [x_x] ', ' /###\ ', '  | |  ')
        stun   = @(' * _ * ', ' [@_@] ', ' /###\ ', '  | |  ')
        dead   = @('       ', '  ___  ', ' [x_x] ', '_/###\_')
    }
    boss  = @{
        stand  = @('   .---.   ', '  / o o \  ', ' (   ^   ) ', '  \_vvv_/  ', '  /|   |\  ')
        attack = @('   .---.   ', '  / O O \  ', '<(  ---  )>', '  \_vvv_/  ', '  /|   |\  ')
        hurt   = @('   .---.   ', '  / x x \  ', ' (   ^   ) ', '  \_vvv_/  ', '  /|   |\  ')
        stun   = @(' *  .---. * ', '  / @ @ \  ', ' (   ~   ) ', '  \_vvv_/  ', '  /|   |\  ')
        dead   = @('           ', '           ', '    .--.   ', '  _/ xx \_ ', ' ~~~~~~~~~~ ')
    }
}

$W = 70
$H = 7
$PBASE = 3
$EBASE = 46

function Fr($pp, $pdx, $ep, $edx, $fx, $fxc, $fxr) {
    return @{ pp = $pp; pdx = $pdx; ep = $ep; edx = $edx; fx = $fx; fxc = $fxc; fxr = $fxr }
}

function Stamp($buf, $row, $col, $text) {
    if ($row -lt 0 -or $row -ge $buf.Length) { return }
    $line = $buf[$row]
    for ($i = 0; $i -lt $text.Length; $i++) {
        $c = $col + $i
        if ($c -ge 0 -and $c -lt $line.Length -and $text[$i] -ne ' ') { $line[$c] = $text[$i] }
    }
}

function PutSprite($buf, $sprite, $col, $bottom) {
    $h = $sprite.Count
    for ($i = 0; $i -lt $h; $i++) {
        $row = $bottom - ($h - 1) + $i
        Stamp $buf $row $col $sprite[$i]
    }
}

function Render($f, $en) {
    $buf = New-Object 'object[]' $H
    for ($r = 0; $r -lt $H; $r++) { $buf[$r] = (' ' * $W).ToCharArray() }
    Stamp $buf ($H - 1) 0 ('_' * $W)
    $bottom = $H - 2
    $ps = $P[$f.pp]
    $es = $E[$en][$f.ep]
    $pcol = $PBASE + $f.pdx
    $ecol = $EBASE + $f.edx
    PutSprite $buf $ps $pcol $bottom
    PutSprite $buf $es $ecol $bottom
    if ($f.fx) { Stamp $buf $f.fxr $f.fxc $f.fx }
    for ($r = 0; $r -lt $H; $r++) { [Console]::WriteLine((-join $buf[$r])) }
}

function Play($frames, $en, $delay) {
    [Console]::Write($ESC + '[?25l')
    for ($r = 0; $r -lt $H; $r++) { [Console]::WriteLine() }
    foreach ($f in $frames) {
        [Console]::Write($ESC + '[' + $H + 'A')
        Render $f $en
        if ($delay -gt 0) { Start-Sleep -Milliseconds $delay }
    }
    [Console]::Write($ESC + '[?25h')
}

# ---------------- последовательности боя ----------------
function Seq-Attack($dmg, $crit) {
    $t = '-' + $dmg
    if ($crit) { $t = 'КРИТ -' + $dmg }
    [void]$frames.Add((Fr 'windup' 0 'stand' 0 '' 0 0))
    [void]$frames.Add((Fr 'windup' 10 'stand' 0 '' 0 0))
    [void]$frames.Add((Fr 'strike' 24 'stand' 0 '' 0 0))
    [void]$frames.Add((Fr 'strike' 34 'hurt' 1 $t 50 0))
    [void]$frames.Add((Fr 'strike' 34 'hurt' -1 $t 50 0))
    [void]$frames.Add((Fr 'stand' 16 'stand' 0 '' 0 0))
    [void]$frames.Add((Fr 'stand' 0 'stand' 0 '' 0 0))
}

function Seq-Block {
    for ($k = 0; $k -lt 4; $k++) { [void]$frames.Add((Fr 'guard' 0 'stand' 0 '[ ]' 12 2)) }
}

function Seq-Special($cls, $dmg) {
    $t = '** -' + $dmg + ' **'
    if ($cls -eq 'mage') {
        [void]$frames.Add((Fr 'up' 0 'stand' 0 '*' 6 1))
        [void]$frames.Add((Fr 'up' 0 'stand' 0 '*' 10 2))
        for ($c = 12; $c -le 42; $c += 6) {
            [void]$frames.Add((Fr 'up' 0 'stand' 0 'o' $c 3))
        }
        [void]$frames.Add((Fr 'stand' 0 'hurt' 2 $t 48 0))
        [void]$frames.Add((Fr 'stand' 0 'hurt' -2 $t 48 0))
        [void]$frames.Add((Fr 'stand' 0 'hurt' 1 $t 48 0))
        [void]$frames.Add((Fr 'stand' 0 'stand' 0 '' 0 0))
    } elseif ($cls -eq 'thief') {
        [void]$frames.Add((Fr 'stand' 0 'stand' 0 '' 0 0))
        [void]$frames.Add((Fr 'none' 0 'stand' 0 '' 0 0))
        [void]$frames.Add((Fr 'none' 0 'stand' 0 '' 0 0))
        [void]$frames.Add((Fr 'stand' 55 'stand' 0 '' 0 0))
        [void]$frames.Add((Fr 'stand' 55 'hurt' 2 $t 48 0))
        [void]$frames.Add((Fr 'stand' 55 'hurt' -2 $t 48 0))
        [void]$frames.Add((Fr 'stand' 55 'stand' 0 '' 0 0))
        [void]$frames.Add((Fr 'none' 0 'stand' 0 '' 0 0))
        [void]$frames.Add((Fr 'stand' 0 'stand' 0 '' 0 0))
    } else {
        [void]$frames.Add((Fr 'windup' 0 'stand' 0 '' 0 0))
        [void]$frames.Add((Fr 'windup' 1 'stand' 0 '' 0 0))
        [void]$frames.Add((Fr 'windup' -1 'stand' 0 '' 0 0))
        [void]$frames.Add((Fr 'windup' 0 'stand' 0 '' 0 0))
        [void]$frames.Add((Fr 'strike' 20 'stand' 0 '' 0 0))
        [void]$frames.Add((Fr 'strike' 34 'hurt' 3 $t 48 0))
        [void]$frames.Add((Fr 'strike' 34 'hurt' -3 $t 48 0))
        [void]$frames.Add((Fr 'strike' 34 'hurt' 3 $t 48 0))
        [void]$frames.Add((Fr 'stand' 14 'stand' 0 '' 0 0))
        [void]$frames.Add((Fr 'stand' 0 'stand' 0 '' 0 0))
    }
}

function Seq-Flee($ok) {
    if ($ok) {
        [void]$frames.Add((Fr 'walk1' 0 'stand' 0 '' 0 0))
        [void]$frames.Add((Fr 'walk2' -3 'stand' 0 '' 0 0))
        [void]$frames.Add((Fr 'walk1' -6 'stand' 0 '' 0 0))
        [void]$frames.Add((Fr 'walk2' -9 'stand' 0 '' 0 0))
    } else {
        [void]$frames.Add((Fr 'walk1' -1 'stand' 0 '' 0 0))
        [void]$frames.Add((Fr 'walk2' -2 'stand' 0 '' 0 0))
        [void]$frames.Add((Fr 'stand' -1 'stand' 0 '' 0 0))
        [void]$frames.Add((Fr 'stand' 0 'stand' 0 '' 0 0))
    }
}

function Seq-EnemyAttack($dmg, $blocked) {
    $pose = 'stand'
    $t = '-' + $dmg
    $hpose = 'hurt'
    if ($blocked) { $pose = 'guard'; $hpose = 'guard'; $t = 'БЛОК -' + $dmg }
    [void]$frames.Add((Fr $pose 0 'attack' -10 '' 0 0))
    [void]$frames.Add((Fr $pose 0 'attack' -24 '' 0 0))
    [void]$frames.Add((Fr $pose 0 'attack' -34 '' 0 0))
    [void]$frames.Add((Fr $hpose 1 'attack' -34 $t 3 0))
    [void]$frames.Add((Fr $hpose -1 'attack' -34 $t 3 0))
    [void]$frames.Add((Fr $pose 0 'attack' -16 '' 0 0))
    [void]$frames.Add((Fr 'stand' 0 'stand' 0 '' 0 0))
}

function Seq-EnemyStun {
    for ($k = 0; $k -lt 4; $k++) { [void]$frames.Add((Fr 'stand' 0 'stun' 0 'ОГЛУШЁН' 46 0)) }
}

function Seq-Win {
    [void]$frames.Add((Fr 'stand' 0 'hurt' 0 '' 0 0))
    [void]$frames.Add((Fr 'stand' 0 'dead' 0 '' 0 0))
    for ($k = 0; $k -lt 8; $k++) {
        $pose = 'up'
        if (($k % 2) -eq 1) { $pose = 'stand' }
        [void]$frames.Add((Fr $pose 0 'dead' 0 'ПОБЕДА' 5 0))
    }
}

function Seq-Lose {
    [void]$frames.Add((Fr 'hurt' 0 'stand' 0 '' 0 0))
    for ($k = 0; $k -lt 6; $k++) { [void]$frames.Add((Fr 'dead' 0 'stand' 0 '' 0 0)) }
}

# ---------------- режимы ----------------
$frames = New-Object System.Collections.ArrayList

if ($mode -eq 'type') {
    $text  = $env:tw
    $delay = [int]$env:tw_delay
    $width = 74
    $col = 2
    [Console]::Write('  ')
    foreach ($word in $text.Split(' ')) {
        if ($col -gt 2 -and ($col + 1 + $word.Length) -gt $width) {
            [Console]::WriteLine()
            [Console]::Write('  ')
            $col = 2
        } elseif ($col -gt 2) {
            [Console]::Write(' ')
            $col++
        }
        foreach ($c in $word.ToCharArray()) {
            [Console]::Write($c)
            $col++
            if ($delay -gt 0) { Start-Sleep -Milliseconds $delay }
            try {
                if ([Console]::KeyAvailable) { [void][Console]::ReadKey($true); $delay = 0 }
            } catch { $delay = 0 }
        }
    }
    [Console]::WriteLine()
}
elseif ($mode -eq 'walk') {
    $i = 0
    $lastx = 0
    for ($x = 0; $x -le 60; $x += 5) {
        $pose = 'walk1'
        if (($i % 2) -eq 1) { $pose = 'walk2' }
        [void]$frames.Add((Fr $pose $x 'stand' 0 '' 0 0))
        $lastx = $x
        $i++
    }
    if ($env:walk_end -eq 'wave') {
        for ($k = 0; $k -lt 10; $k++) {
            $pose = 'up'
            if (($k % 2) -eq 1) { $pose = 'stand' }
            [void]$frames.Add((Fr $pose $lastx 'stand' 0 '' 0 0))
        }
    }
    Play $frames 'none' 60
}
elseif ($mode -eq 'scene') {
    $en = $env:enemy
    if (-not $E.ContainsKey($en)) { $en = 'none' }
    $pact = $env:pact
    $eact = $env:eact
    $result = $env:result
    $cls = $env:class_id
    $pdmg = [int]$env:pdmg
    $edmg = [int]$env:edmg
    $crit = ($env:crit -eq '1')
    $blocked = ($env:pblock -eq '1')
    if ($pact -eq 'idle') {
        [void]$frames.Add((Fr 'stand' 0 'stand' 0 '' 0 0))
        Play $frames $en 0
    } else {
        switch ($pact) {
            'attack'    { Seq-Attack $pdmg $crit }
            'block'     { Seq-Block }
            'special'   { Seq-Special $cls $pdmg }
            'flee_ok'   { Seq-Flee $true }
            'flee_fail' { Seq-Flee $false }
        }
        switch ($eact) {
            'attack' { Seq-EnemyAttack $edmg $blocked }
            'stun'   { Seq-EnemyStun }
        }
        if ($result -eq 'win')  { Seq-Win }
        if ($result -eq 'lose') { Seq-Lose }
        Play $frames $en 85
    }
}