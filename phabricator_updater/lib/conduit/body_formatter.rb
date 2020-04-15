# frozen_string_literal: true

require 'rack'

module Api
  module Conduit
    # class to satisfy Conduit's needs
    # Conduit does not know Content-type application/json for all endpoints
    # it usess application/x-www-form-urlencoded
    # time to time it's not easy to convert JSON/hash to this format
    # we use Rack::Utils.build_nested_query with an extra sugar around
    class BodyFormatter
      class << self
        # transaction is list of numbered modifiers
        # it needs specific format where index of item in list must be also
        # in brackets
        # Ruby/Rack formats list(array) to empty brackets `transaction[][type]`
        # but PHP not and it needs also index of item in list
        #
        # e.g. transactions[0][type]=name&transactions[0][value]=RealName
        def transactions(list_of_transactions, current_message = {})
          current_message[:transactions] ||= {}
          index = current_message[:transactions].size
          list_of_transactions.each do |type, value|
            current_message[:transactions][index.to_s] = {
              type: type,
              value: value
            }
            index += 1
          end
          current_message
        end

        def to_conduit(message)
          build_nested_query(message)
        end

        def build_nested_query(value, prefix = nil)
          case value
          when Array
            i = 0
            value.map do |v|
              i += 1
              build_nested_query(v, "#{prefix}[#{i - 1}]")
            end.join('&')
          when Hash
            value.map do |k, v|
              if prefix
                build_nested_query(v, "#{prefix}[#{Rack::Utils.escape(k)}]")
              else
                build_nested_query(v, Rack::Utils.escape(k))
              end
            end.reject(&:empty?).join('&')
          when nil
            prefix
          else
            raise ArgumentError, 'value must be a Hash' if prefix.nil?

            "#{prefix}=#{Rack::Utils.escape(value)}"
          end
        end
      end
    end
  end
end
