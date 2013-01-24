--
-- lua-Sereal : <http://fperrad.github.com/lua-Sereal/>
--

local r, csnappy = pcall(require, 'csnappy')
if not r then
    csnappy = nil
end

local assert = assert
local error = error
local pairs = pairs
local pcall = pcall
local setmetatable = setmetatable
local tostring = tostring
local type = type
local floor = require'math'.floor
local ldexp = require'math'.ldexp
local huge = require'math'.huge

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

local types_map = setmetatable({
    [0x20] = 'varint',
    [0x21] = 'zigzag',
    [0x22] = 'float',
    [0x23] = 'double',
    [0x24] = 'long_double',
    [0x25] = 'undef',
    [0x26] = 'binary',
    [0x27] = 'string_utf8',
    [0x28] = 'refn',
    [0x29] = 'refp',
    [0x2A] = 'hash',
    [0x2B] = 'array',
    [0x2C] = 'object',
    [0x2D] = 'objectv',
    [0x2E] = 'alias',
    [0x2F] = 'copy',
    [0x30] = 'weaken',
    [0x31] = 'regexp',
    [0x3A] = 'false',
    [0x3B] = 'true',
    [0x3C] = 'many',
    [0x3D] = 'packet_start',
    [0x3E] = 'extend',
    [0x3F] = 'pad',
}, { __index = function (t, k)
        if k < 0x20 then
            if k < 0x10 then
                return 'short_pos'
            else
                return 'short_neg'
            end
        elseif k > 0x3F then
            if k < 0x50 then
                return 'short_array'
            elseif k < 0x60 then
                return 'short_hash'
            elseif k < 0x80 then
                return 'short_binary'
            end
        end
        return 'reserved' .. k
end })

local readers = setmetatable({}, {
    __index = function (t, k) error("read '" .. k .. "' is unimplemented") end
})

local function read_array (c, n)
    local t = {}
    local offset = c.offset
    if offset then
        c.ref[offset] = t
    end
    local decode = c.decoder.readers['any']
    for i = 1, n do
        t[i] = decode(c)
    end
    return t
end

local function read_hash (c, n)
    local t = {}
    local offset = c.offset
    if offset then
        c.ref[offset] = t
    end
    local decode = c.decoder.readers['any']
    for i = 1, n do
        local k = decode(c)
        t[k] = decode(c)
    end
    return t
end

local function read_string (c, n)
    local s, i, j = c.s, c.i, c.j
    local e = i+n-1
    if e > j then
        c:underflow(e)
        s, i, j = c.s, c.i, c.j
    end
    c.i = i+n
    return s:sub(i, e)
end

local function read_varint (c)
    local n = 0
    local m = 1
    repeat
        if m > 2^53 then
            error "varint too big"
        end
        local s, i, j = c.s, c.i, c.j
        if c.i > c.j then
            c:underflow(i)
            s, i, j = c.s, c.i, c.j
        end
        local val = s:sub(i, i):byte()
        c.i = i+1
        n = n + m * (val % 0x80)
        m = m * 0x80
    until val < 0x80
    return n
end

readers['any'] = function (c)
    local s, i, j = c.s, c.i, c.j
    if i > j then
        c:underflow(i)
        s, i, j = c.s, c.i, c.j
    end
    local val = s:sub(i, i):byte()
    c.offset = val >= 0x80 and (i-1)
    c.i = i+1
    return c.decoder.readers[types_map[val % 0x80]](c, val)
end

readers['undef'] = function ()
    return nil
end

readers['false'] = function ()
    return false
end

readers['true'] = function ()
    return true
end

readers['float'] = function (c)
    local s, i, j = c.s, c.i, c.j
    if i+3 > j then
        c:underflow(i+3)
        s, i, j = c.s, c.i, c.j
    end
    local b1, b2, b3, b4 = s:sub(i, i+3):byte(1, 4)
    local sign = b4 > 0x7F
    local expo = (b4 % 0x80) * 0x2 + floor(b3 / 0x80)
    local mant = ((b3 % 0x80) * 0x100 + b2) * 0x100 + b1
    if sign then
        sign = -1
    else
        sign = 1
    end
    local n
    if mant == 0 and expo == 0 then
        n = sign * 0
    elseif expo == 0xFF then
        if mant == 0 then
            n = sign * huge
        else
            n = 0/0
        end
    else
        n = sign * ldexp(1 + mant / 0x800000, expo - 0x7F)
    end
    c.i = i+4
    return n
end

readers['double'] = function (c)
    local s, i, j = c.s, c.i, c.j
    if i+7 > j then
        c:underflow(i+7)
        s, i, j = c.s, c.i, c.j
    end
    local b1, b2, b3, b4, b5, b6, b7, b8 = s:sub(i, i+7):byte(1, 8)
    local sign = b8 > 0x7F
    local expo = (b8 % 0x80) * 0x10 + floor(b7 / 0x10)
    local mant = ((((((b7 % 0x10) * 0x100 + b6) * 0x100 + b5) * 0x100 + b4) * 0x100 + b3) * 0x100 + b2) * 0x100 + b1
    if sign then
        sign = -1
    else
        sign = 1
    end
    local n
    if mant == 0 and expo == 0 then
        n = sign * 0
    elseif expo == 0x7FF then
        if mant == 0 then
            n = sign * huge
        else
            n = 0/0
        end
    else
        n = sign * ldexp(1 + mant / 0x10000000000000, expo - 0x3FF)
    end
    c.i = i+8
    return n
end

readers['short_pos'] = function (c, val)
    return val
end

readers['varint'] = function (c)
    return read_varint(c)
end

readers['short_neg'] = function (c, val)
    return val - 0x20
end

