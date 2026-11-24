-- ================================================================
--  «Игра в Слова» [Roblox] — Universal Auto-Typer v34 (PC + Mobile)
--  База 450k+ слов (CP1251 + UTF-8) | 0% ошибок | Фикс управления ТФ
-- ================================================================

-- ── 1. ЗАЩИТА ОТ ДВОЙНОГО ЗАПУСКА ──
if _G.WordBotConnections then
    for _, conn in ipairs(_G.WordBotConnections) do
        pcall(function() conn:Disconnect() end)
    end
end
_G.WordBotConnections = {}

if _G.WordBotGui then
    pcall(function() _G.WordBotGui:Destroy() end)
    _G.WordBotGui = nil
end

_G.WordBotToken = (_G.WordBotToken or 0) + 1
local myToken = _G.WordBotToken
_G.WordBotGlobalTyping = false

local autoMode = false
local hardMode = false
local profaneMode = false
local PROFANE_WORDS = {}
local BLACKLIST = {}
local BLACKLIST_FILE = "WordBot_Blacklist.txt"
local MAX_DICT_WORDS = 450000

local function addConn(conn)
    table.insert(_G.WordBotConnections, conn)
    return conn
end

local Players         = game:GetService("Players")
local UIS             = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local LP              = Players.LocalPlayer
local PlayerGui       = LP:WaitForChild("PlayerGui")
local Camera          = workspace.CurrentCamera

local isMobile = UIS.TouchEnabled and (not UIS.KeyboardEnabled or Camera.ViewportSize.X <= 950)

-- Таблицы кириллицы (UTF-8)
local CYR_UP = {
    ["А"]="А",["Б"]="Б",["В"]="В",["Г"]="Г",["Д"]="Д",["Е"]="Е",["Ё"]="Ё",["Ж"]="Ж",
    ["З"]="З",["И"]="И",["Й"]="Й",["К"]="К",["Л"]="Л",["М"]="М",["Н"]="Н",["О"]="О",
    ["П"]="П",["Р"]="Р",["С"]="С",["Т"]="Т",["У"]="У",["Ф"]="Ф",["Х"]="Х",["Ц"]="Ц",
    ["Ч"]="Ч",["Ш"]="Ш",["Щ"]="Щ",["Ъ"]="Ъ",["Ы"]="Ы",["Ь"]="Ь",["Э"]="Э",["Ю"]="Ю",["Я"]="Я",
    ["а"]="А",["б"]="Б",["в"]="В",["г"]="Г",["д"]="Д",["е"]="Е",["ё"]="Ё",["ж"]="Ж",
    ["з"]="З",["и"]="И",["й"]="Й",["к"]="К",["л"]="Л",["м"]="М",["н"]="Н",["о"]="О",
    ["п"]="П",["р"]="Р",["с"]="С",["т"]="Т",["у"]="У",["ф"]="Ф",["х"]="Х",["ц"]="Ц",
    ["ч"]="Ч",["ш"]="Ш",["щ"]="Щ",["ъ"]="Ъ",["ы"]="Ы",["ь"]="Ь",["э"]="Э",["ю"]="Ю",["я"]="Я"
}

local CYR_LOW = {
    ["А"]="а",["Б"]="б",["В"]="в",["Г"]="г",["Д"]="д",["Е"]="е",["Ё"]="ё",["Ж"]="ж",
    ["З"]="з",["И"]="и",["Й"]="й",["К"]="к",["Л"]="л",["М"]="м",["Н"]="н",["О"]="о",
    ["П"]="п",["Р"]="р",["С"]="с",["Т"]="т",["У"]="у",["Ф"]="ф",["Х"]="х",["Ц"]="ц",
    ["Ч"]="ч",["Ш"]="ш",["Щ"]="щ",["Ъ"]="ъ",["Ы"]="ы",["Ь"]="ь",["Э"]="э",["Ю"]="ю",["Я"]="я"
}

-- Таблица CP1251 -> UTF-8 (верхний регистр) для огромной базы на 450k+ слов
local CP1251_UP = {}
do
    local letters = {
        "А","Б","В","Г","Д","Е","Ж","З","И","Й","К","Л","М","Н","О","П",
        "Р","С","Т","У","Ф","Х","Ц","Ч","Ш","Щ","Ъ","Ы","Ь","Э","Ю","Я"
    }
    CP1251_UP[168] = "Ё"
    CP1251_UP[184] = "Ё"
    for i = 1, 32 do
        CP1251_UP[191 + i] = letters[i]
        CP1251_UP[223 + i] = letters[i]
    end
end

local function cp1251ToUpperCyr(str)
    local len = #str
    if len < 3 or len > 24 then return nil end
    local res = table.create(len)
    for i = 1, len do
        local u = CP1251_UP[string.byte(str, i)]
        if not u then return nil end
        res[i] = u
    end
    return table.concat(res)
end

local function utf8chars(s)
    local t = {}
    for _, code in utf8.codes(s) do
        table.insert(t, utf8.char(code))
    end
    return t
end

local function toUpperCyr(str)
    if not str or str == "" then return nil end
    if str:find("[%z\1-\127]") then return nil end
    local ok = true
    local res = str:gsub("[\192-\255][\128-\191]*", function(ch)
        local u = CYR_UP[ch]
        if not u then
            ok = false
            return ""
        end
        return u
    end)
    if not ok or res == "" then return nil end
    return res
end

local function toLowerCyr(str)
    if not str or str == "" then return "" end
    return (str:gsub("[\192-\255][\128-\191]*", function(ch)
        return CYR_LOW[ch] or ch
    end):lower())
end

local function toLowerCyrChar(ch)
    return CYR_LOW[ch] or string.lower(ch)
end

