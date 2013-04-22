# PtOnlineMigration

Schema changes tend to lock tables, which can be unacceptable for your production
database. The wonderful people at Percona have developed a tool which helps you
avoid this problem on MySQL databases.

PTOnlineMigration patches ActiveRecord to have the option of altering tables through
the pt-online-schema-change command.

It is highly recommended that you study up on said command:
	http://www.percona.com/doc/percona-toolkit/2.2/pt-online-schema-change.html

This gem depends on the Percona Toolkit, and therefore only works with MySQL.

## Installation

Download/install the percona toolkit from their downloads page:
	http://www.percona.com/downloads/percona-toolkit/

Add this line to your application's Gemfile:

	gem 'pt-online-migration'

And then execute:

	$ bundle

Or install it yourself as:

	$ gem install pt-online-migration

## Usage

The syntax is very similar to `change_table`

e.g.

```ruby
	class SimpleAlterFoo < ActiveRecord::Migration
		def up
			online_alter_table :foo_table, :execute do |t|
				t.integer :new_column_name
			end
		end

		def down
			online_alter_table :foo_table, :execute do |t|
				t.remove :new_column_name
			end
		end
	end
```

or

```ruby
	class ComplexAlterFoo < ActiveRecord::Migration
		def up
			online_alter_table :foo_table, :execute, :database => 'foo_database', :critical_load => 'Threads_running:50' do |t|
				t.integer :new_column_name, :another_new_column_name, :limit => 7
				t.decimal :new_column_with_more_options, :precision => 5, :scale => 3
				t.change :foo_column, :boolean, :null => false
				t.rename :bar_column, :baz_column, :string, :limit => 140
				t.index  :foo_column, :unique => true, :name => 'foo_index'
			end
		end

		def down
			online_alter_table :foo_table, :execute, :database => 'foo_database', :critical_load => 'Threads_running:50' do |t|
				t.remove :new_column_name, :another_new_column_name, :new_column_with_more_options
				t.change :foo_column, :string
				t.rename :baz_column, :bar_column, :string
				t.remove_index :name => 'foo_index'
			end
		end
	end
```

but not

```ruby
	class FailAlterFoo < ActiveRecord::Migration
		def change
			online_alter_table :foo_table, :execute do |t|
				t.integer :new_column_name
			end
		end
	end
```

Change is not supported.

The major difference is that the online_alter_table method takes a few new parameters.
Without the symbol :execute, pt-online-schema-change will perform a dry-run and no actual schema change will be made.
The new method also takes a hash of options which are given to the pt-online-schema-change
command itself. Note in the complex example above a database is specified. If you
don't specify a database  `ActiveRecord::Base.connection.current_database` is assumed.

For a list of accepted options check out the percona-toolkit documention:
	http://www.percona.com/doc/percona-toolkit/2.2/pt-online-schema-change.html

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
