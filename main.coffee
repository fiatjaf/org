cuid           = require 'cuid'
YAML           = {}
YAML.parse     = require('js-yaml').safeLoad
YAML.stringify = require('prettyaml').stringify
Store          = require './store.coffee'
Dispatcher     = require './dispatcher.coffee'

store = new Store
dispatcher = new Dispatcher

{div, span, pre,
 small, i, p, a, button,
 h1, h2, h3, h4,
 form, legend, fieldset, input, textarea, select
 ul, li} = React.DOM

Board = React.createClass
  getInitialState: ->
    types: {}
    selectedDocId: null

  componentDidMount: ->
    @fetchDocs()

  fetchDocs: ->
    store.listTypes().then (types) =>
      @setState types: types

  afterSave: (savedId) ->
    @setState
      selectedDocId: savedId
      typeOfTheNewDoc: undefined
    @fetchDocs()

  handleClickDoc: (docid) ->
    @setState
      selectedDocId: docid
      typeOfTheNewDoc: undefined

  handleCancelEdit: (e) ->
    e.preventDefault()
    @setState
      selectedDocId: null
      typeOfTheNewDoc: undefined

  handleAddList: (e) ->
    e.preventDefault()
    @state.types[cuid.slug()] = []
    @setState types: @state.types

  handleDocDropped: (listName, e) ->
    store.get(e.dataTransfer.getData 'docId').then (draggedDoc) =>
      draggedDoc.type = listName
      store.save(draggedDoc).then => @fetchDocs()

  handleClickNewDoc: (listName, e) ->
    e.preventDefault()
    @setState
      selectedDocId: 'NEW'
      typeOfTheNewDoc: listName

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
        width: 310 * (Object.keys(@state.types).length + 1) + 400
      onMouseDown: @dragStart
      onMouseMove: @drag
      onMouseUp: @dragEnd
      onMouseOut: @dragEnd
    ,
      (Editing
        docid: @state.selectedDocId
        typeOfTheNewDoc: @state.typeOfTheNewDoc
        onCancel: @handleCancelEdit
        afterSave: @afterSave
        afterDelete: @fetchDocs

      )
      (List
        key: listName
        onDropDoc: @handleDocDropped.bind @, listName
        onClickAddNewDoc: @handleClickNewDoc.bind @, listName
      ,
        (Doc
          onClickEdit: @handleClickDoc.bind @, doc._id
          doc: doc,
          key: doc._id
        ) for doc in docs
      ) for listName, docs of @state.types
      (div
        className: 'list new'
        onClick: @handleAddList
      , 'new type')
    )

List = React.createClass
  getInitialState: ->
    height: ''

  onDocBeingDragged: (docType) ->
    if docType and docType == @props.key
      return
    @setState height: "#{@getDOMNode().offsetHeight + 200}px"

  onDocNotBeingDraggedAnymore: ->
    @setState height: ''

  componentDidMount: ->
    dispatcher.on 'doc.dragstart', @onDocBeingDragged
    dispatcher.on 'doc.dragend', @onDocNotBeingDraggedAnymore

  componentWillUnmount: ->
    dispatcher.off 'doc.dragstart', @onDocBeingDragged
    dispatcher.off 'doc.dragend', @onDocNotBeingDraggedAnymore

  dragOver: (e) -> e.preventDefault()
  drop: (e) ->
    draggedDocId = e.dataTransfer.getData 'docId'
    @props.onDropDoc e
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
      (button
        className: 'pure-button new-card'
        onClick: @props.onClickAddNewDoc
      , "create new #{@props.key} card")
    )

Doc = React.createClass
  getInitialState: -> {}

  handleClick: (e) ->
    e.preventDefault()
    @props.onClickEdit()

  dragStart: (e) ->
    dispatcher.emit 'doc.dragstart', @props.doc.type
    e.dataTransfer.setData 'docId', @props.doc._id
    @setState dragging: true

  dragEnd: -> dispatcher.emit 'doc.dragend'

  render: ->
    data = YAML.stringify @props.doc.data

    (div
      className: 'doc'
      onClick: @handleClick
    ,
      (h4 {}, @props.doc._id)
      (pre
        className: if @state.dragging then 'dragging' else ''
        draggable: true
        onDragStart: @dragStart
        onDragEnd: @dragEnd
        ref: 'pre'
      , data)
    )

