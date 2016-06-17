local component = require("component")
local serialization = require("serialization")
local event = require("event")
if not component.isAvailable("modem") then
  return { is_available = false, message = 'No modem available.' }
end
local modem = component.modem

local local_address = modem.address

local rpc = { is_available = true }
rpc.PING_MODE = { ALWAYS = 1, ON_CONNECT = 2, NEVER = 0 }

local default_options = {
  request_port = 111,
  response_port = 112,
  timeout = 5,
  retries = 0,
  ping_timeout = 1,
  ping_mode = rpc.PING_MODE.ON_CONNECT,
  ping_count = 3
}

local busy_request_ports = {}
local busy_response_ports = {}

local function defaultize_options(options)
  options = options or {}
  local r = {}
  for key, val in pairs(default_options) do
    r[key] = options[key] or default_options[key]
  end
  return r
end


local function perform_rpc_request(remote_address, options, payload)
  local request = serialization.serialize(payload)
  local function make_send()
    modem.send(remote_address, options.request_port, request)
  end
  local timeout_per_retry = options.timeout / (options.retries + 1)
  local nretry = 0
  make_send()
  while true do
    local r = table.pack(event.pull(timeout_per_retry, "modem_message", local_address, remote_address, options.response_port))
    if r.n > 0 then
      return r[6], serialization.unserialize(r[7])
    else
      nretry = nretry + 1
      if nretry > options.retries then
        break
      end
      -- resend
      make_send()
    end
  end
  return false, "RPC transaction failed"
end

function rpc.connect(address, options)
  local final_options = defaultize_options(options)
  modem.open(final_options.response_port)

  local function make_ping()
    for val = 1, final_options.ping_count do
      local is_ok, result = perform_rpc_request(address, final_options, { action = "ping", args = { val } })
      if not is_ok then
        error("Ping failed: "..tostring(result))
      end
      if type(result) ~= "table" then
        error("Ping failed: result is not a table")
      end
      if result[1] ~= val then
        error("Ping failed: invalid result")
      end
    end
  end

  local function make_call(function_id, args)
    local is_ok, result = perform_rpc_request(address, final_options, { action = "call", args = args, function_id = function_id })
    if is_ok then
      return table.unpack(result)
    else
      error("Remote error: "..result)
    end
  end

  local function rewrap_object(obj)
    if type(obj) == "table" then
      if obj.__rpc and obj.__rpc.function_id then
        return function(...)
          if final_options.ping_mode == rpc.PING_MODE.ALWAYS then
            make_ping()
          end
          return make_call(obj.__rpc.function_id, {...})
        end
      else
        local r = {}
        for key, val in pairs(obj) do
          r[key] = rewrap_object(val)
        end
        return r
      end
    else
      return obj
    end
  end

  if final_options.ping_mode ~= rpc.PING_MODE.NEVER then
    make_ping()
  end

  local is_ok, wrapper = perform_rpc_request(address, final_options, { action = "connect" })
  if not is_ok then
    error("Connect failed: "..wrapper)
  end
  return rewrap_object(wrapper)


end

function rpc.bind(obj, options)
  if type(obj) ~= "table" then
    error("rpc.bind supports tables only", 1)
  end
  local final_options = defaultize_options(options)
  if busy_request_ports[final_options.request_port] or busy_response_ports[final_options.response_port] then
    print("rpc.bind: port is busy.")
    return false
  end
  busy_request_ports[final_options.request_port] = true
  busy_response_ports[final_options.response_port] = true
  modem.open(final_options.request_port)
  local bound_functions = {}
  local function convert_to_bound_object(value)
    local value_type = type(value)
    if value_type == "boolean" or value_type == "number" or value_type == "string" or value_type == "nil" then
      return value
    elseif value_type == "function" then
      table.insert(bound_functions, value)
      return {
        __rpc = {
          function_id = #bound_functions
        }
      }
    elseif value_type == "table" then
      local r = {}
      for key, val in pairs(value) do
        r[key] = convert_to_bound_object(val)
      end
      return r
    else
      error("Unsupported value type encountered: "..value_type, 1)
    end
  end
  local bound_object = convert_to_bound_object(obj)
  bound_object.__rpc = { options = final_options }

  local function on_modem_message(packet_signal, packet_local_address, packet_remote_address, packet_port, packet_distance, payload)
    if (packet_local_address ~= local_address) or (packet_port ~= bound_object.__rpc.options.request_port) then
      return
    end
    local function respond(is_ok, data)
      modem.send(packet_remote_address, bound_object.__rpc.options.response_port, is_ok, serialization.serialize(data))
    end
    if type(payload) ~= "string" then
      respond(false, string.format("request type is %s (string expected)", type(payload)))
      return
    end
    local request_data = serialization.unserialize(payload)
    if type(request_data) ~= "table" then
      respond(false, string.format("unserialized request type is %s (table expected)", type(request_data)))
      return
    end
    if request_data.action == "ping" then
      respond(true, request_data.args)
    elseif request_data.action == "connect" then
      respond(true, bound_object)
    elseif request_data.action == "call" then
      local func = bound_functions[request_data.function_id]
      local data = table.pack(pcall(func, table.unpack(request_data.args)))
      local is_ok = data[1]
      if is_ok then
        table.remove(data, 1)
        data.n = data.n - 1
      else
        data = data[2] -- error message only
      end
      respond(is_ok, data)
    end
  end
  event.listen("modem_message", on_modem_message)
  if string.len(serialization.serialize(bound_object)) > 4096 then
    error("Bound object is too large")
  end
  return true
end

return rpc
