local keyboard = require("keyboard")
local event = require("event")
local term = require("term")
local text = require("text")
local unicode = require("unicode")

local input = {}

function input.waitForEnter()
    while true do
        local e, addr, ch, code, player = event.pull("key_down")
        if code == keyboard.keys.enter then
            break
        end
    end
end

function input.waitYesNo()
    while true do
        local e, addr, ch, code, player = event.pull("key_down")
        ch = unicode.char(ch)
        if ch == 'y' then
            return 'y'
        end
        if ch == 'n' then
            return 'n'
        end
    end
end

function input.getString()
    return text.trim(term.read());
end

function input.getChar()
    local e, addr, ch, code, player = event.pull("key_down")
    return unicode.char(ch) 
end

function input.getNumber()
    while true do
        local s = term.read();
        if s == nil then
            return nil
        end
        
        s = text.trim(s);
        if s == "" then
            return nil
        end

        local v = tonumber(text.trim(s))
        if v == nil then
            print("Invalid number. Enter another one.");
        else
            return v;
        end
    end
end

return input
