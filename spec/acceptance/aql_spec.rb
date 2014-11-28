# -*- encoding : utf-8 -*-

require 'guacamole'
require 'acceptance/spec_helper'

describe 'BasicAQLSupport' do
  subject { PoniesCollection }

  let(:pegasus_pony) { Fabricate(:pony, type: ['Pegasus']) }
  let(:earth_pony) { Fabricate(:pony, type: ['Earthpony'], name: 'Candy Mane') }
  let(:unicorn_pegasus_pony) { Fabricate(:pony, type: ['Pegasus', 'Unicorn']) }

  before do
    [pegasus_pony, earth_pony, unicorn_pegasus_pony]
  end

  it 'should retrieve models by simple AQL queries' do
    pony_by_name = PoniesCollection.by_aql('FILTER pony.name == @name', name: 'Candy Mane').first
    expect(pony_by_name).to eq earth_pony
  end

  it 'should retrieve models by more complex AQL queries' do
    ponies_by_type = PoniesCollection.by_aql('FILTER POSITION(pony.type, @pony_type, false) == true',
                                             pony_type: 'Pegasus')
    expect(ponies_by_type).to include unicorn_pegasus_pony
    expect(ponies_by_type).to include pegasus_pony
  end

  it 'should allow a custom RETURN statement' do
    custom_color = 'fancy white pink with sparkles'
    pony_by_name = PoniesCollection.by_aql('FILTER pony.name == @name',
                                           { name: 'Candy Mane' },
                                           return_as: %{RETURN MERGE(pony, {"color": "#{custom_color}"})}).first
    expect(pony_by_name.color).to eq custom_color
  end

  it 'should allow to disable the mapping' do
    pony_hash = PoniesCollection.by_aql('FILTER pony.name == @name',
                                        { name: 'Candy Mane' },
                                        mapping: false).first
    expect(pony_hash).to be_an(Ashikawa::Core::Document)
  end

  it 'should allow to provide a custom `FOR x IN y` part' do
    pony_by_name = PoniesCollection.by_aql('FILTER p.name == @name', { name: 'Candy Mane' }, { for_in: 'FOR p IN ponies'}).first
    expect(pony_by_name).to eq earth_pony
  end
end
