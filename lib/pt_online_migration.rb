require "pt_online_migration/version"
require "pt_online_migration/pt_command_builder"

module PtOnlineMigration

	class PtOnlineMigrationError < ActiveRecord::ActiveRecordError
	end

	class ActiveRecord::Migration
		alias_method :orig_announce, :announce

		def announce(message)
			new_message = message
			if @is_online_schema_change and message =~ /^(migrated|reverted)/
				if @executed
					new_message = 'pt-online-schema-change executed, %s' % message
				else
					new_message = 'pt-online-schema-change dry-run complete %s' % message.split(' ')[1]
				end
			end
			orig_announce new_message
		end


		def online_alter_table(*args)
			raise "online_alter_table not supported within 'change' migration" if caller[0][/`.*'/][1..-2] == 'change'

			@is_online_schema_change = true

			host, username, password = Rails.configuration.database_configuration[Rails.env].values_at('host', 'username', 'password')
			default_options = {:host => host, :username => username, :password => password, :database => connection.current_database}
			options = default_options.merge(args.extract_options!.symbolize_keys)
			pt_command = PTCommandBuilder.new(args[0], options, args[1] == :execute)
			@executed = args[1] == :execute
			yield pt_command
			puts pt_command.command
			system("nohup #{pt_command.command} >#{@name}_#{pt_command.table_name}.nohup.out 2>&1")
			unless $?.success?
				raise PtOnlineMigrationError.new
			end
		end
	end
end

