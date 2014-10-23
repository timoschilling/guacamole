# -*- encoding : utf-8 -*-

require 'guacamole/query'

module Guacamole
  class GraphQuery < Query
    def neighbors(start, edge_collection)
      options[:type] = :neighbors
      options[:start] = start
      options[:edge_collection] = edge_collection
      self
    end 

    def ==(other)
      # TODO implement reasonable comparision
    end

    private

    def perfom_query(iterator, &block)
      enumerator = case options[:type]
                   when :neighbors
                     connection.neighbors(options[:start], edges: options[:edge_collection])
                   else
                     [].to_enum
                   end

      enumerator.each(&iterator) 
    end 
  end
end
