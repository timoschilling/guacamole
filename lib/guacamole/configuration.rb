# -*- encoding : utf-8 -*-

require 'active_support'
require 'active_support/core_ext'
require 'logger'
require 'forwardable'
require 'ashikawa-core'
require 'yaml'
require 'erb'

require 'guacamole/document_model_mapper'

module Guacamole
  class << self
    # Configure Guacamole
    #
    # Takes a block in which you can configure Guacamole.
    # @return [Configuration] the resulting configuration
    def configure(&config_block)
      config_block.call configuration

      configuration
    end

    # Contains the configuration of Guacamole
    #
    # @return [Configuration]
    def configuration
      @configuration ||= Configuration
    end

    # Just an alias to Configuration#logger
    #
    # @return [Configuration#logger]
    def logger
      configuration.logger
    end
  end

  # Current configuration
  #
  # You can receive the configuration by calling Guacamole.configuration
  #
  # @!attribute self.database
  #   The raw Database object
  #
  #   The Database implementation is part of Ashikawa::Core
  #
  #   @see http://rubydoc.info/gems/ashikawa-core/Ashikawa/Core/Database
  #   @return [Ashikawa::Core::Database]
  #
  # @!attribute self.default_mapper
  #   The Mapper class that is used by default. This defaults to
  #   DocumentModelMapper
  #
  #   @return [Class] the default mapper class
  #
  # @!attribute self.logger
  #   The logger
  #
  #   This defaults to the Rails logger
  #
  #   @return [Object] the logger
  #
  # @!attribute [r] self.current_environment
  #   The current environment Guacamole is running in
  #
  #   If you are running in Rails, this will return the current Rails environment
  #
  #   @return [Object] current environment
  class Configuration
    # A wrapper object to handle both configuration from a connection URI and a hash.
    class ConfigStruct
      attr_reader :url, :username, :password, :database, :graph

      def initialize(config_hash_or_url)
        case config_hash_or_url
        when Hash
          init_from_hash(config_hash_or_url)
        when String
          init_from_uri_string(config_hash_or_url)
        end
      end

      private

      def init_from_uri_string(uri_string)
        uri       = URI.parse(uri_string)
        @username = uri.user
        @password = uri.password
        uri.user  = nil
        uri.path.match(%r{/_db/(?<db_name>\w+)/?}) { |match| @database = match[:db_name] }

        @url      = "#{uri.scheme}://#{uri.hostname}:#{uri.port}"
      end

      def init_from_hash(hash)
        @username = hash['username']
        @password = hash['password']
        @database = hash['database']
        @graph    = hash['graph']
        @url      = "#{hash['protocol']}://#{hash['host']}:#{hash['port']}"
      end
    end

    # @!visibility protected
    attr_accessor :database, :default_mapper, :logger

    class << self
      extend Forwardable

      def_delegators :configuration,
                     :database, :database=,
                     :default_mapper=,
                     :logger=

      def default_mapper
        configuration.default_mapper || (self.default_mapper = Guacamole::DocumentModelMapper)
      end

      def logger
        configuration.logger ||= (rails_logger || default_logger)
      end

      # Returns the graph associated with this Guacamole application.
      #
      # You can create more graphs by interacting with the database instance directly. This is just the main graph
      # that will be used to realize relations between models. The default name will be generated based on some
      # environment information. To set a custom name use the `graph_name` option when configure your connection.
      #
      # @return [Graph] The graph to be used internally to handle relations
      def graph
        database.graph(graph_name)
      end

      # Sets a custom name for the internally used graph
      #
      # @param [String] graph_name The name of the graph to be used
      def graph_name=(graph_name)
        @graph_name = graph_name
      end

      # The name of the graph to be used internally.
      #
      # Determining the name of the graph will go through the following steps:
      #
      # 1. Use the manually set `graph_name`
      # 2. Use the ENV variable `GUACAMOLE_GRAPH` if present.
      #    This is useful if you configure the application with ENV variables.
      # 3. If a Rails context was found it will use the name of the application with a `_graph` suffix
      # 4. If none of the above matched it will use the database name with a `_graph` suffix
      #
      # @return [String] The name of the graph to be used
      def graph_name
        return @graph_name if @graph_name
        return ENV['GUACAMOLE_GRAPH'] if ENV['GUACAMOLE_GRAPH']

        base_name = if Module.const_defined?('Rails')
                      Rails.application.class.name.deconstantize.underscore
                    else
                      database.name
                    end

        [base_name, 'graph'].join('_')
      end

      # Load a YAML configuration file to configure Guacamole
      #
      # @param [String] file_name The file name of the configuration
      def load(file_name)
        yaml_content    = process_file_with_erb(file_name)
        config          = build_config(YAML.load(yaml_content)[current_environment.to_s])
        self.graph_name = config.graph

        create_database_connection(config)
        warn_if_database_was_not_yet_created
      end

      # Configures the database connection with a connection URI
      #
      # @params [String] connection_uri A URI to describe the database connection
      def configure_with_uri(connection_uri)
        create_database_connection build_config(connection_uri)
      end

      # Creates a config struct from either a hash or a DATABASE_URL
      #
      # @param [Hash, String] config Either a hash containing config params or a complete connection URI
      # @return [ConfigStruct] A simple object with the required connection parameters
      # @api private
      def build_config(config)
        ConfigStruct.new config
      end

      # Creates the actual Ashikawa::Core::Database instance
      #
      # @param [ConfigStruct] config The config object to extract the config parameters from
      # @return [Ashikawa::Core::Database] The configured database instance
      # @api private
      def create_database_connection(config)
        self.database = Ashikawa::Core::Database.new do |arango_config|
          arango_config.url           = config.url
          arango_config.username      = config.username
          arango_config.password      = config.password
          arango_config.database_name = config.database if config.database
          arango_config.logger        = logger
        end
      end

      # The current environment.
      #
      # If you're in a Rails application this will return the Rails environment. If Rails is
      # not available it will use `RACK_ENV` and if that is not available it will fall back to
      # `GUACAMOLE_ENV`. This allows you to use Guacamole not only in Rails.
      #
      # @return [String] The current environment
      def current_environment
        return Rails.env if defined?(Rails)
        ENV['RACK_ENV'] || ENV['GUACAMOLE_ENV']
      end

      private

      def configuration
        @configuration ||= new
      end

      def rails_logger
        return Rails.logger if defined?(Rails)
      end

      def default_logger
        default_logger       = Logger.new(STDOUT)
        default_logger.level = Logger::INFO
        default_logger
      end

      # Prints a warning to STDOUT and the logger if the configured database could not be found
      #
      # @note Ashikawa::Core doesn't know if the database is not present or the collection was not created.
      #       Thus we will just give the user a warning if the database was not found upon initialization.
      def warn_if_database_was_not_yet_created
        database.send_request 'version' # The /version is database specific
      rescue Ashikawa::Core::ResourceNotFound
        warning_msg = "[WARNING] The configured database ('#{database.name}') cannot be found. Please run `rake db:create` to create it."
        logger.warn warning_msg
        warn warning_msg
      end

      def process_file_with_erb(file_name)
        ERB.new(File.read(file_name)).result
      end
    end
  end
end
