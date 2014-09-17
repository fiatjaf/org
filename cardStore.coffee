PouchDB = require './pouchdb'
Promise = require 'lie'
R = require 'ramda'
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

    @pouch.put
      _id: '_design/types'
      views:
        'types':
          map: ((card) -> emit [card.type, card._id]).toString()
          reduce: '_count'

  reset: ->
    @pouch.destroy()

  save: (card) ->
    card._id = cuid() if not card._id
    card.type = cuid.slug() if not card._id
    if card._rev
      card.edited = (new Date()).toISOString()
    else
      card.created = (new Date()).toISOString()

    @pouch.put card

  delete: (card) ->
    @pouch.remove card

  get: (id) ->
    @pouch.get(id)

  getWithRefs: (id) ->
    return new Promise (resolve, reject) =>
      promises = []
      @pouch.get(id).catch((x) -> console.log x).then (card) =>

        # get cards referred by this
        refsList = getRefs card

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

        # get cards referring this
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
            card: card
            referred: refs[0]
            referring: refs[1]

  listTypes: ->
    return new Promise (resolve, reject) =>
      @pouch.query('types',
        include_docs: true
        descending: true
        reduce: false
      ).catch((x) -> console.log x).then (res) ->
        typeFromRow = R.compose R.head, R.get('key')
        typeGroupFromRows = (rows) -> {name: typeFromRow(rows[0]), cards: R.map(R.get('doc'), rows)}
        typeGroupList = R.values R.mapObj typeGroupFromRows, R.groupBy(typeFromRow, res.rows)
        resolve typeGroupList

module.exports = Store
