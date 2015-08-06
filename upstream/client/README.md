# Canvas

## Component Overview
The broad components understood to Canvas are:

 * Packages
 * Repos
 * Templates, and
 * Machines

Packages and Repos are the traditional representations as you know them. A package is an installing piece of software that provides a level of functionality for your system. Your OS is typically compsed of 100s to possibly 1000s of individual packages. Repos are the store for where Packages can be fetched from and installed.

Templates are the recipes for how particular systems are to be composed. They will specify the Repos available and the Packages to be installed to make the final compositions.

Machines are managed systems assigned a Template.

## Command Line Interface

The Canvas command line provides the necessary tools to add, update, remove, synchronise and command your systems to your will.

### Global Options
The following options are global to all commands:
```
-U|--user  # specify canvas user
-H|--host  # specify canvas server host
```

The default user is the name of the system user account invoking the `cnvs` command. The default user can also be specified in the `~/.config/canvas.conf`.

The default host is the Korora Project canvas server located at https://canvas.kororaproject.org/. The default host can also be specified in the `~/.config/canvas.conf`.

### Templates
The following commands allow adding, removing and updating and synchronising Canvas templates.

#### Command Overview
```
cnvs template add [user:]template [--name] [--description] [--includes]
cnvs template update [user:]template [--name] [--description] [--includes]
cnvs template rm [user:]template
cnvs template push [user:]template
cnvs template pull [user:]template [--clean]
cnvs template diff [user:]template
```

#### Adding Templates
The general usage for adding a new template to a Canvas user is described as:
```
cnvs template add [user:]template [--name] [--description] [--includes]
```

For example, adding a new blank template identifed as `htpc` to the Canvas user `firnsy`.
```
cnvs template add firnsy:htpc
```

Adding a new template identifed as `htpc` to the Canvas user `firnsy` that is based on the `core` template from canvas user `kororaproject`.
```
cnvs template add firnsy:htpc --includes kororaproject:core
```


#### Updating Templates
The general usage for updating an existing template of a Canvas user is described as:
```
cnvs template update [user:]template [--name] [--description] [--includes]
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
The general usage for synchronising existing templates of a Canvas user is described as:
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
The general usage for viewing the diff between the current system and an existing template of a Canvas user is described as:
```
cnvs template diff [user:]template
```

For example, the following command would show the diff between the current system to the template `htpc` from Canvas user `firnsy`.
```
cnvs template diff firnsy:htpc
```

### Template Packages
The following commands allow adding and removing of packages from specified Templates.

##### Usage:
The general usage for adding and removing packages from templates is described as:
```
cnvs package add|rm [user:]template package1 package2 ... packageN
```

#### Adding Packages
```
cnvs package add firnsy:htpc foo @bar baz
cnvs package add firnsy:htpc buz
```

#### Removing Packages
```
cnvs package rm firnsy:htpc @bar
cnvs package rm firnsy:htpc foo baz
```

#### Package Definition
When specifying packages it is possible to be as generic or explicit as you wish with regard to epoch, version, release and arch.

The package definition described as:
```
name[[#epoch]:version-release][!arch]
```
Note that a version and revision must be specified together and can not be specified individually.

Examples of package definitions include:
```
foo                   # name only
foo!x86_64            # name and arch
foo:2.1-3             # name, version and release
foo#1:2.1-3!x86_64    # name, epoch, version, release and arch
```

### Machines
The following commands allow adding, removing and updating Canvas machines that are assigned templates. Machines are your configured Canvas systems that can be managed and easily synchronised with your latest configurations.


#### Command Overview
```
cnvs machine add|update [user:]name [--description=] [--name=] [--template=]
cnvs machine rm[ete] [user:]name

cnvs machine diff [user:]name
cnvs machine sync [user:]name
cnvs machine cmd [user:]name command arg1 arg2 ... argN
```

#### Adding Machines
```
cnvs machine add firnsy:odin --template firnsy:htpc
```

#### Updating Machines
```
cnvs machine update firnsy:odin --template firnsy:steam
```

#### Diff Machines
Determine the state of a machine with respect to it's assigned template. Can be used to determine whether a machine requires re-sync with the template or not.
```
cnvs machine diff firnsy:odin
```

#### Synchronising Machines

```
cnvs machine sync firnsy:odin
```

#### Commanding Machines

```
cnvs machine cmd firnsy:odin cat /etc/passwd
cnvs machine cmd firnsy:odin ls /home
cnvs machine cmd firnsy:odin shutdown -h now
cnvs machine cmd firnsy:odin bash
```

#### Removing Machines
```
cnvs machine rm firnsy:odin
```

