local utils = require "lummox.utils"

local Document = {}
Document.__index = Document

function Document.decode(bytes)
    local size1, size2, size3, size4 = string.byte(bytes, 1, 4)
    if not (size1 and size2 and size3 and size4) then
        error('Invalid document, must start have at least 4 bytes')
    end
    local size = utils.encode_u32(size1, size2, size3, size4)
    local idx = 5
    local next_byte = string.byte(bytes, idx)
    while next_byte ~= 0x00 do
        idx = idx + 1
        local name, name_len = assert(read_c_string(bytes:sub(idx)))
        idx = idx + name_len
        if next_byte == 0x01 then
            -- double float
            idx = idx + 8
        elseif next_byte == 0x02 then
            -- string
        elseif next_byte == 0x03 then
            -- embedded document
        elseif next_byte == 0x04 then
            -- array document
        elseif next_byte == 0x05 then
            -- binary
        elseif next_byte == 0x06 then
            -- undefined
        elseif next_byte == 0x07 then
            -- ObjectId (byte*12)
        elseif next_byte == 0x08 then
            -- boolean
        elseif next_byte == 0x09 then
            --datetime
        elseif next_byte == 0x0A then
            -- null
        elseif next_byte == 0x0B then
            -- regex
        elseif next_byte == 0x0C then
            -- DBPointer
        elseif next_byte == 0x0D then
            -- js code
        elseif next_byte == 0x0E then
            -- Symbol
        elseif next_byte == 0x0F then
            -- js code with scope
        elseif next_byte == 0x10 then
            -- i32
        elseif next_byte == 0x11 then
            -- u64 timestamp
        elseif next_byte == 0x12 then
            -- i64
        elseif next_byte == 0x13 then
            -- 128 float
        elseif next_byte == 0xFF then
            -- min key
        elseif next_byte == 0x7F then
            -- max key
        end
        next_byte = string.byte(bytes, idx)
    end
end

return Document