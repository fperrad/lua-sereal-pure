--
-- lua-Sereal : <http://fperrad.github.com/lua-Sereal/>
--

local r, csnappy = pcall(require, 'csnappy')
if not r then
    csnappy = nil
end

local r, jit = pcall(require, 'jit')
if not r then
    jit = nil
end

local SIZEOF_NUMBER = 8
local NUMBER_INTEGRAL = false
if not jit then
    -- Lua 5.1 & 5.2
    local loadstring = loadstring or load
    local luac = string.dump(loadstring "a = 1")
    local header = { luac:sub(1, 12):byte(1, 12) }
    SIZEOF_NUMBER = header[11]
    NUMBER_INTEGRAL = 1 == header[12]
end

local error = error
local pairs = pairs
local setmetatable = setmetatable
local type = type
local unpack = require'table'.unpack or unpack
local char = require'string'.char
local floor = require'math'.floor
local frexp = require'math'.frexp
local ldexp = require'math'.ldexp
local huge = require'math'.huge
local tconcat = require'table'.concat

_ENV = nil
local m = {}
local proto = {}

local function argerror (caller, narg, extramsg)
    if type(narg) == 'string' then
        error("bad option '" .. narg .. "' to "
              .. caller .. " (" .. extramsg .. ")")
    else
        error("bad argument #" .. tostring(narg) .. " to "
              .. caller .. " (" .. extramsg .. ")")
    end
end

local function typeerror (caller, narg, arg, tname)
    argerror(caller, narg, tname .. " expected, got " .. type(arg))
end

local function checktype (caller, narg, arg, tname)
    if type(arg) ~= tname then
        typeerror(caller, narg, arg, tname)
    end
end

