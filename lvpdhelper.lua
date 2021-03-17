-- Copyright (c) 2021 Tur41ks Prod.

-- Информация о скрипте
script_name('«LVPD-Helper»') 		-- Указываем имя скрипта
script_version(3.1) 						-- Указываем версию скрипта BETA
script_author('Henrich_Rogge') 	-- Указываем имя автора

-- Библиотеки
require 'lib.moonloader'
require 'lib.sampfuncs'

local lsampev, sampevents = pcall(require, 'lib.samp.events')
local lencoding, encoding = pcall(require, 'encoding')
local lkey, key           = pcall(require, 'vkeys')
local lmemory, memory     = pcall(require, 'memory')
local lrkeys, rkeys       = pcall(require, 'rkeys')
local limgui, imgui       = pcall(require, 'imgui')
local limadd, imadd       = pcall(require, 'imgui_addons')
local lwm, wm             = pcall(require, 'lib.windows.message')
local llfs, lfs           = pcall(require, 'lfs')
local lrequests, requests = pcall(require, 'requests')

------------------
encoding.default = 'CP1251'
local u8 = encoding.UTF8
dlstatus = require('moonloader').download_status
imgui.ToggleButton = imadd.ToggleButton
imgui.HotKey = imadd.HotKey
------------------

-- Переменные на всякий хлам
nick = ''
reason = ''
uninvite = false
invite = false
tLastKeys = {} 
--targetID = nil

-- Imgui переменные
x, y = getScreenResolution()
code_reason = imgui.ImBuffer(256)
wave = imgui.ImBuffer(512)
lectureStatus = 0
show = 6

-- Лекции\шпоры
data = {
	lecture = {
    string = '',
    list = {},
    text = {},
    time = imgui.ImInt(5000)
	},
	combo = {
    lecture = imgui.ImInt(0),
		addtable = imgui.ImInt(0)
	},
	shpora = {
    edit = -1,
    loaded = 0,
    page = 0,
    select = {},
    inputbuffer = imgui.ImBuffer(10000),
    search = imgui.ImBuffer(256),
    text = ''
	},
	addtable = {
    nick = imgui.ImBuffer(256),
    param1 = imgui.ImBuffer(256),
    param2 = imgui.ImBuffer(256),
    reason = imgui.ImBuffer(256),
  },
	filename = '',
}

-- Imgui окна
window = {
	['main'] = { bool = imgui.ImBool(false), cursor = true },
	['shpora'] = { bool = imgui.ImBool(false), cursor = true },
	['binder'] = { bool = imgui.ImBool(false), cursor = false },
	['addtable'] = { bool = imgui.ImBool(false), cursor = true }
}

-- Биндеры
binders = {
	-- Клавишный биндер
	bindtext    = imgui.ImBuffer(20480),
	bindname    = imgui.ImBuffer(256),
	bindselect  = nil,
	-- Командный биндер
	cmdtext     = imgui.ImBuffer(20480),
	cmdbuf      = imgui.ImBuffer(256),
	cmdparams   = imgui.ImInt(0),
	cmdselect   = nil
}

-- Буфферы
buffers = {
	-- Буффер запроса местоположения
	location = {
		seconds = imgui.ImInt(1),
		id = imgui.ImInt(-1)
	},
	-- Буффер вызова в кабинет шерифа
	call = {
		minutes = imgui.ImInt(1),
		id = imgui.ImInt(-1)
	},
	-- Буффер для выдачи наряда
	outfit = {
		reason = imgui.ImBuffer(256),
		circles = imgui.ImInt(1),
		id = imgui.ImInt(-1)
	},
	-- Буффер для выдачи выговора
	rebuke = {
		reason = imgui.ImBuffer(256),
		type = imgui.ImBuffer(256),
		id = imgui.ImInt(-1)
	}
}

-- Сессионные настройки
sInfo = {
	WorkingDay = false,
	VehicleId = nil,
	AuthTime = nil,
	updateAFK = 0,
	MySkin = nil,
	MyId = nil,
	Nick = ''
}

-- Настройки
pInfo = {
	-- Основные настройки
	options = {
		pg = false,
		tar = 'YouTag',
		tarb = false,
		clistb = false,
		clist = 0,
		advertisement = true
	},
	-- Счетчик онлайна
	onlineTimer = {
		date = 0,
		time = tonumber(0),
		workTime = tonumber(0),
		dayAFK = 0
	},
	-- Счетчик арестов, штрафов.
	dayCounter = {
		arrested = 0,
		tickets = 0
	}
}

-- Клавиши подтверждения\отмены
config_keys = {
	punaccept = { v = {key.VK_F12}}
}

-- Командный биндер
cmd_binder = {}

-- Клавишный биндер
tBindList = {}

-- Лог обновлений
updatesInfo = {
  version = thisScript().version,
  type = 'Внеплановое обновление', -- Плановое обновление, Промежуточное обновление, Внеплановое обновление, Фикс
  date = '16.12.2020',
  list = {
		{ 'Возвращен доступ к скрипту семьи Sedodge;' }
  }
}

-- Рандомные сообщения
messages = {
	{ 'А ты знал что у LVPD есть официальный Discord сервер для общения?', 'Теперь знаешь, подключайся вместе интереснее - https://discord.gg/JDvHZRV' },
	{ 'Ключи можно брать только при аресте. После ареста - сдаешь ключи штабному офицеру.', 'Если тебе нужен ключ для ареста тебе нужно будет подойти к штабному офицеру.' }
}

function main()
	-- Проверяем загружен ли sampfuncs и SAMP если не загружены - отключаем скрипт
	if not isSampfuncsLoaded() or not isSampLoaded() then 
		return 
	end
	-- Проверяем директории, если нужно создаем
	local directoryes = { 'LVPD-Helper', 'LVPD-Helper/lectures', 'LVPD-Helper/shpores' }
	for k, v in pairs(directoryes) do
		if not doesDirectoryExist('moonloader/'..v) then 
			createDirectory('moonloader/'..v) 
		end
	end
	-- Проверяем загружен ли SA-MP
	while not isSampAvailable() do
		wait(0) 
	end
	-- Загрузка сохраненной информации
	-- Клавиша подтверждения
	if not doesFileExist('moonloader/LVPD-Helper/keys.json') then
		local file = io.open('moonloader/LVPD-Helper/keys.json', 'w')
		file:write(encodeJson(config_keys))
		file:close()
	else
		local file = io.open('moonloader/LVPD-Helper/keys.json', 'r')
		config_keys = decodeJson(file:read('*a'))
	end
	saveData(config_keys, 'moonloader/LVPD-Helper/keys.json')
	-- Командный биндер
	if doesFileExist('moonloader/LVPD-Helper/cmdbinder.json') then
		local file = io.open('moonloader/LVPD-Helper/cmdbinder.json', 'r')
		if file then
			cmd_binder = decodeJson(file:read('*a'))
		end
	end
	saveData(cmd_binder, 'moonloader/LVPD-Helper/cmdbinder.json')
	-- Настройки скрипта
	if not doesFileExist('moonloader/LVPD-Helper/config.json') then 
    io.open('moonloader/LVPD-Helper/config.json', 'w'):close()
  else 
    local file = io.open('moonloader/LVPD-Helper/config.json', 'r')
		pInfo = decodeJson(file:read('*a'))
  end
	saveData(pInfo, 'moonloader/LVPD-Helper/config.json') 
	-- Клавишный биндер
	if doesFileExist('moonloader/LVPD-Helper/buttonbinder.json') then
		local file = io.open('moonloader/LVPD-Helper/buttonbinder.json', 'r')
		if file then
			tBindList = decodeJson(file:read())
		end
	end
	saveData(tBindList, 'moonloader/LVPD-Helper/buttonbinder.json')
	for k, v in pairs(tBindList) do
		rkeys.registerHotKey(v.v, true, onHotKey)
		if v.time ~= nil then 
			v.time = nil 
		end
		if v.name == nil then 
			v.name = 'Бинд'..k 
		end
		v.text = v.text:gsub('%[enter%]', ''):gsub('{noenter}', '{noe}')
	end
	saveData(tBindList, 'moonloader/LVPD-Helper/buttonbinder.json')
	-- Если файла шпоры нет - создаем файл и записываем туда начальную информацию
	if not doesFileExist('moonloader/LVPD-Helper/shpores/fisrtshpora.txt') then
		local file = io.open('moonloader/LVPD-Helper/shpores/fisrtshpora.txt', 'w')
		file:write('Вы пока что не настроили шпору.\nЧто бы вставить сюда свой текст вам нужно выполнить ряд дейтсвий:\n1. Открыть папку LVPD-Helper которая находится в папке moonloader\n2. Открыть файл fisrtshpora.txt любым блокнотом\n3. Изменить текст в нем на какой вам нужен\n4. Сохранить файл')
		file:close()
	end
	-- Регистрируем клавишу подтверждения
	punacceptbind = rkeys.registerHotKey(config_keys.punaccept.v, true, punaccept)
	-- Регистрируем команды на функции
	sampRegisterChatCommand('shpora', function()
		window['shpora'].bool.v = not window['shpora'].bool.v
	end)
	sampRegisterChatCommand('sw', function() 
		window['main'].bool.v = not window['main'].bool.v
	end)
	sampRegisterChatCommand('addtable', function() 
		window['addtable'].bool.v = not window['addtable'].bool.v
	end)
	sampRegisterChatCommand('swupd', cmd_lvpdhelperupdates)
	sampRegisterChatCommand('peresec', cmd_peresec)
	sampRegisterChatCommand('loc', cmd_loc)
	sampRegisterChatCommand('cn', cmd_cn)
	sampRegisterChatCommand('r', cmd_r)
	sampRegisterChatCommand('f', cmd_f)
	-- Обновляем сессионные настройки
	-- Проверяем зашёл ли игрок на сервер
	while not sampIsLocalPlayerSpawned() do 
		wait(0) 
	end
	sInfo.MyId = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
	sInfo.Nick = sampGetPlayerNickname(sInfo.MyId)
	sInfo.updateAFK = os.time()
	sInfo.AuthTime = os.date('%d.%m.%y %H:%M:%S') 
	-- Инициализируем функции
	registerCommandsBinder()
	apply_custom_style()
	random_messages()
	onlineTimer()
	update()
	-- Когда инициализированы всё функции то сообщаем, что скрипт загружен
	stext('Скрипт успешно загружен! Открыть меню скрипта - /sw')
	-- Сбрасываем счетчики каждые 24 часа
	if os.date('%a') ~= pInfo.onlineTimer.date and tonumber(os.date('%H')) > 4 then
		pInfo.onlineTimer.date = os.date('%a')
		pInfo.onlineTimer.time = tonumber(0)
		pInfo.onlineTimer.dayAFK = tonumber(0)
		pInfo.onlineTimer.workTime = tonumber(0)
		pInfo.dayCounter.tickets = tonumber(0)
		pInfo.dayCounter.arrested = tonumber(0)
		saveData(pInfo, 'moonloader/LVPD-Helper/config.json') 
	end
	-- Бесконечный цикл
	while true do 
		wait(0)
		-- Проверяем скин нашего персонажа, и переключаем значения в переменной
		sInfo.MySkin = getCharModel(PLAYER_PED)
		if sInfo.MySkin == 280 or sInfo.MySkin == 265 or sInfo.MySkin == 266 or sInfo.MySkin == 267 or sInfo.MySkin == 281 or sInfo.MySkin == 282 or sInfo.MySkin == 288 or sInfo.MySkin == 284 or sInfo.MySkin == 285 or sInfo.MySkin == 304 or sInfo.MySkin == 305 or sInfo.MySkin == 306 or sInfo.MySkin == 307 or sInfo.MySkin == 309 or sInfo.MySkin == 283 or sInfo.MySkin == 303 then 
			sInfo.WorkingDay = true
		else
			sInfo.WorkingDay = false
		end
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
    -- Активация чата на Т
    if isKeyJustPressed(VK_T) and not sampIsDialogActive() and not sampIsScoreboardOpen() and not isSampfuncsConsoleActive() then
      sampSetChatInputEnabled(true)
    end
  end
