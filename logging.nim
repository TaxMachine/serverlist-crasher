import strutils
import os
import times
import strformat

let prefix* = '\e'
let RESET* = $prefix & "[0m"
let UNDERLINE* = $prefix & "[4m"

type
    Logger* = object
        log_file*: File
        log_dir*: string
    LogLevel* = enum
        Info = "INFO"
        Warning = "WARNING"
        Error = "ERROR"
    GROUND* = enum
        BACK = "48"
        FORE = "38"
    COLORMODE* = enum
        INT = "5"
        RGB = "2"

proc getTime(): string =
    return now().format("HH:mm:ss")

proc rgb*(r: int, g: int, b: int, ground: GROUND = FORE, mode: COLORMODE = RGB): string =
    return fmt"{$prefix}[{ground};{mode};{$r};{$g};{$b}m"


proc log*(level: LogLevel, message: string) =
    let color = case level:
        of Info:
            rgb(0, 96, 250)
        of Warning:
            rgb(250, 233, 0)
        of Error:
            rgb(250, 0, 0)
    echo("[" & getTime() & "] [" & color & $level & RESET & "] " & message)