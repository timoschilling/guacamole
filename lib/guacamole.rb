# -*- encoding : utf-8 -*-

require 'guacamole/version'
require 'guacamole/exceptions'
require 'guacamole/configuration'
require 'guacamole/model'
require 'guacamole/collection'
require 'guacamole/edge'
require 'guacamole/callbacks'
require 'guacamole/document_model_mapper'
require 'guacamole/identity_map'

if defined?(Rails)
  require 'guacamole/railtie'
end

# An ODM for ArangoDB
#
# For more general information, see README or Homepage
module Guacamole
end