local function cyrLen(w)
    return math.floor(#w / 2)
end

local function isSitting()
    local char = LP.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    return hum.Sit == true or hum.SeatPart ~= nil
end

-- Восстановление сенсорного управления на ТФ после раунда
local function restoreMobileControls()
    if not isMobile then return end
    pcall(function()
        local focused = UIS:GetFocusedTextBox()
        if focused then
            focused:ReleaseFocus(false)
        end
        local touchGui = PlayerGui:FindFirstChild("TouchGui")
        if touchGui then
            touchGui.Enabled = true
        end
    end)
end

-- ── ВЕЧНЫЙ ЧЁРНЫЙ СПИСОК ──
local function loadBlacklist()
    pcall(function()
        if typeof(isfile) == "function" and typeof(readfile) == "function" and isfile(BLACKLIST_FILE) then
            local data = readfile(BLACKLIST_FILE)
            for line in data:gmatch("[^\r\n]+") do
                local up = toUpperCyr(line:gsub("^%s+", ""):gsub("%s+$", ""))
                if up then BLACKLIST[up] = true end
            end
        end
    end)
end

local function addToBlacklist(word)
    if not word or BLACKLIST[word] then return end
    BLACKLIST[word] = true
    pcall(function()
        if typeof(appendfile) == "function" and typeof(isfile) == "function" and isfile(BLACKLIST_FILE) then
            appendfile(BLACKLIST_FILE, word .. "\n")
        elseif typeof(writefile) == "function" then
            local list = {}
            for w in pairs(BLACKLIST) do table.insert(list, w) end
            writefile(BLACKLIST_FILE, table.concat(list, "\n") .. "\n")
        end
    end)
end

loadBlacklist()

-- ── 2. СЛОВАРЬ (ПОПУЛЯРНЫЕ + ОНЛАЙН-БАЗЫ НА 450K+) ──
local RAW = {
    ["Ё"]="ЁМКОСТЬ,ЁЖИК,ЁЛКА,ЁРШ,ЁЛОЧКА,ЁРШИК",
    ["А"]="АВТОМОБИЛЬ,АВТОБУС,АВТОРИТЕТ,АВТОМАТИКА,АВТОСТРАДА,АВАНГАРД,АВИАНОСЕЦ,АВИАЦИЯ,АПЕЛЬСИН,АПЛОДИСМЕНТЫ,АППАРАТ,АПТЕКАРЬ,АККУМУЛЯТОР,АКАДЕМИЯ,АКВАРИУМ,АККОРДЕОН,АКРОБАТ,АКТИВИСТ,АРИСТОКРАТ,АРХИТЕКТУРА,АРГУМЕНТ,АРТИЛЛЕРИСТ,АРХИВАТОР,АРХЕОЛОГ,АРБУЗ,АСТЕРОИД,АСТРОНАВТ,АСТРОНОМИЯ,АСПИРИН,АСФАЛЬТ,АДМИРАЛ,АДРЕСАТ,АДВОКАТ,АЛЬБАТРОС,АЛЬБОМ,АЛЮМИНИЙ,АНАНАС,АНАЛИЗАТОР,АНТЕННА,АНСАМБЛЬ,АТТРАКЦИОН,АТЛЕТИКА,АТМОСФЕРА,АУДИТОРИЯ,АЭРОПОРТ,АЭРОДРОМ,АМФИТЕАТР,АБРИКОС,АБСОЛЮТ,АГЕНТСТВО,АГРОНОМ,АДАПТЕР,АЛГОРИТМ,АЛФАВИТ,АМАЗОНКА,АМЕРИКАНЕЦ,АМФИБИЯ,АНЕКДОТ,АНОМАЛИЯ,АНТИЛОПА,АРСЕНАЛ,АРТИСТ,АССОРТИМЕНТ,АТАМАН,АТЛАНТИДА,АУКЦИОН,АФРИКА,АФИША,АФОРИЗМ,АФЁРА,АФРИКАНЕЦ,АФГАНИСТАН,АФРОДИТА,АФФЕКТ",
    ["Б"]="БИБЛИОТЕКА,БИОГРАФИЯ,БИОЛОГИЯ,БИНОКЛЬ,БИЗНЕСМЕН,БЕСПИЛОТНИК,БЕЗОПАСНОСТЬ,БЕГЕМОТ,БЕСЕДКА,БЕТОНОМЕШАЛКА,БЕРЕГ,БЕРЁЗА,БАРАБАНЩИК,БАКЛАЖАН,БАССЕЙН,БАБОЧКА,БАДМИНТОН,БАЛАЛАЙКА,БАТАРЕЯ,БАЛЬЗАМ,БАНКОМАТ,БАРОМЕТР,БАЛКОН,БАНАН,БАНДИТ,БАРЬЕР,БУТЕРБРОД,БУДИЛЬНИК,БУМЕРАНГ,БУЛЬВАР,БУМАЖНИК,БУЛЬДОЗЕР,БУКВАРЬ,БОЛЕЛЬЩИК,БОГАТЫРЬ,БОМБАРДИРОВЩИК,БОТАНИК,БОКСЁР,БОЛОТО,БОЛЬНИЦА,БЛОКНОТ,БЛОКБАСТЕР,БЛАГОДАРНОСТЬ,БРИЛЛИАНТ,БРАСЛЕТ,БРОНЕНОСЕЦ,БРОНЕЖИЛЕТ,БРАТСТВО,БРИГАДИР,БРОНЗА,БРЮКИ,БУХГАЛТЕР,БЫСТРОТА,БЮДЖЕТ",
    ["В"]="ВЕЛОСИПЕД,ВЕЛОТРЕК,ВЕНТИЛЯТОР,ВЕРТОЛЁТ,ВЕРНИСАЖ,ВЕЛИЧЕСТВО,ВЕЛИКАН,ВЕЖЛИВОСТЬ,ВЕЩЕСТВО,ВЕСТИБЮЛЬ,ВЕРШИНА,ВЕСНА,ВЕТЕРАН,ВДОХНОВЕНИЕ,ВСЕЛЕННАЯ,ВОДОХРАНИЛИЩЕ,ВОДОПАД,ВОДОРОСЛЬ,ВОЕННОСЛУЖАЩИЙ,ВОЗДУХООЧИСТИТЕЛЬ,ВОСПИТАТЕЛЬ,ВОКЗАЛ,ВОЛЕЙБОЛ,ВОЛШЕБНИК,ВОСПОМИНАНИЕ,ВИНОГРАДНИК,ВИНОГРАД,ВИЗИТЁР,ВИДЕОКАМЕРА,ВИТАМИН,ВИТРИНА,ВУЛКАНОЛОГ,ВУЛКАНИЗАТОР,ВУЛКАН,ВЫКЛЮЧАТЕЛЬ,ВЫСТАВКА,ВЫЧИСЛИТЕЛЬ,ВЫПУСКНИК,ВАГОН,ВАРЕНЬЕ,ВАСИЛЁК,ВАРИАНТ,ВАКЦИНА,ВАМПИР,ВАНИЛЬ,ВСПЫШКА,ВСАДНИК,ВСТРЕЧА,ВТОРНИК,ВХОД",
    ["Г"]="ГОСУДАРСТВО,ГОРИЗОНТ,ГОДОВЩИНА,ГОЛУБИКА,ГОСТИНИЦА,ГОРНОЛЫЖНИК,ГОСПИТАЛЬ,ГОЛОВОЛОМКА,ГОРОД,ГОРЧИЦА,ГИПЕРМАРКЕТ,ГИППОПОТАМ,ГИРЛЯНДА,ГИДРОПЛАН,ГИМНАСТИКА,ГИТАРА,ГАЛАКТИКА,ГАРДЕРОБЩИК,ГАРМОНИЯ,ГАСТРОНОМ,ГАЗЕТА,ГАРАЖ,ГАРНИЗОН,ГРОМООТВОД,ГРОМКОГОВОРИТЕЛЬ,ГРУЗОВИК,ГРАММАТИКА,ГРАДУСНИК,ГРАВИТАЦИЯ,ГРАФОПОСТРОИТЕЛЬ,ГРАНАТ,ГРАНИЦА,ГРЕЙПФРУТ,ГЕОГРАФИЯ,ГЕНЕРАТОР,ГЕРМАНИЙ,ГЕРОЙ,ГЕОЛОГИЯ,ГЕОМЕТРИЯ,ГУСЕНИЦА,ГУМАНОИД,ГУБЕРНАТОР,ГЛАДИАТОР,ГЛИЦЕРИН,ГЛОБУС,ГЛУБИНА,ГНЕЗДО,ГРЕЧКА",
    ["Д"]="ДОСТОПРИМЕЧАТЕЛЬНОСТЬ,ДОКУМЕНТАЦИЯ,ДОБРОТА,ДОКЛАДЧИК,ДОМОФОН,ДОРОГА,ДОСТАВКА,ДИРИЖАБЛЬ,ДИНОЗАВР,ДИРИЖЁР,ДИАГРАММА,ДИСКОТЕКА,ДИАГНОСТИКА,ДИАМЕТР,ДИВИДЕНД,ДИЗАЙНЕР,ДИКТОФОН,ДИПЛОМАТ,ДИСПЕТЧЕР,ДИСТАНЦИЯ,ДИРЕКТОР,ДРЕССИРОВЩИК,ДРАГОЦЕННОСТЬ,ДРАКОН,ДРУЖБА,ДЕЗИНФЕКЦИЯ,ДЕТЕКТИВ,ДЕКОРАЦИЯ,ДЕМОНСТРАТОР,ДЕПОЗИТАРИЙ,ДЕТОНАТОР,ДЕКАБРЬ,ДЕЛЬФИН,ДЕМОКРАТИЯ,ДЕРЕВНЯ,ДВИГАТЕЛЬ,ДВОРЕЦ,ДУРШЛАГ,ДУБЛИКАТ,ДУЭЛЬ,ДНЕВНИК,ДАВЛЕНИЕ,ДАЛЬНОБОЙЩИК,ДАНТИСТ,ДЕСЕРТ,ДЕТАЛЬ,ДИВАН,ДОЖДЬ,ДОКТОР",
    ["Е"]="ЕДИНОМЫШЛЕННИК,ЕДИНОРОГ,ЕДИНСТВО,ЕСТЕСТВОИСПЫТАТЕЛЬ,ЕСТЕСТВЕННИК,ЕЖЕДНЕВНИК,ЕЖЕВИКА,ЕПИСКОП,ЕВРОПЕЕЦ,ЕРАЛАШ,ЕГЕРЬ,ЕХИДНА,ЕНОТ",
    ["Ж"]="ЖЕЛЕЗНОДОРОЖНИК,ЖЕСТОКОСТЬ,ЖЕРЕБЁНОК,ЖЕЛАНИЕ,ЖЕМЧУЖИНА,ЖЕМЧУГ,ЖЕЛЕЗО,ЖЕТОН,ЖЕЛУДОК,ЖЕНЬШЕНЬ,ЖИЗНЕДЕЯТЕЛЬНОСТЬ,ЖИВОПИСЕЦ,ЖИЛЕТ,ЖИТЕЛЬ,ЖИВОТНОЕ,ЖИРАФ,ЖУРНАЛИСТ,ЖУРАВЛЬ,ЖУРНАЛ,ЖАВОРОНОК,ЖАРОВНЯ,ЖАКЕТ,ЖАЛОБА,ЖАСМИН,ЖОНГЛЁР,ЖВАЧКА",
    ["З"]="ЗАКОНОДАТЕЛЬСТВО,ЗАПОВЕДНИК,ЗАЖИГАЛКА,ЗАКЛАДКА,ЗАПЯСТЬЕ,ЗАТМЕНИЕ,ЗАВОД,ЗАВТРАК,ЗАГАДКА,ЗАДАНИЕ,ЗАГОЛОВОК,ЗАКАЗЧИК,ЗАКЛЮЧЕНИЕ,ЗАКОНОПРОЕКТ,ЗАМЕСТИТЕЛЬ,ЗАЩИТНИК,ЗАМОК,ЗАНАВЕСКА,ЗАРЯДКА,ЗЕМЛЕТРЯСЕНИЕ,ЗЕМЛЕДЕЛИЕ,ЗЕМЛЯНИКА,ЗЕРКАЛО,ЗЕБРА,ЗЕЛЕНЬ,ЗВЕЗДОЧЁТ,ЗВУКОРЕЖИССЁР,ЗВЕЗДА,ЗНАМЕНИТОСТЬ,ЗНАНИЕ,ЗООПАРК,ЗДАНИЕ,ЗДОРОВЬЕ,ЗРИТЕЛЬ,ЗИМА,ЗОЛОТО,ЗОНТИК",
    ["И"]="ИССЛЕДОВАТЕЛЬ,ИСКУССТВО,ИСТОЧНИК,ИСПЫТАНИЕ,ИСТОРИЯ,ИЗОБРЕТАТЕЛЬ,ИЗОБРАЖЕНИЕ,ИЗЛУЧЕНИЕ,ИЗУМРУД,ИЗБУШКА,ИЗГОРОДЬ,ИЗБИРАТЕЛЬ,ИЗВЕСТИЕ,ИЛЛЮСТРАЦИЯ,ИЛЛЮМИНАТОР,ИЛЛЮЗИЯ,ИНСТРУМЕНТ,ИНОПЛАНЕТЯНИН,ИНКУБАТОР,ИНФОРМАЦИЯ,ИНЖЕНЕР,ИНТЕРНЕТ,ИНСТРУКТОР,ИНСТИТУТ,ИНТЕЛЛЕКТ,ИНТЕРЕС,ИМЕНИННИК,ИМПЕРИЯ,ИММУНИТЕТ,ИМПЕРАТОР,ИГРУШКА,ИГРОК,ИЕРОГЛИФ,ИДЕАЛ,ИДЕЯ,ИКОНА,ИМБИРЬ,ИНДЕЕЦ,ИНДИКАТОР,ИНДУСТРИЯ,ИСКРА,ИСПАНЕЦ,ИСТИНА",
    ["Й"]="ЙОГУРТ,ЙОДИД,ЙОРК,ЙЕТИ,ЙОТА,ЙОД,ЙОГА",
    ["К"]="КИНЕМАТОГРАФ,КИНОТЕАТР,КИСЛОРОД,КИБЕРНЕТИКА,КИРПИЧ,КАЛЬКУЛЯТОР,КАЛЕЙДОСКОП,КАРАНДАШ,КАРТОФЕЛЬ,КАРУСЕЛЬ,КАТАСТРОФА,КАРТОН,КАСТРЮЛЯ,КАТАЛОГ,КАПИТАН,КАПУСТА,КАРНАВАЛ,КАРТИНА,КОЛОКОЛЬЧИК,КОНСЕРВАТОРИЯ,КОНСТРУКТОР,КОСМОНАВТ,КОМАНДИРОВКА,КОЛЛЕКЦИЯ,КОМПЬЮТЕР,КОРОЛЕВА,КОЛОДЕЦ,КОМБИНЕЗОН,КОМПОЗИТОР,КОНДИТЕР,КОНФЕРЕНЦИЯ,КОРАБЛЕСТРОИТЕЛЬ,КОМАНДА,КОМПАС,КОНВЕРТ,КОНФЕТА,КОРАБЛЬ,КОРОБКА,КОСМОС,КОСТЮМ,КУКУРУЗА,КУСТАРНИК,КУВШИН,КУЗНЕЧИК,КУЛЬТУРА,КУРТКА,КЕРАМИКА,КЕНГУРУ,КЛАВИАТУРА,КЛИЕНТУРА,КЛАССИКА,КНИГА,КНОПКА,КРЕПОСТЬ,КРИСТАЛЛ,КРОКОДИЛ",
    ["Л"]="ЛАБОРАТОРИЯ,ЛАБИРИНТ,ЛАСТОЧКА,ЛАКОМСТВО,ЛАНДШАФТ,ЛАМПОЧКА,ЛАВИНА,ЛЕСОРУБ,ЛЕДОКОЛ,ЛЕКАРСТВО,ЛЕПЕСТОК,ЛЕСТНИЦА,ЛЕГЕНДА,ЛЕЙКОЦИТ,ЛЕТОПИСЕЦ,ЛЕОПАРД,ЛЕСНИК,ЛИСТОПАД,ЛИТЕРАТУРА,ЛИМОНАД,ЛИХОРАДКА,ЛИЧНОСТЬ,ЛИКВИДАТОР,ЛИМОН,ЛИНЕЙКА,ЛИСИЦА,ЛОКОМОТИВ,ЛОБСТЕР,ЛОТЕРЕЯ,ЛОГОПЕД,ЛОДКА,ЛОЖКА,ЛОШАДЬ,ЛУНОХОД,ЛУКОШКО,ЛУНА,ЛЮБОПЫТСТВО,ЛЮМИНИСЦЕНЦИЯ,ЛЮСТРА,ЛЬВЁНОК,ЛЫЖНИК,ЛЯГУШКА",
    ["М"]="МАШИНОСТРОЕНИЕ,МАГНИТОФОН,МАНДАРИН,МАТРЁШКА,МАГАЗИН,МАТЕРИАЛ,МАГИСТРАЛЬ,МАКЕТИРОВАНИЕ,МАНИПУЛЯТОР,МАРШРУТИЗАТОР,МАЙОНЕЗ,МАЛИНА,МАМОНТ,МАРМЕЛАД,МАРШРУТ,МАСТЕР,МАТЕМАТИКА,МОТОЦИКЛИСТ,МОТОЦИКЛ,МОЛОТОК,МОНАСТЫРЬ,МОНИТОР,МОЛЕКУЛА,МОЛНИЯ,МОЛОКО,МОНЕТА,МОРКОВЬ,МОРОЖЕНОЕ,МИКРОСКОП,МИКРОФОН,МИЛЛИОНЕР,МИНЕРАЛ,МИНИСТР,МИНУТА,МЕТАЛЛУРГИЯ,МЕЛЬНИЦА,МЕТЕОРИТ,МЕХАНИЗМ,МЕДИАКОНТЕНТ,МЕТЕОРОЛОГ,МЕДВЕДЬ,МЕДИЦИНА,МЕЛОДИЯ,МНОГОУГОЛЬНИК,МУРАВЕЙНИК,МУЗЕЙ,МУЗЫКАНТ,МУЛЬТФИЛЬМ,МЫШЛЕНИЕ,МЯСНИК",
    ["Н"]="НАБЛЮДАТЕЛЬ,НАКОПИТЕЛЬ,НАВИГАТОР,НАВОЛОЧКА,НАГРУЗКА,НАЕЗДНИК,НАКЛЕЙКА,НАКОВАЛЬНЯ,НАПЁРСТОК,НАПРАВЛЕНИЕ,НАСЕКОМОЕ,НАСЛЕДСТВО,НАСТРОЕНИЕ,НАХОДКА,НАГРАДА,НАПИТОК,НАЗВАНИЕ,НАМЕРЕНИЕ,НАНИМАТЕЛЬ,НАРУШИТЕЛЬ,НАТЮРМОРТ,НАЧАЛЬНИК,НАУКА,НАУШНИКИ,НЕВЕСОМОСТЬ,НЕБОСКРЁБ,НЕЙТРОН,НЕДЕЛЯ,НЕФТЬ,НОУТБУК,НОСОРОГ,НОЖНИЦЫ,НОМЕР,НОСОК,НОЧЬ,НУМЕРАЦИЯ,НЯНЯ",
    ["О"]="ОГНЕТУШИТЕЛЬ,ОГОРОД,ОГУРЕЦ,ОБОРУДОВАНИЕ,ОБСЕРВАТОРИЯ,ОБСТОЯТЕЛЬСТВО,ОБЕЗЬЯНА,ОБЁРТКА,ОБИТАТЕЛЬ,ОБЛАКО,ОБЛОЖКА,ОБЪЕКТИВ,ОБВИНЕНИЕ,ОБЛАДАТЕЛЬ,ОБНОВЛЕНИЕ,ОБРАЗОВАНИЕ,ОБЫВАТЕЛЬ,ОБЩЕЖИТИЕ,ОДНОКЛАССНИК,ОДУВАНЧИК,ОДЕЯЛО,ОДЕЖДА,ОСВЕЩЕНИЕ,ОСЕНЬ,ОСТРОВ,ОКЕАНОЛОГ,ОКЕАН,ОЛИМПИАДА,ОЛЕНЬ,ОПЕРАЦИЯ,ОПЕРАТОР,ОПРЕДЕЛИТЕЛЬ,ОРАНГУТАН,ОРКЕСТР,ОРБИТА,ОРГАНИЗМ,ОТВЁРТКА,ОТПЕЧАТОК,ОТШЕЛЬНИК,ОТКРЫТИЕ,ОТПУСК,ОГРАНИЧИТЕЛЬ,ОФИЦЕР,ОХОТНИК,ОЧКИ",
    ["П"]="ПУТЕШЕСТВЕННИК,ПУТЕШЕСТВИЕ,ПУГОВИЦА,ПУСТЫНЯ,ПАРАШЮТИСТ,ПАРОХОДСТВО,ПАРИКМАХЕР,ПАНОРАМА,ПАСТУХ,ПАКЕТ,ПАЛАТКА,ПАЛЬМА,ПАМЯТНИК,ПАНДА,ПАРОЛЬ,ПАСПОРТ,ПАУК,ПОНЕДЕЛЬНИК,ПОДСНЕЖНИК,ПОДСОЛНУХ,ПОЛИКЛИНИКА,ПОЛОТЕНЦЕ,ПОРОШОК,ПОРТРЕТ,ПОРТФЕЛЬ,ПОСЛАНИЕ,ПОСУДА,ПОТОЛОК,ПОБЕДА,ПОДАРОК,ПОДВОДНИК,ПОЕЗД,ПОЖАРНИК,ПОЛИЦИЯ,ПОМИДОР,ПОПУГАЙ,ПРЕПОДАВАТЕЛЬ,ПРЕДМЕТ,ПРЕЗИДЕНТ,ПРОИЗВОДСТВО,ПРОГРАММА,ПРОЕКТ,ПРОФЕССОР,ПРОДАВЕЦ,ПРОДУКТ,ПРОЖЕКТОР,ПРОСПЕКТ,ПРАВИЛО,ПРАЗДНИК,ПРАКТИКА,ПРИКЛЮЧЕНИЕ,ПРИРОДА,ПРИСТАНЬ,ПРИБОР,ПРИНТЕР,ПРИНЦЕССА,ПЕЙЗАЖ,ПЕЛИКАН,ПЕЛЬМЕНИ,ПЕНАЛ,ПЕНСИОНЕР,ПЕРЧАТКА,ПЕСНЯ,ПИНГВИН,ПИРАМИДА,ПИРАТ,ПИРОЖНОЕ,ПИСАТЕЛЬ,ПИСТОЛЕТ,ПЛАНЕТА,ПЛАСТИЛИН,ПЛОЩАДЬ,ПЬЕДЕСТАЛ,ПЧЕЛА,ПЫЛЕСОС",
    ["Р"]="РАДИОПРИЁМНИК,РАДИАТОР,РАСПИСАНИЕ,РАКЕТОДРОМ,РАВНОВЕСИЕ,РАЗВЕДЧИК,РАЗРАБОТЧИК,РАСПРЕДЕЛИТЕЛЬ,РАССТОЯНИЕ,РАБОТНИК,РАДУГА,РАКЕТА,РАСТЕНИЕ,РАСЧЁСКА,РУКОВОДИТЕЛЬ,РУКОЯТКА,РУСАЛКА,РУБАШКА,РУКЗАК,РУЧКА,РЫБОЛОВСТВО,РЫЦАРЬ,РЕВОЛЬВЕР,РЕЖИССЁР,РЕПЕТИЦИЯ,РЕПОРТАЖ,РЕСПУБЛИКА,РЕСТОРАН,РЕАКТИВ,РЕБЁНОК,РЕВОЛЮЦИЯ,РЕДАКТОР,РЕЗИНКА,РЕЗУЛЬТАТ,РЕКЛАМА,РЕКОРД,РЕМОНТ,РИСУНОК,РОБОТ,РОДИНА,РОЖДЕСТВО,РОМАШКА,РОЯЛЬ,РЮКЗАК",
    ["С"]="САМОЛЁТОСТРОЕНИЕ,САКСОФОН,САЛФЕТКА,САМОВАР,САМОКАТ,САМОЛЁТ,САМОРОДОК,САНДАЛИЯ,САДОВНИК,САЛАТ,САЛЮТ,САПОГ,САХАР,СТОМАТОЛОГ,СТРОИТЕЛЬСТВО,СТРОИТЕЛЬ,СТАДИОН,СТАНЦИЯ,СТАКАН,СТАНДАРТ,СТАРИК,СТАТУЯ,СТЕКЛО,СТРАНА,СТРАНИЦА,СТРЕЛА,СТУДЕНТ,СУПЕРМАРКЕТ,СУББОТА,СУВЕНИР,СУДЬЯ,СУМКА,СУНДУК,СОРЕВНОВАНИЕ,СОЗВЕЗДИЕ,СОБАКА,СОБЫТИЕ,СОВЕСТЬ,СОКРОВИЩЕ,СОЛДАТ,СОЛНЦЕ,СОСЕД,СВАРЩИК,СВИДЕТЕЛЬ,СВОБОДА,СВЕТОФОР,СВИТЕР,СЕКУНДА,СЕЛЁДКА,СЕНТЯБРЬ,СЕРЕБРО,СЕКРЕТ,СЕМЬЯ,СЕРДЦЕ,СИСТЕМА,СИТУАЦИЯ,СИГНАЛ,СИМВОЛ,СКАМЕЙКА,СКАНДАЛ,СКАРАБЕЙ,СКАТЕРТЬ,СКАЗКА,СКАФАНДР,СКЕЛЕТ,СКОРОВАРКА,СКОРОСТЬ,СКОРПИОН,СКУЛЬПТУРА,СМОРОДИНА,СНЕГОВИК,СНЕЖИНКА,СПАСАТЕЛЬ,СПЕКТАКЛЬ,СПУТНИК,СПОРТСМЕН,СРЕДА,СЫРНИК,СЮРПРИЗ",
    ["Т"]="ТЕЛЕВИДЕНИЕ,ТЕЛЕВИЗОР,ТЕЛЕГРАФ,ТЕЛЕСКОП,ТЕЛЕФОН,ТЕЛОХРАНИТЕЛЬ,ТЕМПЕРАТУРА,ТЕПЛИЦА,ТЕРАПЕВТ,ТЕРРИТОРИЯ,ТЕТРАДЬ,ТЕАТР,ТЕКСТ,ТЕХНИКА,ТРЕНАЖЁР,ТРЕУГОЛЬНИК,ТРЕНЕР,ТРАКТОРИСТ,ТРАКТОР,ТРАМВАЙ,ТРАМПЛИН,ТРАНСПОРТ,ТРАДИЦИЯ,ТРИБУНА,ТРОПИНКА,ТРОТУАР,ТРОЛЛЕЙБУС,ТАБЛИЧКА,ТАБУРЕТ,ТАРЕЛКА,ТАБЛЕТКА,ТАКСИСТ,ТАЛАНТ,ТАНЕЦ,ТОННЕЛЬ,ТОРГОВЛЯ,ТОРНАДО,ТОРТ,ТУРИСТ,ТУМАН,ТУРНИР,ТУФЕЛЬКА,ТИГР,ТИПОГРАФИЯ,ТИШИНА,ТЮЛЬПАН",
    ["У"]="УНИВЕРСИТЕТ,УНИВЕРМАГ,УЧИТЕЛЬСКАЯ,УЧИТЕЛЬ,УЧЕБНИК,УЧЕНИК,УДОВОЛЬСТВИЕ,УДИВЛЕНИЕ,УМЫВАЛЬНИК,УГЛЕВОДОРОД,УТЕПЛИТЕЛЬ,УКАЗАТЕЛЬ,УЛЬТРАЗВУК,УПРАВЛЯЮЩИЙ,УСКОРИТЕЛЬ,УСТРОЙСТВО,УЧРЕЖДЕНИЕ,УРАГАН,УРОЖАЙ,УСЛОВИЕ,УСПЕХ,УЛИЦА,УЛЫБКА,УТЮГ",
    ["Ф"]="ФОТОАППАРАТ,ФОТОГРАФ,ФОНТАН,ФОРМУЛА,ФОРТЕПИАНО,ФОНАРИК,ФОКУСНИК,ФИЛАРМОНИЯ,ФИГУРА,ФИЗИКА,ФИЛЬМ,ФИНАЛ,ФИНИШ,ФИОЛЕТОВЫЙ,ФАРМАЦЕВТ,ФАКУЛЬТЕТ,ФАЛЬШИВКА,ФАМИЛИЯ,ФАНТАЗИЯ,ФАБРИКА,ФАКЕЛ,ФАСОЛЬ,ФЕСТИВАЛЬ,ФЕЙЕРВЕРК,ФЕВРАЛЬ,ФЕРМЕР,ФУНИКУЛЁР,ФУТБОЛИСТ,ФУНДАМЕНТ,ФУТБОЛ,ФУТБОЛКА,ФЛОМАСТЕР,ФРАГМЕНТ,ФЛАГ,ФЛЕЙТА,ФРУКТ",
    ["Х"]="ХОЛОДИЛЬНИК,ХОРОВОД,ХОККЕИСТ,ХОЗЯИН,ХОЛМ,ХУДОЖНИК,ХРАНИЛИЩЕ,ХРАБРОСТЬ,ХРАМ,ХРИЗАНТЕМА,ХРОНОМЕТР,ХРУСТАЛЬ,ХЛЕБОРОБ,ХАМЕЛЕОН,ХАРАКТЕР,ХАЛАТ,ХИРУРГ,ХИЩНИК,ХИМИЯ,ХЛОПУШКА,ХОМЯК",
    ["Ц"]="ЦИФЕРБЛАТ,ЦИЛИНДР,ЦИТАДЕЛЬ,ЦИКЛОН,ЦИСТЕРНА,ЦИТАТА,ЦИВИЛИЗАЦИЯ,ЦИРК,ЦИФРА,ЦЫПЛЁНОК,ЦЕЛИТЕЛЬ,ЦЕПОЧКА,ЦЕРЕМОНИЯ,ЦЕНТР,ЦЕНА,ЦАРАПИНА,ЦАРСТВО,ЦВЕТОК,ЦЕРКОВЬ,ЦУНАМИ",
    ["Ч"]="ЧЕЛОВЕЧЕСТВО,ЧЕЛОВЕК,ЧЕРНОМОРЕЦ,ЧЕРНИЛЬНИЦА,ЧЕМОДАНЧИК,ЧЕМОДАН,ЧЕРЕПАХА,ЧЕРЕШНЯ,ЧЕРНИКА,ЧЕРНИЛА,ЧЕРНОСЛИВ,ЧЕРТЁЖ,ЧЕСТНОСТЬ,ЧЕТВЕРГ,ЧЕБУРЕК,ЧЕКАНКА,ЧЕЛЮСТЬ,ЧЕМПИОН,ЧЕСНОК,ЧАСОВЩИК,ЧАЙНИК,ЧАШКА,ЧИНОВНИК,ЧИСЛО,ЧИТАТЕЛЬ,ЧУДОВИЩЕ,ЧУДО",
    ["Ш"]="ШАМПАНСКОЕ,ШАХМАТИСТ,ШАХМАТЫ,ШАПКА,ШАРФ,ШАШЛЫК,ШЛАГБАУМ,ШЛЕМ,ШИНОМОНТАЖ,ШИШКА,ШТУРМОВИК,ШТУРВАЛ,ШТУРМАН,ШПАРГАЛКА,ШКАТУЛКА,ШКАФ,ШКОЛЬНИК,ШКОЛА,ШОКОЛАД,ШОКОЛАДНИЦА,ШОФЁР,ШЕЛКОПРЯД,ШЕДЕВР,ШЕРСТЬ,ШИРИНА,ШУТКА",
    ["Щ"]="ЩЕЛКУНЧИК,ЩЕКОТКА,ЩЕБЁНКА,ЩЕБЕНЬ,ЩЕНОК,ЩЕТИНА,ЩЁТКА,ЩУПАЛЬЦЕ,ЩУКА,ЩИПЦЫ,ЩАВЕЛЬ,ЩИТ",
    ["Э"]="ЭЛЕКТРИЧЕСТВО,ЭЛЕКТРОНИКА,ЭЛЕМЕНТ,ЭЛЕКТРОСТАНЦИЯ,ЭКСПЕРИМЕНТ,ЭКСПЕДИЦИЯ,ЭКСКАВАТОР,ЭКСКУРСОВОД,ЭКВАТОР,ЭКЗАМЕН,ЭКЗЕМПЛЯР,ЭКИПАЖ,ЭКОЛОГИЯ,ЭКОНОМИКА,ЭКСПОНАТ,ЭКРАН,ЭНЦИКЛОПЕДИЯ,ЭНЕРГИЯ,ЭНТУЗИАЗМ,ЭМБЛЕМА,ЭСКАЛАТОР,ЭПИЗОД,ЭПОХА,ЭТАЖ,ЭФФЕКТ",
    ["Ю"]="ЮРИСПРУДЕНЦИЯ,ЮРИСТ,ЮНОШЕСТВО,ЮНОША,ЮВЕЛИР,ЮБИЛЕЙ,ЮСТИЦИЯ,ЮПИТЕР,ЮБКА,ЮМОР,ЮНГА",
    ["Я"]="ЯСНОВИДЯЩИЙ,ЯХТСМЕН,ЯХТА,ЯБЛОНЯ,ЯБЛОКО,ЯВЛЕНИЕ,ЯГНЁНОК,ЯГОДА,ЯГУАР,ЯНВАРЬ,ЯНТАРЬ,ЯРМАРКА,ЯРОСТЬ,ЯЩЕРИЦА,ЯЩИК,ЯКОРЬ,ЯЗЫК,ЯЙЦО,ЯРЛЫК",
}

local DICT = {}
local DICT_SEEN = {}
local WORD_PRIO = {}
local totalDictWords = 0

local function addWordToDict(word, prio)
    if not word or totalDictWords >= MAX_DICT_WORDS then return false end
    prio = prio or 2
    if DICT_SEEN[word] then
        if prio < (WORD_PRIO[word] or 3) then
            WORD_PRIO[word] = prio
        end
        return false
    end
    local len = cyrLen(word)
    if len < 3 or len > 24 then return false end
    local first = word:sub(1, 2)
    if not DICT[first] then DICT[first] = {} end
    DICT_SEEN[word] = true
    WORD_PRIO[word] = prio
    table.insert(DICT[first], word)
    totalDictWords = totalDictWords + 1
    return true
end

for _, str in pairs(RAW) do
    for w in str:gmatch("[^,]+") do
        addWordToDict(w, 1)
    end
end
RAW = nil

local UI_IGNORE = {
    ["СТОЛ"]=true, ["ВЫХОД"]=true, ["ИГРА"]=true, ["ХОД"]=true, ["СЛОВО"]=true,
    ["РАУНД"]=true, ["СТАРТ"]=true, ["МЕНЮ"]=true, ["ЧАТ"]=true, ["СЧЕТ"]=true,
    ["СЧЁТ"]=true, ["ОЧКИ"]=true, ["НАЗАД"]=true, ["ДАЛЕЕ"]=true, ["ПОБЕДА"]=true,
    ["ПРОИГРЫШ"]=true, ["ГОТОВ"]=true, ["ОЖИДАНИЕ"]=true, ["ИГРОКИ"]=true, ["ВРЕМЯ"]=true
}

local RESET_TRIGGERS = {
    "вы проиграли", "проигрыш", "победил", "победа", "раунд окончен",
    "игра окончена", "новая игра", "покинул", "недостаточно игроков", "выбыли"
}

local REJECT_TRIGGERS = {
    "не подходит", "нет в словаре", "не найдено", "такого слова нет",
    "некорректное", "слишком короткое", "неправильное", "не существует"
}

local USED_TRIGGERS = {
    "уже использовано", "уже было", "повтор"
}

_G.WordBotHistory = _G.WordBotHistory or {}
local history = _G.WordBotHistory

local function countHistory()
    local c = 0
    for _ in pairs(history) do c = c + 1 end
    return c
end

local showStatus
local function resetHistory(reason)
    _G.WordBotHistory = {}
    history = _G.WordBotHistory
    if reason and showStatus then
        showStatus(reason)
    end
end

local submitState = "IDLE"
local lastWord = nil
local lastPrefix = nil
local lastAttemptTime = 0
local lastFinishTime = 0
local lastTypeTime = 0

-- ── 3. ИНТЕРФЕЙС ──
pcall(function()
    for _, name in ipairs({"WordGameIndicatorV10", "WordGameIndicatorV11", "WordGameIndicatorV12", "WordGameUniversalGUI"}) do
        local old = PlayerGui:FindFirstChild(name)
        if old then old:Destroy() end
    end
end)

local sg = Instance.new("ScreenGui")
sg.Name = "WordGameUniversalGUI"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = PlayerGui
_G.WordBotGui = sg

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainWidget"
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = sg

local mfCorner = Instance.new("UICorner", mainFrame)
local mfStroke = Instance.new("UIStroke", mainFrame)
mfStroke.Color = Color3.fromRGB(60, 68, 85)
mfStroke.Thickness = 1.5

if isMobile then
    mainFrame.Size = UDim2.new(0, 162, 0, 64)
    mainFrame.Position = UDim2.new(0.5, -81, 0, 18)
    mainFrame.BackgroundTransparency = 1
    mfCorner.CornerRadius = UDim.new(0, 0)
    mfStroke.Transparency = 1
else
    mainFrame.Size = UDim2.new(0, 480, 0, 40)
    mainFrame.Position = UDim2.new(0.5, -240, 0, 10)
    mainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
    mfCorner.CornerRadius = UDim.new(0, 10)
end

-- Кнопка сброса
local resetBtn = Instance.new("TextButton")
resetBtn.Name = "ResetBtn"
resetBtn.Font = Enum.Font.GothamBold
resetBtn.TextColor3 = Color3.fromRGB(220, 230, 245)
resetBtn.Text = "🔄"
resetBtn.Active = true
resetBtn.Parent = mainFrame
local rbCorner = Instance.new("UICorner", resetBtn)

if isMobile then
    resetBtn.Size = UDim2.new(0, 44, 0, 44)
    resetBtn.Position = UDim2.new(0, 2, 0.5, -22)
    resetBtn.BackgroundColor3 = Color3.fromRGB(25, 30, 42)
    resetBtn.BackgroundTransparency = 0.65
    resetBtn.TextTransparency = 0.15
    resetBtn.TextSize = 18
    rbCorner.CornerRadius = UDim.new(1, 0)
    local rbStroke = Instance.new("UIStroke", resetBtn)
    rbStroke.Color = Color3.fromRGB(140, 160, 190)
    rbStroke.Transparency = 0.45
    rbStroke.Thickness = 1.5
else
    resetBtn.Size = UDim2.new(0, 34, 1, -8)
    resetBtn.Position = UDim2.new(0, 4, 0, 4)
    resetBtn.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
    resetBtn.TextSize = 14
    rbCorner.CornerRadius = UDim.new(0, 8)
end

-- Кнопка АВТО-РЕЖИМА
local autoBtn = Instance.new("TextButton")
autoBtn.Name = "AutoBtn"
autoBtn.Font = Enum.Font.GothamBold
autoBtn.Active = true
autoBtn.Parent = mainFrame
local autoCorner = Instance.new("UICorner", autoBtn)
local autoStroke = Instance.new("UIStroke", autoBtn)
autoStroke.Thickness = 1.5

if isMobile then
    autoBtn.Size = UDim2.new(0, 44, 0, 44)
    autoBtn.Position = UDim2.new(0, 52, 0.5, -22)
    autoBtn.BackgroundTransparency = 0.65
    autoBtn.TextTransparency = 0.15
    autoBtn.Text = "🤖"
    autoBtn.TextSize = 19
    autoCorner.CornerRadius = UDim.new(1, 0)
    autoStroke.Transparency = 0.45
else
    autoBtn.Size = UDim2.new(0, 74, 1, -8)
    autoBtn.Position = UDim2.new(0, 42, 0, 4)
    autoBtn.TextSize = 12
    autoCorner.CornerRadius = UDim.new(0, 8)
end

local function updateAutoVisual()
    if autoMode then
        autoBtn.BackgroundColor3 = Color3.fromRGB(20, 55, 32)
        autoBtn.TextColor3 = Color3.fromRGB(80, 255, 130)
        autoStroke.Color = Color3.fromRGB(80, 255, 130)
        if not isMobile then autoBtn.Text = "АВТО: ВКЛ" end
    else
        autoBtn.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
        autoBtn.TextColor3 = Color3.fromRGB(170, 180, 200)
        autoStroke.Color = Color3.fromRGB(110, 120, 140)
        if not isMobile then autoBtn.Text = "АВТО: ВЫКЛ" end
    end
end
updateAutoVisual()

-- Главная кнопка
local actionBtn = Instance.new("TextButton")
actionBtn.Name = "ActionBtn"
actionBtn.Font = Enum.Font.GothamBold
actionBtn.TextColor3 = Color3.fromRGB(80, 255, 130)
actionBtn.Active = true
actionBtn.Parent = mainFrame
local abCorner = Instance.new("UICorner", actionBtn)

if isMobile then
    actionBtn.Size = UDim2.new(0, 56, 0, 56)
    actionBtn.Position = UDim2.new(0, 102, 0.5, -28)
    actionBtn.BackgroundColor3 = Color3.fromRGB(20, 40, 28)
    actionBtn.BackgroundTransparency = 0.65
    actionBtn.TextTransparency = 0.1
    actionBtn.Text = "⚡"
    actionBtn.TextSize = 25
    abCorner.CornerRadius = UDim.new(1, 0)
    local abStroke = Instance.new("UIStroke", actionBtn)
    abStroke.Color = Color3.fromRGB(80, 255, 130)
    abStroke.Transparency = 0.4
    abStroke.Thickness = 1.5
else
    actionBtn.Size = UDim2.new(1, -124, 1, -8)
    actionBtn.Position = UDim2.new(0, 120, 0, 4)
    actionBtn.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
    actionBtn.Text = "WordBot v34: ГОТОВ [Клик или Q / F2]"
    actionBtn.TextSize = 13
    abCorner.CornerRadius = UDim.new(0, 8)
end

-- Вкладка СЛОЖНОГО РЕЖИМА
local hardTab = Instance.new("TextButton")
hardTab.Name = "HardModeTab"
hardTab.Font = Enum.Font.GothamBold
hardTab.Active = true
hardTab.BorderSizePixel = 0
hardTab.Parent = sg
local htCorner = Instance.new("UICorner", hardTab)
htCorner.CornerRadius = UDim.new(0, 10)
local htStroke = Instance.new("UIStroke", hardTab)
htStroke.Thickness = 1.5

if isMobile then
    hardTab.Size = UDim2.new(0, 108, 0, 34)
    hardTab.Position = UDim2.new(1, -116, 0, 74)
    hardTab.BackgroundTransparency = 0.45
    hardTab.TextSize = 12
else
    hardTab.Size = UDim2.new(0, 136, 0, 34)
    hardTab.Position = UDim2.new(1, -146, 0, 14)
    hardTab.BackgroundTransparency = 0.15
    hardTab.TextSize = 12
end

local function updateHardVisual()
    if hardMode then
        hardTab.BackgroundColor3 = Color3.fromRGB(65, 22, 22)
        hardTab.TextColor3 = Color3.fromRGB(255, 110, 90)
        htStroke.Color = Color3.fromRGB(255, 95, 75)
        hardTab.Text = "🔥 Сложный [А]"
    else
        hardTab.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
        hardTab.TextColor3 = Color3.fromRGB(185, 195, 215)
        htStroke.Color = Color3.fromRGB(90, 100, 120)
        hardTab.Text = "🔥 Сложный: OFF"
    end
end
updateHardVisual()

-- Вкладка МАТЫ
local profaneTab = Instance.new("TextButton")
profaneTab.Name = "ProfaneModeTab"
profaneTab.Font = Enum.Font.GothamBold
profaneTab.Active = true
profaneTab.BorderSizePixel = 0
profaneTab.Parent = sg
local ptCorner = Instance.new("UICorner", profaneTab)
ptCorner.CornerRadius = UDim.new(0, 10)
local ptStroke = Instance.new("UIStroke", profaneTab)
ptStroke.Thickness = 1.5

if isMobile then
    profaneTab.Size = UDim2.new(0, 108, 0, 34)
    profaneTab.Position = UDim2.new(1, -116, 0, 114)
    profaneTab.BackgroundTransparency = 0.45
    profaneTab.TextSize = 12
else
    profaneTab.Size = UDim2.new(0, 126, 0, 34)
    profaneTab.Position = UDim2.new(1, -278, 0, 14)
    profaneTab.BackgroundTransparency = 0.15
    profaneTab.TextSize = 12
end

local function updateProfaneVisual()
    if profaneMode then
        profaneTab.BackgroundColor3 = Color3.fromRGB(70, 20, 65)
        profaneTab.TextColor3 = Color3.fromRGB(255, 110, 235)
        ptStroke.Color = Color3.fromRGB(255, 90, 230)
        profaneTab.Text = "🤬 Маты: ON"
    else
        profaneTab.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
        profaneTab.TextColor3 = Color3.fromRGB(185, 195, 215)
        ptStroke.Color = Color3.fromRGB(90, 100, 120)
        profaneTab.Text = "🤬 Маты: OFF"
    end
end
updateProfaneVisual()

-- Плавающий статус (для телефона)
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
statusLabel.BackgroundTransparency = 0.35
statusLabel.BorderSizePixel = 0
statusLabel.TextColor3 = Color3.fromRGB(80, 255, 130)
statusLabel.Font = Enum.Font.GothamBold
statusLabel.Text = ""
statusLabel.Visible = false
statusLabel.ZIndex = 10
statusLabel.Parent = mainFrame
local slCorner = Instance.new("UICorner", statusLabel)
slCorner.CornerRadius = UDim.new(0, 8)

if isMobile then
    statusLabel.Size = UDim2.new(0, 250, 0, 28)
    statusLabel.Position = UDim2.new(0.5, -125, 1, 6)
    statusLabel.TextSize = 12
    local slStroke = Instance.new("UIStroke", statusLabel)
    slStroke.Color = Color3.fromRGB(60, 68, 85)
    slStroke.Transparency = 0.4
    slStroke.Thickness = 1
end

-- Перетаскивание основного виджета
local dragging, dragStart, startPos
addConn(mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end))

