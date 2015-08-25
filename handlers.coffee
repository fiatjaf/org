store = require './store'

handlers =
  cardsForList: (State, data) ->
    data.list
  editCard: (State, data) ->
    store.updateCard data
  newCard: (State, data) ->
    store.updateCard data

module.exports = handlers
