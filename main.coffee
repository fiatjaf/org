React          = require 'react'
cuid           = require 'cuid'
YAML           = {}
YAML.parse     = require('js-yaml').safeLoad
YAML.stringify = require('prettyaml').stringify
Store          = require './store.coffee'

store = new Store

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
    store.get(e.relatedTarget.dataset.id).then (draggedDoc) =>
      draggedDoc.type = listName
      store.save(draggedDoc).then => @fetchDocs()

  handleClickNewDoc: (listName, e) ->
    e.preventDefault()
    @setState
      selectedDocId: 'NEW'
      typeOfTheNewDoc: listName

  render: ->
    (div
      id: 'board'
      style:
        width: 310 * (Object.keys(@state.types).length + 1) + 400
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
  componentDidMount: ->
    interact(@getDOMNode())
      .dropzone(true)
      .accept('.doc pre')
      .on('dragenter', (e) ->
        #t = e.target
        #if e.target != e.relatedTarget.parentElement.parentElement
        #  draggieSize = e.relatedTarget.offsetHeight
        #  t.style.height = "#{t.offsetHeight + draggieSize}px"
      )
      .on('dragleave', (e) ->
        #setTimeout (-> e.target.style.height = ''), 1000
      )
      .on('drop', (e) =>
        @props.onDropDoc e
        #e.target.style.height = ''
      )

  render: ->
    (div className: "list",
      (h3 {}, @props.key)
      @props.children
      (button
        className: 'pure-button new-card'
        onClick: @props.onClickAddNewDoc
      , "create new #{@props.key} card")
    )

Doc = React.createClass
  handleClick: (e) ->
    e.preventDefault()
    @props.onClickEdit()

  componentDidMount: ->
    interact(@refs.pre.getDOMNode()).draggable
      onstart: (e) ->
        e.target.className = 'is-dragging'
      onmove: (e) ->
        t = e.target
        t.x = (t.x|0) + e.dx
        t.y = (t.y|0) + e.dy
        t.style.transform =
        t.style.webkitTransform =
        t.style.mozTransform = "translate(#{t.x}px, #{t.y}px)"
      onend: (e) ->
        e.target.className = ''
        t = e.target
        t.x = t.y = 0
        t.style.transform =
        t.style.webkitTransform =
        t.style.mozTransform = ''

  render: ->
    data = YAML.stringify @props.doc.data
    (div className: 'doc',
      (h4 {}, @props.doc._id)
      (pre
        ref: 'pre'
        'data-id': @props.doc._id
        onMouseUp: @handleClick
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
      doc.refs[groupName] = []
      store.save(doc).then (res) =>
        @loadDoc res.id

  docDroppedAtGroup: (groupName, droppedDocId, e) ->
    if @state.doc
      doc = @state.doc
      doc.refs[groupName].push droppedDocId
      store.save(doc).then (res) =>
        @props.afterSave res.id

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
        (h3 {}, if @state.doc._id then @state.doc._id else "new #{@state.doc.type} card")
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
  componentDidMount: ->
    interact(@getDOMNode())
      .dropzone(true)
      .accept('.doc pre')
      .on('dragenter', (e) ->
        t = e.target
        t.style.backgroundColor = 'beige'
      )
      .on('dragleave', (e) ->
        t = e.target
        t.style.backgroundColor = ''
      )
      .on('drop', (e) =>
        @props.onDocDropped @props.name, e.relatedTarget.dataset.id
        t = e.target
        e.target.style.backgroundColor = ''
      )

  render: ->
    docsdata = @props.docsdata or []

    (fieldset
      className: 'referred'
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