addConn(UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end))

addConn(UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end))

local statusToken = 0
showStatus = function(txt, isErr)
    if isMobile then
        statusToken = statusToken + 1
        local myST = statusToken
        statusLabel.Text = txt
        statusLabel.TextColor3 = isErr and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(80, 255, 130)
        statusLabel.Visible = true
        task.delay(3, function()
            if statusToken == myST then
                statusLabel.Visible = false
            end
        end)
    else
        actionBtn.Text = txt
        actionBtn.TextColor3 = isErr and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(80, 255, 130)
    end
end

-- Фоновая подгрузка баз с GitHub (до 450 000 слов, включая CP1251-базу всех словоформ)
task.spawn(function()
    local sources = {
        { url = "https://raw.githubusercontent.com/sorokinpf/russian_names/master/russian_names.txt", prio = 1 },
        { url = "https://gist.githubusercontent.com/helart/96225136a784f8a3987398be96456dce/raw", prio = 1 },
        { url = "https://raw.githubusercontent.com/Harrix/Russian-Nouns/main/dist/russian_nouns.txt", prio = 2 },
        { url = "https://raw.githubusercontent.com/rominf/profanity-filter/master/profanity_filter/data/ru_profane_words.txt", prio = 2, isProfane = true },
        { url = "https://raw.githubusercontent.com/hingston/russian/master/100000-russian-words.txt", prio = 3 },
        { url = "https://raw.githubusercontent.com/danakt/russian-words/master/russian.txt", prio = 3, isCP1251 = true }
    }

    local added = 0
    for _, src in ipairs(sources) do
        if _G.WordBotToken ~= myToken or totalDictWords >= MAX_DICT_WORDS then break end
        local ok, body = pcall(function() return game:HttpGet(src.url) end)
        if ok and type(body) == "string" and #body > 500 then
            local countInFile = 0
            for line in body:gmatch("[^\r\n]+") do
                if totalDictWords >= MAX_DICT_WORDS then break end
                local clean = line:gsub("^%s+", ""):gsub("%s+$", "")
                local up = src.isCP1251 and cp1251ToUpperCyr(clean) or toUpperCyr(clean)
                if up then
                    if src.isProfane then
                        PROFANE_WORDS[up] = true
                    end
                    if addWordToDict(up, src.prio) then
                        added = added + 1
                    end
                end
                countInFile = countInFile + 1
                if countInFile % 8000 == 0 then
                    task.wait()
                end
            end
        end
    end

    if added > 0 and _G.WordBotToken == myToken then
        showStatus("База готова: " .. tostring(totalDictWords) .. " слов!")
    end
end)