readers['zigzag'] = function (c)
    local n = read_varint(c)
    if (n % 2) == 1 then
        return (n+1) / -2
    else
        return n / 2
    end
end

readers['short_binary'] = function (c, val)
    return read_string(c, val % 0x20)
end

readers['binary'] = function (c)
    return read_string(c, read_varint(c))
end
readers['string_utf8'] = readers['binary']

readers['short_array'] = function (c, val)
    return read_array(c, val % 0x10)
end

readers['array'] = function (c)
    return read_array(c, read_varint(c))
end

readers['short_hash'] = function (c, val)
    return read_hash(c, val % 0x10)
end

readers['hash'] = function (c)
    return read_hash(c, read_varint(c))
end

readers['refn'] = function (c)
    return c.decoder.readers['any'](c)
end

readers['refp'] = function (c)
    local offset = read_varint(c)
    local val = c.ref[offset]
    assert(val, "invalid REFP " .. offset)
    return val
end

readers['copy'] = function (c)
    local decoder, s = c.decoder, c.s
    local offset = read_varint(c)
    assert(offset < c.i, "invalid COPY " .. offset)
    return decoder.readers['any']{
        decoder = decoder,
        s = s,
        i = offset+1,
        j = #s,
        underflow = function (self)
                        error "underflow with COPY"
                    end,
    }
end


local function check_header (s)
    if s:sub(1, 4) ~= '=srl' then
        return false, "bad magic"
    end
    local ver = s:sub(5, 5)
    if #s < 5 and (ver:byte() % 0x10) ~= 1 then
        return false, "bad version"
    end
    return true
end


function proto:looks_like_sereal (s)
    s = s or ''
    checktype('decode_sereal', 1, s, 'string')
    return check_header(s)
end


function proto:decode (s)
    checktype('decode', 1, s, 'string')
    assert(check_header(s))
    local snappy = floor(s:sub(5, 5):byte() / 0x10) % 2
    local cursor = {
        decoder = self,
        ref = {},
        s = s,
        i = 6,
        j = #s,
        underflow = function (self)
                        error "missing bytes"
                    end,
    }
    local header_size = read_varint(cursor)
    cursor.i = cursor.i + header_size
    if snappy == 1 then
        if not csnappy then
            error "snappy not available"
        end
        if self.refuse_snappy then
            error "refuse snappy"
        end
        s = csnappy.decompress(s:sub(cursor.i))
        cursor.s = s
        cursor.i = 1
        cursor.j = #s
    end
    local data = self.readers['any'](cursor)
    if cursor.i < cursor.j then
        error "extra bytes"
    end
    return data
end


local default = {
    refuse_snappy       = (csnappy == nil),
}

local function new (options)
    options = options or {}
    checktype('new', 1, options, 'table')
    local obj = {
        readers = setmetatable({}, { __index = readers }),
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
    for k, v in pairs(proto) do
        obj[k] = v
    end
    return setmetatable({}, {
        __index = obj,
        __newindex = function () error "read-only" end,
        __tostring = function () return m._NAME end,
    })
end
m.new = new


function m.decode_sereal (s, options)
    checktype('decode_sereal', 1, s, 'string')
    options = options or {}
    checktype('decode_sereal', 2, options, 'table')
    local decoder = new(options)
    return decoder:decode(s)
end


function m.looks_like_sereal (s)
    s = s or ''
    checktype('decode_sereal', 1, s, 'string')
    return check_header(s)
end


function m.iter (src, options)
    options = options or {}
    checktype('decoder', 2, options, 'table')
    local decoder = new(options)
    if type(src) == 'string' then
        local cursor = {
            decoder = decoder,
            ref = {},
            s = src,
            i = 1,
            j = #src,
            underflow = function (self)
                            error "missing bytes"
                        end,
        }
        return function ()
            if cursor.i <= cursor.j then
                cursor.s = cursor.s:sub(cursor.i)
                cursor.i = 1
                cursor.j = #cursor.s
                local h = cursor.s:sub(cursor.i, cursor.i + 4)
                assert(check_header(h))
                local snappy = floor(h:sub(5, 5):byte() / 0x10) % 2
                if snappy == 1 then
                    error "iterator refuses snappy"
                end
                cursor.i = cursor.i + 5
                local header_size = read_varint(cursor)
                cursor.i = cursor.i + header_size
                return cursor.i, decoder.readers['any'](cursor)
            end
        end
    elseif type(src) == 'function' then
        local cursor = {
            decoder = decoder,
            ref = {},
            s = '',
            i = 1,
            j = 0,
            underflow = function (self, e)
                            while e > self.j do
                                local chunk = src()
                                if not chunk then
                                    error "missing bytes"
                                end
                                self.s = self.s .. chunk
                                self.j = #self.s
                            end
                        end,
        }
        return function ()
            if cursor.i + 5 > cursor.j then
                pcall(cursor.underflow, cursor, cursor.i + 5)
            end
            if cursor.i <= cursor.j then
                cursor.s = cursor.s:sub(cursor.i)
                cursor.i = 1
                cursor.j = #cursor.s
                local h = cursor.s:sub(cursor.i, cursor.i + 4)
                assert(check_header(h))
                local snappy = floor(h:sub(5, 5):byte() / 0x10) % 2
                if snappy == 1 then
                    error "iterator refuses snappy"
                end
                cursor.i = cursor.i + 5
                local header_size = read_varint(cursor)
                cursor.i = cursor.i + header_size
                return true, decoder.readers['any'](cursor)
            end
        end
    else
        argerror('iter', 1, "string or function expected, got " .. type(src))
    end
end


m._NAME = ...
return m
--
-- Copyright (c) 2012-2013 Francois Perrad
--
-- This library is licensed under the terms of the MIT/X11 license,
-- like Lua itself.
--
