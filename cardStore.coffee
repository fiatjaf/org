EventEmitter = require 'event-emitter'
PouchDB = require './pouchdb'
Promise = require 'lie'

findUUIDs = require './find-uuids.js'

class Store
  constructor: (name='main') ->
    @pouch = new PouchDB(name)
    @pouch.put
      _id: '_design/pasargada'
      views: require './views'

  reset: ->
    @pouch.destroy => @emit 'CHANGE'

  save: (card) ->
    if card._rev
      card.edition = (new Date()).toISOString()
      r = @pouch.put card
    else
      card.creation = (new Date()).toISOString()
      r = @pouch.post card

    r.then => @emit 'CHANGE'

  delete: (card) ->
    @pouch.remove card, => @emit 'CHANGE'

  get: (id) ->
    @pouch.get(id)

  getWithRefs: (id) ->
    return new Promise (resolve, reject) =>
      # get this and cards referring this
      referred = @pouch.query('pasargada/refs',
        startkey: [id, {}]
        endkey: [id, null]
        descending: true
        include_docs: true
        reduce: false
      ).catch((x) => console.log x).then (res) =>
        card = res.rows[0].doc

        referring = {}
        for row in res.rows.slice(1)
          referring[row.key[1]] = referring[row.key[1]] or []
          referring[row.key[1]].push row.doc

        # get cards referred by this
        refs = findUUIDs card, card.type
        ids = []
        fields = []
        for ref in refs
          continue if ref[1] == card._id

          fields.push ref[0]
          ids.push ref[1]
        @pouch.allDocs(
          keys: ids
          include_docs: true
          reduce: false
        ).catch((x) -> console.log x).then (res) ->
          referred = {}
          for row, i in res.rows
            referred[fields[i]] = referred[fields[i]] or []
            referred[fields[i]].push row.doc

          resolve
            card: card
            referring: referring
            referred: referred

  allCards: (cb) ->
    return new Promise (resolve, reject) =>
      @pouch.query('pasargada/types'
        include_docs: true
      ).catch((x) -> console.log x).then (res) ->
        groups = {}
        for row in res.rows
          groups[row.key[0]] = groups[row.key[0]] or []
          groups[row.key[0]].push row.doc
        resolve groups

module.exports = EventEmitter(new Store())
