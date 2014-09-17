cuid           = require 'cuid'
YAML           = {}
YAML.parse     = require('js-yaml').safeLoad
YAML.stringify = require('prettyaml').stringify
CardStore      = require './cardStore.coffee'
Dispatcher     = require './dispatcher.coffee'

cardStore = new CardStore
dispatcher = new Dispatcher

{div, span, pre,
 small, i, p, a, button,
 h1, h2, h3, h4,
 form, legend, fieldset, input, textarea, select
 ul, li} = React.DOM

Board = React.createClass
  displayName: 'Board'
  getInitialState: ->
    typeGroupList: []
    selectedCardId: null

  componentDidMount: ->
    @fetchCards()

  fetchCards: ->
    cardStore.listTypes().then (typeGroupList) =>
      @setState typeGroupList: typeGroupList

  afterSave: (savedId) ->
    @fetchCards()
    if savedId == @state.selectedCardId
      @setState
        selectedCardId: null

  handleClickCard: (cardid) ->
    @setState selectedCardId: cardid

  handleCancelEdit: ->
    @setState selectedCardId: null

  handleAddList: (e) ->
    e.preventDefault()
    @state.typeGroupList.push
      name: cuid.slug()
      cards: []
    @setState typeGroupList: @state.typeGroupList

  handleCardDropped: (listName, e) ->
    cardStore.get(e.dataTransfer.getData 'cardId').then (draggedCard) =>
      draggedCard.type = listName
      cardStore.save(draggedCard).then => @fetchCards()

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
    (div
      id: 'board'
      style:
        width: 310 * (@state.typeGroupList.length + 1) + 400
      onMouseDown: @dragStart
      onMouseMove: @drag
      onMouseUp: @dragEnd
      onMouseOut: @dragEnd
    ,
      (List
        key: typeGroup.name
        onDropCard: @handleCardDropped.bind @, typeGroup.name
      ,
        (Card
          selected: (@state.selectedCardId == card._id)
          onClickEdit: @handleClickCard.bind @, card._id
          card: card,
          key: card._id
        ,
          (Editing
            cardid: card._id
            onCancel: @handleCancelEdit
            afterSave: @afterSave
            afterDelete: @fetchCards
          )
        ) for card in typeGroup.cards
        (div className: 'card',
          (Editing
            type: typeGroup.name
            afterSave: @afterSave
            afterDelete: @fetchCards
          )
        )
      ) for typeGroup in @state.typeGroupList
      (div
        className: 'list new'
        onClick: @handleAddList
      , 'new type')
    )

List = React.createClass
  displayName: 'List'
  getInitialState: ->
    height: ''

  onCardBeingDragged: (cardType) ->
    if cardType and cardType == @props.key
      return
    @setState height: "#{@getDOMNode().offsetHeight + 200}px"

  onCardNotBeingDraggedAnymore: ->
    @setState height: ''

  componentDidMount: ->
    dispatcher.on 'card.dragstart', @onCardBeingDragged
    dispatcher.on 'card.dragend', @onCardNotBeingDraggedAnymore

  componentWillUnmount: ->
    dispatcher.off 'card.dragstart', @onCardBeingDragged
    dispatcher.off 'card.dragend', @onCardNotBeingDraggedAnymore

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
      (h3 {}, @props.key)
      @props.children
    )

Card = React.createClass
  displayName: 'Card'
  getInitialState: -> {}

  handleClick: (e) ->
    e.preventDefault()
    @props.onClickEdit()

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
      content = @props.children
    else
      content = (div
        className: 'listed'
        onClick: @handleClick
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
      (h4 {onClick: @handleClick}, @props.card._id)
      content
    )

Editing = React.createClass
  displayName: 'Editing'
  getInitialState: ->
    textareaSize: 100

  componentWillMount: ->
    if @props.cardid
      @loadCard @props.cardid

  loadCard: (cardid) ->
    cardStore.getWithRefs(cardid).then (result) =>
      {card, referred, referring} = result
      yamlString = if typeof card.data is 'object' then YAML.stringify card.data else card.data
      @setState
        card: card
        referred: referred
        referring: referring
        yamlString: yamlString

  addReferredGroup: (e) ->
    e.preventDefault()
    groupName = cuid.slug()
    card = @state.card or {}
    card.refs = {} unless card.refs
    unless card.refs[groupName]
      card.refs[groupName] = {}
      cardStore.save(card).then (res) =>
        @loadCard res.id

  cardDroppedAtGroup: (groupName, droppedCardId, e) ->
    if @state.card
      card = @state.card
      card.refs[groupName][droppedCardId] = (new Date()).toISOString()
      cardStore.save(card).then (res) =>
        @props.afterSave res.id
        @loadCard res.id

  save: (e) ->
    e.preventDefault()
    card = @state.card or {}
    parsed = YAML.parse @state.yamlString

    # special cases of card data
    card.data = switch typeof parsed
      when 'object' then parsed
      when 'string' then @state.yamlString

    cardStore.save(card).then (res) =>
      @props.afterSave res.id
      if @props.cardid
        @loadCard res.id
      else
        @replaceState {textAreaSize: 100}

  delete: (e) ->
    e.preventDefault()
    if confirm 'Are you sure you want to delete ' + @state.card._id + '?'
      cardStore.delete(@state.card).then => @props.afterDelete()

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

  handleCancel: (e) ->
    e.preventDefault()
    if @props.onCancel
      @props.onCancel()
    else
      @setState card: null

  render: ->
    if not @state.card and not @props.cardid
      return (button
        className: 'pure-button new-card'
        onClick: @handleClickAddNewCard
      , "create new #{@props.type} card")

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
              onClick: @handleCancel
            , 'Cancel')
            (button
              className: 'pure-button delete'
              onClick: @delete
            , 'Delete') if @props.cardid
            (button
              className: 'pure-button save'
              onClick: @save
            , 'Save')
          )
        )
      )
    else
      return (div {})

ReferredGroup = React.createClass
  displayName: 'ReferredGroup'
  getInitialState: ->
    backgroundColor: ''

  dragOver: (e) -> e.preventDefault()
  dragEnter: (e) ->
    e.stopPropagation()
    @setState backgroundColor: 'beige'
  dragLeave: (e) ->
    @setState backgroundColor: ''
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
    cardStore.reset().then(location.reload)

  render: ->
    (div {id: 'main'},
      (button
        className: 'pure-button'
        onClick: @reset
      , 'RESET')
      Board()
    )

React.renderComponent Main(), document.body
