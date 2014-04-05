require 'chef/knife'
require 'chef/knife/util'
require 'set'
require 'json'

module HPCS
  module EDB

    class EdbGroupList < Chef::Knife
      include Util

      banner "knife edb group list [GROUP ...]"

      deps do
        require 'chef/api_client'
        require 'chef/json_compat'
      end

      def run
        setup
        groups = Set.new(name_args.map { |g| g.sub(/^\+/, '') })
        client_name = Chef::Config[:node_name]
        q = Chef::Search::Query.new
        edb_groups = q.search(:edb_groups, "*:*").first.map(&:to_hash) rescue []
        print_groups = edb_groups.sort_by {|g| g[:id]}.map do |group|
          if not groups.empty? and not groups.include?(group[:id])
            next
          end
          
          { 'id' => '+' + group['id'], 'members' => group[:keys].keys,
            'admin' => group['admin'] ? true : false }
        end.compact
        if config[:format] == 'json'
          puts JSON.dump(print_groups)
        else
          print_groups.each do |g|
            puts "  #{g['id']} #{g['admin'] ? '[admin]':''} : #{g['members'].sort.join(', ')}"
          end
        end
      end

    end

  end
end
