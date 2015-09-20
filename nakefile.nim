import nake
import lib/config

const
  compile = "nim c -d:release -threads:on"
  linux_x86 = "--cpu:i386 --os:linux"
  linux_arm = "--cpu:arm --os:linux"
  windows_x86 = "--cpu:i386 --os:windows"
  windows_x64 = "--cpu:amd64 --os:windows"
  macosx_x64 = ""
  #parallel = "--parallelBuild:1 --verbosity:3"
  ls = "litestore"
  ls_file = "litestore.nim"
  zip = "zip -X"

proc filename_for(os: string, arch: string): string =
  return "litestore" & "_v" & version & "_" & os & "_" & arch & ".zip"

task "windows-x86-build", "Build LiteStore for Windows (x86)":
  direshell compile, windows_x86, ls_file

task "windows-x64-build", "Build LiteStore for Windows (x64)":
  direshell compile, windows_x64, ls_file

task "linux-x86-build", "Build LiteStore for Linux (x86)":
  direshell compile, linux_x86,  ls_file
  
task "linux-arm-build", "Build LiteStore for Linux (ARM)":
  direshell compile, linux_arm,  ls_file
  
task "macosx-x64-build", "Build LiteStore for Mac OS X (x64)":
  direshell compile, macosx_x64, ls_file

task "release", "Release LiteStore":
  echo "\n\n\n WINDOWS - x86:\n\n"
  runTask "windows-x86-build"
  direshell zip, filename_for("windows", "x86"), ls & ".exe"
  direshell "rm", ls & ".exe"
  echo "\n\n\n WINDOWS - x64:\n\n"
  runTask "windows-x64-build"
  direshell zip, filename_for("windows", "x64"), ls & ".exe"
  direshell "rm", ls & ".exe"
  echo "\n\n\n LINUX - x86:\n\n"
  runTask "linux-x86-build"
  direshell zip, filename_for("linux", "x86"), ls 
  direshell "rm", ls 
  echo "\n\n\n LINUX - ARM:\n\n"
  runTask "linux-arm-build"
  direshell zip, filename_for("linux", "arm"), ls 
  direshell "rm", ls 
  echo "\n\n\n MAC OS X - x64:\n\n"
  runTask "macosx-x64-build"
  direshell zip, filename_for("macosx", "x64"), ls 
  direshell "rm", ls 
  echo "\n\n\n ALL DONE!"