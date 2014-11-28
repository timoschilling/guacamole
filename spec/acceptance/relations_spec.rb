# -*- encoding : utf-8 -*-
require 'guacamole'
require 'acceptance/spec_helper'

require 'fabricators/book'
require 'fabricators/author'

class Authorship
  include Guacamole::Edge

  from :authors
  to   :books
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

  context 'having a start vertex and multiple target vertices' do
    context 'all are new' do
      let(:suzanne_collins) { Fabricate.build(:author, name: 'Suzanne Collins') }

      let(:the_hunger_games) { Fabricate.build(:book, title: 'The Hunger Games') }
      let(:catching_fire) { Fabricate.build(:book, title: 'Catching Fire') }
      let(:mockingjay) { Fabricate.build(:book, title: 'Mockingjay') }
      let(:panem_trilogy) { [the_hunger_games, catching_fire, mockingjay] }
      
      it 'should create the start, all targets and connect them' do
        suzanne_collins.books = panem_trilogy
        AuthorsCollection.save suzanne_collins

        author = AuthorsCollection.by_key(suzanne_collins.key)

        expect(author.books.map(&:title)).to match_array panem_trilogy.map(&:title)
      end
    end
    
    context 'one target is new' do
      let(:suzanne_collins) { Fabricate.build(:author, name: 'Suzanne Collins') }

      let(:the_hunger_games) { Fabricate(:book, title: 'The Hunger Games') }
      let(:catching_fire) { Fabricate(:book, title: 'Catching Fire') }
      let(:mockingjay) { Fabricate.build(:book, title: 'Mockingjay') }
      let(:panem_trilogy) { [the_hunger_games, catching_fire, mockingjay] }

      it 'should create the start, the new target and connect both the new and existing ones' do
        suzanne_collins.books = panem_trilogy
        AuthorsCollection.save suzanne_collins

        author = AuthorsCollection.by_key(suzanne_collins.key)

        expect(author.books.map(&:title)).to match_array panem_trilogy.map(&:title)
      end
    end

    context 'existing start gets another target' do
      let(:suzanne_collins) { Fabricate(:author, name: 'Suzanne Collins') }

      let(:the_hunger_games) { Fabricate(:book, title: 'The Hunger Games') }
      let(:catching_fire) { Fabricate(:book, title: 'Catching Fire') }
      let(:mockingjay) { Fabricate.build(:book, title: 'Mockingjay') }
      let(:panem_trilogy) { [the_hunger_games, catching_fire, mockingjay] }

      before do
        suzanne_collins.books = [the_hunger_games, catching_fire]
        AuthorsCollection.save suzanne_collins
      end

      it 'should save the new target and connect it to the start' do
        suzanne_collins.books << mockingjay
        AuthorsCollection.save suzanne_collins

        author = AuthorsCollection.by_key(suzanne_collins.key)

        expect(author.books.map(&:title)).to match_array panem_trilogy.map(&:title)
      end
    end

    context 'new connection between existing start and existing target' do
      let(:suzanne_collins) { Fabricate(:author, name: 'Suzanne Collins') }

      let(:the_hunger_games) { Fabricate(:book, title: 'The Hunger Games') }
      let(:catching_fire) { Fabricate(:book, title: 'Catching Fire') }
      let(:mockingjay) { Fabricate(:book, title: 'Mockingjay') }
      let(:panem_trilogy) { [the_hunger_games, catching_fire, mockingjay] }
      
      before do
        suzanne_collins.books = [the_hunger_games, catching_fire]
        AuthorsCollection.save suzanne_collins
      end

      it 'should just add a connection between start and target' do
        suzanne_collins.books << mockingjay
        AuthorsCollection.save suzanne_collins

        author = AuthorsCollection.by_key(suzanne_collins.key)

        expect(author.books.map(&:title)).to match_array panem_trilogy.map(&:title)
      end
    end
  end

  context 'having the target vertex and one target' do
    context 'all are new' do
      let(:suzanne_collins) { Fabricate.build(:author, name: 'Suzanne Collins') }

      let(:the_hunger_games) { Fabricate.build(:book, title: 'The Hunger Games') }
      
      it 'should create the target, the start and connects them' do
        the_hunger_games.author = suzanne_collins
        BooksCollection.save the_hunger_games

        book = BooksCollection.by_key the_hunger_games.key

        expect(book.author.name).to eq suzanne_collins.name
      end
    end
     
    context 'the target is new' do
      let(:suzanne_collins) { Fabricate.build(:author, name: 'Suzanne Collins') }

      let(:the_hunger_games) { Fabricate(:book, title: 'The Hunger Games') }

      it 'should create the start and make the connection' do
        the_hunger_games.author = suzanne_collins
        BooksCollection.save the_hunger_games

        book = BooksCollection.by_key the_hunger_games.key

        expect(book.author.name).to eq suzanne_collins.name
      end
    end

    context 'existing target gets another start' do
      let(:jk_rowling) { Fabricate.build(:author, name: 'J.K. Rowling') }
      let(:suzanne_collins) { Fabricate.build(:author, name: 'Suzanne Collins') }

      let(:the_hunger_games) { Fabricate(:book, title: 'The Hunger Games') }

      before do
        the_hunger_games.author = jk_rowling
        BooksCollection.save the_hunger_games
      end

      it 'should create the new target and connect it with the start' do
        the_hunger_games.author = suzanne_collins
        BooksCollection.save the_hunger_games

        book = BooksCollection.by_key the_hunger_games.key

        expect(book.author.name).to eq suzanne_collins.name
      end
    end

    context 'new connection between existing start and existing target' do
      let(:suzanne_collins) { Fabricate(:author, name: 'Suzanne Collins') }

      let(:the_hunger_games) { Fabricate(:book, title: 'The Hunger Games') }

      it 'should just connect the target with the start' do
        the_hunger_games.author = suzanne_collins
        BooksCollection.save the_hunger_games

        book = BooksCollection.by_key the_hunger_games.key

        expect(book.author.name).to eq suzanne_collins.name
      end
    end
  end
end
