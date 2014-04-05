require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbGroupSetAdmin < Chef::Knife
      include Util

      banner "knife edb group set admin GROUP"

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

        private_pem = File.open(Chef::Config[:client_key]).read
        pubkey = OpenSSL::PKey::RSA.new private_pem

        group_db = Chef::DataBag.load('edb_groups')
        unless group_db[group]
          ui.error("Group #{group} does not exist")
          exit 1
        end

        ui.info("Setting admin flag on EDB group +#{group}")
        set_group_admin_flag(group, true)
      end

    end

  end
end
