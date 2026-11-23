-- ================================================================
--  «Игра в Слова» [Roblox] — Auto-Typer v12 (Ultimate Master)
--  GitHub: https://github.com/tvinkprofi4-web/word-game-bot
-- ================================================================

-- ── 1. ЗАЩИТА ОТ ПОВТОРНОГО ЗАПУСКА (Убиваем все старые копии) ──
if _G.WordBotConnection then
    pcall(function() _G.WordBotConnection:Disconnect() end)
    _G.WordBotConnection = nil
end
if _G.WordBotGui then
    pcall(function() _G.WordBotGui:Destroy() end)
    _G.WordBotGui = nil
end

-- Генерируем уникальный токен этого запуска
_G.WordBotToken = (_G.WordBotToken or 0) + 1
local myToken = _G.WordBotToken

-- Глобальный мьютекс печати
_G.WordBotGlobalTyping = false

local Players   = game:GetService("Players")
local UIS       = game:GetService("UserInputService")
local LP        = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")
local Camera    = workspace.CurrentCamera

local CYR = {
    ["А"]="А",["Б"]="Б",["В"]="В",["Г"]="Г",["Д"]="Д",["Е"]="Е",["Ё"]="Ё",["Ж"]="Ж",
    ["З"]="З",["И"]="И",["Й"]="Й",["К"]="К",["Л"]="Л",["М"]="М",["Н"]="Н",["О"]="О",
    ["П"]="П",["Р"]="Р",["С"]="С",["Т"]="Т",["У"]="У",["Ф"]="Ф",["Х"]="Х",["Ц"]="Ц",
    ["Ч"]="Ч",["Ш"]="Ш",["Щ"]="Щ",["Ъ"]="Ъ",["Ы"]="Ы",["Ь"]="Ь",["Э"]="Э",["Ю"]="Ю",["Я"]="Я",
    ["а"]="А",["б"]="Б",["в"]="В",["г"]="Г",["д"]="Д",["е"]="Е",["ё"]="Ё",["ж"]="Ж",
    ["з"]="З",["и"]="И",["й"]="Й",["к"]="К",["л"]="Л",["м"]="М",["н"]="Н",["о"]="О",
    ["п"]="П",["р"]="Р",["с"]="С",["т"]="Т",["у"]="У",["ф"]="Ф",["х"]="Х",["ц"]="Ц",
    ["ч"]="Ч",["ш"]="Ш",["щ"]="Щ",["ъ"]="Ъ",["ы"]="Ы",["ь"]="Ь",["э"]="Э",["ю"]="Ю",["я"]="Я"
}
local function toCyr(c) return CYR[c] end

