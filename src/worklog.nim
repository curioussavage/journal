import parseopt
import os
import osproc
import parsecfg
import asynctools
import asyncdispatch
import posix
import times
import strutils

import streams

let time_format = times.initTimeFormat("yyyy-MM-dd")
let divider = "----------------------------------------------------------"
let config_dir = os.getConfigDir()
let home_dir = os.getHomeDir()
const app_config_dir = "worklog"
const config_name = "config.ini"

var config: Config = nil

type
  Entry* = ref object
    date: DateTime
    content: string

  Journal =
    seq[Entry]

proc initialize_config(): void =
  let config_path = os.joinPath(config_dir, app_config_dir)
  let config_file_path = os.joinPath(config_path, config_name)
  if not os.existsDir(config_path):
    os.createDir(config_path)

  if not existsFile(config_file_path):
    echo "config does not exist"
    var dict = newConfig()
    dict.setSectionKey("", "journal_dir", os.joinPath(home_dir, "journal.txt"))
    dict.writeConfig(config_file_path)
    config = dict
    echo "created config"
    return

  echo "loading config"
  config = parsecfg.loadConfig(config_file_path)

proc writeHelp(): void =
  echo "foo"
  quit()


proc writeVersion(): void =
  echo  "v1.0"
  quit()


proc saveJournal(journal: File, entry: Entry): void =
  var string_entry = ""
  string_entry.add(entry.date.format(time_format) & "\n\n")
  string_entry.add(entry.content)
  string_entry.add(divider)
  write(journal, string_entry)


proc loadJournal(): File = 
  let location = config.getSectionValue("", "journal_dir")
  echo "file location is " & location
  if not fileExists(location):
    echo "creating journal file"
    writeFile location, ""
  # load file
  let file = open(location, FileMode.fmReadWrite, bufSize=1024)
  echo "file size is " & $getFileSize(file)
  echo "reading file"
  for line in lines file:
    echo "one line"
    echo file.readLine()
  return file


proc parse_journal(journal: File): Journal =
  var
    date: string = ""
    content: string = ""
    res: Journal = @[]

  for line in lines journal:
    echo line
    if line.strip() == divider:
      # add the entry to the result
      try: 
        echo "adding entry"
        res.add Entry(
          date: date.parse(time_format),
          content: content
        )
        date = ""
        content = ""
      except:
        echo "crap"
    if date == "":
      date = line.string
    else:
      content.add line.string

  return res


proc get_input(content = "", editor = "vim"): string =
  let tmpPath = getTempDir() / "userEditString"
  let tmpFile = tmpPath / $getpid()
  createDir tmpPath
  writeFile tmpFile, content
  let err = execCmd(editor & " " & tmpFile)
  return tmpFile.readFile

proc is_same_day(time1, time2: DateTime): bool =
  time1.format(time_format) == time2.format(time_format)

# begin program
initialize_config()
let command_args = commandLineParams()
if command_args.len > 0:
  for kind, key, val in getopt(command_args):
    case kind
    of cmdArgument:
      echo "key", key, "value", val
      # not sure what would go here.
    of cmdLongOption, cmdShortOption:
      case key
      of "help", "h": writeHelp()
      of "version", "v": writeVersion()
    of cmdEnd:
      assert(false) # cannot happen
  # maybe run command here passing args
else:
  echo "loading journal"
  var journal = loadJournal()
  echo "journal loaded"
  var parsed_journal = parse_journal(journal)
  var last_entry: Entry
  let now_date = times.now()
  if parsed_journal.len > 0:
    echo "journal entry for today already created"
    last_entry = parsed_journal[parsed_journal.high]
  if last_entry != nil and is_same_day(now_date, last_entry.date):
     # we have an entry for today already 
    var input = get_input(content=last_entry.content)
    echo input
    # broke and needs to be thought out again.
    # saveJournal(journal, )
  else:
    var input = get_input()
    var newEntry = Entry(date: now_date, content: input)
    saveJournal(journal, newEntry)
