# Canvas

Canvas is a Korora Project initiative to simplify the composition, distribution and management of customised Korora (and Fedora) systems. Canvas draws inspiration from a number of existing solutions that provide OS customisation and building including:

* [openSUSE Build Service](https://build.opensuse.org/)
* [Revisor](https://fedorahosted.org/revisor/), and
* [Spacewalk](https://fedorahosted.org/spacewalk/)

Some fundamental goals of the Canvas project include:

* To provide a simple and intuitive interface for system composition,
* Fitted for extensibility, and
* Allow trivial management of your Mum's install.

## Component Overview
The broad components understood to Canvas are:

 * Packages
 * Repos
 * Templates, and
 * Machines

Packages and Repos are the traditional representations as you know them. A package is an installable piece of software that provides a level of functionality for your system. Your OS is typically compsed of 100s to possibly 1000s of individual packages. Repos are the store for where Packages can be fetched from and installed.

Templates are the recipes for how particular systems are to be composed. They will specify the Repos available and the Packages to be installed to make the final compositions.

Machines are managed systems assigned a Template.

## Getting Started

#### Use Case #1
So `firnsy` has has just done a clean install and has his system package and repo selection just how he likes it. Let's make a template out of it for future usage; we'll call it `laptop`.
```
cnvs template add firnsy:laptop
cnvs template push firnsy:laptop
```

Let's say he then goes and adds some packages for to try out, crawls down some dependency rabbit holes installing packages left, right and centre. We have a problem, `firnsy` wants to go back to exactly how it was before he started messing around. Easy.

```
cnvs template pull firnsy:laptop --clean
```

Order restored.

#### Use Case #2

The `kororaproject` have just pushed out their fancy new `steam` template which turns your desktop into an awesome Steam focused gaming console experience and you want in. You've being fussing with this package and that package but couldn't get it quite right.

```
cnvs template pull kororaproject:steam --clean
shutdown -r now
```

Game on!

## Command Line Reference

The Canvas command line provides the necessary tools to add, update, remove, synchronise and command your systems to your will.

### Global Options
The following options are global to all commands:
```
-U|--user  # specify canvas user
-H|--host  # specify canvas server host
```

The default user is the name of the system user account invoking the `cnvs` command. The default user can also be specified in the `~/.config/canvas.conf`.

The default host is the Korora Project canvas server located at https://canvas.kororaproject.org/. The default host can also be specified in the `~/.config/canvas.conf`.

### Configuration

#### Command Overview
The following commands are available for the management of Canvas templates:
```
cnvs config [--unset] name [value]
```

You can query/set/replace/unset options with this command. The `name` is actually the section and the key separated by a dot, and the value will be escaped.

### Templates
The following commands allow adding, removing, modifying, querying and synchronising Canvas templates.

#### Command Overview
The following commands are available for the management of Canvas templates:
```
cnvs template add [user:]template [--name] [--title] [--description] [--includes] [--public]
cnvs template update [user:]template [--name] [--title] [--description] [--includes] [--public]
cnvs template rm [user:]template
cnvs template push [user:]template
cnvs template pull [user:]template [--clean]
cnvs template diff [user:]template
cnvs template copy [user_from:]template_from [[user_to:]template_to]
cnvs template list
```

#### Adding Templates
The general usage for adding a new template to a Canvas user is described as:
```
cnvs template add [user:]template [--name] [--title] [--description] [--includes] [--public]
```

For example, adding a new blank template identifed as `htpc` to the Canvas user `firnsy`.
```
cnvs template add firnsy:htpc
```

Adding a new template identifed as `htpc` to the Canvas user `firnsy` that is based on the `core` template from canvas user `kororaproject`.
```
cnvs template add firnsy:htpc --includes kororaproject:core
```

When adding new templates they will be private by default. If you wish to make your templates available for others to see then set the `--public` flag to a value of `true` or `1`.

#### Updating Templates
The general usage for updating an existing template of a Canvas user is described as:
```
cnvs template update [user:]template [--name] [--title] [--description] [--includes] [--public]
```

Updating the name and description of existing template `htpc` of Canvas user `firnsy`.
```
cnvs template update firnsy:htpc --name="Firnsy's HTPC" --description="Ultimate HTPC recipe!"
```

#### Removing Templates
The general usage for removing an existing template of a Canvas user is described as:
```
cnvs template rm [user:]template
```

Removing the existing template `htpc` from Canvas user `firnsy`.
```
cnvs template rm firnsy:htpc
```

#### Synchronising Templates
The general usage for synchronising an existing template of a Canvas user is described as:
```
cnvs template push [user:]template
cnvs template pull [user:]template [--clean]
```

For example the following command would install all packages and repos specified in the template `htpc` from the Canvas user `firnsy` to the current system. No packages would be removed from the current system.
```
cnvs template pull firnsy:htpc
```

To ensure the package and repos matched the specified template exactly, just add the `--clean` option. This will remove any packages and repos from the current system that are not specified in the template.
```
cnvs template pull firnsy:htpc --clean
```

To add the current packages and repos of the current system to the template.
```
cnvs template push firnsy:htpc
```

#### Diff Templates:
The general usage for viewing the differences between the current system's configuration and an existing template of a Canvas user is described as:
```
cnvs template diff [user:]template
```

For example, the following command would show the diff between the current system to the template `htpc` from Canvas user `firnsy`.
```
cnvs template diff firnsy:htpc
```

#### Copying Templates
The general usage for copying an existing template of a Canvas user to a new one is described as:
```
cnvs template copy [user_to:]template_from [[user_to:]template_to]
```

For example the following command would copy the `htpc` template from `kororaproject` to the template `my-htpc` for the Canvas user `firnsy`.
```
cnvs template copy kororaproject:htpc firnsy:my-htpc
```

If `firnsy` wanted to retain the same template name he could have abbreviated to:
```
cnvs template copy kororaproject:htpc
```

#### Listing Templates
The general usage for listing templates that are currently accessible is described as:
```
cnvs template list
```

```
cnvs template list
```

### Template Packages
The following commands allow management of packages from specified Templates.

#### Command Overview
The following commands are available for the management of Canvas template packages:
```
cnvs package add [user:]template package1 package2 ... packageN
cnvs package list [user:]template
cnvs package rm [user:]template package1 package2 ... packageN
```

#### Package Definition
When specifying packages it is possible to be as generic or explicit as you wish with regard to epoch, version, release and arch.

The syntax for package definitions is described as:
```
name[[#epoch]@version-release][:arch]
```
When `#epoch` is omitted, the latest epoch will be used.
When `@version-release` is omitted, the latest version and release number will be used.
When `:arch` is omitted, the architecture will be decided during installation according to the architecture of the target system and the architectures available for the package.

Note that a `version` and `release` must be specified together and can not be specified individually, and an `#epoch` cannot be specified without them.

Examples of package definitions include:
```
foo                   # name only
foo:x86_64            # name and arch
foo@2.1-3             # name, version and release
foo#1@2.1-3:x86_64    # name, epoch, version, release and arch
```


#### Adding Packages
The general usage for adding packages from templates is described as:
```
cnvs package add [user:]template package1 package2 ... packageN
```

```
cnvs package add firnsy:htpc foo @bar baz
cnvs package add firnsy:htpc buz
```

#### Removing Packages
The general usage for removing packages from templates is described as:
```
cnvs package rm [user:]template package1 package2 ... packageN
```

```
cnvs package rm firnsy:htpc @bar
cnvs package rm firnsy:htpc foo baz
```

#### Listing Packages
The general usage for listing packages in templates is described as:
```
cnvs package list [user:]template
```

```
cnvs package list firnsy:htpc
```

### Template Repos
The following commands allow management of repos from specified Templates.

#### Command Overview
The following commands are available for the management of Canvas template repos:
```
cnvs repo add [user:]template repo --baseurl=|--metalink=|--mirrorlist= [--cost=] [--enabled=] [--gpgkey=] [--name=] [--priority=]
cnvs repo update [user:]template repo --baseurl=|--metalink=|--mirrorlist= [--cost=] [--enabled=] [--gpgkey=] [--name=] [--priority=]
cnvs repo list [user:] template
cnvs repo rm [user:]template repo
```

#### Repos Definitions

The allowed characters of the `repo` ID string are lower and upper case alphabetic letters, digits, `-`, `_`, `.` and `:`.

##### Repo Options
`cost` (integer)

The relative cost of accessing this repository, defaulting to 1000. This value is compared when the priorities of two repositories are the same. The repository with the lowest cost is picked. It is useful to make the library prefer on-disk repositories to remote ones.

`baseurl` (list)

URLs for the repository.

`enabled` (boolean)

Include this repository as a package source. The default is True.

`gpgkey` (list of strings)

URLs of a GPG key files that can be used for signing metadata and packages of this repository, empty by default. If a file can not be verified using the already imported keys, import of keys from this option is attempted and the keys are then used for verification.

`metalink` (string)

URL of a metalink for the repository.

`mirrorlist` (string)

URL of a mirrorlist for the repository.

`name` (string)

A human-readable name of the repository. Defaults to the ID of the repository.

`priority` (integer)

The priority value of this repository, default is 99. If there is more than one candidate package for a particular operation, the one from a repo with the lowest priority value is picked, possibly despite being less convenient otherwise (e.g. by being a lower version).

`skip_if_unavailable` (boolean)

If enabled, DNF will continue running and disable the repository that couldn’t be contacted for any reason when downloading metadata. This option doesn’t affect skipping of unavailable packages after dependency resolution. To check inaccessibility of repository use it in combination with refresh command line option. The default is True.

#### Adding Repos
The general usage for adding repos from templates is described as:
```
cnvs repo add [user:]template repo --baseurl=|--metalink=|--mirrorlist= [--cost=] [--enabled=] [--gpgkey=] [--name=] [--priority=]
```

```
cnvs repo add firnsy:htpc rpmfusion --mirrorlist='http://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-$releasever&arch=$basearch'
```

#### Updating Repos
The general usage for updating repos from templates is described as:
```
cnvs repo update [user:]template repo --baseurl=|--metalink=|--mirrorlist= [--cost=] [--enabled=] [--gpgkey=] [--name=] [--priority=]
```

```
cnvs repo update firnsy:htpc rpmfusion --priority=50
```

#### Listing Repos
The general usage for listing repos in templates is described as:
```
cnvs repo list [user:]template
```

```
cnvs repo list firnsy:htpc
```

#### Removing Repos
The general usage for removing repos from templates is described as:
```
cnvs repo rm [user:]template repo
```

```
cnvs repo rm firnsy:htpc rpmfusion
```


### Machines
The following commands allow adding, removing and updating Canvas machines that are assigned templates. Machines are your configured Canvas systems that can be managed and easily synchronised with your latest configurations.

Machines have a 1-to-1 link with a Canvas template. For example you may assign your HTPC to a personalised template called `htpc`. Alternatively you may assign your laptop and desktop to your `all-my-favourite-things` template, any changes you make to the template would then be easily reflected on both your laptop and desktop computer.

#### Command Overview
The following commands are available for the management of Canvas machines:
```
cnvs machine add|update [user:]name [--description=] [--location=] [--name=] [--template=]
cnvs machine rm [user:]name
cnvs machine diff [user:]name
cnvs machine sync [user:]name [--pull [[user:]template]] | --push [user:]template]
cnvs machine cmd [user:]name command arg1 arg2 ... argN
```

#### Adding Machines
The general usage for adding a new managed machine to a Canvas user is described as:
```
cnvs machine add [user:]name [--description=] [--location=] [--name=] [--template=]
```

To add the current system as a managed machine named `odin` to the Canvas user `firnsy` linked to the `htpc` template from the same Canvas user is as follows:
```
cnvs machine add firnsy:odin --template firnsy:htpc
```

#### Updating Machines
The general usage for updating an existing managed machine of a Canvas user is described as:
```
cnvs machine add [user:]name [--description=] [--name=] [--template=]
```

For example to change the recently added machine from the `htpc` template to the `steam` template from Canvas user `firnsy` we can simply invoke:
```
cnvs machine update firnsy:odin --template firnsy:steam
```

#### Removing Machines
The general usage for removing an existing managed machine to a Canvas user is described as:
```
cnvs machine rm [user:]name
```

For example:
```
cnvs machine rm firnsy:odin
```

#### Diff Machines
To determine the state of a machine with respect to it's assigned template. Can be used to determine whether a machine requires re-sync with the template or not.

The general usage for diff'ing an existing managed machine of a Canvas user is described as:
```
cnvs machine diff [user:]name
```

For example to view the diff status of the machine `odin` of Canvas user `firnsy` relative to its assigned template can be done with the following command:
```
cnvs machine diff firnsy:odin
```

#### Synchronising Machines
The general usage for synchronising an existing managed machine of a Canvas user is described as:
```
cnvs machine sync [user:]name [--pull [[user:]template]] | --push [user:]template]
```

For example syncronizing machine `odin` of Canvas user `firnsy` is done with the following command:
```
cnvs machine sync firnsy:odin
```

To create a new template `custom` from machine `odin` of Canvas user `firnsy` to the same account, you can do:
```
cnvs machine sync firnsy:odin --push firnsy:custom
```

To revert the machine `odin` of Canvas user `firnsy` to the time of last sync, you can do:
```
cnvs machine sync firnsy:odin --pull
```

To reset the machine `odin` of Canvas user `firnsy` to the template `htpc` of Canvas user `firnsy`, simply:
```
cnvs machine sync firnsy:odin --pull firnsy:htpc
```

#### Commanding Machines
The general usage for sending a command to an existing managed machine of a Canvas user is described as:
```
cnvs machine cmd [user:]name command arg1 arg2 ... argN
```

Examples of running remote commands on the machine `odin` of Canvas user `firnsy` are shown below.
```
cnvs machine cmd firnsy:odin cat /etc/passwd
cnvs machine cmd firnsy:odin ls /home
cnvs machine cmd firnsy:odin shutdown -h now
cnvs machine cmd firnsy:odin bash
```


