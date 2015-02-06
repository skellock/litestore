import
  parseopt2,
  strutils,
  logging
import
  types


const 
  version* = "1.0"
  usage* = "  LiteStore v"& version & " - Lightweight REST Document Store" & """
  (c) 2015 Fabio Cevasco

  Usage:
    LS [-p:<port> -a:<address>] [<file>] [--pack:<directory> | --unpack:<directory>] 

  Options:
    -a, --address     Specify address (default: 0.0.0.0).
    --export          Export the previously-packed specified directory to the current directory.
    -h, --help        Display this message.
    --import          Import the specified directory (Store all its contents).
    -l, --log         Specify the log level: debug, info, warn, error, fatal, none (default: info)
    -p, --port        Specify port number (default: 9500).
    --purge           Delete exported files (used in conjunction with --export).
    -r, --readonly    Allow only data retrieval operations.
    -v, --version     Display the program version.
"""

var 
  file = "data.ls"
  port = 9500
  address = "0.0.0.0"
  operation = opRun
  directory = ""
  readonly = false
  purge = false
  logLevel = lvlInfo
  

for kind, key, val in getOpt():
  case kind:
    of cmdLongOption, cmdShortOption:
      case key:
        of "address", "a":
          address = val
        of "port", "p":
          port = val.parseInt
        of "log", "l":
          logLevel = logging.LevelNames.find(val.toUpper).Level
        of "import":
          operation = opImport
          directory = val
        of "export":
          operation = opExport
          directory = val
        of "purge":
          purge = true
        of "version", "v":
          echo version
          quit(0)
        of "help", "h":
          echo usage
          quit(0)
        of "readonly", "r":
          readonly = true
        else:
          discard
    of cmdArgument:
      file = key
    else:
      discard

var LS*: LiteStore

LS.port = port
LS.address = address
LS.operation = operation
LS.file = file
LS.purge = purge
LS.directory = directory
LS.appversion = version
LS.readonly = readonly
LS.appname = "LiteStore"

# Initialize loggers

logging.handlers.add(newConsoleLogger(logLevel, "$date $time - "))
logging.handlers.add(newRollingFileLogger("litestore.log.txt", fmReadWrite, logLevel, "$date $time - ", 100000))
