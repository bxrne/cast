-- Minimal JSON decoder for the static data files. Objects,
-- arrays, strings with escapes, numbers, true, false, null.
-- Not a validator. Malformed input errors.
local json = {}

local function skip(s, i)
	while true do
		local c = s:sub(i, i)
		if c == " " or c == "\t" or c == "\n" or c == "\r" then
			i = i + 1
		else
			return i
		end
	end
end

local parse_value

local escapes = {
	['"'] = '"', ["\\"] = "\\", ["/"] = "/",
	b = "\b", f = "\f", n = "\n", r = "\r", t = "\t",
}

local function parse_string(s, i)
	i = i + 1
	local out = {}
	while true do
		local c = s:sub(i, i)
		if c == "" then
			error("json: unterminated string")
		end
		if c == '"' then
			return table.concat(out), i + 1
		end
		if c == "\\" then
			local e = s:sub(i + 1, i + 1)
			if e == "u" then
				local n = tonumber(s:sub(i + 2, i + 5), 16)
				if not n then
					error("json: bad unicode escape")
				end
				out[#out + 1] = string.char(n)
				i = i + 6
			else
				local r = escapes[e]
				if not r then
					error("json: bad escape \\" .. e)
				end
				out[#out + 1] = r
				i = i + 2
			end
		else
			out[#out + 1] = c
			i = i + 1
		end
	end
end

local function parse_number(s, i)
	local num = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", i)
	local v = tonumber(num)
	if not v then
		error("json: bad number")
	end
	return v, i + #num
end

local function parse_array(s, i)
	i = i + 1
	local out = {}
	i = skip(s, i)
	if s:sub(i, i) == "]" then
		return out, i + 1
	end
	while true do
		local v
		v, i = parse_value(s, i)
		out[#out + 1] = v
		i = skip(s, i)
		local c = s:sub(i, i)
		if c == "," then
			i = skip(s, i + 1)
		elseif c == "]" then
			return out, i + 1
		else
			error("json: expected , or ]")
		end
	end
end

local function parse_object(s, i)
	i = i + 1
	local out = {}
	i = skip(s, i)
	if s:sub(i, i) == "}" then
		return out, i + 1
	end
	while true do
		i = skip(s, i)
		if s:sub(i, i) ~= '"' then
			error("json: expected string key")
		end
		local k
		k, i = parse_string(s, i)
		i = skip(s, i)
		if s:sub(i, i) ~= ":" then
			error("json: expected :")
		end
		local v
		v, i = parse_value(s, skip(s, i + 1))
		out[k] = v
		i = skip(s, i)
		local c = s:sub(i, i)
		if c == "," then
			i = i + 1
		elseif c == "}" then
			return out, i + 1
		else
			error("json: expected , or }")
		end
	end
end

parse_value = function(s, i)
	i = skip(s, i)
	local c = s:sub(i, i)
	if c == "{" then
		return parse_object(s, i)
	end
	if c == "[" then
		return parse_array(s, i)
	end
	if c == '"' then
		return parse_string(s, i)
	end
	if c == "t" and s:sub(i, i + 3) == "true" then
		return true, i + 4
	end
	if c == "f" and s:sub(i, i + 4) == "false" then
		return false, i + 5
	end
	if c == "n" and s:sub(i, i + 3) == "null" then
		return nil, i + 4
	end
	if c == "-" or c:match("%d") then
		return parse_number(s, i)
	end
	error("json: unexpected char at " .. i)
end

-- Decode one document. Errors on trailing data.
function json.decode(s)
	local v, i = parse_value(s, 1)
	i = skip(s, i)
	if i <= #s then
		error("json: trailing data")
	end
	return v
end

return json
