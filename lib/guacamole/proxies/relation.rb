# -*- encoding: utf-8 -*-

require 'guacamole/proxies/proxy'
require 'guacamole/edge_collection'

module Guacamole
  module Proxies
    class Relation < Proxy
      def initialize(model, edge_class, options = {})
        responsible_edge_collection = EdgeCollection.for(edge_class)

        direction = options[:inverse] ? :inbound : :outbound

        if options[:just_one]
          init model, -> () { responsible_edge_collection.neighbors(model, direction).to_a.first }
        else
          init model, -> () { responsible_edge_collection.neighbors(model, direction) }
        end
      end
    end
  end
end
