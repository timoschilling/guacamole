function(params) {
    var db        = require("internal").db;
    var graph     = require("org/arangodb/general-graph")._graph(params.graph);
    var console   = require("console");
    var log_level = params['log_level'];

    var rubyObjectMap = {};

    console[log_level]("Input params for transaction: %o", params);

    var insertOrReplaceVertex = function(vertex) {
        var result;
        var _key = vertex._key;

        if (rubyObjectMap[vertex.object_id.toString()] !== undefined && (_key === undefined || _key == null)) {
          return true;
        }

        console[log_level]("The key for %o is: %s", vertex.document, _key);
        if (_key === undefined || _key == null) {
            result = graph[vertex.collection].save(vertex.document);
        } else {
            result = graph[vertex.collection].replace(_key, vertex.document);
        }
        vertex.document._key = result._key;
        vertex.document._rev = result._rev;
        vertex.document._id  = result._id;

        rubyObjectMap[vertex.object_id.toString()] = vertex.document;
        console[log_level]("Vertex: %o", vertex);
    }

    var insertOrReplaceConnection = function(edgeCollection) {
        edgeCollection.fromVertices.forEach(insertOrReplaceVertex);
        edgeCollection.toVertices.forEach(insertOrReplaceVertex);

        console[log_level]("Current map: %o", rubyObjectMap);
        console[log_level]("All the edges: %o", edgeCollection.edges);

        if (edgeCollection.oldEdges.length > 0) {
            var query          = "FOR e IN @@edge_collection FILTER POSITION(@keys, e._key, false) == true REMOVE e IN @@edge_collection";
            var bindParameters = { "@edge_collection": edgeCollection.name, "keys": edgeCollection.oldEdges }

            console[log_level](query);
            console[log_level](bindParameters);

            db._query(query, bindParameters);
        }

        edgeCollection.edges.forEach(function(edge) {
            console[log_level]("Current Edge: %o", edge);
            if (edge._from.toString().indexOf('/') == -1) {
                edge._from = rubyObjectMap[edge._from.toString()]._id;
            }
            if (edge._to.toString().indexOf('/') == -1) {
                edge._to = rubyObjectMap[edge._to.toString()]._id;
            }

            graph[edgeCollection.name].save(edge._from, edge._to, edge.attributes);
        });
    }

    params.edgeCollections.forEach(insertOrReplaceConnection);

    return rubyObjectMap;
}
