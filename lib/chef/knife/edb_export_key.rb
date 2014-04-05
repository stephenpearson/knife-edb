require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbExportKey < Chef::Knife
      include Util

      deps do
        require 'chef/api_client'
        require 'chef/json_compat'
      end

      option :outputf, 
        :short => "-f FILE",
        :long  => "--file FILE",
        :description => "Output file"

      banner "knife edb export key BAG ITEM -f FILE"

      def run
        unless name_args.size == 2
          ui.error "Must specify BAG and ITEM"
          show_usage
          exit 1
        end

        unless config[:outputf]
          ui.error "Must specify an output file with -f"
          show_usage
          exit 1
        end
        setup

        bag = name_args[0]
        item = name_args[1]

        enc_keyset = get_enc_keyset(bag, item)
        if ! enc_keyset
          ui.error("Cannot access keyset for #{bag}/#{item}")
          exit 1
        end
        keyset = decrypt_enc_keyset(enc_keyset)
        File.open(config[:outputf], 'w') {|f| f.write(keyset[:edb_key])}
      end
    end
  end
end
