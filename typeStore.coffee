PouchDB = require './pouchdb'

class Store
  constructor: (name='main') ->
    @pouch = new PouchDB(name)
    @pouch.put
      _id: '_design/types'
      views:
        'types':
          map: ((card) -> emit [card.type, card.created, card._id]).toString()
          reduce: '_count'

  listTypes: (cb) ->
    @pouch.query 'types',
      reduce: true
      group_level: 1
    , (err, res) ->
      return cb err if err
      cb null, (row.key[0] for row in res.rows)

  getCards: (type, limit, cb) ->
    @pouch.query 'types',
      include_docs: true
      descending: true
      startkey: [type, {}]
      endkey: [type, null]
      limit: limit
      reduce: false
    , (err, res) ->
      return cb err if err

      cb null, (row.doc for row in res.rows) or []

module.exports = Store
