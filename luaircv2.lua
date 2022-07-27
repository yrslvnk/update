local socket = require "socket"
require "lanes"

local sampfuncsLog = sampfuncsLog
local lua_thread = lua_thread
local wait = wait
local print = print
local error = error
local setmetatable = setmetatable
local rawget = rawget
local unpack = unpack
local pairs = pairs
local assert = assert
local require = require
local tonumber = tonumber
local type = type
local pcall = pcall

module "irc"

local meta = {}
meta.___version___ = "0.2"
meta.__isConnected = false
meta.__isJoined = false
meta.__Status = "Not connecting"
meta.__Prefix = "WebSocket"
meta.__index = meta
_META = meta

require "util"
require "asyncoperations"
require "handlers"

local meta_preconnect = {}

function meta_preconnect.__index(o, k)
	local v = rawget(meta_preconnect, k)

	if not v and meta[k] then
		meta.__isConnected = false
		meta.__isJoined = false
		meta.__Status = ("Field %s"):format(k)
		sampfuncsLog(meta.__Prefix..meta.__Status, -1)
	end
	return v
end

function new(data)
	nick = data.nick:gsub("%W", tonumber(symbol) and symbol or "")
	if not checkNick(nick) then
		nick = "invalid" .. math.random(1, 100)
	end

	local o = {		
		nick = nick;
		username = data.username or "lua";
		realname = data.realname or "Lua owns";
		nickGenerator = data.nickGenerator or defaultNickGenerator;
		hooks = {};
		track_users = true;
	}
	return setmetatable(o, meta_preconnect)
end

function meta:hook(name, id, f)
	f = f or id
	self.hooks[name] = self.hooks[name] or {}
	self.hooks[name][id] = f
	return id or f
end
meta_preconnect.hook = meta.hook


function meta:unhook(name, id)
	local hooks = self.hooks[name]

	assert(hooks, "no hooks exist for this event")
	assert(hooks[id], "hook ID not found")

	hooks[id] = nil
end
meta_preconnect.unhook = meta.unhook

function meta:invoke(name, ...)
	local hooks = self.hooks[name]
	if hooks then
		for id,f in pairs(hooks) do
			if f(...) then
				return true
			end
		end
	end
end

function meta_preconnect:connect(_host, _port)
	lua_thread.create(function()
		meta.__Status = "Preconnect"
		local host, port, password, secure, timeout

		if type(_host) == "table" then
			host = _host.host
			port = _host.port
			timeout = _host.timeout
			password = _host.password
			secure = _host.secure
		else
			host = _host
			port = _port
		end

		host = host or error("host name required to connect", 2)
		port = port or 6667

		local s = socket.tcp()

	 	s:settimeout(timeout or 30)
		assert(s:connect(host, port))

		if secure then
			local work, ssl = pcall(require, "ssl")
			if not work then
				error("LuaSec required for secure connections", 2)
			end

			local params
			if type(secure) == "table" then
				params = secure
			else
				params = {mode = "client", protocol = "tlsv1"}
			end

			s = ssl.wrap(s, params)
			success, errmsg = s:dohandshake()
			if not success then
				error(("could not make secure connection: %s"):format(errmsg), 2)
			end
		end

		self.socket = s
		setmetatable(self, meta)

		self:send("CAP REQ multi-prefix")

		self:invoke("PreRegister", self)
		self:send("CAP END")

		if password then
			self:send("PASS %s", password)
		end

		self:send("NICK %s", self.nick)
		self:send("USER %s 0 * :%s", self.username, self.realname)

		self.channels = {}

		s:settimeout(0)

		repeat
			wait(0)
			self:think()
		until self.authed
		--socket.select(nil, nil, 0.1)

		wait(500)
		meta.__isConnected = true
		meta.__Status = "Connecting"
	end)
end

function meta:prepart(host)	
	self:part(assert(host))
	meta.__isJoined = false
end

function meta:prejoin(host, key)	
	self:join(assert(host), key)
	meta.__isJoined = true
end

function meta:disconnect(message)
	meta.__Status = "Predisconnect"
	message = message or "Bye!"

	self:invoke("OnDisconnect", message, false)
	self:send("QUIT :%s", message)
	
	self:shutdown()	
	meta.__Status = "Disconnecting"
end

function meta:shutdown()
	meta.__isJoined = false
	meta.__isConnected = false
	self.socket:close()
	setmetatable(self, nil)
end

local function getline(self, errlevel)
	local line, err = self.socket:receive("*l")

	if not line and err ~= "timeout" and err ~= "wantread" then
		meta.__Status = "Timeout exceeded"
		sampfuncsLog(meta.__Prefix .. 'Превышено время ожидания (2 мин).', -1)
		self:shutdown()
	end

	return line
end

function meta:think()
	while true do
		local line = getline(self, 3)
		if line and #line > 0 then
			if not self:invoke("OnRaw", line) then
				self:handle(parse(line))
			end
		else
			break
		end
	end
end

local handlers = handlers

function meta:handle(prefix, cmd, params)
	if cmd ~= "ERROR" then
		local handler = handlers[cmd]
		if handler then
			return handler(self, prefix, unpack(params))
		end
	else
		meta.__isConnected = false
		meta.__isJoined = false
		meta.__Status = "Connecting error"
		sampfuncsLog(meta.__Prefix..meta.__Status, -1)
	end
end

local whoisHandlers = {
	["311"] = "userinfo";
	["312"] = "node";
	["319"] = "channels";
	["330"] = "account"; -- Freenode
	["307"] = "registered"; -- Unreal
}

function meta:whois(nick)
	self:send("WHOIS %s", nick)

	local result = {}

	while true do
		local line = getline(self, 3)
		if line then
			local prefix, cmd, args = parse(line)

			local handler = whoisHandlers[cmd]
			if handler then
				result[handler] = args
			elseif cmd == "318" then
				break
			else
				self:handle(prefix, cmd, args)
			end
		end
	end

	if result.account then
		result.account = result.account[3]
	elseif result.registered then
		result.account = result.registered[2]
	end

	return result
end

function meta:topic(channel)
	self:send("TOPIC %s", channel)
end

return meta