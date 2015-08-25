tl = require 'talio'

{div, main, span, pre, nav, section,
 small, i, p, b, a, button,
 h1, h2, h3, h4,
 form, legend, fieldset, input, textarea, select, label,
 table, thead, tbody, tfoot, tr, th, td,
 ul, li} = require 'virtual-elements'

store    = require './store'
handlers = require './handlers'
State    = tl.StateFactory require './basestate'

vrenderMain = (state, channels) ->
  (div id: 'board',
    (div className: 'list',
      (h2 {}, state.lists[listId]['#name'])
      (div
        className: 'card'
        'ev-click': tl.sendClick handlers.editCard, cardId
      , state.cards[cardId][state.lists[listId]['#display']]) for cardId in state.lists[listId].cards
    ) for listId in state.orderedLists
  )

# listen to pouchdb changes and update the state
feed = store.pouch.changes
  since: 'now'
  live: true
  include_docs: true
  returnDocs: false
feed.on 'error', console.log.bind console
feed.on 'change', (info) ->
  if info.doc['#type']
    wait = store.pouch.get()
  else if info.doc['#list'] and info.doc['_id']
    wait = Promise.resolve info.doc
  else
    return

  wait.then((list) ->
    store.cardsInList(list).then((docs) ->
      State.change "lists.#{info.doc._id}", info.doc
    )
  ).catch(console.log.bind console)

# initial state fetch
store.ready.then(->
  store.listsOrder().then((order) -> State.silentlyUpdate 'orderedLists', order)
  store.lists().then((lists) ->
    done = []
    for l in lists
      ((list) ->
        done.push store.cardsInList(list).then((cards) ->
          list.cards = []
          for c in cards
            State.silentlyUpdate "cards.#{c._id}", c
            list.cards.push c
          State.silentlyUpdate "lists.#{list._id}", list
        )
      )(l)
    return Promise.all(done)
  ).then(->
    State.change()
  ).catch(console.log.bind console)
)

# start app
tl.run document.body, vrenderMain, handlers, State
