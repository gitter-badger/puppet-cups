# The CUPS module

[![Build Status](https://travis-ci.org/leoarnold/puppet-cups.svg)](https://travis-ci.org/leoarnold/puppet-cups)
[![Test Coverage](https://codeclimate.com/github/leoarnold/puppet-cups/badges/coverage.svg)](https://codeclimate.com/github/leoarnold/puppet-cups/coverage)
[![Code Climate](https://codeclimate.com/github/leoarnold/puppet-cups/badges/gpa.svg)](https://codeclimate.com/github/leoarnold/puppet-cups)
[![Gemnasium](https://img.shields.io/gemnasium/leoarnold/puppet-cups.svg)](https://gemnasium.com/leoarnold/puppet-cups)
[![Puppet Forge Version](http://img.shields.io/puppetforge/v/leoarnold/cups.svg)](https://forge.puppetlabs.com/leoarnold/cups)
[![Puppet Forge Downloads](http://img.shields.io/puppetforge/dt/leoarnold/cups.svg)](https://forge.puppetlabs.com/leoarnold/cups)
[![MIT License](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE)

#### Table of Contents

1. [Description](#description)
1. [Setup](#setup)
    * [What cups affects](#what-cups-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with cups](#beginning-with-cups)
1. [Usage - A quick start guide](#usage)
    * [Managing printers](#managing-printers)
    * [Managing classes](#managing-classes)
    * [Configuring queues](#configuring-queues)
    * [Configuring CUPS](#configuring-cups)
    * [Using Hiera](#using-hiera)
1. [Reference - The documentation of all features available](#reference)
    * [Classes](#classes)
    * [Defines](#defines)
    * [Types](#types)
    * [Facts](#facts)
1. [Limitations](#limitations)
1. [Contributing - Guidelines for users and developers](#contributing)

## Description

This module installs, configures, and manages the Common Unix Printing System (CUPS) service.

It provides Puppet types to install, configure, and manage CUPS printer queues and classes.

Key design goals include *locale independence* and *test driven development*.

## Setup

### What cups affects

  * The CUPS packages will be installed.

  * The CUPS service will be enabled and launched.

  * The files in `/etc/cups/` will be modified using CUPS command line utilities.

  * The file `/etc/cups/lpoptions` will be deleted. See the section on [limitations](#option-defaults) for details.

### Setup Requirements

This module is written in Ruby 1.9 syntax and tested on systems using

  * Ruby 1.9+ or 2.x

  * CUPS 1.5+ or 2.x

It might also work with CUPS versions prior to 1.5 after [manually installing](http://www.cups.org/software.php?VERSION=ipptool)
the `ipptool` command line utility. It will however **not** work with Ruby versions prior to 1.9.

### Beginning with CUPS

First you need to install this module. One way to do this is

  ```puppet
  puppet module install leoarnold-cups
  ```

All resources in this module require the CUPS daemon to be installed and configured in a certain way.
To ensure these preconditions you should include the main `cups` class wherever you use this module:

  ```puppet
  include '::cups'
  ```

See the [section](#class-cups) on the `cups` class for details.
Adding printer or class resources is described in the section on [usage](#usage).

## Usage

In this section, you will learn the straightforward way to set up CUPS queues from scratch.
If the queues are already installed on the node, you can easily obtain a manifest with their current configuration by running

  ```Shell
  puppet resource cups_queue
  ```

and adjust it following the instructions on [configuring queues](#configuring-queues).

### Managing Printers

There are several ways to set up a printer queue in CUPS.
This section provides the minimal manifest for each method.

**Note** These minimal manifests will *not* update or change the PPD file on already existing queues,
as CUPS does not provide a robust way to determine how the queue was installed.
See however the section on [changing the driver](#changing-the-driver) for a workaround.

If you are unsure which way to choose, we recommend to set up the printer
using the tools provided by your operating system (or the [CUPS web interface](http://localhost:631)),
then take the corresponding PPD file from `/etc/cups/ppd/` and use the `ppd` method.

Minimal printer manifests:

  * Creating a local raw printer:

    ```puppet
    include '::cups'

    cups_queue { 'MinimalRaw':
      ensure => 'printer',
      uri    => 'lpd://192.168.2.105/binary_p1' # Replace with your printer's URI
    }
    ```

    To configure this queue see the section on [setting the usual options](#configuring-queues) or the [type reference](#type-cups_queue).

  * Using a suitable model from the output of the command `lpinfo -m` on the node:

    ```puppet
    include '::cups'

    cups_queue { 'MinimalModel':
      ensure => 'printer',
      model  => 'drv:///sample.drv/generic.ppd',
      uri    => 'lpd://192.168.2.105/binary_p1' # Replace with your printer's URI
    }
    ```

    To configure this queue see the section on [setting the usual options](#configuring-queues) or the [type reference](#type-cups_queue).

  * Using a custom PPD file:

    ```puppet
    include '::cups'

    cups_queue { 'MinimalPPD':
      ensure => 'printer',
      ppd    => '/usr/share/cups/model/myprinter.ppd',
      uri    => 'lpd://192.168.2.105/binary_p1' # Replace with your printer's URI
    }
    ```

    To configure this queue see the section on [setting the usual options](#configuring-queues) or the [type reference](#type-cups_queue).

    In a master-agent setting, you could transfer the PPD file to the client using a `file` resource

    ```puppet
    file { '/usr/share/cups/model/myprinter.ppd':
      ensure => 'file',
      source => 'puppet:///modules/myModule/myprinter.ppd'
    }
    ```

    which will be autorequired by `Cups_queue['MinimalPrinter']`.

  * Using a System V interface script:

    ```puppet
    include '::cups'

    cups_queue { 'MinimalInterface':
      ensure    => 'printer',
      interface => '/usr/share/cups/model/myprinter.sh',
      uri       => 'lpd://192.168.2.105/binary_p1' # Replace with your printer's URI
    }
    ```

    To configure this queue see the section on [setting the usual options](#configuring-queues) or the [type reference](#type-cups_queue).

    In a master-agent setting, you could transfer the interface script to the client using a `file` resource

    ```puppet
    file { '/usr/share/cups/model/myprinter.sh':
      ensure => 'file',
      source => 'puppet:///modules/myModule/myprinter.sh'
    }
    ```

    which will be autorequired by `Cups_queue['MinimalPrinter']`.

#### Changing the driver

When a printer queue is already present and managed using a PPD file, it is generally hard to tell which model or PPD file was used to install the queue.
Nevertheless it might become necessary to change the model or update the PPD file *without* changing the queue name, e.g. because the PPD file contains some login credentials.

This module introduces a way to update the driver (i.e. force a reinstall) through syncing the `make_and_model` property, which defaults to

  * the `NickName` (fallback `ModelName`) value from the printer's PPD file in `/etc/cups/ppd/` if the printer was installed using a PPD file or a model.

  * `Local System V Printer` if the printer uses a System V interface script.

  * `Local Raw Printer` for raw print queues.

**Example:** On the node, running `puppet resource cups_queue Office` returns

  ```puppet
  cups_queue { 'Office':
    ensure         => 'printer',
    make_and_model => 'HP Color LaserJet 4730mfp Postscript (recommended)',
    ...
  }
  ```

and you would like to

  * use a different model

    ```Shell
    $ lpinfo -m | grep 4730mfp
    ...
    drv:///hpcups.drv/hp-color_laserjet_4730mfp-pcl3.ppd HP Color LaserJet 4730mfp pcl3, hpcups 3.14.3
    postscript-hp:0/ppd/hplip/HP/hp-color_laserjet_4730mfp-ps.ppd HP Color LaserJet 4730mfp Postscript (recommended)
    ...
    ```

    then you just need to adapt the manifest from above to

    ```puppet
    cups_queue { 'Office':
      ensure         => 'printer',
      model          => 'drv:///hpcups.drv/hp-color_laserjet_4730mfp-pcl3.ppd',
      make_and_model => 'HP Color LaserJet 4730mfp pcl3, hpcups 3.14.3',
      ...
    }
    ```

  * use a custom PPD file instead which contains the line

    ```
    *NickName: "HP Color LaserJet 4730mfp Postscript (MyCompany v2)"
    ```

    then you just need to adapt the manifest from above to

    ```puppet
    cups_queue { 'Office':
      ensure         => 'printer',
      ppd            => '/usr/share/cups/model/hp4730v2.ppd',
      make_and_model => 'HP Color LaserJet 4730mfp Postscript (MyCompany v2)',
      ...
    }
    ```

  * use a System V interface script, then you just need to adapt the manifest from above to

    ```puppet
    cups_queue { 'Office':
      ensure         => 'printer',
      interface      => '/usr/share/cups/model/myprinter.sh',
      make_and_model => 'Local System V Printer',
      ...
    }
    ```

    This will, however, **not** work if the printer was already using a System V interface script (and hence the `make_and_model` would not change).
    Instead, you can just sync the script right to the place where CUPS expects it:

    ```puppet
    include '::cups'

    file { '/etc/cups/interfaces/Office':
      ensure => 'file',
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
      source => 'puppet:///modules/myModule/myprinter.sh'
    }

    cups_queue { 'Office':
      ensure    => 'printer',
      interface => '/etc/cups/interfaces/Office',
      ...
    }
    ```

  * make it a raw queue. Then you just need to adapt the manifest from above to

    ```puppet
    cups_queue { 'Office':
      ensure         => 'printer',
      make_and_model => 'Local Raw Printer',
      ...
    }
    ```

### Managing Classes

When defining a printer class, it is *mandatory* to also define its member printers in the same catalog:

  ```puppet
  include '::cups'

  cups_queue { 'MinimalClass':
    ensure  => 'class',
    members => ['Office', 'Warehouse']
  }

  cups_queue { 'Office':
    ensure => 'printer',
    ...
  }

  cups_queue { 'Warehouse':
    ensure => 'printer',
    ...
  }
  ```

The `Cups_queue['MinimalClass']` resource will autorequire its member resources `Cups_queue['Office', 'Warehouse']`.

### Configuring queues

Once you have your minimal [printer](#managing-printers) or [class](#managing-classes) manifest, you will need to apply some configuration.

**Job handling:**
In CUPS, newly installed queues are disabled and rejecting by default, which can lead to confusion at times.
The corresponding `cups_queue` properties are:

  * `accepting`: Should incoming jobs be enqueued or rejected?

  * `enabled`: Should pending jobs be sent to the device or kept pending?

If you want your print queues to "just work", you should set both to `true` by default using

  ```puppet
  # Default values for all 'cups_queue' resources in the current scope:
  # Use 'Cups_queue' with upper case first letter and without resource name
  Cups_queue {
    accepting => 'true',
    enabled   => 'true',
  }
  ```

This module does not set default values by itself, since it might be of disadvantage in a professional copy shop environment.

**Option defaults:**
Sometimes you need to set some default values for CUPS or vendor options of a print queue,
e.g. to enable Duplex to save trees or because you use A4 paper instead of US Letter.

To see all vendor options and their possible values for the queue `Office`, you can use `lpoptions`:

  ```Shell
  $ lpoptions -p Office -l
  PageSize/Media Size: *Letter Legal Executive Tabloid A3 A4 A5 B5 EnvISOB5 Env10 EnvC5 EnvDL EnvMonarch
  InputSlot/Media Source: *Default Upper Manual
  Duplex/2-Sided Printing: *None DuplexNoTumble DuplexTumble
  Option1/Duplexer: *False True
  ```

The asterisk (*) indicates the current value. Use this to adapt your manifest

  ```puppet
  cups_queue { 'Office':
    ...
    options => {
      'Duplex'   => 'DuplexNoTumble',
      'PageSize' => 'A4',
    }
  }
  ```

You only need to provide values for options you actually care about.

**Access control:**
Of course you want your boss Mr. Lumbergh, the secretary Nina and every member of the workers' council
to be able to print to the office printer from every node. But all others should be denied to use this printer.

Assuming they respectively have the user accounts `lumbergh`, `nina`, and the user group `council`, this can be achieved by:

  ```puppet
  cups_queue { 'Office':
    ...
    access => {
      'policy' => 'allow',
      'users'  => ['lumbergh', 'nina', '@council'],
    }
  }
  ```

Note that group names must be prefixed with an `@` sign.

Changing the policy to `deny` would deny all `users`, but allow everybody else. Furthermore, you can unset all restrictions by using

  ```puppet
  cups_queue { 'Office':
    ...
    access => {
      'policy' => 'allow',
      'users'  => ['all'],
    }
  }
  ```

because `all` is interpreted by CUPS as a wildcard, not as an account name.

### Configuring CUPS

Now that you have created manifest for all your queues, you may want to set the default destination.

  ```puppet
  class { '::cups'
    default_queue => 'Office',
  }
  ```

This will require the resource `Cups_queue['Office']` to be defined in the catalog.

To find out about all options available for `Class['::cups']` see the [section below](#class-cups).

### Using Hiera

You can also create `cups_queue` resources using Hiera.
Make sure your setup includes the `::cups` class on the relevant nodes and replace a manifest like

  ```puppet
  class { '::cups':
    default_queue => 'GroundFloor',
  }

  cups_queue { 'Office':
    ensure => 'printer',
    uri    => 'lpd://192.168.2.105/binary_p1',
  }

  cups_queue { 'GroundFloor':
    ensure  => 'class',
    members => ['Office', 'Warehouse'],
  }
  ```

with the Hiera data

  ```YAML
  ---
  cups::default_queue: 'GroundFloor'
  cups::hiera: priority
  cups_queue:
    'Office':
      ensure: 'printer'
      uri: 'lpd://192.168.2.105/binary_p1'
    'GroundFloor':
      ensure: 'class'
      members: ['Office', 'Warehouse']
  ```

## Reference

### Classes

* [`cups`](#class-cups)

### Defines

* [`cups::ctl`](#define-cupsctl)

### Types

* [`cups_queue`](#type-cups_queue)

### Facts

* `cups_classes`: An array of the names of all installed classes.

* `cups_classmembers`: A hash with the names of all classes (as keys) and their members (as array value).

* `cups_printers`: An array of the names of all installed print queues (*excluding* classes).

* `cups_queues`: An array of the names of all installed print queues (*including* classes).

#### Class: `cups`

Installs, configures, and manages the CUPS service.

##### Attributes (all optional)

* `confdir`: The fully qualified directory (without trailing slash) for the CUPS configuration files. Defaults to `/etc/cups`.

* `default_queue`: The name of the default destination for all print jobs. Requires the catalog to contain a `cups_queue` resource with the same name.

* `hiera`: When set to `priority` or `merge`, Puppet will look up the Hiera key `cups_queue` to manage `cups_queue` resources. See also the [example](#using-hiera) above. Disabled by default.

* `packages`: An array with the names of all packages needed to install for CUPS and `ipptool`. Use `[]` to disable automatic package management. OS dependent defaults apply.

* `services`: An array with the names of all CUPS services to be managed. Use `[]` to disable automatic service management. OS dependent defaults apply.

* `webinterface`: Boolean value to enable or disable the CUPS web interface at [`http://localhost:631`](http://localhost:631).

#### Define: `cups::ctl`

A convenience wrapper for the `cupsctl` command used to configure the CUPS daemon.

##### Attributes

* `title`: *mandatory* - The name of the parameter to be managed.

* `ensure`: *mandatory* - The value to be ensured.

#### Type: `cups_queue`

Installs and manages CUPS print queues.

##### Attributes

* `name`: *mandatory* - CUPS queue names are case insensitive and may contain any printable character except SPACE, TAB, "/", or "#".

* `ensure`: *mandatory* - Specifies whether this queue should be a `class`, a `printer` or `absent`.

* `access`:  Manages queue access control. Takes a hash with keys `policy` and `users`.
The `allow` policy restricts access to the `users` provided, while the `deny` policy lets everybody except the specified `users` submit jobs.
The `users` are provided as a non-empty array of Unix group names (prefixed with an `@`) and Unix user names.

* `accepting`: Boolean value specifying whether the queue should accept print jobs or reject them.

* `description`: A short informative description of the queue.

* `enabled`: Boolean value specifying whether the queue should be running or stopped.

* `held`: A held queue will print all jobs in print or pending, but all new jobs will be held. Setting `false` will release them.

* `location`: A short information where to find the hardcopies.

* `options`: A hash of options (as keys) and their target value. Use `lpoptions -p [queue_name] -l` on the node for a list of all options available for the queue and their supported values.

* `shared`: Boolean value specifying whether to share this queue on the network. Default is `false`.

##### Class-only attributes

* `members`: *mandatory* - A non-empty array with the names of CUPS queues. The class will be synced to contain only these members in the given order. If the catalog contains `cups_queue` resources for these queues, they will be required automatically.

##### Printers-only attributes

* `interface`: The absolute path to a System V interface script on the node.
If the catalog contains a `file` resource with this path as title, it will automatically be required.

* `make_and_model`: This value is used for [driver updates and changes](#changing-the-driver).
Matches the `NickName` (fallback `ModelName`) value from the printer's PPD file
if the printer was installed using a PPD file or a model,
and `Local System V Printer` or `Local Raw Printer` otherwise.

* `model`: A supported printer model. Use `lpinfo -m` on the node to list all models available.

* `ppd`: The absolute path to a PPD file on the node.
If the catalog contains a `file` resource with this path as title, it will automatically be required.
The recommended location for your PPD files is `/usr/share/cups/model/` or `/usr/local/share/cups/model/`.

* `uri`: The device URI of the printer. Use `lpinfo -v` on the node to scan for printer URIs.

## Limitations

### Option defaults

Sometimes it may be necessary to modify the default values for some queue options to ensure an intuitive user experience,
e.g. to enable the use of an optional duplex unit.
For historic reasons there are two ways to set default values for all users:

* Daemon defaults are set using `sudo lpadmin` and will affect all jobs from both local and remote hosts.
The CUPS daemon saves them frequently - but not immediately - to `/etc/cups/classes.conf`, `/etc/cups/printers.conf`, and the PPD files in `/etc/cups/ppd/`.

* Local defaults are set using `sudo lpoptions` and will only affect jobs from the local host, *overriding* the daemon defaults for these jobs.
The values are saved to the file `/etc/cups/lpoptions`.

Hence there is no robust way to determine the current daemon defaults when used in conjunction with local defaults.
If local defaults aren't used, the command `lpoptions -p [queue_name] -l` will return the daemon defaults.

In order to provide a stable and idempotent way for Puppet to set default option values for all jobs sent to a queue,
this module will *disable* the use of local defaults by deleting the file `/etc/cups/lpoptions`.

## Contributing

There are several ways to contribute for both users and developers:

* This module is striving for the ["Puppet approved"](https://forge.puppetlabs.com/approved) badge.
If you like this module, please show your appreciation by giving it a
[positive rating](https://forge.puppetlabs.com/leoarnold/cups) in the PuppetForge
and spreading the news in your favorite way.

* Want to suggesting a new feature, point out a flaw in the documentation or report a bug?
Please open a [GitHub issue](https://github.com/leoarnold/puppet-cups/issues)
using the suggested skeleton from the [contribution guidelines](CONTRIBUTING.md).

* Developers might want to submit a [GitHub pull request](https://github.com/leoarnold/puppet-cups/pulls).
It is highly recommended to open an **issue first** and discuss changes with the maintainer.
See the [contribution guidelines](CONTRIBUTING.md) for our quality standards and legal requirements.

_Thank you for your interest in the CUPS module._
