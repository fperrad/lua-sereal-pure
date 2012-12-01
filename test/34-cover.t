#! /usr/bin/lua

require 'Test.More'

plan(17)

local m = require 'Sereal'

is( m.Decoder.decode_sereal(m.Encoder.encode_sereal(math.pi)), math.pi, "pi" )
is( m.Decoder.decode_sereal(m.Encoder.encode_sereal(3.140625, { number='float' })), 3.140625, "3.140625" )

is( m.Decoder.decode_sereal(m.Encoder.encode_sereal(2^5)), 2^5, "2^5" )
is( m.Decoder.decode_sereal(m.Encoder.encode_sereal(-2^5)), -2^5, "-2^5" )
is( m.Decoder.decode_sereal(m.Encoder.encode_sereal(2^11)), 2^11, "2^11" )
is( m.Decoder.decode_sereal(m.Encoder.encode_sereal(-2^11)), -2^11, "-2^11" )
is( m.Decoder.decode_sereal(m.Encoder.encode_sereal(2^21)), 2^21, "2^21" )
is( m.Decoder.decode_sereal(m.Encoder.encode_sereal(-2^21)), -2^21, "-2^21" )
is( m.Decoder.decode_sereal(m.Encoder.encode_sereal(2^51)), 2^51, "2^51" )
is( m.Decoder.decode_sereal(m.Encoder.encode_sereal(-2^51)), -2^51, "-2^51" )

s = string.rep('x', 2^3)
is( m.Decoder.decode_sereal(m.Encoder.encode_sereal(s)), s, "#s 2^3" )
s = string.rep('x', 2^11)
is( m.Decoder.decode_sereal(m.Encoder.encode_sereal(s)), s, "#s 2^11" )
s = string.rep('x', 2^19)
is( m.Decoder.decode_sereal(m.Encoder.encode_sereal(s)), s, "#s 2^19" )

t = { string.rep('x', 2^3):byte(1, -1) }
is_deeply( m.Decoder.decode_sereal(m.Encoder.encode_sereal(t)), t, "#t 2^3" )
t = { string.rep('x', 2^9):byte(1, -1) }
is_deeply( m.Decoder.decode_sereal(m.Encoder.encode_sereal(t)), t, "#t 2^9" )

h = { string.rep('x', 2^3):byte(1, -1) }
h[2] = nil
is_deeply( m.Decoder.decode_sereal(m.Encoder.encode_sereal(h)), h, "#h 2^3" )
h = { string.rep('x', 2^9):byte(1, -1) }
h[2] = nil
is_deeply( m.Decoder.decode_sereal(m.Encoder.encode_sereal(h)), h, "#h 2^9" )