local RAW = {
    ["Ё"]="ЁМКОСТЬ,ЁЖИК,ЁЛКА,ЁРШ",
    ["А"]="АВТОМОБИЛЬ,АПЕЛЬСИН,АККУМУЛЯТОР,АРИСТОКРАТ,АРХИТЕКТУРА,АВИАНОСЕЦ,АПЛОДИСМЕНТЫ,АСТЕРОИД,АСТРОНАВТ,АКАДЕМИЯ,АКВАРИУМ,АККОРДЕОН,АКРОБАТ,АДМИРАЛ,АЛЬБАТРОС,АЛЮМИНИЙ,АНАНАС,АНТЕННА,АСПИРИН,АТТРАКЦИОН,АУДИТОРИЯ,АЭРОПОРТ,АВТОБУС,АВАНГАРД,АВТОРИТЕТ,АДРЕСАТ,АДВОКАТ,АКТИВИСТ,АЛЬБОМ,АМФИТЕАТР,АНАЛИЗАТОР,АНСАМБЛЬ,АППАРАТ,АРГУМЕНТ,АРТИЛЛЕРИСТ,АРХИВАТОР,АРХЕОЛОГ,АСФАЛЬТ,АТЛЕТИКА,АТМОСФЕРА,АЭРОДРОМ",
    ["Б"]="БИБЛИОТЕКА,БЕСПИЛОТНИК,БАРАБАНЩИК,БУТЕРБРОД,БЕЗОПАСНОСТЬ,БУДИЛЬНИК,БАКЛАЖАН,БУМЕРАНГ,БОЛЕЛЬЩИК,БАССЕЙН,БАБОЧКА,БАДМИНТОН,БАЛАЛАЙКА,БАТАРЕЯ,БЕГЕМОТ,БИНОКЛЬ,БЛОКНОТ,БРИЛЛИАНТ,БУЛЬВАР,БРАСЛЕТ,БРОНЕНОСЕЦ,БАЛЬЗАМ,БАНКОМАТ,БАРОМЕТР,БЕСЕДКА,БЕТОНОМЕШАЛКА,БИОГРАФИЯ,БИОЛОГИЯ,БЛАГОДАРНОСТЬ,БЛОКБАСТЕР,БОГАТЫРЬ,БОМБАРДИРОВЩИК,БОТАНИК,БРОНЕЖИЛЕТ,БУМАЖНИК",
    ["В"]="ВЕЛОСИПЕД,ВЕНТИЛЯТОР,ВЕРТОЛЁТ,ВДОХНОВЕНИЕ,ВСЕЛЕННАЯ,ВЕЛИЧЕСТВО,ВОДОХРАНИЛИЩЕ,ВИНОГРАДНИК,ВУЛКАНОЛОГ,ВОДОПАД,ВОДОРОСЛЬ,ВЫКЛЮЧАТЕЛЬ,ВАГОН,ВАРЕНЬЕ,ВАСИЛЁК,ВЕЖЛИВОСТЬ,ВЕЩЕСТВО,ВИНОГРАД,ВСПЫШКА,ВЫСТАВКА,ВАРИАНТ,ВЕЛИКАН,ВЕЛОТРЕК,ВЕРНИСАЖ,ВЕСТИБЮЛЬ,ВИЗИТЁР,ВИДЕОКАМЕРА,ВОЕННОСЛУЖАЩИЙ,ВОЗДУХООЧИСТИТЕЛЬ,ВОСПИТАТЕЛЬ,ВУЛКАНИЗАТОР,ВЫЧИСЛИТЕЛЬ",
    ["Г"]="ГОСУДАРСТВО,ГИПЕРМАРКЕТ,ГАЛАКТИКА,ГИППОПОТАМ,ГРОМООТВОД,ГЕОГРАФИЯ,ГРАММАТИКА,ГОРИЗОНТ,ГАРДЕРОБЩИК,ГРУЗОВИК,ГРАДУСНИК,ГАРМОНИЯ,ГИРЛЯНДА,ГОДОВЩИНА,ГОЛУБИКА,ГОСТИНИЦА,ГРЕЙПФРУТ,ГУСЕНИЦА,ГАСТРОНОМ,ГЕНЕРАТОР,ГЕРМАНИЙ,ГИДРОПЛАН,ГЛАДИАТОР,ГЛИЦЕРИН,ГОРНОЛЫЖНИК,ГОСПИТАЛЬ,ГРАВИТАЦИЯ,ГРАФОПОСТРОИТЕЛЬ,ГРОМКОГОВОРИТЕЛЬ,ГУМАНОИД",
    ["Д"]="ДОСТОПРИМЕЧАТЕЛЬНОСТЬ,ДИРИЖАБЛЬ,ДИНОЗАВР,ДРЕССИРОВЩИК,ДРАГОЦЕННОСТЬ,ДЕЗИНФЕКЦИЯ,ДИРИЖЁР,ДОКУМЕНТАЦИЯ,ДВИГАТЕЛЬ,ДИАГРАММА,ДИСКОТЕКА,ДЕТЕКТИВ,ДУРШЛАГ,ДНЕВНИК,ДОБРОТА,ДЕКОРАЦИЯ,ДЕМОНСТРАТОР,ДЕПОЗИТАРИЙ,ДЕТОНАТОР,ДИАГНОСТИКА,ДИАМЕТР,ДИВИДЕНД,ДИЗАЙНЕР,ДИКТОФОН,ДИПЛОМАТ,ДИСПЕТЧЕР,ДИСТАНЦИЯ,ДОКЛАДЧИК,ДУБЛИКАТ",
    ["Е"]="ЕДИНОМЫШЛЕННИК,ЕСТЕСТВОИСПЫТАТЕЛЬ,ЕЖЕДНЕВНИК,ЕДИНОРОГ,ЕЖЕВИКА,ЕПИСКОП,ЕДИНСТВО,ЕВРОПЕЕЦ,ЕСТЕСТВЕННИК,ЕРАЛАШ",
    ["Ж"]="ЖЕЛЕЗНОДОРОЖНИК,ЖИЗНЕДЕЯТЕЛЬНОСТЬ,ЖУРНАЛИСТ,ЖЕМЧУЖИНА,ЖАВОРОНОК,ЖИВОПИСЕЦ,ЖЕСТОКОСТЬ,ЖЕРЕБЁНОК,ЖАРОВНЯ,ЖЕЛАНИЕ,ЖЕМЧУГ,ЖОНГЛЁР,ЖУРАВЛЬ,ЖАКЕТ,ЖЕЛЕЗО,ЖЕТОН,ЖИЛЕТ,ЖИТЕЛЬ,ЖАЛОБА,ЖЕЛУДОК,ЖЕНЬШЕНЬ",
    ["З"]="ЗАКОНОДАТЕЛЬСТВО,ЗЕМЛЕТРЯСЕНИЕ,ЗАПОВЕДНИК,ЗЕМЛЕДЕЛИЕ,ЗАЖИГАЛКА,ЗВЕЗДОЧЁТ,ЗНАМЕНИТОСТЬ,ЗЕМЛЯНИКА,ЗАКЛАДКА,ЗАПЯСТЬЕ,ЗАТМЕНИЕ,ЗООПАРК,ЗАВОД,ЗАВТРАК,ЗАГАДКА,ЗАДАНИЕ,ЗЕРКАЛО,ЗДАНИЕ,ЗРИТЕЛЬ,ЗАГОЛОВОК,ЗАКАЗЧИК,ЗАКЛЮЧЕНИЕ,ЗАКОНОПРОЕКТ,ЗАМЕСТИТЕЛЬ,ЗАЩИТНИК,ЗВУКОРЕЖИССЁР",
    ["И"]="ИССЛЕДОВАТЕЛЬ,ИЗОБРЕТАТЕЛЬ,ИЛЛЮСТРАЦИЯ,ИНСТРУМЕНТ,ИНОПЛАНЕТЯНИН,ИНКУБАТОР,ИЗОБРАЖЕНИЕ,ИНФОРМАЦИЯ,ИСПЫТАНИЕ,ИМЕНИННИК,ИНЖЕНЕР,ИНТЕРНЕТ,ИСКУССТВО,ИСТОЧНИК,ИЗЛУЧЕНИЕ,ИЗУМРУД,ИЗБУШКА,ИЗГОРОДЬ,ИГРУШКА,ИМПЕРИЯ,ИЕРОГЛИФ,ИЗБИРАТЕЛЬ,ИЛЛЮМИНАТОР,ИММУНИТЕТ,ИНСТРУКТОР",
    ["Й"]="ЙОГУРТ,ЙОДИД,ЙОРК,ЙЕТИ,ЙОТА,ЙОД",
    ["К"]="КИНЕМАТОГРАФ,КАЛЬКУЛЯТОР,КОЛОКОЛЬЧИК,КОНСЕРВАТОРИЯ,КОНСТРУКТОР,КОСМОНАВТ,КОМАНДИРОВКА,КАЛЕЙДОСКОП,КАРАНДАШ,КАРТОФЕЛЬ,КАРУСЕЛЬ,КАТАСТРОФА,КОЛЛЕКЦИЯ,КОМПЬЮТЕР,КОРОЛЕВА,КОЛОДЕЦ,КУКУРУЗА,КУСТАРНИК,КАРТОН,КАСТРЮЛЯ,КАТАЛОГ,КЕРАМИКА,КИНОТЕАТР,КЛАВИАТУРА,КЛИЕНТУРА,КОМБИНЕЗОН,КОМПОЗИТОР,КОНДИТЕР,КОНФЕРЕНЦИЯ,КОРАБЛЕСТРОИТЕЛЬ",
    ["Л"]="ЛАБОРАТОРИЯ,ЛЕСОРУБ,ЛИСТОПАД,ЛОКОМОТИВ,ЛЕДОКОЛ,ЛУНОХОД,ЛАБИРИНТ,ЛИТЕРАТУРА,ЛЮБОПЫТСТВО,ЛАСТОЧКА,ЛАКОМСТВО,ЛЕКАРСТВО,ЛЕПЕСТОК,ЛЕСТНИЦА,ЛИМОНАД,ЛИХОРАДКА,ЛИЧНОСТЬ,ЛОБСТЕР,ЛОТЕРЕЯ,ЛУКОШКО,ЛЬВЁНОК,ЛАНДШАФТ,ЛЕГЕНДА,ЛЕЙКОЦИТ,ЛЕТОПИСЕЦ,ЛИКВИДАТОР,ЛОГОПЕД,ЛЮМИНИСЦЕНЦИЯ",
    ["М"]="МАШИНОСТРОЕНИЕ,МОТОЦИКЛИСТ,МИКРОСКОП,МИКРОФОН,МИЛЛИОНЕР,МНОГОУГОЛЬНИК,МАГНИТОФОН,МЕТАЛЛУРГИЯ,МУРАВЕЙНИК,МАНДАРИН,МАТРЁШКА,МОЛОТОК,МОНАСТЫРЬ,МОНИТОР,МОТОЦИКЛ,МАГАЗИН,МАТЕРИАЛ,МЕЛЬНИЦА,МЕТЕОРИТ,МЕХАНИЗМ,МАГИСТРАЛЬ,МАКЕТИРОВАНИЕ,МАНИПУЛЯТОР,МАРШРУТИЗАТОР,МЕДИАКОНТЕНТ,МЕТЕОРОЛОГ",
    ["Н"]="НАБЛЮДАТЕЛЬ,НЕВЕСОМОСТЬ,НАКОПИТЕЛЬ,НАВИГАТОР,НЕБОСКРЁБ,НАВОЛОЧКА,НАГРУЗКА,НАЕЗДНИК,НАКЛЕЙКА,НАКОВАЛЬНЯ,НАПЁРСТОК,НАПРАВЛЕНИЕ,НАСЕКОМОЕ,НАСЛЕДСТВО,НАСТРОЕНИЕ,НАХОДКА,НОУТБУК,НАГРАДА,НАПИТОК,НОСОРОГ,НАЗВАНИЕ,НАМЕРЕНИЕ,НАНИМАТЕЛЬ,НАРУШИТЕЛЬ,НАТЮРМОРТ,НАЧАЛЬНИК,НЕЙТРОН",
    ["О"]="ОГНЕТУШИТЕЛЬ,ОБОРУДОВАНИЕ,ОБСЕРВАТОРИЯ,ОДНОКЛАССНИК,ОСВЕЩЕНИЕ,ОКЕАНОЛОГ,ОБСТОЯТЕЛЬСТВО,ОДУВАНЧИК,ОБЕЗЬЯНА,ОБЁРТКА,ОБИТАТЕЛЬ,ОБЛАКО,ОБЛОЖКА,ОБЪЕКТИВ,ОЛИМПИАДА,ОПЕРАЦИЯ,ОРАНГУТАН,ОТВЁРТКА,ОТПЕЧАТОК,ОТШЕЛЬНИК,ОБВИНЕНИЕ,ОБЛАДАТЕЛЬ,ОБНОВЛЕНИЕ,ОБРАЗОВАНИЕ,ОБЫВАТЕЛЬ,ОГРАНИЧИТЕЛЬ,ОПРЕДЕЛИТЕЛЬ",
    ["П"]="ПУТЕШЕСТВЕННИК,ПАРАШЮТИСТ,ПАРОХОДСТВО,ПОНЕДЕЛЬНИК,ПРЕПОДАВАТЕЛЬ,ПРОИЗВОДСТВО,ПАРИКМАХЕР,ПОДСНЕЖНИК,ПОДСОЛНУХ,ПОЛИКЛИНИКА,ПОЛОТЕНЦЕ,ПОРОШОК,ПОРТРЕТ,ПОРТФЕЛЬ,ПОСЛАНИЕ,ПОСУДА,ПОТОЛОК,ПРАВИЛО,ПРАЗДНИК,ПРЕДМЕТ,ПРИКЛЮЧЕНИЕ,ПРИРОДА,ПРИСТАНЬ,ПРОГРАММА,ПРОЕКТ,ПРОФЕССОР,ПУТЕШЕСТВИЕ,ПЬЕДЕСТАЛ,ПАНОРАМА,ПАСТУХ,ПЕЙЗАЖ,ПЕЛИКАН",
    ["Р"]="РАДИОПРИЁМНИК,РУКОВОДИТЕЛЬ,РАСПИСАНИЕ,РАКЕТОДРОМ,РАВНОВЕСИЕ,РЫБОЛОВСТВО,РАЗВЕДЧИК,РЕВОЛЬВЕР,РЕЖИССЁР,РЕПЕТИЦИЯ,РЕПОРТАЖ,РЕСПУБЛИКА,РЕСТОРАН,РУКОЯТКА,РУСАЛКА,РАДИАТОР,РАЗРАБОТЧИК,РАСПРЕДЕЛИТЕЛЬ,РАССТОЯНИЕ,РЕАКТИВ",
    ["С"]="САМОЛЁТОСТРОЕНИЕ,СТОМАТОЛОГ,СТРОИТЕЛЬСТВО,СУПЕРМАРКЕТ,СОРЕВНОВАНИЕ,СОЗВЕЗДИЕ,САКСОФОН,САЛФЕТКА,САМОВАР,САМОКАТ,САМОЛЁТ,САМОРОДОК,САНДАЛИЯ,СВАРЩИК,СВИДЕТЕЛЬ,СВОБОДА,СЕКУНДА,СЕЛЁДКА,СЕНТЯБРЬ,СЕРЕБРО,СИСТЕМА,СИТУАЦИЯ,СКАМЕЙКА,СКАНДАЛ,СКАРАБЕЙ,СКАТЕРТЬ,СКЕЛЕТ,СКОРОВАРКА,СКОРОСТЬ,СКОРПИОН,СКУЛЬПТУРА,СМОРОДИНА,СНЕГОВИК,СНЕЖИНКА,СПАСАТЕЛЬ,СПЕКТАКЛЬ,СПУТНИК,СТАДИОН,СТАНЦИЯ,СТРОИТЕЛЬ",
    ["Т"]="ТЕЛЕВИДЕНИЕ,ТЕЛОХРАНИТЕЛЬ,ТЕМПЕРАТУРА,ТРЕНАЖЁР,ТРАКТОРИСТ,ТАБЛИЧКА,ТАБУРЕТ,ТАРЕЛКА,ТЕЛЕВИЗОР,ТЕЛЕГРАФ,ТЕЛЕСКОП,ТЕЛЕФОН,ТЕПЛИЦА,ТЕРАПЕВТ,ТЕРРИТОРИЯ,ТЕТРАДЬ,ТОННЕЛЬ,ТОРГОВЛЯ,ТРАКТОР,ТРАМВАЙ,ТРАМПЛИН,ТРАНСПОРТ,ТРЕУГОЛЬНИК,ТРИБУНА,ТРОПИНКА,ТРОТУАР,ТУРИСТ",
    ["У"]="УНИВЕРСИТЕТ,УЧИТЕЛЬСКАЯ,УДОВОЛЬСТВИЕ,УМЫВАЛЬНИК,УГЛЕВОДОРОД,УТЕПЛИТЕЛЬ,УДИВЛЕНИЕ,УКАЗАТЕЛЬ,УЛЬТРАЗВУК,УНИВЕРМАГ,УЧЕБНИК,УЧЕНИК,УЧИТЕЛЬ,УПРАВЛЯЮЩИЙ,УСКОРИТЕЛЬ,УСТРОЙСТВО,УЧРЕЖДЕНИЕ",
    ["Ф"]="ФОТОАППАРАТ,ФИЛАРМОНИЯ,ФАРМАЦЕВТ,ФЕСТИВАЛЬ,ФЕЙЕРВЕРК,ФУНИКУЛЁР,ФУТБОЛИСТ,ФЛОМАСТЕР,ФАКУЛЬТЕТ,ФАЛЬШИВКА,ФАМИЛИЯ,ФАНТАЗИЯ,ФЕВРАЛЬ,ФИГУРА,ФОНТАН,ФОРМУЛА,ФОРТЕПИАНО,ФРАГМЕНТ,ФУНДАМЕНТ",
    ["Х"]="ХОЛОДИЛЬНИК,ХУДОЖНИК,ХРАНИЛИЩЕ,ХРИЗАНТЕМА,ХРОНОМЕТР,ХЛЕБОРОБ,ХАМЕЛЕОН,ХАРАКТЕР,ХИРУРГ,ХИЩНИК,ХЛОПУШКА,ХОРОВОД,ХРАБРОСТЬ,ХРУСТАЛЬ",
    ["Ц"]="ЦИФЕРБЛАТ,ЦИЛИНДР,ЦИТАДЕЛЬ,ЦЫПЛЁНОК,ЦЕЛИТЕЛЬ,ЦАРАПИНА,ЦАРСТВО,ЦЕПОЧКА,ЦЕРЕМОНИЯ,ЦЕРКОВЬ,ЦИКЛОН,ЦИСТЕРНА,ЦИТАТА",
    ["Ч"]="ЧЕЛОВЕЧЕСТВО,ЧАСОВЩИК,ЧЕРНОМОРЕЦ,ЧЕРНИЛЬНИЦА,ЧЕМОДАНЧИК,ЧЕРЕПАХА,ЧЕРЕШНЯ,ЧЕРНИКА,ЧЕРНИЛА,ЧЕРНОСЛИВ,ЧЕРТЁЖ,ЧЕСТНОСТЬ,ЧЕТВЕРГ,ЧЕБУРЕК,ЧЕКАНКА,ЧЕЛОВЕК,ЧЕЛЮСТЬ,ЧЕМОДАН,ЧЕМПИОН,ЧИНОВНИК",
    ["Ш"]="ШАМПАНСКОЕ,ШАХМАТИСТ,ШЛАГБАУМ,ШИНОМОНТАЖ,ШТУРМОВИК,ШПАРГАЛКА,ШАХМАТЫ,ШКАТУЛКА,ШКОЛЬНИК,ШОКОЛАД,ШТУРВАЛ,ШТУРМАН,ШЕЛКОПРЯД,ШОКОЛАДНИЦА",
    ["Щ"]="ЩЕЛКУНЧИК,ЩЕКОТКА,ЩЕБЁНКА,ЩУПАЛЬЦЕ,ЩИПЦЫ,ЩАВЕЛЬ,ЩЕБЕНЬ,ЩЕНОК,ЩЕТИНА,ЩЁТКА",
    ["Э"]="ЭЛЕКТРИЧЕСТВО,ЭКСПЕРИМЕНТ,ЭКСПЕДИЦИЯ,ЭКСКАВАТОР,ЭНЦИКЛОПЕДИЯ,ЭЛЕКТРОНИКА,ЭКСКУРСОВОД,ЭКВАТОР,ЭКЗАМЕН,ЭКЗЕМПЛЯР,ЭКИПАЖ,ЭКОЛОГИЯ,ЭКОНОМИКА,ЭКСПОНАТ,ЭЛЕМЕНТ,ЭМБЛЕМА,ЭНЕРГИЯ,ЭНТУЗИАЗМ,ЭСКАЛАТОР",
    ["Ю"]="ЮРИСПРУДЕНЦИЯ,ЮНОШЕСТВО,ЮВЕЛИР,ЮБИЛЕЙ,ЮРИСТ,ЮНОША,ЮСТИЦИЯ,ЮПИТЕР",
    ["Я"]="ЯСНОВИДЯЩИЙ,ЯХТСМЕН,ЯБЛОНЯ,ЯВЛЕНИЕ,ЯГНЁНОК,ЯГОДА,ЯГУАР,ЯНВАРЬ,ЯНТАРЬ,ЯРМАРКА,ЯРОСТЬ,ЯЩЕРИЦА,ЯБЛОКО,ЯКОРЬ,ЯЩИК",
}

