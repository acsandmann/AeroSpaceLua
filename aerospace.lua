--- aerospace module for sending commands to the AeroSpace window manager server
-- @module Aerospace
-- @copyright 2025
-- @license MIT

local socket               = require("posix.sys.socket")
local unistd               = require("posix.unistd")
local cjson                = require("cjson")
local simdjson             = require("simdjson")

local DEFAULT              = {
	SOCK_FMT = "/tmp/bobko.aerospace-%s.sock",
	MAX_BUF  = 2048,
	EXT_BUF  = 4096,
}
local ERR                  = {
	SOCKET   = "socket error",
	NOT_INIT = "socket not connected",
	JSON     = "failed to decode JSON",
}

local AF_UNIX, SOCK_STREAM = socket.AF_UNIX, socket.SOCK_STREAM
local write, read, close   = unistd.write, unistd.read, unistd.close
local encode               = cjson.encode

local use_simd             = true
local function decode(str)
	if use_simd then
		local ok, val = pcall(simdjson.parse, str)
		if ok then return val end
		use_simd = false
	end
	local ok, val = pcall(cjson.decode, str)
	if not ok then error(ERR.JSON .. ": " .. tostring(val)) end
	return val
end

local function connect(path)
	local fd, err = socket.socket(AF_UNIX, SOCK_STREAM, 0)
	if not fd then error(ERR.SOCKET .. ": " .. tostring(err)) end
	if socket.connect(fd, { family = AF_UNIX, path = path }) ~= 0 then
		close(fd); error("cannot connect to " .. path)
	end
	return fd
end

local function stdout(raw)
	local ok, doc = pcall(simdjson.open, raw)
	if not ok then error(ERR.JSON .. ": " .. tostring(doc)) end
	return doc:atPointer("/stdout")
end

local Aerospace = {}; Aerospace.__index = Aerospace

function Aerospace.new(path)
	if not path then
		local username = io.popen("id -un"):read("*l")
		path = DEFAULT.SOCKET_PATH_REG:format(username)
	end

	return setmetatable({ sockPath = path, fd = connect(path) }, Aerospace)
end

function Aerospace:close()
	if self.fd then
		close(self.fd); self.fd = nil
	end
end

Aerospace.__gc = Aerospace.close

function Aerospace:reconnect()
	self:close(); self.fd = connect(self.sockPath)
end

function Aerospace:is_initialized() return self.fd ~= nil end

local PAYLOAD_TMPL = '{"command":"","args":%s,"stdin":""}\n'
function Aerospace:_query(args, want_json, big)
	if not self:is_initialized() then error(ERR.NOT_INIT) end
	local payload = PAYLOAD_TMPL:format(encode(args))
	write(self.fd, payload)

	-- Read all available data from socket in chunks
    local chunks = {}
    local chunk_size = big and DEFAULT.EXT_BUF or DEFAULT.MAX_BUF
    repeat
        local chunk = read(self.fd, chunk_size)
        if chunk and #chunk > 0 then
            table.insert(chunks, chunk)
        else
            break
        end
    until #chunk < chunk_size  -- Stop when we get a partial chunk (last chunk)

    local raw = table.concat(chunks)
	local out = stdout(raw)
	return want_json and decode(out) or out
end

local function passthrough(self, argtbl, json, big, cb)
	local res = self:_query(argtbl, json, big)
	return cb and cb(res) or res
end

function Aerospace:list_apps(cb)
	return passthrough(self, { "list-apps", "--json" }, true, nil, cb)
end

function Aerospace:query_workspaces(cb)
	return passthrough(self, {
		"list-workspaces", "--all",
		"--format", "%{workspace-is-focused}%{workspace-is-visible}%{workspace}%{monitor-appkit-nsscreen-screens-id}",
		"--json" }, true, true, cb)
end

function Aerospace:list_current(cb)
	return passthrough(self, { "list-workspaces", "--focused" }, false, nil, cb)
end

function Aerospace:list_windows(space, cb)
	return passthrough(self, { "list-windows", "--workspace", space, "--json" }, false, nil, cb)
end

function Aerospace:focused_window(cb)
	return passthrough(self, { "list-windows", "--focused", "--json" }, false, nil, cb)
end

function Aerospace:workspace(ws)
	return self:_query({ "workspace", ws }, false)
end

function Aerospace:list_all_windows(cb)
	return passthrough(self, {
		"list-windows", "--all", "--json",
		"--format", "%{window-id}%{app-name}%{window-title}%{workspace}" }, true, true, cb)
end

return Aerospace
