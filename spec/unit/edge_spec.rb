# -*- encoding : utf-8 -*-

require 'spec_helper'
require 'guacamole/edge'

class TestEdge
  include Guacamole::Edge
end

describe Guacamole::Edge do
  context 'having an instance of an edge' do
    subject { TestEdge.new }

    it 'should be a specialized Guacamole::Model' do
      expect(subject).to be_kind_of Guacamole::Model
    end

    it 'should have a special attribute :from' do
      expect(subject).to respond_to(:from)
    end

    it 'should have a special attribute :to' do
      expect(subject).to respond_to(:to)
    end
  end

  context 'defining edges' do
    subject { TestEdge }

    it 'should define a :from definition' do
      subject.from :orders

      expect(subject.from).to eq :orders
    end

    it 'should define a :to definition' do
      subject.to :customers

      expect(subject.to).to eq :customers
    end
  end
end

