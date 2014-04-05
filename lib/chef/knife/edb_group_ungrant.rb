require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbGroupUngrant < Chef::Knife
      include Util

      banner "knife edb group ungrant GROUP TARGET1  TARGET2 .. TARGETn"

      deps do
        require 'chef/api_client'
        require 'chef/json_compat'
      end

      def run
        unless name_args.size >= 2
          puts "Must specify GROUP and TARGET client"
          show_usage
          exit 1
        end
        setup

        group = parse_group_name name_args[0]
        targets = name_args[1..-1]

        targets.each do |target|
          ui.info("Removing access to +#{group} for client #{target}")
          remove_enc_group_keyset(group, target)
        end
      end

    end

  end
end
