#! /usr/bin/lua

local unpack = table.unpack or unpack

require 'Test.More'

local m = require 'Sereal'

local data = {
    false,              "false",
    true,               "true",
    nil,                "undef",

    0,                  "0 short pos",
    0,                  "0 varint",
    0,                  "0 varint",
    0,                  "0 varint",
    0,                  "0 zigzag",
    0,                  "0 zigzag",
    0,                  "0 zigzag",
    -1,                 "-1 short neg",
    -1,                 "-1 zigzag",
    -1,                 "-1 zigzag",
    -1,                 "-1 zigzag",
    15,                 "15 short pos",
    127,                "127 varint",
    128,                "128 varint",
    2^14,               "2^14 varint",
    2^21,               "2^21 varint",
    -16,                "-16 short neg",
    -64,                "-64 zigzag",
    63,                 "63 zigzag",
    -65,                "-65 zigzag",
    64,                 "64 zigzag",
    -(2^13),            "-(2^13) zigzag",
    2^13,               "2^13 zigzag",
    -(2^20),            "-(2^20) zigzag",
    2^20,               "2^20 zigzag",

    0.0,                "0.0 float",
    0.0,                "0.0 double",
    -0.0,               "-0.0 float",
    -0.0,               "-0.0 double",
    1.0,                "1.0 double",
    -1.0,               "-1.0 double",

    '',                 "'' short binary",
    '',                 "'' binary",
    '',                 "'' string utf8",
    'a',                "'a' short binary",
    'a',                "'a' binary",
    'a',                "'a' binary",
    'a',                "'a' string utf8",
    'a',                "'a' string utf8",

    {},                 "[] short array",
    {},                 "[] array",
    { 0 },              "[0] short array",
    { 0 },              "[0] array",
    { 0 },              "[0] array",

    {},                 "{} short hash",
    {},                 "{} hash",
    { a=97 },           "{ a=97 } short hash",
    { a=97 },           "{ a=97 } hash",
    { a=97 },           "{ a=97 } hash",

    { {} },             "[[]]",
    { {'a'} },          "[['a']]",
}

local a = {}
a.foo = a
data[#data+1] = a
data[#data+1] = "direct cycle"

plan(2 * #data)

local source = [===[
header  3a                              # false
header  3b                              # true
header  25                              # undef

header  00                              # 0 short pos
header  20 00                           # 0 varint
header  20 80 00                        # 0 varint
header  20 80 80 00                     # 0 varint
header  21 00                           # 0 zigzag
header  21 80 00                        # 0 zigzag
header  21 80 80 00                     # 0 zigzag
header  1f                              # -1 short neg
header  21 01                           # -1 zigzag
header  21 81 00                        # -1 zigzag
header  21 81 80 00                     # -1 zigzag
header  0F                              # 15 short pos
header  20 7F                           # 127 varint
header  20 80 01                        # 128 varint
header  20 80 80 01                     # 2^14 varint
header  20 80 80 80 01                  # 2^21 varint
header  10                              # -16 short neg
header  21 7F                           # -64 zigzag
header  21 7E                           # 63 zigzag
header  21 81 01                        # -65 zigzag
header  21 80 01                        # 64 zigzag
header  21 FF 7F                        # -(2^13) zigzag
header  21 80 80 01                     # 2^13 zigzag
header  21 FF FF 7F                     # -(2^20) zigzag
header  21 80 80 80 01                  # 2^20 zigzag

header  22 00 00 00 00                  # 0.0 float
header  23 00 00 00 00 00 00 00 00      # 0.0 double
header  22 00 00 00 80                  # -0.0 float
header  23 00 00 00 00 00 00 00 80      # -0.0 double
header  23 00 00 00 00 00 00 f0 3f      # 1.0 double
header  23 00 00 00 00 00 00 f0 bf      # -1.0 double

header  60                              # '' short binary
header  26 00                           # '' binary
header  27 00                           # '' string utf8
header  61 61                           # 'a' short binary
header  26 01 61                        # 'a' binary
header  26 81 00 61                     # 'a' binary
header  27 01 61                        # 'a' string utf8
header  27 81 00 61                     # 'a' string utf8

header  40                              # [] short array
header  28 2b 00                        # [] array
header  41 00                           # [0] short array
header  28 2b 01 00                     # [0] array
header  28 2b 81 00 00                  # [0] array

header  50                              # {} short hash
header  28 2a 00                        # {} hash
header  51 61 61 20 61                  # { a=97 } short hash
header  28 2a 01 61 61 20 61            # { a=97 } hash
header  28 2a 81 00 61 61 20 61         # { a=97 } hash

header  41 40                           # [[]]
header  41 41 61 61                     # [['a']]

header  28 aa 01 63 66 6f 6f 29 07      #
]===]

source = source:gsub('#[^\n]+', ''):gsub('header', '3d 73 72 6c 01 00')
local t = {}
for v in source:gmatch'%x%x' do
    t[#t+1] = tonumber(v, 16)
end
local srl = string.char(unpack(t))


local i = 1
for _, val in m.Decoder.iter(srl) do
    if type(val) == 'table' then
        is_deeply(val, data[i], "reference     " .. data[i+1])
        is_deeply(m.Decoder.decode_sereal(m.Encoder.encode_sereal(data[i])), data[i], "decode/encode " .. data[i+1])
    else
        is(val, data[i], "reference     " .. data[i+1])
        is(m.Decoder.decode_sereal(m.Encoder.encode_sereal(data[i])), data[i], "decode/encode " .. data[i+1])
    end
    i = i + 2
end

local f = io.open('cases.srl', 'w')
f:write(srl)
f:close()
local r, ltn12 = pcall(require, 'ltn12')        -- from LuaSocket
if not r then
    diag "ltn12.source.file emulated"
    ltn12 = { source = {} }

    function ltn12.source.file (handle)
        if handle then
            return function ()
                local chunk = handle:read(1)
                if not chunk then
                    handle:close()
                end
                return chunk
            end
        else return function ()
                return nil, "unable to open file"
            end
        end
    end
end
local i = 1
local f = io.open('cases.srl', 'r')
local src = ltn12.source.file(f)
for _, val in m.Decoder.iter(src) do
    if type(val) == 'table' then
        is_deeply(val, data[i], "reference   " .. data[i+1])
    else
        is(val, data[i], "reference   " .. data[i+1])
    end
    i = i + 2
end
os.remove 'cases.srl'   -- clean up

local i = 1
for _, val in m.Decoder.iter(srl, { number='float'} ) do
    if type(val) == 'table' then
        is_deeply(m.Decoder.decode_sereal(m.Encoder.encode_sereal(data[i])), data[i], "decode/encode " .. data[i+1])
    else
        is(m.Decoder.decode_sereal(m.Encoder.encode_sereal(data[i])), data[i], "decode/encode " .. data[i+1])
    end
    i = i + 2
end

