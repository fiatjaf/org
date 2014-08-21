PouchDB = require './pouchdb'
Promise = require 'lie'
cuid = require 'cuid'

class Store
  constructor: (name='main') ->
    @pouch = new PouchDB(name)
    @pouch.put
      _id: '_design/refs'
      views:
        'refs':
          map: ((doc) ->
            for k, rfid of doc.data
              if k[0] == '@'
                emit [rfid, doc.data.type, k]
          ).toString()
          reduce: '_count'

    @pouch.put
      _id: '_design/types'
      views:
        'types':
          map: ((doc) -> emit [doc.data.type, doc._id]).toString()
          reduce: '_count'

  save: (doc) ->
    doc._id = cuid() if not doc._id
    if doc._rev
      doc.edited = (new Date()).toISOString()
    else
      doc.created = (new Date()).toISOString()
    @pouch.put doc

  delete: (doc) ->
    @pouch.remove doc

  get: (id) ->
    return new Promise (resolve, reject) =>
      promises = []
      @pouch.get(id).then (doc) =>

        # get docs referenced by this
        for k, v of doc.data
          rids = {}
          if k[0] == '@'
            rids[v.slice(1 + v.indexOf '-')] = k
        rfd = @pouch.allDocs(
          include_docs: true
          keys: Object.keys rids
        ).then (res) =>
          for row in res.rows
            doc.data[rids[row.doc._id]] = row.doc.data

        promises.push rfd

        # get docs referencing this
        rfr = @pouch.query('refs',
          descending: true
          include_docs: true
          startkey: [id, {}]
          endkey: [id]
          reduce: false
        ).then (res) =>
          for row in res.rows
            doc.data[row.key[1]] = doc[row.key[1]] or []
            doc.data[row.key[1]].push row.doc.data

        promises.push rfr

        # when the two steps are complete, resolve
        Promise.all(promises).then ->
          resolve(doc)

  listTypes: ->
    return new Promise (resolve, reject) =>
      @pouch.query('types',
        include_docs: true
        descending: true
        reduce: false
      ).then (res) ->
        types = {}
        for row in res.rows
          if not types[row.key[0]]
            types[row.key[0]] = []
          types[row.key[0]].push row.doc
        resolve types

  addIndex: (name, map, reduce) ->
    views = {}
    views[name] = {
      map: map.toString()
    }
    views[name].reduce = reduce.toString() if reduce

    @pouch.put({
      _id: "_design/#{name}"
      views: views
    })

module.exports = Store
