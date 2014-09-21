cuid           = require 'cuid'
parallel       = require 'run-parallel'
YAML           = {}
YAML.parse     = require('js-yaml').safeLoad
YAML.stringify = require('prettyaml').stringify

dispatcher = require './dispatcher.coffee'
store = require './store.coffee'

{div, span, pre,
 small, i, p, a, button,
 h1, h2, h3, h4,
 form, legend, fieldset, input, textarea, select
 ul, li} = React.DOM

Board = React.createClass
  displayName: 'Board'
  getInitialState: ->
    lists: []
    newLists: []

  componentDidMount: ->
    @fetchLists()
    dispatcher.on 'CHANGE', @fetchLists

  componentWillUnmount: ->
    dispatcher.off 'CHANGE', @fetchLists

  fetchLists: ->
    store.list.getListsDefinitions (err, listsDefinitions) =>
      # when there are no defined configurations for lists,
      # just show the types.
      if not listsDefinitions
        store.type.listTypes (err, types) =>
          @setState lists: ({
            id: type
            type: type
            label: type
            kind: 'type'
          } for type in types)
        return

      # a real error
      if err and err.status != 404
        return err

      lists = []
      for list in listsDefinitions
        if list.kind is 'type'
          lists.push
            id: list.type
            kind: 'type'
            type: list.type
            label: list.label or list.type
        else if list.kind is 'view'
          lists.push
            id: list.id
            kind: 'view'
            label: list.label or list.id
            reduced: list.reduced

      @setState lists: lists

  i: 0 # trello-like scrolling
  dragStart: (e) ->
    if e.target == @getDOMNode()
      @setState
        dragging: true
        startCoords:
          pageX: e.pageX
          pageY: e.pageY
          clientX: e.clientX
          clientY: e.clientY
  drag: (e) ->
    if @state.dragging
      e.preventDefault()
      @i++
      if @i % 3 == 0
        dx = @state.startCoords.pageX - e.pageX
        dy = @state.startCoords.pageY - e.pageY
        ax = window.pageXOffset || document.documentElement.scrollLeft
        ay = window.pageYOffset || document.documentElement.scrollTop
        window.scrollTo ax+dx, ay+dy
  dragEnd: ->
    if @state.dragging
      @setState dragging: false

  render: ->
    lists = @state.lists.concat @state.newLists

    (div
      id: 'board'
      style:
        width: 310 * (lists.length + 1) + 400
      onMouseDown: @dragStart
      onMouseMove: @drag
      onMouseUp: @dragEnd
      onMouseOut: @dragEnd
    ,
      (List
        key: list.id
        id: list.id
        label: list.label or list.id
        kind: list.kind
        onDropCard: @handleCardDropped.bind @, list.type
      ) for list in lists
      (div
        className: 'list new'
        onClick: @handleAddList
      , 'new type')
    )

  handleAddList: (e) ->
    e.preventDefault()
    id = cuid.slug()
    @state.newLists.push
      id: id
      kind: 'type'
      type: id
      label: id
    @setState newLists: @state.newLists

  handleCardDropped: (type, e) ->
    store.card.get e.dataTransfer.getData('cardId'), (err, draggedCard) =>
      draggedCard.type = type
      dispatcher.saveCard draggedCard

List = React.createClass
  displayName: 'List'
  getDefaultProps: ->
    limit: 10

  getInitialState: ->
    cards: []
    selectedCardId: null
    height: ''

  componentDidMount: ->
    dispatcher.on 'card.dragstart', @onCardBeingDragged
    dispatcher.on 'card.dragend', @onCardNotBeingDraggedAnymore
    @fetchCards @props.kind if @props.kind

  componentWillReceiveProps: (nextProps) ->
    @fetchCards nextProps.kind

  fetchCards: (kind) ->
    store[kind].getCards @props.id, @props.limit, (err, cards) =>
      @setState cards: cards

  componentWillUnmount: ->
    dispatcher.off 'card.dragstart', @onCardBeingDragged
    dispatcher.off 'card.dragend', @onCardNotBeingDraggedAnymore

  onCardBeingDragged: (cardType) ->
    if cardType and cardType == @props.key
      return
    @setState height: "#{@getDOMNode().offsetHeight + 200}px"

  onCardNotBeingDraggedAnymore: ->
    @setState height: ''

  dragOver: (e) -> e.preventDefault()
  drop: (e) ->
    e.stopPropagation()
    draggedCardId = e.dataTransfer.getData 'cardId'
    @props.onDropCard e
    @setState height: ''

  render: ->
    (div
      className: "list"
      onDragOver: @dragOver
      onDragEnter: @dragEnter
      onDragLeave: @dragLeave
      onDrop: @drop
      style:
        height: @state.height
    ,
      (h3 {}, @props.label)
      (div className: 'card',
        (Editing
          label: @props.label
          type: @props.id
          onCancel: @handleCancelEdit
        )
      )
      (Card
        selected: (@state.selectedCardId == card._id)
        onClickEdit: @handleClickEdit.bind @, card._id
        onCancelEdit: @handleCancelEdit
        card: card,
        key: card._id
        _id: card._id
      ) for card in @state.cards
    )

  handleClickEdit: (cardId, e) ->
    e.preventDefault()
    @setState selectedCardId: cardId

  handleCancelEdit: (e) ->
    e.preventDefault()
    @setState selectedCardId: null

