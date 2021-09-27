-- Copyright (c) 2021 Tur41ks Prod.

-- Информация о скрипте
script_name('«Chatlog»') 		    -- Указываем имя скрипта
script_version(1.1) 						  -- Указываем версию скрипта
script_author('Henrich_Rogge') 	-- Указываем имя автора

-- Библиотеки
require 'lib.moonloader'
require 'lib.sampfuncs'

local sampevents = require 'lib.samp.events'
local imgui = require 'imgui'
local imadd = require 'imgui_addons'
local encoding = require 'encoding'

------------------
encoding.default = 'CP1251'
local u8 = encoding.UTF8
dlstatus = require('moonloader').download_status
------------------

local accessnicks = {
	[1] = 'Henrich_Rogge',
	[2] = 'Tigo_Sahakyan'
}
local tablechatlog = {}
local tablesmslog = {}
local x, y = getScreenResolution()
local searchchatlog = imgui.ImBuffer(256)
local searchsmslog = imgui.ImBuffer(256)

-- Imgui окна
window = {
	['chatlog'] = { bool = imgui.ImBool(false), cursor = true },
	['smslog'] = { bool = imgui.ImBool(false), cursor = true }
}

function main()
  -- Проверяем загружен ли sampfuncs и SAMP если не загружены - возвращаемся к началу
	if not isSampfuncsLoaded() or not isSampLoaded() then return end
	-- Проверяем директории, если нужно создаем
	if not doesDirectoryExist('moonloader/CHAT-LOG') then createDirectory('moonloader/CHAT-LOG') end
  -- Проверяем загружен ли SA-MP
	while not isSampAvailable() do wait(0) end 
	-- СМС чатлог
	if doesFileExist('moonloader/CHAT-LOG/smslog.txt') then 
    local file = io.open('moonloader/CHAT-LOG/smslog.txt', 'r')
		tablesmslog = decodeJson(file:read('*a'))
  end
	saveData(tablesmslog, 'moonloader/CHAT-LOG/smslog.txt') 
	-- Регистрируем команды чата
  sampRegisterChatCommand('chatlog', function()
    window['chatlog'].bool.v = not window['chatlog'].bool.v
  end)
	sampRegisterChatCommand('smslogg', function()
    window['smslog'].bool.v = not window['smslog'].bool.v
		saveData(tablesmslog, 'moonloader/CHAT-LOG/smslog.txt')
  end)
  -- Проверяем зашёл ли игрок на сервер
	while not sampIsLocalPlayerSpawned() do wait(0) end
  -- Инициализируем функции
  applyCustomStyle()
	updateScript()
	autoSaveData()
	-- Когда инициализированы всё функции то проверяем права доступа
	checkAccess()
  while true do 
    wait(0)
    -- Imgui окна
		local ImguiWindowSettings = {false, false}
		for k, settings in pairs(window) do
			if settings.bool.v and ImguiWindowSettings[1] == false then
				imgui.Process = true
				ImguiWindowSettings[1] = true
			end
			if settings.bool.v and settings.cursor and ImguiWindowSettings[2] == false then
				imgui.ShowCursor = true
				ImguiWindowSettings[2] = true
			end
		end
		if ImguiWindowSettings[1] == false then
			imgui.Process = false
		end
		if ImguiWindowSettings[2] == false then
			imgui.ShowCursor = false
		end
  end
end

-- Авто-обновление
function updateScript()
	local filepath = os.getenv('TEMP') .. '\\chatlogupd.json'
	downloadUrlToFile('https://raw.githubusercontent.com/Tur41k/update/master/chatlogupd.json', filepath, function(id, status, p1, p2)
		if status == dlstatus.STATUS_ENDDOWNLOADDATA then
			local file = io.open(filepath, 'r')
			if file then
				local info = decodeJson(file:read('*a'))
				updatelink = info.updateurl
				if info and info.latest then
					if tonumber(thisScript().version) < tonumber(info.latest) then
						lua_thread.create(function()
							stext('Обнаружены изменения доступа, обновляю файл доступа к скрипту.')
							wait(300)
							downloadUrlToFile(updatelink, thisScript().path, function(id3, status1, p13, p23)
								if status1 == dlstatus.STATUS_ENDDOWNLOADDATA then
									print('Обновление успешно скачано и установлено.')
								elseif status1 == 64 then
									stext('Файл доступа успешно обновлен.')
								end
							end)
						end)
					else
						print('Обновлений скрипта не обнаружено.')
						update = false
					end
				end
			else
				print('Проверка обновления прошла неуспешно. Запускаю старую версию.')
			end
		elseif status == 64 then
			print('Проверка обновления прошла неуспешно. Запускаю старую версию.')
			update = false
		end
	end)
