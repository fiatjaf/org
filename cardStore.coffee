PouchDB = require './pouchdb'
parallel = require 'run-parallel'
cuid = require 'cuid'

getRefs = (card) ->
  refs = []
  for k, v of card.refs
    for subv, date of v
      refs.push [k, subv, date]
  return refs

class Store
  constructor: (name='main') ->
    @pouch = new PouchDB(name)
    @pouch.put
      _id: '_design/refs'
      views:
        'refs':
          map: """function (card) {
            var getRefs = #{getRefs.toString()}
            getRefs(card).forEach( function (ref) {
              var k = ref[0];
              var v = ref[1];
              var date = ref[2];
              emit([v, k, card.type, date]);
            })
          }"""
          reduce: '_count'

  reset: ->
    @pouch.destroy()

  save: (card, cb) ->
    card._id = cuid() if not card._id
    card.type = cuid.slug() if not card._id
    if card._rev
      card.edited = (new Date()).toISOString()
    else
      card.created = (new Date()).toISOString()

    @pouch.put card, cb

  delete: (card, cb) ->
    @pouch.remove card, cb

  get: (id, cb) -> @pouch.get id, cb

  getWithRefs: (id, cb) ->
    @pouch.get id, (err, card) =>
      return cb err if err

      parallel [
        ((callback) =>
          # get cards referred by this
          refsList = getRefs card
          @pouch.allDocs
            include_docs: true
            keys: (ref[1] for ref in refsList)
          , (err, res) ->
            return callback err if err

            fetched = {}
            for row in res.rows
              fetched[row.id] = row.doc.data

            referred = {}
            for ref in refsList
              group = ref[0]
              id = ref[1]
              referred[group] = referred[group] or []
              referred[group].push fetched[id]
            callback null, referred

        ), ((callback) =>
          # get cards referring this
          @pouch.query 'refs',
            descending: true
            include_docs: true
            startkey: [id, {}]
            endkey: [id]
            reduce: false
          , (err, res) ->
            return callback err if err

            referring = {}
            for row in res.rows
              referring['@' + row.key[1]] = referring['@' + row.key[1]] or []
              referring['@' + row.key[1]].push row.doc.data
            callback null, referring
        )
      ], (err, refs) =>
        return cb err if err
        cb null,
          card: card
          referred: refs[0]
          referring: refs[1]

module.exports = Store
