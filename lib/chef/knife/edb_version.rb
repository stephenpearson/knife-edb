require 'chef/knife'
require "knife-edb/version"

module HPCS
  module EDB

    class EdbVersion < Chef::Knife

      banner "knife edb version"

      def run
        version = Knife::Edb::VERSION
        ui.info("Knife EDB, version = #{version}")
      end

    end

  end
end
