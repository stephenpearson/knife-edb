require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbEncryptFile < Chef::Knife
      include Util

      banner "knife edb encrypt file [BAG] FILE [-f output.json]"

      option :outputf, 
        :short => "-f FILE",
        :long  => "--file FILE",
        :description => "Output file"

      deps do
        require 'chef/api_client'
        require 'chef/json_compat'
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
        (bag, file) = get_bag_file
        setup

        if ! File.readable?(file)
          ui.error("Cannot read file #{file}")
          exit 1
        end

        json = JSON.load(File.open(file).read)
        id = json["id"] rescue nil
        if ! id
          ui.error("No ID attribute in file #{file}")
          exit 1
        end

        enc_keyset = get_enc_keyset(bag, id)
        if ! enc_keyset
          add_keyset(bag, id)
        end

        enc_keyset = get_enc_keyset(bag, id)
        keyset = decrypt_enc_keyset enc_keyset
        edb_key = keyset[:edb_key]

        data = Chef::DataBagItem.from_hash(json)
        data.data_bag(bag)
        enc_data = Chef::EncryptedDataBagItem.encrypt_data_bag_item(data, edb_key)
        json = sorted_json(JSON.parse(enc_data.to_json))

        if config[:outputf]
          File.open(config[:outputf], 'w') {|f| f.write(json)}
        else
          puts json
        end
      end
    end

  end
end
