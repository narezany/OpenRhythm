extends Node
## Loc - runtime translations. Keys are the English source strings, so every
## Control that already holds English text is translated automatically by
## Godot's auto-translation; no call sites need to change.

const LANGS := [
	{"code": "en", "name": "English"},
	{"code": "ru", "name": "Русский"},
	{"code": "zh", "name": "中文"},
	{"code": "de", "name": "Deutsch"},
	{"code": "nl", "name": "Nederlands"},
	{"code": "es", "name": "Español"},
]

const RU := {
	"PLAY": "ИГРАТЬ", "MAP EDITOR": "РЕДАКТОР КАРТ", "SONGS": "ПЕСНИ",
	"SETTINGS": "НАСТРОЙКИ", "CREDITS": "АВТОРЫ", "QUIT": "ВЫХОД",
	"STATS": "СТАТИСТИКА", "TOTAL SCORE": "ОБЩИЙ СЧЁТ",
	"free play\nor story mode": "свободная игра\nили история",
	"create maps\nfor any track": "карты\nдля любого трека",
	"manage library\ndelete / disable": "библиотека\nудалить / выключить",
	"audio\ncursor": "звук\nкурсор", "who made this\nand why": "кто сделал\nи зачем",
	"see you soon": "до встречи", "records\nachievements": "рекорды\nдостижения",
	"SELECT SONG": "ВЫБОР ПЕСНИ", "EDITOR — SELECT SONG": "РЕДАКТОР — ВЫБОР ПЕСНИ",
	"← Back": "← Назад", "Back": "Назад", "Esc — back": "Esc — назад",
	"MODIFIERS": "МОДИФИКАТОРЫ", "START": "СТАРТ", "Cancel": "Отмена",
	"NEW MAP": "НОВАЯ КАРТА", "CREATE": "СОЗДАТЬ", "+  NEW MAP": "+  НОВАЯ КАРТА",
	"Library is empty.": "Библиотека пуста.",
	"Modifiers change the score multiplier. Multiplicative.":
		"Модификаторы меняют множитель очков. Перемножаются.",
	"Master volume": "Общая громкость", "Music volume": "Громкость музыки",
	"SFX volume": "Громкость эффектов", "Music": "Музыка", "Effects": "Эффекты",
	"Hitsounds": "Звуки попаданий", "Cursor sensitivity": "Чувствительность курсора",
	"Audio": "Звук", "Video": "Графика", "Accessibility": "Доступность",
	"Controls": "Управление", "Language": "Язык", "Gameplay": "Игра",
	"Fullscreen": "Полный экран", "V-Sync": "Вертикальная синхронизация",
	"FPS limit": "Ограничение FPS", "Audio offset": "Аудио-смещение",
	"Calibrate": "Калибровка", "Reduce motion": "Меньше тряски",
	"Reduce flashes": "Меньше вспышек", "Disable song video": "Отключить видео песен",
	"Cursor size": "Размер курсора", "Gamepad cursor speed": "Скорость стика",
	"Relative touch cursor": "Относительный тач-курсор",
	"MELLY — colors": "MELLY — цвета", "Reset to defaults": "Сбросить",
	"PAUSED": "ПАУЗА", "Resume": "Продолжить", "Restart": "Заново",
	"Main menu": "Главное меню", "ESC — pause": "ESC — пауза",
	"RESULTS": "РЕЗУЛЬТАТЫ", "SCORE": "СЧЁТ", "ACCURACY": "ТОЧНОСТЬ",
	"MAX COMBO": "МАКС. КОМБО", "NEW RECORD": "НОВЫЙ РЕКОРД",
	"Retry": "Ещё раз", "Song select": "К списку песен", "Menu": "Меню",
	"Save replay": "Сохранить реплей", "Replay saved": "Реплей сохранён",
	"STORY MODE": "РЕЖИМ ИСТОРИИ", "LOCKED": "ЗАКРЫТО",
	"Choose your difficulty:": "Выбери сложность:",
	"Library folder:": "Папка библиотеки:", "Copy path": "Копировать путь",
	"RESCAN": "ОБНОВИТЬ", "Enable": "Включить", "Disable": "Выключить",
	"Delete": "Удалить", "Import": "Импорт", "IMPORT MAP": "ИМПОРТ КАРТЫ",
	"Import .sspm / Sound Space map": "Импорт .sspm / карты Sound Space",
	"CALIBRATION": "КАЛИБРОВКА", "Tap on every beat": "Стучи в каждый бит",
	"Taps": "Ударов", "Detected offset": "Найденное смещение",
	"Apply": "Применить", "Reset": "Сброс",
	"Keep tapping — at least 8 taps needed": "Стучи дальше — нужно минимум 8 ударов",
	"Space / click / tap on the beat. The game measures your delay itself.":
		"Пробел / клик / тап в бит. Игра сама измерит твою задержку.",
	"ACHIEVEMENTS": "ДОСТИЖЕНИЯ", "Songs played": "Сыграно песен",
	"Notes hit": "Попаданий", "Best combo": "Лучшее комбо",
	"Play time": "Время в игре", "Locked": "Закрыто",
	"BEFORE YOU START": "ПЕРЕД НАЧАЛОМ", "I understand": "Я понял",
	"Save": "Сохранить", "Play": "Играть", "Pause": "Пауза",
	"Undo": "Отменить", "Redo": "Вернуть", "Copy": "Копировать",
	"Paste": "Вставить", "Select all": "Выделить всё", "Snap": "Сетка",
	"Zoom": "Масштаб", "Speed": "Скорость", "Hold note": "Длинная нота",
	"Notes": "Ноты", "Saved": "Сохранено", "Test": "Тест",
}

