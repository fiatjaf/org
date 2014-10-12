
var findUUIDs = function (o, parentField) {
  // finds uuids recursively.
  // returns an array of [uuid, field] descriptors
  if (!parentField) {
    parentField = o.type
    delete o._id
  }

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

module.exports = {
  types: {
    map: (function (doc) {
      if (doc.type) emit([doc.type, doc.creation])
    }).toString()
  },
  refs: {
    map: (function (doc) {

      var findUUIDs = expt
 
      var refs = findUUIDs(doc)
      for (var i = 0; i < ref.length; i++) {
        var uuid = refs[i][0]
        var field = refs[i][1]

        emit(['<-', uuid, field, doc._id])
        emit(['->', doc._id, field, uuid])
      }
    }).toString().replace('expt', findUUIDs.toString())
  },
}
