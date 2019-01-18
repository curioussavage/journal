import parseopt
import os
import osproc
import parsecfg
import strformat
import posix
import times
import strutils
import db_sqlite
import options
import tables

import json

const
  divider = "----------------------------------------------------------"
  app_config_dir = "com.github.curioussavage.journal"
  config_name = "config.ini"

let time_format = times.initTimeFormat("yyyy-MM-dd")
let config_dir = os.getConfigDir()
let home_dir = os.getHomeDir()

var config: Config = nil
var theDb: DbConn

type
  Entry* = ref object
    date: DateTime
    content: string
    id: Option[int]

  Journal =
    seq[Entry]

proc to_json(entry: Entry): JsonNode =
  return %*{ "date": $entry.date, "content": entry.content }

proc initialize_config(): void =
  let config_path = os.joinPath(config_dir, app_config_dir)
  let config_file_path = os.joinPath(config_path, config_name)
  if not os.existsDir(config_path):
    os.createDir(config_path)

  if not existsFile(config_file_path):
    var dict = newConfig()
    # add default values
    dict.setSectionKey("", "journal_dir", os.joinPath(home_dir, "journal.db"))
    dict.setSectionKey("", "editor", "nano")
    dict.writeConfig(config_file_path)
    config = dict
    return

  config = parsecfg.loadConfig(config_file_path)


proc get_template(): string =
  let path = config_dir / app_config_dir / "template" 
  if not os.existsFile(path):
    return ""

  let file = readFile(path)
  echo file
  return file


proc loadJournal() =
  let location = config.getSectionValue("", "journal_dir")
  if existsFile(location):
    theDb = db_sqlite.open(location, "", "", "")
  else:
    theDb = db_sqlite.open(location, "", "", "")
    theDb.exec(sql("""create table entries (
        Id      INTEGER PRIMARY KEY,
        date    INT,
        content TEXT )"""))


proc writeHelp(): void =
  echo """Journal v1.1.0

Description:
  journal is a command line journal program. It keeps your journal entries
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
  """
  quit()


proc writeVersion(): void =
  echo  "Journal v1.0.0"
  quit()


proc saveJournal(db: DbConn, entry: Entry): void =
  discard db.insertId(
    sql("INSERT INTO entries (date, content) VALUES (?, ?)"),
    entry.date.toTime.toUnix, entry.content
  )


proc updateJournal(db: DbConn, entry: Entry): void =
  discard db.insertId(
    sql("UPDATE entries SET content = ? WHERE id = ?"),
    entry.content,
    entry.id.get
  )


proc get_todays_entry(db: DbConn): Option[Entry] =
  var n = now()
  var now_date = initDateTime(n.monthday, n.month, n.year, 0, 0, 0)
  var row = db.getRow(
    sql("""SELECT * FROM entries WHERE date > ?"""),
    now_date.toTime.toUnix,
  )
  if row[0] != "":
    var x = row[1].parseInt.fromUnix.local
    return some(Entry(date: x, content: row[2], id: some(row[0].parseInt)))


proc get_input(content = ""): string =
  let tmpPath = getTempDir() / "userEditString"
  let tmpFile = tmpPath / $getpid()
  try:
    createDir tmpPath
  except:
    echo "could not create tempfile"

  try:
    writeFile tmpFile, content
  except:
    echo "couild not write to tempfile"

  try:
    let err = execCmd(config.getSectionValue("", "editor") & " " & tmpFile)
  except:
    echo "editor could not open/edit file"
  return tmpFile.readFile


proc edit_template() =
  let path = config_dir / app_config_dir / "template" 
  var templ = ""
  if os.existsFile(path):
    templ = readFile(path)
  
  templ = get_input(content=templ)
  try:
    writeFile(path, templ)
  except:
    echo "Could not save template"
  

proc list_db_entry(row: Row) =
  echo row[1].parseInt.fromUnix.local.format(time_format)
  echo "\n"
  echo row[2]
  echo divider


proc list_entries() =
  for row in theDb.rows(sql"SELECT * from entries ORDER BY date ASC"):
    list_db_entry(row)


proc list_entries(days: int) = 
  var now = now()
  now = now - days(days)
  for row in theDb.rows(
    sql"""SELECT * FROM entries WHERE date > ?""",
    now.toTime.toUnix
  ):
    list_db_entry(row)


proc edit_entry(date: string) =
  var day_end: DateTime
  try:
    var parsed_date = date.parse(time_format)
    var day_end = initDateTime(
      parsed_date.monthday,
      parsed_date.month,
      parsed_date.year,
      23, 59, 59
    )

    var row = theDb.getRow(
      sql("""SELECT * FROM entries WHERE date > ? AND date < ?"""),
      parsed_date.toTime.toUnix, day_end.toTime.toUnix
    )
    if row[0] != "":
      var input = get_input(content=row[2])
      theDb.updateJournal(Entry(
        id: some(row[0].parseInt),
        date: row[1].parseInt.fromUnix.local,
        content: input
      ))
    else:
      let message = &"no entry for {parsed_date.format(time_format)}. Modify this file to create one"
      var input = get_input(content=message)
      if input == message:
        return
      else:
        theDb.saveJournal(Entry(
          date: parsed_date + 12.hours,
          content: input
        ))
  except:
    echo "could not parse time format"
    raise


proc export_journal() =
  var res = newJArray()
  for row in theDb.fastRows(sql("Select * from entries")):
    res.add(Entry(date: row[1].parseInt.fromUnix.local, content: row[2]).to_json)
  echo res


# begin program
initialize_config()
loadJournal()
let command_args = commandLineParams()
if command_args.len > 0:
  var command: string
  var args: TableRef[string, string] = newTable[string, string]()
  for kind, key, val in getopt(command_args):
    case kind
    of cmdArgument:
      command = key
    of cmdLongOption, cmdShortOption:
      case key
      of "help", "h": writeHelp()
      of "version", "v": writeVersion()
      of "template", "t": edit_template()
      of "days":
        args["days"] = val
      of "date":
        args["date"] = val
    of cmdEnd:
      assert(false) # cannot happen

  case command
  of "list", "ls":
    if args.hasKey "days":
      list_entries(days=args["days"].parseInt)
    else:
      list_entries()
  of "edit", "e": edit_entry(date=args["date"])
  of "export", "exp": export_journal()
  of "template", "t": edit_template()
else:
  var maybe_today_entry = theDb.get_todays_entry
  if maybe_today_entry.isSome:
     # we have an entry for today already 
    var input = get_input(content=maybe_today_entry.get().content)
    var entry = maybe_today_entry.get
    entry.content = input
    theDb.updateJournal(entry)
  else:
    var templ = get_template()
    var input = get_input(content=templ)
    if input != templ:
      var now_date = now()
      var newEntry = Entry(date: now_date, content: input)
      theDb.saveJournal(newEntry)
