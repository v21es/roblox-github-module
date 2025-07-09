local git={}
git.version='1.1'
git.ctypes={}
git.ctypes.ctypes=function() local list={};for i, v in git.ctypes do table.insert(list,i);end;return list;end
git.ctypes.raw=function(response) return response;end
git.ctypes.json=function(response) local http=game:GetService('HttpService');response=http:JSONDecode(response);return response;end
git.ctypes.env=function(response) local env={};response=string.gsub(response,' //','//') for i, v in string.split(response,'\n') do local comment=string.find(v,'//');if comment then v=string.sub(v,0,comment-1) end;local name=string.split(v,'=')[1];if string.find(name,'//') or name=='' then continue end;local value=string.sub(v,string.len(name)+2,-1);env[name]=value end;return env;end

-- Read Public Github files with <ENV>, <JSON> support. URL Example: https://github.com/<name>/<repo>/blob/<branch>/<file_name>. To get all Content Types, set <content_type> as 'ctypes'. // Made by @v21es.
git.read_public_file=function(url:string,content_type:string?)
	content_type=content_type or 'raw'
	assert(url~=nil,'URL Not specified or nil.')

	local http=game:GetService('HttpService')

	local replace={
		["\\u003c"]='<',
		["\\u0026"]='&',
		["\\u003e"]='>',
		['\\\\']='\\',
		['\\"']='"',
		['\\t']='	'
	}

	local success, raw_response=pcall(function()
		return http:GetAsync(url,true)
	end)

	if not success then error('?ERROR: '..raw_response);return error end

	local response=string.split(raw_response,'rawLines":[')[2]
	local response=string.split(string.gsub(response,'\\"]','#__$QSB__'),'"]')[1]
	local response=string.gsub(response,'#__$QSB__','\"]')
	local response=string.gsub(response,'","','\n')	
	local response=string.sub(response,2,-1)
	for name, value in replace do
		response=string.gsub(response,name,value)
	end

	local tag=function(t)
		return string.sub(response,1,string.len(t))==t
	end

	local success, ctype_response=pcall(function()
		return git.ctypes[content_type](response)
	end)

	if not success then
		if string.find(ctype_response,'attempt to call a nil value') then
			error('?ERROR: Content type "'..tostring(content_type)..'" is not valid or encountered an error.')
			return error
		else
			error(ctype_response)
		end
	end

	return ctype_response
end

-- Read Private/Public Github files with <ENV>, <JSON> support. URL Example: https://api.github.com/repos/<name>/<repo>/contents/<file_name>. To get all Content Types, set <content_type> as 'ctypes'. // Made by @v21es.
git.read_file=function(token,url,content_type:string?)
	content_type=content_type or 'raw'
	local http=game:GetService('HttpService')

	local headers = {
		["Authorization"]="Bearer "..token,
		["Accept"]="application/vnd.github.v3+json"
	}
	local response = http:GetAsync(url,true,headers)
	local response=http:JSONDecode(response)
	local content=git.base64.decode(response.content)

	local success, ctype_response=pcall(function()
		return git.ctypes[content_type](content)
	end)

	return ctype_response
end

-- Set Github file content using a Fine-Grained Token. // Made by @v21es.
git.set_file=function(token,url,content)
	local http=game:GetService('HttpService')
	local encoded_content = git.base64.encode(content)

	local headers = {
		["Authorization"]="token "..token,
		["Accept"]="application/vnd.github.v3+json"
	}
	local preinfo = http:GetAsync(url,true,headers)
	local preinfo=http:JSONDecode(preinfo)

	local data={
		message='update file via .lua',
		content=encoded_content,
		sha=preinfo.sha
	}
	local data=http:JSONEncode(data)

	local response=http:RequestAsync({
		Url=url,
		Method="PUT",
		Headers=headers,
		Body=data
	})
	local response=http:JSONDecode(response)
	return response
end

git.base64 = {}

local extract = function( v, from, width )
	local w = 0
	local flag = 2^from
	for i = 0, width-1 do
		local flag2 = flag + flag
		if v % flag2 >= flag then
			w = w + 2^i
		end
		flag = flag2
	end
	return w
