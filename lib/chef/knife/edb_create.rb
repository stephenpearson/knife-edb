require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbCreate < Chef::Knife
      include Util

      banner "knife edb create BAG ITEM"

      deps do
        require 'chef/api_client'
        require 'chef/json_compat'
      end

      def run
        unless name_args.size == 2
          puts "Must specify BAG and ITEM"
          show_usage
          exit 1
        end
        setup
   
        bag = name_args[0]
        item = name_args[1]

        if get_enc_keyset(bag, item)
          ui.error("You already have an EDB key for #{bag}/#{item}")
          exit 1
        end

        enc_keyset = generate_enc_keyset(nil)
        client_name = Chef::Config[:node_name]
        ui.info("Creating key #{bag}/#{item}")
        store_enc_keyset(bag, item, enc_keyset, client_name)
      end

    end

  end
end
