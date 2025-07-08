-- Read Github files with <ENV>, <JSON> support. To get all Content Types, set <content_type> as 'ctypes'. // Made by @v21es.
local read_url=function(url:string,content_type:string?)
	content_type=content_type or 'raw'
	assert(url~=nil,'URL Not specified or nil.')
	
	local http=game:GetService('HttpService')
	
	local replace={
		["\\u003c"]='<',
		["\\u0026"]='&',
		["\\u003e"]='>',
		['\\\\']='\\',
		['\\"']='"'
	}
	
	local success, raw_response=pcall(function()
		return http:GetAsync(url,true)
	end)
	
	if not success then print('?ERROR: '..raw_response);return error end
	
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
	
	local ctypes={} -- Return by content type
	ctypes.ctypes=function()
		local list={}
		for i, v in ctypes do
			table.insert(list,i)
		end
		return list
	end
	ctypes.raw=function()
		return response
	end
	
	ctypes.json=function()
		response=http:JSONDecode(response)
		return response
	end
	
	ctypes.env=function()
		local env={}
		for i, v in string.split(response,'\n') do
			local name=string.split(v,'=')[1]
			local value=string.split(v,'=')[2]
			env[name]=value
		end
		return env
	end
	
	local success, ctype_response=pcall(function()
		return ctypes[content_type]()
	end)
	
	if not success then
		if string.find(ctype_response,'attempt to call a nil value') then
			warn('?ERROR: Content type "'..tostring(content_type)..'" is not valid or encountered an error.')
			return error
		else
			error(ctype_response)
		end
	end
	
	return ctype_response
end
