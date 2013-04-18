
module PtOnlineMigration

	class PTCommandBuilder

		def initialize(table_name, options, execute)
			@table_name = table_name
			@cmd_prefix = "pt-online-schema-change D=#{options.delete(:database)},t=#{table_name} "
			@cmd_prefix += execute ? '--execute' : '--dry-run'
			@pt_options = options
			@alter_statements = []
		end


		%w( string text integer float decimal datetime timestamp time date binary boolean ).each do |type|
			class_eval <<-EOV
				def #{type}(*args)
					options = args.extract_options!
					args.each do |name|
						add_column(name, :#{type}, options)
					end
				end
			EOV
		end


		def add_column(name, type, options)
			alter_statement
			definition = column_definition(type, options)
			@alter_statements.push "add column #{name.to_s} #{definition}"
		end


		def index(columns, options = {})
			alter_statement
			columns = [columns] unless columns.class == Array
			options[:name] ||= "#{@table_name}_#{columns.join('_')}_index"
			@alter_statements.push "add#{' unique' if options[:unique]} index #{options[:name].to_s} (#{columns.join(', ')})"
		end


		def rename(old_name, new_name, type, options = {})
			alter_statement
			@cmd_prefix += ' --no-check-alter'
			definition = column_definition(type, options)
			@alter_statements.push "change column #{old_name} #{new_name} #{definition}"
		end


		def command
			@pt_options.map do |k, v|
				@cmd_prefix += " --#{k.to_s.gsub('_', '-')} '#{v}'"
			end

			return "#{@cmd_prefix} #{@modification_type || ''} '#{@alter_statements.join(', ')}'"
		end


		def change(name, type, options = {})
			alter_statement
			definition = column_definition(type, options)
			@alter_statements.push "modify column #{name.to_s} #{definition}"
		end


		def remove(*column_names)
			alter_statement
			column_names.each do |name|
				@alter_statements.push "drop column #{name.to_s}"
			end
		end


		def remove_index(options)
			alter_statement
			options = {:column => options} if options.class == Symbol
			index = name_index(options)
			@alter_statements.push "drop index #{index}"
		end

		private

		def alter_statement
			@modification_type ||= '--alter'
		end


		def column_definition(type, options)
			default_options = {:default => :no_default, :precision => 1, :null => true, :scale => 0}
			options = options.merge(default_options){|k, incoming, default| options.key?(k) ? incoming : default}

			column_definition = case type
				when :binary then 'blob'
				when :boolean then 'tinyint(1)'
				when :date then 'date'
				when :datetime then 'datetime'
				when :decimal then "decimal(#{options[:precision]}, #{options[:scale]})"
				when :float then 'float'
				when :integer then options[:limit] ? "int(#{options[:limit]})" : 'int(11)'
				when :string then options[:limit] ? "varchar(#{options[:limit]})" : 'varchar(255)'
				when :text then 'text'
				when :time then 'time'
				when :timestamp then 'datetime'
				else type.to_s
			end

			column_definition += ' not null' if options[:null] == false
			options[:default] ||= 'null'
			column_definition += " default #{options[:default]}" unless options[:default] == :no_default
			column_definition += ' auto_increment' if options[:auto_increment]
			column_definition += ' first' if options[:first]
			column_definition += " after #{options[:first]}" if options[:first]

			return column_definition
		end


		def name_index(options)
			return "#{@table_name}_#{options[:column]}_index" if options[:column]
			return "#{@table_name}_#{options[:column].join('_')}_index" if options[:columns]
			return options[:name] if options[:name]
			raise ArgumentError, "unable to determine index from #{options.inspect}"
		end
	end
end
