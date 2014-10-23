# -*- encoding : utf-8 -*-

require 'spec_helper'
require 'guacamole/edge_collection'

describe Guacamole::EdgeCollection do
  let(:graph)  { double('Graph') }
# /// What do we need?
#
# 2. Each EachCollection needs the following features
#   * Provide access to graph functions provided by Ashikawa::Core (i.e. Neighbors function)

 let(:config) { double('Configuration') }

  before do
    allow(Guacamole).to receive(:configuration).and_return(config)
    allow(config).to receive(:graph).and_return(graph)
    allow(graph).to receive(:add_edge_definition)
  end

  context 'the edge collection module' do
    subject { Guacamole::EdgeCollection }

    context 'with user defined edge collection class' do
      let(:edge_class) { double('EdgeClass', name: 'MyEdge') }
      let(:user_defined_edge_collection) { double('EdgeCollection') }

      before do
        stub_const('MyEdgesCollection', user_defined_edge_collection)
        allow(user_defined_edge_collection).to receive(:add_edge_definition_to_graph)
      end

      it 'should return the edge collection for a given edge class' do
        expect(subject.for(edge_class)).to eq user_defined_edge_collection
      end
    end

    context 'without user defined edge collection class' do
      let(:edge_class) { double('EdgeClass', name: 'AmazingEdge') }
      let(:auto_defined_edge_collection) { double('EdgeCollection') }

      before do
        stub_const('ExampleEdge', double('Edge').as_null_object)
        allow(auto_defined_edge_collection).to receive(:add_edge_definition_to_graph)
      end

      it 'should create an edge collection class' do
        edge_collection = subject.create_edge_collection('ExampleEdgesCollection')

        expect(edge_collection.name).to eq 'ExampleEdgesCollection'
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
    subject do
      class SomeEdgesCollection
        include Guacamole::EdgeCollection
      end
    end

    let(:database) { double('Database') }
    let(:edge_collection_name) { 'some_edges' }
    let(:raw_edge_collection) { double('Ashikawa::Core::EdgeCollection') }
    let(:collection_a) { :a }
    let(:collection_b) { :b }
    let(:edge_class) { double('EdgeClass', name: 'SomeEdge', from: collection_a, to: collection_b)}
    let(:model) { double('Model') }

    before do
      stub_const('SomeEdge', edge_class)
      allow(graph).to receive(:edge_collection).with(edge_collection_name).and_return(raw_edge_collection)
      allow(subject).to receive(:database).and_return(database)
      allow(graph).to receive(:add_edge_definition)
    end

    after do
      # This stunt is required to have a fresh subject each time and not running into problems
      # with cached mock doubles that will raise errors upon test execution.
      Object.send(:remove_const, subject.name)
    end

    its(:edge_class) { should eq edge_class }
    its(:graph)      { should eq graph }

    it 'should be a specialized Guacamole::Collection' do
      expect(subject).to include Guacamole::Collection 
    end

    it 'should map the #connectino to the underlying edge_connection' do
      allow(subject).to receive(:graph).and_return(graph)
      
      expect(subject.connection).to eq raw_edge_collection
    end

    context 'initialize the edge definition' do
      it 'should add the edge definition as soon as the module is included' do
        just_another_edge_collection = Class.new
        expect(just_another_edge_collection).to receive(:add_edge_definition_to_graph)

        just_another_edge_collection.send(:include, Guacamole::EdgeCollection)
      end

      it 'should ignore if the the edge definition was already added' do
        expect(graph).to receive(:add_edge_definition).and_raise(Ashikawa::Core::ResourceNotFound)

        expect { subject.add_edge_definition_to_graph }.not_to raise_error
      end
      
      it 'should create the edge definition based on the edge class' do
        expect(graph).to receive(:add_edge_definition).with(edge_collection_name, from: [collection_a], to: [collection_b])

        subject.add_edge_definition_to_graph
      end
    end

    context 'accessing the mapper' do
      let(:collection_a) { double('Collection') }
      let(:collection_b) { double('Collection') }
      let(:mapper_a) { double('DocumentModelMapper') }
      let(:mapper_b)  { double('DocumentModelMapper') }

      before do
        allow(collection_a).to receive(:mapper).and_return(mapper_a)
        allow(collection_b).to receive(:mapper).and_return(mapper_b)
        allow(edge_class).to receive(:from_collection).and_return(collection_a)
        allow(edge_class).to receive(:to_collection).and_return(collection_b)
        allow(mapper_a).to receive(:responsible_for?).with(model).and_return(true)
        allow(mapper_b).to receive(:responsible_for?).with(model).and_return(false)
      end

      it 'should provide a method to get the mapper for the :to collection' do
        expect(subject.mapper_for_target(model)).to eq mapper_b
      end

      it 'should provide a method to get the mapper for the :from collection' do
        expect(subject.mapper_for_start(model)).to eq mapper_a
      end
    end

    context 'getting neighbors' do
      let(:graph_query) { instance_double('Guacamole::GraphQuery') }
      let(:target_mapper) { double('DocumentModelMapper') }

      before do
        allow(Guacamole::GraphQuery).to receive(:new).and_return(graph_query)
        allow(subject).to receive(:mapper_for_target).with(model).and_return(target_mapper)
        allow(graph_query).to receive(:neighbors).and_return(graph_query)
      end

      it 'should return a query object' do
        query = subject.neighbors(model)

        expect(query).to eq graph_query
      end

      it 'should initialize the query object with the graph an the appropriate mapper' do
        expect(Guacamole::GraphQuery).to receive(:new).with(graph, target_mapper).and_return(graph_query)

        subject.neighbors(model)
      end

      it 'should provide a #neighbors function' do
        expect(graph_query).to receive(:neighbors).with(model, 'some_edges')
        
        subject.neighbors(model)
      end
    end
  end
end
