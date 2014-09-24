should = require 'should'
async = require 'async'
fs = require "fs"

PouchDB = require 'pouchdb'
Schema = require('jugglingdb').Schema
PouchAdapter = require("./src/pouchdb").PouchDB

getNewSchema = (name) ->
    schema = new Schema 'memory'
    schema.settings = {}
    schema.adapter = new PouchAdapter schema, name

    schema.Note = schema.define 'Note',
        title:
            type: String
        content:
            type: Schema.Text
        author:
            type: String

    schema.MailBox = schema.define 'MailBox',
        name:
            type: String

    return schema


describe "Existence", ->

    before (done) ->
        @schema = getNewSchema 'test-01'
        @schema.adapter.db.put _id: '321', (err, response) ->
            done()

    after (done) ->
        @schema.adapter.db.destroy done

    describe "Check Existence of a Document that does not exist in database", ->

        it "When I check existence of Document with id 123", \
                (done) ->
            @schema.Note.exists '123', (err, isExist) =>
                should.not.exist err
                @isExist = isExist
                done()

        it "Then false should be returned", ->
            @isExist.should.not.be.ok

    describe "Check Existence of a Document that does exist in database", ->

        it "When I check existence of Document with id 321", \
                (done) ->
            @schema.Note.exists '321', (err, isExist) =>
                should.not.exist err
                @isExist = isExist
                done()

        it "Then true should be returned", ->
            @isExist.should.be.ok


describe "Find", ->

    before (done) ->
        @schema = getNewSchema 'test-02'
        data =
            _id: '321'
            title: "my note"
            content: "my content"
            docType: "Note"

        @schema.adapter.db.put data, (response) ->
            done()

    after (done) ->
        @schema.adapter.db.destroy done

    describe "Find a note that does not exist in database", ->

        it "When I claim note with id 123", (done) ->
            @schema.Note.find '123', (err, note) =>
                @note = note
                done()

        it "Then null should be returned", ->
            should.not.exist @note

    describe "Find a note that does exist in database", ->

        it "When I claim note with id 321", (done) ->
            @schema.Note.find '321', (err, note) =>
                console.log note
                @note = note
                done()

        it "Then I should retrieve my note ", ->
            should.exist @note
            @note.title.should.equal "my note"
            @note.content.should.equal "my content"


describe "Create", ->

    before (done) ->
        @schema = getNewSchema 'test-03'
        done()

    after (done) ->
        @schema.adapter.db.destroy done

    describe "Create a new Document without an id", ->

        before ->
            @id = null

        after (done) ->
            @note.destroy =>
                @err = null
                @note = null
                done()

        it "When I create a document without an id", (done) ->
            @schema.Note.create { "title": "cool note", "content": "new note" }, \
                    (err, note) =>
                @err = err if err
                @note = note
                done()

        it "Then the id of the new Document should be returned", ->
            should.not.exist @err
            should.exist @note.id
            @id = @note.id

        it "And the Document should exist in Database", (done) ->
            @schema.Note.exists  @id, (err, isExist) =>
                should.not.exist err
                isExist.should.be.ok
                done()

        it "And the Document in DB should equal the sent Document", (done) ->
            @schema.Note.find  @id, (err, note) =>
                should.not.exist err
                note.id.should.equal @id
                note.content.should.equal "new note"
                done()

    describe "Create a new Document with a given id", ->

        before ->
            @id = "987"

        after ->
            @err = null
            @note = null

        it "When I create a document with id 987", (done) ->
            @schema.Note.create { id: @id, "content": "new note" }, (err, note) =>
                @err = err
                @note = note
                done()

        it "Then this should be set on document", ->
            should.not.exist @err
            should.exist @note
            @note.id.should.equal @id

        it "And the Document with id 987 should exist in Database", (done) ->
            @schema.Note.exists @id, (err, isExist) =>
                should.not.exist err
                isExist.should.be.ok
                done()

        it "And the Document in DB should equal the sent Document", (done) ->
            @schema.Note.find @id, (err, note) =>
                should.not.exist err
                note.id.should.equal @id
                note.content.should.equal "new note"
                done()