const ZH := {
	"PLAY": "开始游戏", "MAP EDITOR": "谱面编辑器", "SONGS": "歌曲",
	"SETTINGS": "设置", "CREDITS": "制作人员", "QUIT": "退出",
	"STATS": "统计", "TOTAL SCORE": "总分",
	"free play\nor story mode": "自由游玩\n或剧情模式",
	"create maps\nfor any track": "为任意曲目\n制作谱面",
	"manage library\ndelete / disable": "管理曲库\n删除 / 禁用",
	"audio\ncursor": "音频\n光标", "who made this\nand why": "谁做的\n为什么",
	"see you soon": "再见", "records\nachievements": "记录\n成就",
	"SELECT SONG": "选择歌曲", "EDITOR — SELECT SONG": "编辑器 — 选择歌曲",
	"← Back": "← 返回", "Back": "返回", "Esc — back": "Esc — 返回",
	"MODIFIERS": "modifier", "START": "开始", "Cancel": "取消",
	"NEW MAP": "新建谱面", "CREATE": "创建", "+  NEW MAP": "+  新建谱面",
	"Library is empty.": "曲库为空。",
	"Modifiers change the score multiplier. Multiplicative.": "modifier 会改变分数倍率，且相互相乘。",
	"Master volume": "主音量", "Music volume": "音乐音量",
	"SFX volume": "音效音量", "Music": "音乐", "Effects": "音效",
	"Hitsounds": "打击音", "Cursor sensitivity": "光标灵敏度",
	"Audio": "音频", "Video": "画面", "Accessibility": "无障碍",
	"Controls": "控制", "Language": "语言", "Gameplay": "玩法",
	"Fullscreen": "全屏", "V-Sync": "垂直同步",
	"FPS limit": "帧率限制", "Audio offset": "音频偏移",
	"Calibrate": "校准", "Reduce motion": "减少画面晃动",
	"Reduce flashes": "减少闪烁", "Disable song video": "关闭歌曲视频",
	"Cursor size": "光标大小", "Gamepad cursor speed": "手柄光标速度",
	"Relative touch cursor": "相对触摸光标",
	"MELLY — colors": "MELLY — 颜色", "Reset to defaults": "恢复默认",
	"PAUSED": "已暂停", "Resume": "继续", "Restart": "重新开始",
	"Main menu": "主菜单", "ESC — pause": "ESC — 暂停",
	"RESULTS": "成绩", "SCORE": "分数", "ACCURACY": "准确率",
	"MAX COMBO": "最大连击", "NEW RECORD": "新纪录",
	"Retry": "重试", "Song select": "选择歌曲", "Menu": "菜单",
	"Save replay": "保存回放", "Replay saved": "回放已保存",
	"STORY MODE": "剧情模式", "LOCKED": "未解锁",
	"Choose your difficulty:": "选择难度：",
	"Library folder:": "曲库文件夹：", "Copy path": "复制路径",
	"RESCAN": "重新扫描", "Enable": "启用", "Disable": "禁用",
	"Delete": "删除", "Import": "导入", "IMPORT MAP": "导入谱面",
	"Import .sspm / Sound Space map": "导入 .sspm / Sound Space 谱面",
	"CALIBRATION": "校准", "Tap on every beat": "跟着每一拍点击",
	"Taps": "点击次数", "Detected offset": "测得偏移",
	"Apply": "应用", "Reset": "重置",
	"Keep tapping — at least 8 taps needed": "继续点击 — 至少需要 8 次",
	"Space / click / tap on the beat. The game measures your delay itself.":
		"跟着节拍按空格 / 点击。游戏会自动测量你的延迟。",
	"ACHIEVEMENTS": "成就", "Songs played": "已游玩歌曲",
	"Notes hit": "命中音符", "Best combo": "最佳连击",
	"Play time": "游戏时长", "Locked": "未解锁",
	"BEFORE YOU START": "开始之前", "I understand": "我明白了",
	"Save": "保存", "Play": "播放", "Pause": "暂停",
	"Undo": "撤销", "Redo": "重做", "Copy": "复制",
	"Paste": "粘贴", "Select all": "全选", "Snap": "吸附",
	"Zoom": "缩放", "Speed": "速度", "Hold note": "长按音符",
	"Notes": "音符", "Saved": "已保存", "Test": "试玩",
}

