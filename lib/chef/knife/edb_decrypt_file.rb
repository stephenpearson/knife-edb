require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbDecryptFile < Chef::Knife
      include Util

      banner "knife edb decrypt file [BAG] FILE"

      deps do
        require 'chef/api_client'
        require 'chef/json_compat'
        require 'chef/data_bag_item'
        require 'chef/encrypted_data_bag_item'
        require 'chef/knife/core/object_loader'
      end

      def run
        (bag, file) = get_bag_file

        data = nil
        begin
          json = JSON.load(File.open(file).read)
        rescue
          ui.error "Cannot read file #{file}: #{$!}"
          exit 1
        end
        setup

        data = Chef::DataBagItem.from_hash(json)
        item = data["id"]

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