local DICT = {}
for letter, str in pairs(RAW) do
    DICT[letter] = {}
    for w in str:gmatch("[^,]+") do table.insert(DICT[letter], w) end
end
RAW = nil

_G.WordBotHistory = _G.WordBotHistory or {}
local history = _G.WordBotHistory

-- ── 2. ЧИСТЫЙ И КРАСИВЫЙ ИНТЕРФЕЙС ──
pcall(function()
    for _, name in ipairs({"WordGameIndicatorV10", "WordGameIndicatorV11", "WordGameIndicatorV12"}) do
        local old = PlayerGui:FindFirstChild(name)
        if old then old:Destroy() end
    end
end)

local sg = Instance.new("ScreenGui")
sg.Name = "WordGameIndicatorV12"
sg.ResetOnSpawn = false
sg.Parent = PlayerGui
_G.WordBotGui = sg

local statusBtn = Instance.new("TextButton")
statusBtn.Size = UDim2.new(0, 480, 0, 36)
statusBtn.Position = UDim2.new(0.5, -240, 0, 10)
statusBtn.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
statusBtn.TextColor3 = Color3.fromRGB(80, 255, 120)
statusBtn.Font = Enum.Font.GothamBold
statusBtn.TextSize = 13
statusBtn.Text = "WordBot v12: ГОТОВ [Жми Q / F2 или кликай сюда]"
statusBtn.Parent = sg
local uic = Instance.new("UICorner", statusBtn)
uic.CornerRadius = UDim.new(0, 8)
local uis = Instance.new("UIStroke", statusBtn)
uis.Color = Color3.fromRGB(60, 65, 80)

