require "pt_online_migration/version"
require "pt_online_migration/pt_command_builder"

module PtOnlineMigration

	class ActiveRecord::Migration
		def online_alter_table(*args)
			raise "online_alter_table not supported within 'change' migration" if caller[0][/`.*'/][1..-2] == 'change'

			default_options = {:database => connection.current_database}
			options = default_options.merge(args.extract_options!.symbolize_keys)
			pt_command = PTCommandBuilder.new(args[0], options, args[1] == :execute)
			yield pt_command
			system(pt_command.command)
		end
	end
end

