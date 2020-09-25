require 'qurd/action'
module Qurd
  class Action
    # Clean up route53 records, in private zones
    # @example Route53Private configuration
    #   auto_scaling_queues:
    #     staging:
    #       credentials: foo
    #       region: us-east-1
    #       queues:
    #         - "/QueueName/i"
    #   route53_private:
    #     staging:
    #       hosted_zone: "private.staging.example.com."
    class Route53Private < Action
      # Parent class for errors
      class Errors
        # Hosted Zone not found
        class ZoneNotFound < StandardError; end
        # Resource record set not found
        class ResourceNotFound < StandardError; end
        # Hostname not available from EC2 and Chef
        class HostNotFound < StandardError; end
      end

      @configure_done = false
      # Verify each +auto_scaling_queue+ has a corresponding +route53_private+ key and
      # that each of those keys defines a +hosted_zone+
      # @param [String] _action the action being configured
      # @raise [RuntimeError] if any +auto_scaling_queues+ do not have correctly
      #   configured +route53_private+ keys
      def self.configure(_action)
        return if @configure_done
        check_configuration
        @configure_done = true
      end

      # Delete the record, if the message did not fail other processing steps and
      # dry_run is not true
      # @see {#Qurd::Message}
      def terminate
        if failed?
          qurd_logger.warn('Not deleting, message failed to process')
        elsif qurd_configuration.dry_run
          if !hosted_zone
            qurd_logger.debug('Dry run; missing hosted_zone')
          elsif !hostname
            qurd_logger.debug('Dry run; missing hostname')
          elsif !resource_record
            qurd_logger.debug('Dry run; missing resource_record')
          else
            qurd_logger.debug('Dry run; would delete')
          end
        else
          begin
            route53_delete
          rescue Errors::ResourceNotFound => e
            # If the zone derived from the hostname equals the hosted zone it's
            # a real problem. If, on the other hand, the hosted zone differs
            # from the derived zone assume Route53CreatePriavte is false or only.
            raise e if @derived_domain == qurd_route53.hosted_zone
          end
        end
      end

      # Respond to test actions
      def test
        qurd_logger.info('Test')
      end

      private

      def route53
        @route53 ||= aws_client(:Route53)
      end

      def qurd_route53
        @config ||= qurd_configuration.route53_private[name]
      end

      def chef_node_name
        return @chef_node_name if defined? @chef_node_name
        @chef_node_name = chef_node.name
        qurd_logger.debug("Found chef name '#{@chef_node_name}'")
        @chef_node_name
      rescue NoMethodError
        qurd_logger.debug('No node found')
        nil
      end

      def hostname
        # NOTE: during private zone r53 migration, instance/node names may be
        # configured in both private and public zones or only one of the zones
        name = instance_name || chef_node_name
        if ENV['A5Y_ENV'] == 'dev'
          # test-1.dev.zoo.us-east-1.adaptly.com -> (test-1.dev.)(zoo.us-east-1.adaptly.com)
          name[/([-\w]+\.[-\w]+\.)(.*)/]
        else
          # test-1.production.us-east-1.adaptly.com -> (test-1.)(production.us-east-1.adaptly.com)
          name[/([-\w]+\.)(.*)/]
        end
        @derived_domain = $2
        @hostname = $1
        @hostname += qurd_route53.hosted_zone
        @hostname.sub!(/([^.])$/, '\1.')
        qurd_logger.debug("Using host '#{@hostname}'")
        @hostname
      rescue NoMethodError
        qurd_logger!('No instance or chef information',
                     Errors::HostNotFound)
      end

      def resource_record(tries = nil)
        @rr = aws_retryable(tries) do
          route53.list_resource_record_sets(
            hosted_zone_id: hosted_zone.id,
            start_record_name: hostname
          ).resource_record_sets.find{|r|
            r.name == hostname
          }
        end
        @rr || qurd_logger!('Resource record not found',
                            Errors::ResourceNotFound)
      end

      def route53_delete(tries = nil)
        qurd_logger.debug('Deleting')
        aws_retryable(tries) do
          route53.change_resource_record_sets(
            hosted_zone_id: hosted_zone.id,
            change_batch: {
              changes: [
                action: 'DELETE',
                resource_record_set: {
                  name: resource_record.name,
                  type: resource_record.type,
                  ttl: resource_record.ttl,
                  resource_records: resource_record.resource_records
                }
              ]
            }
          )
        end
      rescue Qurd::Action::Route53Private::Errors => e
        qurd_logger.error("Failed to delete: #{e}")
        failed!(e)
      end

      def hosted_zone(tries = nil)
        return @hosted_zone if defined? @hosted_zone
        name = qurd_route53.hosted_zone
        qurd_logger.debug("Looking for zone '#{name}'")
        aws_retryable(tries) do
          @hosted_zone = route53.list_hosted_zones_by_name(
            dns_name: name,
            max_items: 1
          ).hosted_zones.find{|z| z.name == name}
          qurd_logger.debug "Found zone '#{@hosted_zone}'"
        end
        @hosted_zone || qurd_logger!("Zone not found: '#{name}'",
                                     Errors::ZoneNotFound)
      end

      def self.config_valid?(name)
        if qurd_configuration.route53_private.nil? || \
           qurd_configuration.route53_private[name].nil? || \
           qurd_configuration.route53_private[name].hosted_zone.nil?
          false
        else
          true
        end
      end

      def self.check_configuration
        missing = []
        qurd_configuration.auto_scaling_queues.each do |name, _monitor|
          missing << name unless config_valid?(name)
        end
        m = missing.join(', ')
        qurd_logger! "Missing configuration for route53_private: #{m}" unless m.empty?
      end
    end
  end
end
