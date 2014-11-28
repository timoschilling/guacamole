# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'guacamole/configuration'
require 'tempfile'

describe 'Guacamole.configure' do
  subject { Guacamole }

  it 'should yield the Configuration class' do
    subject.configure do |config|
      expect(config).to eq Guacamole::Configuration
    end
  end
end

describe 'Guacamole.configuration' do
  subject { Guacamole }

  it 'should return the Configuration class' do
    expect(Guacamole.configuration).to eq Guacamole::Configuration
  end
end

describe 'Guacamole.logger' do
  subject { Guacamole }

  it 'should just forward to Configuration#logger' do
    expect(Guacamole.configuration).to receive(:logger)

    subject.logger
  end
end

describe Guacamole::Configuration do
  subject { Guacamole::Configuration }

  describe 'database' do
    it 'should set the database' do
      database         = double('Database')
      subject.database = database

      expect(subject.database).to eq database
    end
  end

  describe 'default_mapper' do
    it 'should set the default mapper' do
      default_mapper         = double('Mapper')
      subject.default_mapper = default_mapper

      expect(subject.default_mapper).to eq default_mapper
    end

    it 'should return Guacamole::DocumentModelMapper as default' do
      subject.default_mapper = nil

      expect(subject.default_mapper).to eq Guacamole::DocumentModelMapper
    end
  end

  describe 'logger' do
    before do
      subject.logger = nil
    end

    it 'should set the logger' do
      logger = double('Logger')
      allow(logger).to receive(:level=)
      subject.logger = logger

      expect(subject.logger).to eq logger
    end

    it 'should default to Logger.new(STDOUT)' do
      expect(subject.logger).to be_a Logger
    end

    it 'should set the log level to :info for the default logger' do
      expect(subject.logger.level).to eq Logger::INFO
    end
  end

  describe 'build_config' do
    context 'from a hash' do
      let(:config_hash) do
        {
          'protocol' => 'http',
          'host'     => 'localhost',
          'port'     => 8529,
          'username' => 'username',
          'password' => 'password',
          'database' => 'awesome_db'
        }
      end
      let(:config_struct) { subject.build_config(config_hash) }

      it 'should create a struct with a database URL' do
        expect(config_struct.url).to eq 'http://localhost:8529'
      end

      it 'should create a struct with a username' do
        expect(config_struct.username).to eq 'username'
      end

      it 'should create a struct with password' do
        expect(config_struct.password).to eq 'password'
      end

      it 'should create a struct with database' do
        expect(config_struct.database).to eq 'awesome_db'
      end
    end

    context 'from a URL' do
      let(:database_url) { 'http://username:password@localhost:8529/_db/awesome_db' }
      let(:config_struct) { subject.build_config(database_url) }

      it 'should create a struct with a database URL' do
        expect(config_struct.url).to eq 'http://localhost:8529'
      end

      it 'should create a struct with a username' do
        expect(config_struct.username).to eq 'username'
      end

      it 'should create a struct with password' do
        expect(config_struct.password).to eq 'password'
      end

      it 'should create a struct with database' do
        expect(config_struct.database).to eq 'awesome_db'
      end
    end
  end

  describe 'create_database_connection' do
    let(:config_struct)    { double('ConfigStruct', url: 'http://localhost', username: 'user', password: 'pass', database: 'pony_db') }
    let(:arango_config)    { double('ArangoConfig').as_null_object }
    let(:database)         { double('Ashikawa::Core::Database') }
    let(:guacamole_logger) { double('logger') }

    before do
      allow(Ashikawa::Core::Database).to receive(:new).and_yield(arango_config).and_return(database)
      allow(subject).to receive(:logger).and_return(guacamole_logger)
    end

    it 'should create the actual Ashikawa::Core::Database instance' do
      expect(arango_config).to receive(:url=).with('http://localhost')
      expect(arango_config).to receive(:username=).with('user')
      expect(arango_config).to receive(:password=).with('pass')

      subject.create_database_connection config_struct
    end

    it 'should pass the Guacamole logger to the Ashikawa::Core::Database connection' do
      expect(arango_config).to receive(:logger=).with(guacamole_logger)

      subject.create_database_connection config_struct
    end

    it 'should assign the database connection to the configuration instance' do
      subject.create_database_connection config_struct

      expect(subject.database).to eq database
    end
  end

  describe 'load' do
    let(:config) { double('Config') }
    let(:env_config) { double('ConfigForEnv') }
    let(:config_struct) { double('ConfigStruct') }
    let(:current_environment) { 'development' }

    before do
      allow(subject).to receive(:current_environment).and_return(current_environment)
      allow(subject).to receive(:warn_if_database_was_not_yet_created)
      allow(subject).to receive(:create_database_connection)
      allow(subject).to receive(:process_file_with_erb).with('config_file.yml')
      allow(subject).to receive(:build_config).and_return(config_struct)
      allow(config).to  receive(:[]).with('development').and_return(env_config)
      allow(YAML).to    receive(:load).and_return(config)
    end

    it 'should parse a YAML configuration' do
      expect(YAML).to receive(:load).and_return(config)

      subject.load 'config_file.yml'
    end

    it 'should load the part for the current environment from the config file' do
      expect(config).to receive(:[]).with(current_environment)

      subject.load 'config_file.yml'
    end

    it 'should create a database config struct from config file' do
      expect(subject).to receive(:build_config).with(env_config).and_return(config_struct)

      subject.load 'config_file.yml'
    end

    it 'should create the database connection with a config struct' do
      expect(subject).to receive(:create_database_connection).with(config_struct)

      subject.load 'config_file.yml'
    end

    it 'should warn if the database was not found' do
      allow(subject).to receive(:database).and_return(double('Database'))
      allow(subject.database).to receive(:name)
      expect(subject.database).to receive(:send_request).with('version').and_raise(Ashikawa::Core::ResourceNotFound)
      expect(subject).to receive(:warn_if_database_was_not_yet_created).and_call_original

      logger = double('logger')
      expect(logger).to receive(:warn)
      expect(subject).to receive(:warn)
      allow(subject).to receive(:logger).and_return(logger)

      subject.load 'config_file.yml'
    end

    context 'erb support' do
      let(:config_file) { File.open 'spec/support/guacamole.yml.erb' }
      let(:protocol_via_erb) { ENV['ARANGODB_PROTOCOL'] = 'https' }
      let(:database_via_erb) { ENV['ARANGODB_DATABASE'] = 'my_playground' }

      before do
        allow(subject).to receive(:process_file_with_erb).and_call_original
      end

      after do
        ENV.delete 'ARANGODB_PROTOCOL'
        ENV.delete 'ARANGODB_DATABASE'
      end

      it 'should process the YAML file with ERB' do
        processed_yaml = <<-YAML
development:
  protocol: '#{protocol_via_erb}'
  host: 'localhost'
  port: 8529
  database: '#{database_via_erb}'
        YAML
        expect(YAML).to receive(:load).with(processed_yaml)

        subject.load config_file.path
      end
    end
  end

  describe 'configure with a connection URI' do
    let(:config_struct) { double('ConfigStruct') }
    let(:connection_uri) { 'http://username:password@locahost:8529/_db/awesome_db' }

    before do
      allow(subject).to receive(:create_database_connection)
      allow(subject).to receive(:build_config).and_return(config_struct)
    end

    it 'should build a config_struct from the connection URI' do
      expect(subject).to receive(:build_config).with(connection_uri)

      subject.configure_with_uri(connection_uri)
    end

    it 'should use the config_struct to create the database connection' do
      expect(subject).to receive(:create_database_connection).with(config_struct)

      subject.configure_with_uri(connection_uri)
    end
  end
end
