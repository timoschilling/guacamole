# -*- encoding : utf-8 -*-

module Guacamole
  # Build an AQL query for ArangoDB
  class AqlQuery < Query
    # The AQL fragment to be added into the complete query
    attr_accessor :aql_fragment

    # The associated collection
    attr_reader :collection

    # The additional options
    attr_reader :options

    # Create a new AqlQuery
    #
    # @param [Guacamole::Collection] collection The collection class to be used
    # @param [Class] mapper The class of the mapper to use
    # @param [Hash] options Additional options for query execution
    # @option options [String] :return_as ('RETURN #{model_name}') A custom `RETURN` statement
    # @option options [Boolean] :mapping (true) Should the mapping be performed?
    def initialize(collection, mapper, options = {})
      @collection = collection
      super(collection.connection.query, mapper)
      @options = default_options.merge(options)
    end

    # Set the bind parameters
    #
    # @param [Hash] bind_parameters All the bind parameters
    def bind_parameters=(bind_parameters)
      @options[:bind_vars] = bind_parameters
    end

    # Get the bind parameters
    #
    # @return [Hash] All the bind parameters
    def bind_parameters
      @options[:bind_vars]
    end

    # Creates an AQL string based on the `aql_fragment`,
    # the collection and model information.
    #
    # @return [String] An AQL string ready to be send to Arango
    def aql_string
      aql_string = "#{for_in} #{aql_fragment} #{return_as}"
      Guacamole.logger.debug "[AQL] #{aql_string} | bind_parameters: #{bind_parameters}"
      aql_string
    end

    # The RETURN part of the query
    #
    # @return [String] Either the default `RETURN model_name` or a custom string
    def return_as
      options[:return_as]
    end

    def for_in
      options[:for_in]
    end

    # Should the mapping step be perfomed? If set to false we will return the raw document.
    #
    # @return [Boolean] Either if the mapping should be perfomed or not
    def perform_mapping?
      options[:mapping]
    end

    # The default options to be set for the query
    #
    # @return [Hash] The default options
    def default_options
      {
        return_as: "RETURN #{model_name}",
        for_in:    "FOR #{model_name} IN #{collection_name}",
        mapping:   true
      }
    end

    private

    # The name of the model to be used in the query
    def model_name
      mapper.model_class.model_name.element
    end

    # The name of the collection to be used in the query
    def collection_name
      collection.collection_name
    end

    # Executes an AQL query with bind parameters
    #
    # @see Query#perfom_query
    def perfom_query(iterator_with_mapping, &block)
      iterator = perform_mapping? ? iterator_with_mapping : iterator_without_mapping(&block)
      connection.execute(aql_string, options).each(&iterator)
    end

    # An iterator to be used if no mapping should be performed
    def iterator_without_mapping(&block)
      ->(document) { block.call document }
    end
  end
end
