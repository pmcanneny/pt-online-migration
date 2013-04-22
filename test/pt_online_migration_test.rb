require 'active_record'
require 'pt_online_migration'
require 'test/unit'
require 'mocha/setup'


module Kernel
	def system(cmd)
		return cmd
	end
end


class PTOnlineMigrationTest < Test::Unit::TestCase

	def setup
		@test_migration = ActiveRecord::Migration.new
	end

	def test_complicated_migration
		ActiveRecord::Base.expects(:connection).returns(stub(:current_database => 'stub_db'))

		command = @test_migration.online_alter_table :foo_table, :execute, :database => 'foo_database', :critical_load => 'Threads_running:50' do |t|
			t.integer :new_column, :another_new_column, :limit => 7
			t.decimal :new_column_with_more_options, :precision => 5, :scale => 3
			t.change :foo_column, :boolean, :null => false
			t.rename :bar_column, :baz_column, :string, :limit => 140
			t.index  :foo_column, :unique => true, :name => 'foo_index'
		end

		expected = [
			'pt-online-schema-change D=foo_database,t=foo_table --execute',
			"--no-check-alter --critical-load 'Threads_running:50' --alter 'add column",
			'new_column int(7), add column another_new_column int(7), add column',
			'new_column_with_more_options decimal(5, 3), modify column foo_column tinyint(1)',
			'not null, change column bar_column baz_column varchar(140), add unique index',
			"foo_index (foo_column)'"
		]
		assert_equal expected.join(' '), command
	end


	def test_simple_migration
		ActiveRecord::Base.expects(:connection).returns(stub(:current_database => 'stub_db'))

		simple_migration = ActiveRecord::Migration.new
		command = @test_migration.online_alter_table :foo_table, :execute do |t|
			t.integer :new_column_name
		end

		expected = "pt-online-schema-change D=stub_db,t=foo_table --execute --alter 'add column new_column_name int(11)'"
		assert_equal expected, command
	end
end
