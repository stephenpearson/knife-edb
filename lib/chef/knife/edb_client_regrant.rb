require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbClientRegrant < Chef::Knife
      include Util

      banner "knife edb client regrant CLIENT"

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
          edb_key["keys"].keys.each do |item|
            enc_keyset = get_enc_keyset(bag, item)
            if enc_keyset == false
              ui.warn("No such edb: #{bag}/#{item}")
            end
            unless enc_keyset and enc_keyset[:enc_enc_key]
              ui.warn("You haven't been granted access to #{bag}/#{item}")
              enc_keyset = false
            end
            if enc_keyset
              keyset = decrypt_enc_keyset(enc_keyset)
              store_enc_keyset(bag, item, keyset, client)
            end
          end
        end
      end

    end

  end
end
