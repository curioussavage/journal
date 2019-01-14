# Journal

journal is a simple command line journal program. If you look under the hood
it is just a wrapper around a single table in a sqlite database.

## Motivation

I don't have the best memory in the world and at work it is important to be able
to remember what you have accomplished. I was using a nice little tool [jrnl](https://github.com/maebert/jrnl)
however I wasn't really a fan of its idea of multiple journal entries per day. I
just wanted one entry per day that I could easily edit.

## Installation

You can find the latest release [here](https://github.com/curioussavage/journal/releases).

Only linux is supported right now since that is the OS I use and test on.

journal is written in [Nim](https://nim-lang.org/). The program has no dependencies
outside of the standard library so all you need is the compiler to build from source.

## Usage
 
The following guide can be seen by running `journal -h`

```
Worklog v1.1.0

Description:
  Worklog is a command line journal program. It keeps your journal entries
  in a sqlite database file. An external editor is used to edit the entries.

Usage:
  Run the command without any arguments to create or edit todays entry.

Commands:
  --help, -h    display this help

  --version, -v display the version

  edit, e       edit an existing entry or create an entry for a past date
    
                args:
                  --date   a date in the format yyyy-MM-dd

  list, ls      used to list journal entries

                args:
                  --days   an integer specifying the number of days to list

  export, exp   export journal to JSON

  template t    edit the template used for new entries

```
