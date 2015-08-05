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
-u|--user user
-h|--host canvas server
```

### Templates
The following commands allow creating, deleting and modifying Canvas templates.

##### Usage:
The general form for adding, deleting, modifying and synchronising templates is described as:
```
cnv template add|mod[ify] [user:]template [--name] [--description] [--includes]
cnv template del[ete] [user:]template
cnv template sync [user:]template [--clean]
```

#### Adding Templates:
Adding a new blank template identifed as "htpc" to the canvas user "firnsy".
```
cnv template add firnsy:htpc
```

Adding a new template identifed as "htpc" to the canvas user "firnsy" that is based on the "core" template from canvas user "kororaproject".
```
cnv template add firnsy:htpc --includes kororaproject:core
```

#### Deleting Templates:
```
cnv template del firnsy:htpc
cnv template mod firnsy:htpc --description= --includes kororaproject:gnome
```

#### Synchronising Templates:
Synchronising templates with the existing system.
```
cnv template sync [user:]template [--clean]
```

### Template Packages
The following commands allow adding and deleting of packages from specified Templates.

##### Usage:
The general usage for adding and removing packages from templates is described as:
```
cnv package add|del[ete] [user:]template package1 package2 ... packageN
```

#### Adding Packages

```
cnv package add firnsy:htpc foo @bar baz
cnv package add firnsy:htpc foo
```

#### Deleting Packages
```
cnv package del firnsy:htpc @bar
cnv package del firnsy:htpc foo baz
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
cvn machine add|del[ete] [user:]name [--description=] [--template=]
cvn machine mod[ify] [--description=] [--template=]

cvn machine sync [user:]name
cvn machine cmd [user:]name command arg1 arg2 ... argN
```


