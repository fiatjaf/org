var findUUIDs = require('./find-uuids.js')

module.exports = {
  'types': {
    map: (function (doc) {
      if (doc.type) emit([doc.type, doc.creation])
    }).toString()
  },
  'refs': {
    map: (function (doc) {

      var findUUIDs = '_fu_'

      var refs = findUUIDs(doc, doc.type)

      refs.forEach(function (ref) {
        var field = ref[0]
        var uuid = ref[1]
        if (doc._id == uuid) return

        // to grab this card when it is referring the actually queried card
        emit([uuid, field])
      })

      // to grab the card itself in the same call
      emit([doc._id, {}])

    }).toString().replace("'_fu_'", findUUIDs.toString())
  },
}
