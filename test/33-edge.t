#! /usr/bin/lua

require 'Test.More'

plan(22)

local m = require 'Sereal'

is( m.Decoder.decode_sereal(m.Encoder.encode_sereal(1/0)), 1/0, "inf" )

is( m.Decoder.decode_sereal(m.Encoder.encode_sereal(-1/0)), -1/0, "-inf" )

local nan = m.Decoder.decode_sereal(m.Encoder.encode_sereal(0/0))
type_ok( nan, 'number', "nan" )
ok( nan ~= nan )

is( m.Encoder.encode_sereal{}:byte(7, 7), 0x40, "empty table as array" )

local t = { 'a', nil, 'c', nil, 'e' }
is( m.Encoder.encode_sereal(t):byte(7, 7), 0x45, "array with few holes as array" )
is_deeply( m.Decoder.decode_sereal(m.Encoder.encode_sereal(t)), t, "array with few holes" )
local t2 = { [1]='a', [3]='c', [5]='e' }
is( m.Encoder.encode_sereal(t2):byte(7, 7), 0x45, "array with few holes as array" )
is_deeply( m.Decoder.decode_sereal(m.Encoder.encode_sereal(t2)), t, "array with few holes" )

local t = setmetatable( { 'a', 'b', 'c' }, { __index = { [4] = 'd' } } )
is( t[4], 'd' )
t = m.Decoder.decode_sereal(m.Encoder.encode_sereal(t))
is( t[2], 'b' )
is( t[4], nil, "don't follow metatable" )

local t = setmetatable( { a = 1, b = 2, c = 3 }, { __index = { d = 4 } } )
is( t.d, 4 )
t = m.Decoder.decode_sereal(m.Encoder.encode_sereal(t))
is( t.b, 2 )
is( t.d, nil, "don't follow metatable" )

is( m.Encoder.encode_sereal(3.402824e+38, { number='float' }), m.Encoder.encode_sereal(1/0, { number='float' }), "float 3.402824e+38" )
is( m.Encoder.encode_sereal(7e42, { number='float' }), m.Encoder.encode_sereal(1/0, { number='float' }), "inf (downcast double -> float)" )
is( m.Encoder.encode_sereal(-7e42, { number='float' }), m.Encoder.encode_sereal(-1/0, { number='float' }), "inf (downcast double -> float)" )
is( m.Decoder.decode_sereal(m.Encoder.encode_sereal(7e42, { number='float' })), 1/0, "inf (downcast double -> float)" )
is( m.Decoder.decode_sereal(m.Encoder.encode_sereal(-7e42, { number='float' })), -1/0, "-inf (downcast double -> float)" )
is( m.Decoder.decode_sereal(m.Encoder.encode_sereal(7e-42, { number='float' })), 0, "epsilon (downcast double -> float)" )
is( m.Decoder.decode_sereal(m.Encoder.encode_sereal(-7e-42, { number='float' })), -0, "-epsilon (downcast double -> float)" )

