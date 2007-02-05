-----------------------------------------------------------------------------
-- POP3 support for the Lua language.
-- 
-- Module: Messages
-- Author: Guilherme Martins
-- Conforming to: RFC 1939
-----------------------------------------------------------------------------
local Private,Public = {}, {}

messages = Public

--Debug option
Private.DEBUG = false


local function debug(...)
	if Private.DEBUG then print("LUAPOP3 DEBUG : ",unpack(arg)) end
end


-----------
-- function : getParsedMessage(msg,resp)
--
-- Parses the message and returns a mesage object
--
------------------------------------------------------
function Public.getParsedMessage(body)
	local msg = {}
	Private.fillProperties(msg,body)
	return msg
end

-------------
-- function : fillProperties(msg,body)
--
-- Gets the message attributes from resp and add to 
-- the message as properties
--
-- Returns the message
--------------------------
function Private.fillProperties(msg,body)
	local bodyStr
	-- Creates the message string from the body
	if type(body) == "table" then
		bodyStr = table.concat(body,"\n");
	else
		bodyStr = tostring(body)
	end
	msg.all = bodyStr
	message_s = string.gsub(bodyStr, "^.-\n", "")
   
    local_, _, header, bodyPart = string.find(message_s, "^(.-\n)\n(.*)")	
	
	-- Code history
	--local _,_,header, bodyPart = string.find(bodyStr.."\n","(.-\n)\n(.*)")
	
	msg.header = Private.headers(header)
	msg.body = Private.fillMessageParts(msg,bodyPart)
	
	-- Code history
	--msg.attchment = Private.fillMessageAttchments(msg,bodyPart)	
	--Private.fillHeaderProperties(msg,header)

end

-------------------
-- function: headers(header)
-- Parse the headers attributes to a table
--
-- Returns a table with the header like properties
--
-- Coded by Diego Nehab
--
-- Modified by Guilherme Martins
--------------------------------------------------------------
function Private.headers(headers_s)
    local headers = {}
    headers_s = "\n" .. tostring(headers_s) .. "$$$:\n"
    local i, j = 1, 1
    local name, value, _
    while 1 do
        j = string.find(headers_s, "\n%S-:", i+1)
        if not j then break end
        _, _, name, value = string.find(string.sub(headers_s, i+1, j-1), "(%S-):(.*)")
        value = string.gsub(value or "", "\r\n", "\n")
        value = string.gsub(value, "\n%s*", " ")
        name = string.lower(name)
        if headers[name] then headers[name] = headers[name] .. ", " ..  value
        else headers[name] = value end
        i, j = j, i
    end
    headers["$$$"] = nil
    return headers
end

-------------------------
-- function : fillMessageParts(msg,body)
--
-- Create a message body depending from the content-type
-- if the message is multipart, returns a table with the parts 
-- else returns a table with a single text part
--
-----------------------------------------------------------------------
function Private.fillMessageParts(msg,body)
 local result = {}
 local content = msg.header["content-type"] or ""
 
 --find the content type from the header property
 local_,_,content,atts = string.find(content,"([%w/]*)%s*;%s*(.*)")

 -- if don�t have this attribute, uses text/plain
 content = content or "text/plain"
 atts = atts or "" 
 
 debug(content)
 debug(atts)
 
 -- Checks for multpart main type or text
 local slashIndex = string.find(content,"/")
 
 
 if string.lower(content) == "text/plain" then
 	--pure text case
 	return {body}
 	
 elseif string.lower(string.sub(content,1,slashIndex-1)) == "multipart" then
 	--Multipart case
 	local boundary
 	-- get the parts boundary from the header	
 	for key,value in string.gfind(atts,"(%w*)=[\"]?([%w-_=.%s]*)") do
		if string.lower(key) == "boundary" then
			boundary = value
			break;
		end
		boundary = ""		
	end
	
	debug("BOUNDARY = ",boundary)
	
	-- if the boundary was not founded throws a error
	if boundary == "" then return error("No message part boundary found for multipart mail message!") end
	
	-- get the last boundary index
	local _,endpart = string.find(body,"--"..boundary.."--")
	
	
	if endpart then
	   local s,e = string.find(body,"--"..boundary,1)
		 		
	 -- mount the parts
	   while true do
		    local firstIndex,last2index = string.find(body,"--"..boundary,e)
		    if not firstIndex then break; end	 		
	 		local part = string.sub(body,e+1,firstIndex-1)
	 		part = Private.getParsedPart(part)
	 		debug("PART",part)
	 		table.insert(result,part)
	 		s,e = firstIndex , last2index
	 	end
 		return result
 	end
 else
 	return {body}
 end
 
end

---------------------
--function : getParsedPart
--
-- Gets the message Part parsed as a table with a pheader
-- property thats represent the part headers and a pcontent
-- that represent the body part
--
-- Returns the message Part
----------------------------------
function Private.getParsedPart(part) 
	local result = {}
   part_s = string.gsub(part, "^.-\n", "")
   
   local_, _, header, bodyPart = string.find(part_s, "^(.-\n)\n(.*)")
   result.pheader =  Private.headers(header)
   result.pcontent=string.sub(bodyPart,1,string.len(bodyPart)-1)   
   
 return result

end