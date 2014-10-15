# youfle

The goal of **youfle** (this is probably a provisory name until I find something better, it is a mix of YAML and souflé, so cool, a souflé of YAMLs) is to make a nice customizable -- or usable as is -- base for CRUD apps. **youfle** relies on [PouchDB](https://github.com/pouchdb/pouchdb/), so it is offline-first, and can sync with a CouchDB instance.

The idea is to create a low-level (because it operates almost directly inside the database and can adapt to almost any data or database) interface for a Couch/Pouch database that normal people can use for categorizing stuff, managing business stuff and gaining insights about their data.

The YAML format is chosen, because it is thought (by me, in all my ignorance and prepotence) that it is understandable by any person, with a bit of training, to read and modify. Besides this, **youfle** should give immediate feedback and help the user to input the data in the correct format. Although this approach is not infallible, it is thought (again, by me) that it is better to do this than to write some, still very fallible, along with other problems, specific and limiting CRUD app interface.

# To test

Right now, the only thing **youfle** does is accept the creation of _cards_ that are organized in _Lists_, in a _Trello_ fashion. The only Lists currently available are the lists implied by the card _type_. Each card can have any structure you want (even pure text or invalid YAML) and hold any information you want, but if some card has, in any field, the value of the the \_id (as represented by an UUID) of other card, they will be related and shown together in their _View_ interface.

So, enter the [demo](http://fiatjaf.github.io/youfle/), create some cards and edit their content.

1. To edit: **Double-click the UUID of the card**
2. To view: **Click at the card content** (the `<pre>` tag with a YAML string)
3. To change the card type: **Drag the card to the other list**

# To give feedback

Give feedback. This is here only waiting for feedback. Any feedback is great. Don't be shy to file an issue, even you only have two words to say. Or send me an email or reach me via [Twitter](https://twitter.com/fiatjaf).

______

## To be implemented:

* Reusable CouchDB MapReduce interface in the form of Lists
* Full-text search for cards
* Other kinds of Lists (filter, group)
* Better visualization of links between cards
* Type templates/schemas for cards created on each type
* Live updates with PouchDB changes

## Ideas to be thinked of:

* A better format for presenting card information, instead of raw YAML
* Card-reducers: reduce all the info of any card to, for example, a single name, so it can be easily identified in lists
* Custom text parsers (for each type, along with type templates and schemas) to translate the input into structured data
