PouchDB = require './pouchdb'
Promise = require 'lie'
cuid = require 'cuid'

getRefs = (doc) ->
  refs = []
  for k, v of doc.data
    if k[0] == '@'
      if v.push # array
        for subv in v
          refs.push [k, subv]
      else if typeof v == 'string' # string
        refs.push [k, v]
  return refs

class Store
  constructor: (name='main') ->
    @pouch = new PouchDB(name)
    @pouch.put
      _id: '_design/refs'
      views:
        'refs':
          map: """function (doc) {
            var getRefs = #{getRefs.toString()}
            getRefs(doc).forEach( function () {
              var k = ref[0];
              var v = ref[1];
              emit([v, doc.data.type, k]);
            })
          }"""
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

    # bring back hidden refs
    if doc.refs
      for k, v of doc.refs
        doc.data[k] = v
      delete doc.refs

    # check ref integrity
    for ref in getRefs doc
      v = ref[1]
      if typeof v isnt 'string'
        throw Error('ref is not string: ' + v)

    @pouch.put doc

  delete: (doc) ->
    @pouch.remove doc

  get: (id) ->
    return new Promise (resolve, reject) =>
      promises = []
      @pouch.get(id).catch(-> console.log arguments).then (doc) =>

        # get docs referenced by this
        rids = {}
        for ref in getRefs doc
          k = ref[0]
          v = ref[1]
          rids[v] = k

        # hide the refs
        doc.refs = {}
        for k, v of doc.data
          if k[0] == '@'
            doc.refs[k] = v
            delete doc.data[k]

        rfd = @pouch.allDocs(
          include_docs: true
          keys: Object.keys rids
        ).catch(-> console.log arguments).then (res) =>
          for row in res.rows
            if not doc.data[rids[row.doc._id]]
              # it is nothing, just add
              doc.data[rids[row.doc._id]] = row.doc.data
            else if doc.data[rids[row.doc._id]].push
              # more than two (it is already an array)
              doc.data[rids[row.doc._id]].push row.doc.data
            else if typeof doc.data[rids[row.doc._id]] == 'object'
              # more than one referred doc (change it from object to array)
              doc.data[rids[row.doc._id]] = [doc.data[rids[row.doc._id]]]
              doc.data[rids[row.doc._id]].push row.doc.data

        promises.push rfd

        # get docs referencing this
        rfr = @pouch.query('refs',
          descending: true
          include_docs: true
          startkey: [id, {}]
          endkey: [id]
          reduce: false
        ).catch(-> console.log arguments).then (res) =>
          for row in res.rows
            doc.data[row.key[1]] = doc.data[row.key[1]] or []
            doc.data[row.key[1]].push row.doc.data

        promises.push rfr

        # when the two steps are complete, resolve
        Promise.all(promises).catch(-> console.log arguments).then ->
          resolve(doc)

  listTypes: ->
    return new Promise (resolve, reject) =>
      @pouch.query('types',
        include_docs: true
        descending: true
        reduce: false
      ).catch(-> console.log arguments).then (res) ->
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
