EventEmitter = require 'wolfy-eventemitter'
PouchDB = require './pouchdb'
Promise = require 'lie'

class Store extends EventEmitter.EventEmitter
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
    else
      card.creation = (new Date()).toISOString()

    @pouch.put card, => @emit 'CHANGE'

  delete: (card) ->
    @pouch.remove card, => @emit 'CHANGE'

  get: (id) ->
    @pouch.get(id)

  getWithRefs: (id) ->
    return new Promise (resolve, reject) =>
      promises = []
      @pouch.get(id).catch((x) -> console.log x).then (card) =>

        # get cards referred by this
        referred = @pouch.query('pasargada/refs',
          startkey: ['->', id, {}]
          endkey: ['->', id, null]
          descending: true
          include_docs: true
          reduce: false
        ).catch((x) -> console.log x).then (res) ->
          groups = {}
          for row in res.rows
            groups[row.key[2]] = groups[row.key[2]] or []
            groups[row.key[2]].push row.doc
          return groups
        promises.push referred

        # get cards referring this
        referring = @pouch.query('pasargada/refs',
          startkey: ['<-', id, {}]
          endkey: ['<-', id, null]
          descending: true
          include_docs: true
          reduce: false
        ).catch((x) -> console.log x).then (res) ->
          groups = {}
          for row in res.rows
            groups[row.key[2]] = groups[row.key[2]] or []
            groups[row.key[2]].push row.doc
          return groups
        promises.push referring

        # when the two steps are complete, resolve
        Promise.all(promises).catch((x) -> console.log x).then (refs) ->
          resolve
            card: card
            referred: refs[0]
            referring: refs[1]

  allCards: (cb) ->
    return new Promise (resolve, reject) ->
      @pouch.query('pasargada/types'
        include_docs: true
      ).catch((x) -> console.log x).then (res) ->
        groups = {}
        for row in res.rows
          groups[row.key[1]] = groups[row.key[1]] or []
          groups[row.key[1]].push row.doc
        return groups

module.exports = Store
