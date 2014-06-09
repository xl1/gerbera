module.exports = (ary, func) ->
  ary.reduce (result, x) ->
    result.concat func x
  , []
