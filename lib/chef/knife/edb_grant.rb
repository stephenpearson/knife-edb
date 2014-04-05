require 'chef/knife'
require 'chef/knife/util'
require 'ostruct'

module HPCS
  module EDB

    class EdbGrant < Chef::Knife
      include Util

      banner "knife edb grant BAG ITEM TARGET1 .. TARGETn [-q query] [--client-query]\n"+
             "    A target can be a node name, a group name (starting with '+'),\n"+
             "    or a node query (starting with '?')"

      deps do
        require 'chef/api_client'
        require 'chef/json_compat'
      end

      option :query_mode,
        :short => "-q",
        :long  => "--query",
        :boolean => true,
        :description => "Use query mode (against nodes by default)"

      option :client_query,
        :long => "--client-query",
        :boolean => true,
        :description => "Query against client objects instead of nodes"

      def run
        unless name_args.size >= 3
          puts "Must specify EDB, ITEM and TARGET client(s)"
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
            clients = q.search(:client, client_query).first
          else
            node_query = targets.map {|i| "(#{i})"}.join(" OR ")
            nodes = q.search(:node, node_query).first
            clients = nodes.map do |n|
              o = OpenStruct.new
              o.public_key = n["public_key"]
              o.name = n["fqdn"]
              o
            end
          end
        else
          clients = build_client_list(targets)
        end
        grant_clients(bag, item, clients)
      end

    end

  end
end
