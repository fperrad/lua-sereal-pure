#! /usr/bin/lua

require 'Test.More'

plan(2)

local m = require 'Sereal'

local a = { "copy", "copy", "copy" }
eq_array( m.Decoder.decode_sereal(m.Encoder.encode_sereal(a)), a, "copy string" )

local a = { 3.14, 3.14, 3.14 }
eq_array( m.Decoder.decode_sereal(m.Encoder.encode_sereal(a)), a, "copy double" )

