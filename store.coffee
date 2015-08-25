window.PouchDB = PouchDB = require 'pouchdb'

Promise = require 'lie'
extend  = require 'xtend'
cuid    = require 'cuid'

PouchDB.plugin require 'pouchdb-find'
PouchDB.debug.enable 'pouchdb:find'

class Store
  constructor: ->
    @pouch = window.pouch = new PouchDB('base')

    @ready = Promise.all([
      @pouch.createIndex
        name: 'list-lists'
        index: { fields: ['#list'] }
        ddoc: 'youfle'
    ,
      @pouch.createIndex
        name: 'find-id-for-type-name'
        index: { fields: ['#name'] }
        ddoc: 'youfle'
    ,
      @pouch.createIndex
        name: 'docs-default'
        index: { fields: ['#type', '#created'] }
        ddoc: 'youfle'
    ]).catch(console.log.bind console)
  save: (type, doc) ->
    doc._id = doc._id or cuid.slug()
    date = (new Date).toISOString()
    now = date.split('T')[0]
    now = now.concat date.split('T')[1].split('.')[0].split(':')
    doc['#updated'] = now
    doc['#created'] = if doc['#created'] then doc['#created'] else now
    Promise.resolve().then(->
      @pouch.find
        selector: { '#name': type }
        fields: ['_id']
        limit: 1
    ).then((res) ->
      typeId = res.docs[0]._id
      doc['#type'] = typeId
      @pouch.put doc
    ).catch(console.log.bind console)
  newList: (name, doc) ->
    doc._id = cuid.slug()
    doc['#name'] = name
    @pouch.put(doc).catch(console.log.bind console)
  listsOrder: ->
    @pouch.get('list-order').then((doc) ->
      if doc
        return doc.order
      else
        @pouch.find(
          selector: { '#list': { '$exists': true } }
          fields: ['_id']
        )
    ).catch(console.log.bind console)
  lists: ->
    @pouch.find(
      selector: { '#list': { '$exists': true } }
    ).then((res) -> res.docs).catch(console.log.bind console)
  cardsInList: (list, page=0) ->
    # find docs for this list
    if list['#filter']
      @pouch.find(
        selector: { '#type': list['#list'] }
        sort: [_id: 'desc']
        limit: 100
      ).then((res) ->
        ret = []
        for doc in res.docs
          pass = true
          for field, val of list['#filter']
            if doc[field] != val
              pass = false
              break
          if pass == true
            ret.push doc
        return ret
      ).catch(console.log.bind console)
    else
      @pouch.find(
        selector: { type: list['#list'] }
        sort: [_id: 'desc']
        limit: 15
      ).then((res) -> res.docs).catch(console.log.bind console)

store = new Store

# initial lists
store.newList 'clients',
  '#list': 'client'
  '#baseSchema':
    name: true
    phone: true
  '#display': 'name'
store.newList 'items',
  '#list': 'item'
  '#baseSchema':
    name: true
    status: true
    price: true
    client: true
  '#display': 'name'
store.newList 'manufacturing',
  '#list': 'item'
  '#filter':
    status: 'manufacturing'
  '#display': 'name'
store.newList 'done',
  '#list': 'item'
  '#filter':
    status: 'done'
  '#display': 'name'
# ~
# initial docs
store.save 'item',
  status: 'manufacturing'
  name: 'metal ring'
store.save 'item',
  status: 'done'
  name: 'golden necklace'
store.save 'client',
  name: 'Amadeus'
store.save 'client',
  name: 'Alphonsus'
  phone: '354896137'
# ~

module.exports = store
