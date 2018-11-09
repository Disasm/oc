# run the server by executing the following command in the repository root:
# python -m CGIHTTPServer 8000

import os
import glob
import fnmatch

print("Content-type: text/plain\n")

dir = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir))

print("{")
for root, dirnames, filenames in os.walk(dir):
    for filename in fnmatch.filter(filenames, '*.lua'):
        path = os.path.join(root, filename)
        relative_path = os.path.relpath(path, dir).replace("\\", "/")
        print("  [\"%s\"] = %d," % (relative_path, int(round(os.path.getmtime(path)))))
print("}")
