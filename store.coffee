PouchDB = require 'pouchdb'
Promise = require 'lie'

class Store
  constructor: (name='main') ->
    @pouch = new PouchDB(name)
    @pouch.put
      _id: '_design/refs'
      views:
        'refs':
          map: (doc) ->
            for k, v of doc
              if typeof v is 'string' and v.slice(0, 4) == '_id-'
                emit [v.slice(4), doc.type, k]

  save: (doc) ->
    doc._id = (new Date()).toISOString()
    @pouch.put doc

  get: (id) ->
    return new Promise (resolve, reject) =>
      promises = []
      @pouch.get(id).then (doc) =>

        # get docs referenced by this
        for k, v of doc
          rids = []
          if typeof v is 'string' and v.slice(0, 4) == '_id-'
            rids.push v

        rfd = @pouch.allDocs(
          include_docs: true
          keys: rids
        ).then (res) =>
          for row in res.rows
            doc[k] = row.doc

        promises.push rfd

        # get docs referencing this
        rfr = @pouch.query('refs',
          descending: true
          include_docs: true
          startkey: [id, {}]
          endkey: [id]
        ).then (res) =>
          for row in res.rows
            doc[row.key[1]] = doc[row.key[1]] or []
            doc[row.key[1]].push row.doc

        promises.push rfr

        # when the two steps are complete, resolve
        Promise.all(promises).then ->
          resolve(doc)

  addIndex: (name, opts) ->
    _id = "_design/#{name}"
    @pouch.get(_id).then (doc) =>
      ddoc = doc or {_id: _id}
      ddoc.views = ddoc.views or {name: {}}
      ddoc.views[name].map = opts.map
      ddoc.views[name].reduce = opts.reduce if opts.reduce
      @pouch.put ddoc









