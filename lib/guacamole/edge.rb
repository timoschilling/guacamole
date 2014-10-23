# -*- encoding : utf-8 -*-

require 'guacamole/model'

require 'active_support'
require 'active_support/concern'

module Guacamole
  # An Edge representing a relation between two models within a Graph
  #
  # A Guacamole::Edge is specialized model with two predefined attributes (`from` and `to`)
  # and a class level DSL to define the relation between models inside a Graph. Like normal
  # models, edge models don't know the database. But unlike the collection classes you define
  # yourself for your models Guacamole will create a default collection class to be used with
  # your edge models.
  #
  # @!attribute [r] from
  #   The model on the from side of the edge
  #
  #   @return [Guacamole::Model] The document from which the relation originates
  #
  # @!attribute [r] to
  #   The model on the to side of the edge
  #
  #   @return [Guacamole::Model] The document to which the relation directs
  #
  # @!method self.from(collection_name)
  #   Define the collection from which all these edges will originate
  #
  #   @api public
  #   @param [Symbol] collection_name The name of the originating collection
  #
  # @!method self.to(collection_name)
  #   Define the collection to which all these edges will direct
  #
  #   @api public
  #   @param [Symbol] collection_name The name of the target collection
  module Edge
    extend ActiveSupport::Concern

    included do
      include Guacamole::Model

      attribute :from, Object
      attribute :to, Object
    end

    module ClassMethods
      def from(collection_name = nil)
        if collection_name.nil?
          @from
        else
          @from = collection_name
        end
      end

      def to(collection_name = nil)
        if collection_name.nil?
          @to
        else
          @to = collection_name
        end
      end

      def to_collection
        [to.to_s.camelcase, 'Collection'].join('').constantize
      end

      def from_collection
        [from.to_s.camelcase, 'Collection'].join('').constantize
      end
    end
  end
end
