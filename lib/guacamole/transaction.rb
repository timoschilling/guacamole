# -*- encoding : utf-8 -*-

require 'ashikawa-core'

module Guacamole
  class Transaction
    extend Forwardable
    def_delegators :collection, :mapper, :database

    attr_reader :collection, :model

    class TxEdgeCollection
      attr_reader :edge_collection, :model, :ea, :to_models, :from_models, :old_edges

      def initialize(ea, model)
        @ea              = ea
        @model           = model
        @edge_collection = EdgeCollection.for(ea.edge_class)

        init
      end

      def init
        case model
        when ea.edge_class.from_collection.model_class
          @from_models = [model]
          @to_models   = [ea.get_value(model)].compact.flatten
          @old_edges   = edge_collection.by_example(_from: model._id).map(&:key)
        when ea.edge_class.to_collection.model_class
          @to_models   = [model]
          @from_models = [ea.get_value(model)].compact.flatten
          @old_edges   = edge_collection.by_example(_to: model._id).map(&:key)
        else
          raise RuntimeError
        end
      end

      def select_mapper
        select_mapper = ->(m) { edge_collection.mapper_for_start(m) }
      end

      def from_vertices
        from_models.map do |m|
          {
            object_id: m.object_id,
            collection: edge_collection.edge_class.from_collection.collection_name,
            document: select_mapper.call(m).model_to_document(m),
            _key: m.key,
            _id: m._id
          }
        end
      end

      def to_vertices
        to_models.map do |m|
          {
            object_id: m.object_id,
            collection: edge_collection.edge_class.to_collection.collection_name,
            document: select_mapper.call(m).model_to_document(m),
            _key: m.key,
            _id: m._id
          }
        end
      end

      def to_vertices_with_only_existing_documents
        to_vertices.select { |v| v[:_key].nil?  }
      end

      def edges
        from_vertices.each_with_object([]) do |from_vertex, edges|
          to_vertices.each do |to_vertex|
            edges << {
              :_from => from_vertex[:_id] || from_vertex[:object_id],
              :_to   => to_vertex[:_id]   || to_vertex[:object_id],
              :attributes => {}
            }
          end
        end
      end

      def edge_collection_for_transaction
        {
          name: edge_collection.collection_name,
          fromVertices: from_vertices,
          toVertices: to_vertices_with_only_existing_documents,
          edges: edges,
          oldEdges: old_edges
        }
      end
    end

    class << self
      def run(options)
        new(options).execute_transaction
      end
    end

    def initialize(options)
      @collection = options[:collection]
      @model      = options[:model]
    end

    def edge_collections
      mapper.edge_attributes.each_with_object([]) do |ea, edge_collections|
        edge_collections << prepare_edge_collection_for_transaction(ea)
      end
    end

    def prepare_edge_collection_for_transaction(ea)
      TxEdgeCollection.new(ea, model).edge_collection_for_transaction
    end

    def write_collections
      edge_collections.map do |ec|
        [ec[:name]] +
          ec[:fromVertices].map { |fv| fv[:collection] } +
          ec[:toVertices].map { |tv| tv[:collection] }
      end.flatten.uniq.compact
    end

    def read_collections
      write_collections
    end

    def transaction_params
      {
        edgeCollections: edge_collections,
        graph: Guacamole.configuration.graph.name,
        log_level: 'debug'
      }
    end

    def execute_transaction
      transaction.execute(transaction_params)
    end

    def transaction_code
      File.read(Guacamole.configuration.shared_path.join('transaction.js'))
    end

    private

    def transaction
      transaction = database.create_transaction(transaction_code,
                                                write: write_collections,
                                                read:  read_collections)
      transaction.wait_for_sync = true

      transaction
    end
  end
end