local function countHistory()
    local c = 0
    for _ in pairs(history) do c = c + 1 end
    return c
end

local function showStatus(txt, isErr)
    statusBtn.Text = txt
    statusBtn.TextColor3 = isErr and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(80, 255, 120)
end

local function utf8chars(s)
    local t = {}
    for _, code in utf8.codes(s) do table.insert(t, utf8.char(code)) end
    return t
end

local function getTypingBox()
    local wgui = PlayerGui:FindFirstChild("WordGameUI")
    if not wgui then return nil end
    for _, obj in ipairs(wgui:GetDescendants()) do
        if obj:IsA("TextBox") and obj.Name == "TypingCapture" then return obj end
    end
    return nil
end

-- ── 3. ТОЧНЫЙ ЗАХВАТ БУКВЫ РАУНДА ──
local function getActiveLetter()
    local wgui = PlayerGui:FindFirstChild("WordGameUI")
    if not wgui then return nil end

    -- Способ 1: Ищем заголовок "Напиши слово на букву" -> рядом TextLabel с буквой
    for _, heading in ipairs(wgui:GetDescendants()) do
        if heading:IsA("TextLabel") and heading.Visible then
            local t = heading.Text or ""
            if t:find("Напиши слово") or t:find("слово на") then
                local parent = heading.Parent
                if parent then
                    for _, child in ipairs(parent:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Visible and child ~= heading then
                            local s = child.Text:gsub("%s+", "")
                            local ch = utf8chars(s)
                            if #ch == 1 and toCyr(ch[1]) then
                                return toCyr(ch[1])
                            end
                        end
                    end
                end
            end
        end
    end

    -- Способ 2: Центральная плитка над головой
    local screenCenter = Camera.ViewportSize.X / 2
    local bestChar, minDistance = nil, 999999
    for _, obj in ipairs(wgui:GetDescendants()) do
        pcall(function()
            if obj:IsA("TextLabel") and obj.Visible then
                local n = obj.Name
                if n == "Glyph" or (n ~= "Heading" and n ~= "Title" and n ~= "Label" and n ~= "HeavyFill" and n ~= "Letter") then
                    local s = obj.Text:gsub("%s+", "")
                    local ch = utf8chars(s)
                    if #ch == 1 and toCyr(ch[1]) then
                        local posX = obj.AbsolutePosition.X + obj.AbsoluteSize.X / 2
                        local posY = obj.AbsolutePosition.Y
                        if posY > 50 and posY < Camera.ViewportSize.Y * 0.45 then
                            local dist = math.abs(posX - screenCenter)
                            if dist < minDistance then
                                minDistance = dist
                                bestChar = toCyr(ch[1])
                            end
                        end
                    end
                end
            end
        end)
    end

    return bestChar
end

-- ── 4. ПОДБОР СЛОВА (БЕЗ ПОВТОРОВ) ──
local function pickWord(letter)
    local pool = DICT[letter]
    if not pool or #pool == 0 then return nil end

    local unused = {}
    for _, w in ipairs(pool) do
        if not history[w] then table.insert(unused, w) end
    end

    if #unused == 0 then
        for _, w in ipairs(pool) do history[w] = nil end
        unused = pool
    end

    table.sort(unused, function(a, b)
        return #utf8chars(a) > #utf8chars(b)
    end)

    local topN = math.min(#unused, 3)
    local chosen = unused[math.random(1, topN)]
    history[chosen] = true
    return chosen
end

-- ── 5. АТОМАРНЫЙ ВВОД (Защита от спутывания букв) ──
local lastTypeTime = 0

local function doAutoAnswer()
    -- Проверка на старую копию скрипта
    if _G.WordBotToken ~= myToken then return end

    -- Глобальная защита от двойного нажатия / одновременной печати
    if _G.WordBotGlobalTyping and (tick() - lastTypeTime < 3.0) then
        return
    end
    _G.WordBotGlobalTyping = true
    lastTypeTime = tick()

    local success, err = pcall(function()
        local tb = getTypingBox()
        if not tb then
            showStatus("Поле ввода TypingCapture не найдено!", true)
            return
        end

        local myLetter = getActiveLetter()
        if not myLetter then
            showStatus("Буква раунда не найдена! Сядь за стол.", true)
            return
        end

        local word = pickWord(myLetter)
        if not word then
            showStatus("Нет слов на букву: " .. myLetter, true)
            return
        end

        showStatus("Буква: [" .. myLetter .. "] -> Слово: " .. word .. "...")

        -- Тщательная очистка поля ввода перед стартом
        tb:CaptureFocus()
        tb.Text = ""
        task.wait(0.08)
        tb.Text = ""

        -- Отрезаем первую букву (игра сама держит первую букву в плитке 1!)
        local chars = utf8chars(word)
        local tail = {}
        for i = 2, #chars do table.insert(tail, chars[i]) end

        -- Абсолютная защита: собираем строку в буфере и перезаписываем целиком
        -- Никаких склеек двух копий скрипта!
        local currentBuffer = ""
        local totalTime = 1.0 + math.random() * 0.35
        local perChar = totalTime / math.max(#tail, 1)

        for _, c in ipairs(tail) do
            -- Если запустили новую копию скрипта — мгновенно прерываем старую
            if _G.WordBotToken ~= myToken then return end

            currentBuffer = currentBuffer .. string.lower(c)
            tb.Text = currentBuffer
            task.wait(perChar + (math.random() - 0.5) * perChar * 0.2)
        end

        task.wait(0.06)
        tb:ReleaseFocus(true)
        pcall(function()
            if typeof(keypress) == "function" then
                keypress(0x0D)
                task.wait(0.03)
                keyrelease(0x0D)
            end
        end)

        showStatus("Отправлено: " .. word .. " | Слов в истории: " .. tostring(countHistory()))
    end)

    _G.WordBotGlobalTyping = false
    if not success then
        showStatus("Ошибка: " .. tostring(err):sub(1, 35), true)
    end
end

-- Клик мышкой
statusBtn.MouseButton1Click:Connect(doAutoAnswer)

-- Клавиши Q или F2
_G.WordBotConnection = UIS.InputBegan:Connect(function(input)
    if _G.WordBotToken ~= myToken then return end
    if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.F2 then
        doAutoAnswer()
    elseif input.KeyCode == Enum.KeyCode.R and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
        _G.WordBotHistory = {}
        history = _G.WordBotHistory
        showStatus("Память слов очищена!")
    end
end)

print("[WordGameBot v12] Загружен! Защита от двойного запуска АКТИВНА.")