-- ── 4. ПОИСК ПОЛЯ ВВОДА, ОЧЕРЕДИ И ЧТЕНИЕ ПЛИТОК ──
local function getTypingBox()
    local wgui = PlayerGui:FindFirstChild("WordGameUI")
    if not wgui then return nil end
    for _, obj in ipairs(wgui:GetDescendants()) do
        if obj:IsA("TextBox") and obj.Name == "TypingCapture" then return obj end
    end
    return nil
end

local function isActuallyVisible(obj)
    local cur = obj
    while cur and cur ~= PlayerGui do
        if cur:IsA("GuiObject") and not cur.Visible then
            return false
        elseif cur:IsA("ScreenGui") and not cur.Enabled then
            return false
        end
        cur = cur.Parent
    end
    return true
end

local function isMyTurn()
    if not isSitting() then return false end
    local wgui = PlayerGui:FindFirstChild("WordGameUI")
    if not wgui or not wgui.Enabled then return false end
    if not getTypingBox() then return false end

    for _, obj in ipairs(wgui:GetDescendants()) do
        if (obj:IsA("TextButton") or obj:IsA("TextLabel")) and obj.Visible then
            local t = obj.Text or ""
            if (t == "Ввод" or t == "Стереть") and isActuallyVisible(obj) then
                return true
            end
        end
    end
    return false
