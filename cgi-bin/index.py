# run the server by executing the following command in the repository root:
# python -m CGIHTTPServer 8000

import os
import glob
import fnmatch

allowed_extensions = [".lua"]

print("Content-type: text/plain\n")

root_dir = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir))

def print_dir(dir):
  for name in os.listdir(dir):
    if name.startswith("."): continue
    path = os.path.join(dir, name)
    extension = os.path.splitext(name)[1]
    if os.path.isdir(path):
      print_dir(path)
    elif extension in allowed_extensions:
      relative_path = os.path.relpath(path, root_dir).replace("\\", "/")
      time = int(round(os.path.getmtime(path)))
      print("  [\"%s\"] = %d," % (relative_path, time))

print("{")
print_dir(root_dir)
print("}")
