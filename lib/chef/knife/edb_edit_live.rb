require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbEditLive < Chef::Knife
      include Util

      banner "knife edb edit live BAG ITEM"

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
        if enc_keyset
          keyset = decrypt_enc_keyset enc_keyset
          edb_key = keyset[:edb_key]
          data.data_bag(bag)
          data = Chef::EncryptedDataBagItem.new(data, edb_key).to_hash

          result = edit_sorted_data(data)
          if result == data
            ui.info("Nothing changed, skipping save")
            exit 0
          end

          data = Chef::DataBagItem.from_hash(result)
          data.data_bag(bag)
          enc_data = Chef::EncryptedDataBagItem.encrypt_data_bag_item(data, edb_key)
          enc_db = Chef::DataBagItem.from_hash(enc_data)
          enc_db.data_bag(bag)
          enc_db.save
        else
          ui.error("Key not found for databag #{bag} and item #{item}")
          exit 1
        end
      end

    end

  end
end