Editing = React.createClass
  getInitialState: ->
    doc: null
    referred: {}
    referring: {}
    yamlString: ''

  componentWillReceiveProps: (nextProps) ->
    if not nextProps.docid
      @setState
        doc: null
        referred: {}
        referring: {}
        yamlString: ''
    else if nextProps.docid == 'NEW' and nextProps.typeOfTheNewDoc
      doc = {type: nextProps.typeOfTheNewDoc, data: {}}
      @setState
        doc: doc
        referred: {}
        referring: {}
        yamlString: ''
    else
      @loadDoc nextProps.docid

  loadDoc: (docid) ->
    store.getWithRefs(docid).then (result) =>
      {doc, referred, referring} = result
      @setState
        doc: doc
        referred: referred
        referring: referring
        yamlString: YAML.stringify doc.data

  addReferredGroup: (e) ->
    e.preventDefault()
    groupName = cuid.slug()
    doc = @state.doc or {}
    doc.refs = {} unless doc.refs
    unless doc.refs[groupName]
      doc.refs[groupName] = {}
      store.save(doc).then (res) =>
        @loadDoc res.id

  docDroppedAtGroup: (groupName, droppedDocId, e) ->
    if @state.doc
      doc = @state.doc
      doc.refs[groupName][droppedDocId] = (new Date()).toISOString()
      store.save(doc).then (res) =>
        @props.afterSave res.id
        @loadDoc res.id

  save: (e) ->
    e.preventDefault()
    doc = @state.doc or {}
    data = YAML.parse @state.yamlString
    doc.data = data
    store.save(doc).then (res) =>
      @props.afterSave res.id

  delete: (e) ->
    e.preventDefault()
    if confirm 'Are you sure you want to delete ' + @state.docs._id + '?'
      store.delete(doc).then => @props.afterDelete()

  handleChange: (e) ->
    @setState yamlString: e.target.value

  render: ->
    if not @state.doc
      return (div {})

    (form className: 'editing pure-form pure-form-stacked',
      (fieldset className: 'main',
        (h3 {}, if not @state.doc._id then "new #{@state.doc.type} card" else '')
        (textarea
          value: @state.yamlString
          onChange: @handleChange
        )
      )
      (h3 {}, 'referenced by this:') if @state.doc.refs and Object.keys(@state.doc.refs).length
      (ReferredGroup
        name: groupName
        docsdata: @state.referred[groupName]
        onDocDropped: @docDroppedAtGroup
      ) for groupName of @state.doc.refs
      (button
        className: 'pure-button add-referred'
        onClick: @addReferredGroup
      , 'Add group of references') if @state.doc._id
      (h3 {}, 'referring this:') if Object.keys(@state.referring).length
      (fieldset className: 'referring',
        (h4 {}, type)
        (pre {}, YAML.stringify data) for data in docsdata
      ) for type, docsdata of @state.referring
      (fieldset {},
        (button
          className: 'pure-button cancel'
          onClick: @props.onCancel
        , 'Cancel')
        (button
          className: 'pure-button delete'
          onClick: @delete
        , 'Delete') if @state.doc
        (button
          className: 'pure-button save'
          onClick: @save
        , 'Save')
      )
    )

ReferredGroup = React.createClass
  getInitialState: ->
    backgroundColor: ''

  dragOver: (e) -> e.preventDefault()
  dragEnter: (e) ->
    @setState backgroundColor: 'beige'
  dragLeave: (e) ->
    @setState backgroundColor: ''
  drop: (e) ->
    draggedDocId = e.dataTransfer.getData 'docId'
    @props.onDocDropped @props.name, draggedDocId
    @setState backgroundColor: ''

  render: ->
    docsdata = @props.docsdata or []

    (fieldset
      className: 'referred'
      onDrop: @drop
      onDragOver: @dragOver
      onDragEnter: @dragEnter
      onDragLeave: @dragLeave
      style:
        backgroundColor: @state.backgroundColor
    ,
      (h4 {}, @props.name)
      (pre {}, YAML.stringify data) for data in docsdata
      (span {}, 'drop a card here') if not docsdata.length
    )

Main = React.createClass
  reset: (e) ->
    e.preventDefault()
    store.reset().then(location.reload)

  render: ->
    (div {id: 'main'},
      (button
        className: 'pure-button'
        onClick: @reset
      , 'RESET')
      Board()
    )

React.renderComponent Main(), document.body
