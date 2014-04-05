require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbGroupCreate < Chef::Knife
      include Util

      banner "knife edb group create GROUP"

      deps do
        require 'chef/api_client'
        require 'chef/json_compat'
      end

      def run
        unless name_args.size == 1
          puts "Must specify GROUP"
          show_usage
          exit 1
        end
        setup
   
        group = parse_group_name name_args[0]

        private_pem = File.open(Chef::Config[:client_key]).read
        pubkey = OpenSSL::PKey::RSA.new private_pem

        group_db = Chef::DataBag.load('edb_groups')
        if group_db[group]
          ui.error("A group called #{group} already exists")
          exit 1
        end

        ui.info("Creating EDB group +#{group}")
        enc_group_keyset = generate_enc_group_keyset(pubkey)
        client_name = Chef::Config[:node_name]
        store_enc_group_keyset(group, enc_group_keyset, client_name)
      end

    end

  end
end