end

local function readTileData()
    local wgui = PlayerGui:FindFirstChild("WordGameUI")
    if not wgui then return nil, nil end

    local viewH = Camera.ViewportSize.Y
    local tiles = {}

    for _, obj in ipairs(wgui:GetDescendants()) do
        pcall(function()
            if obj:IsA("TextLabel") and obj.Visible then
                local n = obj.Name
                if n == "Glyph" or (n ~= "Heading" and n ~= "Title" and n ~= "Label" and n ~= "HeavyFill" and n ~= "Letter") then
                    local s = (obj.Text or ""):gsub("%s+", "")
                    local up = toUpperCyr(s)
                    if up and #up == 2 then
                        local posY = obj.AbsolutePosition.Y
                        local posX = obj.AbsolutePosition.X
                        if posY > 40 and posY < viewH * 0.52 and obj.AbsoluteSize.Y >= 20 then
                            table.insert(tiles, {
                                ch = up,
                                x = posX,
                                y = posY,
                                size = obj.AbsoluteSize.Y,
                                obj = obj
                            })
                        end
                    end
                end
            end
        end)
    end

    if #tiles == 0 then return nil, nil end

    local rows = {}
    for _, t in ipairs(tiles) do
        local placed = false
        for _, row in ipairs(rows) do
            if math.abs(row.y - t.y) <= 15 then
                table.insert(row.items, t)
                placed = true
                break
            end
        end
        if not placed then
            table.insert(rows, { y = t.y, items = { t } })
        end
    end

    table.sort(rows, function(a, b)
        return a.items[1].size > b.items[1].size
    end)

    local bestRow = rows[1].items
    table.sort(bestRow, function(a, b)
        return a.x < b.x
    end)

    local res = {}
    for _, t in ipairs(bestRow) do
        table.insert(res, t.ch)
    end
    return table.concat(res), bestRow
