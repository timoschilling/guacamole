# -*- encoding : utf-8 -*-

require 'spec_helper'
require 'guacamole/edge_collection'

class SomeEdgeCollection
  include Guacamole::EdgeCollection
end

# /// What do we need?
#
# 2. Each EachCollection needs the following features
#   * Add its edge definition to the graph
#   * Access to the graph
#   * Provide access to graph functions provided by Ashikawa::Core (i.e. Neighbors function)

describe Guacamole::EdgeCollection do
  context 'the edge collection module' do
    subject { Guacamole::EdgeCollection }

    context 'with user defined edge collection class' do
      let(:edge_class) { double('EdgeClass', name: 'MyEdge') }
      let(:user_defined_edge_collection) { double('EdgeCollection') }

      before do
        stub_const('MyEdgesCollection', user_defined_edge_collection)
      end

      it 'should return the edge collection for a givene edge class' do
        expect(subject.for(edge_class)).to eq user_defined_edge_collection
      end
    end

    context 'without user defined edge collection class' do
      let(:edge_class) { double('EdgeClass', name: 'AmazingEdge') }
      let(:auto_defined_edge_collection) { double('EdgeCollection') }

      it 'should create an edge collection class' do
        edge_collection = subject.create_edge_collection('SomeEdgesCollection')

        expect(edge_collection.name).to eq 'SomeEdgesCollection'
        expect(edge_collection.ancestors).to include Guacamole::EdgeCollection
      end
        
      it 'should return the edge collection for a givene edge class' do
        allow(subject).to receive(:create_edge_collection)
          .with('AmazingEdgesCollection')
          .and_return(auto_defined_edge_collection)

        expect(subject.for(edge_class)).to eq auto_defined_edge_collection
      end
    end
  end

  context 'concrete edge collections' do
    subject { SomeEdgeCollection }

    it 'should be a specialized Guacamole::Collection' do
      expect(subject).to include Guacamole::Collection 
    end
  end
end
