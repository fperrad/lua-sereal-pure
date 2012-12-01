#! /usr/bin/lua

require 'Test.More'

plan(13)

local m = require 'Sereal'

error_like( function ()
                m.Encoder.encode_sereal( print )
            end,
            "dump 'function' is unimplemented" )

error_like( function ()
                m.Encoder.encode_sereal( coroutine.create(plan) )
            end,
            "dump 'thread' is unimplemented" )

error_like( function ()
                m.Encoder.encode_sereal( io.stdin )
            end,
            "dump 'userdata' is unimplemented" )

is( m.Decoder.decode_sereal(m.Encoder.encode_sereal("text")), "text" )

error_like( function ()
                m.Decoder.decode_sereal(m.Encoder.encode_sereal("text"):sub(1, -2))
            end,
            "missing bytes" )

error_like( function ()
                m.Decoder.decode_sereal(m.Encoder.encode_sereal("text") .. "more")
            end,
            "extra bytes" )

error_like( function ()
                m.Decoder.decode_sereal( {} )
            end,
            "bad argument #1 to decode_sereal %(string expected, got table%)" )

error_like( function ()
                m.Decoder.iter( false )
            end,
            "bad argument #1 to iter %(string or function expected, got boolean%)" )

error_like( function ()
                m.Decoder.iter( {} )
            end,
            "bad argument #1 to iter %(string or function expected, got table%)" )

for _, val in m.Decoder.iter(string.rep(m.Encoder.encode_sereal("text"), 2)) do
    is( val, "text" )
end

error_like( function ()
                for _, val in m.Decoder.iter(string.rep(m.Encoder.encode_sereal("text"), 2):sub(1, -2)) do
                    is( val, "text" )
                end
            end,
            "missing bytes" )