end

local function readTileRow()
    local w = readTileData()
    return w
end

local function getActivePrefix()
    local rowWord = readTileRow()
    if not rowWord then return nil end
    local len = cyrLen(rowWord)
    if len >= 1 and len <= 6 and not UI_IGNORE[rowWord] then
        return rowWord
    end
    return nil
end

local function getTileColor(tileObj)
    if not tileObj or not tileObj.Parent then return Color3.new(0, 0, 0) end
    local p = tileObj.Parent
    if p:IsA("GuiObject") and p.BackgroundTransparency < 0.85 then
        return p.BackgroundColor3
    elseif tileObj.BackgroundTransparency < 0.85 then
        return tileObj.BackgroundColor3
    end
    return tileObj.TextColor3
end

-- ── 5. ЗАПОМИНАНИЕ СЛОВ, РЕАЛЬНЫЙ СТАТУС СЕРВЕРА И АВТО-СБРОС ──
local function handleServerRejection(isAlreadyUsed)
    if submitState == "CHECKING" then
        submitState = "REJECTED"
    end
    if lastWord then
        history[lastWord] = true
        if not isAlreadyUsed then
            addToBlacklist(lastWord)
            showStatus("В ЧС навсегда: " .. lastWord, true)
        end
    end
end

local function rememberWord(rawText)
    if not rawText or rawText == "" then return end
    local clean = rawText:gsub("^%s+", ""):gsub("%s+$", "")
    local lowCheck = toLowerCyr(clean)

    for _, trig in ipairs(RESET_TRIGGERS) do
        if lowCheck:find(trig, 1, true) then
            submitState = "IDLE"
            restoreMobileControls()
            if countHistory() > 0 then
                resetHistory("Авто-сброс (конец раунда)!")
            end
            return
        end
    end

    for _, trig in ipairs(USED_TRIGGERS) do
        if lowCheck:find(trig, 1, true) then
            handleServerRejection(true)
            return
        end
    end

    for _, trig in ipairs(REJECT_TRIGGERS) do
        if lowCheck:find(trig, 1, true) then
            handleServerRejection(false)
            return
        end
    end

    local up = toUpperCyr(clean)
    if up and not UI_IGNORE[up] and cyrLen(up) >= 3 then
        history[up] = true
        addWordToDict(up, 1)
    end
