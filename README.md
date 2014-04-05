# Knife::Edb

An encrypted data bag key manager for Chef.

## Requirements
Requires
    -   Ruby version 1.8.7+ or 1.9.2+
    -   Chef gem must be installed
    -   A valid chef client key and knife.rb configuration file in .chef/

## Build
    rake build

## Concepts

The existing encrypted data bag functionallity provided by Chef uses a
symmetric key to protect access to a given data bag.  Data bags are
encrypted during upload to the Chef server when using knife data bag
commands with the --secret or --secret-file options.  Cookbook recipes can
decrypt the data bag provided they have access to a copy of the key on the
local filesystem.

The secret key must be kept secret to prevent unauthorised access, yet it
must be distributed to all users who wish to upload data bags and this can
present a security risk: Users may leave copies of unsecured keys on the
filesystem and it may be difficult to audit who has access to a key.
To make matters worse, either the data in data bags must be checked
unencrypted into a git repository, or the data must be checked-in
in encrypted form and there is no simple mechanism for other users to
decrypt the encrypted file in order to make modifications.

This plugin provides a wrapper around Chef's encrypted data bags.  It
manages EDB keys in a key store which is kept in a regular data bag on
the Chef server.  The keys are encrypted using the knife client's RSA public
key.  Each client has it's own copy of the EDB key for each data bag item.
When performing an action that requires access to the EDB key, the plugin
fetches the client's copy of the key and decrypts it using its private key.
For example: When editing encrypted data bag files, the plugin decrypts
the file, starts the editor and then automatically re-encrypts when
finished.

This plugin can be used with the "edb_keys" cookbook, which looks for
EDB keys which have been granted to the current client and automatically
installs them onto the local filesystem.  Encrypted Data bags can then be
read using the usual Chef::EncryptedDataBagItem.load_secret method.  The
act of distributing keys to servers becomes simply a matter of granting
access using the plugin's "edb grant" sub-comamnd.

A change to how the corresponding edb_keys cookbook is triggered was
introduced in version 0.3.0 (both versions of knife plugin and cookbook).
Now keys are only downloaded to the server if a timestamp (set by a
grant or ungrant command) does not match the timestamp on a node.  The
timestamp is set inside the edb_trigger data bag and is managed
automatically by the knife edb plugin.  This new arrangement reduces
load on the Chef server considerably if there are a large number of grants
in the organisation.

If keys are not delivered to the target node, try resetting the trigger
by running: "knife edb trigger", wait a few seconds for Solr to reindex
and then run chef-client.

Under normal circumstances it shouldn't be necessary to reset the trigger.

## Usage

Note that most EDB commands take the form:

    $ knife edb <subcommand> BAG ITEM ...

BAG is obviously the data bag name, and ITEM is the data bag item within
the data bag.
    
### Typical workflow

Create a new EDB file.  The first time the plugin is run, it notices that
the edb_keys and edb_groups data bags are missing and the user will be
prompted to create it.  Secondly the plugin determines that there is no
EDB key for the new data bag item so it offers to create it:

    $ knife edb edit file example data_bags/example/item1.json
    WARNING: edb_keys data bag not found
    Would you like to create the edb_keys data bag now? (Y/N) y
    WARNING: No such EDB: example/item1
    Would you like to create a key for example/item1? (Y/N) y

After editing, the file can be decrypted to stdout for verification:

    $ knife edb decrypt file example data_bags/example/item1.json 
    {
      "id": "item1",
      "foo": "bar"
    }

A plaintext file can be encrypted to STDOUT:

    $ knife edb encrypt file example data_bags/example/item2.json.plaintext 
    WARNING: No such EDB: example/item2
    Would you like to create a key for example/item2? (Y/N) y
    {
      "id": "item2",
      "foo": "hTaEOKisMM1RmADqtw8rzA==\n"
    }

Or the file can be converted into directly into an encrypted file:

    $ knife edb encrypt file example data_bags/example/item2.json.plaintext -f data_bags/example/item2.json

The list of known keys can be obtained using "edb list":

    $ knife edb list
     example/
        item1	7a6e198d60ec434d371ac79949f742d1
        item2   not granted

