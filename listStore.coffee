PouchDB = require './pouchdb'

class Store
  constructor: (name='main') ->
    @pouch = new PouchDB(name)

  getListsDefinitions: (cb) ->
    @pouch.get '_design/lists', (err, doc) ->
      if err
        if err.status == 404
          # 404 is a normal error, it just means the user hasn't
          # set up any definitions or orders for his card lists
          return cb null, null
        else
          return cb err

      lists = []
      for id in doc.order
        lists.push doc.definitions[id]
      cb null, lists

  setListsDefinitions: (definitions, cb) ->
    @pouch.get '_design/lists', (err, doc) ->
      if err
        if err.status == 404
          # 404 is a normal error, it just means the user hasn't
          # set up any definitions or orders for his card lists
          # so we will create this doc now
          doc =
            _id: '_design/lists'
            order: Object.keys definitions
        else
          return cb err

      doc.definitions = definitions
      @pouch.put(doc, cb)

  changePositionOf: (id, to, cb) ->
    @pouch.get '_design/lists', (err, doc) ->
      if err
        if err.status == 404
          # 404 is a normal error, it just means the user hasn't
          # set up any definitions or orders for his card lists
          # so we will create this doc now
          doc =
            _id: '_design/lists'
            order: Object.keys definitions
        else
          return cb err

      pos = doc.order.indexOf id
      thing = doc.order.splice pos, 1
      before = doc.order.slice 0, to
      after = doc.order.slice to
      doc.order = before.concat thing, after
      @pouch.put(doc, cb)
        
module.exports = Store
