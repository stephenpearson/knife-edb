require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbEditFile < Chef::Knife
      include Util

      banner "knife edb edit file [BAG] FILE"

      deps do
        require 'chef/api_client'
        require 'chef/json_compat'
        require 'chef/data_bag_item'
        require 'chef/encrypted_data_bag_item'
      end

      def add_keyset(bag, item)
        ui.warn("No such EDB key: #{bag}/#{item}")
        ui.confirm("Would you like to create a key for #{bag}/#{item}")
        enc_keyset = generate_enc_keyset(nil)
        client_name = Chef::Config[:node_name]
        store_enc_keyset(bag, item, enc_keyset, client_name)
      end

      def run
        setup
        (bag, file) = get_bag_file

        id = file.sub(/\.+[^\.]*$/, '').split('/').last

        if File.readable?(file)
          json = JSON.load(File.open(file).read)
          id = json["id"] rescue nil
          if ! id
            ui.error("No ID attribute in file #{file}")
            exit 1
          end

          enc_keyset = get_enc_keyset(bag, id)
          if ! enc_keyset
            ui.error("Cannot access keyset for #{bag}/#{id}")
            exit 1
          end

          data = Chef::DataBagItem.from_hash(json)
          edb_key = get_edb_key(bag, id)
          data.data_bag(bag)

          begin
            data = Chef::EncryptedDataBagItem.new(data, edb_key).to_hash
          rescue
            ui.error("Cannot decrypt file #{file} as EDB #{bag}/#{id}")
            exit 1
          end
        else
          data = { "id" => id }
        end

        result = edit_sorted_data(data)

        if result == data
          ui.info("Nothing changed, skipping save")
          exit 0
        end

        id = result["id"]
        if ! get_enc_keyset(bag, id)
          add_keyset(bag, id)
        end

        edb_key = get_edb_key(bag, id)

        data = Chef::DataBagItem.from_hash(result)
        data.data_bag(bag)
        enc_data = Chef::EncryptedDataBagItem.encrypt_data_bag_item(data, edb_key)

        File.open(file, 'w') do |f|
          f.puts sorted_json(JSON.parse(enc_data.to_json))
        end
      end

    end

  end
end
