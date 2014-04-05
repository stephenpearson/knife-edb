require 'chef/knife'
require 'chef/knife/util'

module HPCS
  module EDB

    class EdbList < Chef::Knife

      include Util

      banner "knife edb list"

      deps do
        require 'chef/api_client'
        require 'chef/json_compat'
        require 'chef/search/query'
      end

      def run
        setup
        client_name = Chef::Config[:node_name]
        client_groups = get_client_groups(client_name).map {|g| "+#{g}"}
        q = Chef::Search::Query.new
        edb_keys = q.search(:edb_keys, "*:*").first.map(&:to_hash) rescue []
        edb_list = edb_keys.map {|i| i['id']}.sort
        edb_list.each do |bag|
          dbi = edb_keys.select {|b| b['id'] == bag}.first
          item_list = dbi['keys'].keys
          puts " #{bag}/"
          item_list.each do |item|
            enc_keyset = nil
            obj = dbi['keys'][item][client_name] rescue nil
            if obj
              enc_keyset = {
                :enc_enc_key => Base64.decode64(obj['enc_enc_key']),
                :enc_edb_key => Base64.decode64(obj['enc_edb_key'])
              }
            else
              edb_groups = dbi['keys'][item].keys.select {|g| g =~ /^\+/}
              group_list = edb_groups & client_groups
              my_group = group_list.first or nil
              my_group = my_group.sub(/^\+/, '') if my_group
              if group_list.any?
                obj = dbi['keys'][item]["+#{my_group}"] rescue nil
                if obj
                  enc_keyset = {
                    :enc_enc_key => Base64.decode64(obj['enc_enc_key']),
                    :enc_edb_key => Base64.decode64(obj['enc_edb_key']),
                    :group => my_group
                  }
                end
              end
            end
            if enc_keyset
              keyset = decrypt_enc_keyset enc_keyset
              if keyset
                digest = Digest::MD5.hexdigest(keyset[:edb_key])
                puts "    #{item}\t#{digest}"
              else
                puts "    #{item}\t(decrypt error)"
              end
            else
              puts "    #{item}\t(not granted)"
            end
          end
        end
      end

    end

  end
end
