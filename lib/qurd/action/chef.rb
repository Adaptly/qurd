require 'qurd/action'
require 'chef'
require 'chef/search/query'
module Qurd
  class Action
    # Clean up chef client and node data
    # @example Chef configuration
    #   chef_configuration: "/etc/chef/some_knife_config.rb"
    class Chef < Action
      @configure_done = false

      # Add a setter and getter for {#Qurd::Message} +chef_node+ +chef_client+
      # and configure Chef using {#Qurd::Configuration} +chef_configuration+ or
      # the default +/etc/chef/knife.rb+. If {#Qurd::Configuration} +log_file+
      # is defined, Chef will log to it.
      # @param [String] _action the name of the action being configured
      def self.configure(_action)
        return if @configure_done
        configure_chef
        Qurd::Message.add_accessor(:chef_node)
        Qurd::Message.add_accessor(:chef_client)
        @configure_done = true
      end

      # Parse Chef's configuration file, as defined in +qurd.yml+, set Chef's
      # +log_level+, and Chef's +log_location+
      def self.configure_chef
        config = File.expand_path(qurd_configuration.chef_configuration ||
                                  '/etc/chef/knife.rb')
        qurd_logger.debug("Configuring Chef for using #{config}")
        ::Chef::Config.from_file(config)
        ::Chef::Config[:log_level] = qurd_configuration.log_level
        if qurd_configuration.log_file_io
          qurd_logger.debug('Setting chef log file to ' \
                            "'#{qurd_configuration.log_file_io.path}'")
          ::Chef::Config[:log_location] = qurd_configuration.log_file_io
        end
      end

      # Find the node, using the +instance_id+ of the +message+
      def run_before
        find_chef_node
        find_chef_client
      end

      # Delete the node, if the message did not fail other processing steps and
      # dry_run is not true
      # @see {#Qurd::Message}
      def terminate
        if message.failed?
          qurd_logger.warn('Not deleting, message failed to process')
        elsif qurd_configuration.dry_run
          check_dry_run
        else
          qurd_logger.debug('Deleting')
          message.chef_node.destroy unless message.chef_node.nil?
          message.chef_client.destroy unless message.chef_client.nil?
        end
      end

      # Respond to test actions
      def test
        qurd_logger.info('Test')
      end

      private

      # Set the +message+ +chef_node+ and +context+ +chef_name+
      # @see chef_search_node
      def find_chef_node
        node = chef_search_node
        message.chef_node = node
        message.context[:chef_name] = node.name
        qurd_logger.debug('Chef node found')
      rescue NoMethodError
        qurd_logger.warn('Chef node not found')
        message.chef_node = nil
        message.context[:chef_name] = nil
      end

      # Set the +message+ +chef_client+ and +context+ +chef_client_name+
      # @see chef_search_client
      def find_chef_client
        client = chef_search_client(message.chef_node.name)
        message.chef_client = client
        message.context[:chef_client_name] = client.name
        qurd_logger.debug('Chef client found')
      rescue NoMethodError
        qurd_logger.warn('Chef client not found')
        message.chef_client = nil
        message.context[:chef_client_name] = nil
      end

      # Memoize a +Chef::Search::Query+
      # @return [Chef::Search::Query]
      def chef_search
        @chef_search ||= ::Chef::Search::Query.new
      end

      # Search for a Chef node, based on the +instance_id+
      # @return [Chef::Node|nil]
      # @see instance_id
      def chef_search_node
        res = chef_search.search(:node, "instance_id:#{message.instance_id}")
        res.last == 1 ? res[0][0] : nil
      end

      # Search for a Chef client, based on the +name+ passed, likely FQDN
      # @param [String] name the client's name
      # @return [Chef::ApiClient|nil]
      def chef_search_client(name)
        res = chef_search.search(:client, "name:#{name}")
        res.last == 1 ? res[0][0] : nil
      end

      # Print log messages, based on object state
      def check_dry_run
        if !find_chef_node
          qurd_logger.debug('Dry run; missing node')
        elsif !find_chef_client
          qurd_logger.debug('Dry run; missing client')
        else
          qurd_logger.debug('Dry run; would delete')
        end
      end
    end
  end
end
