# -*- encoding : utf-8 -*-
require 'guacamole'
require 'acceptance/spec_helper'

require 'fabricators/book'
require 'fabricators/author'

class Authorship
  include Guacamole::Edge

  from :authors, as: :author
  to   :books, as: :book
end

class BooksCollection
  include Guacamole::Collection

  map do
    attribute :author, via: Authorship
  end
end

class AuthorsCollection
  include Guacamole::Collection

  map do
    attribute :books, via: Authorship
  end
end

describe 'Graph based relations' do
  let(:suzanne_collins) { Fabricate(:author, name: 'Suzanne Collins') }

  let(:the_hunger_games) { Fabricate(:book, title: 'The Hunger Games') }
  let(:catching_fire) { Fabricate(:book, title: 'Catching Fire') }
  let(:mockingjay) { Fabricate(:book, title: 'Mockingjay') }
  let(:panem_trilogy) { [the_hunger_games, catching_fire, mockingjay] }

  it 'should store and load relations' do
    suzanne_collins.books = panem_trilogy
    AuthorsCollection.save suzanne_collins

    author = AuthorsCollection.by_key(suzanne_collins.key)

    expect(author.books).to match_array panem_trilogy
  end
end
