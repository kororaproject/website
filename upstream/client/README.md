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

The Canvas command line provides the necessary tools to create, modify, synchronise and command your systems to your will.

##### Global Options
The following options are global to all commands:
```
-u|--user  # specify canvas user
-h|--host  # specify canvas server host
```

### Templates
The following commands allow creating, deleting and modifying Canvas templates.

##### Usage:
The general form for adding, deleting, modifying, pushing and pulling (revert) templates is described as:
```
cnvs template add|mod[ify] [user:]template [--name] [--description] [--includes]
cnvs template del[ete] [user:]template
cnvs template push [user:]template
cnvs template pull [user:]template [--clean]
cnvs template diff [user:]template
```

#### Adding Templates:
Adding a new blank template identifed as "htpc" to the Canvas user "firnsy".
```
cnvs template add firnsy:htpc
```

Adding a new template identifed as "htpc" to the Canvas user "firnsy" that is based on the "core" template from canvas user "kororaproject".
```
cnvs template add firnsy:htpc --includes kororaproject:core
```


#### Modifying Templates:
Modifying the name and description of existing template "htpc" of Canvas user "firnsy".
```
cnvs template mod firnsy:htpc --name="Firnsy's HTPC" --description="Ultimate HTPC recipe!"
```

#### Deleting Templates:
Deleting the existing template "htpc" from Canvas user "firnsy".
```
cnvs template del firnsy:htpc
```

#### Synchronising Templates:
Synchronising templates with the existing system.
```
cnvs template pull firnsy:htpc --clean
cnvs template push firnsy:htpc
```

#### Diff Templates:
Diff the specified template with current system.
```
cnvs template diff firnsy:htpc
```

### Template Packages
The following commands allow adding and deleting of packages from specified Templates.

##### Usage:
The general usage for adding and removing packages from templates is described as:
```
cnvs package add|del[ete] [user:]template package1 package2 ... packageN
```

#### Adding Packages
```
cnvs package add firnsy:htpc foo @bar baz
cnvs package add firnsy:htpc buz
```

#### Deleting Packages
```
cnvs package del firnsy:htpc @bar
cnvs package del firnsy:htpc foo baz
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
The following commands allow creating, deleting and modifying Canvas machines that are assigned templates. Machines are your configured Canvas systems that can be managed and easily synchronised with your latest configurations.


##### Usage:
The general usage for adding, deleting, modifying, synchronising and commanding your machines is described as:
```
cnvs machine add|del[ete] [user:]name [--description=] [--template=]
cnvs machine mod[ify] [--description=] [--template=]

cnvs machine sync [user:]name
cnvs machine cmd [user:]name command arg1 arg2 ... argN
```

#### Adding Machines
```
cnvs machine add firnsy:odin --template firnsy:htpc
```

#### Modifying Machines
```
cnvs machine mod firnsy:odin --template firnsy:steam
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
```


#### Deleting Machines
```
cnvs machine del firnsy:odin
```

