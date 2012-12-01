#! /usr/bin/lua

require 'Test.More'

plan(2)

local m = require 'Sereal'

local a = {}
a.foo = a
is_deeply( m.Decoder.decode_sereal(m.Encoder.encode_sereal(a)), a, "direct cycle" )

local a = {}
local b = {}
a.foo = b
b.foo = a
is_deeply( m.Decoder.decode_sereal(m.Encoder.encode_sereal(a)), a, "indirect cycle" )

