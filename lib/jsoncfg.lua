local jsoncfg = {}

function jsoncfg.read(path)
	if doesFileExist(path) then
		local f = io.open(path, 'a+')
		local data = decodeJson(f:read('*a'))
		f:close()
		return data
	else
		return {} -- empty data
	end
end

function jsoncfg.write(path, data)
	if doesFileExist(path) then
		os.remove(path) -- newbie double writing fix, but i think io.input fix it
	end

	if type(data) ~= 'table' then
		return
	end

	local f = io.open(path, 'a+')
	local writing_data = encodeJson(data)
	f:write(writing_data) -- new json data

	f:close()
end

return jsoncfg
