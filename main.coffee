cuid           = require 'cuid'
YAML           = {}
YAML.parse     = require('js-yaml').safeLoad
YAML.stringify = require('prettyaml').stringify
M              = require 'moraerty'
I              = require 'immutable'
Store          = require './store.coffee'
Dispatcher     = require './dispatcher.coffee'

store = new Store
dispatcher = new Dispatcher

CTX = M.createContext React, I, {
  typeGroupLists: []
  selectedDocId: null
}

{div, span, pre,
 small, i, p, a, button,
 h1, h2, h3, h4,
 form, legend, fieldset, input, textarea, select
 ul, li} = React.DOM

Board = React.createClass
  displayName: 'Board'
  getInitialState: ->
    typeGroupList: []
    selectedDocId: null

  componentWillMount: ->
    CTX.init(@)

  componentDidMount: ->
    @fetchDocs()

  fetchDocs: ->
    store.listTypes().then (typeGroupList) =>
      @setState typeGroupList: typeGroupList

  afterSave: (savedId) ->
    @fetchDocs()
    if savedId == @state.selectedDocId
      @setState
        selectedDocId: null

  handleClickDoc: (docid) ->
    @setState selectedDocId: docid

  handleCancelEdit: ->
    @setState selectedDocId: null

  handleAddList: (e) ->
    e.preventDefault()
    @state.typeGroupList.push
      name: cuid.slug()
      docs: []
    @setState typeGroupList: @state.typeGroupList

  handleDocDropped: (listName, e) ->
    store.get(e.dataTransfer.getData 'docId').then (draggedDoc) =>
      draggedDoc.type = listName
      store.save(draggedDoc).then => @fetchDocs()

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
        onDropDoc: @handleDocDropped.bind @, typeGroup.name
      ,
        (Doc
          selected: (@state.selectedDocId == doc._id)
          onClickEdit: @handleClickDoc.bind @, doc._id
          doc: doc,
          key: doc._id
        ,
          (Editing
            docid: doc._id
            onCancel: @handleCancelEdit
            afterSave: @afterSave
            afterDelete: @fetchDocs
          )
        ) for doc in typeGroup.docs
        (div className: 'doc',
          (Editing
            type: typeGroup.name
            afterSave: @afterSave
            afterDelete: @fetchDocs
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
    e.stopPropagation()
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
    )

Doc = React.createClass
  displayName: 'Doc'
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
    yamlString = switch typeof @props.doc.data
      when 'object' then YAML.stringify @props.doc.data
      else @props.doc.data

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
      className: 'doc'
    ,
      (h4 {onClick: @handleClick}, @props.doc._id)
      content
    )

Editing = React.createClass
  displayName: 'Editing'
  getInitialState: ->
    textareaSize: 100

  componentWillMount: ->
    if @props.docid
      @loadDoc @props.docid

  loadDoc: (docid) ->
    store.getWithRefs(docid).then (result) =>
      {doc, referred, referring} = result
      yamlString = if typeof doc.data is 'object' then YAML.stringify doc.data else doc.data
      @setState
        doc: doc
        referred: referred
        referring: referring
        yamlString: yamlString

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
    parsed = YAML.parse @state.yamlString

    # special cases of doc data
    doc.data = switch typeof parsed
      when 'object' then parsed
      when 'string' then @state.yamlString

    store.save(doc).then (res) =>
      @props.afterSave res.id
      if @props.docid
        @loadDoc res.id
      else
        @replaceState {textAreaSize: 100}

  delete: (e) ->
    e.preventDefault()
    if confirm 'Are you sure you want to delete ' + @state.doc._id + '?'
      store.delete(@state.doc).then => @props.afterDelete()

  handleClickAddNewDoc: (e) ->
    e.preventDefault()
    @setState
      doc: {type: @props.type, data: {}}
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
      @setState doc: null

  render: ->
    if not @state.doc and not @props.docid
      return (button
        className: 'pure-button new-card'
        onClick: @handleClickAddNewDoc
      , "create new #{@props.type} card")

    else if @state.doc
      textareaHeight = @state.yamlString.split('\n').length * 18

      return (div className: 'editing',
        (form className: 'pure-form pure-form-stacked',
          (fieldset className: 'main',
            (h3 {}, if not @state.doc._id then "new #{@state.doc.type} card" else 'new')
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
            docsdata: @state.referred[groupName]
            onDocDropped: @docDroppedAtGroup
          ) for groupName of @state.doc.refs if @state.doc.refs
          (button
            className: 'pure-button add-referred'
            onClick: @addReferredGroup
          , 'Add group of references') if @state.doc._id
          (fieldset
            key: type
            className: 'referring'
          ,
            (h4 {}, type + ':')
            (pre {key: data.slice(0, 20) + data.slice(-20)},
              if typeof data is 'object' then YAML.stringify data else data
            ) for data in docsdata
          ) for type, docsdata of @state.referring
          (fieldset {},
            (button
              className: 'pure-button cancel'
              onClick: @handleCancel
            , 'Cancel')
            (button
              className: 'pure-button delete'
              onClick: @delete
            , 'Delete') if @props.docid
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
      (h4 {}, @props.name + ':')
      (pre {key: data.slice(0, 20) + data.slice(-20)},
        if typeof data is 'object' then YAML.stringify data else data
      ) for data in docsdata
      (span {}, 'drop a card here') if not docsdata.length
    )

Main = React.createClass
  displayName: 'Main'
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
