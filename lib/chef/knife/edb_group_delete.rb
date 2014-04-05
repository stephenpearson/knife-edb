require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbGroupDelete < Chef::Knife
      include Util

      banner "knife edb group delete GROUP"

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
        ui.info("Deleting EDB group +#{group}")
        Chef::DataBagItem.load("edb_groups", group).destroy("edb_groups", group)
      end

    end

  end
end
