require 'tempfile'
require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbRemoteImportKey < Chef::Knife
      include Util

      banner "knife edb remote import key BAG ITEM -r REMOTE_CHEF_CONFIG"

      option :chefconf, 
        :short => "-r CONFIG",
        :long  => "--remote-chef-config config",
        :description => "Import key from remote chef server"

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

        if ! config[:chefconf]
          ui.error("Must specify a remote chef config with -r")
          exit 1
        end

        if get_enc_keyset(bag, item)
          ui.warn("You already have an EDB key for #{bag}/#{item}")
          ui.confirm("Are you sure you want to overwrite it")
        end

        file = Tempfile.new('key').path
        ui.info("Exporting remote key #{bag}/#{item} into temp file #{file}")
        system("knife edb export key #{bag} #{item} -c #{config[:chefconf]} -f #{file}")

        key = File.open(file).read

        enc_keyset = generate_enc_keyset(key)
        client_name = Chef::Config[:node_name]
        ui.info("Importing key #{bag}/#{item}")
        store_enc_keyset(bag, item, enc_keyset, client_name)
      end

    end

  end
end
