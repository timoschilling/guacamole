# -*- encoding : utf-8 -*-

require 'guacamole/collection'
require 'guacamole/graph_query'

require 'ashikawa-core'
require 'active_support'
require 'active_support/concern'
require 'active_support/core_ext/string/inflections'

module Guacamole
  module EdgeCollection
    extend ActiveSupport::Concern
    include Guacamole::Collection

    class << self
      def for(edge_class)
        collection_name = [edge_class.name.pluralize, 'Collection'].join

        collection_name.constantize
      rescue NameError
        create_edge_collection(collection_name)
      end

      def create_edge_collection(collection_name)
        new_collection_class = Class.new
        Object.const_set(collection_name, new_collection_class)
        new_collection_class.send(:include, Guacamole::EdgeCollection)
      end
    end

    module ClassMethods
      def graph
        @graph ||= Guacamole.configuration.graph
      end

      def connection
        @connection ||= graph.edge_collection(collection_name)
      end

      def edge_class
        @edge_class ||= model_class
      end

      def add_edge_definition_to_graph
        graph.add_edge_definition(collection_name,
                                  from: [edge_class.from],
                                  to: [edge_class.to])
      rescue
        # TODO: This case needs to be handled: Definition was already added to graph
      end

      def neighbors(model)
        query = GraphQuery.new(graph, mapper_for_target(model))
        query.neighbors(model, collection_name)
      end

      def mapper_for_target(model)
        vertex_mapper.find { |mapper| !mapper.responsible_for?(model) }
      end

      def mapper_for_start(model)
        vertex_mapper.find { |mapper| mapper.responsible_for?(model) }
      end

      def vertex_mapper
        [edge_class.from_collection, edge_class.to_collection].map(&:mapper)
      end
    end 

    included do
      add_edge_definition_to_graph
    end
  end
end
