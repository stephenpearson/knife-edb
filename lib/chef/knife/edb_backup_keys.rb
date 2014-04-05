require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbBackupKeys < Chef::Knife

      include Util

      option :outputd, 
        :short => "-d DIR",
        :long  => "--dir DIR",
        :description => "Write files to this directory"

      banner "knife edb backup keys -d DIR"

      deps do
        require 'chef/api_client'
        require 'chef/json_compat'
      end

      def run
        if ! config[:outputd]
          ui.error("Must specify an output directory with -d")
          exit 1
        end
        setup

        ui.confirm("Really backup edb keys to directory #{config[:outputd]}")

        client_name = Chef::Config[:node_name]
        dir = config[:outputd] ? config[:outputd] : "."
        edbs = get_edb_keys_data_bag
        edbs.map(&:first).each do |edb|
          db = Chef::DataBagItem.load('edb_keys', edb).to_hash
          File.open("#{dir}/#{edb}.json", "w") do |f|
            f.puts sorted_json(db)
          end
        end
      end

    end

  end
end
