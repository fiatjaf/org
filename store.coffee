CardStore = require './cardStore.coffee'
ListStore = require './listStore.coffee'
TypeStore = require './typeStore.coffee'
ViewStore = require './viewStore.coffee'

module.exports =
  card: new CardStore
  list: new ListStore
  type: new TypeStore
  view: new ViewStore
