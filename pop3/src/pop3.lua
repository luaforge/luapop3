-----------------------------------------------------------------------------
-- POP3 support for the Lua language.
-- 
-- Author: Guilherme Martins
-- Conforming to: RFC 1939
-----------------------------------------------------------------------------
require"message"

local Public, Private = {}, {}

_G.pop3 = Public
--- Timeout in seconds before the program gives up on a connection.
Private.TIMEOUT = 60
--- default port for pop3 service.
Private.PORT = 110
--Debug option
Private.DEBUG = false


local function debug(...)
	if Private.DEBUG then print(unpack(arg)) end
end
---------------------------
-- 
-- function : cmd(conn,command,params) 
--
-- Sends a command to the pop3 server
--
-- Return the response of this command
---------------------------------------------------
function Private.cmd(conn,command, params)
	
	local popMsg
	
	-- Checks for a previous connection
	if not conn then error("No POP3 Client Connection.") end
	
	--creates the message that will be sent to server
	if params then		
		if type(params)=='table' then
			popMsg = command .. " " .. table.concat(params," ")
		elseif type(params)=='string' then
			popMsg = command .. " " .. params
		else
			error("Invalid Parameter Type to compile a POP3 Command")
		end
	else
		popMsg = command
	end
	
	popMsg = popMsg .. "\r\n"
	
	debug("POP3 REQUEST", popMsg )
	
	-- send the command
    local ok, errMsg = conn:send(popMsg)
    
    -- in case of erro close the connection and throw a error
    if not ok then conn:close() end
	if errMsg then error(errMsg) end
	
	-- returns the response
	return Private.getResponse(conn)
end


---------------------------------
-- function : geResponse(client)
--
-- Get the server Response for any command
--
-- Returns the response string
--------------------------------------------------
function Private.getResponse(client)
	local resp, errMsg = client:receive()
    if not resp then client:close();error(errMsg); end

    debug("POP3 RESPONSE : ",resp)
   	
   	local __,__,code, info = string.find(resp,"(+OK)(.*)") 
	
	debug(code,info)
	if code == "+OK"  then
		return code, info
	elseif code == "-ERR" then
		return nil , info
	elseif not code then
		return nil , resp
	end
	debug("Return CODE : " , code)
	client:close()
	error(resp)

end

---------------------------
-- 
-- function : conn(_,conf)
-- 
-- Start a pop3 server connection and pass 
-- to the transaction state
--
-- Needs conf.user,conf.pass,conf.host
--
-- Returns a pop3client instance
-------------------------------
function Private.conn(_,conf)
		local pop3Client = setmetatable(Public,{__index = Private})
		--check for socket module
		if not socket then error("Socket module required as 'socket'.")end
		
		--connect to the pop3 server
		pop3Client.client , errMsg = socket.connect(conf.host,Private.PORT)		
		if not pop3Client.client then error(errMsg)end
		--settimeout
		pop3Client.client:settimeout(Private.TIMEOUT)
		
		-- get the Server Welcome response
		-- don´t need this
		Private.getResponse(pop3Client.client)
		
		local code , resp
		-- Noop Server
		code , resp = Private.cmd(pop3Client.client,"NOOP")
		if code == "-ERR" then error(resp) end
		
		--AUTHORIZATION STATE
		if not secure then 
			-- non secure authetication with plain password
			code , resp = Private.cmd(pop3Client.client,"USER",conf.user)
			if code == "-ERR" then error(resp) end
			code , resp = Private.cmd(pop3Client.client,"PASS",conf.pass)
			if code == "-ERR" then error(resp) end
		else
			-- secure password md5 hash
			code , resp = Private.cmd(pop3Client.client,"APOP",{conf.user,conf.pass})
			if code == "-ERR" then error(resp) end
		end
		
		--Logged , end of AUTHORIZATION STATE
		debug("Welcome to " .. conf.host .. " pop3 server")
		
		return pop3Client
end

---------
-- function : mailinfo()
--
-- Returns the count of msgs and the total size of the maildrop
--
-------------------

function Public:mailinfo()
	
	-- Send the STAT Command
	local code , resp = Private.cmd(self.client,"STAT")
	
	--Check for ERRORS
	if code == "-ERR" then error(resp) end
	
	-- Parse the response
	_,_,numStr,sizeStr = string.find(resp,"(.*%s)(.*)")
	
	debug(numStr,sizeStr)
	
	--Conversion to number...
	return tonumber(numStr), tonumber(sizeStr)

end

-------------
-- function : messages()
--
-- Iterator to all server menssages, intent to be used like a iterator
-- 
-- Returns a function the iterate under the server messages
------------------------
function Public:messages()
	local c = 1
	local total, _ = self:mailinfo()
	
	return function ()
			if(c > total) then  return nil end
			msg = Private.getmessage(self.client,c)
			c=c+1
			return msg 
		end

end

-------
-- function : getmessage(num)
--
-- Gets the mensage that has a index 'num' at the maildrop
--
-- Returns the message Object
-------------------
function Private.getmessage(client,num)
	
	-- get message information
	local code , resp = Private.cmd(client,"LIST",tostring(num))
	
	if code == "-ERR" then return nil end
	
	_,_,_,sizeStr = string.find(resp,"(.*%s)(.*)")
	
	-- Sends the RERT command to the server
	local code , resp = Private.retr(client,num)
	-- parse the message
	local msg = messages.getParsedMessage(resp);
	
	-- set some properties as index id , size and uid
	msg.id   = num
	msg.size = tonumber(sizeStr)
	msg.uid  = Private.uid(client,num) 
		
	return msg

end

-------------
-- function : message(num)
-- 
-- Returns the message with  the index 'num'
---------------------------------------------

function Public:message(num)

	return Private.getmessage(self.client,num)

end


-------------------
-- function : retr(client, num)
--
-- Gets the message with index equals to 'num'
--
-----------------------------------------
function Private.retr(client,num)

	
	local code, resp = Private.cmd(client,"RETR", tostring(num))
	if code == "-ERR" then error(resp) end
	if code == "+OK" then
		local all = {}
		--for each line , use a table like a buffer
		local line = client:receive()
		while line ~= "." do
			table.insert(all, line)
			line = client:receive()	
		end
		return nil, all
	end
	return code, resp

	
end

----------------------
-- function : uid(num)
-- 
-- Gets the unique identifier to the message with index 'num'
--
-- Returns the identifier as a string or throw a error
-------------------------------------------------------------
function Private.uid(client,num)
	local code, resp = Private.cmd(client,"UIDL", tostring(num))
	if code == "-ERR" then error(resp) end
	if code == "+OK" then return resp end
end


----------------------
-- function : delete(num)
-- 
-- Deletes the message from the maildrop
--
-- Returns true if deleted or nil,errMsg
------------------------------------
function Public:delete(num)
	local code, resp = Private.cmd(self.client,"DELE", tostring(num))
	if code == "-ERR" then return nil, resp end
	if code == "+OK" then return true end
end

----------------------
-- function : quit()
--
-- Closes the server connection
--
---------------------------------------
function Public:quit()
	Private.cmd(self.client,"QUIT")
	Private.getResponse(self.client)
	self.client:close()
end

-- points pop3 call to conn
setmetatable (pop3, {__call = Private.conn})		
		
		
	
	