end

function checkAccess()
	for i = 1, #accessnicks do
		if accessnicks[i] == sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(1))) then
			state = true
			break
		else
			state = false
		end
	end
	if state then
		stext('Скрипт успешно загружен! Команды скрипта - /chatlog or /smslog')
	else
		stext('У вас нет доступа к этому скрипту, обратитесь к vk.com/tigosahakyan')
		thisScript():unload()
	end
end

-- Автосохранение данных
function autoSaveData()
	lua_thread.create(function()
		while true do
			wait(10000)
			saveData(tablesmslog, 'moonloader/CHAT-LOG/smslog.txt')
		end
	end)
end

-- Логируем чат и смс
function sampevents.onServerMessage(color, text)
  if text then
		local colors = ("{%06X}"):format(bit.rshift(color, 8))
    table.insert(tablechatlog, os.date(colors.."[%H:%M:%S] ") .. text)
  end
	if color == -65366 and (text:match('SMS%: .+. Отправитель%: .+') or text:match('SMS%: .+. Получатель%: .+') or text:match('SMS%: .+ Отправитель%: .+') or text:match('SMS%: .+ Получатель%: .+')) then
		if text:match('SMS%: .+. Отправитель%: .+%[%d+%]') then 
			ONEsmsid = text:match('SMS%: .+. Отправитель%: .+%[(%d+)%]') 
		elseif text:match('SMS%: .+. Получатель%: .+%[%d+%]') then 
			ONEsmstoid = text:match('SMS%: .+. Получатель%: .+%[(%d+)%]') 
		elseif text:match('SMS%: .+ Отправитель%: .+%[%d+%]') then 
			TWOsmsid = text:match('SMS%: .+ Отправитель%: .+%[(%d+)%]') 
		elseif text:match('SMS%: .+ Получатель%: .+%[%d+%]') then 
			TWOsmstoid = text:match('SMS%: .+ Получатель%: .+%[(%d+)%]') 
		end
		local colors = ("{%06X}"):format(bit.rshift(color, 8))
		table.insert(tablesmslog, os.date(colors.."[%H:%M:%S] ") .. text)
	end
end

