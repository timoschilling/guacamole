# -*- encoding : utf-8 -*-

require 'spec_helper'
require 'guacamole/proxies/relation'

describe Guacamole::Proxies::Relation do
  let(:model) { double('Model') }
  let(:edge_class) { double('EdgeClass') }
  let(:responsible_edge_collection) { double('EdgeCollection') }
  let(:edge_collection_name)        { 'name_of_the_edge_collection' }

  before do
    allow(Guacamole::EdgeCollection).to receive(:for).with(edge_class).and_return(responsible_edge_collection)
    allow(responsible_edge_collection).to receive(:collection_name).and_return(edge_collection_name)
  end

  context 'initialization' do
    subject { Guacamole::Proxies::Relation }

    it 'should take a model and edge class as params' do
      expect { subject.new(model, edge_class) }.not_to raise_error
    end
  end

  context 'initialized proxy' do
    subject { Guacamole::Proxies::Relation.new(model, edge_class) }

    it 'should call the #neigbors method on the appropriate edge collection' do
      expect(responsible_edge_collection).to receive(:neighbors)
        .with(model)

      subject.to_a
    end
  end
end
