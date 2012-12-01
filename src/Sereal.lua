--
-- lua-Sereal : <http://fperrad.github.com/lua-Sereal/>
--

local Sereal = ...

return {
        Decoder         = require(Sereal .. '.Decoder'),
        Encoder         = require(Sereal .. '.Encoder'),
        _VERSION        = "0.0.1",
        _DESCRIPTION    = "lua-Sereal : a fast binary serializer",
        _COPYRIGHT      = "Copyright (c) 2012 Francois Perrad",
}
--
-- This library is licensed under the terms of the MIT/X11 license,
-- like Lua itself.
--
