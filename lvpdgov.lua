-- Copyright (c) 2020 Tur41ks Prod.

-- Информация о скрипте
script_name('lvpd-gov')        -- Указываем имя скрипта
script_version(1.11) 					 -- Указываем версию скрипта
script_author('Henrich_Rogge') -- Указываем имя автора

-- Библиотеки
require 'lib.moonloader'
require 'lib.sampfuncs'

local wm = require 'lib.windows.message'
local encoding = require 'encoding'
local imgui = require 'imgui'
local key = require 'vkeys'

-- Кодировка для Imgui 
encoding.default = 'cp1251'
u8 = encoding.UTF8

-- Переменные
wave = imgui.ImBuffer(512)
x, y = getScreenResolution()
show = 1

-- Imgui окна
window = {
	['main'] = { bool = imgui.ImBool(false), cursor = true }
}

-- Сессионные настройки
sInfo = {
	myid = nil,
	mynick = '',
	myrank = ''
}

function main()
  -- Проверяем загружен ли SA-MP
	while not isSampAvailable() do
		wait(0) 
  end
  -- Сообщаем что скрипт загружен
  text('by {FFDF84}Henrich Rogge {FFFFFF}successfully loaded. Open script - /lvpdgov')
  -- Проверяем зашёл ли игрок на сервер
  while not sampIsLocalPlayerSpawned() do 
    wait(0) 
	end
	-- Регистрируем команду открытия imgui окна
	sampRegisterChatCommand('lvpdgov', function() 
		window['main'].bool.v = not window['main'].bool.v
	end)
  -- Инициализируем стиль Imgui окна
	apply_custom_style()
	-- Проверяем есть ли обновление для скрипта, если есть - обновляем
	update()
	-- Обновляем сессионные настройки
	sInfo.myid = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
	sInfo.mynick = sampGetPlayerNickname(sInfo.myid)
	if sInfo.mynick == 'Henrich_Rogge' then
		sInfo.myrank = 'Майор'
	elseif sInfo.mynick == 'Sergo_Nod' then
		sInfo.myrank = 'Подполковник'
	elseif sInfo.mynick == 'Rodrigo_Sedodge' then
		sInfo.myrank = 'Майор'
	elseif sInfo.mynick == 'Robert_Prado' then
		sInfo.myrank = 'Подполковник'
	elseif sInfo.mynick == 'Alexey_Gallagher' then
		sInfo.myrank = 'Полковник'
	elseif sInfo.mynick == 'Bernhard_Rogge' then
		sInfo.myrank = 'Подполковник'
	elseif sInfo.mynick == 'Joseph_Jenkins' then
		sInfo.myrank = 'Полковник'
	elseif sInfo.mynick == 'Subaru_Snape' then
		sInfo.myrank = 'Полковник'
	elseif sInfo.mynick == 'Jerard_Presli' then
		sInfo.myrank = 'Шериф'
	end
  -- Если игрок нажал клавишу Esc то закрываем imgui окна и прячем курсор
	addEventHandler('onWindowMessage', function(msg, wparam, lparam)
		if msg == wm.WM_KEYDOWN or msg == wm.WM_SYSKEYDOWN then
			if wparam == key.VK_ESCAPE then
				if not sampIsChatInputActive() and not sampIsDialogActive() and not sampIsScoreboardOpen() then
					if window['main'].bool.v then 
						window['main'].bool.v = false consumeWindowMessage(true, true) 
					end
				end
			end
		end
	end)
  -- Ставим бесконечный цикл
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

