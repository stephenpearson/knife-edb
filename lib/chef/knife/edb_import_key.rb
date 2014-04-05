require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbImportKey < Chef::Knife
      include Util

      banner "knife edb import key BAG ITEM -f FILE"

      option :importf, 
        :short => "-f FILE",
        :long  => "--import FILE",
        :description => "Import key from file"

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

        if ! config[:importf]
          ui.error("Must specify a key to import with -f")
          exit 1
        end

        if get_enc_keyset(bag, item)
          ui.warn("You already have an EDB key for #{bag}/#{item}")
          ui.confirm("Are you sure you want to overwrite it")
        end

        # Need to strip key to fix chef bug
        key = File.open(config[:importf]).read
        key.force_encoding("BINARY") if RUBY_VERSION > "1.9"
        key.strip!

        enc_keyset = generate_enc_keyset(key)
        client_name = Chef::Config[:node_name]
        store_enc_keyset(bag, item, enc_keyset, client_name)
      end

    end

  end
end
