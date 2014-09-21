PouchDB = require './pouchdb'
Promise = require 'lie'

class Store
  constructor: (name='main') ->
    @pouch = new PouchDB(name)

module.exports = Store
