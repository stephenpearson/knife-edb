require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbTrigger < Chef::Knife
      include Util

      banner "knife edb trigger"

      deps do
        require 'chef/api_client'
        require 'chef/json_compat'
      end

      def run
        setup
        ui.info("Manually triggering edb_keys recipe")
        set_trigger
      end

    end

  end
end
