# NWNstance

A nim tool designed to update instances of various NWN resources within area information (.git) files.

## Arguments
|||
|---|---|
|--erfs|module to perform operation on (currently unsupported)|
|--dirs|directory to perform operation on; assumes current if not provided|
|-f, --file|CSV of blueprint files to update|
|--skip|CSV of fields to skip when updating an instance|
|--merge|CSV of fields to merge when updating an instance|

example call (case ignored for command line arguments):
```
nwnstance --dirs:"~/Neverwinter Nights/modules/<module>" -f myawesomeitem.uti,myotheritem.uti --merge vartable --skip cost,tag
```