The string after item1 is an MD5 hash of the EDB key.  All users who have
been granted access should see the same hash.  If the key is unreadable
(i.e. if you haven't been granted access to it) then the hash will not
be displayed and "not granted" will be shown instead.

There is a convenience method which can upload the data bag item and create
the data bag in one step:

    $ knife edb upload example data_bags/example/item1.json 
    The example data bag does not exist.  Create it now? (Y/N) y

To grant access to some other users and servers:

    $ knife edb grant example item1 user1 user2 server1.com server2.net
    Adding access to example/item1 for client user1
    Adding access to example/item1 for client user2
    Adding access to example/item1 for client server1.com
    Adding access to example/item1 for client server2.net

A server will be able to install the key into /etc/chef/auto_edb_keys
if it has the edb_keys cookbook in it's run list.

See "groups" below for information about granting access to a predefined
group of clients.

Revoke access:

    $ knife edb ungrant example item1 user2
    Removing access to example/item1 for client user2

Create a data bag item key only:

    $ knife edb create example secret_data

It is strongly recommended that you regularly back up a copy of the
edb_keys and edb_groups data bags and check them into a version controlled
repository.  This can be done as follows:

    $ knife edb backup keys -d data_bags/edb_keys
    $ knife edb backup groups -d data_bags/edb_groups

To copy an EDB key onto another Chef server:

Method 1:

    (source) $ knife edb export key example item1 -f example-item1.key
    (target) $ knife edb import key example item1 -f example-item1.key

Method 2:
Using the target knife command, add the -r option to identify
a remote chef knife.rb config.

   (target) $ knife edb remote import key example item1 -r ~/chefs/remoteserver/knife.rb

To remove an EDB key:

    $ knife edb delete example item1
    Really delete "example/item1" EDB keys for all clients? (Y/N) y

### Shortcuts

When managing encrypted data bag files there is a shortcut which obviates the need to specify
the data bag name, provided that the file is contained in a directory with the same
name as the data bag name.  For example, if we have the following files and directories:

<pre>
chef
└── data_bags
    └── example
        ├── item1.json
        └── item2.json
</pre>

.. then if the CWD is chef/data_bags/example, we don't have to specify the "example" data bag:

    $ knife edb edit file item1.json
    $ knife edb decrypt file item2.json
    $ knife edb encrypt file item1.json
    $ knife edb upload item1.json

Note that this shortcut is only applicable for the above commands.

### Groups

Gem version 0.1.0 adds support for groups.  A group is an RSA keypair
for which access to the private key can be granted to clients.
Groups can be granted access to an edb key and all members of the
group will then have full access to that edb key, as if they had
been granted access individually.

To distinguish them from regular chef clients, groups are prefixed
with a '+' symbol.

Groups are created and populated as follows:

    $ knife edb group create +techops
    WARNING: edb_groups data bag not found
    Would you like to create the edb_groups data bag now? (Y/N) y
    $ knife edb group grant +techops user1 user2
    Adding access to +techops for client user1
    Adding access to +techops for client user2

Then groups can be granted access to the edb:

    $ knife edb grant example item1 +techops

Note that the edb_keys cookbook does not support groups, so to
grant access for a key to a server you should use a direct grant
for each server.

### Permissions and grants

All operations require access to a chef server and a valid chef client key.
Most operations require either a client key with the chef admin flag
enabled, and/or an edb grant for the key in question.  In general, any
operation that decrypts the edb key will require a grant, whereas anything
that requires writing to a data bag item on the chef server will require
admin permissions.  The required permissions are summarised below:

* a = requires client key with chef admin permissions
* g = requires edb grant or group grant

<pre>
    (  )  knife edb backup groups -d DIR
    (  )  knife edb backup keys -d DIR
    (a )  knife edb create BAG ITEM
    ( g)  knife edb decrypt file BAG FILE
    ( g)  knife edb decrypt live BAG ITEM
    (a )  knife edb delete BAG ITEM
    ( g)  knife edb edit file BAG FILE
    (ag)  knife edb edit live BAG ITEM
    ( g)  knife edb encrypt file BAG FILE
    ( g)  knife edb export key BAG ITEM -f FILE
    (ag)  knife edb grant BAG ITEM TARGET1 TARGET2 .. TARGETn
    (a )  knife edb group create GROUP
    (a )  knife edb group delete GROUP
    (ag)  knife edb group grant GROUP TARGET1 TARGET2 .. TARGETn
    (  )  knife edb group list
    (a )  knife edb group ungrant GROUP TARGET1  TARGET2 .. TARGETn
    (a )  knife edb import key BAG ITEM -f FILE
    (  )  knife edb list
    (ag)  knife edb refresh BAG ITEM
    ( g)  knife edb show BAG ITEM
    (a )  knife edb ungrant BAG ITEM TARGET1  TARGET2 .. TARGETn
    (a )  knife edb upload BAG FILE
    (a )  knife edb trigger
</pre>

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
