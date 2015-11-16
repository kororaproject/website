# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "kp-canvas"
  config.vm.box_url = "https://download.fedoraproject.org/pub/fedora/linux/releases/22/Cloud/x86_64/Images/Fedora-Cloud-Base-Vagrant-22-20150521.x86_64.vagrant-libvirt.box"

  config.vm.network "forwarded_port", guest: 3000, host: 3000

  config.vm.provider :libvirt do |domain|
    # Increase memory so that we can build Mojo::Pg from cpan
    domain.memory = 1024
  end

  config.vm.provision "shell", path: "vagrant/provision.sh", args: "provision"
end