const DE := {
	"PLAY": "SPIELEN", "MAP EDITOR": "MAP-EDITOR", "SONGS": "SONGS",
	"SETTINGS": "EINSTELLUNGEN", "CREDITS": "CREDITS", "QUIT": "BEENDEN",
	"STATS": "STATISTIK", "TOTAL SCORE": "GESAMTPUNKTE",
	"free play\nor story mode": "freies Spiel\noder Story",
	"create maps\nfor any track": "Maps für jeden\nTrack erstellen",
	"manage library\ndelete / disable": "Bibliothek\nlöschen / deaktivieren",
	"audio\ncursor": "Audio\nCursor", "who made this\nand why": "wer das machte\nund warum",
	"see you soon": "bis bald", "records\nachievements": "Rekorde\nErfolge",
	"SELECT SONG": "SONG WÄHLEN", "EDITOR — SELECT SONG": "EDITOR — SONG WÄHLEN",
	"← Back": "← Zurück", "Back": "Zurück", "Esc — back": "Esc — zurück",
	"MODIFIERS": "MODIFIKATOREN", "START": "START", "Cancel": "Abbrechen",
	"NEW MAP": "NEUE MAP", "CREATE": "ERSTELLEN", "+  NEW MAP": "+  NEUE MAP",
	"Library is empty.": "Bibliothek ist leer.",
	"Modifiers change the score multiplier. Multiplicative.":
		"Modifikatoren ändern den Punktemultiplikator. Multiplikativ.",
	"Master volume": "Gesamtlautstärke", "Music volume": "Musiklautstärke",
	"SFX volume": "Effektlautstärke", "Music": "Musik", "Effects": "Effekte",
	"Hitsounds": "Trefferklänge", "Cursor sensitivity": "Cursor-Empfindlichkeit",
	"Audio": "Audio", "Video": "Grafik", "Accessibility": "Barrierefreiheit",
	"Controls": "Steuerung", "Language": "Sprache", "Gameplay": "Spiel",
	"Fullscreen": "Vollbild", "V-Sync": "V-Sync",
	"FPS limit": "FPS-Limit", "Audio offset": "Audio-Offset",
	"Calibrate": "Kalibrieren", "Reduce motion": "Weniger Bewegung",
	"Reduce flashes": "Weniger Blitze", "Disable song video": "Song-Video aus",
	"Cursor size": "Cursorgröße", "Gamepad cursor speed": "Gamepad-Cursortempo",
	"Relative touch cursor": "Relativer Touch-Cursor",
	"MELLY — colors": "MELLY — Farben", "Reset to defaults": "Zurücksetzen",
	"PAUSED": "PAUSE", "Resume": "Fortsetzen", "Restart": "Neustart",
	"Main menu": "Hauptmenü", "ESC — pause": "ESC — Pause",
	"RESULTS": "ERGEBNIS", "SCORE": "PUNKTE", "ACCURACY": "GENAUIGKEIT",
	"MAX COMBO": "MAX. COMBO", "NEW RECORD": "NEUER REKORD",
	"Retry": "Nochmal", "Song select": "Songauswahl", "Menu": "Menü",
	"Save replay": "Replay speichern", "Replay saved": "Replay gespeichert",
	"STORY MODE": "STORY-MODUS", "LOCKED": "GESPERRT",
	"Choose your difficulty:": "Wähle den Schwierigkeitsgrad:",
	"Library folder:": "Bibliotheksordner:", "Copy path": "Pfad kopieren",
	"RESCAN": "NEU EINLESEN", "Enable": "Aktivieren", "Disable": "Deaktivieren",
	"Delete": "Löschen", "Import": "Importieren", "IMPORT MAP": "MAP IMPORTIEREN",
	"Import .sspm / Sound Space map": ".sspm / Sound-Space-Map importieren",
	"CALIBRATION": "KALIBRIERUNG", "Tap on every beat": "Tippe auf jeden Beat",
	"Taps": "Eingaben", "Detected offset": "Ermittelter Offset",
	"Apply": "Übernehmen", "Reset": "Zurücksetzen",
	"Keep tapping — at least 8 taps needed": "Weiter tippen — mindestens 8 nötig",
	"Space / click / tap on the beat. The game measures your delay itself.":
		"Leertaste / Klick / Tippen im Takt. Das Spiel misst deine Verzögerung selbst.",
	"ACHIEVEMENTS": "ERFOLGE", "Songs played": "Gespielte Songs",
	"Notes hit": "Getroffene Noten", "Best combo": "Beste Combo",
	"Play time": "Spielzeit", "Locked": "Gesperrt",
	"BEFORE YOU START": "BEVOR DU STARTEST", "I understand": "Verstanden",
	"Save": "Speichern", "Play": "Abspielen", "Pause": "Pause",
	"Undo": "Rückgängig", "Redo": "Wiederholen", "Copy": "Kopieren",
	"Paste": "Einfügen", "Select all": "Alles wählen", "Snap": "Raster",
	"Zoom": "Zoom", "Speed": "Tempo", "Hold note": "Halte-Note",
	"Notes": "Noten", "Saved": "Gespeichert", "Test": "Test",
}

