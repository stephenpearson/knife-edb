require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbShow < Chef::Knife
      include Util

      deps do
        require 'chef/api_client'
        require 'chef/json_compat'
      end

      option :full, 
        :short => "-f",
        :long  => "--full",
        :boolean => true,
        :description => "Show decrypted keyset"

      banner "knife edb show BAG ITEM"

      def showdata(data)
        puts Base64.encode64(data).gsub(/^ */, '   ')
      end

      def run
        unless name_args.size == 2
          ui.error "Must specify BAG and ITEM"
          show_usage
          exit 1
        end
        setup

        bag = name_args[0]
        item = name_args[1]

        enc_keyset = get_enc_keyset(bag, item)
        if enc_keyset == false
          ui.error("No such EDB: #{bag}/#{item}")
          exit 1
        end

        if enc_keyset
          keyset = decrypt_enc_keyset(enc_keyset)
        else
          keyset = nil
        end

        puts "Name:   #{bag}/#{item}"
        if keyset
          puts "Digest: #{Digest::MD5.hexdigest(keyset[:edb_key])}"
        else
          puts "Digest: unknown (not granted)"
        end
        clients = get_clients_list(bag, item)
        puts "Grants: #{clients.sort.join(', ')}"

        exit 0 unless keyset

        if config[:full]
          puts "Encrypted EDB key:"
          showdata enc_keyset[:enc_edb_key]
          puts "Encrypted AES key:"
          showdata enc_keyset[:enc_enc_key]
          puts "EDB key:"
          showdata keyset[:edb_key]
          puts "AES key:"
          showdata keyset[:enc_key]
        end
      end
    end
  end
end
