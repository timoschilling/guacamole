# -*- encoding: utf-8 -*-

require 'guacamole/proxies/proxy'
require 'guacamole/edge_collection'

module Guacamole
  module Proxies
    class Relation < Proxy
      def initialize(model, edge_class, just_one = false)
        responsible_edge_collection = EdgeCollection.for(edge_class)

        if just_one
          init model, -> () { responsible_edge_collection.neighbors(model).to_a.first }
        else
          init model, -> () { responsible_edge_collection.neighbors(model) }
        end
      end
    end
  end
end
