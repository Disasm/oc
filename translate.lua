file_serialization = require("file_serialization")
term = require("term")
text = require("text")

args = {...}
if #args < 1 then
  print("Usage: translate <filename>")
  return
end

t = file_serialization.load(args[1])
if type(t) ~= "table" then
  print("Nothing to translate")
  return
end

queue = {}
for k,v in pairs(t) do
  if k == v then
    queue[#queue+1] = k
  end
end

for _,word in pairs(queue) do
  print("Word: "..word)
  s = text.trim(term.read())
  if s == "" then
    break
  end
  t[word] = s
end

file_serialization.save(args[1], t)
