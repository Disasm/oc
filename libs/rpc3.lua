local component = require("component")
local serialization = require("serialization")
local event = require("event")
local modem = component.modem

local local_address = modem.address

local default_options = {
  request_port = 111,
  response_port = 112,
  timeout = 5,
  retries = 4,
  ping_timeout = 1,
  ping_mode = "ping_always"
}

local function defaultize_options(options)
  local r = {}
  for key, val in pairs(default_options) do
    r[key] = options[key] or default_options[key]
  end
  return r
end

local rpc = {}

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
      return table.unpack(serialization.unserialize(tostring(r[6])))
    else
      nretry = nretry + 1
      if nretry > retries then
        break
      end
      -- resend
      make_send()
    end
  end
  return false, "RPC transaction failed"
end

local function rpc.connect(address, options)
  local final_options = defaultize_options(options)
  modem.open(options.response_port)

  local make_ping()
    local val = 1
    local is_ok, result = perform_rpc_request(address, final_options, { action = "ping", args = { 1 = val } })
    if not is_ok then
      error("Ping failed: "..result)
    end
    if type(result) ~= "table" then
      error("Ping failed: result is not a table")
    end
    if result[1] ~= val then
      error("Ping failed: invalid result")
    end
  end

  local make_call(function_id, args)
    local is_ok, result = perform_rpc_request(address, final_options, { action = "call", args = args })
    if is_ok then
      return result
    else
      error("Remote error: "..result)
    end
  end

  local function rewrap_object(obj)
    if type(obj) == "table" then
      if obj.__rpc and obj.__rpc.function_id then
        return function(...)
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


  local is_ok, wrapper = perform_rpc_request(address, final_options, { action = "connect" })
  if not is_ok then
    error("Connect failed: "..wrapper)
  end
  return rewrap_object(wrapper)

end

local function rpc.bind(obj, options)
  if type(obj) ~= "table" then
    error("rpc.bind supports tables only", 1)
  end
  local final_options = defaultize_options(options)
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
      modem.send(packet_remote_address, bound_object.__rpc.options.response_port, is_ok, data)
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
      local is_ok, data = pcall(func, table.unpack(request_data.args))
      respond(is_ok, serialization.serialize(data))
    end
  end
  event.listen("modem_message", on_modem_message)
  return true
end

return rpc
