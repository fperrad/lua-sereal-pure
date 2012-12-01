#! /usr/bin/lua

require 'Test.More'

plan(14)

local Encoder = require 'Sereal'.Encoder

type_ok( Encoder.encode_sereal, 'function', "function Sereal.Encoder.encode_sereal")

local e = Encoder.new()
is( tostring(e), 'Sereal.Encoder' )
type_ok( e, 'table' )
type_ok( e.encode, 'function', "method encode" )
type_ok( e.snappy, 'boolean' )
type_ok( e.snappy_threshold, 'number' )
type_ok( e.number, 'string' )

local e = Encoder.new{ snappy = true, snappy_threshold = 128, number = 'float' }
is( e.snappy, true )
is( e.snappy_threshold, 128 )
is( e.number, 'float' )

error_like( function ()
                e.snappy_threshold = 1024
            end,
            "read%-only" )

local e = Encoder.new{ snappy = false }
is( e.snappy, false )

error_like( function ()
                Encoder.new{ snappy = 1 }
            end,
            "bad option 'snappy' to new %(boolean expected, got number%)" )

error_like( function ()
                Encoder.new{ number = 'bad' }
            end,
            "bad option 'number' to new %(invalid value 'bad'%)" )

