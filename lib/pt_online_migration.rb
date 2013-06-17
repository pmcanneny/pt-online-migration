require "pt_online_migration/version"
require "pt_online_migration/pt_command_builder"

module PtOnlineMigration

	class PtOnlineMigrationError < ActiveRecord::ActiveRecordError
	end

	class ActiveRecord::Migration
		attr_accessor :executed, :is_online_schema_change

		def executed?
			return @executed != false
		end


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

			host = Rails.configuration.database_configuration[Rails.env]['host']
			default_options = {:host => host, :database => connection.current_database}
			options = default_options.merge(args.extract_options!.symbolize_keys)
			pt_command = PTCommandBuilder.new(args[0], options, args[1] == :execute)
			@executed = args[1] == :execute
			yield pt_command
			system(pt_command.command)
			unless $?.success?
				raise PtOnlineMigrationError.new
			end
		end
	end


	class ActiveRecord::MigrationProxy
		delegate :executed?, :to => :migration
	end


	class ActiveRecord::Migrator
		alias_method :orig_record_version_state_after_migrating, :record_version_state_after_migrating

		def record_version_state_after_migrating(version)
			active_migration = migrations.detect { |m| m.version == version }

			if active_migration.executed?
				orig_record_version_state_after_migrating(version)
			end
		end
	end
end

