YAML           = require './yaml.coffee'
cardStore      = require './cardStore.coffee'
dispatcher     = require './dispatcher.coffee'

{div, span, pre,
 small, i, p, a, button,
 h1, h2, h3, h4,
 form, legend, fieldset, input, textarea, select
 ul, li} = React.DOM

Board = React.createClass
  displayName: 'Board'
  getInitialState: ->
    cardsByType: {}
    editingCardId: null
    viewingCardId: null

  componentDidMount: ->
    @fetchCards()
    cardStore.on 'CHANGE', @fetchCards
  componentWillUnmount: -> cardStore.off 'CHANGE', @fetchCards
  fetchCards: -> cardStore.allCards().then (cardsByType) => @setState cardsByType: cardsByType

  handleViewCard: (cardid) -> @setState viewingCardId: cardid
  handleEditCard: (cardid) -> @setState editingCardId: cardid
  handleCancelEdit: -> @setState editingCardId: null

  handleCardDropped: (listName, e) ->
    cardStore.get(e.dataTransfer.getData 'cardId').then (draggedCard) =>
      draggedCard.type = listName
      cardStore.save(draggedCard)

  addCard: ->
    type = prompt 'Which type?'
    cardStore.save({type: type})

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
        width: 310 * (Object.keys(@state.cardsByType).length + 1) + 400
      onMouseDown: @dragStart
      onMouseMove: @drag
      onMouseUp: @dragEnd
      onMouseOut: @dragEnd
    ,
      (List
        key: type
        onDropCard: @handleCardDropped.bind @, type
      ,
        (Card
          editing: (@state.editingCardId == card._id)
          onView: @handleViewCard.bind @, card._id
          onEdit: @handleEditCard.bind @, card._id
          card: card,
          key: card._id
        ,
          (Editing
            cardid: card._id
            onCancel: @handleCancelEdit
          )
        ) for card in cards
        (div className: 'card',
          (Editing
            type: type
            template: @templates[type] if @templates
          )
        )
      ) for type, cards of @state.cardsByType
      (button
        onClick: @addCard
      , 'Add card')
      (View cardid: @state.viewingCardId)
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

  dragStart: (e) ->
    dispatcher.emit 'card.dragstart', @props.card.type
    e.dataTransfer.setData 'cardId', @props.card._id
    @setState dragging: true

  dragEnd: -> dispatcher.emit 'card.dragend'

  render: ->
    yamlString = YAML.stringifyCard @props.card

    if @props.editing
      content = @props.children
    else
      content = (div
        className: 'listed'
        onClick: @handleClick
      ,
        (pre
          className: if @state.dragging then 'dragging' else ''
          onClick: @props.onView
          draggable: true
          onDragStart: @dragStart
          onDragEnd: @dragEnd
          ref: 'pre'
        , yamlString)
      )

    (div
      className: 'card'
    ,
      (h4 {onDoubleClick: @props.onEdit}, @props.card._id)
      content
    )

View = React.createClass
  displayName: 'View'
  getInitialState: ->
    card: {}
    referred: {}
    referring: {}

  loadCard: (cardid) ->
    cardStore.getWithRefs(@props.cardid).then (result) =>
      {card, referred, referring} = result
      @setState
        card: card
        referred: referred
        referring: referring

  render: ->
    (div className: 'overlay',
      (div className: 'referring',

      )
      (div className: 'card',

      )
      (div className: 'referred',

      )
    )

Editing = React.createClass
  displayName: 'Editing'
  getInitialState: ->
    textareaSize: 100

  componentWillMount: ->
    if @props.cardid
      @loadCard @props.cardid

  loadCard: (cardid) ->
    cardStore.get(cardid).then (card) =>
      @setState
        card: card
        yamlString: YAML.stringifyCard card

  save: (e) ->
    e.preventDefault()
    card = YAML.parseCard @state.yamlString, @state.card
    cardStore.save(card)

  delete: (e) ->
    e.preventDefault()
    if confirm 'Are you sure you want to delete ' + @state.card._id + '?'
      cardStore.delete(@state.card)

  handleClickAddNewCard: (e) ->
    e.preventDefault()

    card = @props.template or {type: @props.type}
    card.type = @props.type

    @setState
      card: card
      yamlString: YAML.stringifyCard card

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
      (Board {})
    )

React.renderComponent Main(), document.body
