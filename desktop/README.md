# Desktop Setup

This folder codifies the base configuration of a Linux development desktop. It reduces the friction associated with setting up a development desktop.

The script *setup.yml* loads tasks on a per-operating system basis, by loading a file named {{ansible_os_family}}.yml an [ansible fact](https://docs.ansible.com/ansible/latest/user_guide/playbooks_vars_facts.html).  As an example, all Arch Linux derivatives load Archlinux.yml.  To add support for your operating system, add a family-specific file.

## Requirements

This directory includes an *ansible* script, for provisioning a workstation. Either install ansible via python (*pip install ansible* or using your package manager, if supported (i.e *pacman -S ansible*).

## Running

To install dependencies, run the following command from this folder, as a **non-root** user. When asked for a password, enter the password used to sudo.

ansible-playbook -c local -i localhost, -K setup.yml