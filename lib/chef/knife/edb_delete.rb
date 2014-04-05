require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbDelete < Chef::Knife
      include Util

      banner "knife edb delete BAG ITEM"

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

        ui.confirm("Really delete \"#{bag}/#{item}\" EDB keys for all clients")
        remove_item(bag, item)
      end

    end

  end
end
