require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbRefresh < Chef::Knife
      include Util

      banner "knife edb refresh BAG ITEM"

      deps do
        require 'chef/api_client'
        require 'chef/json_compat'
      end

      def run
        unless name_args.size == 2
          puts "Must specify EDB name"
          show_usage
          exit 1
        end
        setup

        bag = name_args[0]
        item = name_args[1]

        enc_keyset = get_enc_keyset(bag, item)
        unless enc_keyset and enc_keyset[:enc_enc_key]
          ui.error("You haven't been granted access to #{name}")
          exit 1
        end

        dbi = get_edb_keys_data_bag_item(bag)
        if ! dbi["keys"]
          ui.error("Missing 'keys' object in #{bag}/#{item} EDB")
          exit 1
        end

        clients = dbi["keys"][item] ? dbi["keys"][item].keys : []
        keyset = decrypt_enc_keyset(enc_keyset)

        clients.each do |target|
          target_pubkey = get_public_key(target)
          enc_keyset = encrypt_keyset(keyset, target_pubkey)
          ui.info("Refreshing key #{bag}/#{item} for client #{target}")
          store_enc_keyset(bag, item, enc_keyset, target)
        end
      end

    end

  end
end
