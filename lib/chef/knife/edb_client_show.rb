require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbClientShow < Chef::Knife
      include Util

      banner "knife edb client show CLIENT"

      deps do
        require 'chef/api_client'
        require 'chef/json_compat'
      end

      def run
        unless name_args.size == 1
          puts "Must specify CLIENT"
          show_usage
          exit 1
        end
        setup
   
        client = name_args[0]
        q = Chef::Search::Query.new
        edb_keys =q.search(:edb_keys).first
        targets = [client] + get_client_groups(client).map {|g| "+#{g}"}
        puts "Client #{client} has grants to:"
        edb_keys.each do |edb_key|
          bag = edb_key.id
          shown_bag = false
          edb_key["keys"].keys.each do |item|
            access = edb_key['keys'][item].keys
            via = access & targets
            if via.any?
              puts " #{bag}/" unless shown_bag
              shown_bag = true
              if via.select {|i| i =~ /^[^\+]/}.any?
                puts "   #{item}"
              else
                puts "   #{item} (via #{via.join(', ')})"
              end
            end
          end
          puts if shown_bag
        end
      end

    end

  end
end
