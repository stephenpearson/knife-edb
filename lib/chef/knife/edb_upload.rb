require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbUpload < Chef::Knife
      include Util

      banner "knife edb upload [BAG] FILE"

      deps do
        require 'chef/api_client'
        require 'chef/json_compat'
      end

      def run
        (bag, file) = get_bag_file

        if ! File.readable?(file)
          ui.error("Can't read file #{file}")
          exit 1
        end
        setup

        json = JSON.parse(File.open(file).read)

        if ! Chef::DataBag.list.keys.include?(bag)
          ui.confirm("The #{bag} data bag does not exist.  Create it now")
          db = Chef::DataBag.new
          db.name(bag)
          db.create
        end

        dbi = Chef::DataBagItem.new
        dbi.data_bag(bag)
        dbi.raw_data = json
        dbi.save
      end

    end

  end
end
