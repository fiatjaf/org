PouchDB = require './pouchdb'
Promise = require 'lie'
cuid = require 'cuid'

getRefs = (doc) ->
  refs = []
  for k, v of doc.refs
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
          map: """function (doc) {
            var getRefs = #{getRefs.toString()}
            getRefs(doc).forEach( function (ref) {
              var k = ref[0];
              var v = ref[1];
              var date = ref[2];
              emit([v, k, doc.type, date]);
            })
          }"""
          reduce: '_count'

    @pouch.put
      _id: '_design/types'
      views:
        'types':
          map: ((doc) -> emit [doc.type, doc._id]).toString()
          reduce: '_count'

  reset: ->
    @pouch.destroy()

  save: (doc) ->
    doc._id = cuid() if not doc._id
    doc.type = cuid.slug() if not doc._id
    if doc._rev
      doc.edited = (new Date()).toISOString()
    else
      doc.created = (new Date()).toISOString()

    @pouch.put doc

  delete: (doc) ->
    @pouch.remove doc

  get: (id) ->
    @pouch.get(id)

  getWithRefs: (id) ->
    return new Promise (resolve, reject) =>
      promises = []
      @pouch.get(id).catch((x) -> console.log x).then (doc) =>

        # get docs referred by this
        refsList = getRefs doc

        referred = @pouch.allDocs(
          include_docs: true
          keys: (ref[1] for ref in refsList)
        ).catch((x) -> console.log x).then (res) =>

          fetched = {}
          for row in res.rows
            fetched[row.id] = row.doc.data

          result = {}
          for ref in refsList
            group = ref[0]
            id = ref[1]
            result[group] = result[group] or []
            result[group].push fetched[id]
          return result

        promises.push referred

        # get docs referring this
        referring = @pouch.query('refs',
          descending: true
          include_docs: true
          startkey: [id, {}]
          endkey: [id]
          reduce: false
        ).catch((x) -> console.log x).then (res) =>
          result = {}
          for row in res.rows
            result['@' + row.key[1]] = result['@' + row.key[1]] or []
            result['@' + row.key[1]].push row.doc.data
          return result

        promises.push referring

        # when the two steps are complete, resolve
        Promise.all(promises).catch((x) -> console.log x).then (refs) ->
          resolve
            doc: doc
            referred: refs[0]
            referring: refs[1]

  listTypes: ->
    return new Promise (resolve, reject) =>
      @pouch.query('types',
        include_docs: true
        descending: true
        reduce: false
      ).catch((x) -> console.log x).then (res) ->
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
