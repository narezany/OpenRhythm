#!/usr/bin/env python3
"""Generate scripts/Loc.gd from the translation table below.

Keys are the English source strings, so Godot's automatic Control translation
picks them up with no call-site changes. Run after adding or changing any UI
string:  python3 tools/gen_loc.py

It also reports which strings found in the scripts are still untranslated, so
coverage never silently rots.
"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANGS = ["ru", "zh", "de", "nl", "es"]

# Strings that must stay as they are: names, brands, symbols.
SKIP = {
    "Open Rhythm", "Neon Drift", "MELLY", "Custom", "Discord", "Telegram forum",
    "English", "Русский", "中文", "Deutsch", "Nederlands", "Español",
    "mods: ", "OPEN",
    # FileDialog filter specs and the difficulty names written into imported maps
    "*.sspm ; Sound Space Plus / Rhythia map", "*.txt ; Sound Space map data",
    "*.wav ; WAV audio", "*.ogg ; OGG audio", "*.mp3 ; MP3 audio",
    "Unrated", "Easy", "Medium", "Hard", "Logic", "Tasukete", "Imported",
    "torso", "head", "arm_l", "arm_r", "leg_l", "leg_r",
    "target", "fade", "cage", "speed", "slow", "mirror", "hidden", "clicky",
}

T = {}


def add(en, ru, zh, de, nl, es):
    T[en] = {"ru": ru, "zh": zh, "de": de, "nl": nl, "es": es}


# ---------------------------------------------------------------- menu / nav
add("PLAY", "ИГРАТЬ", "开始游戏", "SPIELEN", "SPELEN", "JUGAR")
add("MAP EDITOR", "РЕДАКТОР КАРТ", "谱面编辑器", "MAP-EDITOR", "MAP-EDITOR", "EDITOR DE MAPAS")
add("SONGS", "ПЕСНИ", "歌曲", "SONGS", "NUMMERS", "CANCIONES")
add("SETTINGS", "НАСТРОЙКИ", "设置", "EINSTELLUNGEN", "INSTELLINGEN", "AJUSTES")
add("CREDITS", "АВТОРЫ", "制作人员", "CREDITS", "CREDITS", "CRÉDITOS")
add("QUIT", "ВЫХОД", "退出", "BEENDEN", "AFSLUITEN", "SALIR")
add("STATS", "СТАТИСТИКА", "统计", "STATISTIK", "STATISTIEK", "ESTADÍSTICAS")
add("TOTAL SCORE", "ОБЩИЙ СЧЁТ", "总分", "GESAMTPUNKTE", "TOTALE SCORE", "PUNTUACIÓN TOTAL")
add("free play\\nor story mode", "свободная игра\\nили история", "自由游玩\\n或剧情模式",
    "freies Spiel\\noder Story", "vrij spelen\\nof verhaalmodus", "juego libre\\no modo historia")
add("create maps\\nfor any track", "карты\\nдля любого трека", "为任意曲目\\n制作谱面",
    "Maps für jeden\\nTrack erstellen", "maps maken\\nvoor elk nummer",
    "crea mapas\\npara cualquier tema")
add("manage library\\ndelete / disable", "библиотека\\nудалить / выключить", "管理曲库\\n删除 / 禁用",
    "Bibliothek\\nlöschen / deaktivieren", "bibliotheek\\nverwijderen / uitzetten",
    "biblioteca\\nborrar / desactivar")
add("audio\\ncursor", "звук\\nкурсор", "音频\\n光标", "Audio\\nCursor", "audio\\ncursor", "audio\\ncursor")
add("who made this\\nand why", "кто сделал\\nи зачем", "谁做的\\n为什么",
    "wer das machte\\nund warum", "wie dit maakte\\nen waarom", "quién lo hizo\\ny por qué")
add("see you soon", "до встречи", "再见", "bis bald", "tot snel", "hasta pronto")
add("records\\nachievements", "рекорды\\nдостижения", "记录\\n成就",
    "Rekorde\\nErfolge", "records\\nprestaties", "récords\\nlogros")
add("← Back", "← Назад", "← 返回", "← Zurück", "← Terug", "← Atrás")
add("Back", "Назад", "返回", "Zurück", "Terug", "Atrás")
add("Esc — back", "Esc — назад", "Esc — 返回", "Esc — zurück", "Esc — terug", "Esc — atrás")
add("Main menu", "Главное меню", "主菜单", "Hauptmenü", "Hoofdmenu", "Menú principal")
add("Cancel", "Отмена", "取消", "Abbrechen", "Annuleren", "Cancelar")
add("Save", "Сохранить", "保存", "Speichern", "Opslaan", "Guardar")
add("Delete", "Удалить", "删除", "Löschen", "Verwijderen", "Borrar")
add("Enable", "Включить", "启用", "Aktivieren", "Aanzetten", "Activar")
add("Copy", "Копировать", "复制", "Kopieren", "Kopiëren", "Copiar")
add("Paste", "Вставить", "粘贴", "Einfügen", "Plakken", "Pegar")
add("Duplicate", "Дублировать", "复制副本", "Duplizieren", "Dupliceren", "Duplicar")
add("Undo", "Отменить", "撤销", "Rückgängig", "Ongedaan maken", "Deshacer")
add("Redo", "Вернуть", "重做", "Wiederholen", "Opnieuw", "Rehacer")
add("Select all", "Выделить всё", "全选", "Alles wählen", "Alles selecteren", "Seleccionar todo")
add("Test", "Тест", "试玩", "Test", "Test", "Probar")
add("Play", "Играть", "播放", "Abspielen", "Afspelen", "Reproducir")
add("Pause", "Пауза", "暂停", "Pause", "Pauze", "Pausa")
add("Reset", "Сброс", "重置", "Zurücksetzen", "Reset", "Reiniciar")
add("Apply", "Применить", "应用", "Übernehmen", "Toepassen", "Aplicar")
add("Generate", "Сгенерировать", "生成", "Generieren", "Genereren", "Generar")
add("Attach", "Прикрепить", "附加", "Anhängen", "Koppelen", "Adjuntar")

# ---------------------------------------------------------------- song select
add("SELECT SONG", "ВЫБОР ПЕСНИ", "选择歌曲", "SONG WÄHLEN", "KIES NUMMER", "ELIGE CANCIÓN")
add("EDITOR — SELECT SONG", "РЕДАКТОР — ВЫБОР ПЕСНИ", "编辑器 — 选择歌曲",
    "EDITOR — SONG WÄHLEN", "EDITOR — KIES NUMMER", "EDITOR — ELIGE CANCIÓN")
add("MODIFIERS", "МОДИФИКАТОРЫ", "modifier", "MODIFIKATOREN", "MODIFIERS", "MODIFICADORES")
add("START", "СТАРТ", "开始", "START", "START", "EMPEZAR")
add("NEW MAP", "НОВАЯ КАРТА", "新建谱面", "NEUE MAP", "NIEUWE MAP", "NUEVO MAPA")
add("+  NEW MAP", "+  НОВАЯ КАРТА", "+  新建谱面", "+  NEUE MAP", "+  NIEUWE MAP", "+  NUEVO MAPA")
add("CREATE", "СОЗДАТЬ", "创建", "ERSTELLEN", "AANMAKEN", "CREAR")
add("Library is empty.", "Библиотека пуста.", "曲库为空。",
    "Bibliothek ist leer.", "Bibliotheek is leeg.", "La biblioteca está vacía.")
add("Modifiers change the score multiplier. Multiplicative.",
    "Модификаторы меняют множитель очков. Перемножаются.",
    "modifier 会改变分数倍率，且相互相乘。",
    "Modifikatoren ändern den Punktemultiplikator. Multiplikativ.",
    "Modifiers veranderen de scorevermenigvuldiger. Vermenigvuldigend.",
    "Los modificadores cambian el multiplicador de puntos. Se multiplican entre sí.")
add("No songs found. Put folders or .zip song packs into:",
    "Песни не найдены. Положи папки или .zip-паки в:",
    "未找到歌曲。请将文件夹或 .zip 曲包放入：",
    "Keine Songs gefunden. Lege Ordner oder .zip-Packs hier ab:",
    "Geen nummers gevonden. Zet mappen of .zip-packs in:",
    "No se encontraron canciones. Pon carpetas o packs .zip en:")
add("Song title — the game creates its own folder:",
    "Название песни — игра сама создаст папку:",
    "歌曲标题 — 游戏会自动创建文件夹：",
    "Songtitel — das Spiel legt den Ordner selbst an:",
    "Nummertitel — het spel maakt zelf een map aan:",
    "Título de la canción — el juego crea su propia carpeta:")
add("My awesome song", "Моя крутая песня", "我的超棒歌曲",
    "Mein toller Song", "Mijn geweldige nummer", "Mi canción genial")
add("After creating, open the song folder and drop your audio file\\n(audio.wav / .ogg / .mp3) inside — or pick it via the file dialog in the editor.",
    "После создания открой папку песни и положи туда аудиофайл\\n(audio.wav / .ogg / .mp3) — или выбери его в редакторе через диалог.",
    "创建后打开歌曲文件夹并放入音频文件\\n（audio.wav / .ogg / .mp3）——或在编辑器中用文件对话框选择。",
    "Lege danach eine Audiodatei in den Songordner\\n(audio.wav / .ogg / .mp3) — oder wähle sie im Editor aus.",
    "Zet daarna een audiobestand in de nummermap\\n(audio.wav / .ogg / .mp3) — of kies het in de editor.",
    "Después abre la carpeta y pon dentro tu archivo de audio\\n(audio.wav / .ogg / .mp3) — o elígelo en el editor.")

# ---------------------------------------------------------------- modifiers
add("TARGET", "ЦЕЛЬ", "目标", "ZIEL", "DOEL", "OBJETIVO")
add("BLACKOUT", "ЗАТЕМНЕНИЕ", "黑屏", "BLACKOUT", "BLACKOUT", "APAGÓN")
add("CAGE", "КЛЕТКА", "牢笼", "KÄFIG", "KOOI", "JAULA")
add("SPEED UP", "УСКОРЕНИЕ", "加速", "SCHNELLER", "SNELLER", "MÁS RÁPIDO")
add("SLOW DOWN", "ЗАМЕДЛЕНИЕ", "减速", "LANGSAMER", "LANGZAMER", "MÁS LENTO")
add("MIRROR", "ЗЕРКАЛО", "镜像", "SPIEGEL", "SPIEGEL", "ESPEJO")
add("HIDDEN", "СКРЫТЫЙ", "隐藏", "VERSTECKT", "VERBORGEN", "OCULTO")
add("CLICKY", "ВСЁ КЛИКОМ", "全部点击", "ALLES KLICKEN", "ALLES KLIKKEN", "TODO CLIC")
add("CLICKS", "КЛИКИ", "点击音符", "KLICKS", "KLIKS", "CLICS")
add("Play the click notes the mapper put in this chart. +15% score.",
    "Играть кликабельные ноты, которые заложил автор карты. +15% очков.",
    "启用作者在这张谱面里放置的点击音符。分数 +15%。",
    "Spiele die Klick-Noten, die der Mapper eingebaut hat. +15% Punkte.",
    "Speel de kliknoten die de mapper erin heeft gezet. +15% score.",
    "Juega las notas de clic que puso el autor del mapa. +15% de puntos.")
add("waveform: .wav only", "волна: только .wav", "波形：仅限 .wav",
    "Wellenform: nur .wav", "golfvorm: alleen .wav", "onda: solo .wav")
add("Highlights the nearest upcoming note and switches the highlight to it after each hit. -20% score.",
    "Подсвечивает ближайшую ноту и переключается на следующую после попадания. -20% очков.",
    "高亮最近的下一个音符，每次命中后切换到下一个。分数 -20%。",
    "Hebt die nächste Note hervor und wechselt nach jedem Treffer weiter. -20% Punkte.",
    "Markeert de eerstvolgende noot en schuift na elke treffer door. -20% score.",
    "Resalta la nota más cercana y pasa a la siguiente tras cada acierto. -20% de puntos.")
add("Cubes turn invisible shortly before reaching you — memorize them. +25% score.",
    "Кубы исчезают незадолго до прилёта — запоминай их. +25% очков.",
    "方块在飞到你面前之前会消失——把它们记住。分数 +25%。",
    "Würfel werden kurz vor dem Ziel unsichtbar — merke sie dir. +25% Punkte.",
    "Kubussen worden vlak voor aankomst onzichtbaar — onthoud ze. +25% score.",
    "Los cubos se vuelven invisibles justo antes de llegar — memorízalos. +25% de puntos.")
add("Your cursor is locked inside the frame for the whole song. -10% score.",
    "Курсор заперт внутри рамки на всю песню. -10% очков.",
    "整首歌期间光标被锁在框内。分数 -10%。",
    "Der Cursor bleibt den ganzen Song im Rahmen eingesperrt. -10% Punkte.",
    "Je cursor blijft het hele nummer binnen het kader. -10% score.",
    "El cursor queda encerrado en el marco toda la canción. -10% de puntos.")
add("The whole song plays 1.4x faster. +30% score.",
    "Вся песня играет в 1.4 раза быстрее. +30% очков.",
    "整首歌以 1.4 倍速播放。分数 +30%。",
    "Der ganze Song läuft 1,4x schneller. +30% Punkte.",
    "Het hele nummer speelt 1,4x sneller. +30% score.",
    "Toda la canción suena 1,4x más rápido. +30% de puntos.")
add("The whole song plays at 0.75x. Good for learning a chart. -30% score.",
    "Вся песня играет на 0.75x. Удобно разучивать карту. -30% очков.",
    "整首歌以 0.75 倍速播放，适合练谱。分数 -30%。",
    "Der ganze Song läuft mit 0,75x. Gut zum Lernen. -30% Punkte.",
    "Het hele nummer speelt op 0,75x. Handig om te leren. -30% score.",
    "Toda la canción suena a 0,75x. Útil para aprender. -30% de puntos.")
add("The grid is mirrored left to right. Same score.",
    "Сетка зеркалится слева направо. Очки те же.",
    "网格左右镜像。分数不变。",
    "Das Raster wird links-rechts gespiegelt. Gleiche Punkte.",
    "Het raster wordt links-rechts gespiegeld. Zelfde score.",
    "La rejilla se refleja de izquierda a derecha. Mismos puntos.")
add("No outline guides for upcoming notes. +20% score.",
    "Никаких контуров-подсказок для будущих нот. +20% очков.",
    "不再显示下一个音符的轮廓提示。分数 +20%。",
    "Keine Umriss-Hinweise für kommende Noten. +20% Punkte.",
    "Geen omtrekhulp voor komende noten. +20% score.",
    "Sin contornos guía para las notas siguientes. +20% de puntos.")
add("Every cube has to be clicked, not just covered. +40% score.",
    "Каждый куб нужно кликнуть, а не просто накрыть. +40% очков.",
    "每个方块都必须点击，而不只是覆盖。分数 +40%。",
    "Jeder Würfel muss geklickt werden, nicht nur überdeckt. +40% Punkte.",
    "Elke kubus moet geklikt worden, niet alleen bedekt. +40% score.",
    "Cada cubo hay que clicarlo, no solo cubrirlo. +40% de puntos.")

# ---------------------------------------------------------------- settings
add("Master volume", "Общая громкость", "主音量", "Gesamtlautstärke", "Hoofdvolume", "Volumen general")
add("Music volume", "Громкость музыки", "音乐音量", "Musiklautstärke", "Muziekvolume", "Volumen de música")
add("SFX volume", "Громкость эффектов", "音效音量", "Effektlautstärke", "Effectvolume", "Volumen de efectos")
add("Music", "Музыка", "音乐", "Musik", "Muziek", "Música")
add("Effects", "Эффекты", "音效", "Effekte", "Effecten", "Efectos")
add("Hitsounds", "Звуки попаданий", "打击音", "Trefferklänge", "Hitgeluiden", "Sonidos de golpe")
add("Audio offset", "Аудио-смещение", "音频偏移", "Audio-Offset", "Audio-offset", "Desfase de audio")
add("Calibrate", "Калибровка", "校准", "Kalibrieren", "Kalibreren", "Calibrar")
add("Audio", "Звук", "音频", "Audio", "Audio", "Audio")
add("Video", "Графика", "画面", "Grafik", "Beeld", "Vídeo")
add("Accessibility", "Доступность", "无障碍", "Barrierefreiheit", "Toegankelijkheid", "Accesibilidad")
add("Controls", "Управление", "控制", "Steuerung", "Besturing", "Controles")
add("Language", "Язык", "语言", "Sprache", "Taal", "Idioma")
add("Melly", "Melly", "Melly", "Melly", "Melly", "Melly")
add("Fullscreen", "Полный экран", "全屏", "Vollbild", "Volledig scherm", "Pantalla completa")
add("V-Sync", "Вертикальная синхронизация", "垂直同步", "V-Sync", "V-Sync", "V-Sync")
add("FPS limit", "Ограничение FPS", "帧率限制", "FPS-Limit", "FPS-limiet", "Límite de FPS")
add("Reduce motion", "Меньше тряски", "减少画面晃动", "Weniger Bewegung", "Minder beweging", "Reducir movimiento")
add("Reduce flashes", "Меньше вспышек", "减少闪烁", "Weniger Blitze", "Minder flitsen", "Reducir destellos")
add("Disable song video", "Отключить видео песен", "关闭歌曲视频",
    "Song-Video aus", "Videoclip uit", "Desactivar vídeo")
add("Cursor size", "Размер курсора", "光标大小", "Cursorgröße", "Cursorgrootte", "Tamaño del cursor")
add("Cursor sensitivity", "Чувствительность курсора", "光标灵敏度",
    "Cursor-Empfindlichkeit", "Cursorgevoeligheid", "Sensibilidad del cursor")
add("Gamepad cursor speed", "Скорость стика", "手柄光标速度",
    "Gamepad-Cursortempo", "Gamepad-cursorsnelheid", "Velocidad del stick")
add("Relative touch cursor", "Относительный тач-курсор", "相对触摸光标",
    "Relativer Touch-Cursor", "Relatieve touch-cursor", "Cursor táctil relativo")
add("Reset to defaults", "Сбросить", "恢复默认", "Zurücksetzen", "Standaard herstellen", "Restablecer")
add("MELLY — colors", "MELLY — цвета", "MELLY — 颜色", "MELLY — Farben", "MELLY — kleuren", "MELLY — colores")
add("Damps camera shake, zoom punches and parallax.",
    "Приглушает тряску камеры, рывки зума и параллакс.",
    "减弱镜头抖动、缩放冲击和视差。",
    "Dämpft Kamerawackeln, Zoom-Stöße und Parallaxe.",
    "Dempt cameraschudden, zoomstoten en parallax.",
    "Atenúa el temblor de cámara, los zooms y el paralaje.")
add("Damps full-screen flashes and strobing on the beat. Recommended if bright flashing bothers you.",
    "Приглушает вспышки на весь экран и стробы под бит. Включи, если яркое мигание мешает.",
    "减弱全屏闪光和随节拍的频闪。如果强烈闪烁让你不适，建议开启。",
    "Dämpft Vollbild-Blitze und Stroboskop auf dem Beat. Empfohlen, wenn helles Flackern stört.",
    "Dempt schermvullende flitsen en stroboscoop op de beat. Aan te raden bij lichtgevoeligheid.",
    "Atenúa los destellos a pantalla completa y el estrobo al ritmo. Recomendado si te molestan.")
add("Cursor moves with finger offset, stays where left. Game/editor only.",
    "Курсор двигается относительно пальца и остаётся на месте. Только в игре и редакторе.",
    "光标随手指相对移动，松开后停在原处。仅在游戏和编辑器中。",
    "Der Cursor folgt dem Finger relativ und bleibt liegen. Nur im Spiel und Editor.",
    "De cursor volgt de vinger relatief en blijft liggen. Alleen in spel en editor.",
    "El cursor sigue el dedo de forma relativa y se queda donde lo dejas. Solo en juego y editor.")
add("Positive values judge notes later, for when you hear the audio late. Let the game measure it for you:",
    "Положительные значения судят ноты позже — если звук доходит с задержкой. Пусть игра измерит сама:",
    "正值会让判定更晚，适合音频延迟的情况。让游戏自己测量：",
    "Positive Werte bewerten Noten später, wenn du den Ton verzögert hörst. Lass es das Spiel messen:",
    "Positieve waarden beoordelen noten later, als je het geluid te laat hoort. Laat het spel het meten:",
    "Los valores positivos juzgan las notas más tarde, si oyes el audio con retraso. Deja que el juego lo mida:")
add("Some in-game text is only in English for now.",
    "Часть текста в игре пока только на английском.",
    "游戏中仍有部分文本只有英文。",
    "Ein Teil der Texte ist vorerst nur auf Englisch.",
    "Een deel van de tekst is voorlopig alleen in het Engels.",
    "Parte del texto del juego todavía está solo en inglés.")
add("Cursor left", "Курсор влево", "光标左移", "Cursor links", "Cursor links", "Cursor izquierda")
add("Cursor right", "Курсор вправо", "光标右移", "Cursor rechts", "Cursor rechts", "Cursor derecha")
add("Cursor up", "Курсор вверх", "光标上移", "Cursor hoch", "Cursor omhoog", "Cursor arriba")
add("Cursor down", "Курсор вниз", "光标下移", "Cursor runter", "Cursor omlaag", "Cursor abajo")
add("Restart", "Заново", "重新开始", "Neustart", "Opnieuw", "Reiniciar")
add("Resume", "Продолжить", "继续", "Fortsetzen", "Hervatten", "Continuar")
add("Skip intro", "Пропустить вступление", "跳过前奏", "Intro überspringen", "Intro overslaan", "Saltar intro")
add("Confirm / advance", "Подтвердить / далее", "确认 / 继续",
    "Bestätigen / weiter", "Bevestigen / verder", "Confirmar / avanzar")
add("press a key…", "нажми клавишу…", "请按一个键…", "Taste drücken…", "druk op een toets…", "pulsa una tecla…")

# ---------------------------------------------------------------- gameplay
add("PAUSED", "ПАУЗА", "已暂停", "PAUSE", "GEPAUZEERD", "EN PAUSA")
add("PRESS BACK AGAIN TO EXIT", "НАЖМИТЕ НАЗАД ЕЩЁ РАЗ ДЛЯ ВЫХОДА", "再按一次返回键退出",
    "ZUM BEENDEN ERNEUT ZURÜCK DRÜCKEN", "DRUK NOGMAALS OP TERUG OM AF TE SLUITEN",
    "PULSA ATRÁS OTRA VEZ PARA SALIR")
add("ESC — pause", "ESC — пауза", "ESC — 暂停", "ESC — Pause", "ESC — pauze", "ESC — pausa")
add("RESULTS", "РЕЗУЛЬТАТЫ", "成绩", "ERGEBNIS", "RESULTAAT", "RESULTADOS")
add("Retry", "Ещё раз", "重试", "Nochmal", "Opnieuw", "Reintentar")
add("Save replay", "Сохранить реплей", "保存回放", "Replay speichern", "Replay opslaan", "Guardar repetición")
add("Continue story →", "Продолжить историю →", "继续剧情 →",
    "Story fortsetzen →", "Verhaal vervolgen →", "Continuar historia →")
add("← Back to editor", "← Назад в редактор", "← 回到编辑器",
    "← Zurück zum Editor", "← Terug naar editor", "← Volver al editor")
add("played on phone  •  bigger hit zones", "играно на телефоне  •  зоны шире",
    "在手机上游玩  •  判定区更大", "am Handy gespielt  •  größere Trefferzonen",
    "op telefoon gespeeld  •  grotere trefzones", "jugado en móvil  •  zonas más grandes")
add("★ NEW RECORD ★", "★ НОВЫЙ РЕКОРД ★", "★ 新纪录 ★",
    "★ NEUER REKORD ★", "★ NIEUW RECORD ★", "★ NUEVO RÉCORD ★")
add("★ STORY COMPLETE ★", "★ ИСТОРИЯ ПРОЙДЕНА ★", "★ 剧情通关 ★",
    "★ STORY ABGESCHLOSSEN ★", "★ VERHAAL VOLTOOID ★", "★ HISTORIA COMPLETADA ★")

# ---------------------------------------------------------------- tutorial
add("Welcome to the tutorial! Let's learn how to play.",
    "Добро пожаловать в обучение! Давай научимся играть.",
    "欢迎来到教程！我们来学怎么玩。",
    "Willkommen im Tutorial! Lernen wir das Spiel.",
    "Welkom bij de tutorial! Laten we leren spelen.",
    "¡Bienvenido al tutorial! Vamos a aprender a jugar.")
add("Watch the frame: a cube will fly into a cell.",
    "Смотри на рамку: куб прилетит в клетку.",
    "看着方框：一个方块会飞进某个格子。",
    "Achte auf den Rahmen: ein Würfel fliegt in eine Zelle.",
    "Let op het kader: er vliegt een kubus in een vakje.",
    "Mira el marco: un cubo volará hacia una casilla.")
add("Move your cursor onto that cell and CATCH the cube when it lands!",
    "Наведи курсор на эту клетку и ПОЙМАЙ куб, когда он прилетит!",
    "把光标移到那个格子上，在方块落下时接住它！",
    "Bewege den Cursor auf die Zelle und FANG den Würfel bei der Landung!",
    "Beweeg je cursor naar dat vakje en VANG de kubus als hij landt!",
    "¡Lleva el cursor a esa casilla y ATRAPA el cubo al aterrizar!")
add("Dead center = PERFECT. A bit off = GREAT or GOOD. Edge = BULLSHIT.",
    "Точно в центр = PERFECT. Немного мимо = GREAT или GOOD. По краю = BULLSHIT.",
    "正中心 = PERFECT，偏一点 = GREAT 或 GOOD，边缘 = BULLSHIT。",
    "Genau mittig = PERFECT. Etwas daneben = GREAT oder GOOD. Am Rand = BULLSHIT.",
    "Precies in het midden = PERFECT. Iets ernaast = GREAT of GOOD. Rand = BULLSHIT.",
    "Justo en el centro = PERFECT. Un poco fuera = GREAT o GOOD. Al borde = BULLSHIT.")
add("Missed? No worries — try again, nobody's watching.",
    "Промазал? Не страшно — пробуй ещё, никто не смотрит.",
    "没接住？没关系——再来一次，没人看着。",
    "Verfehlt? Halb so wild — nochmal, niemand schaut zu.",
    "Gemist? Geeft niet — probeer opnieuw, niemand kijkt.",
    "¿Fallaste? Tranquilo — inténtalo otra vez, nadie mira.")
add("Got it! Cubes land with the music. Ready for more?",
    "Понял! Кубы прилетают под музыку. Готов дальше?",
    "明白了吧！方块跟着音乐落下。准备好继续了吗？",
    "Verstanden! Die Würfel landen im Takt. Bereit für mehr?",
    "Snap je? Kubussen landen op de muziek. Klaar voor meer?",
    "¡Ya lo tienes! Los cubos caen con la música. ¿Seguimos?")
add("Here comes the song — good luck!",
    "А вот и песня — удачи!", "歌曲来了——祝你好运！",
    "Und jetzt der Song — viel Glück!", "Daar komt het nummer — succes!",
    "Aquí llega la canción — ¡suerte!")

# ---------------------------------------------------------------- story
add("STORY MODE", "РЕЖИМ ИСТОРИИ", "剧情模式", "STORY-MODUS", "VERHAALMODUS", "MODO HISTORIA")
add("LOCKED", "ЗАКРЫТО", "未解锁", "GESPERRT", "VERGRENDELD", "BLOQUEADO")
add("Choose your difficulty:", "Выбери сложность:", "选择难度：",
    "Wähle den Schwierigkeitsgrad:", "Kies je moeilijkheid:", "Elige la dificultad:")
add("1 • FIRST STEPS", "1 • ПЕРВЫЕ ШАГИ", "1 • 初次上手",
    "1 • ERSTE SCHRITTE", "1 • EERSTE STAPPEN", "1 • PRIMEROS PASOS")
add("2 • NIGHT DRIVE", "2 • НОЧНАЯ ПОЕЗДКА", "2 • 夜间驾驶",
    "2 • NACHTFAHRT", "2 • NACHTRIT", "2 • VIAJE NOCTURNO")
add("3 • OVERDRIVE", "3 • ОВЕРДРАЙВ", "3 • 超载",
    "3 • OVERDRIVE", "3 • OVERDRIVE", "3 • SOBREMARCHA")
add("Learn the basics with Melly.\\nJust the tutorial.",
    "Основы вместе с Melly.\\nТолько туториал.",
    "和 Melly 一起学基础。\\n只有教程。",
    "Die Grundlagen mit Melly.\\nNur das Tutorial.",
    "De basis met Melly.\\nAlleen de tutorial.",
    "Lo básico con Melly.\\nSolo el tutorial.")
add("This map has no audio yet", "У этой карты ещё нет музыки", "这张谱面还没有音频",
    "Diese Map hat noch kein Audio", "Deze map heeft nog geen audio",
    "Este mapa aún no tiene audio")
add("Pick a file and the game copies it into the song's own folder, or drop the file in there yourself and press Scan.",
    "Выбери файл — игра сама скопирует его в папку песни. Или положи файл туда сам и нажми «Просканировать».",
    "选一个文件，游戏会把它复制到这首歌自己的文件夹里；也可以自己把文件放进去再点扫描。",
    "Wähle eine Datei, das Spiel kopiert sie in den Songordner - oder lege sie selbst dort ab und drücke Scannen.",
    "Kies een bestand, het spel kopieert het naar de map van het nummer - of zet het er zelf in en druk op Scannen.",
    "Elige un archivo y el juego lo copia a la carpeta de la canción, o ponlo tú ahí y pulsa Escanear.")
add("Open folder", "Открыть папку", "打开文件夹", "Ordner öffnen", "Map openen", "Abrir carpeta")
add("Folder path copied", "Путь к папке скопирован", "已复制文件夹路径",
    "Ordnerpfad kopiert", "Mappad gekopieerd", "Ruta de la carpeta copiada")
add("Hyper Drive, Neon Drift, Midnight Pulse.\\nChoose your difficulty.",
    "Hyper Drive, Neon Drift, Midnight Pulse.\\nВыбери сложность.",
    "Hyper Drive、Neon Drift、Midnight Pulse。\\n选择难度。",
    "Hyper Drive, Neon Drift, Midnight Pulse.\\nWähle die Schwierigkeit.",
    "Hyper Drive, Neon Drift, Midnight Pulse.\\nKies je moeilijkheid.",
    "Hyper Drive, Neon Drift, Midnight Pulse.\\nElige la dificultad.")
add("Bass Rush, Crimson Step, Afterburner.\\nThe heavy set.",
    "Bass Rush, Crimson Step, Afterburner.\\nТяжёлый сет.",
    "Bass Rush、Crimson Step、Afterburner。\\n重口味套装。",
    "Bass Rush, Crimson Step, Afterburner.\\nDas harte Set.",
    "Bass Rush, Crimson Step, Afterburner.\\nDe zware set.",
    "Bass Rush, Crimson Step, Afterburner.\\nEl set pesado.")
add("Hey! You want to learn how to play Open Rhythm?",
    "Эй! Хочешь научиться играть в Open Rhythm?",
    "嘿！想学怎么玩 Open Rhythm 吗？",
    "Hey! Willst du lernen, wie man Open Rhythm spielt?",
    "Hé! Wil je leren hoe je Open Rhythm speelt?",
    "¡Eh! ¿Quieres aprender a jugar a Open Rhythm?")
add("Then watch closely — I'll show you everything myself!",
    "Тогда смотри внимательно — я всё покажу сам!",
    "那就看仔细了——我亲自教你！",
    "Dann pass gut auf — ich zeige dir alles selbst!",
    "Kijk dan goed — ik laat je alles zelf zien!",
    "Entonces mira bien — ¡te lo enseño yo misma!")
add("Well, how's your first impression of the game?",
    "Ну как, каково первое впечатление от игры?",
    "那么，对这游戏的第一印象如何？",
    "Und, wie ist dein erster Eindruck vom Spiel?",
    "En, wat is je eerste indruk van het spel?",
    "Bueno, ¿qué tal la primera impresión del juego?")
add("Yeah, you can't really enjoy a tutorial... let's do it for real!",
    "Да, туториалом не насладишься... давай по-настоящему!",
    "对吧，教程玩不出什么感觉……来真的吧！",
    "Ja, an einem Tutorial hat man wenig Spaß... jetzt richtig!",
    "Ja, van een tutorial word je niet warm... nu echt!",
    "Ya, un tutorial no se disfruta... ¡vamos en serio!")
add("Three tracks, no stopping. The last one is my favourite.",
    "Три трека без остановок. Последний — мой любимый.",
    "三首曲子，不许停。最后一首是我最喜欢的。",
    "Drei Tracks am Stück. Der letzte ist mein Liebling.",
    "Drie tracks achter elkaar. De laatste is mijn favoriet.",
    "Tres temas sin parar. El último es mi favorito.")
add("Shall we continue?", "Продолжим?", "继续吧？",
    "Machen wir weiter?", "Gaan we verder?", "¿Seguimos?")
add("finish the TUTORIAL first (Story Mode) to unlock Free Play",
    "сначала пройди ТУТОРИАЛ (режим истории), чтобы открыть свободную игру",
    "先完成教程（剧情模式）才能解锁自由游玩",
    "Beende erst das TUTORIAL (Story-Modus), um Freies Spiel freizuschalten",
    "Voltooi eerst de TUTORIAL (verhaalmodus) om vrij spelen te openen",
    "Termina primero el TUTORIAL (modo historia) para desbloquear el juego libre")

# ---------------------------------------------------------------- songs screen
add("Library folder:", "Папка библиотеки:", "曲库文件夹：", "Bibliotheksordner:", "Bibliotheekmap:", "Carpeta de biblioteca:")
add("Copy path", "Копировать путь", "复制路径", "Pfad kopieren", "Pad kopiëren", "Copiar ruta")
add("RESCAN", "ОБНОВИТЬ", "重新扫描", "NEU EINLESEN", "OPNIEUW SCANNEN", "REESCANEAR")
add("IMPORT MAP", "ИМПОРТ КАРТЫ", "导入谱面", "MAP IMPORTIEREN", "MAP IMPORTEREN", "IMPORTAR MAPA")
add("Import .sspm / Sound Space map", "Импорт .sspm / карты Sound Space",
    "导入 .sspm / Sound Space 谱面", ".sspm / Sound-Space-Map importieren",
    ".sspm / Sound Space-map importeren", "Importar .sspm / mapa de Sound Space")
add("Drop song folders or .zip packs here, then press RESCAN. Or import an .sspm / Sound Space map.",
    "Кидай сюда папки песен или .zip-паки и жми ОБНОВИТЬ. Или импортируй .sspm / карту Sound Space.",
    "把歌曲文件夹或 .zip 包放到这里，然后点重新扫描。也可以导入 .sspm / Sound Space 谱面。",
    "Lege Songordner oder .zip-Packs hier ab und drücke NEU EINLESEN. Oder importiere eine .sspm-Map.",
    "Zet nummermappen of .zip-packs hier neer en druk op OPNIEUW SCANNEN. Of importeer een .sspm-map.",
    "Deja aquí carpetas o packs .zip y pulsa REESCANEAR. O importa un mapa .sspm / Sound Space.")
add("Could not delete that folder", "Не удалось удалить папку", "无法删除该文件夹",
    "Ordner konnte nicht gelöscht werden", "Kon die map niet verwijderen",
    "No se pudo borrar esa carpeta")
add("Storage access denied — I can't see your custom songs, dude.\\nAllow \"All files access\" for Open Rhythm in Android Settings → Apps → Open Rhythm → Permissions.",
    "Нет доступа к файлам — я не вижу твои песни, чувак.\\nРазреши «Доступ ко всем файлам» для Open Rhythm в Настройках Android → Приложения → Open Rhythm → Разрешения.",
    "存储权限被拒绝——我看不到你的自定义歌曲。\\n请在 Android 设置 → 应用 → Open Rhythm → 权限中允许“所有文件访问权限”。",
    "Kein Dateizugriff — deine eigenen Songs sind unsichtbar.\\nErlaube \"Zugriff auf alle Dateien\" für Open Rhythm in Android-Einstellungen → Apps → Berechtigungen.",
    "Geen bestandstoegang — ik zie je eigen nummers niet.\\nSta \"Toegang tot alle bestanden\" toe voor Open Rhythm in Android-instellingen → Apps → Rechten.",
    "Sin acceso al almacenamiento — no veo tus canciones.\\nPermite \"Acceso a todos los archivos\" para Open Rhythm en Ajustes de Android → Apps → Permisos.")
add("Storage access denied — custom songs are invisible.\\nDude, I can't look at your songs: allow \"All files access\"\\nfor Open Rhythm in Android Settings → Apps → Permissions.",
    "Нет доступа к файлам — свои песни не видны.\\nЧувак, я не могу посмотреть твои песни: разреши «Доступ ко всем файлам»\\nдля Open Rhythm в Настройках Android → Приложения → Разрешения.",
    "存储权限被拒绝——自定义歌曲不可见。\\n我看不到你的歌曲：请在 Android 设置 → 应用 → 权限中\\n为 Open Rhythm 允许“所有文件访问权限”。",
    "Kein Dateizugriff — eigene Songs sind unsichtbar.\\nIch komme nicht an deine Songs: erlaube \"Zugriff auf alle Dateien\"\\nfür Open Rhythm in Android-Einstellungen → Apps → Berechtigungen.",
    "Geen bestandstoegang — eigen nummers zijn onzichtbaar.\\nIk kan je nummers niet zien: sta \"Toegang tot alle bestanden\" toe\\nvoor Open Rhythm in Android-instellingen → Apps → Rechten.",
    "Sin acceso al almacenamiento — tus canciones no se ven.\\nNo puedo mirar tus canciones: permite \"Acceso a todos los archivos\"\\npara Open Rhythm en Ajustes de Android → Apps → Permisos.")

# ---------------------------------------------------------------- stats
add("No records yet — go play something.", "Рекордов пока нет — сыграй что-нибудь.",
    "还没有记录——去玩点什么吧。", "Noch keine Rekorde — spiel etwas.",
    "Nog geen records — ga iets spelen.", "Aún no hay récords — juega algo.")
add("No saved replays yet.", "Сохранённых реплеев пока нет.", "还没有保存的回放。",
    "Noch keine gespeicherten Replays.", "Nog geen opgeslagen replays.",
    "Aún no hay repeticiones guardadas.")

# ---------------------------------------------------------------- calibration
add("CALIBRATION", "КАЛИБРОВКА", "校准", "KALIBRIERUNG", "KALIBRATIE", "CALIBRACIÓN")
add("Space / click / tap on the beat. The game measures your delay itself.",
    "Пробел / клик / тап в бит. Игра сама измерит твою задержку.",
    "跟着节拍按空格 / 点击 / 轻触。游戏会自动测量你的延迟。",
    "Leertaste / Klick / Tippen im Takt. Das Spiel misst deine Verzögerung selbst.",
    "Spatie / klik / tik op de beat. Het spel meet je vertraging zelf.",
    "Espacio / clic / toque al ritmo. El juego mide tu retardo por sí solo.")
add("Keep tapping — at least 8 taps needed", "Стучи дальше — нужно минимум 8 ударов",
    "继续点击 — 至少需要 8 次", "Weiter tippen — mindestens 8 nötig",
    "Blijf tikken — minstens 8 nodig", "Sigue tocando — hacen falta 8 como mínimo")
add("Taps", "Ударов", "点击次数", "Eingaben", "Tikken", "Toques")
add("Detected offset", "Найденное смещение", "测得偏移", "Ermittelter Offset",
    "Gemeten offset", "Desfase detectado")

# ---------------------------------------------------------------- disclaimer
add("BEFORE YOU START", "ПЕРЕД НАЧАЛОМ", "开始之前", "BEVOR DU STARTEST",
    "VOORDAT JE BEGINT", "ANTES DE EMPEZAR")
add("I understand", "Я понял", "我明白了", "Verstanden", "Begrepen", "Entendido")
add("Open Rhythm is a rhythm game, not a music player.",
    "Open Rhythm — это ритм-игра, а не музыкальный плеер.",
    "Open Rhythm 是一款节奏游戏，不是音乐播放器。",
    "Open Rhythm ist ein Rhythmusspiel, kein Musikplayer.",
    "Open Rhythm is een ritmespel, geen muziekspeler.",
    "Open Rhythm es un juego de ritmo, no un reproductor de música.")
add("The tracks here exist so there is something to play to. If a song grabs you — go and listen to it properly: Spotify, Apple Music, YouTube, Bandcamp, wherever the artist actually gets paid for it.",
    "Треки здесь нужны, чтобы было подо что играть. Зацепила песня — послушай её по-нормальному: Spotify, Apple Music, YouTube, Bandcamp, там, где автору реально платят.",
    "这里的曲子只是为了让你有东西可玩。如果某首歌打动了你，就去正经地听它：Spotify、Apple Music、YouTube、Bandcamp，去创作者真正能拿到钱的地方。",
    "Die Tracks hier sind nur da, damit du etwas zum Spielen hast. Wenn dich ein Song packt, hör ihn richtig: Spotify, Apple Music, YouTube, Bandcamp — dort, wo die Künstler auch bezahlt werden.",
    "De tracks hier zijn er zodat je ergens op kunt spelen. Als een nummer je grijpt: luister het fatsoenlijk via Spotify, Apple Music, YouTube of Bandcamp, waar de artiest er ook aan verdient.",
    "Los temas están aquí solo para tener algo con lo que jugar. Si una canción te engancha, escúchala en condiciones: Spotify, Apple Music, YouTube, Bandcamp, donde el artista cobre de verdad.")
add("We support the original authors. Maps are built on their songs out of respect for the music, and where an author has given their blessing we say so — the Verity tracks are used with the author's permission.",
    "Мы за оригинальных авторов. Карты сделаны по их песням из уважения к музыке, и где автор дал добро — мы об этом говорим: треки Verity используются с разрешения автора.",
    "我们支持原作者。这些谱面是出于对音乐的尊重而制作的；凡是得到作者许可的我们都会说明——Verity 的曲目已获得作者授权。",
    "Wir stehen hinter den Urhebern. Die Maps entstehen aus Respekt vor der Musik, und wo eine Erlaubnis vorliegt, sagen wir es: die Verity-Tracks werden mit Erlaubnis des Autors genutzt.",
    "Wij steunen de originele makers. Maps zijn gemaakt uit respect voor de muziek, en waar een maker toestemming gaf zeggen we dat: de Verity-tracks worden met toestemming gebruikt.",
    "Apoyamos a los autores originales. Los mapas se hacen por respeto a la música, y donde hay permiso lo decimos: los temas de Verity se usan con permiso del autor.")
add("If you are an artist and you want your track out of this game, tell us in Telegram or Discord and it is gone.",
    "Если ты автор и хочешь убрать свой трек из игры — напиши в Telegram или Discord, и его не будет.",
    "如果你是音乐人，希望把自己的曲子从游戏里撤下来，在 Telegram 或 Discord 告诉我们，马上就撤。",
    "Wenn du Künstler bist und deinen Track hier nicht haben willst: schreib uns auf Telegram oder Discord, dann ist er weg.",
    "Ben je artiest en wil je je track hier weg? Laat het weten via Telegram of Discord en hij verdwijnt.",
    "Si eres artista y quieres tu tema fuera del juego, dínoslo en Telegram o Discord y desaparece.")

# ---------------------------------------------------------------- achievements
add("And so it begins", "И понеслось", "就此开始", "Und los geht's", "En daar gaan we", "Y así empieza")
add("Cannot be stopped", "Не остановить", "停不下来", "Nicht zu stoppen", "Niet te stoppen", "Imparable")
add("Absolutely locked in", "Полная концентрация", "完全进入状态",
    "Voll im Tunnel", "Volledig in de zone", "Totalmente concentrado")
add("Sharp", "Остро", "犀利", "Scharf", "Scherp", "Afilado")
add("No thoughts, head empty, only SS", "В голове пусто, только SS", "脑子空空，只有 SS",
    "Kopf leer, nur noch SS", "Hoofd leeg, alleen SS", "Sin pensamientos, solo SS")
add("Not a single cube was harmed", "Ни один куб не пострадал", "没有一个方块受伤",
    "Kein Würfel kam zu Schaden", "Geen enkele kubus gewond", "Ningún cubo resultó herido")
add("Ten thousand cubes later", "Десять тысяч кубов спустя", "一万个方块之后",
    "Zehntausend Würfel später", "Tienduizend kubussen later", "Diez mil cubos después")
add("Touch grass? never heard of it", "Погулять? не слышал", "出门走走？没听说过",
    "Frische Luft? nie gehört", "Naar buiten? nooit van gehoord", "¿Salir a la calle? ni idea")
add("Why do you do this to yourself", "Зачем ты так с собой", "你为什么要这样折磨自己",
    "Warum tust du dir das an", "Waarom doe je jezelf dit aan", "Por qué te haces esto")
add("Trust me bro, I know the chart", "Отвечаю, я знаю карту наизусть", "信我，我记得整张谱",
    "Vertrau mir, ich kenne die Map", "Geloof me, ik ken de map", "Confía, me sé el mapa")
add("Gotta go fast", "Надо быстрее", "必须要快", "Muss schneller gehen", "Sneller, sneller", "Hay que ir rápido")
add("We have time at home", "У нас дома есть время", "家里有的是时间",
    "Wir haben Zeit zu Hause", "We hebben thuis tijd genoeg", "Tiempo tenemos en casa")
add("Everything is backwards", "Всё наоборот", "一切都反过来了",
    "Alles verkehrt herum", "Alles omgekeerd", "Todo al revés")
add("Certified chart cook", "Дипломированный маппер", "认证谱面大厨",
    "Zertifizierter Map-Koch", "Gediplomeerd mapmaker", "Cocinero de mapas certificado")
add("Borrowed from the neighbours", "Одолжил у соседей", "从邻居那儿借来的",
    "Bei den Nachbarn geliehen", "Geleend van de buren", "Prestado a los vecinos")
add("It was never lag", "Дело было не в лаге", "从来都不是延迟的问题",
    "Es lag nie am Lag", "Het lag nooit aan de lag", "Nunca fue el lag")
add("is that a silly gubby", "это что, силли габби", "那是个傻乎乎的小家伙吗",
    "ist das ein silly gubby", "is dat een silly gubby", "¿eso es un silly gubby?")
add("Evidence, your honour", "Улика, ваша честь", "呈上证据，法官大人",
    "Beweisstück, Euer Ehren", "Bewijsstuk, edelachtbare", "Prueba, señoría")
add("It is 4 AM and I am fine", "Четыре утра, и всё нормально", "凌晨四点，我很好",
    "Es ist 4 Uhr und mir geht's gut", "Het is 4 uur en het gaat prima",
    "Son las 4 de la mañana y estoy bien")
add("Certified BULLSHIT enjoyer", "Ценитель BULLSHIT", "BULLSHIT 认证爱好者",
    "Zertifizierter BULLSHIT-Genießer", "Gediplomeerd BULLSHIT-liefhebber",
    "Disfrutón de BULLSHIT certificado")
add("Perfectly balanced, as all things", "Идеальный баланс, как и всё сущее", "完美的平衡，如同万物",
    "Perfekt ausbalanciert, wie alles", "Perfect in balans, zoals alles",
    "Perfectamente equilibrado, como todo")
add("Reading in another tongue", "Читаю на другом языке", "换种语言来读",
    "Auf einer anderen Sprache", "Lezen in een andere taal", "Leyendo en otra lengua")
add("Sat through the whole thing", "Досидел до конца", "从头看到尾",
    "Bis zum Ende durchgehalten", "Helemaal uitgezeten", "Aguantó hasta el final")

add("Finish your first song", "Пройди первую песню", "完成你的第一首歌",
    "Beende deinen ersten Song", "Voltooi je eerste nummer", "Termina tu primera canción")
add("Reach a combo of 100", "Набери комбо 100", "达成 100 连击",
    "Erreiche ein Combo von 100", "Haal een combo van 100", "Llega a un combo de 100")
add("Reach a combo of 500", "Набери комбо 500", "达成 500 连击",
    "Erreiche ein Combo von 500", "Haal een combo van 500", "Llega a un combo de 500")
add("Finish a song with rank S", "Пройди песню на ранг S", "以 S 评价完成一首歌",
    "Beende einen Song mit Rang S", "Voltooi een nummer met rang S",
    "Termina una canción con rango S")
add("Finish a song with rank SS", "Пройди песню на ранг SS", "以 SS 评价完成一首歌",
    "Beende einen Song mit Rang SS", "Voltooi een nummer met rang SS",
    "Termina una canción con rango SS")
add("Finish a song without a miss", "Пройди песню без единого промаха", "零 MISS 完成一首歌",
    "Beende einen Song ohne Miss", "Voltooi een nummer zonder miss",
    "Termina una canción sin fallar")
add("Hit 10 000 notes in total", "Попади по 10 000 нот суммарно", "累计命中 10 000 个音符",
    "Triff insgesamt 10 000 Noten", "Raak in totaal 10 000 noten",
    "Acierta 10 000 notas en total")
add("Play 50 songs", "Сыграй 50 песен", "游玩 50 首歌", "Spiele 50 Songs",
    "Speel 50 nummers", "Juega 50 canciones")
add("Finish a song with two or more modifiers", "Пройди песню с двумя и более модификаторами",
    "带两个或更多 modifier 完成一首歌", "Beende einen Song mit zwei oder mehr Modifikatoren",
    "Voltooi een nummer met twee of meer modifiers",
    "Termina una canción con dos o más modificadores")
add("Finish a song with BLACKOUT on", "Пройди песню с ЗАТЕМНЕНИЕМ", "开启黑屏完成一首歌",
    "Beende einen Song mit BLACKOUT", "Voltooi een nummer met BLACKOUT",
    "Termina una canción con APAGÓN")
add("Finish a song with SPEED UP on", "Пройди песню с УСКОРЕНИЕМ", "开启加速完成一首歌",
    "Beende einen Song mit SCHNELLER", "Voltooi een nummer met SNELLER",
    "Termina una canción con MÁS RÁPIDO")
add("Finish a song with SLOW DOWN on", "Пройди песню с ЗАМЕДЛЕНИЕМ", "开启减速完成一首歌",
    "Beende einen Song mit LANGSAMER", "Voltooi een nummer met LANGZAMER",
    "Termina una canción con MÁS LENTO")
add("Finish a song with MIRROR on", "Пройди песню с ЗЕРКАЛОМ", "开启镜像完成一首歌",
    "Beende einen Song mit SPIEGEL", "Voltooi een nummer met SPIEGEL",
    "Termina una canción con ESPEJO")
add("Save a map in the editor", "Сохрани карту в редакторе", "在编辑器中保存一张谱面",
    "Speichere eine Map im Editor", "Sla een map op in de editor",
    "Guarda un mapa en el editor")
add("Import a map from another game", "Импортируй карту из другой игры", "从其它游戏导入一张谱面",
    "Importiere eine Map aus einem anderen Spiel", "Importeer een map uit een ander spel",
    "Importa un mapa de otro juego")
add("Run the offset calibration", "Пройди калибровку смещения", "运行偏移校准",
    "Führe die Offset-Kalibrierung aus", "Voer de offsetkalibratie uit",
    "Ejecuta la calibración de desfase")
add("Repaint Melly in the settings", "Перекрась Melly в настройках", "在设置里给 Melly 换色",
    "Färbe Melly in den Einstellungen um", "Verf Melly opnieuw in de instellingen",
    "Repinta a Melly en los ajustes")
add("Save a replay", "Сохрани реплей", "保存一段回放", "Speichere ein Replay",
    "Sla een replay op", "Guarda una repetición")
add("Play between 3 and 5 in the morning", "Сыграй между тремя и пятью утра", "在凌晨 3 点到 5 点之间游玩",
    "Spiele zwischen 3 und 5 Uhr morgens", "Speel tussen 3 en 5 uur 's nachts",
    "Juega entre las 3 y las 5 de la madrugada")
add("Collect 10 BULLSHIT judgements in one song", "Собери 10 BULLSHIT за одну песню",
    "在一首歌里收集 10 个 BULLSHIT", "Sammle 10 BULLSHIT in einem Song",
    "Verzamel 10 BULLSHIT in één nummer", "Consigue 10 BULLSHIT en una canción")
add("Finish a song without hitting a single note", "Доиграй песню, не попав ни по одной ноте",
    "一个音符都没打中就完成一首歌", "Beende einen Song, ohne eine Note zu treffen",
    "Voltooi een nummer zonder één noot te raken",
    "Termina una canción sin acertar ni una nota")
add("Switch the game language", "Смени язык игры", "切换游戏语言",
    "Wechsle die Spielsprache", "Wissel de taal van het spel", "Cambia el idioma del juego")
add("Finish a story", "Пройди историю", "完成一段剧情", "Beende eine Story",
    "Voltooi een verhaal", "Termina una historia")

# ---------------------------------------------------------------- stats tabs
add("Records", "Рекорды", "记录", "Rekorde", "Records", "Récords")
add("Achievements", "Достижения", "成就", "Erfolge", "Prestaties", "Logros")
add("Replays", "Реплеи", "回放", "Replays", "Replays", "Repeticiones")
add("Songs played", "Сыграно песен", "已游玩歌曲", "Gespielte Songs", "Gespeelde nummers", "Canciones jugadas")
add("Notes hit", "Попаданий", "命中音符", "Getroffene Noten", "Geraakte noten", "Notas acertadas")
add("Best combo", "Лучшее комбо", "最佳连击", "Beste Combo", "Beste combo", "Mejor combo")
add("Play time", "Время в игре", "游戏时长", "Spielzeit", "Speeltijd", "Tiempo jugado")
add("Replay saved", "Реплей сохранён", "回放已保存", "Replay gespeichert",
    "Replay opgeslagen", "Repetición guardada")

# ---------------------------------------------------------------- editor
add("Snap", "Сетка", "吸附", "Raster", "Raster", "Ajuste")
add("BPM", "BPM", "BPM", "BPM", "BPM", "BPM")
add("Auto-generate from the audio", "Автогенерация по аудио", "根据音频自动生成",
    "Automatisch aus dem Audio", "Automatisch uit de audio", "Autogenerar desde el audio")
add("Hold note", "Длинная нота", "长按音符", "Halte-Note", "Houdnoot", "Nota mantenida")
add("Click note", "Кликабельная нота", "点击音符", "Klick-Note", "Kliknoot", "Nota de clic")
add("Hold notes", "Длинные ноты", "长按音符", "Halte-Noten", "Houdnoten", "Notas mantenidas")
add("Click notes", "Кликабельные ноты", "点击音符", "Klick-Noten", "Kliknoten", "Notas de clic")
add("Nothing to undo", "Отменять нечего", "没有可撤销的操作",
    "Nichts rückgängig zu machen", "Niets om ongedaan te maken", "Nada que deshacer")
add("Select notes first (drag in the timeline)", "Сначала выдели ноты (рамкой на таймлайне)",
    "请先选中音符（在时间轴上拖选）", "Wähle erst Noten aus (im Timeline ziehen)",
    "Selecteer eerst noten (sleep in de tijdlijn)",
    "Selecciona notas primero (arrastra en la línea de tiempo)")
add("New notes are click notes", "Новые ноты — кликабельные", "新音符将是点击音符",
    "Neue Noten sind Klick-Noten", "Nieuwe noten zijn kliknoten",
    "Las notas nuevas serán de clic")
add("New notes are normal", "Новые ноты — обычные", "新音符将是普通音符",
    "Neue Noten sind normal", "Nieuwe noten zijn normaal", "Las notas nuevas serán normales")
add("Replaces the whole chart. Onset detection needs a .wav; other formats get an even beat grid.",
    "Заменяет всю карту. Детект онсетов работает с .wav; остальным форматам достаётся ровная битовая сетка.",
    "会替换整张谱面。起音检测需要 .wav；其它格式只会得到均匀的节拍网格。",
    "Ersetzt die ganze Map. Onset-Erkennung braucht .wav; andere Formate bekommen ein gleichmäßiges Beat-Raster.",
    "Vervangt de hele map. Onsetdetectie vereist .wav; andere formaten krijgen een gelijkmatig beatraster.",
    "Reemplaza el mapa entero. La detección de onsets necesita .wav; otros formatos reciben una rejilla de beats.")
add("Timeline: drag = select · Ctrl+click = add · drag the right edge = hold length · wheel = scroll · Ctrl+wheel = zoom · middle drag = pan",
    "Таймлайн: тянуть = выделить · Ctrl+клик = добавить · тянуть правый край = длина удержания · колесо = прокрутка · Ctrl+колесо = зум · средняя кнопка = панорама",
    "时间轴：拖动 = 框选 · Ctrl+点击 = 添加 · 拖右边缘 = 长按时长 · 滚轮 = 滚动 · Ctrl+滚轮 = 缩放 · 中键拖动 = 平移",
    "Timeline: ziehen = auswählen · Strg+Klick = hinzufügen · rechte Kante ziehen = Haltelänge · Rad = scrollen · Strg+Rad = zoomen · Mittelklick ziehen = schwenken",
    "Tijdlijn: slepen = selecteren · Ctrl+klik = toevoegen · rechterrand slepen = houdlengte · wiel = scrollen · Ctrl+wiel = zoomen · middelste knop = pannen",
    "Línea de tiempo: arrastrar = seleccionar · Ctrl+clic = añadir · arrastrar el borde derecho = duración · rueda = desplazar · Ctrl+rueda = zoom · botón central = mover")
add("Touch editing works, but the desktop build is far comfier for serious mapping.",
    "Тач-редактирование работает, но для серьёзного маппинга на ПК куда удобнее.",
    "触屏编辑可以用，但正经做谱还是桌面版舒服得多。",
    "Touch-Bearbeitung geht, aber ernsthaftes Mapping ist am Desktop viel angenehmer.",
    "Bewerken met touch werkt, maar serieus mappen gaat veel prettiger op de desktop.",
    "Editar con el dedo funciona, pero para mapear en serio el escritorio es mucho más cómodo.")
add("Pick audio file…", "Выбрать аудиофайл…", "选择音频文件…",
    "Audiodatei wählen…", "Audiobestand kiezen…", "Elegir archivo de audio…")
add("Scan song folder", "Просканировать папку", "扫描歌曲文件夹",
    "Songordner durchsuchen", "Nummermap scannen", "Escanear la carpeta")
add("No audio yet. Pick a file — it is copied into this song's folder.",
    "Аудио ещё нет. Выбери файл — он скопируется в папку песни.",
    "还没有音频。选一个文件——它会被复制到这首歌的文件夹里。",
    "Noch kein Audio. Wähle eine Datei — sie wird in den Songordner kopiert.",
    "Nog geen audio. Kies een bestand — het wordt naar de nummermap gekopieerd.",
    "Aún no hay audio. Elige un archivo — se copiará a la carpeta de la canción.")
add("…or paste a full path", "…или вставь полный путь", "…或粘贴完整路径",
    "…oder einen vollen Pfad einfügen", "…of plak een volledig pad",
    "…o pega una ruta completa")
add("File not found", "Файл не найден", "找不到文件", "Datei nicht gefunden",
    "Bestand niet gevonden", "Archivo no encontrado")
add("Song folder missing", "Папка песни не найдена", "找不到歌曲文件夹",
    "Songordner fehlt", "Nummermap ontbreekt", "Falta la carpeta de la canción")
add("No audio files in the song folder", "В папке песни нет аудиофайлов", "歌曲文件夹里没有音频文件",
    "Keine Audiodateien im Songordner", "Geen audiobestanden in de nummermap",
    "No hay archivos de audio en la carpeta")
add("Auto: no audio or too quiet", "Авто: нет аудио или слишком тихо", "自动：没有音频或太安静",
    "Auto: kein Audio oder zu leise", "Auto: geen audio of te stil",
    "Auto: sin audio o demasiado bajo")
add("▶  Play", "▶  Играть", "▶  播放", "▶  Start", "▶  Start", "▶  Play")
add("⏸  Pause", "⏸  Пауза", "⏸  暂停", "⏸  Pause", "⏸  Pauze", "⏸  Pausa")

# ---------------------------------------------------------------- format strings
add("Saved: %s", "Сохранено: %s", "已保存：%s", "Gespeichert: %s", "Opgeslagen: %s", "Guardado: %s")
add("Audio attached: %s", "Аудио прикреплено: %s", "已附加音频：%s",
    "Audio angehängt: %s", "Audio gekoppeld: %s", "Audio adjuntado: %s")
add("Copied %d notes", "Скопировано нот: %d", "已复制 %d 个音符",
    "%d Noten kopiert", "%d noten gekopieerd", "%d notas copiadas")
add("Pasted %d notes", "Вставлено нот: %d", "已粘贴 %d 个音符",
    "%d Noten eingefügt", "%d noten geplakt", "%d notas pegadas")
add("Auto: too few notes (%d)", "Авто: слишком мало нот (%d)", "自动：音符太少（%d）",
    "Auto: zu wenige Noten (%d)", "Auto: te weinig noten (%d)", "Auto: muy pocas notas (%d)")
add("Auto: %d notes @ %.1f BPM", "Авто: %d нот @ %.1f BPM", "自动：%d 个音符 @ %.1f BPM",
    "Auto: %d Noten @ %.1f BPM", "Auto: %d noten @ %.1f BPM", "Auto: %d notas @ %.1f BPM")
add("Hold notes: %s", "Длинные ноты: %s", "长按音符：%s",
    "Halte-Noten: %s", "Houdnoten: %s", "Notas mantenidas: %s")
add("Click notes: %s", "Кликабельные ноты: %s", "点击音符：%s",
    "Klick-Noten: %s", "Kliknoten: %s", "Notas de clic: %s")
add("EDITOR — %s", "РЕДАКТОР — %s", "编辑器 — %s", "EDITOR — %s", "EDITOR — %s", "EDITOR — %s")
add("Size  x%.2f", "Размер  x%.2f", "大小  x%.2f", "Größe  x%.2f", "Grootte  x%.2f", "Tamaño  x%.2f")
add("Speed  %.2fx", "Скорость  %.2fx", "速度  %.2fx", "Tempo  %.2fx", "Snelheid  %.2fx", "Velocidad  %.2fx")
add("Folder: %s", "Папка: %s", "文件夹：%s", "Ordner: %s", "Map: %s", "Carpeta: %s")
add("grid 1/%d   •   step %.3f s", "сетка 1/%d   •   шаг %.3f с", "网格 1/%d   •   步长 %.3f 秒",
    "Raster 1/%d   •   Schritt %.3f s", "raster 1/%d   •   stap %.3f s",
    "rejilla 1/%d   •   paso %.3f s")
add("Bar %d.%d   •   %02d:%04.1f   •   notes: %d   •   selected: %d",
    "Такт %d.%d   •   %02d:%04.1f   •   нот: %d   •   выделено: %d",
    "小节 %d.%d   •   %02d:%04.1f   •   音符：%d   •   已选：%d",
    "Takt %d.%d   •   %02d:%04.1f   •   Noten: %d   •   gewählt: %d",
    "Maat %d.%d   •   %02d:%04.1f   •   noten: %d   •   geselecteerd: %d",
    "Compás %d.%d   •   %02d:%04.1f   •   notas: %d   •   seleccionadas: %d")
add("Every song in your library.\\nMods, difficulties, records.",
    "Все песни из твоей библиотеки.\\nМоды, сложности, рекорды.",
    "你曲库里的所有歌曲。\\nmodifier、难度、记录。",
    "Alle Songs deiner Bibliothek.\\nMods, Schwierigkeiten, Rekorde.",
    "Alle nummers in je bibliotheek.\\nMods, moeilijkheden, records.",
    "Todas las canciones de tu biblioteca.\\nMods, dificultades, récords.")
add("Three stories: learn with Melly,\\nthen drive, then survive Overdrive.",
    "Три истории: научись с Melly,\\nпотом поездка, потом переживи Овердрайв.",
    "三段剧情：先跟 Melly 学，\\n然后夜驾，最后熬过超载。",
    "Drei Storys: erst mit Melly lernen,\\ndann fahren, dann Overdrive überleben.",
    "Drie verhalen: leren met Melly,\\ndan rijden, dan Overdrive overleven.",
    "Tres historias: aprende con Melly,\\nluego conduce, luego sobrevive a Overdrive.")
add("TORSO", "Торс", "躯干", "Rumpf", "Romp", "Torso")
add("HEAD", "Голова", "头部", "Kopf", "Hoofd", "Cabeza")
add("LEFT ARM", "Левая рука", "左臂", "Linker Arm", "Linkerarm", "Brazo izquierdo")
add("RIGHT ARM", "Правая рука", "右臂", "Rechter Arm", "Rechterarm", "Brazo derecho")
add("LEFT LEG", "Левая нога", "左腿", "Linkes Bein", "Linkerbeen", "Pierna izquierda")
add("RIGHT LEG", "Правая нога", "右腿", "Rechtes Bein", "Rechterbeen", "Pierna derecha")
add("on", "вкл", "开", "an", "aan", "sí")
add("off", "выкл", "关", "aus", "uit", "no")


# ---------------------------------------------------------------- tutorial v2
add("Watch the frame: a cube will fly into one of the nine cells.",
    "Смотри на рамку: куб прилетит в одну из девяти клеток.",
    "看着方框：方块会飞进九个格子中的一个。",
    "Achte auf den Rahmen: ein Würfel fliegt in eine der neun Zellen.",
    "Let op het kader: er vliegt een kubus in een van de negen vakjes.",
    "Mira el marco: un cubo volará a una de las nueve casillas.")
add("Long cubes are HOLDS: stay on them until they run out.",
    "Длинные кубы — это УДЕРЖАНИЯ: не отпускай их до конца.",
    "长方块是长按音符：一直待在上面直到它结束。",
    "Lange Würfel sind HALTE-NOTEN: bleib drauf, bis sie auslaufen.",
    "Lange kubussen zijn HOUDNOTEN: blijf erop tot ze aflopen.",
    "Los cubos largos son NOTAS MANTENIDAS: quédate en ellos hasta el final.")
add("Let go early and the hold does not count. Carry it to the end.",
    "Отпустишь раньше — удержание не засчитается. Веди до конца.",
    "提前松开就不算数。要一直带到最后。",
    "Zu früh losgelassen zählt nicht. Trag ihn bis zum Ende.",
    "Te vroeg loslaten telt niet. Draag hem tot het einde.",
    "Si lo sueltas antes, no cuenta. Llévalo hasta el final.")
add("A cube in a ring has to be CLICKED, not just covered.",
    "Куб в кольце нужно КЛИКНУТЬ, а не просто накрыть.",
    "带圆环的方块必须点击，而不只是覆盖。",
    "Ein Würfel im Ring muss GEKLICKT werden, nicht nur überdeckt.",
    "Een kubus in een ring moet je KLIKKEN, niet alleen bedekken.",
    "Un cubo con anillo hay que CLICARLO, no solo cubrirlo.")
add("In other songs clicks are off until you switch on the CLICKS modifier.",
    "В остальных песнях клики выключены, пока не включишь модификатор КЛИКИ.",
    "在其它歌曲里点击音符默认关闭，需要打开「点击音符」modifier。",
    "In anderen Songs sind Klicks aus, bis du den KLICKS-Modifikator einschaltest.",
    "In andere nummers staan kliks uit tot je de KLIKS-modifier aanzet.",
    "En otras canciones los clics están apagados hasta que actives el modificador CLICS.")
add("All three together now — good luck!",
    "А теперь всё вместе — удачи!", "现在三种一起来——祝你好运！",
    "Und jetzt alle drei zusammen — viel Glück!",
    "Nu alle drie tegelijk — succes!", "Ahora los tres juntos — ¡suerte!")

# ---------------------------------------------------------------- judgements
add("PERFECT", "ИДЕАЛЬНО", "完美", "PERFEKT", "PERFECT", "PERFECTO")
add("GREAT", "ОТЛИЧНО", "很棒", "SEHR GUT", "GEWELDIG", "GENIAL")
add("GOOD", "ХОРОШО", "不错", "GUT", "GOED", "BIEN")
add("BULLSHIT", "ДЕРЬМО", "垃圾", "MURKS", "WAARDELOOS", "BASURA")
add("MISS", "МИМО", "未命中", "DANEBEN", "MIS", "FALLO")
add("GO!", "ПОЕХАЛИ!", "开始！", "LOS!", "GAAN!", "¡VAMOS!")

# ---------------------------------------------------------------- credits
add("created by narezany", "автор — narezany", "由 narezany 制作",
    "erstellt von narezany", "gemaakt door narezany", "creado por narezany")
add("coding — Claude Opus 5 (thanks for the late nights!)",
    "код — Claude Opus 5 (спасибо за ночные сессии!)",
    "编程 — Claude Opus 5（感谢那些通宵！）",
    "Code — Claude Opus 5 (danke für die langen Nächte!)",
    "code — Claude Opus 5 (bedankt voor de late nachten!)",
    "código — Claude Opus 5 (¡gracias por las noches en vela!)")
add("game idea — inspired by Rhythia", "идея — вдохновлено Rhythia",
    "游戏创意 — 受 Rhythia 启发", "Spielidee — inspiriert von Rhythia",
    "spelidee — geïnspireerd door Rhythia", "idea — inspirado en Rhythia")
add("want more maps, contests and news?", "хочешь больше карт, конкурсов и новостей?",
    "想要更多谱面、比赛和消息吗？", "Mehr Maps, Wettbewerbe und News?",
    "meer maps, wedstrijden en nieuws?", "¿quieres más mapas, concursos y noticias?")
add("join the community — buttons below", "заходи в сообщество — кнопки ниже",
    "加入社区 — 按钮在下面", "komm in die Community — Buttons unten",
    "kom bij de community — knoppen hieronder", "únete a la comunidad — botones abajo")

# ---------------------------------------------------------------- editor v2
add("Copied to your library: %s", "Скопировано в твою библиотеку: %s",
    "已复制到你的曲库：%s", "In deine Bibliothek kopiert: %s",
    "Naar je bibliotheek gekopieerd: %s", "Copiado a tu biblioteca: %s")
add("Could not copy this song into your library",
    "Не удалось скопировать песню в библиотеку",
    "无法把这首歌复制到你的曲库",
    "Song konnte nicht in die Bibliothek kopiert werden",
    "Kon dit nummer niet naar je bibliotheek kopiëren",
    "No se pudo copiar esta canción a tu biblioteca")


# ---------------------------------------------------------------- versus
add("VERSUS", "ДУЭЛЬ", "对战", "DUELL", "DUEL", "DUELO")
add("two players\\none chart", "два игрока\\nодна карта", "两名玩家\\n同一张谱面",
    "zwei Spieler\\neine Map", "twee spelers\\neen map", "dos jugadores\\nun mapa")
add("Two players, one chart, higher score wins. Direct connection, no server.",
    "Два игрока, одна карта, побеждает больший счёт. Прямое соединение, без сервера.",
    "两名玩家，同一张谱面，分高者胜。直连，无需服务器。",
    "Zwei Spieler, eine Map, mehr Punkte gewinnt. Direktverbindung, kein Server.",
    "Twee spelers, een map, de hoogste score wint. Directe verbinding, geen server.",
    "Dos jugadores, un mapa, gana quien puntúe más. Conexión directa, sin servidor.")
add("HOST", "СОЗДАТЬ", "创建房间", "HOSTEN", "HOSTEN", "CREAR")
add("JOIN", "ПОДКЛЮЧИТЬСЯ", "加入", "BEITRETEN", "MEEDOEN", "UNIRSE")
add("Disconnect", "Отключиться", "断开连接", "Trennen", "Verbreken", "Desconectar")
add("Not connected", "Нет подключения", "未连接", "Nicht verbunden",
    "Niet verbonden", "Sin conexión")
add("START THE MATCH", "НАЧАТЬ МАТЧ", "开始对战", "MATCH STARTEN",
    "START DE MATCH", "EMPEZAR EL DUELO")
add("Back to versus", "Назад к дуэли", "返回对战", "Zurück zum Duell",
    "Terug naar duel", "Volver al duelo")
add("host address, e.g. 192.168.1.42", "адрес хоста, например 192.168.1.42",
    "房主地址，例如 192.168.1.42", "Host-Adresse, z. B. 192.168.1.42",
    "hostadres, bijv. 192.168.1.42", "dirección del host, p. ej. 192.168.1.42")
add("Waiting for a player…", "Ждём игрока…", "等待玩家加入…",
    "Warte auf einen Spieler…", "Wachten op een speler…", "Esperando a un jugador…")
add("Connected — waiting for the host to pick a song",
    "Подключено — ждём, пока хост выберет песню",
    "已连接 — 等待房主选歌",
    "Verbunden — der Host wählt einen Song",
    "Verbonden — de host kiest een nummer",
    "Conectado — el host está eligiendo canción")
add("Player connected", "Игрок подключился", "玩家已连接",
    "Spieler verbunden", "Speler verbonden", "Jugador conectado")
add("The other player left", "Второй игрок вышел", "对手已离开",
    "Der andere Spieler ist weg", "De andere speler is weg", "El otro jugador se fue")
add("Could not connect", "Не удалось подключиться", "无法连接",
    "Verbindung fehlgeschlagen", "Verbinden mislukt", "No se pudo conectar")
add("The host closed the game", "Хост закрыл игру", "房主关闭了游戏",
    "Der Host hat das Spiel geschlossen", "De host heeft het spel gesloten",
    "El host cerró la partida")
add("Type the host's address first", "Сначала впиши адрес хоста", "请先输入房主地址",
    "Gib zuerst die Host-Adresse ein", "Vul eerst het adres van de host in",
    "Escribe primero la dirección del host")
add("Nobody has joined yet", "Пока никто не подключился", "还没有人加入",
    "Noch ist niemand beigetreten", "Er is nog niemand binnen", "Todavía no se unió nadie")
add("Checking the other player has the same chart…",
    "Проверяем, что у второго игрока та же карта…",
    "正在检查对方是否有相同的谱面…",
    "Prüfe, ob der andere dieselbe Map hat…",
    "Controleren of de ander dezelfde map heeft…",
    "Comprobando que el otro tenga el mismo mapa…")
add("The charts do not match", "Карты не совпадают", "谱面不一致",
    "Die Maps stimmen nicht überein", "De maps komen niet overeen",
    "Los mapas no coinciden")
add("You do not have that song", "У тебя нет этой песни", "你没有这首歌",
    "Du hast diesen Song nicht", "Je hebt dat nummer niet", "No tienes esa canción")
add("Different game version", "Разные версии игры", "游戏版本不同",
    "Unterschiedliche Spielversion", "Andere spelversie", "Versión del juego distinta")
add("Different network protocol", "Разные сетевые протоколы", "网络协议不同",
    "Unterschiedliches Netzwerkprotokoll", "Ander netwerkprotocol",
    "Protocolo de red distinto")
add("YOU WIN", "ТЫ ПОБЕДИЛ", "你赢了", "DU GEWINNST", "JIJ WINT", "GANASTE")
add("YOU LOSE", "ТЫ ПРОИГРАЛ", "你输了", "DU VERLIERST", "JIJ VERLIEST", "PERDISTE")
add("A DRAW", "НИЧЬЯ", "平局", "UNENTSCHIEDEN", "GELIJKSPEL", "EMPATE")
add("Waiting for the other player…", "Ждём второго игрока…", "等待对手完成…",
    "Warte auf den anderen Spieler…", "Wachten op de andere speler…",
    "Esperando al otro jugador…")
add("COPY THIS SONG", "СКОПИРОВАТЬ ПЕСНЮ", "复制这首歌",
    "SONG KOPIEREN", "NUMMER KOPIËREN", "COPIAR ESTA CANCIÓN")
add("This song ships with the game and cannot be edited in place. Name the copy that goes into your library:",
    "Эта песня идёт вместе с игрой, править её на месте нельзя. Как назвать копию в твоей библиотеке?",
    "这首歌随游戏一起发布，无法就地编辑。给放进你曲库的副本起个名字：",
    "Dieser Song gehört zum Spiel und kann nicht direkt bearbeitet werden. Wie soll die Kopie heißen?",
    "Dit nummer hoort bij het spel en kan niet ter plekke bewerkt worden. Hoe heet de kopie?",
    "Esta canción viene con el juego y no se puede editar en su sitio. ¿Cómo se llama la copia?")

# ---------------------------------------------------------------- updater
add("Update", "Обновить", "更新", "Aktualisieren", "Bijwerken", "Actualizar")
add("Retry", "Ещё раз", "重试", "Nochmal", "Opnieuw", "Reintentar")
add("Downloading…", "Скачиваю…", "正在下载…", "Lade herunter…", "Downloaden…", "Descargando…")
add("Version %s is out — you have %s", "Вышла версия %s — у тебя %s",
    "已发布 %s 版 — 你的是 %s", "Version %s ist da — du hast %s",
    "Versie %s is uit — jij hebt %s", "Salió la versión %s — tienes %s")
add("Installing — the game will restart", "Устанавливаю — игра перезапустится",
    "正在安装 — 游戏会重启", "Wird installiert — das Spiel startet neu",
    "Installeren — het spel start opnieuw", "Instalando — el juego se reiniciará")
add("Saved to Downloads — open it to install",
    "Сохранено в «Загрузки» — открой файл, чтобы установить",
    "已保存到下载文件夹 — 打开它进行安装",
    "In Downloads gespeichert — zum Installieren öffnen",
    "Opgeslagen in Downloads — open het om te installeren",
    "Guardado en Descargas — ábrelo para instalar")
add("Check for updates", "Проверять обновления", "检查更新",
    "Nach Updates suchen", "Controleren op updates", "Buscar actualizaciones")
add("Asks GitHub once, when the menu opens, whether a newer release exists. Nothing is sent.",
    "Один запрос к GitHub при открытии меню: есть ли релиз новее. Ничего не отправляется.",
    "打开菜单时向 GitHub 查询一次是否有更新版本。不会发送任何数据。",
    "Fragt GitHub einmal beim Öffnen des Menüs, ob es eine neuere Version gibt. Es wird nichts gesendet.",
    "Vraagt GitHub eenmaal bij het openen van het menu of er een nieuwere versie is. Er wordt niets verzonden.",
    "Pregunta a GitHub una vez, al abrir el menú, si hay una versión más nueva. No se envía nada.")
add("Could not start the download", "Не удалось начать загрузку", "无法开始下载",
    "Download konnte nicht gestartet werden", "Kon de download niet starten",
    "No se pudo iniciar la descarga")
add("Download failed", "Загрузка не удалась", "下载失败",
    "Download fehlgeschlagen", "Download mislukt", "Falló la descarga")
add("The downloaded file is empty", "Скачанный файл пустой", "下载的文件是空的",
    "Die heruntergeladene Datei ist leer", "Het gedownloade bestand is leeg",
    "El archivo descargado está vacío")
add("Could not unpack the update", "Не удалось распаковать обновление", "无法解压更新",
    "Update konnte nicht entpackt werden", "Kon de update niet uitpakken",
    "No se pudo descomprimir la actualización")

# ---------------------------------------------------------------- emit
def gd_escape(s):
    return s.replace('"', '\\"')


def collect_source_strings():
    pats = [
        re.compile(r'G\.(?:label|button)\(\s*"((?:[^"\\]|\\.)*)"'),
        re.compile(r'(?:\.text|placeholder_text|tooltip_text)\s*=\s*"((?:[^"\\]|\\.)*)"'),
        re.compile(r'_(?:show_)?toast\(\s*"((?:[^"\\]|\\.)*)"'),
        re.compile(r'"(?:name|desc|label|title|sub|text)"\s*:\s*"((?:[^"\\]|\\.)*)"'),
        re.compile(r'\btr\(\s*"((?:[^"\\]|\\.)*)"'),
        re.compile(r'_tag\(\s*"((?:[^"\\]|\\.)*)"'),
        # const arrays of plain strings: TABS, dialog lines, disclaimer body
        re.compile(r'^\s*"((?:[^"\\]|\\.)*)",\s*$', re.M),
        re.compile(r'\[\s*((?:"(?:[^"\\]|\\.)*"\s*,\s*)+"(?:[^"\\]|\\.)*")\s*\]'),
    ]
    out = set()
    for f in glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True):
        src = open(f, encoding="utf-8").read()
        for p in pats:
            for m in p.finditer(src):
                g = m.group(1)
                if '", "' in g:
                    parts = re.findall(r'"((?:[^"\\]|\\.)*)"', g)
                else:
                    parts = [g]
                # the regex captures source text, so \" is still escaped there
                # while the table holds the runtime string
                out.update(x.replace('\\"', '"') for x in parts)
    return out


def looks_translatable(s):
    if not s or len(s) < 2 or s in SKIP:
        return False
    if s.startswith("res://") or s.startswith("http"):
        return False
    if s.startswith("/") or "://" in s:
        return False
    if re.fullmatch(r'[a-z0-9_]+', s):        # ids, sfx names, extensions
        return False
    letters = re.sub(r'[^A-Za-z]', '', s)
    return len(letters) >= 2


def hint_strings():
    """Tutorial hints live in songs/tutorial/map.json, not in the scripts."""
    path = os.path.join(ROOT, "songs", "tutorial", "map.json")
    if not os.path.exists(path):
        return set()
    import json
    data = json.load(open(path, encoding="utf-8"))
    return {str(h.get("text", "")) for h in data.get("hints", [])}


def main():
    lines = [
        "extends Node",
        "## Loc - runtime translations. Keys are the English source strings, so every",
        "## Control that already holds English text is translated automatically by",
        "## Godot's auto-translation; no call sites need to change.",
        "##",
        "## GENERATED by tools/gen_loc.py - edit the table there, not this file.",
        "",
        "const LANGS := [",
        '\t{"code": "en", "name": "English"},',
        '\t{"code": "ru", "name": "Русский"},',
        '\t{"code": "zh", "name": "中文"},',
        '\t{"code": "de", "name": "Deutsch"},',
        '\t{"code": "nl", "name": "Nederlands"},',
        '\t{"code": "es", "name": "Español"},',
        "]",
        "",
    ]
    names = {"ru": "RU", "zh": "ZH", "de": "DE", "nl": "NL", "es": "ES"}
    for code in LANGS:
        lines.append("const %s := {" % names[code])
        for en in sorted(T):
            lines.append('\t"%s": "%s",' % (gd_escape(en), gd_escape(T[en][code])))
        lines.append("}")
        lines.append("")
    lines += [
        "",
        "func _ready() -> void:",
        "\tprocess_mode = Node.PROCESS_MODE_ALWAYS",
        "\t_register(\"ru\", RU)",
        "\t_register(\"zh\", ZH)",
        "\t_register(\"de\", DE)",
        "\t_register(\"nl\", NL)",
        "\t_register(\"es\", ES)",
        "\t# G loads before this autoload, so a saved locale is already in place; an",
        "\t# empty one means a first launch and follows the system language",
        "\tif G.locale == \"\":",
        "\t\tG.locale = system_default()",
        "\tapply(G.locale)",
        "",
        "",
        "func _register(code: String, table: Dictionary) -> void:",
        "\tvar t := Translation.new()",
        "\tt.locale = code",
        "\tfor key in table:",
        "\t\tt.add_message(key, str(table[key]))",
        "\tTranslationServer.add_translation(t)",
        "",
        "",
        "func apply(code: String) -> void:",
        "\tTranslationServer.set_locale(code)",
        "",
        "",
        "## Locale guessed from the OS on first launch; falls back to English.",
        "static func system_default() -> String:",
        "\tvar sys := OS.get_locale_language()",
        "\tfor l in LANGS:",
        "\t\tif str(l.code) == sys:",
        "\t\t\treturn sys",
        "\treturn \"en\"",
        "",
        "",
        "static func lang_name(code: String) -> String:",
        "\tfor l in LANGS:",
        "\t\tif str(l.code) == code:",
        "\t\t\treturn str(l.name)",
        "\treturn code",
        "",
    ]
    path = os.path.join(ROOT, "scripts", "Loc.gd")
    open(path, "w", encoding="utf-8").write("\n".join(lines))
    print("wrote %s: %d strings x %d languages" % (path, len(T), len(LANGS)))

    found = collect_source_strings() | hint_strings()
    missing = sorted(s for s in found if looks_translatable(s) and s not in T)
    extra = sorted(s for s in T if s not in found)
    if missing:
        print("\nUNTRANSLATED (%d):" % len(missing))
        for s in missing:
            print("  |%s|" % s.replace("\\n", " / "))
    if extra:
        print("\nnot found in scripts (%d): %s" % (len(extra), ", ".join(extra[:12])))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
