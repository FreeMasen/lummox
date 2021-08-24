local utils = require "lummox.utils"
math.randomseed(os.time()) 

describe("Utils", function()
  it("round trip encode/decode", function()
    for i = 0, 10000 do
      local test_value = math.random(0, 0xffffffff)
      assert.are.equal(test_value, utils.decode_u32(utils.encode_u32(test_value)))
    end
  end)
end)
