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

  handleClickDoc: (docid, e) ->
    e.preventDefault()
    store.get(docid).then (doc, referred, referring) =>
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
      (List {key: listName},
        (Doc
          onClickEdit: @handleClickDoc.bind @, doc._id
          doc: doc,
          key: doc._id
        ) for doc in docs
      ) for listName, docs of @state.types
    )

List = React.createClass
  render: ->
    (div className: 'list',
      (h3 {}, @props.key)
      @props.children
    )

Doc = React.createClass
  render: ->
    data = YAML.stringify @props.doc.data
    (div className: 'doc',
      (h4 {}, @props.doc._id)
      (pre
        onClick: @props.onClickEdit
      , data)
    )

Editing = React.createClass
  getInitialState: ->
    yamlString: ''

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
