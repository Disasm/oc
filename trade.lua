package.path = package.path .. ';/libs/?.lua;/libtrade/?.lua'

package.loaded["libtrade/trade"] = nil
_G["libtrade/trade"] = nil
require("libtrade/trade")()
