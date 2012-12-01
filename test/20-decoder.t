#! /usr/bin/lua

require 'Test.More'

plan(11)

local Decoder = require 'Sereal'.Decoder

type_ok( Decoder.decode_sereal, 'function', "function Sereal.Decoder.decode_sereal")
type_ok( Decoder.looks_like_sereal, 'function', "function Sereal.Decoder.looks_like_sereal")
type_ok( Decoder.iter, 'function', "function Sereal.Decoder.iter")

local d = Decoder.new()
is( tostring(d), 'Sereal.Decoder' )
type_ok( d, 'table' )
type_ok( d.decode, 'function', "method decode" )
type_ok( d.looks_like_sereal, 'function', "method looks_like_sereal")
type_ok( d.refuse_snappy, 'boolean' )

local d = Decoder.new{ refuse_snappy = true }
is( d.refuse_snappy, true )

error_like( function ()
                d.refuse_snappy = 1
            end,
            "read%-only" )

local d = Decoder.new{ refuse_snappy = false }
is( d.refuse_snappy, false )
