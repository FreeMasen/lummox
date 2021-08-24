local utils = require "lummox.utils"
local Document = require "lummox.document"

local Element = {}
Element.__index = Element

local ElementType = {
  [0x01] = 'Float',
  [0x02] = "UTF-8 string",
  [0x03] = "Embedded document",
  [0x04] = "Array",
  [0x05] = "binary",
  [0x06] = "Undefined",
  [0x07] = "ObjectId",
  [0x08] = "Boolean",
  [0x09] = "UTC datetime",
  [0x0A] = "Null",
  [0x0B] = "RegEx",
  [0x0C] = "DBPointer",
  [0x0D] = "JavaScript code",
  [0x0E] = "Symbol",
  [0x0F] = "JavaScript code w/ scope",
  [0x10] = "int32",
  [0x11] = "Timestamp",
  [0x12] = "int64",
  [0x13] = "decimal128",
  [0xFF] = "Min key",
  [0x7F] = "Max key",
}

local BinarySubType = {
  [0x00] = "Generic",
  [0x01] = "Function",
  [0x02] = "Binary (Old)",
  [0x03] = "UUID (Old)",
  [0x04] = "UUID",
  [0x05] = "MD5",
  [0x06] = "Encrypted BSON value",
  [0x80] = "User Defined",
}

function read_c_string(bytes)
  if #bytes == 0 then return nil, 'empty string' end
  local idx = 1
  local c = bytes:byte(idx)
  while c > 0 do
      idx = idx + 1
      c = bytes:byte(idx)
  end
  return bytes:sub(1, idx-1), idx
end

local decoders = {}

local function decode_float(bytes)
  local s, v = pcall(string.unpack, 'f', bytes)
  if not s then
    return nil, v
  end
  return v, 4
end
decoders[0x01] = decode_float

local function decode_string(bytes)
  local s, l = pcall(string.unpack, '<i4', bytes)
  if not s then
    return nil, string.format('Failed to decode string length: %s', l)
  end
  if #bytes < l + 5 then
    return nil, string.format('Expected at least %s bytes found #s', l+5, #bytes)
  end
  local ret = bytes:sub(5, l+4)
  return ret, l
end
decoders[0x02] = decode_string

local function decode_document(bytes) --
  local doc = Document.decode(bytes)
  return doc, doc.size
end
decoders[0x03] = decode_document

local function decode_array(bytes) --
  local doc = Document.decode(bytes)
  return doc, doc.size
end
decoders[0x04] = decode_array

local function decode_binary(bytes) --
  local s, l = pcall(string.unpack, '<i4', bytes)
  if not s then
    return nil, string.format('Failed to decode binary length: %s', l)
  end
  if #bytes < l + 5 then
    return nil, string.format('Expected at least %s bytes found #s', l+5, #bytes)
  end
  local sub_type = bytes:byte(5)
  local ret = bytes:sub(6, l+6)
  return { bytes = ret, sub_type = sub_type }, l
end
decoders[0x05] = decode_binary

local function decode_nil(bytes)
  return nil, 0
end

--undefined
decoders[0x06] = decode_nil

local function decode_object_id(bytes)
  if #bytes < 12 then
    return nil, "ObjectId must be 12 bytes"
  end
  local values = bytes:sub(1, 12)
  return values, 12
end
decoders[0x07] = decode_object_id

local function decode_boolean(bytes) --
  if #bytes < 1 then
    return nil, "boolean value must be 1 byte"
  end
  local v = bytes:byte(1)
  return v > 0, 1
end
decoders[0x08] = decode_boolean

local function decode_int64(bytes) --
  local s, timestamp = pcall(string.unpack, '<i8', bytes)
  if not s then
    return nil, timestamp
  end
  return timestamp, 8
end
--UTC Datetime
decoders[0x09] = decode_int64

--null
decoders[0x0A] = decode_nil

local function decode_regex(bytes) --
  local pattern, len = read_c_string(bytes)
  local flags, f_len = read_c_string(bytes:sub(len+1))
  return {
    pattern = pattern,
    flags = flags,
  }, len + f_len
end
decoders[0x0B] = decode_regex

local function decode_db_pointer(bytes) --
  local collection, length = decode_string(bytes)
  local id = decode_object_id(bytes:sub(length+1))
  return {
    collection = collection,
    id = id
  }, length + 4
end
decoders[0x0C] = decode_db_pointer

--js code
decoders[0x0D] = decode_string
--Symbol
decoders[0x0E] = decode_string

local function decode_int32(bytes)
  local s, v = string.unpack('<i4', bytes)
  if not s then
    return nil, v
  end
  return v, 4
end

local function decode_js_with_scope(bytes)
  local id, id_len = decode_int32(bytes)
  local code, code_len = decode_string(bytes:sub(id_len))
  local scope, scope_len = decode_document(bytes:sub(id_len + code_len))
  return {id = id, code = code, scope = scope}, id_len + code_len + scope_len
end
decoders[0x0F] = decode_js_with_scope

--int32
decoders[0x10] = decode_int32

local function decode_timestamp(bytes)
    local s, v = string.unpack('I8', bytes)
    if not s then
      return nil, v
    end
    return v, 8
end
decoders[0x11] = decode_timestamp

--Int64
decoders[0x12] = decode_int64

local function decode_d128(bytes)
  --TODO, actually handle decoding
  local s = bytes:sub(1, 16)
  return s
end
decoders[0x13] = decode_d128

--Min key
decoders[0xFF] = decode_nil
--Max key
decoders[0x7F] = decode_nil

function Element.decode(bytes)
  local idx = 1
  local element_type, err
  element_type, err = utils.decode_u32(bytes:byte(idx, idx+1, idx+2, idx+3))
  if not element_type then
    return nil, err
  end
  idx = 5
  local decoder = decoders[element_type]
  if not decoder then
    return nil, string.format('Unknown element type', element_type)
  end
  local key, key_len = read_c_string(bytes:sub(idx))
  if not key then
    return nil, key_len
  end
  idx = idx + key_len
  local value, value_len = decoder(bytes:sub(idx))
  if not value then
    return nil, value_len
  end
  if bytes:byte(idx+1) ~= 0 then
    return nil, string.format('invalid document element, expected null byte found" %s', bytes:byte(idx+1))
  end
  return setmetatable({
    key = key,
    value = value,
  }, Element), 4 + key_len + value_len + 1
end

return Element