end

local function hookTextLabel(obj)
    if not obj:IsA("TextLabel") then return end
    rememberWord(obj.Text)
    addConn(obj:GetPropertyChangedSignal("Text"):Connect(function()
        if _G.WordBotToken ~= myToken then return end
        rememberWord(obj.Text)
    end))
end

local function watchWordGameUI(wgui)
    for _, d in ipairs(wgui:GetDescendants()) do
        hookTextLabel(d)
    end
    addConn(wgui.DescendantAdded:Connect(function(d)
        if _G.WordBotToken ~= myToken then return end
        hookTextLabel(d)
    end))
end

local existingWgui = PlayerGui:FindFirstChild("WordGameUI")
if existingWgui then watchWordGameUI(existingWgui) end
addConn(PlayerGui.ChildAdded:Connect(function(child)
    if _G.WordBotToken ~= myToken then return end
    if child.Name == "WordGameUI" then
        watchWordGameUI(child)
    end
end))

pcall(function()
    if TextChatService and TextChatService.MessageReceived then
        addConn(TextChatService.MessageReceived:Connect(function(msg)
            if _G.WordBotToken ~= myToken then return end
            if msg and msg.Text then
                rememberWord(msg.Text)
            end
        end))
    end
end)

-- Следим за словами соперников и выходом со стула
task.spawn(function()
    local wasInMatch = false
    local missingTicks = 0
    local lastLongWord = nil

    while _G.WordBotToken == myToken do
        task.wait(0.25)

        local inMatch = isSitting() and (getTypingBox() ~= nil)
        if inMatch then
            wasInMatch = true
            missingTicks = 0

            if not _G.WordBotGlobalTyping then
                local cur = readTileRow()
                local curLen = cur and cyrLen(cur) or 0
                if curLen >= 4 and not UI_IGNORE[cur] then
                    lastLongWord = cur
                elseif lastLongWord and curLen < cyrLen(lastLongWord) then
                    history[lastLongWord] = true
                    addWordToDict(lastLongWord, 1)
                    lastLongWord = nil
                end
            end
        elseif wasInMatch then
            missingTicks = missingTicks + 1
            if missingTicks >= 6 then
                wasInMatch = false
                missingTicks = 0
                lastLongWord = nil
                submitState = "IDLE"
                restoreMobileControls()
                if countHistory() > 0 then
                    resetHistory("Авто-сброс (встал со стула)!")
                end
            end
        end
    end
end)

