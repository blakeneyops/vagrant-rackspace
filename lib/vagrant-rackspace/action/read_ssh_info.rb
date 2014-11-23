require "log4r"

module VagrantPlugins
  module Rackspace
    module Action
      # This action reads the SSH info for the machine and puts it into the
      # `:machine_ssh_info` key in the environment.
      class ReadSSHInfo
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_rackspace::action::read_ssh_info")
        end

        def call(env)
          env[:machine_ssh_info] = read_ssh_info(env[:rackspace_compute], env[:machine])

          @app.call(env)
        end

        def read_ssh_info(rackspace, machine)
          return nil if machine.id.nil?

          # Find the machine
          server = rackspace.servers.get(machine.id)
          if server.nil?
            # The machine can't be found
            @logger.info("Machine couldn't be found, assuming it got destroyed.")
            machine.id = nil
            return nil
          end

          # Read the DNS info
          user = machine.config.ssh.username
          @logger.info("SSH username: " + user)
          return {
            :host => get_ip(server, machine),
            :port => 22,
            :username => user
          }
        end
        
        def get_ip(server, machine)
                
          # Default to public networking
          ip_network = 'public'
          
          machine.config.vm.networks.each do |type, options|
            # We only handle private and public networks
            next if type != :private_network && type != :public_network
            
            if type == :private_network
              @logger.info("Private network selected.")
              ip_network = 'private'
              
              if options[:ip]
                @logger.info("Static IP not supported by this provider. Using DHCP.")
              end
              break
            end
          end
          
          # Retrieve IP addresses for specified network
          if !server.addresses.has_key?(ip_network)
            # The network can't be found
            @logger.info("IP network couldn't be found. Returning default IP address.")
            return server.ipv4_address
          end
          
          # Find IPv4 address
          addresses = server.addresses.fetch(ip_network)
          addresses.each do |address|
            if address.fetch('version') == 4
              return address.fetch('addr')
            end
          end
          
          # Return the default IP address if a suitable address cannot be found
          @logger.info("Suitable address couldn't be found in the specified network. Returning default IP address.")
          return server.ipv4_address
                      
        end
      end
    end
  end
end
