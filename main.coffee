React = require 'react'
Yaml  = require 'js-yaml'

{div, span, p,
 small, i, a, button,
 h1, h2, h3,
 form, input, textarea, select} = React.DOM

Board = React.createClass
  getInitialState: ->
    first = (new Date()).toISOString()
    docs = {}
    docs[first] = {
      _id: first
      data: {pli: 'plo', hu: 'aks'},
      style:
        position: 'absolute'
        left: 0
        top: 0
        width: 200
        height: 100
        border: '2px solid red'
    }
    return docs: docs

  dragOver: (e) ->
    e.preventDefault()

  drop: (e) ->
    e.preventDefault()
    offset = e.dataTransfer.getData('offset').split(',')
    docid = e.dataTransfer.getData('docid')
    docs = @state.docs
    doc = docs[docid]

    w = @getDOMNode().offsetWidth
    h = @getDOMNode().offsetHeight

    left = (e.clientX + parseInt(offset[0],10))
    top = (e.clientY + parseInt(offset[1],10))

    if left + doc.style.width > w
      doc.style.left = (w - doc.style.width)
    else if left < 0
      doc.style.left = 0
    else
      doc.style.left = left

    if top + doc.style.height > h
      doc.style.top = (h - doc.style.height)
    else if top < 0
      doc.style.top = 0
    else
      doc.style.top = top

    @setState docs: docs

  render: ->
    (div
      id: 'board'
      onDragOver: @dragOver
      onDrop: @drop
    , (Doc(doc: doc, key: id) for id, doc of @state.docs))

Doc = React.createClass
  dragStart: (e) ->
    style = window.getComputedStyle e.target, null
    offset = (parseInt(style.getPropertyValue("left"),10) - e.clientX) + ',' + (parseInt(style.getPropertyValue("top"),10) - e.clientY)
    e.dataTransfer.setData 'offset', offset
    e.dataTransfer.setData 'docid', @props.doc._id

  render: ->
    content = Yaml.safeDump @props.doc.data
    (div
      style: @props.doc.style
      draggable: true
      onDragStart: @dragStart
    , content)

React.renderComponent Board(), document.body