-- ── 6. ПОДБОР СЛОВА ──
local function pickWord(prefix, isRetry)
    local firstLetter = prefix:sub(1, 2)
    local pool = DICT[firstLetter]
    if not pool or #pool == 0 then return nil end

    local prefixBytes = #prefix
    local matches, unused = {}, {}
    local hardA_matches, hardA_unused = {}, {}
    local prof_matches, prof_unused = {}, {}
    local profA_matches, profA_unused = {}, {}

    for _, w in ipairs(pool) do
        if #w > prefixBytes and w:sub(1, prefixBytes) == prefix and not BLACKLIST[w] then
            local isProf = PROFANE_WORDS[w]
            if profaneMode or not isProf then
                local isUnused = (not history[w]) and (w ~= lastWord)
                local endsA = (w:sub(-2) == "А")

                table.insert(matches, w)
                if isUnused then table.insert(unused, w) end

                if hardMode and endsA then
                    table.insert(hardA_matches, w)
                    if isUnused then table.insert(hardA_unused, w) end
                end

                if profaneMode and isProf then
                    table.insert(prof_matches, w)
                    if isUnused then table.insert(prof_unused, w) end
                    if hardMode and endsA then
                        table.insert(profA_matches, w)
                        if isUnused then table.insert(profA_unused, w) end
                    end
                end
            end
        end
    end

    if #matches == 0 then return nil end

    local function filterNotLast(list)
        if #list <= 1 then return list end
        local res = {}
        for _, w in ipairs(list) do
            if w ~= lastWord then table.insert(res, w) end
        end
        return (#res > 0) and res or list
    end

    local candidates
    if profaneMode and hardMode and #profA_matches > 0 then
        if #profA_unused == 0 then
            for _, w in ipairs(profA_matches) do history[w] = nil end
            profA_unused = filterNotLast(profA_matches)
        end
        candidates = profA_unused
    elseif profaneMode and #prof_matches > 0 then
        if #prof_unused == 0 then
            for _, w in ipairs(prof_matches) do history[w] = nil end
            prof_unused = filterNotLast(prof_matches)
        end
        candidates = prof_unused
    elseif hardMode and #hardA_matches > 0 then
        if #hardA_unused == 0 then
            for _, w in ipairs(hardA_matches) do history[w] = nil end
            hardA_unused = filterNotLast(hardA_matches)
        end
        candidates = hardA_unused
    else
        if #unused == 0 then
            for _, w in ipairs(matches) do history[w] = nil end
            unused = filterNotLast(matches)
        end
        candidates = unused
    end

    if hardMode then
        table.sort(candidates, function(a, b)
            local la, lb = #a, #b
            if la ~= lb then return la > lb end
            return (WORD_PRIO[a] or 2) > (WORD_PRIO[b] or 2)
        end)
    elseif isRetry then
        table.sort(candidates, function(a, b)
            local pa, pb = WORD_PRIO[a] or 2, WORD_PRIO[b] or 2
            if pa ~= pb then return pa < pb end
            return #a > #b
        end)
    else
        table.sort(candidates, function(a, b)
            local pa, pb = WORD_PRIO[a] or 2, WORD_PRIO[b] or 2
            if pa ~= pb then return pa < pb end
            return #a < #b
        end)
    end

    local topN = math.min(#candidates, 6)
    local chosen = candidates[math.random(1, topN)]
    history[chosen] = true
    return chosen
end

-- ── 7. АВТООТВЕТ (0% ОШИБОК) + МОНИТОР ОТВЕТА СЕРВЕРА ──
local function isStuckOnLastWord(rowText)
    if not lastPrefix or not rowText or (tick() - lastAttemptTime >= 20) then
        return false
    end
    if rowText == lastWord then
        return true
    end
    if rowText:sub(1, #lastPrefix) == lastPrefix and #rowText > #lastPrefix then
        return true
    end
    return false
end

local function startServerCheckMonitor(snapshotTiles, expectedWord)
    task.spawn(function()
        local initColors = {}
        local initFirstX = nil
        if snapshotTiles and #snapshotTiles > 0 then
            initFirstX = snapshotTiles[1].x
            for idx, t in ipairs(snapshotTiles) do
                initColors[idx] = getTileColor(t.obj)
            end
        end

        local startT = tick()
        while _G.WordBotToken == myToken and submitState == "CHECKING" do
            task.wait(0.08)
            local elapsed = tick() - startT

            if not isMyTurn() then
                submitState = "ACCEPTED"
                return
            end

            local curWord, curTiles = readTileData()
            if not curWord or (curWord ~= expectedWord and curWord ~= lastWord and cyrLen(curWord) <= 6) then
                if elapsed >= 0.15 then
                    submitState = "ACCEPTED"
                    return
                end
            end

            if curTiles and #curTiles > 0 then
                if initFirstX and math.abs(curTiles[1].x - initFirstX) >= 3 and curWord == expectedWord then
                    handleServerRejection(false)
                    return
                end

                for idx, t in ipairs(curTiles) do
                    local c = getTileColor(t.obj)
                    local ic = initColors[idx] or Color3.new(0, 0, 0)
                    if c.R > 0.65 and c.R > c.G * 1.4 and c.R > c.B * 1.4 and (c.R - ic.R) > 0.12 then
                        handleServerRejection(false)
                        return
                    end
                    if c.G > 0.60 and c.G > c.R * 1.3 and c.G > c.B * 1.3 and (c.G - ic.G) > 0.12 then
                        submitState = "ACCEPTED"
                        return
                    end
                end
            end

            if elapsed >= 1.8 then
                handleServerRejection(false)
                return
            end
        end
    end)
end

local function doAutoAnswer()
    if _G.WordBotToken ~= myToken then return end
    if _G.WordBotGlobalTyping and (tick() - lastTypeTime < 5.0) then return end

    _G.WordBotGlobalTyping = true
    lastTypeTime = tick()

    local success, err = pcall(function()
        if not isSitting() then
            showStatus("Сядь на стул в матче!", true)
            return
        end

        local tb = getTypingBox()
        if not tb then
            showStatus("Поле ввода не найдено (жди матч)!", true)
            return
        end

        local rowText = readTileRow()
        local prefix = nil
        local isRetry = false

        if submitState == "REJECTED" or isStuckOnLastWord(rowText) then
            if lastPrefix then
                prefix = lastPrefix
                isRetry = true
                if lastWord then history[lastWord] = true end
            end
        end

        if not prefix then
            prefix = getActivePrefix()
        end

        if not prefix then
            showStatus("Буквы не найдены! Подожди свой ход.", true)
            return
        end

        local word = pickWord(prefix, isRetry)
        if not word then
            showStatus("Нет слов на: " .. prefix, true)
            return
        end

        lastPrefix = prefix
        lastWord = word
        lastAttemptTime = tick()

        local tag
        if profaneMode and hardMode then
            tag = "Маты (...А) ["
        elseif profaneMode then
            tag = "Маты ["
        elseif hardMode then
            tag = "Сложный (...А) ["
        elseif isRetry then
            tag = "Повтор ["
        else
            tag = "Топ ["
        end
        showStatus(tag .. prefix .. "] -> " .. word .. "...")

        tb:CaptureFocus()
        tb.Text = ""
        task.wait(0.08)
        tb.Text = ""

        local chars = utf8chars(word)
        local prefixLen = cyrLen(prefix)
        local tail = {}
        for i = prefixLen + 1, #chars do
            table.insert(tail, chars[i])
        end

        local typed = {}
        local totalTime
        if #chars >= 10 then
            totalTime = 1.0 + math.random()
        else
            totalTime = isMobile and 0.75 or (0.95 + math.random() * 0.25)
        end
        local perChar = totalTime / math.max(#tail, 1)
        local midIndex = math.floor(#tail / 2)

        for i, c in ipairs(tail) do
            if _G.WordBotToken ~= myToken then return end
            table.insert(typed, toLowerCyrChar(c))
            tb.Text = table.concat(typed)
            task.wait(perChar + (math.random() - 0.5) * perChar * 0.2)

            if i == midIndex and #tail >= 2 then
                task.wait(0.45)
            end
        end

        local snapWord, snapTiles = readTileData()
        task.wait(0.06)
        submitState = "CHECKING"
        tb:ReleaseFocus(true)

        if not isMobile then
            pcall(function()
                if typeof(keypress) == "function" then
                    keypress(0x0D)
                    task.wait(0.03)
                    keyrelease(0x0D)
                end
            end)
        end

        startServerCheckMonitor(snapTiles, snapWord or word)
        showStatus("Проверка: " .. word .. " (" .. tostring(countHistory()) .. ")")
    end)

    lastFinishTime = tick()
    _G.WordBotGlobalTyping = false
    if not success then
        submitState = "IDLE"
        showStatus("Ошибка: " .. tostring(err):sub(1, 30), true)
    end
end

-- ── 8. ФОНОВЫЙ АВТО-ХОД ──
task.spawn(function()
    while _G.WordBotToken == myToken do
        task.wait(0.20)
        if autoMode and not _G.WordBotGlobalTyping and isMyTurn() then
            if submitState == "CHECKING" then
                continue
            end

            if submitState == "REJECTED" then
                task.wait(0.20)
                if autoMode and not _G.WordBotGlobalTyping and isMyTurn() then
                    doAutoAnswer()
                end
            else
                local sinceFinish = tick() - lastFinishTime
                if sinceFinish >= 0.6 and getActivePrefix() ~= nil then
                    task.wait(0.30 + math.random() * 0.35)
                    if autoMode and not _G.WordBotGlobalTyping and isMyTurn() and submitState ~= "CHECKING" then
                        doAutoAnswer()
                    end
                end
            end
        elseif not isMyTurn() and submitState == "ACCEPTED" then
            submitState = "IDLE"
        end
    end
end)

-- ── 9. ТАП С ПОРОГОМ СМЕЩЕНИЯ ──
local function attachTap(btn, callback)
    local pressPos = nil
    addConn(btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            pressPos = input.Position
        end
    end))
    addConn(btn.InputEnded:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) and pressPos then
            local moved = (input.Position - pressPos).Magnitude
            pressPos = nil
            if moved < 12 then
                callback()
            end
        end
    end))
end

attachTap(actionBtn, doAutoAnswer)
attachTap(resetBtn, function()
    submitState = "IDLE"
    restoreMobileControls()
    resetHistory("Память сброшена!")
end)
attachTap(autoBtn, function()
    autoMode = not autoMode
    updateAutoVisual()
    showStatus(autoMode and "АВТО-ХОД: ВКЛЮЧЁН 🤖" or "АВТО-ХОД: ВЫКЛЮЧЕН")
end)
attachTap(hardTab, function()
    hardMode = not hardMode
    updateHardVisual()
    showStatus(hardMode and "СЛОЖНЫЙ РЕЖИМ: слова на «А» 🔥" or "Сложный режим выключен")
end)
attachTap(profaneTab, function()
    profaneMode = not profaneMode
    updateProfaneVisual()
    showStatus(profaneMode and "РЕЖИМ МАТОВ: ВКЛЮЧЁН 🤬" or "Режим матов выключен")
end)

-- ── 10. ХОТКЕИ (только ПК) ──
addConn(UIS.InputBegan:Connect(function(input)
    if _G.WordBotToken ~= myToken then return end
    if isMobile then return end
    if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.F2 then
        doAutoAnswer()
    elseif input.KeyCode == Enum.KeyCode.R and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
        submitState = "IDLE"
        resetHistory("Память сброшена!")
    end
end))

print("[WordGameBot v34] Запущен! Режим: " .. (isMobile and "ТЕЛЕФОН" or "ПК"))