local function dump_varint (buffer, n)
    while n >= 0x80 do
        buffer[#buffer+1] = 0x80 + (n % 0x80)
        n = floor(n / 0x80)
    end
    buffer[#buffer+1] = n
end


local dumpers = setmetatable({}, {
    __index = function (t, k) error("dump '" .. k .. "' is unimplemented") end
})

dumpers['nil'] = function (buffer)
    buffer[#buffer+1] = 0x25                    -- undef
end

dumpers['boolean'] = function (buffer, bool)
    if bool then
        buffer[#buffer+1] = 0x3b                -- true
    else
        buffer[#buffer+1] = 0x3a                -- false
    end
end

dumpers['table'] = function (buffer, tbl, obj)
    local offset = obj.saved[tbl]
    if offset then
        buffer[#buffer+1] = 0x29                -- refp
        dump_varint(buffer, offset)
        local tag = buffer[offset-5]
        if tag < 0x80 then
            buffer[offset-5] = tag + 0x80
        end
    else
        obj.saved[tbl] = #buffer + 6
        local is_map, n, max = false, 0, 0
        for k in pairs(tbl) do
            if type(k) == 'number' and k > 0 then
                if k > max then
                    max = k
                end
            else
                is_map = true
            end
            n = n + 1
        end
        if max > 2*n then   -- sparse array
--        if max ~= n then    -- there are holes
            is_map = true
        end
        if is_map then
            return obj.dumpers['map'](buffer, tbl, obj, n)
        else
            return obj.dumpers['array'](buffer, tbl, obj, max)
        end
    end
end

dumpers['map'] = function (buffer, tbl, obj, n)
    if n <= 0x0F then
        buffer[#buffer+1] = 0x50 + n            -- short_hashref
    else
        buffer[#buffer+1] = 0x28                -- refn
        buffer[#buffer+1] = 0x2A                -- hash
        dump_varint(buffer, n)
    end
    local encode = obj.dumpers
    for k, v in pairs(tbl) do
        encode[type(k)](buffer, k, obj)
        encode[type(v)](buffer, v, obj)
    end
end

dumpers['array'] = function (buffer, tbl, obj, n)
    if n <= 0x0F then
        buffer[#buffer+1] = 0x40 + n            -- short_arrayref
    else
        buffer[#buffer+1] = 0x28                -- refn
        buffer[#buffer+1] = 0x2B                -- array
        dump_varint(buffer, n)
    end
    local encode = obj.dumpers
    for i = 1, n do
        local v = tbl[i]
        encode[type(v)](buffer, v, obj)
    end
end

dumpers['string'] = function (buffer, str, obj)
    local offset = obj.saved[str]
    if offset then
        buffer[#buffer+1] = 0x2F                -- copy
        dump_varint(buffer, offset)
    else
        offset = #buffer + 6
        if #str > offset / 0x80 then
            obj.saved[str] = offset
        end
        local n = #str
        if n <= 0x1F then
            buffer[#buffer+1] = 0x60 + n        -- short_binary
        else
            buffer[#buffer+1] = 0x26            -- binary
            dump_varint(buffer, n)
        end
        for c in str:gmatch'.' do
            buffer[#buffer+1] = c:byte()
        end
    end
end

dumpers['integer'] = function (buffer, n, obj)
    if n >= 0 then
        if n <= 0x0F then
            buffer[#buffer+1] = n               -- short_pos
        else
            local offset = obj.saved[n]
            if offset then
                buffer[#buffer+1] = 0x2F        -- copy
                dump_varint(buffer, offset)
            else
                offset = #buffer + 6
                if n > offset then
                    obj.saved[n] = offset
                end
                buffer[#buffer+1] = 0x20        -- varint
                dump_varint(buffer, n)
--                buffer[#buffer+1] = 0x21        -- zigzag
--                dump_varint(buffer, 2*n)
            end
        end
    else
        if n >= -0x10 then
            buffer[#buffer+1] = 0x20 + n        -- short_neg
        else
            local offset = obj.saved[n]
            if offset then
                buffer[#buffer+1] = 0x2F        -- copy
                dump_varint(buffer, offset)
            else
                offset = #buffer + 6
                local z = -2*n-1
                if z > offset then
                    obj.saved[n] = offset
                end
                buffer[#buffer+1] = 0x21        -- zigzag
                dump_varint(buffer, z)
            end
        end
    end
end

dumpers['float'] = function (buffer, n, obj)
    local offset = obj.saved[n]
    if offset then
        buffer[#buffer+1] = 0x2F                -- copy
        dump_varint(buffer, offset)
    else
        buffer[#buffer+1] = 0x22                -- float
        offset = #buffer + 6 - 1
        if n ~= n then      -- nan
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0x88
            buffer[#buffer+1] = 0xFF
        elseif n == huge then
            obj.saved[n] = offset
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0x80
            buffer[#buffer+1] = 0x7F
        elseif n == -huge then
            obj.saved[n] = offset
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0x80
            buffer[#buffer+1] = 0xFF
        else
            obj.saved[n] = offset
            local sign = 0
            if n < 0 then
                sign = 0x80
                n = -n
            end
            local mant, expo = frexp(n)
            mant = (mant * 2 - 1) * ldexp(0.5, 24)
            expo = expo + 0x7E
            buffer[#buffer+1] = mant % 0x100
            buffer[#buffer+1] = floor(mant / 0x100) % 0x100
            buffer[#buffer+1] = (expo % 0x2) * 0x80 + floor(mant / 0x10000)
            buffer[#buffer+1] = sign + floor(expo / 0x2)
        end
    end
end

dumpers['double'] = function (buffer, n, obj)
    local offset = obj.saved[n]
    if offset then
        buffer[#buffer+1] = 0x2F                -- copy
        dump_varint(buffer, offset)
    else
        buffer[#buffer+1] = 0x23                -- double
        offset = #buffer + 6 - 1
        if n ~= n then      -- nan
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0xF8
            buffer[#buffer+1] = 0xFF
        elseif n == huge then
            obj.saved[n] = offset
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0xF0
            buffer[#buffer+1] = 0x7F
        elseif n == -huge then
            obj.saved[n] = offset
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0x00
            buffer[#buffer+1] = 0xF0
            buffer[#buffer+1] = 0xFF
        else
            obj.saved[n] = offset
            local sign = 0
            if n < 0 then
                sign = 0x80
                n = -n
            end
            local mant, expo = frexp(n)
            mant = (mant * 2 - 1) * ldexp(0.5, 53)
            expo = expo + 0x3FE
            buffer[#buffer+1] = mant % 0x100
            buffer[#buffer+1] = floor(mant / 0x100) % 0x100
            buffer[#buffer+1] = floor(mant / 0x10000) % 0x100
            buffer[#buffer+1] = floor(mant / 0x1000000) % 0x100
            buffer[#buffer+1] = floor(mant / 0x100000000) % 0x100
            buffer[#buffer+1] = floor(mant / 0x10000000000) % 0x100
            buffer[#buffer+1] = (expo % 0x10) * 0x10 + floor(mant / 0x1000000000000)
            buffer[#buffer+1] = sign + floor(expo / 0x10)
        end
    end
end


function proto:encode (data)
    if not csnappy and self.snappy then
        error "snappy not available"
    end
    local buffer = {}
    self.saved = {}
    self.dumpers[type(data)](buffer, data, self)
    local payload = char(unpack(buffer))
    if self.snappy and #payload > self.snappy_threshold then
        return '=srl\17\0' .. csnappy.compress(payload)
    else
        return '=srl\1\0' .. payload
    end
end


local default = {
    snappy              = (csnappy ~= nil),
    snappy_threshold    = 1024,
}
if NUMBER_INTEGRAL then
    default.number = 'integer'
elseif SIZEOF_NUMBER == 4 then
    default.number = 'float'
else
    default.number = 'double'
end

local function new (options)
    options = options or {}
    checktype('new', 1, options, 'table')
    local obj = {
        dumpers = setmetatable({}, { __index = dumpers }),
    }
    for k, v in pairs(default) do
        local opt = options[k]
        if opt ~= nil then
            checktype('new', k, opt, type(v))
            obj[k] = opt
        else
            obj[k] = v
        end
    end
    local number = obj.number
    if number == 'integer' then
        obj.dumpers['number'] = dumpers['signed']
    elseif number == 'float' then
        obj.dumpers['number'] = function (buffer, n, obj)
            if floor(n) ~= n or n ~= n or n == huge or n == -huge then
                return dumpers['float'](buffer, n, obj)
            else
                return dumpers['integer'](buffer, n, obj)
            end
        end
    elseif number == 'double' then
        obj.dumpers['number'] = function (buffer, n, obj)
            if floor(n) ~= n or n ~= n or n == huge or n == -huge then
                return dumpers['double'](buffer, n, obj)
            else
                return dumpers['integer'](buffer, n, obj)
            end
        end
    else
        argerror('new', 'number', "invalid value '" .. number .."'")
    end
    for k, v in pairs(proto) do
        obj[k] = v
    end
    return setmetatable({ saved = true }, {
        __index = obj,
        __newindex = function () error "read-only" end,
        __tostring = function () return m._NAME end,
    })
end
m.new = new


function m.encode_sereal (data, options)
    options = options or {}
    checktype('encode_sereal', 2, options, 'table')
    local encoder = new(options)
    return encoder:encode(data)
end


m._NAME = ...
return m
--
-- Copyright (c) 2012 Francois Perrad
--
-- This library is licensed under the terms of the MIT/X11 license,
-- like Lua itself.
--
