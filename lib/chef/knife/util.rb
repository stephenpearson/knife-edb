# Mixin to provide utility methods to knife edb plugin classes
# Some conventions:
# * edb_key - Symmetric key used to encrypt/decrypt encrypted data bags.
# * enc_edb_key - Symmetrically encrypted edb_key using enc_key below.
# * enc_key - AES key used to encrypt an edb_key.
# * enc_enc_key - Encrypted AES key, encrypted using client public key.
# * keyset - a hash containing edb_key and enc_key
# * enc_keyset - a hash containing enc_edb_key and enc_enc_key

require 'json'
require 'ostruct'

module HPCS
  module EDB
    module Util

      # To be run by all commands on startup
      def setup
        create_edb_store
        create_edb_group_store
      end

      # Get bag and file from command line
      def get_bag_file
        unless name_args.size >= 1
          show_usage
          exit 1
        end

        if name_args.size == 1
          file = name_args[0]
          bag = File.basename(File.dirname(File.expand_path(file)))
        else
          bag = name_args[0]
          file = name_args[1]
        end
        [bag, file]
      end

      # JSON sorter
      def sorted_json(json, indent = 0)
        ws = " " * indent
        ws2 = " " * ( indent + 2 )
        if json.kind_of? Array
          arrayRet = []
          json.each do |a|
            arrayRet.push(sorted_json(a, indent + 2))
          end
          return "[\n" + ws2 << arrayRet.join(",\n" + ws2) << "\n" + ws + "]"
        elsif json.kind_of? Hash
          ret = []
          json.keys.sort.sort {|a, b| a == 'id' ? -1 : b == 'id' ? 1 : a <=> b}.each do |k|
            ret.push(k.to_json << " : " << sorted_json(json[k], indent + 2))
          end
          return "{\n" + ws2 << ret.join(",\n" + ws2) << "\n" + ws + "}"
        else
          return json.to_json
        end
        raise Exception("Unable to handle object of type " + json.class)
      end

      # One line change from Chef::Knife#edit-data in lib/chef/knife.rb
      def edit_sorted_data(data, parse_output=true)
        output = sorted_json(data)  # This line changed

        if (!config[:no_editor])
          filename = "knife-edit-"
          0.upto(20) { filename += rand(9).to_s }
          filename << ".js"
          filename = File.join(Dir.tmpdir, filename)
          tf = File.open(filename, "w")
          tf.sync = true
          tf.puts output
          tf.close
          raise "Please set EDITOR environment variable" unless system("#{config[:editor]} #{tf.path}")
          tf = File.open(filename, "r")
          output = tf.gets(nil)
          tf.close
          File.unlink(filename)
        end

        parse_output ? Chef::JSONCompat.from_json(output) : output
      end

      # Lookup public key for Group
      def get_group_public_key(group)
        @group_public_key ||= {}
        if @group_public_key[group]
          return @group_public_key[group]
        else
          client = get_group_data_bag_item(group)["pubkey"]
          @group_public_key[group] = OpenSSL::PKey::RSA.new(client)
        end
      end

      # Lookup public key for Client/User
      def get_client_obj(target)
        if target =~ /^\+/
          pubkey = get_group_public_key(target.sub(/^\+/, ''))
          name = target
          group = OpenStruct.new
          group.public_key = pubkey
          group.name = name
          return group
        end

        client = OpenStruct.new
        begin
          # Try all three methods for finding the pubkey in parallel
          api = Chef::REST.new(Chef::Config[:chef_server_url])
          client1 = nil
          client2 = nil
          client3 = nil
          [ Thread.new { client1 = Chef::ApiClient.load(target) rescue nil },
            Thread.new { client2 = api.get_rest("/users/#{target}") rescue nil },
            Thread.new { client3 = Chef::Node.load(target) rescue nil} ].each(&:join)
          if (client3["public_key"] rescue nil)
            client.public_key = client3["public_key"]
            client.name = name
          elsif (client1.public_key rescue nil)
            client.public_key = client1.public_key
            client.name = client1.name
          else
            client.public_key = client2["public_key"]
            client.name = client2["username"]
          end
        rescue
          client = nil
        end

        client
      end

      def get_public_key(target)
        if target =~ /^\+/
          return get_group_public_key(target.sub(/^\+/, ''))
        end
        client_obj = get_client_obj(target)
        return nil unless client_obj
        pubkey = client_obj.public_key
        unless pubkey
          ui.error "Could not retrieve public key for \"#{target}\""
          ui.info "Make sure the target node has a top level 'public_key' attribute."
          ui.info "This is usually created by the edb_keys cookbook."
          exit 1
        end
        OpenSSL::PKey::RSA.new(pubkey)
      end

      def create_databag_if_missing(name)
        if ! Chef::DataBag.list[name]
          ui.warn "#{name} data bag not found"
          ui.confirm("Would you like to create the #{name} data bag now")
          bag = Chef::DataBag.new
          bag.name(name)
          bag.create
        end
      end

      def set_trigger
        @trigger_set ||= false
        return if @trigger_set

        if ! Chef::DataBag.list['edb_trigger']
          ui.warn("Creating edb_trigger data bag")
          db = Chef::DataBag.new
          db.name("edb_trigger")
          db.create
        end

        trigger = {
          "id" => "timestamp",
          "value" => Time.now.to_f.to_s
        }

        databag_item = Chef::DataBagItem.new
        databag_item.data_bag("edb_trigger")
        databag_item.raw_data = trigger
        databag_item.save

        @trigger_set = true
      end

      # Create a new EDB store data bag for storing EDB keysets
      def create_edb_store
        @edb_store_created ||= false
        create_databag_if_missing('edb_keys') unless @edb_store_created
        @edb_store_created = true
      end

      # Create a new EDB group store data bag for storing EDB groups
      def create_edb_group_store
        @edb_group_store_created ||= false
        create_databag_if_missing('edb_groups') unless @edb_group_store_created
        @edb_group_store_created = true
      end

      # Parse group name
      def parse_group_name(group)
        if group =~ /^\+/
          return group.sub(/^\+/, '')
        end
        ui.error("Group names must begin with '+'")
        exit 1
      end

      # Return a list of known EDBs
      def get_edb_list
       create_edb_store
       Chef::DataBag.load('edb_keys').keys
      end

      # Returns a list of known encrypted data bag items for bag named edb.
      def get_edb_item_list(edb)
        create_edb_store
        Chef::DataBagItem.load('edb_keys', edb)['keys'].keys
      end

      # Return the edb_keys data bag
      def get_edb_keys_data_bag
        create_edb_store
        Chef::DataBag.load('edb_keys')
      end

      # Return the edb_keys data bag
      def get_edb_groups_data_bag
        create_edb_group_store
        Chef::DataBag.load('edb_groups')
      end

      # Return the EDB item for a given EDB
      def get_edb_keys_data_bag_item(bag)
        create_edb_store
        dbi = Chef::DataBagItem.load('edb_keys', bag)
        dbi.data_bag('edb_keys')
        dbi
      end

      # Return the group data bag item for a given group
      def get_group_data_bag_item(group)
        create_edb_group_store
        dbi = Chef::DataBagItem.load('edb_groups', group)
        dbi.data_bag('edb_groups')
        dbi
      end

      # Returns list of clients permitted to access bag, item.
      def get_clients_list(bag, item)
        dbi = get_edb_keys_data_bag_item(bag)
        if ! dbi['keys']
          ui.error("Cannot read 'keys' hash in edb bag #{bag}")
          exit 1
        end
        return [] if ! dbi['keys'][item]
        dbi['keys'][item].keys
      end

      # Returns list of groups that client is a member of
      def get_client_groups(client)
        q = Chef::Search::Query.new
        q.search(:edb_groups, "keys_#{client}:*").first.map { |i| i.to_hash[:id] }
      end

      # Returns list of groups that are permitted to access bag, item
      def get_groups_list(bag, item)
        get_clients_list(bag, item).select do |client|
          client =~ /^\+/
        end.map do |client|
          client.sub(/^\+/, '')
        end
      end

      # Returns the encrypted keyset for bag, item.
      def get_enc_keyset(bag, item)
        client_name = Chef::Config[:node_name]
        get_edb_list
        if ! Chef::DataBag.load('edb_keys').keys.include?(bag)
          return false
        end
        enc_edb_entry = Chef::DataBagItem.load('edb_keys', bag)['keys'][item]
        return false unless enc_edb_entry
        groups = nil
        if (! enc_edb_entry) or (! enc_edb_entry[client_name])
          groups = get_client_groups(client_name) & get_groups_list(bag, item)
          return nil if groups.empty?
          client_name = "+#{groups.first}"
        end
        enc_enc_key = Base64.decode64(enc_edb_entry[client_name]['enc_enc_key'])
        enc_edb_key = Base64.decode64(enc_edb_entry[client_name]['enc_edb_key'])
        if groups
          { :enc_enc_key => enc_enc_key, :enc_edb_key => enc_edb_key, :group => groups.first }
        else
          { :enc_enc_key => enc_enc_key, :enc_edb_key => enc_edb_key }
        end
      end

      # Returns the encrypted group keyset for group
      def get_enc_group_keyset(group)
        client_name = Chef::Config[:node_name]
        create_edb_group_store
        @edb_groups_cache ||= Chef::DataBag.load('edb_groups')
        if ! @edb_groups_cache.keys.include?(group)
          return nil
        end

        if ! @edb_group_items_cache
	  q = Chef::Search::Query.new
	  @edb_group_items_cache = q.search(:edb_groups, "*:*")
        end

        group = @edb_group_items_cache.first.select {|i| i.id == group}.first
        enc_group_entry = group['keys']
        if (! enc_group_entry) or (! enc_group_entry[client_name])
          return nil
        end

        enc_group_key = Base64.decode64(enc_group_entry[client_name]['enc_group_key'])
        enc_enc_key = Base64.decode64(enc_group_entry[client_name]['enc_enc_key'])
        {
          :enc_group_key => enc_group_key,
          :enc_enc_key => enc_enc_key,
          :pubkey => group[:pubkey]
        }
      end

      # Returns the decrypted edb key for the current client.
      def get_edb_key(bag, item)
        enc_keyset = get_enc_keyset(bag, item)
        keyset = decrypt_enc_keyset enc_keyset
        raise "Decrypt error on #{bag}/#{item}" unless keyset
        keyset[:edb_key]
      end

      # Decrypts an encrypted keyset using the current clients' RSA key.
      def decrypt_enc_keyset(keyset)
        private_pem = File.open(Chef::Config[:client_key]).read
        pk = OpenSSL::PKey::RSA.new(private_pem)
        if keyset[:group]
          enc_group_keyset = get_enc_group_keyset(keyset[:group])
          group_keyset = decrypt_enc_group_keyset(enc_group_keyset)
          if group_keyset
            group_pem = group_keyset[:group_key]
            gk = OpenSSL::PKey::RSA.new(group_pem)
            enc_key = gk.private_decrypt(keyset[:enc_enc_key]) rescue nil
          else
            ui.warn("Failed to decrypt EDB key using group key +#{keyset[:group]}")
            enc_key = pk.private_decrypt(keyset[:enc_enc_key]) rescue nil
          end
        else
          enc_key = pk.private_decrypt(keyset[:enc_enc_key]) rescue nil
        end
        return nil unless enc_key
        edb_key = aes_decrypt(keyset[:enc_edb_key], enc_key)
        { :enc_key => enc_key, :edb_key => edb_key }
      end

      # Decrypts an encrypted group keyset using the current clients' RSA key.
      def decrypt_enc_group_keyset(keyset)
        private_pem = File.open(Chef::Config[:client_key]).read
        pk = OpenSSL::PKey::RSA.new(private_pem)
        enc_key = pk.private_decrypt(keyset[:enc_enc_key]) rescue nil
        return nil unless enc_key
        group_key = aes_decrypt(keyset[:enc_group_key], enc_key)
        result = { :enc_key => enc_key, :group_key => group_key }
        if keyset[:pubkey]
          result.merge!({:pubkey => keyset[:pubkey]})
        end
        result
      end

      # Encrypts an unencrypted keyset using the given public key
      def encrypt_keyset(keyset, pubkey)
        enc_key = OpenSSL::Random.random_bytes 32
        enc_enc_key = pubkey.public_encrypt(enc_key)
        enc_edb_key = aes_encrypt(keyset[:edb_key], enc_key)
        { :enc_enc_key => enc_enc_key, :enc_edb_key => enc_edb_key }
      end

      # Encrypts an unencrypted group keyset using the given public key
      def encrypt_group_keyset(keyset, pubkey)
        enc_key = OpenSSL::Random.random_bytes 32
        enc_enc_key = pubkey.public_encrypt(enc_key)
        enc_group_key = aes_encrypt(keyset[:group_key], enc_key)
        result = { :enc_enc_key => enc_enc_key, :enc_group_key => enc_group_key }
        if keyset[:pubkey]
          result.merge!({:pubkey => keyset[:pubkey]})
        end
        result
      end

      # AES encrypts a msg using given key
      def aes_encrypt(msg, key, dir = :encrypt)
        cipher = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
        cipher.send(dir)
        cipher.pkcs5_keyivgen(key)
        result = cipher.update(msg)
        result << cipher.final
        result
      end

      # AES decrypts enc_msg using given key
      def aes_decrypt(enc_msg, key)
        aes_encrypt(enc_msg, key, :decrypt)
      end

      # Generate a new random keyset (or use given key)
      def generate_enc_keyset(edb_key = nil)
        # Hack to deal with flaw in which Chef loads EDB keys
        unless edb_key
          edb_key = " "
          while edb_key != edb_key.strip
            edb_key = Base64.encode64(OpenSSL::Random.random_bytes 512).strip
          end
        end

        private_pem = File.open(Chef::Config[:client_key]).read
        pubkey = OpenSSL::PKey::RSA.new private_pem
        encrypt_keyset({ :edb_key => edb_key }, pubkey)
      end

      def generate_enc_group_keyset(pubkey)
        group_key = OpenSSL::PKey::RSA.generate(2048)
        group_pubkey = group_key.public_key
        enc_key = OpenSSL::Random.random_bytes 32
        enc_enc_key = pubkey.public_encrypt(enc_key)
        enc_group_key = aes_encrypt(group_key.to_s, enc_key)
        {
          :enc_enc_key => enc_enc_key,
          :enc_group_key => enc_group_key,
          :group_pubkey => group_pubkey
        }
      end

      # Removes a keyset from the edb_keys store
      def remove_enc_keyset_list(bag, item, clients)
        data_bag_entry = get_edb_keys_data_bag_item(bag)
        data_bag_entry['keys'] ||= {}
        clients.each do |client_name|
          if ! data_bag_entry['keys'][item]
            ui.error("#{bag}/#{item} does not exist")
          end
          if ! data_bag_entry['keys'][item][client_name]
            ui.warn("#{client_name} has not been granted access to #{bag}/#{item}")
          end
          if data_bag_entry['keys'][item]
            if data_bag_entry['keys'][item].size > 1
              data_bag_entry['keys'][item].delete(client_name)
            else
              ui.error("Refusing to ungrant last client with access to this key!")
            end
          end
        end
        set_trigger
        data_bag_entry.save
      end

      def remove_enc_keyset(bag, item, client_name)
        remove_enc_keyset_list(bag, item, [client_name])
      end

      # Removes a group keyset from the edb_groups store
      def remove_enc_group_keyset(group, client_name)
        data_bag_entry = get_group_data_bag_item(group)
        data_bag_entry['keys'] ||= {}
        if ! data_bag_entry['keys'][client_name]
          ui.warn("#{client_name} has not been granted access to #{group}")
          exit 1
        end
        if data_bag_entry['keys'].size > 1
          data_bag_entry['keys'].delete(client_name)
          data_bag_entry.save
        else
          ui.error("Refusing to ungrant last client with access to this group!")
        end
      end

      # Removes an encrypted data bag key from the edb_keys data bag
      def remove_item(bag, item)
        if ! Chef::DataBag.load('edb_keys')[bag]
          ui.warn("No such edb: #{bag}/#{item}")
          return
        end
        db = Chef::DataBagItem.load('edb_keys', bag)
        entry = db['keys']
        if entry and entry[item]
          entry.delete(item)
          if entry.empty?
            Chef::DataBagItem.load("edb_keys", bag).destroy("edb_keys", bag)
          else
            db.save
          end
        else
          ui.warn("No such edb: #{bag}/#{item}")
        end
        set_trigger
      end

      def store_enc_keyset_list(bag, item, keysets)
        create_edb_store
        if ! Chef::DataBag.load('edb_keys')[bag]
          data_bag_item = Chef::DataBagItem.new
          data_bag_item.data_bag('edb_keys')
          data_bag_item.raw_data = { "id" => bag }
        else
          data_bag_item = Chef::DataBagItem.load('edb_keys', bag)
          data_bag_item.data_bag('edb_keys')
        end

        data_bag_item['keys'] ||= {}
        new = data_bag_item['keys'][item] ? false : true

        client_name = Chef::Config[:node_name]
        my_enc_keyset = keysets.select {|k| k[:client_name] == client_name}.first
        keysets += get_admin_group_enc_keysets(bag, item, my_enc_keyset) if new and my_enc_keyset

        keysets.each do |keyset|
          data_bag_item['keys'][item] ||= {}
          data_bag_item['keys'][item][keyset[:client_name]] = {
            "enc_edb_key" => Base64.encode64(keyset[:enc_edb_key]),
            "enc_enc_key" => Base64.encode64(keyset[:enc_enc_key])
          }
        end

        data_bag_item.save
        set_trigger
        return new ? true : false
      end

      # Get enc_keysets for any admin groups the client has access to
      def get_admin_group_enc_keysets(bag, item, enc_keyset)
        client_name = Chef::Config[:node_name]
        q = Chef::Search::Query.new
        admin_groups = q.search(:edb_groups, "admin:true and keys_#{client_name}:enc_enc_key").first
        # puts "admin_groups = #{admin_groups.inspect}"

        keyset = decrypt_enc_keyset(enc_keyset)
        admin_groups.map do |group|
          ui.info "Granting to +#{group.id}"
          target_pubkey = get_group_public_key(group.id)
          enc_keyset = encrypt_keyset(keyset, target_pubkey)
          encrypt_keyset(keyset, OpenSSL::PKey::RSA.new(group['pubkey'])).merge({:client_name => "+#{group.id}"})
        end
      end

      # Store or update a keyset in a given bag, item
      def store_enc_keyset(bag, item, keyset, client_name)
        keyset[:client_name] = client_name
        store_enc_keyset_list(bag, item, [keyset])
      end

      # Set/Reset the admin flag on a group
      def set_group_admin_flag(group, value = true)
        data_bag_entry = get_group_data_bag_item(group)
        data_bag_entry['admin'] = value
        data_bag_entry.save
      end

      # Store group
      def store_enc_group_keyset(group, keyset, client_name)
        data_bag_entry = nil
        create_edb_group_store
        if ! Chef::DataBag.load('edb_groups')[group]
          data_bag_entry = Chef::DataBagItem.new
          data_bag_entry.data_bag('edb_groups')
          data_bag_entry.raw_data = {
            "id" => group,
            "pubkey" => keyset[:group_pubkey],
            "keys" => {
              client_name => {
                "enc_group_key" => Base64.encode64(keyset[:enc_group_key]),
                "enc_enc_key" => Base64.encode64(keyset[:enc_enc_key])
              }
            }
          }
          data_bag_entry.save
        else
          data_bag_entry = get_group_data_bag_item(group)
          data_bag_entry['keys'] ||= {}
          data_bag_entry['keys'][client_name] = {
            "enc_group_key" => Base64.encode64(keyset[:enc_group_key]),
            "enc_enc_key" => Base64.encode64(keyset[:enc_enc_key])
          }
          data_bag_entry.save
        end
      end

      # Build a list of clients from a mixed list of nodes, node queries,
      # and groups.
      # Node queries are identified by a leading '?' (e.g. '?role:Glance-api'),
      # and are expanded to lists of nodes.
      def build_client_list(targets)
        target_list = targets.map do |tgtspec|
          if tgtspec.start_with?("?")
            q = Chef::Search::Query.new
            nodelist = q.search(:node, tgtspec[1..-1]).first
            tl = nodelist.map { |n| n['fqdn'] }
            if tl.empty?
              ui.warn("Query '#{tgtspec[1..-1]}' matches no nodes.")
            end
          else
            tl = tgtspec
          end
          Chef::Log.debug("'#{tgtspec}' -> #{tl.inspect}")
          tl
        end.flatten
        # Convert this to a list of client objects
        clients = target_list.map do |t|
          public_key = get_public_key(t)
          name = t
          ui.warn("Can't find public key for #{t}") unless public_key
          if public_key
            o = OpenStruct.new
            o.name = name
            o.public_key = public_key
            o
          else
            nil
          end
        end.flatten.compact
        return clients
      end

      # Grant access on a databag item to a list of clients
      def grant_clients(bag, item, clients)
        enc_keyset = get_enc_keyset(bag, item)
        if enc_keyset == false
          ui.error("No such edb: #{bag}/#{item}")
          exit 1
        end
        unless enc_keyset and enc_keyset[:enc_enc_key]
          ui.error("You haven't been granted access to #{bag}/#{item}")
          exit 1
        end

        keyset = decrypt_enc_keyset(enc_keyset)
        enc_keysets = []
        clients.each do |client|
          target_pubkey = OpenSSL::PKey::RSA.new(client.public_key) rescue nil
          if ! target_pubkey
            ui.warn("Could not find public key for #{client.name}")
          else
            enc_keyset = encrypt_keyset(keyset, target_pubkey)
            enc_keyset[:client_name] = client.name
            enc_keysets << enc_keyset
            ui.info("Adding access to #{bag}/#{item} for client #{client.name}")
          end
        end
        store_enc_keyset_list(bag, item, enc_keysets)
      end

    end
  end
end