-- Имгуи меню
function imgui.OnDrawFrame()
  if window['chatlog'].bool.v then
    imgui.SetNextWindowPos(imgui.ImVec2(x / 2, y / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(950, 600), imgui.Cond.FirstUseEver)   
    imgui.Begin(u8(thisScript().name..' | Общий чатлог | Version: '..thisScript().version), window['chatlog'].bool, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)
		imgui.PushItemWidth(250)
		imgui.Text(u8('Поиск по тексту'))
		imgui.InputText('##inptext', searchchatlog)
		imgui.PopItemWidth()
		imgui.Separator()
		imgui.Spacing()
    for k, v in pairs(tablechatlog) do
			if u8:decode(searchchatlog.v) == '' or string.find(rusUpper(v), rusUpper(u8:decode(searchchatlog.v))) ~= nil then
				imgui.TextColoredRGB(v)
			end
			if imgui.IsItemClicked() then
				local text = v:gsub('{......}', '')
				sampSetChatInputEnabled(true)
				sampSetChatInputText(text)
			end
    end
    imgui.End()
  end
	if window['smslog'].bool.v then
    imgui.SetNextWindowPos(imgui.ImVec2(x / 2, y / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(900, 600), imgui.Cond.FirstUseEver)   
    imgui.Begin(u8(thisScript().name..' | СМС чатлог| Version: '..thisScript().version), window['smslog'].bool, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)
		imgui.PushItemWidth(250)
		imgui.Text(u8('Поиск по тексту'))
		imgui.InputText('##inptext', searchsmslog)
		imgui.PopItemWidth()
		imgui.Separator()
		imgui.Spacing()
    for k, v in pairs(tablesmslog) do
			if u8:decode(searchsmslog.v) == '' or string.find(rusUpper(v), rusUpper(u8:decode(searchsmslog.v))) ~= nil then
				imgui.TextColoredRGB(v)
			end
			if imgui.IsItemClicked() then
				local text = v:gsub('{......}', '')
				sampSetChatInputEnabled(true)
				sampSetChatInputText(text)
			end
    end
    imgui.End()
  end
end

-- Сохраняем информацию
function saveData(table, path)
	if doesFileExist(path) then 
		os.remove(path) 
	end
  local file = io.open(path, 'w')
  if file then
		file:write(encodeJson(table))
		file:close()
  end
end

-- rusUpper для русских букв
function rusUpper(string)
	-- Русские буквы
	local russian_characters = { [168] = 'Ё', [184] = 'ё', [192] = 'А', [193] = 'Б', [194] = 'В', [195] = 'Г', [196] = 'Д', [197] = 'Е', [198] = 'Ж', [199] = 'З', [200] = 'И', [201] = 'Й', [202] = 'К', [203] = 'Л', [204] = 'М', [205] = 'Н', [206] = 'О', [207] = 'П', [208] = 'Р', [209] = 'С', [210] = 'Т', [211] = 'У', [212] = 'Ф', [213] = 'Х', [214] = 'Ц', [215] = 'Ч', [216] = 'Ш', [217] = 'Щ', [218] = 'Ъ', [219] = 'Ы', [220] = 'Ь', [221] = 'Э', [222] = 'Ю', [223] = 'Я', [224] = 'а', [225] = 'б', [226] = 'в', [227] = 'г', [228] = 'д', [229] = 'е', [230] = 'ж', [231] = 'з', [232] = 'и', [233] = 'й', [234] = 'к', [235] = 'л', [236] = 'м', [237] = 'н', [238] = 'о', [239] = 'п', [240] = 'р', [241] = 'с', [242] = 'т', [243] = 'у', [244] = 'ф', [245] = 'х', [246] = 'ц', [247] = 'ч', [248] = 'ш', [249] = 'щ', [250] = 'ъ', [251] = 'ы', [252] = 'ь', [253] = 'э', [254] = 'ю', [255] = 'я', }
  local strlen = string:len()
	if strlen == 0 then return string end
  string = string:upper()
  local output = ''
  for i = 1, strlen do
    local ch = string:byte(i)
    if ch >= 224 and ch <= 255 then -- lower russian characters
      output = output .. russian_characters[ch-32]
    elseif ch == 184 then -- ё
      output = output .. russian_characters[168]
    else
      output = output .. string.char(ch)
    end
  end
  return output
end

-- Цветной текст имгуи
function imgui.TextColoredRGB(text)
  local style = imgui.GetStyle()
  local colors = style.Colors
  local ImVec4 = imgui.ImVec4
  local explode_argb = function(argb)
    local a = bit.band(bit.rshift(argb, 24), 0xFF)
    local r = bit.band(bit.rshift(argb, 16), 0xFF)
    local g = bit.band(bit.rshift(argb, 8), 0xFF)
    local b = bit.band(argb, 0xFF)
    return a, r, g, b
  end
  local getcolor = function(color)
    if color:sub(1, 6):upper() == 'SSSSSS' then
    	local r, g, b = colors[1].x, colors[1].y, colors[1].z
    	local a = tonumber(color:sub(7, 8), 16) or colors[1].w * 255
    	return ImVec4(r, g, b, a / 255)
    end
  	local color = type(color) == 'string' and tonumber(color, 16) or color
  	if type(color) ~= 'number' then return end
    	local r, g, b, a = explode_argb(color)
    	return imgui.ImColor(r, g, b, a):GetVec4()
  	end
  	local render_text = function(text_)
  	for w in text_:gmatch('[^\r\n]+') do
    	local text, colors_, m = {}, {}, 1
    	w = w:gsub('{(......)}', '{%1FF}')
    	while w:find('{........}') do
      	local n, k = w:find('{........}')
      	local color = getcolor(w:sub(n + 1, k - 1))
      	if color then
        	text[#text], text[#text + 1] = w:sub(m, n - 1), w:sub(k + 1, #w)
        	colors_[#colors_ + 1] = color
        	m = n
      	end
      	w = w:sub(1, n - 1) .. w:sub(k + 1, #w)
     	end
      if text[0] then
        for i = 0, #text do
          imgui.TextColored(colors_[i] or colors[1], u8(text[i]))
          imgui.SameLine(nil, 0)
        end
        imgui.NewLine()
			else 
				imgui.Text(u8(w)) 
			end
    end
  end
  render_text(text)
end

-- Если скрипт вылетел скрываем курсор, и сохраняем данные
function onScriptTerminate(LuaScript, quitGame)
	if LuaScript == thisScript() then
		showCursor(false)
		lua_thread.create(function()
			print('Скрипт выключился. Настройки сохранены.')
		end)
  end
end

-- Украшение нашего имгуи меню
function applyCustomStyle()
	imgui.SwitchContext()
	local style = imgui.GetStyle()
	local colors = style.Colors
	local clr = imgui.Col
	local ImVec4 = imgui.ImVec4
	local ImVec2 = imgui.ImVec2
	
	style.ChildWindowRounding = 8.0
	style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
	style.WindowPadding = ImVec2(15, 15)
	style.WindowRounding = 10.0
	style.FramePadding = ImVec2(5, 5)
	style.FrameRounding = 6.0
	style.ItemSpacing = ImVec2(12, 8)
	style.ItemInnerSpacing = ImVec2(8, 5)
	style.IndentSpacing = 25.0
	style.ScrollbarSize = 15.0
	style.ScrollbarRounding = 9.0
	style.GrabMinSize = 15.0
	style.GrabRounding = 7.0
	
	colors[clr.Text] = ImVec4(0.95, 0.96, 0.98, 1.00)
	colors[clr.TextDisabled] = ImVec4(0.36, 0.42, 0.47, 1.00)
	colors[clr.WindowBg] = ImVec4(0.11, 0.15, 0.17, 1.00)
	colors[clr.ChildWindowBg] = ImVec4(0.11, 0.15, 0.17, 1.00)
	colors[clr.PopupBg] = ImVec4(0.08, 0.08, 0.08, 0.94)
	colors[clr.Border] = ImVec4(0.43, 0.43, 0.50, 0.50)
	colors[clr.BorderShadow] = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[clr.FrameBg] = ImVec4(0.20, 0.25, 0.29, 1.00)
	colors[clr.FrameBgHovered] = ImVec4(0.12, 0.20, 0.28, 1.00)
	colors[clr.FrameBgActive] = ImVec4(0.09, 0.12, 0.14, 1.00)
	colors[clr.TitleBg] = ImVec4(0.09, 0.12, 0.14, 0.65)
	colors[clr.TitleBgCollapsed] = ImVec4(0.00, 0.00, 0.00, 0.51)
	colors[clr.TitleBgActive] = ImVec4(0.08, 0.10, 0.12, 1.00)
	colors[clr.MenuBarBg] = ImVec4(0.15, 0.18, 0.22, 1.00)
	colors[clr.ScrollbarBg] = ImVec4(0.02, 0.02, 0.02, 0.39)
	colors[clr.ScrollbarGrab] = ImVec4(0.20, 0.25, 0.29, 1.00)
	colors[clr.ScrollbarGrabHovered] = ImVec4(0.18, 0.22, 0.25, 1.00)
	colors[clr.ScrollbarGrabActive] = ImVec4(0.09, 0.21, 0.31, 1.00)
	colors[clr.ComboBg] = ImVec4(0.20, 0.25, 0.29, 1.00)
	colors[clr.CheckMark] = ImVec4(0.28, 0.56, 1.00, 1.00)
	colors[clr.SliderGrab] = ImVec4(0.28, 0.56, 1.00, 1.00)
	colors[clr.SliderGrabActive] = ImVec4(0.37, 0.61, 1.00, 1.00)
	colors[clr.Button] = ImVec4(0.20, 0.25, 0.29, 1.00)
	colors[clr.ButtonHovered] = ImVec4(0.28, 0.56, 1.00, 1.00)
	colors[clr.ButtonActive] = ImVec4(0.06, 0.53, 0.98, 1.00)
	colors[clr.Header] = ImVec4(0.20, 0.25, 0.29, 0.55)
	colors[clr.HeaderHovered] = ImVec4(0.26, 0.59, 0.98, 0.80)
	colors[clr.HeaderActive] = ImVec4(0.26, 0.59, 0.98, 1.00)
	colors[clr.ResizeGrip] = ImVec4(0.26, 0.59, 0.98, 0.25)
	colors[clr.ResizeGripHovered] = ImVec4(0.26, 0.59, 0.98, 0.67)
	colors[clr.ResizeGripActive] = ImVec4(0.06, 0.05, 0.07, 1.00)
	colors[clr.CloseButton] = ImVec4(0.40, 0.39, 0.38, 0.16)
	colors[clr.CloseButtonHovered] = ImVec4(0.40, 0.39, 0.38, 0.39)
	colors[clr.CloseButtonActive] = ImVec4(0.40, 0.39, 0.38, 1.00)
	colors[clr.PlotLines] = ImVec4(0.61, 0.61, 0.61, 1.00)
	colors[clr.PlotLinesHovered] = ImVec4(1.00, 0.43, 0.35, 1.00)
	colors[clr.PlotHistogram] = ImVec4(0.90, 0.70, 0.00, 1.00)
	colors[clr.PlotHistogramHovered] = ImVec4(1.00, 0.60, 0.00, 1.00)
	colors[clr.TextSelectedBg] = ImVec4(0.25, 1.00, 0.00, 0.43)
	colors[clr.ModalWindowDarkening] = ImVec4(1.00, 0.98, 0.95, 0.73)
end

-- Упрощение жизни
function stext(text)
  sampAddChatMessage((' %s {FFFFFF}%s'):format(script.this.name, text), 0x2C7AA9)
end