end

-- Credit @iskolbin on Github for base64 encoder/decoder on lua.
function git.base64.makeencoder( s62, s63, spad )
	local encoder = {}
	for b64code, char in pairs{[0]='A','B','C','D','E','F','G','H','I','J',
		'K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y',
		'Z','a','b','c','d','e','f','g','h','i','j','k','l','m','n',
		'o','p','q','r','s','t','u','v','w','x','y','z','0','1','2',
		'3','4','5','6','7','8','9',s62 or '+',s63 or'/',spad or'='} do
		encoder[b64code] = char:byte()
	end
	return encoder
end

-- Credit @iskolbin on Github for base64 encoder/decoder on lua.
function git.base64.makedecoder( s62, s63, spad )
	local decoder = {}
	for b64code, charcode in pairs( git.base64.makeencoder( s62, s63, spad )) do
		decoder[charcode] = b64code
	end
	return decoder
end

local DEFAULT_ENCODER = git.base64.makeencoder()
local DEFAULT_DECODER = git.base64.makedecoder()

local char, concat = string.char, table.concat

-- Credit @iskolbin on Github for base64 encoder/decoder on lua.
function git.base64.encode( str, encoder, usecaching )
	encoder = encoder or DEFAULT_ENCODER
	local t, k, n = {}, 1, #str
	local lastn = n % 3
	local cache = {}
	for i = 1, n-lastn, 3 do
		local a, b, c = str:byte( i, i+2 )
		local v = a*0x10000 + b*0x100 + c
		local s
		if usecaching then
			s = cache[v]
			if not s then
				s = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[extract(v,6,6)], encoder[extract(v,0,6)])
				cache[v] = s
			end
		else
			s = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[extract(v,6,6)], encoder[extract(v,0,6)])
		end
		t[k] = s
		k = k + 1
	end
	if lastn == 2 then
		local a, b = str:byte( n-1, n )
		local v = a*0x10000 + b*0x100
		t[k] = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[extract(v,6,6)], encoder[64])
	elseif lastn == 1 then
		local v = str:byte( n )*0x10000
		t[k] = char(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[64], encoder[64])
	end
	return concat( t )
end

-- Credit @iskolbin on Github for base64 encoder/decoder on lua.
function git.base64.decode( b64, decoder, usecaching )
	decoder = decoder or DEFAULT_DECODER
	local pattern = '[^%w%+%/%=]'
	if decoder then
		local s62, s63
		for charcode, b64code in pairs( decoder ) do
			if b64code == 62 then s62 = charcode
			elseif b64code == 63 then s63 = charcode
			end
		end
		pattern = ('[^%%w%%%s%%%s%%=]'):format( char(s62), char(s63) )
	end
	b64 = b64:gsub( pattern, '' )
	local cache = usecaching and {}
	local t, k = {}, 1
	local n = #b64
	local padding = b64:sub(-2) == '==' and 2 or b64:sub(-1) == '=' and 1 or 0
	for i = 1, padding > 0 and n-4 or n, 4 do
		local a, b, c, d = b64:byte( i, i+3 )
		local s
		if usecaching then
			local v0 = a*0x1000000 + b*0x10000 + c*0x100 + d
			s = cache[v0]
			if not s then
				local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40 + decoder[d]
				s = char( extract(v,16,8), extract(v,8,8), extract(v,0,8))
				cache[v0] = s
			end
		else
			local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40 + decoder[d]
			s = char( extract(v,16,8), extract(v,8,8), extract(v,0,8))
		end
		t[k] = s
		k = k + 1
	end
	if padding == 1 then
		local a, b, c = b64:byte( n-3, n-1 )
		local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40
		t[k] = char( extract(v,16,8), extract(v,8,8))
	elseif padding == 2 then
		local a, b = b64:byte( n-3, n-2 )
		local v = decoder[a]*0x40000 + decoder[b]*0x1000
		t[k] = char( extract(v,16,8))
	end
	return concat( t )
end

return git