const NL := {
	"PLAY": "SPELEN", "MAP EDITOR": "MAP-EDITOR", "SONGS": "NUMMERS",
	"SETTINGS": "INSTELLINGEN", "CREDITS": "CREDITS", "QUIT": "AFSLUITEN",
	"STATS": "STATISTIEK", "TOTAL SCORE": "TOTALE SCORE",
	"free play\nor story mode": "vrij spelen\nof verhaalmodus",
	"create maps\nfor any track": "maps maken\nvoor elk nummer",
	"manage library\ndelete / disable": "bibliotheek\nverwijderen / uitzetten",
	"audio\ncursor": "audio\ncursor", "who made this\nand why": "wie dit maakte\nen waarom",
	"see you soon": "tot snel", "records\nachievements": "records\nprestaties",
	"SELECT SONG": "KIES NUMMER", "EDITOR — SELECT SONG": "EDITOR — KIES NUMMER",
	"← Back": "← Terug", "Back": "Terug", "Esc — back": "Esc — terug",
	"MODIFIERS": "MODIFIERS", "START": "START", "Cancel": "Annuleren",
	"NEW MAP": "NIEUWE MAP", "CREATE": "AANMAKEN", "+  NEW MAP": "+  NIEUWE MAP",
	"Library is empty.": "Bibliotheek is leeg.",
	"Modifiers change the score multiplier. Multiplicative.":
		"Modifiers veranderen de scorevermenigvuldiger. Vermenigvuldigend.",
	"Master volume": "Hoofdvolume", "Music volume": "Muziekvolume",
	"SFX volume": "Effectvolume", "Music": "Muziek", "Effects": "Effecten",
	"Hitsounds": "Hitgeluiden", "Cursor sensitivity": "Cursorgevoeligheid",
	"Audio": "Audio", "Video": "Beeld", "Accessibility": "Toegankelijkheid",
	"Controls": "Besturing", "Language": "Taal", "Gameplay": "Spel",
	"Fullscreen": "Volledig scherm", "V-Sync": "V-Sync",
	"FPS limit": "FPS-limiet", "Audio offset": "Audio-offset",
	"Calibrate": "Kalibreren", "Reduce motion": "Minder beweging",
	"Reduce flashes": "Minder flitsen", "Disable song video": "Videoclip uit",
	"Cursor size": "Cursorgrootte", "Gamepad cursor speed": "Gamepad-cursorsnelheid",
	"Relative touch cursor": "Relatieve touch-cursor",
	"MELLY — colors": "MELLY — kleuren", "Reset to defaults": "Standaard herstellen",
	"PAUSED": "GEPAUZEERD", "Resume": "Hervatten", "Restart": "Opnieuw",
	"Main menu": "Hoofdmenu", "ESC — pause": "ESC — pauze",
	"RESULTS": "RESULTAAT", "SCORE": "SCORE", "ACCURACY": "NAUWKEURIGHEID",
	"MAX COMBO": "MAX COMBO", "NEW RECORD": "NIEUW RECORD",
	"Retry": "Opnieuw", "Song select": "Nummerkeuze", "Menu": "Menu",
	"Save replay": "Replay opslaan", "Replay saved": "Replay opgeslagen",
	"STORY MODE": "VERHAALMODUS", "LOCKED": "VERGRENDELD",
	"Choose your difficulty:": "Kies je moeilijkheid:",
	"Library folder:": "Bibliotheekmap:", "Copy path": "Pad kopiëren",
	"RESCAN": "OPNIEUW SCANNEN", "Enable": "Aanzetten", "Disable": "Uitzetten",
	"Delete": "Verwijderen", "Import": "Importeren", "IMPORT MAP": "MAP IMPORTEREN",
	"Import .sspm / Sound Space map": ".sspm / Sound Space-map importeren",
	"CALIBRATION": "KALIBRATIE", "Tap on every beat": "Tik op elke beat",
	"Taps": "Tikken", "Detected offset": "Gemeten offset",
	"Apply": "Toepassen", "Reset": "Reset",
	"Keep tapping — at least 8 taps needed": "Blijf tikken — minstens 8 nodig",
	"Space / click / tap on the beat. The game measures your delay itself.":
		"Spatie / klik / tik op de beat. Het spel meet je vertraging zelf.",
	"ACHIEVEMENTS": "PRESTATIES", "Songs played": "Gespeelde nummers",
	"Notes hit": "Geraakte noten", "Best combo": "Beste combo",
	"Play time": "Speeltijd", "Locked": "Vergrendeld",
	"BEFORE YOU START": "VOORDAT JE BEGINT", "I understand": "Begrepen",
	"Save": "Opslaan", "Play": "Afspelen", "Pause": "Pauze",
	"Undo": "Ongedaan maken", "Redo": "Opnieuw", "Copy": "Kopiëren",
	"Paste": "Plakken", "Select all": "Alles selecteren", "Snap": "Raster",
	"Zoom": "Zoom", "Speed": "Snelheid", "Hold note": "Houdnoot",
	"Notes": "Noten", "Saved": "Opgeslagen", "Test": "Test",
}