end

function imgui.OnDrawFrame()
	-- Основное imgui окно
	if window['main'].bool.v then
		-- Устанавливаем размер окна
		imgui.SetNextWindowSize(imgui.ImVec2(700, 400), imgui.Cond.FirstUseEver)
		imgui.SetNextWindowPos(imgui.ImVec2(x / 2, y / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
		-- Формируем окно и указываем имя 
		imgui.Begin(u8(thisScript().name..' | Главное меню | Version: '..thisScript().version), window['main'].bool, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.MenuBar + imgui.WindowFlags.NoResize)
		-- Формируем меню
		if imgui.BeginMenuBar() then
			if imgui.BeginMenu(u8('Основное')) then
				if imgui.MenuItem(u8('Главное меню')) then
					binderclose()
					show = 6
				elseif imgui.MenuItem(u8('Настройки')) then
					binderclose()
					show = 1 
				end
				imgui.EndMenu()
			end
			if imgui.BeginMenu(u8('Действия')) then
				if imgui.MenuItem(u8('Лекции')) then
					binderclose()
					show = 2
				elseif imgui.MenuItem(u8('Занять гос. волну')) then
					binderclose()
					show = 10 
				end
				imgui.EndMenu()
			end
			if imgui.BeginMenu(u8('Действие с игроком')) then
				if imgui.MenuItem(u8('Выдать выговор')) then
					binderclose()
					show = 8
				elseif imgui.MenuItem(u8('Выдать наряд')) then
					binderclose()
					show = 9
				elseif imgui.MenuItem(u8('Вызвать игрока')) then
					binderclose()
					show = 11
				elseif imgui.MenuItem(u8('Запросить местоположение')) then
					binderclose()
					show = 12
				end
				imgui.EndMenu()
			end
			if imgui.BeginMenu(u8('Полезное')) then
				if imgui.MenuItem(u8('Шпора')) then 
					window['shpora'].bool.v = not window['shpora'].bool.v
				elseif imgui.MenuItem(u8('Биндер')) then
					window['binder'].bool.v = true
					show = 4
				end
				imgui.EndMenu()
			end
			if imgui.BeginMenu(u8('Информация')) then
				if imgui.MenuItem(u8('Авторы')) then
					binderclose()
					show = 3
				elseif imgui.MenuItem(u8('Команды')) then
					binderclose()
					show = 7
				end
				imgui.EndMenu()
			end
			if imgui.BeginMenu(u8('Остальное')) then
				if imgui.MenuItem(u8('Перезагрузить скрипт')) then
					lua_thread.create(function()
						stext('Перезагружаемся...')
						binderclose()
						window['main'].bool.v = not window['main'].bool.v
						wait(1000)
						thisScript():reload()
					end)
				end
				if imgui.MenuItem(u8('Отключить скрипт')) then
					lua_thread.create(function()
						stext('Отключаю скрипт...')
						binderclose()
						window['main'].bool.v = not window['main'].bool.v
						wait(1000)
						stext('Скрипт успешно отключен!')
						thisScript():unload()
					end)
				end
				imgui.EndMenu()
			end
			imgui.EndMenuBar()
		end
		if show == 1 then
			local tagb 				= imgui.ImBool(pInfo.options.tarb)
			local tagf 				= imgui.ImBuffer(u8(pInfo.options.tar), 256)
			local clistb 			= imgui.ImBool(pInfo.options.clistb)
			local clistbuffer = imgui.ImInt(pInfo.options.clist)
			local pg 					= imgui.ImBool(pInfo.options.pg)
			local advert      = imgui.ImBool(pInfo.options.advertisement)
			-- Функция настройки Авто-Тега
			if imgui.BeginChild('##1', imgui.ImVec2(320, 90)) then
				imgui.CentrText(u8('Настройка авто-тега'))
				if imgui.ToggleButton(u8('Использовать авто-тег'), tagb) then 
					pInfo.options.tarb = not pInfo.options.tarb 
					saveData(pInfo, 'moonloader/LVPD-Helper/config.json') 
				end; imgui.SameLine(); imgui.Text(u8('Использовать авто-тег'))
				if tagb.v then
					if imgui.InputText(u8('Введите свой тег'), tagf) then 
						pInfo.options.tar = u8:decode(tagf.v) 
						saveData(pInfo, 'moonloader/LVPD-Helper/config.json') 
					end
				end
				imgui.EndChild()
			end
			imgui.SameLine()
			-- Функция настройки Авто-Клиста
			if imgui.BeginChild('##2', imgui.ImVec2(320, 90)) then
				imgui.CentrText(u8('Настройка авто-клиста'))
				if imgui.ToggleButton(u8('Использовать авто-клист'), clistb) then 
					pInfo.options.clistb = not pInfo.options.clistb
					saveData(pInfo, 'moonloader/LVPD-Helper/config.json') 
				end; imgui.SameLine(); imgui.Text(u8('Использовать авто-клист')); imgui.SameLine(); imgui.TextQuestion(u8('С защитой от троллинга'))
				if clistb.v then
					imgui.PushItemWidth(195)
					if imgui.SliderInt(u8('Выберите значение'), clistbuffer, 0, 33) then 
						pInfo.options.clist = clistbuffer.v
						saveData(pInfo, 'moonloader/LVPD-Helper/config.json') 
					end
				end
				imgui.EndChild()
			end
			if imgui.BeginChild('##10', imgui.ImVec2(320, 130)) then
				if imgui.ToggleButton(u8('pg'), pg) then 
					pInfo.options.pg = not pInfo.options.pg
					saveData(pInfo, 'moonloader/LVPD-Helper/config.json') 
				end; imgui.SameLine(); imgui.Text(u8('Отыгровки выдачи погонов')); imgui.SameLine(); imgui.TextQuestion(u8('Для 11+'))
				if imgui.ToggleButton(u8('das'), advert) then 
					pInfo.options.advertisement = not pInfo.options.advertisement
					saveData(pInfo, 'moonloader/LVPD-Helper/config.json') 
				end; imgui.SameLine(); imgui.Text(u8('Полезная реклама'))
				imgui.EndChild()
			end
			imgui.SameLine()
			if imgui.BeginChild('##10312', imgui.ImVec2(345, 100)) then
				if imgui.HotKey('##punaccept', config_keys.punaccept, tLastKeys, 50) then
					rkeys.changeHotKey(punacceptbind, config_keys.punaccept.v)
					stext('Клавиша успешно изменена!')
					saveData(config_keys, 'moonloader/LVPD-Helper/keys.json')
				end; imgui.SameLine(); imgui.Text(u8('Клавиша подтверждения'))
				imgui.EndChild()
			end
		elseif show == 2 then
			imgui.PushItemWidth(150)
			if data.lecture.string == '' then
				-- Загружаем список лекций и помещаем в таблицу
				data.combo.lecture.v = 0
				data.lecture.list = {}
				data.lecture.string = u8('Не выбрано\0')
				for file in lfs.dir(getWorkingDirectory()..'\\LVPD-Helper\\lectures') do
					if file ~= '.' and file ~= '..' then
						local attr = lfs.attributes(getWorkingDirectory()..'\\LVPD-Helper\\lectures\\'..file)
						if attr.mode == 'file' then 
							table.insert(data.lecture.list, file)
							data.lecture.string = data.lecture.string..u8:encode(file)..'\0'
						end
					end
				end
				if #data.lecture.list == 0 then
					name = 'firstlecture.txt'
					local file = io.open('moonloader/LVPD-Helper/lectures/firstlecture.txt', 'w+')
					file:write('Обычное сообщение\n/s Сообщение с криком\n/b Сообщение в b чат\n/rb Сообщение в рацию\n/w Сообщение шепотом')
					file:flush()
					file:close()
					file = nil
				end
				data.lecture.string = data.lecture.string..'\0'
			end
			imgui.Columns(2, _, false)
			imgui.SetColumnWidth(-1, 200)
			imgui.Text(u8('Выберите файл лекции'))
			imgui.Combo('##lec', data.combo.lecture, data.lecture.string)
			if imgui.Button(u8('Загрузить лекцию')) then
				if data.combo.lecture.v > 0 then
					local file = io.open('moonloader/LVPD-Helper/lectures/'..data.lecture.list[data.combo.lecture.v], 'r+')
					if file == nil then 
						atext('Файл не найден!')
					else
						data.lecture.text = {} 
						for line in io.lines('moonloader/LVPD-Helper/lectures/'..data.lecture.list[data.combo.lecture.v]) do
							table.insert(data.lecture.text, line)
						end
						if #data.lecture.text > 0 then
							atext('Файл лекции успешно загружен!')
						else 
							atext('Файл лекции пуст!') 
						end
					end
					file:close()
					file = nil
				else 
					atext('Выберите файл лекции!') 
				end
			end
			imgui.NextColumn()
			imgui.PushItemWidth(200)
			imgui.Text(u8('Выберите задержку (в миллисекундах)'))
			imgui.InputInt('##inputlec', data.lecture.time)
			if lectureStatus == 0 then
				if imgui.Button(u8('Запустить лекцию')) then
					if #data.lecture.text == 0 then 
						stext('Файл лекции не загружен!') 
						return 
					end
					if data.lecture.time.v == 0 then 
						stext('Время не может быть равно 0!') 
						return 
					end
					if lectureStatus ~= 0 then 
						stext('Лекция уже запущена/на паузе.') 
						return 
					end
					local ltext = data.lecture.text
					local ltime = data.lecture.time.v
					atext('Вывод лекции начался.')
					lectureStatus = 1
					lua_thread.create(function()
						while true do
							if lectureStatus == 0 then 
								break 
							end
							if lectureStatus >= 1 then
								sampSendChat(ltext[lectureStatus])
								lectureStatus = lectureStatus + 1
							end
							if lectureStatus > #ltext then
								wait(150)
								lectureStatus = 0
								stext('Вывод лекции завершен.')
								break 
							end
							wait(tonumber(ltime))
						end
					end)
				end
			else
				if imgui.Button(u8:encode(string.format('%s', lectureStatus > 0 and 'Пауза' or 'Возобновить'))) then
					if lectureStatus == 0 then 
						stext('Лекция не запущена.') 
						return 
					end
					lectureStatus = lectureStatus * -1
					if lectureStatus > 0 then 
						stext('Лекция возобновлена.')
					else 
						stext('Лекция приостановлена.') 
					end
				end
				imgui.SameLine()
				if imgui.Button(u8('Стоп')) then
					if lectureStatus == 0 then 
						stext('Лекция не запущена.') 
						return 
					end
					lectureStatus = 0
					stext('Вывод лекции прекращен.')
				end
			end
			imgui.NextColumn()
			imgui.Columns(1)
			imgui.Separator()
			imgui.Text(u8('Содержимое файла лекции:'))
			imgui.Spacing()
			if #data.lecture.text == 0 then 
				imgui.Text(u8('Файл не загружен/пуст!')) 
			end
			for i = 1, #data.lecture.text do
				imgui.Text(u8:encode(data.lecture.text[i]))
			end
		elseif show == 3 then
			imgui.NewLine()
			imgui.NewLine()
			imgui.NewLine()
			imgui.NewLine()
			imgui.CentrText('Script Version: '..thisScript().version)
			imgui.NewLine()
			imgui.CentrText(u8('Разработчик: Henrich Rogge'))
			imgui.CentrText(u8('Тестер: Bernhard Rogge'))
			imgui.CentrText(u8('Авторы: Henrich Rogge and Bernhard Rogge'))
		elseif show == 4 then
			if imgui.BeginChild('##commandlist', imgui.ImVec2(170, 290)) then
				for k, v in pairs(cmd_binder) do
					if imgui.Selectable(u8(('/%s##%s'):format(v.cmd, k)), binders.cmdselect == k) then 
						binders.cmdselect = k 
						binders.cmdbuf.v = u8(v.cmd) 
						binders.cmdparams.v = v.params
						binders.cmdtext.v = u8(v.text)
					end
				end
				imgui.EndChild()
			end
			imgui.SameLine()
			if imgui.BeginChild('##cmd_binderetting', imgui.ImVec2(500, 290)) then
				for k, v in pairs(cmd_binder) do
					if binders.cmdselect == k then
						if imgui.BeginChild('##команд', imgui.ImVec2(110, 50)) then
							imgui.PushItemWidth(105)
							imgui.Text(u8('Введите команду:'))
							imgui.InputText(u8('##Введите команду'), binders.cmdbuf)
						 	imgui.EndChild()
						end
						imgui.SameLine()
						if imgui.BeginChild('##casd', imgui.ImVec2(170, 50)) then
							imgui.PushItemWidth(165)
							imgui.Text(u8('Введите кол-во параметров:'))
							imgui.InputInt(u8('##Введи кол-во параметров'), binders.cmdparams, 0)
							imgui.EndChild()
						end
						imgui.Text(u8('Введите текст команды:'))
						imgui.InputTextMultiline(u8('##cmdtext'), binders.cmdtext, imgui.ImVec2(470, 175))
						if imgui.Button(u8('Сохранить команду'), imgui.ImVec2(130, 25)) then
							sampUnregisterChatCommand(v.cmd)
							v.cmd = u8:decode(binders.cmdbuf.v)
							v.params = binders.cmdparams.v
							v.text = u8:decode(binders.cmdtext.v)
							saveData(cmd_binder, 'moonloader/LVPD-Helper/cmdbinder.json')
							registerCommandsBinder()
							stext('Команда успешно сохранена!')
						end
						imgui.SameLine()
						if imgui.Button(u8('Удалить команду##')..k, imgui.ImVec2(130, 25)) then
							sampUnregisterChatCommand(v.cmd)
							binders.cmdselect = nil
							binders.cmdbuf.v = ''
							binders.cmdparams.v = 0
							binders.cmdtext.v = ''
							table.remove(cmd_binder, k)
							saveData(cmd_binder, 'moonloader/LVPD-Helper/cmdbinder.json')
							registerCommandsBinder()
							stext('Команда успешно удалена!')
						end
					end
				end
				imgui.EndChild()
			end
			if imgui.Button(u8('Добавить команду'), imgui.ImVec2(170, 25)) then
				table.insert(cmd_binder, {cmd = '', params = 0, text = ''})
				saveData(cmd_binder, 'moonloader/LVPD-Helper/cmdbinder.json')
			end
			imgui.SameLine(564)
			if imgui.Button(u8('Клавишный биндер')) then
				show = 5
			end
		elseif show == 5 then
			imgui.BeginChild('##bindlist', imgui.ImVec2(170, 290))
			for k, v in ipairs(tBindList) do
				if imgui.Selectable(u8('')..u8:encode(v.name)) then 
					binders.bindselect = k
					binders.bindname.v = u8(v.name) 
					binders.bindtext.v = u8(v.text)
				end
			end
			imgui.EndChild()
			imgui.SameLine()
			if imgui.BeginChild('##editbind', imgui.ImVec2(500, 290)) then
				for k, v in ipairs(tBindList) do 
					if binders.bindselect == k then
						if imgui.BeginChild('##cmbdas', imgui.ImVec2(155, 50)) then
							imgui.PushItemWidth(150)
							imgui.Text(u8('Введите название бинда:'))
							imgui.InputText('##Введите название бинда', binders.bindname)
							imgui.EndChild()
						end
						imgui.SameLine()
						if imgui.BeginChild('##3123454', imgui.ImVec2(200, 50)) then
							imgui.Text(u8('Клавиша:'))
							if imgui.HotKey(u8('##HK').. k, v, tLastKeys, 55) then
								if not rkeys.isHotKeyDefined(v.v) then
									if rkeys.isHotKeyDefined(tLastKeys.v) then
										rkeys.unRegisterHotKey(tLastKeys.v)
									end
									rkeys.registerHotKey(v.v, true, onHotKey)
								end
								saveData(tBindList, 'moonloader/LVPD-Helper/buttonbinder.json')
							end
							imgui.EndChild()
						end
						imgui.Text(u8('Введите текст бинда:'))
						imgui.InputTextMultiline('##Введите текст бинда', binders.bindtext, imgui.ImVec2(470, 175))
						if imgui.Button(u8('Сохранить бинд##')..k, imgui.ImVec2(110, 25)) then
							stext('Бинд успешно сохранен!')
							v.name = u8:decode(binders.bindname.v)
							v.text = u8:decode(binders.bindtext.v)
							saveData(tBindList, 'moonloader/LVPD-Helper/buttonbinder.json')
						end
						imgui.SameLine()
						if imgui.Button(u8('Удалить бинд##')..k, imgui.ImVec2(100, 25)) then
							stext('Бинд успешно удален!')
							table.remove(tBindList, k)
							saveData(tBindList, 'moonloader/LVPD-Helper/buttonbinder.json')
						end
					end
				end
				imgui.EndChild()
			end
			if imgui.Button(u8('Добавить клавишу'), imgui.ImVec2(170, 25)) then
				tBindList[#tBindList + 1] = {text = '', v = {}, time = 0, name = 'Бинд'..#tBindList + 1}
				saveData(tBindList, 'moonloader/LVPD-Helper/buttonbinder.json')
			end
			imgui.SameLine(564)
			if imgui.Button(u8('Командный биндер')) then
				show = 4
			end
		elseif show == 6 then
			if imgui.BeginChild('##FirstW', imgui.ImVec2(327.5, 322), true, imgui.WindowFlags.VerticalScrollbar) then
				imgui.CentrText(u8('Информация')) 
				imgui.Separator()
				imgui.Text(u8('Ник: %s[%d]'):format(sInfo.Nick, sInfo.MyId))
				imgui.TextColoredRGB(string.format('Рабочий день: %s', sInfo.WorkingDay == true and '{00bf80}Начат' or '{ec3737}Окончен'))
				imgui.Text(u8(('Время авторизации: %s'):format(sInfo.AuthTime)))
				imgui.Text(u8('Отыграно за сегодня: %s'):format(secToTime(pInfo.onlineTimer.time)))
				imgui.Text(u8('Из них на работе: %s'):format(secToTime(pInfo.onlineTimer.workTime)))
				imgui.Text(u8('AFK за сегодня: %s'):format(secToTime(pInfo.onlineTimer.dayAFK)))
				imgui.EndChild()
			end
			imgui.SameLine()
			if imgui.BeginChild('##TwoW', imgui.ImVec2(330, 322), true, imgui.WindowFlags.VerticalScrollbar) then
				imgui.CentrText(u8('Статистика за день'))
				imgui.Separator()
				imgui.Text(u8('Преступников арестовано: %s'):format(pInfo.dayCounter.arrested))
				imgui.Text(u8('Штрафов выписано: %s'):format(pInfo.dayCounter.tickets))
				imgui.EndChild()
			end
		elseif show == 7 then
			imgui.BulletText(u8('/sw - Открыть меню скрипта.'))
			imgui.BulletText(u8('/shpora - Открыть меню с шпорами.'))
			imgui.BulletText(u8('/loc [id/nick] [seconds] - Запросить местоположение игрока.'))
			imgui.BulletText(u8('/peresec [1/2/3] [reason] - Сообщить о пересечении нейтрального округа.'))
			imgui.BulletText(u8('/cn [id] [0 - RP nick, 1 - NonRP nick] - Скопировать ник в буффер обмена.'))
			imgui.BulletText(u8('/swupd - Просмотреть список обновления.'))
			imgui.BulletText(u8('/r [Text] - Авто тег в рации.'))
			imgui.BulletText(u8('/f [Text] - Авто тег в рации.'))
		elseif show == 8 then
			imgui.Text(u8('Введите ID'))
      imgui.InputInt('##player4', buffers.rebuke.id, 0)
      imgui.Text(u8('Тип выговора'))
      imgui.InputText('##vig', buffers.rebuke.type)
      imgui.Text(u8('Причина выговора'))
      imgui.InputText('##reason1', buffers.rebuke.reason)
      imgui.Spacing()
      if sampIsPlayerConnected(buffers.rebuke.id.v) then
        imgui.Text(u8('Вывод: %s получает %s выговор за %s'):format(sampGetPlayerNickname(buffers.rebuke.id.v):gsub('_', ' '), (buffers.rebuke.type.v), (buffers.rebuke.reason.v)))
      else
        imgui.Text(u8('Игрок с ID %s не подключен к серверу'):format(buffers.rebuke.id.v))
      end
      if imgui.Button(u8('Выдать выговор'), imgui.ImVec2(-0.1, 30)) then
        if sampIsPlayerConnected(buffers.rebuke.id.v) then
					sampSendChat(string.format('/r %s %s получает %s выговор за %s', tag(), sampGetPlayerNickname(buffers.rebuke.id.v):gsub('_', ' '), u8:decode(buffers.rebuke.type.v), u8:decode(buffers.rebuke.reason.v)))
				else 
					stext('Игрок оффлайн!') 
				end
			end
		elseif show == 9 then
			imgui.Text(u8('Введите ID'))
      imgui.InputInt('##player3', buffers.outfit.id, 0)
      imgui.Text(u8('Количество кругов'))
      imgui.InputInt('##krugi', buffers.outfit.circles)
      imgui.Text(u8('Причина наряда'))
      imgui.InputText('##reason', buffers.outfit.reason)
      imgui.Spacing()
      if sampIsPlayerConnected(buffers.outfit.id.v) then
        imgui.Text(u8('Вывод: %s получает наряд %s кругов за %s'):format(sampGetPlayerNickname(buffers.outfit.id.v):gsub('_', ' '), buffers.outfit.circles.v, (buffers.outfit.reason.v)))
      else
        imgui.Text(u8('Игрок с ID %s не подключен к серверу'):format(buffers.outfit.id.v))
      end
      if imgui.Button(u8('Выдать наряд'), imgui.ImVec2(-0.1, 30)) then
        if sampIsPlayerConnected(buffers.outfit.id.v) then
					sampSendChat(string.format('/r %s %s получает наряд %s кругов за %s', tag(), sampGetPlayerNickname(buffers.outfit.id.v):gsub('_', ' '), buffers.outfit.circles.v, u8:decode(buffers.outfit.reason.v)))
				else 
					stext('Игрок оффлайн!') 
				end
			end
		elseif show == 10 then
			local btn_size = imgui.ImVec2(-0.1, 25)
			imgui.PushItemWidth(200)
			imgui.Text(u8('Введите время говки в формате **:**, **:** и т. д.'))
			imgui.InputText('##inputtext', wave)
			imgui.Separator()
			imgui.Text(u8('/d OG, гос. волна на %s занята за LVPD. Возражения на п.%s.'):format(u8:decode(wave.v), sInfo.MyId))
			if imgui.Button(u8('Занять гос. волну новостей'), btn_size) then
				sampSendChat(string.format('/d OG, гос. волна на %s занята за LVPD. Возражения на п.%s.', u8:decode(wave.v), sInfo.MyId))
			end
			imgui.Text(u8('/d OG, напоминаю, гос. волна новостей на %s за LVPD.'):format(u8:decode(wave.v)))
			if imgui.Button(u8('Напомнить о занятой гос. волне новостей'), btn_size) then
				sampSendChat(string.format('/d OG, напоминаю, гос. волна новостей на %s за LVPD.', u8:decode(wave.v)))
			end
		elseif show == 11 then
			imgui.Text(u8('Введите ID'))
      imgui.InputInt('##player2', buffers.call.id, 0)
      imgui.Text(u8('РВП'))
			imgui.InputInt('##minutes2', buffers.call.minutes)
			buttonSize = imgui.ImVec2(215, 30)
			imgui.Spacing()
			if imgui.Button(u8('Вызвать в кабинет шерифа'), buttonSize) then
				if sampIsPlayerConnected(buffers.call.id.v) then
					sampSendChat(string.format('/r %s %s, подойди в кабинет шерифа, РВП - %s минут', tag(), sampGetPlayerNickname(buffers.call.id.v):gsub('_', ' '), buffers.call.minutes.v))
				else 
					stext('Игрок оффлайн!') 
				end
			end
			imgui.SameLine()
			if imgui.Button(u8('Вызвать на второй этаж'), buttonSize) then
				if sampIsPlayerConnected(buffers.call.id.v) then
					sampSendChat(string.format('/r %s %s, подойдите на 2 этаж.', tag(), sampGetPlayerNickname(buffers.call.id.v):gsub('_', ' ')))
				else 
					stext('Игрок оффлайн!') 
				end
			end
			imgui.SameLine()
			if imgui.Button(u8('Вызвать в Conference Room'), buttonSize) then
				if sampIsPlayerConnected(buffers.call.id.v) then
					sampSendChat(string.format('/r %s %s, подойдите в Conference Room.', tag(), sampGetPlayerNickname(buffers.call.id.v):gsub('_', ' ')))
				else 
					stext('Игрок оффлайн!') 
				end
			end
		elseif show == 12 then
			imgui.Text(u8('Введите ID'))
      imgui.InputInt('##player1', buffers.location.id, 0)
      imgui.Text(u8('Секунды'))
			imgui.InputInt('##minutes1', buffers.location.seconds)
			imgui.Spacing()
      if sampIsPlayerConnected(buffers.location.id.v) then
        imgui.Text(u8('Вывод: %s, ваше местоположение? на ответ %s секунд.'):format(sampGetPlayerNickname(buffers.location.id.v):gsub('_', ' '), buffers.location.seconds.v))
			else
				if buffers.location.id.v == sInfo.MyId then
					imgui.Text(u8('Нельзя запрашивать у самого себя!'))
				else
					imgui.Text(u8('Игрок с ID %s не подключен к серверу'):format(buffers.location.id.v))
				end
      end
			if imgui.Button(u8('Запросить местоположение'), imgui.ImVec2(-0.1, 30)) then
				if buffers.location.id.v == sInfo.MyId then
					stext('Нельзя запрашивать у самого себя!')
				else
					if sampIsPlayerConnected(buffers.location.id.v) then
						sampSendChat(string.format('/r %s %s, ваше местоположение? на ответ %s секунд.', tag(), sampGetPlayerNickname(buffers.location.id.v):gsub('_', ' '), buffers.location.seconds.v))
					else 
						stext('Игрок оффлайн!') 
					end
				end
			end
		end
		imgui.End()
		-- Ключи для биндеров
		if window['binder'].bool.v then
			imgui.SetNextWindowSize(imgui.ImVec2(200, 300), imgui.Cond.FirstUseEver)
			imgui.SetNextWindowPos(imgui.ImVec2(x / 2.7, y / 1.2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
			imgui.Begin('##binder', window['binder'].bool, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoTitleBar)
			if show == 4 then
				imgui.Text(u8('{noe} - Оставить сообщение в поле ввода\n{f6} - Отправить сообщение через чат\n{param:1} и т.д - Параметры\n{myid} - Ваш ID\n{myrpnick} - Ваш РП ник\n{naparnik} - Ваш напарник\n{kv} - Ваш текущий квадрат\n{VehId} - Ваш ID авто\n{wait:sek} - Задержка между строками\n{screen} - Сделать скриншот экрана\n{mytag} - Ваш тег'))
			elseif show == 5 then
				imgui.Text(u8('{noe} - Оставить сообщение в поле ввода\n{f6} - Отправить сообщение через чат\n{myid} - Ваш ID\n{myrpnick} - Ваш РП ник\n{naparnik} - Ваш напарник\n{kv} - Ваш текущий квадрат\n{VehId} - Ваш ID авто\n{wait:sek} - Задержка между строками\n{screen} - Сделать скриншот экрана\n{mytag} - Ваш тег'))
			end
			imgui.End()
		end
	end
	-- Меню шпоры
	if window['shpora'].bool.v then
    if data.shpora.loaded == 0 then
      data.shpora.select = {}
      for file in lfs.dir(getWorkingDirectory()..'\\LVPD-Helper\\shpores') do
        if file ~= '.' and file ~= '..' then
          local attr = lfs.attributes(getWorkingDirectory()..'\\LVPD-Helper\\shpores\\'..file)
          if attr.mode == 'file' then 
            table.insert(data.shpora.select, file)
          end
        end
      end
      data.shpora.page = 1
      data.shpora.loaded = 1
    end
    if data.shpora.loaded == 1 then
      if #data.shpora.select == 0 then
        data.shpora.text = {}
        data.shpora.edit = 0
      else
        -- Изменился пункт меню, загружаем шпору из уже загруженного списка файлов
        data.filename = 'moonloader/LVPD-Helper/shpores/'..data.shpora.select[data.shpora.page]
        ----------
        data.shpora.text = {}
        for line in io.lines(data.filename) do
          table.insert(data.shpora.text, line)
        end
      end
      data.shpora.search.v = ''
      data.shpora.loaded = 2
    end
    imgui.SetNextWindowSize(imgui.ImVec2(x - 400, y - 250), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowPos(imgui.ImVec2(x / 2, y / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.Begin(u8('LVPD-Helper | Шпора'), window['shpora'].bool, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.MenuBar + imgui.WindowFlags.HorizontalScrollbar)
    if imgui.BeginMenuBar(u8('LVPD-Helper')) then
      for i = 1, #data.shpora.select do
        -- Выводим названия файлов в пункты меню, удаляем .txt из названия
        local text = data.shpora.select[i]:gsub('.txt', '')
        if imgui.MenuItem(u8:encode(text)) then
          data.shpora.page = i
          data.shpora.loaded = 1
        end
      end
      imgui.EndMenuBar()
    end
    ---------
    if data.shpora.edit < 0 and #data.shpora.select > 0 then
      if imgui.Button(u8('Новая шпора'), imgui.ImVec2(120, 30)) then
        data.shpora.edit = 0
        data.shpora.search.v = ''
        data.shpora.inputbuffer.v = ''
      end
      imgui.SameLine()
      if imgui.Button(u8('Изменить шпору'), imgui.ImVec2(120, 30)) then
        data.shpora.edit = data.shpora.page
        local text = data.shpora.select[data.shpora.page]:gsub('.txt', '')
        data.shpora.search.v = u8:encode(text)
        local ttext  = ''
        for k, v in pairs(data.shpora.text) do
          ttext = ttext .. v .. '\n'
        end
        data.shpora.inputbuffer.v = u8:encode(ttext)
      end
      imgui.SameLine()
      if imgui.Button(u8('Удалить шпору'), imgui.ImVec2(120, 30)) then
        os.remove(data.filename)
        data.shpora.loaded = 0
        stext('Шпора \''..data.filename..'\' успешно удалена!')
      end
      imgui.Spacing()
      ---------
      imgui.PushItemWidth(250)
      imgui.Text(u8('Поиск по тексту'))
      imgui.InputText('##inptext', data.shpora.search)
      imgui.PopItemWidth()
      imgui.Separator()
      imgui.Spacing()
      for k, v in pairs(data.shpora.text) do
        if u8:decode(data.shpora.search.v) == '' or string.find(rusUpper(v), rusUpper(u8:decode(data.shpora.search.v))) ~= nil then
          imgui.Text(u8(v))
        end
      end
    else
      imgui.PushItemWidth(250)
      imgui.Text(u8('Введите название шпоры'))
      imgui.InputText('##inptext', data.shpora.search)
      imgui.PopItemWidth()
      if imgui.Button(u8('Сохранить'), imgui.ImVec2(120, 30)) then
        if #data.shpora.search.v ~= 0 and #data.shpora.inputbuffer.v ~= 0 then
          if data.shpora.edit == 0 then
            local file = io.open('moonloader\\LVPD-Helper\\shpores\\'..u8:decode(data.shpora.search.v)..'.txt', 'a+')
            file:write(u8:decode(data.shpora.inputbuffer.v))
            file:close()
            stext('Шпора успешно создана!')
          elseif data.shpora.edit > 0 then
            local file = io.open(data.filename, 'w+')
            file:write(u8:decode(data.shpora.inputbuffer.v))
            file:close()
            local rename = os.rename(data.filename, 'moonloader\\LVPD-Helper\\shpores\\'..u8:decode(data.shpora.search.v)..'.txt')
            if rename then
              stext('Шпора успешно изменена!')
            else
              stext('Ошибка при изменении шпоры')
            end
          end
          data.shpora.search.v = ''
          data.shpora.loaded = 0
          data.shpora.edit = -1
				else 
					stext('Все поля должны быть заполнены!') 
				end
      end
      imgui.SameLine()
      if imgui.Button(u8('Отмена'), imgui.ImVec2(120, 30)) then
        if #data.shpora.select > 0 then
          data.shpora.edit = -1
          data.shpora.search.v = ''
				else 
					stext('Вам необходимо создать хотя бы одну шпору!') 
				end
      end
      imgui.Separator()
      imgui.Spacing()
      imgui.InputTextMultiline('##intextmulti', data.shpora.inputbuffer, imgui.ImVec2(-1, -1))
    end
    imgui.End()
	end 
	-- Реестр
	if window['addtable'].bool.v then
		-- Устанавливаем размер окна
		imgui.SetNextWindowSize(imgui.ImVec2(700, 400), imgui.Cond.FirstUseEver)
		imgui.SetNextWindowPos(imgui.ImVec2(x / 2, y / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
		-- Формируем окно и указываем имя 
		imgui.Begin(u8(thisScript().name..' | addtable | Version: '..thisScript().version), window['addtable'].bool, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize)
		imgui.Text(u8'Выберите тип данных')
		imgui.Combo('##combo', data.combo.addtable, u8'Не выбрано\0Повышение\0Увольнение\0Контракт\0Выговор\0Призывник\0test\0\0')
		imgui.Separator()
		if data.combo.addtable.v > 0 then
			imgui.InputText(u8 'Введите ID/ник игрока', data.addtable.nick)
		end
		if data.combo.addtable.v == 1 then
			imgui.InputText(u8 'С какого ранга', data.addtable.param1)
			imgui.InputText(u8 'На какой ранг', data.addtable.param2)
			imgui.InputText(u8 'Причина', data.addtable.reason)
		elseif data.combo.addtable.v == 2 then
			imgui.InputText(u8 'Причина', data.addtable.reason)
		elseif data.combo.addtable.v == 3 then
			imgui.InputText(u8 'Тип КС (1,2)', data.addtable.param2)
			imgui.InputText(u8 'Взвод', data.addtable.reason)
		elseif data.combo.addtable.v == 4 then
			imgui.InputText(u8 'Тип выговора (1 - обычный, 2 - строгий)', data.addtable.param2)
			imgui.InputText(u8 'Причина', data.addtable.reason)
			imgui.InputText(u8 'Приговор', data.addtable.param1)
		elseif data.combo.addtable.v == 6 then
			imgui.InputText(u8 'Причина', data.addtable.reason)
		end
		if data.combo.addtable.v > 0 then
			if imgui.Button(u8'Отправить') then
				local nickname = u8:decode(data.addtable.nick.v)
				local param1 = u8:decode(data.addtable.param1.v)
				local param2 = u8:decode(data.addtable.param2.v)
				local reason = u8:decode(data.addtable.reason.v)
				local pid = tonumber(nickname)
				if sInfo.MyId ~= pid and sInfo.Nick ~= nickname then
					if pid ~= nil then
						if sampIsPlayerConnected(pid) then nickname = sampGetPlayerNickname(pid) end
					end
					if tonumber(nickname) == nil then
						if data.combo.addtable.v == 1 then
							if nickname ~= '' and param1 ~= '' and param2 ~= '' and reason ~= '' then
								if tonumber(param1) ~= nil and tonumber(param1) >= 1 and tonumber(param1) < 15 and tonumber(param2) ~= nil and tonumber(param2) >= 1 and tonumber(param2) < 15 then
									atext(('Повышение: [Ник: %s] [С ранга: %s] [На ранг: %s] [Причина: %s]'):format(nickname, param1, param2, reason))
									sendGoogleMessage('giverank', nickname, param1, param2, reason, os.time())
								else atext('Неверные параметры ранга!') end
							else atext('Все поля должны быть заполнены!') end
	
						elseif data.combo.addtable.v == 2 then
							if nickname ~= '' and reason ~= '' and nickname ~= nil and reason ~= nil then
								atext(('Увольнение: [Ник: %s] [Причина: %s]'):format(nickname, reason))
								sendGoogleMessage('uninvite', nickname, _, _, reason, os.time())
							else atext('Все поля должны быть заполнены!') end
	
						elseif data.combo.addtable.v == 3 then
							if nickname ~= '' and nickname ~= nil and reason ~= nil and reason ~= '' and param2 ~= '' and param2 ~= nil then
								if tonumber(param2) ~= nil and (tonumber(param2) == 1 or tonumber(param2) == 2) then
									atext(('Контракт: [Ник: %s] [Тип КС: %s] [Взвод: %s]'):format(nickname, param2, reason))
									sendGoogleMessage('contract', nickname, _, param2, reason, os.time())
								else atext('Неверный тип КС') end
							else atext('Все поля должны быть заполнены!') end
	
						elseif data.combo.addtable.v == 4 then
							if nickname ~= '' and param1 ~= '' and param2 ~= '' and param2 ~= nil and reason ~= '' and nickname ~= nil and param1 ~= nil and reason ~= nil then
								if tonumber(param2) ~= nil and (tonumber(param2) == 1 or tonumber(param2) == 2) then
									atext(('Выговор: [Ник: %s] [Тип: %s] [Приговор: %s] [Причина: %s]'):format(nickname, param2, param1, reason))
									sendGoogleMessage('reprimand', nickname, param1, param2, reason, os.time())
								else atext('Неверный тип выговора') end
							else atext('Все поля должны быть заполнены!') end
	
						elseif data.combo.addtable.v == 5 then
							if nickname ~= '' and nickname ~= nil then
								atext(('Призывник: [Ник: %s] [Дата: %s]'):format(nickname, os.date('%d.%m.%y')))
								sendGoogleMessage('prizivnik', nickname, _, _, _, os.time())
							else atext('Все поля должны быть заполнены!') end    
							
						elseif data.combo.addtable.v == 6 then
							if nickname ~= '' and nickname ~= nil and reason ~= nil and reason ~= '' then
								atext(('Тест: [Ник: %s] [Дата: %s] [Причина: %s]'):format(nickname, os.date('%d.%m.%y'), reason))
								sendGoogleMessage('test', nickname, _, _, reason, os.time())
							else atext('Все поля должны быть заполнены!') end
						end

					else atext('Неверный ID игрока!') end
				else atext('Вы не можете внести себя в таблицу!') end
			end
		end
		imgui.End()
	end
end

-- younick, docs, stepen', reason, time
function sendGoogleMessage(type, name, param1, param2, reason, time)
  local mynick = sInfo.Nick
  local date = os.date('*t', time)
  date = ('%d.%d.%d %d:%d:%d'):format(date.day, date.month, date.year, date.hour, date.min, date.sec)
  -- Формируем ссылки
  local url = '?executor='..mynick
  if type == 'giverank' then
    url = url..('&type=%s&who=%s&param1=%s&param2=%s&reason=%s&date=%s'):format(type, name, encodeURI(u8:encode(param1)), encodeURI(u8:encode(param2)), encodeURI(u8:encode(reason)), date)
  elseif type == 'uninvite' then
    url = url..('&type=%s&who=%s&reason=%s&date=%s&param1=1&param2=1'):format(type, name, encodeURI(u8:encode(reason)), date)
  elseif type == 'contract' then
    local date1 = os.date('*t', time)
    local date2 = os.date('*t', time+(604800*tonumber(param2)))
    date = ('%d.%d.%d - %d.%d.%d'):format(date1.day, date1.month, date1.year, date2.day, date2.month, date2.year)
    if tonumber(param2) == 2 then param1 = 4
    else param1 = 3 end
    url = url..('&type=%s&who=%s&param1=%s&date=%s&reason=%s&param2=1'):format(type, name, encodeURI(u8:encode(param1)), date, encodeURI(u8:encode(reason)))
  elseif type == 'reprimand' then
    local date1 = os.date('*t', time)
    local date2 = os.date('*t', time+(604800*tonumber(param2)))
    date = ('%d.%d.%d - %d.%d.%d'):format(date1.day, date1.month, date1.year, date2.day, date2.month, date2.year)
    url = url..('&type=%s&who=%s&reason=%s&date=%s&param1=%s&param2=1'):format(type, name, encodeURI(u8:encode(reason)), date, encodeURI(u8:encode(param1)))
  elseif type == 'blacklist' then
    url = url..('&type=%s&who=%s&reason=%s&date=%s&param1=%s&param2=%s'):format(type, name, encodeURI(u8:encode(reason)), date, encodeURI(u8:encode(param1)), encodeURI(u8:encode(param2)))
  elseif type == 'prizivnik' then
    local newdate = os.date('*t', time+(86400*2))
    newdate = ('%d.%d.%d'):format(newdate.day, newdate.month, newdate.year)
    local olddate = os.date('*t', time)
    olddate = ('%d.%d.%d'):format(olddate.day, olddate.month, olddate.year)
    url = url..('&type=%s&who=%s&date=%s&reason=1&param1=%s&param2=1'):format(type, name, olddate, newdate)
	elseif type == 'test' then
		url = url..('&type=%s&who=%s&reason=%s&date=%s&param1=1&param2=1'):format(type, name, encodeURI(u8:encode(reason)), date)
  else return end
  local complete = false
  lua_thread.create(function()
    local dlstatus = require('moonloader').download_status
    local downloadpath = getWorkingDirectory() .. '\\LVPD-Helper\\urlRequests.json'
    wait(50)
    -- Google Script отклоняет запросы через requests.
    downloadUrlToFile('https://script.google.com/macros/s/AKfycbyAr7MlRYrmMTiD3ZAG2gQnnQl4AABJP6tcjipS7y-u0V-0pyBPmwQa/exec'..url, downloadpath, function(id, status, p1, p2) -- remove
      if status == dlstatus.STATUS_ENDDOWNLOADDATA then
        complete = true
      end
    end)
    while complete ~= true do wait(50) end
    local file = io.open('moonloader/LVPD-Helper/urlRequests.json', 'r+')
    if file == nil then return end
    local cfg = file:read('*a')
    file:close()
    wait(50)
    os.remove(downloadpath)
    return
  end)
end

--- Кодирует текст для передачи в URI
function encodeURI(str)
  if (str) then
    str = string.gsub (str, '\n', '\r\n')
    str = string.gsub (str, '([^%w ])',
      function (c) return string.format ('%%%02X', string.byte(c)) end)
    str = string.gsub (str, ' ', '+')
   end
   return str
end

-- rusUpper для русских букв
function rusUpper(string)
	-- Русские буквы
	local russian_characters = {
  	[168] = 'Ё', [184] = 'ё', [192] = 'А', [193] = 'Б', [194] = 'В', [195] = 'Г', [196] = 'Д', [197] = 'Е', [198] = 'Ж', [199] = 'З', [200] = 'И', [201] = 'Й', [202] = 'К', [203] = 'Л', [204] = 'М', [205] = 'Н', [206] = 'О', [207] = 'П', [208] = 'Р', [209] = 'С', [210] = 'Т', [211] = 'У', [212] = 'Ф', [213] = 'Х', [214] = 'Ц', [215] = 'Ч', [216] = 'Ш', [217] = 'Щ', [218] = 'Ъ', [219] = 'Ы', [220] = 'Ь', [221] = 'Э', [222] = 'Ю', [223] = 'Я', [224] = 'а', [225] = 'б', [226] = 'в', [227] = 'г', [228] = 'д', [229] = 'е', [230] = 'ж', [231] = 'з', [232] = 'и', [233] = 'й', [234] = 'к', [235] = 'л', [236] = 'м', [237] = 'н', [238] = 'о', [239] = 'п', [240] = 'р', [241] = 'с', [242] = 'т', [243] = 'у', [244] = 'ф', [245] = 'х', [246] = 'ц', [247] = 'ч', [248] = 'ш', [249] = 'щ', [250] = 'ъ', [251] = 'ы', [252] = 'ь', [253] = 'э', [254] = 'ю', [255] = 'я',
	}
  local strlen = string:len()
	if strlen == 0 then 
		return string 
	end
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

-- Автотег в рацию
function cmd_r(args)
	if #args == 0 then
		atext('Введите: /r [text]')
		return
	end
	if pInfo.options.tarb == true then
		sampSendChat(string.format('/r %s; `%s: %s', pInfo.options.tar, sInfo.MyId, args))
	else
		sampSendChat(string.format('/r %s', args))
	end
end

function cmd_f(args)
	if #args == 0 then
		atext('Введите: /f [text]')
		return
	end
	if pInfo.options.tarb == true then
		sampSendChat(string.format('/f %s; `%s, %s', pInfo.options.tar, sInfo.MyId, args))
	else
		sampSendChat(string.format('/f `%s, %s', sInfo.MyId, args))
	end
end

-- Копирование никнеймов
function cmd_cn(args)
	if #args == 0 then 
		atext('Введите: /cn [id] [0 - RP nick, 1 - NonRP nick]') 
		return 
	end
  args = string.split(args, ' ')
  if #args == 1 then
    cmd_cn(args[1]..' 0')
  elseif #args == 2 then
    local getID = tonumber(args[1])
		if getID == nil then 
			stext('Неверный ID игрока!') 
			return 
		end
		if not sampIsPlayerConnected(getID) then 
			stext('Игрок оффлайн!') 
			return 
		end 
    getID = sampGetPlayerNickname(getID)
    if tonumber(args[2]) == 1 then
      stext(('НонРП Ник {2C7AA9}%s {FFFFFF}скопирован в буфер обмена.'):format(getID))
    else
      getID = string.gsub(getID, '_', ' ')
      stext(('РП Ник {2C7AA9}%s {FFFFFF}скопирован в буфер обмена.'):format(getID))
    end
    setClipboardText(getID)
  else
    atext('Введите: /cn [id] [0 - RP nick, 1 - NonRP nick]')
    return
  end 
end

-- Запрос местоположения
function cmd_loc(args)
	args = string.split(args, ' ')
	if #args ~= 2 then
		atext('Введите: /loc [id] [seconds]') 
		return
	end
	local nick = tonumber(args[1])
	local seconds = tonumber(args[2])
	if nick and seconds ~= nil then
		local rpnick = sampGetPlayerNickname(nick):gsub('_', ' ')
		if nick == sInfo.MyId or rpnick == sInfo.Nick then
			stext('Нельзя запрашивать у самого себя!')
			return
		else
			sampSendChat(string.format('/r %s %s, ваше местоположение? На ответ %s секунд.', tag(), rpnick, seconds))
		end
	end
end

-- Пересечение нейтральных округов
function cmd_peresec(args)
	if #args == 0 then
		atext('Введите: /peresec [1/2/3] [reason]')
		atext('1 - Северный, 2 - Центральный, 3 - Южный.')
		return
	end
	local args = string.split(args, ' ', 2)
	args[1] = tonumber(args[1])
	local reason = args[2]
	if args[1] == 1 then
		sampSendChat(string.format('/d AF, пересекаю северный нейтральный округ по причине %s.', reason))
	elseif args[1] == 2 then
		sampSendChat(string.format('/d AF, пересекаю центральный нейтральный округ по причине %s.', reason))
	elseif args[1] == 3 then
		sampSendChat(string.format('/d AF, пересекаю южный нейтральный округ по причине %s.', reason))
	end
end

-- Лог обновлений
function cmd_lvpdhelperupdates()
  local str = '{FFFFFF}Тип: {2C7AA9}'..updatesInfo.type..'\n{FFFFFF}Версия скрипта: {2C7AA9}'..updatesInfo.version..'\n{FFFFFF}Дата выхода: {2C7AA9}'..updatesInfo.date..'{FFFFFF}\n\n'
  for i = 1, #updatesInfo.list do
    str = str..'{2C7AA9}-{FFFFFF}'
    for j = 1, #updatesInfo.list[i] do
      str = string.format('%s %s%s\n', str, j > 1 and ' ' or '', updatesInfo.list[i][j]:gsub('``(.-)``', '{2C7AA9}%1{FFFFFF}'))
    end
  end
  sampShowDialog(61315125, '{2C7AA9}LVPD-Helper | {FFFFFF}Список обновлений', str, 'Закрыть', '', DIALOG_STYLE_MSGBOX)
end

-- Делит строку по паттерну
function string.split(str, delim, plain)
  local tokens, pos, plain = {}, 1, not (plain == false)
  repeat
    local npos, epos = string.find(str, delim, pos, plain)
    table.insert(tokens, string.sub(str, pos, npos and npos - 1))
    pos = epos and epos + 1
  until not pos
  return tokens
end

-- Если скрипт вылетел скрываем курсор, и сохраняем данные
function onScriptTerminate(LuaScript, quitGame)
	if LuaScript == thisScript() then
		showCursor(false)
		lua_thread.create(function()
			print('Скрипт выключился. Настройки сохранены.')
			if pInfo.onlineTimer.time then
				pInfo.onlineTimer.time = pInfo.onlineTimer.time
				saveData(pInfo, 'moonloader/LVPD-Helper/config.json') 
			end
		end)
  end
end

-- Cчетчики
function onlineTimer()
	lua_thread.create(function()
		updatecount = 0 
		while true do
			if sInfo.WorkingDay == true then
				pInfo.onlineTimer.workTime = pInfo.onlineTimer.workTime + 1
			end
			pInfo.onlineTimer.time = pInfo.onlineTimer.time + 1
			pInfo.onlineTimer.dayAFK = pInfo.onlineTimer.dayAFK + (os.time() - sInfo.updateAFK - 1)
			if updatecount >= 10 then 
				saveData(pInfo, 'moonloader/LVPD-Helper/config.json')  
				updatecount = 0 
			end
			updatecount = updatecount + 1
			sInfo.updateAFK = os.time()
			wait(1000)
		end
	end)
end

-- Перевод секунд в 00:00:00
function secToTime(sec)
  local hour, minute, second = sec / 3600, math.floor(sec / 60), sec % 60
  return string.format('%02d:%02d:%02d', math.floor(hour) ,  minute - (math.floor(hour) * 60), second)
end

-- Закрытие меню подсказки для биндеров
function binderclose()
	if window['binder'].bool.v == true then
		window['binder'].bool.v = false
	end
end

-- Если нажал клавишу - выполняем действие
function punaccept()
	if invite == true then
		sampSendChat(string.format('/r %s %s новый сотрудник нашего департамента.', tag(), nick))
		invite = false
	end
	if uninvite == true then
		lua_thread.create(function()
			sampSendChat(string.format('/me достал КПК, после чего отметил личное дело %s как «Уволен»', nick))
			wait(1000)
			sampSendChat(string.format('/r %s Офицер %s уволен из департамента. Причина: %s.', tag(), nick, reason))
		end)
		uninvite = false
	end
end

-- Рандомные сообщения
function random_messages()
	lua_thread.create(function()
		while true do
			wait(600000)
			if pInfo.options.advertisement == true then
				for _, v in pairs(messages[math.random(1, #messages)]) do
					atext(v)
				end
			end
		end
	end)
end

-- Авто-обновление
function update()
	local filepath = os.getenv('TEMP') .. '\\lvpdhelperupd.json'
	downloadUrlToFile('https://raw.githubusercontent.com/Tur41k/update/master/lvpdhelperupd.json', filepath, function(id, status, p1, p2)
		if status == dlstatus.STATUS_ENDDOWNLOADDATA then
			local file = io.open(filepath, 'r')
			if file then
				local info = decodeJson(file:read('*a'))
				updatelink = info.updateurl
				if info and info.latest then
					if tonumber(thisScript().version) < tonumber(info.latest) then
						lua_thread.create(function()
							stext('Началось скачивание обновления. Скрипт перезагрузится через пару секунд.')
							wait(300)
							downloadUrlToFile(updatelink, thisScript().path, function(id3, status1, p13, p23)
								if status1 == dlstatus.STATUS_ENDDOWNLOADDATA then
									print('Обновление успешно скачано и установлено.')
								elseif status1 == 64 then
									stext('Обновление успешно скачано и установлено. Просмотреть список изменений - /swupd')
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

-- Ключи для командного биндера
function registerCommandsBinder()
	for k, v in pairs(cmd_binder) do
		if sampIsChatCommandDefined(v.cmd) then 
			sampUnregisterChatCommand(v.cmd) 
		end
		sampRegisterChatCommand(v.cmd, function(args)
			thread = lua_thread.create(function()
				local params = string.split(args, ' ', v.params)
				local cmdtext = v.text
				if #params < v.params then
					local paramtext = ''
					for i = 1, v.params do
						paramtext = paramtext .. '[параметр'..i..'] '
					end
					atext(('Введите: /%s %s'):format(v.cmd, paramtext))
					return
				else
					for line in cmdtext:gmatch('[^\r\n]+') do
						if line:match('^{wait%:%d+}$') then
							wait(line:match('^%{wait%:(%d+)}$'))
						elseif line:match('^{screen}$') then
							screen()
						else
							local bIsEnter = string.match(line, '^{noe}(.+)') ~= nil
							local bIsF6 = string.match(line, '^{f6}(.+)') ~= nil
							local keys = {
								['{f6}'] = '',
								['{noe}'] = '',
								['{myid}'] = sInfo.MyId,
								['{kv}'] = kvadrat(),
								['{naparnik}'] = unit(),
								['{myrpnick}'] = sInfo.Nick:gsub('_', ' '),
								['{VehId}'] = sInfo.VehicleId,
								['{mytag}'] = tag()
							}
							for i = 1, v.params do
								keys['{param:'..i..'}'] = params[i]
							end
							for k1, v1 in pairs(keys) do
								line = line:gsub(k1, v1)
							end
							if not bIsEnter then
								if bIsF6 then
									sampProcessChatInput(line)
								else
									sampSendChat(line)
								end
							else
								sampSetChatInputText(line)
								sampSetChatInputEnabled(true)
							end
						end
					end
				end
			end)
		end)
	end
end

-- Ключи для клавишного биндера
function onHotKey(id, keys)
	lua_thread.create(function()
		local sKeys = tostring(table.concat(keys, ' '))
		for k, v in pairs(tBindList) do
			if sKeys == tostring(table.concat(v.v, ' ')) then
				local tostr = tostring(v.text)
				if tostr:len() > 0 then
					for line in tostr:gmatch('[^\r\n]+') do
						if line:match('^{wait%:%d+}$') then
							wait(line:match('^%{wait%:(%d+)}$'))
						elseif line:match('^{screen}$') then
							screen()
						else
							local bIsEnter = string.match(line, '^{noe}(.+)') ~= nil
							local bIsF6 = string.match(line, '^{f6}(.+)') ~= nil
							local keys = {
								['{f6}'] = '',
								['{noe}'] = '',
								['{myid}'] = sInfo.MyId,
								['{kv}'] = kvadrat(),
								['{naparnik}'] = unit(),
								['{myrpnick}'] = sInfo.Nick:gsub('_', ' '),
								['{VehId}'] = sInfo.VehicleId,
								['{mytag}'] = tag()
							}
							for k1, v1 in pairs(keys) do
								line = line:gsub(k1, v1)
							end
							if not bIsEnter then
								if bIsF6 then
									sampProcessChatInput(line)
								else
									sampSendChat(line)
								end
							else
								sampSetChatInputText(line)
								sampSetChatInputEnabled(true)
							end
						end
					end
				end
			end
		end
	end)
end

-- Пока окно открыто блокируем нажатия биндера
function rkeys.onHotKey(id, keys)
	if sampIsChatInputActive() or sampIsDialogActive() or isSampfuncsConsoleActive() then
		return false
	end
end

-- Скрин экрана (для клавишного биндера)
function screen()
	memory.setuint8(sampGetBase() + 0x119CBC, 1) 
end

-- Samp Events (хуки)
function sampevents.onServerMessage(color, text)
	if text:find('Вы предложили .+ вступить в LVPD.') or text:find('Вы перевели .+ в Полицию ЛВ') then
		local pNick = text:match('Вы предложили (.+) вступить в LVPD.') or text:match('Вы перевели (.+) в Полицию ЛВ')
		lua_thread.create(function()
			wait(100)
			nick = pNick:gsub('_', ' ')
			invite = true
			atext(('Нажмите {139904}%s{FFFFFF} для оповещения в рацию об принятии'):format(table.concat(rkeys.getKeysName(config_keys.punaccept.v), ' + ')))
		end)
	end
	if text:find('Вы выгнали .+ из организации. Причина: .+') and color == 1806958506 then
		local pNick, pReason = text:match('Вы выгнали (.+) из организации. Причина: (.+)')
		lua_thread.create(function()
			wait(100)
			nick = pNick:gsub('_', ' ')
			reason = pReason
			uninvite = true
			atext(('Нажмите {139904}%s{FFFFFF} для оповещения в рацию об увольнении'):format(table.concat(rkeys.getKeysName(config_keys.punaccept.v), ' + ')))
		end)
	end
	if color == 1687547391 then
		if text:find('Вы выписали штраф в размере') then
			pInfo.dayCounter.tickets = pInfo.dayCounter.tickets + 1
		elseif text:find('Вы посадили в тюрьму') then
			pInfo.dayCounter.arrested = pInfo.dayCounter.arrested + 1
		end
		if pInfo.options.clistb == true then
			if text:find('Рабочий день начат') then
				lua_thread.create(function()
					wait(1)
					sampSendChat(string.format('/clist %s', pInfo.options.clist))
				end)
			end
		end
	end
	if pInfo.options.pg == true then
		if color == -1697828097 then
			if text:find('Вы назначили (.+) (.+)') then
				local nick, rank = text:match('Вы назначили (.+) (.+)')
				-- Название погон
				local ranknames = {
					['Кадет[1].'] = 'Кадета',
					['Офицер[2].'] = 'Офицера',
					['Мл.Сержант[3].'] = 'Мл.Сержанта',
					['Сержант[4].'] = 'Сержанта',
					['Прапорщик[5].'] = 'Прапорщика',
					['Ст.Прапорщик[6].'] = 'Ст.Прапорщика',
					['Мл.Лейтенант[7].'] = 'Мл.Лейтенанта',
					['Лейтенант[8].'] = 'Лейтенанта',
					['Ст.Лейтенант[9].'] = 'Ст.Лейтенанта',
					['Капитан[10].'] = 'Капитана',
					['Майор[11].'] = 'Майора',
					['Подполковник[12].'] = 'Подполковника',
					['Полковник[13].'] = 'Полковника'
				}
				if ranknames[rank] ~= nil then 
					local rank = ranknames[rank]
					local nick = nick:gsub('_', ' ')
					lua_thread.create(function()
						wait(1000)
						sampSendChat(string.format('/me достал футляр с погонами %s и передал их %s', rank, nick))
					end)
				end
			end
		end
	end
end

function sampevents.onSendSpawn()
	if pInfo.options.clistb and sInfo.WorkingDay == true then
		lua_thread.create(function()
			wait(1400)
			sampSendChat(string.format('/clist %s', pInfo.options.clist))
		end)
	end
end

-- Узнаем нужную нам информацию
-- Фракция по скину персонажа
function sampGetFraktionBySkin(id)
  local skin = 0
  local t = 'Гражданский'
  local result, ped = sampGetCharHandleBySampPlayerId(id)
  if result then
    skin = getCharModel(ped)
  else
    skin = getCharModel(PLAYER_PED)
  end
  if skin == 102 or skin == 103 or skin == 104 or skin == 195 or skin == 21 then 
    t = 'Ballas Gang' 
  elseif skin == 105 or skin == 106 or skin == 107 or skin == 269 or skin == 270 or skin == 271 or skin == 86 or skin == 149 or skin == 297 then 
    t = 'Grove Gang' 
  elseif skin == 108 or skin == 109 or skin == 110 or skin == 190 or skin == 47 then 
    t = 'Vagos Gang' 
  elseif skin == 114 or skin == 115 or skin == 116 or skin == 48 or skin == 44 or skin == 41 or skin == 292 then 
    t = 'Aztec Gang' 
  elseif skin == 173 or skin == 174 or skin == 175 or skin == 193 or skin == 226 or skin == 30 or skin == 119 then 
    t = 'Rifa Gang' 
  elseif skin == 191 or skin == 252 or skin == 287 or skin == 61 or skin == 179 or skin == 255 then 
    t = 'Army' 
  elseif skin == 57 or skin == 98 or skin == 147 or skin == 150 or skin == 187 or skin == 216 then 
    t = 'Мэрия' 
	elseif skin == 59 or skin == 172 or skin == 189 or skin == 240 then 
    t = 'Автошкола' 
  elseif skin == 201 or skin == 247 or skin == 248 or skin == 254 or skin == 248 or skin == 298 then 
    t = 'Байкеры' 
  elseif skin == 272 or skin == 112 or skin == 125 or skin == 214 or skin == 111  or skin == 126 then 
    t = 'Русская мафия' 
  elseif skin == 113 or skin == 124 or skin == 214 or skin == 223 then 
    t = 'La Cosa Nostra' 
  elseif skin == 120 or skin == 123 or skin == 169 or skin == 186 then 
    t = 'Yakuza' 
  elseif skin == 211 or skin == 217 or skin == 250 or skin == 261 then 
    t = 'News' 
  elseif skin == 70 or skin == 219 or skin == 274 or skin == 275 or skin == 276 or skin == 70 then 
    t = 'Медики' 
  elseif skin == 286 or skin == 141 or skin == 163 or skin == 164 or skin == 165 or skin == 166 then 
    t = 'FBI' 
  elseif skin == 280 or skin == 265 or skin == 266 or skin == 267 or skin == 281 or skin == 282 or skin == 288 or skin == 284 or skin == 285 or skin == 304 or skin == 305 or skin == 306 or skin == 307 or skin == 309 or skin == 283 or skin == 303 then 
    t = 'Полиция' 
  end
  return t
end

-- Ник Unit'a(ов) (в машине, на улице)
function unit()
	local v = {}
  if isCharInAnyCar(PLAYER_PED) then
    local veh = storeCarCharIsInNoSave(PLAYER_PED)
    for i = 0, 999 do
      if sampIsPlayerConnected(i) then
        local ichar = select(2, sampGetCharHandleBySampPlayerId(i))
        if doesCharExist(ichar) then
          if isCharInAnyCar(ichar) then
            local iveh = storeCarCharIsInNoSave(ichar)
            if veh == iveh then
							if sampGetFraktionBySkin(i) == 'Полиция' or sampGetFraktionBySkin(i) == 'FBI' then
								local inick, ifam = sampGetPlayerNickname(i):match('(.+)_(.+)')
								if inick and ifam then
									table.insert(v, string.format('%s.%s', inick:sub(1,1), ifam))
                end
              end
            end
          end
        end
      end
    end
  else
    local myposx, myposy, myposz = getCharCoordinates(PLAYER_PED)
    for i = 0, 999 do
      if sampIsPlayerConnected(i) then
        local ichar = select(2, sampGetCharHandleBySampPlayerId(i))
        if doesCharExist(ichar) then
          local ix, iy, iz = getCharCoordinates(ichar)
          if getDistanceBetweenCoords3d(myposx, myposy, myposz, ix, iy, iz) <= 30 then
						if sampGetFraktionBySkin(i) == 'Полиция' or sampGetFraktionBySkin(i) == 'FBI' then
							local inick, ifam = sampGetPlayerNickname(i):match('(.+)_(.+)')
							local inick = sampGetPlayerNickname(i)
							if inick and ifam then
								table.insert(v, string.format('%s.%s', inick:sub(1,1), ifam))
							end
            end
          end
        end
      end
    end
  end
  if #v == 0 then
    return 'Unit: not.'
  elseif #v == 1 then
    return 'Unit: '..table.concat(v, ', ').. '.'
  elseif #v >=2 then
    return 'Unit\'s: '..table.concat(v, ', ').. '.'
  end
end

-- Квадрат где наш персонаж находится
function kvadrat()
  local KV = {
    [1] = 'А',
    [2] = 'Б',
    [3] = 'В',
    [4] = 'Г',
    [5] = 'Д',
    [6] = 'Ж',
    [7] = 'З',
    [8] = 'И',
    [9] = 'К',
    [10] = 'Л',
    [11] = 'М',
    [12] = 'Н',
    [13] = 'О',
    [14] = 'П',
    [15] = 'Р',
    [16] = 'С',
    [17] = 'Т',
    [18] = 'У',
    [19] = 'Ф',
    [20] = 'Х',
    [21] = 'Ц',
    [22] = 'Ч',
    [23] = 'Ш',
    [24] = 'Я',
  }
  local X, Y, Z = getCharCoordinates(playerPed)
  X = math.ceil((X + 3000) / 250)
  Y = math.ceil((Y * - 1 + 3000) / 250)
  Y = KV[Y]
  local KVX = (Y..'-'..X)
  return KVX
end

-- Автотег для биндера
function tag()
	local tag = {}
	if pInfo.options.tarb == true then
		table.insert(tag, string.format('%s; `%s,', pInfo.options.tar, sInfo.MyId))
	else
		table.insert(tag, string.format('`%s,', sInfo.MyId))
	end
	return table.concat(tag)
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

-- Функции для красоты в imgui
function imgui.CentrText(text)
	local width = imgui.GetWindowWidth()
	local calc = imgui.CalcTextSize(text)
	imgui.SetCursorPosX( width / 2 - calc.x / 2 )
	imgui.Text(text)
end

function imgui.TextQuestion(text)
	imgui.TextDisabled('(?)')
	if imgui.IsItemHovered() then
		imgui.BeginTooltip()
		imgui.PushTextWrapPos(450)
		imgui.TextUnformatted(text)
		imgui.PopTextWrapPos()
		imgui.EndTooltip()
	end
end

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

function atext(text)
	sampAddChatMessage((' » {FFFFFF}%s'):format(text), 0x2C7AA9)
end