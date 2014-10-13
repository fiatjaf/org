YAML           = {}
YAML.parse     = require('js-yaml').safeLoad
YAML.stringify = require('prettyaml').stringify

YAML.stringifyCard = (card) ->
  card = JSON.parse JSON.stringify card
  delete card._id
  delete card._rev
  delete card.type
  delete card.creation
  delete card.edition

  if card.text and Object.keys(card).length == 1
    yamlString = card.text
  else
    yamlString = YAML.stringify card

  yamlString

YAML.parseCard = (yamlString, fullCard) ->
  try
    card = YAML.parse yamlString
    if typeof card is 'string'
      throw {}
  catch e
    card = {text: yamlString}

  card._id = fullCard._id
  card._rev = fullCard._rev
  card.type = fullCard.type
  card.creation = fullCard.creation
  card.edition = fullCard.edition
  card

module.exports = YAML
