require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbUngrant < Chef::Knife
      include Util

      banner "knife edb ungrant BAG ITEM TARGET1  TARGET2 .. TARGETn"

      deps do
        require 'chef/api_client'
        require 'chef/json_compat'
      end

      option :query_mode, 
        :short => "-q",
        :long  => "--query",
        :boolean => true,
        :description => "Use query mode"

      option :client_query,
        :long => "--client-query",
        :boolean => true,
        :description => "Query against client objects instead of nodes"

      def run
        unless name_args.size >= 3
          puts "Must specify EDB, ITEM and TARGET client"
          show_usage
          exit 1
        end
        setup

        bag = name_args[0]
        item = name_args[1]
        targets = name_args[2..-1]

        if config[:query_mode]
          q = Chef::Search::Query.new
          if config[:client_query]
            client_query = targets.map {|i| "(#{i})"}.join(" OR ")
            clients = q.search(:client, client_query).first.map(&:name)
          else
            node_query = targets.map {|i| "(#{i})"}.join(" OR ")
            clients = q.search(:node, node_query).first.map(&:name)
          end
        else
          clients = targets
        end

        ui.info("Removing access to #{bag}/#{item} for #{clients.join(', ')}")
        remove_enc_keyset_list(bag, item, clients)
      end

    end

  end
end
