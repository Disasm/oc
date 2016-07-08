package.path = package.path .. ';/home/libs/?.lua;/home/libtrade/?.lua'

package.loaded["libtrade/trade"] = nil
_G["libtrade/trade"] = nil
require("libtrade/trade")()
