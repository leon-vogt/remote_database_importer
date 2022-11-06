module RemoteDatabaseImporter
  class Config
    require "tty/config"
    require "colorize"

    def initialize
      @config = TTY::Config.new
      @config.filename = "remote_database_importer"
      @config.extname = ".yml"
      @config.append_path Dir.pwd
    end

    def read_or_create_configfile
      unless @config.exist?
        puts "===========================================================".colorize(:green)
        puts "Hi there! There is no config file yet, lets create one! 😄"
        create_default_config
        config_location = [@config.filename, @config.extname].join
        puts "Created config file: #{config_location}"
        puts "===========================================================".colorize(:green)
      end
      @config.read
    end

    def ask(question, default: nil, options: nil)
      question += " (#{options.join(" / ")})" if options.present?
      question += " [#{default}]" if default.present?

      puts question.colorize(:light_blue)
      answer = $stdin.gets.chomp
      answer.present? ? answer : default
    end

    def create_default_config
      enter_new_environments = true
      environment_count = 1

      local_db_name = ask("Whats the name of the local database you wanna import to?", default: "myawesomeapp_development")
      @config.set(:local_db_name, value: local_db_name)
      puts

      while enter_new_environments
        puts "#{environment_count}. Environment".colorize(:green)
        env = ask("Whats the name of the #{environment_count}. environment you wanna add?", default: "staging")
        puts

        puts "Database settings:".colorize(:green)
        db_name = ask("Enter the DB name for the #{env} environment:", default: "myawesomeapp_#{env}")
        db_user = ask("Enter the DB user for the #{env} environment:", default: "deployer")
        puts

        puts "Connection settings:".colorize(:green)
        host = ask("Enter the IP or hostname of the DB server:", default: "myawesomeapp.com")
        dump_type = ask("Should the DB dump happen over a ssh tunnel or can pg_dump connect to the DB port directly?", default: "pg_dump", options: ["ssh_tunnel", "pg_dump"])

        ssh_user, ssh_port, postgres_port = nil
        if dump_type == "ssh_tunnel"
          ssh_user = ask("Enter the username for the SSH connection:", default: "deployer")
          ssh_port = ask("Enter the port for the SSH connection:", default: "22")
        else
          postgres_port = ask("Enter the database port for the pg_dump command:", default: "5432")
        end
        puts

        env_config = {
          env.to_s => {
            "database" => {
              "name" => db_name,
              "user" => db_user
            },
            "connection" => {
              "host" => host,
              "dump_type" => dump_type,
              "postgres_port" => postgres_port,
              "ssh_user" => ssh_user,
              "ssh_port" => ssh_port
            }
          }
        }
        @config.append(env_config, to: :environments)

        continue = ask("Do you wanna add another environment? (anything other than 'yes' will exit)")
        if continue&.downcase == "yes"
          environment_count += 1
        else
          enter_new_environments = false
        end
      end

      puts "Define custom commands that run after successful import:".colorize(:green)
      custom_commands = ask("Enter semicolon separated commands that should run after importing the DB:", default: "rake db:migrate; echo 'All Done'")
      puts

      @config.set(:custom_commands, value: custom_commands)
      @config.write
    end
  end
end
