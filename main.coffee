React          = require 'react'
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
    editingDoc: null

  componentDidMount: ->
    @fetchDocs()

  fetchDocs: ->
    store.listTypes().then (types) =>
      @setState types: types

  handleClickDoc: (docid) ->
    store.getWithRefs(docid).then (result) =>
      {doc, referred, referring} = result
      @setState
        editingDoc: doc
        editingReferred: referred
        editingReferring: referring

  handleCancelEdit: (e) ->
    e.preventDefault()
    @setState
      editingDoc: null
      editingReferred: null
      editingReferring: null

  handleDocDropped: (listIdentifier, e) ->
    store.get(e.relatedTarget.dataset.id).then (draggedDoc) =>
      draggedDoc.data.type = listIdentifier
      store.save(draggedDoc).then => @fetchDocs()

  render: ->
    (div
      id: 'board'
      style:
        width: 310 * Object.keys(@state.types).length + 400
    ,
      (Editing
        doc: @state.editingDoc
        referred: @state.editingReferred
        referring: @state.editingReferring
        onCancel: @handleCancelEdit
        afterSave: @fetchDocs
        afterDelete: @fetchDocs
      )
      (List
        key: listName
        onDropDoc: @handleDocDropped.bind @, listName
      ,
        (Doc
          onClickEdit: @handleClickDoc.bind @, doc._id
          doc: doc,
          key: doc._id
        ) for doc in docs
      ) for listName, docs of @state.types
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
    yamlString: ''

  handleDocDropped: (e) ->
    if @props.doc
      doc = @props.doc
      store.get(e.relatedTarget.dataset.id).then (draggedDoc) =>
        addAs = prompt "add #{draggedDoc._id} to #{doc._id} as:"
        doc.refs = doc.refs or {}
        doc.refs[addAs] = draggedDoc._id
        store.save(doc).then => @fetchDocs()

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
        @handleDocDropped e
        #e.target.style.height = ''
      )

  componentWillReceiveProps: (nextProps) ->
    if not nextProps.doc
      doc = {data: {type: 'item'}}
    else
      doc = nextProps.doc

    @setState yamlString: YAML.stringify doc.data

  save: (e) ->
    e.preventDefault()
    doc = @props.doc or {}
    data = YAML.parse @state.yamlString
    doc.data = data
    store.save(doc).then => @props.afterSave()

  delete: (e) ->
    e.preventDefault()
    if confirm 'Are you sure you want to delete ' + @props.docs._id + '?'
      store.delete(doc).then => @props.afterDelete()

  handleChange: (e) ->
    @setState yamlString: e.target.value

  render: ->
    (form className: 'editing pure-form pure-form-stacked',
      (fieldset className: 'main',
        (h3 {}, if @props.doc then @props.doc._id else 'new card')
        (textarea
          value: @state.yamlString
          onChange: @handleChange
        )
      )
      (fieldset className: 'referred',
        (pre {}, YAML.stringify @props.referred)
      ) if @props.referred
      (fieldset className: 'referring',
        (pre {}, YAML.stringify @props.referring)
      ) if @props.referring
      (fieldset {},
        (button
          className: 'pure-button cancel'
          onClick: @props.onCancel
        , 'Cancel')
        (button
          className: 'pure-button delete'
          onClick: @delete
        , 'Delete') if @props.doc
        (button
          className: 'pure-button save'
          onClick: @save
        , 'Save')
      )
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
