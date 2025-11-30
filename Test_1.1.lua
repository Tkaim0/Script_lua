local inicfg = require 'inicfg'
local filename = 'test.ini'

local imgui = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

local ini = inicfg.load({
    script = { workscript = true },
    menu = { x = 217, y = 218, w = 516, h = 291 }
}, filename)
inicfg.save(ini, filename)

local workscript = ini.script.workscript

local name_raw = "Test"
local version_raw = "1.0"
local author_raw = "Tkaim"
local info_raw = "- Тестовый скрипт"

local script_prefix = "[" .. name_raw .. "] "
local message_color = 0x00FF00FF

local WinState = imgui.new.bool(false)
local tab = 1
local tabs = {'Основное','Настройки','Инфа'}
local confirm_delete = false

local UpdateWindow = imgui.new.bool(false)

local function SaveMenuSize(pos, size)
    ini.menu.x = pos.x
    ini.menu.y = pos.y
    ini.menu.w = size.x
    ini.menu.h = size.y
    inicfg.save(ini, filename)
end

local function readJsonFile(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local content = file:read("*all")
    file:close()
    local dkjson = require 'dkjson'
    local obj, _, err = dkjson.decode(content)
    if err then
        print("JSON error: "..err)
        return nil
    end
    return obj
end

local function check_update()
    sampAddChatMessage(script_prefix.."Начинаю проверку обновлений...", message_color)
    local path = getWorkingDirectory().."\\Update_Info.json"
    os.remove(path)

    local url = 'https://github.com/Tkaim0/Script_lua/raw/main/Update_Info.json' 

    downloadUrlToFile(url, path, function(id, status)
        if status == 6 then
            local updateInfo = readJsonFile(path)
            if updateInfo then
                if version_raw ~= updateInfo.current_version then
                    sampAddChatMessage(script_prefix.."Доступна новая версия: "..updateInfo.current_version, message_color)
                    UpdateWindow[0] = true
                else
                    sampAddChatMessage(script_prefix.."У вас установлена последняя версия", message_color)
                end
            end
        end
    end)
end

imgui.OnFrame(function() return WinState[0] end, function()
    imgui.SetNextWindowPos(imgui.ImVec2(ini.menu.x, ini.menu.y), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowSize(imgui.ImVec2(ini.menu.w, ini.menu.h), imgui.Cond.FirstUseEver)
    imgui.Begin(u8'Меню', WinState)

    if imgui.BeginChild('Menu##Left', imgui.ImVec2(120,0), true) then
        for i, nameTab in ipairs(tabs) do
            if imgui.Button(u8(nameTab), imgui.ImVec2(100,30)) then
                tab = i
            end
            imgui.Spacing()
        end
        imgui.EndChild()
    end

    imgui.SameLine()

    if imgui.BeginChild('Content##Right', imgui.ImVec2(0,0), true) then
        if tab == 1 then
            imgui.Text(u8('Состояние скрипта: '..(workscript and "Включен" or "Выключен")))
        elseif tab == 2 then
            imgui.Text(u8'Настройки')
            imgui.Spacing()

            if imgui.Button(u8'Выключить скрипт') then
                workscript = false
                ini.script.workscript = false
                inicfg.save(ini, filename)
                sampSendChat("/cm")
                WinState[0] = false
            end
            imgui.Spacing()

            if imgui.Button(u8'Перезагрузить скрипт') then
                thisScript():reload()
            end
            imgui.Spacing()

            if imgui.Button(u8'Проверить обновления') then
                check_update()
            end
            imgui.Spacing()

            if confirm_delete then
                imgui.Text(u8'Вы уверены, что хотите удалить скрипт?')
                if imgui.Button(u8'Да, удалить') then
                    os.remove(getWorkingDirectory().."\\test.lua")
                    os.remove(filename)
                    sampAddChatMessage(script_prefix.."Скрипт удален", message_color)
                    WinState[0] = false
                end
                imgui.SameLine()
                if imgui.Button(u8'Отмена') then
                    confirm_delete = false
                end
            else
                if imgui.Button(u8'Удалить скрипт') then
                    confirm_delete = true
                end
            end

            if workscript then
                imgui.TextWrapped(u8("Текущая версия скрипта: "..version_raw))
            end

        elseif tab == 3 then
            imgui.Text(u8("Название скрипта: "..name_raw))
            imgui.Text(u8("Версия: "..version_raw))
            imgui.Text(u8("Автор: "..author_raw))
            imgui.TextWrapped(u8("Информация: "..info_raw))
        end
        imgui.EndChild()
    end

    local pos = imgui.GetWindowPos()
    local size = imgui.GetWindowSize()
    SaveMenuSize(pos, size)
    imgui.End()
end)

imgui.OnFrame(function() return UpdateWindow[0] end, function()
    local path = getWorkingDirectory().."\\Update_Info.json"
    local updateInfo = readJsonFile(path)
    if updateInfo then
        imgui.Begin(u8("Доступна новая версия"), UpdateWindow)
        imgui.TextWrapped(u8("Версия: "..updateInfo.current_version))
        imgui.TextWrapped(u8("Что нового:\n"..updateInfo.update_info))

        if imgui.Button(u8("Скачать и обновить")) then
            local lua_url = updateInfo.update_url:gsub("blob/", "raw/") 
            downloadUrlToFile(lua_url, getWorkingDirectory().."\\test.lua", function(id, status)
                if status == 6 then
                    sampAddChatMessage(u8("Скрипт обновлён! Перезагрузите его."), message_color)
                else
                    sampAddChatMessage(u8("Ошибка скачивания: "..status), 0xFF0000FF)
                end
            end)
        end

        if imgui.Button(u8("Закрыть")) then
            UpdateWindow[0] = false
        end
        imgui.End()
    end
end)

function main()
    while not isSampAvailable() do wait(0) end
    sampAddChatMessage(script_prefix.."Скрипт загружен", message_color)
    wait(1000)
    check_update()

    sampRegisterChatCommand('cm', function()
        workscript = not workscript
        ini.script.workscript = workscript
        inicfg.save(ini, filename)
        sampAddChatMessage(workscript and 'Скрипт включен' or 'Скрипт выключен', 0xFFFF0000)
    end)
	sampRegisterChatCommand('', function()
	if not workscript then return end
	sampSendChat("")
	end)
    sampRegisterChatCommand('cmd', function()
        if not workscript then return end
        WinState[0] = not WinState[0]
    end)

    while true do
        wait(0)
    end
end
print(namescript)
if nameauthor == "Tkaim" then
    print(nameauthor)
else
    print("Зачем сменил автора скрипта? Автор: Tkaim")
end
print(versionscript)
print(infoscript)