const ES := {
	"PLAY": "JUGAR", "MAP EDITOR": "EDITOR DE MAPAS", "SONGS": "CANCIONES",
	"SETTINGS": "AJUSTES", "CREDITS": "CRÉDITOS", "QUIT": "SALIR",
	"STATS": "ESTADÍSTICAS", "TOTAL SCORE": "PUNTUACIÓN TOTAL",
	"free play\nor story mode": "juego libre\no modo historia",
	"create maps\nfor any track": "crea mapas\npara cualquier tema",
	"manage library\ndelete / disable": "biblioteca\nborrar / desactivar",
	"audio\ncursor": "audio\ncursor", "who made this\nand why": "quién lo hizo\ny por qué",
	"see you soon": "hasta pronto", "records\nachievements": "récords\nlogros",
	"SELECT SONG": "ELIGE CANCIÓN", "EDITOR — SELECT SONG": "EDITOR — ELIGE CANCIÓN",
	"← Back": "← Atrás", "Back": "Atrás", "Esc — back": "Esc — atrás",
	"MODIFIERS": "MODIFICADORES", "START": "EMPEZAR", "Cancel": "Cancelar",
	"NEW MAP": "NUEVO MAPA", "CREATE": "CREAR", "+  NEW MAP": "+  NUEVO MAPA",
	"Library is empty.": "La biblioteca está vacía.",
	"Modifiers change the score multiplier. Multiplicative.":
		"Los modificadores cambian el multiplicador de puntos. Se multiplican entre sí.",
	"Master volume": "Volumen general", "Music volume": "Volumen de música",
	"SFX volume": "Volumen de efectos", "Music": "Música", "Effects": "Efectos",
	"Hitsounds": "Sonidos de golpe", "Cursor sensitivity": "Sensibilidad del cursor",
	"Audio": "Audio", "Video": "Vídeo", "Accessibility": "Accesibilidad",
	"Controls": "Controles", "Language": "Idioma", "Gameplay": "Juego",
	"Fullscreen": "Pantalla completa", "V-Sync": "V-Sync",
	"FPS limit": "Límite de FPS", "Audio offset": "Desfase de audio",
	"Calibrate": "Calibrar", "Reduce motion": "Reducir movimiento",
	"Reduce flashes": "Reducir destellos", "Disable song video": "Desactivar vídeo",
	"Cursor size": "Tamaño del cursor", "Gamepad cursor speed": "Velocidad del stick",
	"Relative touch cursor": "Cursor táctil relativo",
	"MELLY — colors": "MELLY — colores", "Reset to defaults": "Restablecer",
	"PAUSED": "EN PAUSA", "Resume": "Continuar", "Restart": "Reiniciar",
	"Main menu": "Menú principal", "ESC — pause": "ESC — pausa",
	"RESULTS": "RESULTADOS", "SCORE": "PUNTUACIÓN", "ACCURACY": "PRECISIÓN",
	"MAX COMBO": "COMBO MÁX.", "NEW RECORD": "NUEVO RÉCORD",
	"Retry": "Reintentar", "Song select": "Lista de canciones", "Menu": "Menú",
	"Save replay": "Guardar repetición", "Replay saved": "Repetición guardada",
	"STORY MODE": "MODO HISTORIA", "LOCKED": "BLOQUEADO",
	"Choose your difficulty:": "Elige la dificultad:",
	"Library folder:": "Carpeta de biblioteca:", "Copy path": "Copiar ruta",
	"RESCAN": "REESCANEAR", "Enable": "Activar", "Disable": "Desactivar",
	"Delete": "Borrar", "Import": "Importar", "IMPORT MAP": "IMPORTAR MAPA",
	"Import .sspm / Sound Space map": "Importar .sspm / mapa de Sound Space",
	"CALIBRATION": "CALIBRACIÓN", "Tap on every beat": "Toca en cada tiempo",
	"Taps": "Toques", "Detected offset": "Desfase detectado",
	"Apply": "Aplicar", "Reset": "Reiniciar",
	"Keep tapping — at least 8 taps needed": "Sigue tocando — hacen falta 8 como mínimo",
	"Space / click / tap on the beat. The game measures your delay itself.":
		"Espacio / clic / toque al ritmo. El juego mide tu retardo por sí solo.",
	"ACHIEVEMENTS": "LOGROS", "Songs played": "Canciones jugadas",
	"Notes hit": "Notas acertadas", "Best combo": "Mejor combo",
	"Play time": "Tiempo jugado", "Locked": "Bloqueado",
	"BEFORE YOU START": "ANTES DE EMPEZAR", "I understand": "Entendido",
	"Save": "Guardar", "Play": "Reproducir", "Pause": "Pausa",
	"Undo": "Deshacer", "Redo": "Rehacer", "Copy": "Copiar",
	"Paste": "Pegar", "Select all": "Seleccionar todo", "Snap": "Ajuste",
	"Zoom": "Zoom", "Speed": "Velocidad", "Hold note": "Nota mantenida",
	"Notes": "Notas", "Saved": "Guardado", "Test": "Probar",
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register("ru", RU)
	_register("zh", ZH)
	_register("de", DE)
	_register("nl", NL)
	_register("es", ES)
	# G loads before this autoload, so a saved locale is already in place; an
	# empty one means a first launch and follows the system language
	if G.locale == "":
		G.locale = system_default()
	apply(G.locale)


func _register(code: String, table: Dictionary) -> void:
	var t := Translation.new()
	t.locale = code
	for key in table:
		t.add_message(key, str(table[key]))
	TranslationServer.add_translation(t)


func apply(code: String) -> void:
	TranslationServer.set_locale(code)


## Locale guessed from the OS on first launch; falls back to English.
static func system_default() -> String:
	var sys := OS.get_locale_language()
	for l in LANGS:
		if str(l.code) == sys:
			return sys
	return "en"


static func lang_name(code: String) -> String:
	for l in LANGS:
		if str(l.code) == code:
			return str(l.name)
	return code
