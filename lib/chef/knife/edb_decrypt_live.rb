require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbDecryptLive < Chef::Knife
      include Util

      banner "knife edb decrypt live BAG ITEM"

      deps do
        require 'chef/api_client'
        require 'chef/json_compat'
        require 'chef/data_bag_item'
        require 'chef/encrypted_data_bag_item'
        require 'chef/knife/core/object_loader'
      end

      def run
        unless name_args.size == 2
          show_usage
          exit 1
        end
        setup
   
        bag = name_args[0]
        item = name_args[1]

        data = Chef::DataBagItem.load(bag, item)

        enc_keyset = get_enc_keyset(bag, item)
        if ! enc_keyset
          ui.error("You haven't been granted access to #{bag}/#{item}")
          exit 1
        end

        keyset = decrypt_enc_keyset enc_keyset
        edb_key = keyset[:edb_key]
        data.data_bag(bag)
        data = Chef::EncryptedDataBagItem.new(data, edb_key).to_hash
        puts sorted_json(data)
      end

    end

  end
end
