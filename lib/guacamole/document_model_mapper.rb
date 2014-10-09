# -*- encoding : utf-8 -*-

require 'guacamole/proxies/referenced_by'
require 'guacamole/proxies/references'
require 'guacamole/proxies/relation'

module Guacamole
  # This is the default mapper class to map between Ashikawa::Core::Document and
  # Guacamole::Model instances.
  #
  # If you want to build your own mapper, you have to build at least the
  # `document_to_model` and `model_to_document` methods.
  #
  # @note If you plan to bring your own `DocumentModelMapper` please consider using an {Guacamole::IdentityMap}.
  class DocumentModelMapper
    # An attribute to encapsulate special mapping
    class Attribute
      # The name of the attribute with in the model
      #
      # @return [Symbol] The name of the attribute
      attr_reader :name

      # Additional options to be used for the mapping
      #
      # @return [Hash] The mapping options for the attribute
      attr_reader :options

      # Create a new attribute instance
      #
      # You must at least provide the name of the attribute to be mapped and
      # optionally pass configuration for the mapper when it processes this attribute.
      #
      # @param [Symbol] name The name of the attribute
      # @param [Hash] options Additional options to be passed
      # @option options [Edge] :via The Edge class this attribute relates to
      def initialize(name, options = {})
        @name    = name.to_sym
        @options = options
      end

      # The name of the getter for this attribute
      #
      # @returns [Symbol] The method name to read this attribute
      def getter
        name
      end

      # The name of the setter for this attribute
      #
      # @return [String] The method name to set this attribute
      def setter
        "#{name}="
      end

      # Should this attribute be mapped via an Edge in a Graph?
      #
      # @return [Boolean] True if there was an edge class configured
      def map_via_edge?
        !!edge_class
      end

      # The edge class to be used during the mapping process
      #
      # @return [Edge] The actual edge class
      def edge_class
        options[:via]
      end

      # To Attribute instances are equal if their name is equal
      #
      # @param [Attribute] other The Attribute to compare this one to
      # @return [Boolean] True if both have the same name
      def ==(other)
        other.instance_of?(self.class) &&
          other.name == self.name
      end
      alias_method :eql?, :==
    end

    # The class to map to
    #
    # @return [class] The class to map to
    attr_reader :model_class

    # The arrays embedded in this model
    #
    # @return [Array] An array of embedded models
    attr_reader :models_to_embed
    attr_reader :referenced_by_models
    attr_reader :referenced_models

    # The list of Attributes to treat specially during the mapping process
    #
    # @return [Array<Attribute>] The list of special attributes
    attr_reader :attributes

    # Create a new instance of the mapper
    #
    # You have to provide the model class you want to map to.
    # The Document class is always Ashikawa::Core::Document
    #
    # @param [Class] model_class
    def initialize(model_class, identity_map = IdentityMap)
      @model_class          = model_class
      @identity_map         = identity_map
      @models_to_embed      = []
      @referenced_by_models = []
      @referenced_models    = []
      @attributes           = []
    end

    class << self
      # construct the {collection} class for a given model name.
      #
      # @example
      #   collection_class = collection_for(:user)
      #   collection_class == userscollection # would be true
      #
      # @note This is an class level alias for {DocumentModelMapper#collection_for}
      # @param [symbol, string] model_name the name of the model
      # @return [class] the {collection} class for the given model name
      def collection_for(model_name)
        "#{model_name.to_s.classify.pluralize}Collection".constantize
      end
    end

    # construct the {collection} class for a given model name.
    #
    # @example
    #   collection_class = collection_for(:user)
    #   collection_class == userscollection # would be true
    #
    # @todo As of now this is some kind of placeholder method. As soon as we implement
    #       the configuration of the mapping (#12) this will change. Still the {DocumentModelMapper}
    #       seems to be a good place for this functionality.
    # @param [symbol, string] model_name the name of the model
    # @return [class] the {collection} class for the given model name
    def collection_for(model_name)
      self.class.collection_for model_name
    end

    # Map a document to a model
    #
    # Sets the revision, key and all attributes on the model
    #
    # @param [Ashikawa::Core::Document] document
    # @return [Model] the resulting model with the given Model class
    def document_to_model(document)
      identity_map.retrieve_or_store model_class, document.key do
        model = model_class.new(document.to_h)

        handle_referenced_documents(document, model)
        handle_referenced_by_documents(document, model)
        handle_related_documents(document, model)

        model.key = document.key
        model.rev = document.revision

        model
      end
    end

    # Map a model to a document
    #
    # This will include all embedded models
    #
    # @param [Model] model
    # @return [Ashikawa::Core::Document] the resulting document
    def model_to_document(model)
      document = model.attributes.dup.except(:key, :rev)

      handle_embedded_models(model, document)
      handle_referenced_models(model, document)
      handle_referenced_by_models(model, document)
      handle_related_models(model, document)

      document
    end

    # Declare a model to be embedded
    #
    # With embeds you can specify that the document in the
    # collection embeds a document that should be mapped to
    # a certain model. Your model has to specify an attribute
    # with the type Array (of this model).
    #
    # @param [Symbol] model_name Pluralized name of the model class to embed
    # @example A blogpost with embedded comments
    #   class BlogpostsCollection
    #     include Guacamole::Collection
    #
    #     map do
    #       embeds :comments
    #     end
    #   end
    #
    #   class Blogpost
    #     include Guacamole::Model
    #
    #     attribute :comments, Array[Comment]
    #   end
    #
    #   class Comment
    #     include Guacamole::Model
    #   end
    #
    #   blogpost = BlogpostsCollection.find('12313121')
    #   p blogpost.comments #=> An Array of Comments
    def embeds(model_name)
      @models_to_embed << model_name
    end

    def referenced_by(model_name)
      @referenced_by_models << model_name
    end

    def references(model_name)
      @referenced_models << model_name
    end

    # Mark an attribute of the model to be specially treated during mapping
    #
    # @param [Symbol] attribute_name The name of the model attribute
    # @param [Hash] options Additional options to configure the mapping process
    # @option options [Edge] :via The Edge class this attribute relates to
    # @example Define a relation via an Edge in a Graph
    #   class Authorship
    #     include Guacamole::Edge
    #
    #     from :users
    #     to :posts
    #   end
    #
    #   class BlogpostsCollection
    #     include Guacamole::Collection
    #
    #     map do
    #       attribute :author, via: Authorship
    #     end
    #   end
    def attribute(attribute_name, options = {})
      @attributes << Attribute.new(attribute_name, options)
    end

    # Returns a list of attributes that have an Edge class configured
    #
    # @return [Array<Attribute>] A list of attributes which all have an Edge class
    def edge_attributes
      attributes.select(&:map_via_edge?)
    end

    private

    def identity_map
      @identity_map
    end

    def handle_embedded_models(model, document)
      models_to_embed.each do |attribute_name|
        document[attribute_name] = model.send(attribute_name).map do |embedded_model|
          embedded_model.attributes.except(:key, :rev)
        end
      end
    end

    def handle_referenced_models(model, document)
      referenced_models.each do |ref_model_name|
        ref_key = [ref_model_name.to_s, 'id'].join('_').to_sym
        ref_model = model.send ref_model_name
        document[ref_key] = ref_model.key if ref_model
        document.delete(ref_model_name)
      end
    end

    def handle_referenced_by_models(model, document)
      referenced_by_models.each do |ref_model_name|
        document.delete(ref_model_name)
      end
    end

    def handle_related_models(model, document)
      edge_attributes.each do |edge_attribute|
        document.delete(edge_attribute.name)
      end
    end

    def handle_referenced_documents(document, model)
      referenced_models.each do |ref_model_name|
        model.send("#{ref_model_name}=", Proxies::References.new(ref_model_name, document))
      end
    end

    def handle_referenced_by_documents(document, model)
      referenced_by_models.each do |ref_model_name|
        model.send("#{ref_model_name}=", Proxies::ReferencedBy.new(ref_model_name, model))
      end
    end

    def handle_related_documents(document, model)
      edge_attributes.each do |edge_attribute|
        model.send(edge_attribute.setter, Proxies::Relation.new(model, edge_attribute.edge_class))
      end
    end
  end
end