describe "Update", ->

    before (done) ->
        data =
            id: "321"
            title: "my note"
            content: "my content"
            docType: "Note"

        @schema = getNewSchema 'test-04'
        @note = new @schema.Note data

        @schema.Note.create data, (err, note) =>
            @err = err if err
            @note = note
            done()

    after (done) ->
        @schema.adapter.db.destroy done

    describe "Try to Update a Document that doesn't exist", ->
        after ->
            @err = null

        it "When I update a document with id 123", (done) ->
            @note.id = "123"
            @note.save (err) =>
                @err = err
                done()

        it "Then no error is returned", ->
            should.not.exist @err

        it "And a new doc is created", ->
            should.exist @note.id

    describe "Update an existing document", ->

        it "When I update document with id 321", (done) ->
            @note.id = "321"
            @note._id = "321"
            @note.title = "my new title"
            @note.save (err) =>
                @err = err
                done()

        it "Then no error is returned", ->
            should.not.exist @err

        it "And the old document must have been replaced in DB", (done) ->
            @schema.Note.find @note.id, (err, updatedNote) =>
                should.not.exist err
                updatedNote.id.should.equal "321"
                updatedNote.title.should.equal "my new title"
                done()


describe "Update attributes", ->

    before (done) ->
        data =
            id: "321"
            title: "my note"
            content: "my content"
            docType: "Note"

        @schema = getNewSchema 'test-05'
        @schema.Note.create data, (err, note) =>
            @err = err if err
            @note = note
            done()

    after (done) ->
        @schema.adapter.db.destroy done


    describe "Update a Document", ->

        it "When I update document with id 321", (done) ->
            @note.id = "321"
            @note.updateAttributes title: "my new title", (err) =>
                @err = err
                done()

        it "Then no error is returned", ->
            should.not.exist @err

        it "And the old document must have been replaced in DB", (done) ->
            @schema.Note.find @note.id, (err, updatedNote) =>
                should.not.exist err
                updatedNote.id.should.equal "321"
                updatedNote.title.should.equal "my new title"
                done()


describe "Delete", ->
    before (done) ->
        data =
            id: "321"
            title: "my note"
            content: "my content"
            docType: "Note"

        @schema = getNewSchema 'test-06'
        @schema.Note.create data, (err, note) =>
            @err = err if err
            @note = note
            done()

    after (done) ->
        @schema.adapter.db.destroy done


    describe "Deletes a document that is not in Database", ->

        it "When I delete Document with id 123", (done) ->
            note = new @schema.Note id: "123"
            note.destroy (err) =>
                @err = err
                done()

        it "Then an error should be returned", ->
            should.exist @err

    describe "Deletes a document from database", ->

        it "When I delete document with id 321", (done) ->
            note = new @schema.Note id: "321"
            note.destroy (err) =>
                @err = err
                done()

        it "Then no error is returned", ->
            should.not.exist @err

        it "And Document with id 321 shouldn't exist in Database", (done) ->
            @schema.Note.exists "321", (err, isExist) =>
                isExist.should.not.be.ok
                done()


docs = [
    { title: "Note 01", content: "little stories begin", docType: "Note", _id: "100" }
    { title: "Note 02", content: "dragons are coming", docType: "Note", _id: "200" }
    { title: "Note 03", content: "hobbits are afraid", docType: "Note", _id: "300" }
    { title: "Note 04", content: "such as humans", docType: "Note", _id: "400" }
    { description: "Task 01", docType: "Task", _id: "500" }
    { description: "Task 02", docType: "Task", _id: "600" }
    { description: "Task 03", docType: "Task", _id: "700" }
]

