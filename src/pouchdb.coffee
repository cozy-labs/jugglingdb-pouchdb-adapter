fs = require 'fs'
pathHelpers = require 'path'
async = require 'async'
mkdirp = require 'mkdirp'
Pouch = require 'pouchdb'
indexer = require 'search-index'

module.exports.initialize = (@schema, callback) ->
    schema.adapter = new module.exports.PouchDB schema
    process.nextTick callback


class module.exports.PouchDB

    constructor: (@schema) ->
        @_models = {}
        dbName = process.env.POUCHDB_NAME || 'cozy'
        @db = new Pouch dbName
        @views = {}


    # Register Model to adapter and define extra methods
    define: (descr) ->
        descr.properties.docType = type: String, default: descr.model.modelName
        @_models[descr.model.modelName] = descr

        descr.model.search = (query, callback) =>
            @search descr.model.modelName, query, callback
        descr.model.defineRequest = (name, map, callback) =>
            @defineRequest descr.model.modelName, name, map, callback
        descr.model.request = (name, params, callback) =>
            @request descr.model.modelName, name, params, callback
        descr.model.rawRequest = (name, params, callback) =>
            @rawRequest descr.model.modelName, name, params, callback
        descr.model.removeRequest = (name, callback) =>
            @removeRequest descr.model.modelName, name, callback
        descr.model.requestDestroy = (name, params, callback) =>
            @requestDestroy descr.model.modelName, name, params, callback
        descr.model.all = (params, callback) =>
            @all descr.model.modelName, params, callback
        descr.model.destroyAll = (params, callback) =>
            @destroyAll descr.model.modelName, params, callback
        descr.model.applyRequest = (params, callback) =>
            @applyRequest descr.model.modelName, params, callback
        descr.model._forDB = (data) =>
            @_forDB descr.model.modelName, data
        descr.model::index = (fields, callback) ->
            @_adapter().index @, fields, callback
        descr.model::attachFile = (path, data, callback) ->
            @_adapter().attachFile  @, path, data, callback
        descr.model::getFile = (path, callback) ->
            @_adapter().getFile  @, path, callback
        descr.model::saveFile = (path, filePath, callback) ->
            @_adapter().saveFile  @, path, filePath, callback
        descr.model::removeFile = (path, callback) ->
            @_adapter().removeFile  @, path, callback
        descr.model::attachBinary = (path, data, callback) ->
            @_adapter().attachBinary  @, path, data, callback
        descr.model::getBinary = (path, callback) ->
            @_adapter().getBinary  @, path, callback
        descr.model::saveBinary = (path, filePath, callback) ->
            @_adapter().saveBinary  @, path, filePath, callback
        descr.model::removeBinary = (path, callback) ->
            @_adapter().removeBinary  @, path, callback


    # Check existence of model in the data system.
    exists: (model, id, callback) ->
        @db.get id, (err, doc) =>
            if err and not err.status is 404
                callback err
            else if err?.status is 404
                callback null, false
            else
                callback null, true


    # Find a doc with its ID. Returns it if it is found else it
    # returns null
    find: (model, id, callback) ->
        @db.get id, (err, doc) =>
            if err
                callback err
            else if not doc?
                callback null, null
            else if doc.docType.toLowerCase() isnt model.toLowerCase()
                callback null, null
            else
                callback null, new @_models[model].model(doc)


    # Create a new document from given data. If no ID is set a new one
    # is automatically generated.
    create: (model, data, callback) ->
        data.docType = model

        func = 'post'
        if data.id? or data._id?
            data.id = data._id unless data.id?
            data._id = data.id unless data._id?
            func = 'put'

        @db[func] data, (err, response) =>
            if err
                callback err
            else if not response.ok
                callback new Error 'An error occured while creating document.'
            else
                callback null, response.id


    # Save all model attributes to DB.
    save: (model, data, callback) ->
        data.docType = model
        @db.get data.id, (err, doc) =>
            if err
                callback err
            else if not doc?
                callback new Error 'document does not exist'
            else if doc.docType.toLowerCase() isnt model.toLowerCase()
                callback new Error 'document does not exist'
            else
                data._id = data.id
                data._rev = doc._rev
                @db.put data, (err, response) =>
                    if err
                        callback err
                    if not response.ok
                        callback new Error 'An error occured while saving document.'
                    else
                        callback()


    # Save only given attributes to DB.
    updateAttributes: (model, id, data, callback) ->
        data.id = id
        @save model, data, callback


    # Save only given attributes to DB. If model does not exist it is created.
    # It requires an ID.
    updateOrCreate: (model, data, callback) ->
        data.docType = model
        @save model, data, callback


    # Destroy model in database.
    # Call method like this:
    #     note = new Note id: 123
    #     note.destroy ->
    #         ...
    destroy: (model, id, callback) ->
        @db.get id, (err, doc) =>
            if err
                callback err
            else
                @db.remove doc, (err, response) ->
                    if err
                        callback err
                    else if not response.ok
                        callback new Error 'An error occured while deleting document.'
                    else
                        callback()


    # index given fields of model instance inside cozy data indexer.
    # it requires that note is saved before indexing, else it won't work
    # properly (it took data from db).
    # ex: note.index ["content", "title"], (err) ->
    #  ...
    #
    # TODO make search index silent.
    index: (model, fields, callback) ->
        doc = {}
        fields.push 'docType'
        for field in fields
            doc[field] = model[field]
        wrapper = {}
        wrapper[model.id] = doc

        indexer.add wrapper, 'index', fields, (msg) ->
            callback()


    # Retrieve note through index. Give a query then grab results.
    # ex: Note.search "dragon", (err, docs) ->
    # ...
    #
    search: (model, query, callback) ->
        q =
            query:
                '*': query.split(' ')
            offset: "0"
            pageSize: "20"
            filter:
                docType: model

        indexer.search q, (hits) =>
            results = []
            ids = []

            for hit in hits.hits
                ids.push hit.id

            async.eachSeries ids, (id, cb) =>
                @find model, id, (err, result) ->
                    results.push result unless err?
                    cb()

            , (err) ->
                callback err, results


    # Save a file into data system and attach it to current model.
    attachFile: (model, path, data, callback) ->
        if typeof data is 'function'
            callback = data

        folder = pathHelpers.join "attachments", model.id
        mkdirp folder, (err) ->
            if err then callback err
            else
                filename = pathHelpers.basename path
                filepath = pathHelpers.join folder, filename
                source = fs.createReadStream path
                target = fs.createWriteStream filepath
                source.on 'error', callback
                source.on 'end', callback
                source.pipe target


    # Get file stream of given file for given model.
    getFile: (model, path, callback) ->
        folder = pathHelpers.join "attachments", model.id
        filename = pathHelpers.basename path
        filepath = pathHelpers.join folder, filename
        source = fs.createReadStream filepath
        source.on 'error', callback
        source.on 'end', callback
        source


    # Save to disk given file for given model.
    saveFile: (model, path, filePath, callback) ->
        target = fs.createWriteStream filePath
        source = getFile model, path, callback
        source.on 'error', callback
        target.on 'finish', callback
        source.pipe target


    # Remove from db given file of given model.
    removeFile: (model, filename, callback) ->
        folder = pathHelpers.join "attachments", model.id
        filepath = pathHelpers.join folder, filename
        fs.unlink filepath, callback


    # Save a file into data system and attach it to current model.
    attachBinary: (model, path, data, callback) ->
        if typeof data is 'function'
            callback = data

        folder = pathHelpers.join "attachments", model.id
        mkdirp folder, (err) ->
            if err then callback err
            else
                filename = pathHelpers.basename path
                filepath = pathHelpers.join folder, filename
                source = fs.createReadStream path
                target = fs.createWriteStream filepath
                source.on 'error', callback
                source.on 'end', callback
                source.pipe target


    # Get file stream of given file for given model.
    getBinary: (model, path, callback) ->
        folder = pathHelpers.join "attachments", model.id
        filename = pathHelpers.basename path
        filepath = pathHelpers.join folder, filename
        source = fs.createReadStream filepath
        source.on 'error', callback
        source.on 'end', callback
        source


    # Save to disk given file for given model.
    saveBinary: (model, path, filePath, callback) ->
        target = fs.createWriteStream filePath
        source = getFile model, path, callback
        source.on 'error', callback
        target.on 'finish', callback
        source.pipe target


    # Remove from db given file of given model.
    removeBinary: (model, path, callback) ->
        folder = pathHelpers.join "attachments", model.id
        filepath = pathHelpers.join folder, filename
        fs.unlink filepath, callback


    # Check if an error occurred. If any, it returns a proper error.
    checkError: (error, response, body, code, callback) ->
        if error
            callback error
        else if response.statusCode isnt code
            msgStatus = "expected: #{code}, got: #{response.statusCode}"
            msg = "#{msgStatus} -- #{body.error}"
            callback new Error msg
        else
            callback null


    # Create a new couchdb view which is typed with current model type.
    defineRequest: (model, name, request, callback) ->
        if typeof(request) is "function"
            map = request
        else
            map = request.map
            reduce = request.reduce

        qs = map.toString()
        qs = qs.substring 'function(doc) {'.length
        qs = qs.substring 0, (qs.length - 1)
        stringquery = "if (doc.docType.toLowerCase() === " + \
                      "\"#{model.toLowerCase()}\") #{qs.toString()}};"
        stringquery = stringquery.replace '\n', ''

        map = new Function "doc", stringquery
        if reduce?
            view =
                map: map
                reduce: reduce
        else
            view = map

        name = "_design/#{model.toLowerCase()}/#{name}"
        @views[name] = view
        callback()
        #@db.get name, (err, designDoc) =>
        #    unless designDoc?
        #        designDoc =
        #            _id: name
        #            views: {}
        #    unless designDoc.views?
        #        designDoc.views = {}
        #    designDoc.views[name] = view
        #    @db.put designDoc, stale: 'update_after', (err, designDoc) ->
        #        callback()


    # Return defined request result.
    request: (model, name, params, callback) ->
        if typeof(params) is "function"
            callback = params
            params = {}

        name = '_design/' + model.toLowerCase() + '/' + name
        view = @views[name]
        @db.query view, params, (err, body) =>
            if err
                callback err
            else
                results = []
                for doc in body.rows
                    doc.value.id = doc.value._id
                    results.push new @_models[model].model(doc.value)
                callback null, results


    # Return defined request result in the format given by data system
    # (couchDB style).
    rawRequest: (model, name, params, callback) ->
        if typeof(params) is "function"
            callback = params
            params = {}

        name = '_design/' + model.toLowerCase() + '/' + name
        view = @views[name]
        @db.query view, params, (err, body) =>
            if err
                callback err
            else
                callback null, body


    # Delete request that match given name for current type.
    removeRequest: (model, name, callback) ->
        name = '_design/' + model.toLowerCase() + '/' + name
        delete @views[name]
        callback()


    # Delete all results that should be returned by the request.
    requestDestroy: (model, name, params, callback) ->
        if typeof(params) is "function"
            callback = params
            params = {}

        @request model, name, params, (err, docs) ->
            if err
                callback err
            else
                async.eachSeries docs, (doc, cb) ->
                    doc.destroy cb
                , (err) ->
                    callback err


    # Shortcut for "all" view, a view containing all objects of this type.
    # This method is useful because Juggling make some usage of it for joins.
    # This requires that view all exist for this object.
    all: (model, params, callback) ->
        view = "all"
        if params?.view?
            view = params.view
            delete params.view

        @request model, view, params, callback


    # Shortcut for destroying all documents from "all" view,
    # This requires that view all exist for this object.
    destroyAll: (model, params, callback) ->
        view = "all"
        if params?.view?
            view = params.view
            delete params.view

        @requestDestroy model, view, params, callback


    # Weird rewrite due to a juggling DB on array parsing.
    _forDB: (model, data) ->
        res = {}
        Object.keys(data).forEach (propName) =>
            if @whatTypeName(model, propName) is 'JSON'
                res[propName] = JSON.stringify(data[propName])
            else
                res[propName] = data[propName]
        return res


    # Weird rewrite due to a juggling DB on array parsing.
    whatTypeName: (model, propName) ->
        ds = @schema.definitions[model]
        return ds.properties[propName] && ds.properties[propName].type.name


# Send mail
exports.sendMail = (data, callback) ->
    callback new Error 'not implemented yet'


# Send mail to user
exports.sendMailToUser = (data, callback) ->
    callback new Error 'not implemented yet'


# Send mail from user
exports.sendMailFromUser = (data, callback) ->
    callback new Error 'not implemented yet'


exports.commonRequests =
    checkError: (err) ->
        console.log "An error occured while creating request" if err

    all: -> emit doc._id, doc
    allType: -> emit doc.docType, doc
    allSlug: -> emit doc.slug, doc
    allDate: -> emit doc.date, doc
