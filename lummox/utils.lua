local m = {}

function m.decode_u32(bytes)
  local s, v, l = pcall(string.unpack, '<I4', bytes)
  if not s then
    return nil, v
  end
  return v, l
end

function m.encode_u32(v)
  local s, v = pcall(string.pack, '<I4', v)
  if not s then
    return nil, v
  end
  return v
end

return m
