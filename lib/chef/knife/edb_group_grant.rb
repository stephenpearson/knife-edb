require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbGroupGrant < Chef::Knife
      include Util

      banner "knife edb group grant GROUP TARGET1 TARGET2 .. TARGETn"

      deps do
        require 'chef/api_client'
        require 'chef/json_compat'
      end

      def run
        unless name_args.size >= 2
          puts "Must specify GROUP and TARGET client(s)"
          show_usage
          exit 1
        end
        setup

        group = parse_group_name name_args[0]
        targets = name_args[1..-1]

        enc_group_keyset = get_enc_group_keyset(group)
        unless enc_group_keyset and enc_group_keyset[:enc_enc_key]
          ui.error("You haven't been granted access to #{group}")
          exit 1
        end

        group_keyset = decrypt_enc_group_keyset(enc_group_keyset)

        targets.each do |target|
          target_pubkey = get_public_key(target)
          if target_pubkey == nil
            ui.warn("Can't find public key for #{target}")
          else
            enc_group_keyset = encrypt_group_keyset(group_keyset, target_pubkey)
            ui.info("Adding access to +#{group} for client #{target}")
            store_enc_group_keyset(group, enc_group_keyset, target)
          end
        end
      end

    end

  end
end
