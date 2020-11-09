# Package

version       = "0.1.0"
author        = "Ed Burke (tinygiant)"
description   = "An NWN tool to update blueprint instances in area information (.git) files"
license       = "MIT"
srcDir        = "src"
bin           = @["instify"]



# Dependencies

requires "nim >= 1.2.0"
requires "neverwinter >= 1.3.1"
requires "docopt >= 0.6.8"
