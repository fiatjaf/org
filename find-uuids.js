module.exports = function findUUIDs (o, parentField) {
  var refs = []

  if (typeof o == 'string') {
    if (/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/i.test(o)) {
      var field = parentField
      refs.push([field, o])
    }
  }
  else if (typeof o == 'object' && Array.isArray(o)) {
    var field = parentField + '[]'
    for (var i = 0; i <= o.length; i++) {
      refs = refs.concat(findUUIDs(o[i], field))
    }
  }
  else if (o) {
    for (var key in o) {
      var value = o[key]
      var field = parentField + '.' + key
      refs = refs.concat(findUUIDs(value, field))
    }
  }

  return refs
}
