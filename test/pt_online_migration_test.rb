require 'active_record'
require 'active_record/connection_adapters/mysql2_adapter'
require 'pt_online_migration'
require 'test/unit'
require 'mysql2'
require 'mocha/setup'

Rails = Class.new

class PTOnlineMigrationTest < Test::Unit::TestCase

	def setup
		@test_migration = ActiveRecord::Migration.new

		@test_migration.class.class_eval do
			attr_accessor :cmd, :puts_message

			def system(command)
				self.cmd = command
			end

			def puts(message)
				self.puts_message = message
			end
		end

		Mysql2::Client.expects(:new).at_least_once.returns(nil)
		ActiveRecord::ConnectionAdapters::Mysql2Adapter.any_instance.expects(:configure_connection).at_least_once.returns(true)
		ActiveRecord::ConnectionAdapters::Mysql2Adapter.any_instance.expects(:current_database).returns('stub_db')
		Rails.stubs(:configuration => stub(:database_configuration => { 'test' => {'host' => 'stub_host', 'username' => 'stub_user', 'password' => 'stub_password'}}))
		Rails.expects(:env).returns('test').at_least_once
		ActiveRecord::Base.establish_connection({
			"adapter"=>"mysql2",
			"database"=>"stub_db",
		})
	end


	def test_complicated_migration
		@test_migration.online_alter_table :foo_table, :execute, :host => 'bar_host', :database => 'foo_database', :username => 'baz_user', :password => 'biz_password', :critical_load => 'Threads_running:50' do |t|
			t.integer :new_column, :another_new_column, :limit => 7
			t.decimal :new_column_with_more_options, :precision => 5, :scale => 3, :default => nil
			t.change :foo_column, :boolean, :null => false
			t.rename :bar_column, :baz_column, :string, :limit => 140
			t.index  :foo_column, :unique => true, :name => 'foo_index'
		end

		expected_pt_command = [
			'pt-online-schema-change h=bar_host,u=baz_user,p=biz_password,D=foo_database,t=foo_table --execute --print',
			"--no-check-alter --critical-load 'Threads_running:50' --alter 'add column",
			'new_column bigint, add column another_new_column bigint, add column',
			'new_column_with_more_options decimal(5,3) default null, modify column foo_column tinyint(1)',
			'not null, change column bar_column baz_column varchar(140), add unique index',
			"foo_index (foo_column)'"
		]

		expected = "nohup #{expected_pt_command.join(' ')} >#{@test_migration.name}_foo_table.nohup.out 2>&1"
		assert_equal expected, @test_migration.cmd
	end


	def test_remove_migration
		@test_migration.online_alter_table :foo_table, :execute, :host => 'bar_host', :username => 'baz_user', :password => 'biz_password', :database => 'foo_database', :critical_load => 'Threads_running:50' do |t|
			t.remove :new_column, :another_new_column, :new_column_with_more_options
			t.change :foo_column, :string
			t.rename :baz_column, :bar_column, :string
			t.remove_index :name => 'foo_index'
		end

		expected_pt_command = [
			"pt-online-schema-change h=bar_host,u=baz_user,p=biz_password,D=foo_database,t=foo_table --execute --print --no-check-alter --critical-load 'Threads_running:50' --alter",
			"'drop column new_column, drop column another_new_column, drop column new_column_with_more_options,",
			"modify column foo_column varchar(255), change column baz_column bar_column varchar(255), drop index foo_index'"
		]

		expected = "nohup #{expected_pt_command.join(' ')} >#{@test_migration.name}_foo_table.nohup.out 2>&1"
		assert_equal expected, @test_migration.cmd
	end


	def test_simple_migration
		@test_migration.online_alter_table :foo_table, :execute do |t|
			t.integer :new_column_name
		end

		expected_pt_command = "pt-online-schema-change h=stub_host,u=stub_user,p=stub_password,D=stub_db,t=foo_table --execute --print --alter 'add column new_column_name int(11)'"
		expected = "nohup #{expected_pt_command} >#{@test_migration.name}_foo_table.nohup.out 2>&1"
		assert_equal expected, @test_migration.cmd
	end


	def test_simple_dry_run
		@test_migration.online_alter_table :foo_table do |t|
			t.integer :new_column_name
		end

		expected_pt_command = "pt-online-schema-change h=stub_host,u=stub_user,p=stub_password,D=stub_db,t=foo_table --dry-run --print --alter 'add column new_column_name int(11)'"
		expected = "nohup #{expected_pt_command} >#{@test_migration.name}_foo_table.nohup.out 2>&1"
		assert_equal expected, @test_migration.cmd
	end


	def test_announce_pass_through
		@test_migration.online_alter_table :foo_table do |t|
			t.integer :new_column_name
		end
		@test_migration.announce 'this should pass through'
		assert_nil @test_migration.puts_message =~ /pt-online-schema-change/
		assert_not_nil @test_migration.puts_message =~ /this should pass through/
	end


	def test_announce_migrated
		@test_migration.online_alter_table :foo_table do |t|
			t.integer :new_column_name
		end
		@test_migration.announce 'migrated, this should get cut off'
		assert_not_nil @test_migration.puts_message =~ /pt-online-schema-change dry-run complete this/
	end


	def test_announce_reverted
		@test_migration.online_alter_table :foo_table, :execute do |t|
			t.integer :new_column_name
		end
		@test_migration.announce 'reverted, this should get appended'
		assert_not_nil @test_migration.puts_message =~ /pt-online-schema-change executed, reverted, this should get appended/
	end
end
