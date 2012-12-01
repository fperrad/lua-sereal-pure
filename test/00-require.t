#! /usr/bin/lua

require 'Test.More'

plan(7)

if not require_ok 'Sereal' then
    BAIL_OUT "no lib"
end

local m = require 'Sereal'
type_ok( m, 'table' )
like( m._COPYRIGHT, 'Perrad', "_COPYRIGHT" )
like( m._DESCRIPTION, 'fast binary serializer', "_DESCRIPTION" )
like( m._VERSION, '^%d%.%d%.%d$', "_VERSION" )

type_ok( m.Decoder, 'table', "Sereal.Decoder" )
type_ok( m.Encoder, 'table', "Sereal.Encoder" )

