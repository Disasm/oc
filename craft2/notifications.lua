local event = require("event")
local component = require("component")
local nb
if component.isAvailable("iron_noteblock") then
  nb = component.iron_noteblock
end

local instrument = 5
local volume = 1

local function play_note(x)
  if nb then
    nb.playNote(instrument, x, volume)
  end
end

local notifications = {}

function notifications.play_major_chord(base, delay)
  play_note(base)
  event.timer(delay, function()
    play_note(base + 4)
    event.timer(delay, function()
      play_note(base + 7)
      event.timer(delay, function()
        play_note(base + 12)
      end)
    end)
  end)
end

function notifications.play_minor_chord(base, delay)
  play_note(base + 12)
  event.timer(delay, function()
    play_note(base + 7)
    event.timer(delay, function()
      play_note(base + 3)
      event.timer(delay, function()
        play_note(base)
      end)
    end)
  end)
end

return notifications
