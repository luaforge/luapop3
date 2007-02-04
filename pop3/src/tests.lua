------
-- TESTE of POP3 CLIENT
-- by Guilherme Martins
-----------------

require"pop3"
require"md5"

-----
--
--Connection to the server
---------
pop3Client = pop3{  host="mail.vbdf.net",
					user="luapop3@vbdf.net",
					pass = "luapop123"
				};

print("Total messages","Total Size")
print(pop3Client:mailinfo())


function printbody(a,b)
	--case of multipart message
	if type(b) == 'table' then
		print("---Part Header --")
	 	table.foreach(b.pheader ,print)
	 	print("---Part Content --")
	 	print(b.pcontent)
		print("-- End Part")
	else
		print("---Text Part --")
		print (b)
		print("---End Text Part --")
	end
end

for message in pop3Client:messages() do
		
	print("***********************************************************************")
	print("Message Id: " ..  message.id) -- Message id (to the pop3 server)
	print("Message Size: " ..message.size) -- Size in bytes
	print("Message Unique Id: " ..tostring(message.uid))
	print("Message Header: " ..tostring(message.header)) -- Table with fields that contain the header values
	--The header attributes is in lower case
	print("\tContent-Type: " ..tostring(message.header['content-type'])) 
	print("\tMime-Version: " ..tostring(message.header['mime-version'])) 
	print("\tContent-Transfer-Enconding: " .. tostring(message.header['content-transfer-encoding']))
	print("\tSubject: " .. tostring(message.header.subject))
	print("\tFrom: " .. tostring(message.header.from))
	print("\tTo: " .. tostring(message.header.to))
	print("\tDate: " .. tostring(message.header.date))
	print("\n")
	table.foreach(message.body,printbody)
	print("\n")
	
	print("####################################")
end

-- Can get a specific message
print( "Message 1" .. tostring(pop3Client:message(1)))
--You can delete message with this command
--pop3Client:delete(1)

--Closing server connection
pop3Client:quit()