describe "Requests", ->

    before (done) ->
        @ids = []

        @schema = getNewSchema 'test-07'
        async.eachSeries docs, (doc, callback) =>
            @schema.adapter.db.post doc, (err, newDoc) =>
                @ids.push newDoc.id
                callback()
        , (err) ->
            done()

    after (done) ->
        @schema.adapter.db.destroy done


    describe "View creation", ->

        describe "Creation of the first view + design document creation", ->

            it "When I send a request to create view every_docs", (done) ->
                delete @err
                @map = (doc) ->
                    emit doc._id, doc
                    return
                @schema.Note.defineRequest "every_notes", @map, (err) ->
                    should.not.exist err
                    done()


    describe "Access to a view without option", ->

        describe "Access to a non existing view", ->

            it "When I send a request to access view dont-exist", (done) ->
                delete @err
                @schema.Note.request "dont-exist", (err, notes) =>
                    @err = err
                    should.exist err
                    done()


        describe "Access to an existing view : every_notes", (done) ->

            it "When I send a request to access view every_docs", (done) ->
                delete @err
                @schema.Note.request "every_notes", (err, notes) =>
                    @notes = notes
                    done()

            it "Then I should have 4 documents returned", ->
                @notes.should.have.length 4

        describe "Access to a doc from a view : every_notes", (done) ->

            it "When I send a request to access doc 3 from every_docs", \
                    (done) ->
                delete @err
                data = key: @ids[3]
                @schema.Note.request "every_notes", data, (err, notes) =>
                    @notes = notes
                    done()

            it "Then I should have 1 documents returned", ->
                @notes.should.have.length 1
                @notes[0].id.should.equal @ids[3]

    describe "Deletion of docs through requests", ->

        describe "Delete a doc from a view : every_notes", (done) ->

            it "When I send a request to delete a doc from every_docs", \
                    (done) ->
                data = key: @ids[3]
                @schema.Note.requestDestroy "every_notes", data, (err) ->
                    should.not.exist err
                    done()

            it "And I send a request to access view every_notes", (done) ->
                delete @err
                delete @notes
                data = key: @ids[3]
                @schema.Note.request "every_notes", data, (err, notes) =>
                    @notes = notes
                    done()

            it "Then I should have 0 documents returned", ->
                @notes.should.have.length 0

            it "And other documents are still there", (done) ->
                @schema.Note.request "every_notes", (err, notes) =>
                    should.not.exist err
                    notes.should.have.length 3
                    done()

        #describe "Delete all doc from a view : every_notes", (done) ->

            #it "When I delete all docs from every_docs", (done) ->
                #Note.requestDestroy "every_notes", (err) ->
                    #should.not.exist err
                    #done()

            #it "And I send a request to grab all docs from every_docs", \
                    #(done) ->
                #delete @err
                #delete @notes
                #Note.request "every_notes", (err, notes) =>
                    #@notes = notes
                    #done()

            #it "Then I should have 0 documents returned", ->
                #@notes.should.have.length 0
                #

### Attachments ###

describe "Attachments", ->

    before (done) ->
        @schema = getNewSchema 'test-06'
        data =
            title: "my note"
            content: "my content"
            docType: "Note"

        @schema.Note.create data, (err, note) =>
            @err = err if err
            @note = note
            done()

    after (done) ->
        @schema.adapter.db.destroy done

    describe "Add an attachment", ->

        it "When I add an attachment", (done) ->
            @note.attachFile "./test.png", (err) =>
                @err = err
                done()

        it "Then no error is returned", ->
            should.not.exist @err

    describe "Retrieve an attachment", ->

        it "When I claim this attachment", (done) ->
            stream = @note.getFile "test.png", -> done()
            stream.pipe fs.createWriteStream('./test-get.png')

        it "Then I got the same file I attached before", ->
            fileStats = fs.statSync('./test.png')
            resultStats = fs.statSync('./test-get.png')
            resultStats.size.should.equal fileStats.size

    describe "Remove an attachment", ->

        it "When I remove this attachment", (done) ->
            @note.removeFile "test.png", (err) =>
                @err = err
                done()

        it "Then no error is returned", ->
            should.not.exist @err

        it "When I claim this attachment", (done) ->
            stream = @note.getFile "test.png", (err) =>
                @err = err
                done()
            stream.pipe fs.createWriteStream('./test-get.png')

        it "Then I got an error", ->
            should.exist @err
