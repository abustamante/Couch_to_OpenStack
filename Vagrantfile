# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'securerandom'

# remove the 'client' entry to below to save on host resources
nodes = {
    'proxy' => [1,10],
    'controller'  => [1, 200],
    'swift' => [5, 201],
#    'swift2' => [1, 202],
#    'swift3' => [1, 203],
#    'swift4' => [1, 204],
#    'swift5' => [1, 205],
}



# This is some magic to help avoid network collisions.
# If however, it still collides, or if you need to vagrant up machines one at a time, comment out this line and uncomment the one below it
#third_octet = SecureRandom.random_number(200)
third_octet = 80

Vagrant.configure("2") do |config|
  # We assume virtualbox, if using Fusion, you'll want to change this as needed
  config.vm.box = "precise64.box"
  config.vm.box_url = "http://files.vagrantup.com/precise64.box"
  #VMware Fusion\Workstation Users: Comment the line above and uncomment the appropriate line below
  #config.vm.box_url = "http://files.vagrantup.com/precise64_vmware.box"

  nodes.each do |prefix, (count, ip_start)|
    count.times do |i|
      if prefix=="swift"
      hostname = "%s" % [prefix, (i+1)] + (i+1).to_s
        config.vm.define "#{hostname}" do |box|
          box.vm.hostname = "#{hostname}.book"
          box.vm.network :private_network, ip: "172.16.#{third_octet}.#{ip_start+i}", :netmask => "255.255.0.0"
          box.vm.network :private_network, ip: "10.10.#{third_octet}.#{ip_start+i}", :netmask => "255.255.0.0"
          box.vm.network :private_network, ip: "192.168.#{third_octet}.#{ip_start+i}", :netmask => "255.255.255.0"

          # Run the Shell Provisioning Script file
          box.vm.provision :shell, :path => "#{prefix}.sh"

          # If using VMware Fusion
          box.vm.provider :vmware_fusion do |v|
          # Default  
            v.vmx["memsize"] = 1024
            if prefix == "compute"
              v.vmx["memsize"] = 2048
              v.vmx["numvcpus"] = 2
            end
          end

          # If using VMware Workstation
          box.vm.provider :vmware_workstation do |v|
          # Default  
            v.vmx["memsize"] = 1024
            if prefix == "compute"
              v.vmx["memsize"] = 3128
              v.vmx["numvcpus"] = 2
            elsif prefix == "controller"
              v.vmx["memsize"] = 2048
            elsif prefix == "client" or prefix == "proxy"
              v.vmx["memsize"] = 512
            end
          end
          # If using VirtualBox
          box.vm.provider :virtualbox do |vbox|
	      # Defaults
            vbox.customize ["modifyvm", :id, "--memory", 768]
            vbox.customize ["modifyvm", :id, "--cpus", 1]
            vbox.customize ["createhd", "--filename", "#{hostname}_disk_2.vdi", "--size", 2000 * 1024]
            vbox.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 1, "--device", 0, "--type","hdd", "--medium","#{hostname}_disk_2.vdi"]
           end
         end
	  else
      hostname = "%s" % [prefix, (i+1)]
        config.vm.define "#{hostname}" do |box|
          box.vm.hostname = "#{hostname}.book"
          box.vm.network :private_network, ip: "172.16.#{third_octet}.#{ip_start+i}", :netmask => "255.255.0.0"
          box.vm.network :private_network, ip: "10.10.#{third_octet}.#{ip_start+i}", :netmask => "255.255.0.0"
          box.vm.network :private_network, ip: "192.168.#{third_octet}.#{ip_start+i}", :netmask => "255.255.255.0"

          # Run the Shell Provisioning Script file
          box.vm.provision :shell, :path => "#{hostname}.sh"

          # If using VMware Fusion
          box.vm.provider :vmware_fusion do |v|
          # Default  
            v.vmx["memsize"] = 1024
            if prefix == "compute"
              v.vmx["memsize"] = 2048
              v.vmx["numvcpus"] = 2
            elsif prefix == "controller"
              v.vmx["memsize"] = 1024
            elsif prefix == "client" or prefix == "proxy"
              v.vmx["memsize"] = 512
            end
          end

          # If using VMware Workstation
          box.vm.provider :vmware_workstation do |v|
          # Default  
            v.vmx["memsize"] = 1024
            if prefix == "compute"
              v.vmx["memsize"] = 3128
              v.vmx["numvcpus"] = 2
            elsif prefix == "controller"
              v.vmx["memsize"] = 2048
            elsif prefix == "client" or prefix == "proxy"
              v.vmx["memsize"] = 512
            end
          end

          # If using VirtualBox
          box.vm.provider :virtualbox do |vbox|
	  # Defaults
            vbox.customize ["modifyvm", :id, "--memory", 768]
            vbox.customize ["modifyvm", :id, "--cpus", 1]
            if prefix == "client" or prefix == "proxy"
              vbox.customize ["modifyvm", :id, "--memory", 512]
            elsif prefix == "swift"
              hostname = "%s" % [prefix, (i+1)] + (i+1).to_s 
           end
          end  
        end
      end
    end
  end
end