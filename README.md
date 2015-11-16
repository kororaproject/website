---------------------------------------------------------------------
0. INTRODUCTION
---------------------------------------------------------------------

Canvas is an open, lightweight framework providing:
  - package browser,
  - package inventory management, and
  - machine inventory management


Canvas was developed for the Korora ecosystem.

---------------------------------------------------------------------
 1. INSTALLING
---------------------------------------------------------------------
Korora Canvas can be install either as a [Vagrant](https://www.vagrantup.com/) box, or installed locally on a linux machine.

   1. Vagrant

   Install Vagrant:
   ```bash
   dnf install -y vagrant vagrant-libvirt
   ```
   Bring up the vagrant box:
   ```bash
   vagrant up
   ```

   2. Local

   Install the pre-requisites:
   ```bash
   sudo ./vagrant/provision.sh

   ```
   Run canvasd (via morbo for development)  
   ```bash
   morbo ./canvasd
   ```


Test server by listing templates with the test user:
```bash
cd client/
./cnvs template list -U test -H 'http://localhost:3000'
```
You will prompted for a password, the default password for the test user is:
> password

The server will then list the available templates:
> ./cnvs template list -U test -H 'http://localhost:3000'

> Password (test):

>0 templates found.
