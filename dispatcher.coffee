EventEmitter = require 'wolfy-eventemitter'
YAML           = {}
YAML.parse     = require('js-yaml').safeLoad
YAML.stringify = require('prettyaml').stringify

store = require './store.coffee'

class Dispatcher extends EventEmitter.EventEmitter
  construct: ->

  saveCard: (card, yamlString) ->
    if yamlString
      parsed = YAML.parse yamlString

      # special cases of card data
      card.data = switch typeof parsed
        when 'object' then parsed
        when 'string' then yamlString

    store.card.save card, (err, res) =>
      @emit "CHANGE"

  deleteCard: (card) ->
    store.card.delete card

  reset: ->
    store.card.reset location.reload

module.exports = new Dispatcher