Card = React.createClass
  displayName: 'Card'
  getInitialState: -> {}

  dragStart: (e) ->
    dispatcher.emit 'card.dragstart', @props.card.type
    e.dataTransfer.setData 'cardId', @props.card._id
    @setState dragging: true

  dragEnd: -> dispatcher.emit 'card.dragend'

  render: ->
    yamlString = switch typeof @props.card.data
      when 'object' then YAML.stringify @props.card.data
      else @props.card.data

    if @props.selected
      content =
        (Editing
          cardId: @props._id
          onCancel: @props.onCancelEdit
        )
 
    else
      content =
        (div
          className: 'listed'
          onClick: @props.onClickEdit
        ,
          (pre
            className: if @state.dragging then 'dragging' else ''
            draggable: true
            onDragStart: @dragStart
            onDragEnd: @dragEnd
            ref: 'pre'
          , yamlString)
        )

    (div
      className: 'card'
    ,
      (h4 {}, @props._id)
      content
    )

Editing = React.createClass
  displayName: 'Editing'
  getInitialState: ->
    textareaSize: 100

  componentWillMount: ->
    if @props.cardId
      @loadCard @props.cardId

  componentWillReceiveProps: (nextProps) ->
    if nextProps.cardId
      @loadCard nextProps.id
    else
      @replaceState {textAreaSize: 100}

  loadCard: (cardId) ->
    store.card.getWithRefs cardId, (err, result) =>
      {card, referred, referring} = result
      yamlString = if typeof card.data is 'object' then YAML.stringify card.data else card.data
      @setState
        card: card
        referred: referred
        referring: referring
        yamlString: yamlString

  render: ->
    if not @state.card and not @props.cardId
      return (button
        className: 'pure-button new-card'
        onClick: @handleClickAddNewCard
      , "create new #{@props.label} card")

    else if @state.card
      textareaHeight = @state.yamlString.split('\n').length * 18

      return (div className: 'editing',
        (form className: 'pure-form pure-form-stacked',
          (fieldset className: 'main',
            (h3 {}, if not @state.card._id then "new #{@state.card.type} card" else 'new')
            (textarea
              value: @state.yamlString
              onChange: @handleChange
              style:
                minHeight: if textareaHeight < 100 then 100 else textareaHeight
            )
          )
          (ReferredGroup
            key: groupName
            name: groupName
            cardsdata: @state.referred[groupName]
            onCardDropped: @cardDroppedAtGroup
          ) for groupName of @state.card.refs if @state.card.refs
          (button
            className: 'pure-button add-referred'
            onClick: @addReferredGroup
          , 'Add group of references') if @state.card._id
          (fieldset
            key: type
            className: 'referring'
          ,
            (h4 {}, type + ':')
            (pre {key: data.slice(0, 20) + data.slice(-20)},
              if typeof data is 'object' then YAML.stringify data else data
            ) for data in cardsdata
          ) for type, cardsdata of @state.referring
          (fieldset {},
            (button
              className: 'pure-button cancel'
              onClick: @props.onCancel
            , 'Cancel')
            (button
              className: 'pure-button delete'
              onClick: @delete
            , 'Delete') if @props.cardId
            (button
              className: 'pure-button save'
              onClick: @save
            , 'Save')
          )
        )
      )
    else
      return (div {})

  addReferredGroup: (e) ->
    e.preventDefault()
    groupName = cuid.slug()
    card = @state.card or {}
    card.refs = {} unless card.refs
    unless card.refs[groupName]
      card.refs[groupName] = {}
      dispatcher.saveCard card

  cardDroppedAtGroup: (groupName, droppedCardId, e) ->
    if @state.card
      card = @state.card
      card.refs[groupName][droppedCardId] = (new Date()).toISOString()
      dispatcher.saveCard card

  save: (e) ->
    e.preventDefault()
    dispatcher.saveCard @state.card or {}, @state.yamlString

  delete: (e) ->
    e.preventDefault()
    if confirm 'Are you sure you want to delete ' + @state.card._id + '?'
      dispatcher.deleteCard @state.card

  handleClickAddNewCard: (e) ->
    e.preventDefault()
    @setState
      card: {type: @props.type, data: {}}
      referred: {}
      referring: {}
      yamlString: ''

  handleChange: (e) ->
    @setState
      yamlString: e.target.value

ReferredGroup = React.createClass
  displayName: 'ReferredGroup'
  getInitialState: ->
    backgroundColor: ''

  dragOver: (e) -> e.preventDefault()
  dragEnter: (e) ->
    e.stopPropagation()
    @setState backgroundColor: 'beige'
  dragLeave: (e) -> @setState backgroundColor: ''
  drop: (e) ->
    e.stopPropagation()
    draggedCardId = e.dataTransfer.getData 'cardId'
    @props.onCardDropped @props.name, draggedCardId
    @setState backgroundColor: ''

  render: ->
    cardsdata = @props.cardsdata or []

    (fieldset
      className: 'referred'
      onDrop: @drop
      onDragOver: @dragOver
      onDragEnter: @dragEnter
      onDragLeave: @dragLeave
      style:
        backgroundColor: @state.backgroundColor
    ,
      (h4 {}, @props.name + ':')
      (pre {key: data.slice(0, 20) + data.slice(-20)},
        if typeof data is 'object' then YAML.stringify data else data
      ) for data in cardsdata
      (span {}, 'drop a card here') if not cardsdata.length
    )

Main = React.createClass
  displayName: 'Main'
  reset: (e) ->
    e.preventDefault()
    store.card.reset()

  render: ->
    (div {id: 'main'},
      (button
        className: 'pure-button'
        onClick: @reset
      , 'RESET')
      Board()
    )

React.renderComponent Main(), document.body
