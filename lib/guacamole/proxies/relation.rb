# -*- encoding: utf-8 -*-

require 'guacamole/proxies/proxy'
require 'guacamole/edge_collection'

module Guacamole
  module Proxies
    class Relation < Proxy
      def initialize(model, edge_class)
        responsible_edge_collection = EdgeCollection.for(edge_class)

        init model,
             -> () { responsible_edge_collection.neighbors(model, edges: responsible_edge_collection.collection_name) }
      end
    end
  end
end