function imgui.OnDrawFrame()
	-- Основное imgui окно
	if window['main'].bool.v then
		-- Устанавливаем размер окна
		imgui.SetNextWindowSize(imgui.ImVec2(550, 300), imgui.Cond.FirstUseEver)
		imgui.SetNextWindowPos(imgui.ImVec2(x/2, y/2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
		-- Формируем окно и указываем имя 
		imgui.Begin(u8(thisScript().name..' | Главное меню | Version: '..thisScript().version), window['main'].bool, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.MenuBar + imgui.WindowFlags.NoResize)
		-- Формируем меню
		if imgui.BeginMenuBar() then
			if imgui.BeginMenu(u8('Основное')) then
				if imgui.MenuItem(u8('Занять гос. волну')) then
          show = 1
        elseif imgui.MenuItem(u8('Вещать новости')) then
          show = 2
				end
				imgui.EndMenu()
			end
			if imgui.BeginMenu(u8('Остальное')) then
				if imgui.MenuItem(u8('Перезагрузить скрипт')) then
					lua_thread.create(function()
						text('перезагружаюсь')
						window['main'].bool.v = not window['main'].bool.v
						wait(1000)
						thisScript():reload()
					end)
				end
				if imgui.MenuItem(u8('Отключить скрипт')) then
					lua_thread.create(function()
						text('отключаюсь...')
						window['main'].bool.v = not window['main'].bool.v
						wait(1000)
					  text('успешно отключен!')
						thisScript():unload()
					end)
				end
				imgui.EndMenu()
			end
			imgui.EndMenuBar()
    end
		if show == 1 then
			local btn_size = imgui.ImVec2(-0.1, 25)
			imgui.PushItemWidth(200)
			imgui.Text(u8('Введите время говки в формате **:**, **:** и т. д.'))
			imgui.InputText('##inputtext', wave)
			imgui.Separator()
			imgui.Text(u8('/d OG, занимаю волну гос. новостей на %s. Возражения на пдж. %s.'):format(u8:decode(wave.v), sInfo.myid))
			if imgui.Button(u8('Занять гос. волну'), btn_size) then
				sampSendChat(string.format('/d OG, занимаю волну гос. новостей на %s. Возражения на пдж. %s.', u8:decode(wave.v), sInfo.myid))
			end
			imgui.Text(u8('/d OG, возражений не поступило волна гос. новостей на %s за LVPD.'):format(u8:decode(wave.v)))
			if imgui.Button(u8('Возражений не поступило'), btn_size) then
				sampSendChat(string.format('/d OG, возражений не поступило волна гос. новостей на %s за LVPD.', u8:decode(wave.v)))
			end
			imgui.Text(u8('/d OG, напоминаю, волна гос. новостей на %s за LVPD.'):format(u8:decode(wave.v)))
			if imgui.Button(u8('Напомнить о занятой гос. волне'), btn_size) then
				sampSendChat(string.format('/d OG, напоминаю, волна гос. новостей на %s за LVPD.', u8:decode(wave.v)))
			end
		elseif show == 2 then
			local btn_size = imgui.ImVec2(-0.1, 49.5)
      if imgui.Button(u8('Заявления (Для DB)'), btn_size) then
				lua_thread.create(function()
					sampSendChat('/d OG, занимаю волну гос. новостей, просьба не перебивать.')
					wait(5000)
					sampSendChat('/gov [LVPD] Уважаемые жители Штата, прошу минуточку внимания.')
					wait(5000)
					sampSendChat('/gov [LVPD] На оф. портале вы можете оставить заявление по факту преступления.')
					wait(5000)
					sampSendChat('/gov [LVPD] Помните, ваша бдительность может спасти чью-то жизнь.')
					wait(5000)
					sampSendChat(string.format('/gov [LVPD] Берегите себя и своих близких. С уважением, %s LVPD - %s.', sInfo.myrank, sInfo.mynick))
					wait(5000)
					sampSendChat('/d OG, освободил волну.')
				end)
      end
      if imgui.Button(u8('Набор по NTS'), btn_size) then
				lua_thread.create(function()
					sampSendChat('/d OG, занимаю волну гос. новостей, просьба не перебивать.')
					wait(5000)
					sampSendChat('/gov [LVPD] Уважаемые жители Штата, на портале полицейской академии города Las-Venturas\'a объявлен набор курсантов.')
					wait(5000)
					sampSendChat('/gov [LVPD] Мы гарантируем Вам обучение высокого уровня по уникальной спец. программе \"New Training System\"')
					wait(5000)
					sampSendChat('/gov [LVPD] После обучения Вы получите все необходимые навыки. Подробности на оф. портале департамента.')
					wait(5000)
					sampSendChat(string.format('/gov [LVPD] Берегите себя и своих близких. С уважением, %s LVPD - %s.', sInfo.myrank, sInfo.mynick))
					wait(5000)
					sampSendChat('/d OG, освободил волну.')
				end)
      end
      if imgui.Button(u8('Правила парковки'), btn_size) then
				lua_thread.create(function()
					sampSendChat('/d OG, занимаю волну гос. новостей, просьба не перебивать.')
					wait(5000)
					sampSendChat('/gov [LVPD] Уважаемые жители Штата, прошу минуточку внимания.')
					wait(5000)
					sampSendChat('/gov [LVPD] Напоминаю, что за не соблюдение правил парковки возле Казино и АВЛВ к Вам будут применены санкции!')
					wait(5000)
					sampSendChat(string.format('/gov [LVPD] Прошу каждого относиться с уважением к окружающим. С уважением, %s LVPD - %s.', sInfo.myrank, sInfo.mynick))
					wait(5000)
					sampSendChat('/d OG, освободил волну.')
				end)
      end
      if imgui.Button(u8('Сдача запрещенки'), btn_size) then
				lua_thread.create(function()
					sampSendChat('/d OG, занимаю волну гос. новостей, просьба не перебивать.')
					wait(5000)
					sampSendChat('/gov [LVPD] Уважаемые жители штата, в любое время дня и ночи вы можете сдать запрещенные вещества.')
					wait(5000)
					sampSendChat('/gov [LVPD] А так же, сдаться с поличным и получить средний срок заключения.')
					wait(5000)
					sampSendChat(string.format('/gov [LVPD] Спасибо за внимание. С уважением, %s LVPD - %s.', sInfo.myrank, sInfo.mynick))
					wait(5000)
					sampSendChat('/d OG, освободил волну.')
				end)
      end
		end
		imgui.End()
  end
end

-- Авто-обновление
function update()
	local filepath = os.getenv('TEMP') .. '\\lvpdgovupd.json'
	downloadUrlToFile('https://raw.githubusercontent.com/Tur41k/update/master/lvpdgovupd.json', filepath, function(id, status, p1, p2)
		if status == dlstatus.STATUS_ENDDOWNLOADDATA then
			local file = io.open(filepath, 'r')
			if file then
				local info = decodeJson(file:read('*a'))
				updatelink = info.updateurl
				if info and info.latest then
					if tonumber(thisScript().version) < tonumber(info.latest) then
						lua_thread.create(function()
							text('Началось скачивание обновления. Скрипт перезагрузится через пару секунд.')
							wait(300)
							downloadUrlToFile(updatelink, thisScript().path, function(id3, status1, p13, p23)
								if status1 == dlstatus.STATUS_ENDDOWNLOADDATA then
									print('Обновление успешно скачано и установлено. Приятной игры')
								elseif status1 == 64 then
									text('Обновление успешно скачано и установлено. Приятной игры.')
								end
							end)
						end)
					else
						print('Обновлений скрипта не обнаружено. Приятной игры.')
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

-- Украшение нашего имгуи меню
function apply_custom_style()
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
	style.ItemSpacing = ImVec2(85, 8)
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
function text(text)
  sampAddChatMessage((' %s {FFFFFF}%s'):format(script.this.name, text), 0x2C7AA9)
end

-- Если скрипт вылетел скрываем курсор
function onScriptTerminate(scr)
	if scr == script.this then
		showCursor(false)
	end
end