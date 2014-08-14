## About

*jugglingdb-pouchdb-adapter* is an 
[JugglingDB](https://github.com/1602/jugglingdb "JugglingDB") adapter to make
usage of [PouchDB](http://pouchdb.com/) easy.


## Usage

Init database then define your models:

```coffeescript
schema = new Schema 'pouchdb-adapter', dbName: 'pouchdb'

Note = schema.define 'Note', 
    id: String
    title: String
    content: String
    creationDate: Date
```


### Documents

```coffeescript
# Existence
Note.exists 123, (err, isExist) ->
    console.log isExist

# Find
Note.find 321, (err, note) ->
    console.log note

# Create
Note.create { id: "321", "content":"created value"}, (err, note) ->
    console.log note.id

# Update
note.save (err) ->
    console.log err

# Update attributes
note.updateAttributes title: "my new title", (err) ->
    console.log err

# Upsert
Note.createOrUpdate @data.id, (err, note) ->
    console.log err

# Delete
note.destroy (err) ->
    console.log err
```


### Indexation

```coffeescript
# Index document fields
note.index ["title", "content"], (err) ->
    console.log err

# Search through indexes
Note.search "dragons", (err, notes) ->
    console.log notes
```


### Files

```coffeescript
# Attach file
note.attachFile "./test.png", (err) ->
    console.log err

# Get file
stream = @note.getFile "test.png", (err) ->
     console.log err
stream.pipe fs.createWriteStream('./test-get.png')
```


### Requests

```coffeescript
# Define request
map = (doc) ->
    emit doc._id, doc
    return

Note.defineRequest "every_notes", map, (err) ->
    console.log err

# Get request results
Note.request "every_notes", (err, notes) ->
    console.log notes

# Destroy documents through request results
Note.requestDestroy "every_notes", {key: ids[3]}, (err) ->

# Remove request
Note.removeRequest "every_notes", (err) ->
     console.log err
```


## Build & tests

To build source to JS, run

    cake build

To run tests:

    cake tests

## What is Cozy?

![Cozy Logo](https://raw.github.com/mycozycloud/cozy-setup/gh-pages/assets/images/happycloud.png)

[Cozy](http://cozy.io) is a platform that brings all your web services in the
same private space.  With it, your web apps and your devices can share data
easily, providing you with a new experience. You can install Cozy on your own
hardware where no one profiles you. 

## Community 

You can reach the Cozy Community by:

* Chatting with us on IRC #cozycloud on irc.freenode.net
* Posting on our [Forum](https://groups.google.com/forum/?fromgroups#!forum/cozy-cloud)
* Posting issues on the [Github repos](https://github.com/mycozycloud/)
* Mentioning us on [Twitter](http://twitter.com/mycozycloud)
