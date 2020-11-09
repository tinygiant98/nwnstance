import json, shared, strutils, strformat, base64

let args = DOC """
Update instances of blueprints in a packed or unpacked nwn module

Note: this tool does not work on files that have been converted to json via
  tools such as neverwinter.nim.  Unpacked modules must be in gff formats.

Usage:
  $0 [options]
  $0 (--dirs <dir> | --erfs <erf>) [-s <file>...] [--filtetypes <types>...] [options]
  $USAGE

Options:
  --all                       Match all files.
  -b, --binary BINARY         Match only files where the data contains BINARY.
  --filetypes TYPES           Comma delimited list of gff file extensions to search
                              for the instance to update [default: git]
  -f, --file FILES            Comma delimited list of blueprint files
  -s, --source SOURCES        Blueprints as sources to update instances
  -d, --details               Show more details.
  --skip SKIPS                Fields to skip modification of [Default: ]
  --merge MERGES              Fields to merge [Default: ]
  --drop DROPS                Fields to drop from the instances [Default: ]
  --md5                       Generate md5 checksums of files.
  --sha1                      Generate sha1 checksums of files.

  --erfs ERFS                 Load comma-separated erf files [default: ]
  --dirs DIRS                 Load comma-separated directories [default: """ & getCurrentDir() & """]
  $OPT
"""

const
  OptionalFields = @["VarTable"]

proc dump(s: GffStruct, indent = 0): string =
  for k, v in pairs(s.fields):
    case v.fieldKind:
    of GffFieldKind.Byte: echo repeat(' ', indent * 2) & k & ":" & $v.getValue(GffByte).int
    of GffFieldKind.Char: echo repeat(' ', indent * 2) & k & ":" & $v.getValue(GffChar).int
    of GffFieldKind.Word: echo repeat(' ', indent * 2) & k & ":" & $v.getValue(GffWord).int
    of GffFieldKind.Short: echo repeat(' ', indent * 2) & k & ":" & $v.getValue(GffShort).int
    of GffFieldKind.Dword: echo repeat(' ', indent * 2) & k & ":" & $v.getValue(GffDword).int
    of GffFieldKind.Int: echo repeat(' ', indent * 2) & k & ":" & $v.getValue(GffInt).int
    of GffFieldKind.Float: echo repeat(' ', indent * 2) & k & ":" & $v.getValue(GffFloat).float
    of GffFieldKind.Dword64: echo repeat(' ', indent * 2) & k & ":" & $v.getValue(GffDword64).int64
    of GffFieldKind.Int64: echo repeat(' ', indent * 2) & k & ":" & $v.getValue(GffInt64).int64
    of GffFieldKind.Double: echo repeat(' ', indent * 2) & k & ":" & $v.getValue(GffDouble).float64
    of GffFieldKind.CExoString: echo repeat(' ', indent * 2) & k & ":" & $v.getValue(GffCExoString)
    of GffFieldKind.CExoLocString:
      let entries = newJObject()
      for kk, vv in pairs(v.getValue(GffCExoLocString).entries):
        entries[$kk] = %vv

      echo repeat(' ', indent * 2) & fmt"{k}:{entries}"
    of GffFieldKind.ResRef: echo repeat(' ', indent * 2) & k & ":" & $v.getValue(GffResRef).string
    of GffFieldKind.Void: echo repeat(' ', indent * 2) & k & ":" & $v.getValue(GffVoid).string.encode()
    of GffFieldKind.Struct:
      let s = v.getValue(GffStruct)
      echo repeat(' ', indent * 2) & k & ":" & dump(s, indent + 1)
      #echo fmt"--------struct {k}"
    of GffFieldKind.List:
      echo repeat(' ', indent * 2) & k & ":--"
      for elem in v.getValue(GffList):
        discard dump(elem, indent + 1)
        echo repeat(' ', indent * 2) & repeat("-", k.len) & "---"

proc updateSimple[T: GffFieldType](instance, blueprint: GffSTruct, k: string, t: typedesc[T], indent = 0): T =
  if blueprint.hasField(k, t):
    let
      oldvalue = $instance[k, t]
      newvalue = $blueprint[k, t]

    if oldvalue != newvalue:
      result = blueprint[k, t]
      #instance[k, t] = blueprint[k, t]
      debug repeat(' ', indent * 2) & fmt"field {k} updated from {oldvalue} to {newvalue}"
    else:
      debug repeat(' ', indent * 2) & fmt"field {k} did not require updating"    

proc update(instance: var GffStruct, blueprint: GffStruct, indent = 0) =
  for k, v in pairs(instance.fields):
    if k.tolower in mapIt(split($args["--skip"], ","), it.toLower):
      echo "field " & k & " skipped on user request"
      continue

    if k.tolower in mapIt(split($args["--drop"], ","), it.toLower):
      if k in OptionalFields:
        #need delayed delete function
        echo "field " & k & " dropped on user request"
        continue

    case v.fieldKind:
    of GffFieldKind.Byte: instance[k, GffByte] = instance.updateSimple(blueprint, k, GffByte, indent + 1)
    of GffFieldKind.Char: instance[k, GffChar] = instance.updateSimple(blueprint, k, GffChar, indent + 1)
    of GffFieldKind.Word: instance[k, GffWord] = instance.updateSimple(blueprint, k, GffWord, indent + 1)
    of GffFieldKind.Short: instance[k, GffShort] = instance.updateSimple(blueprint, k, GffShort, indent + 1)
    of GffFieldKind.Dword: instance[k, GffDword] = instance.updateSimple(blueprint, k, GffDword, indent + 1)
    of GffFieldKind.Int: instance[k, GffInt] = instance.updateSimple(blueprint, k, GffInt, indent + 1)
    of GffFieldKind.Float: instance[k, GffFloat] = instance.updateSimple(blueprint, k, GffFloat, indent + 1)
    of GffFieldKind.Dword64: instance[k, GffDword64] = instance.updateSimple(blueprint, k, GffDword64, indent + 1)
    of GffFieldKind.Int64: instance[k, GffInt64] = instance.updateSimple(blueprint, k, GffInt64, indent + 1)
    of GffFieldKind.Double: instance[k, GffDouble] = instance.updateSimple(blueprint, k, GffDouble, indent + 1)
    of GffFieldKind.CExoString: instance[k, GffCExoString] = instance.updateSimple(blueprint, k, GffCExoString, indent + 1)
    of GffFieldKind.ResRef: 
      let
        oldvalue = $instance[k, GffResRef]
        newvalue = $blueprint[k, GffResRef]

      if oldvalue != newvalue:
        instance[k, GffResRef] = blueprint[k, GffResRef]
        debug fmt"field {k} update from {oldvalue} to {newvalue}"


    of GffFieldKind.CExoLocString:
      #instance[k, GffCExoLocString] = instance.updateSimple(blueprint, k, GffCExoLocString)
      echo "not updating CEXOLOCSTRING"
    of GffFieldKind.Void: 

      echo fmt"{k} VOID VOID VOID"
    of GffFieldKind.Struct: 

      echo fmt"{k} STRUCT STRUCT STRUCT"
    of GffFieldKind.List:
      if k.tolower in mapIt(split($args["--merge"], ","), it.toLower):
        if blueprint[k, GffList].len > 0:
          var list = blueprint[k, GffList]

          for i, struct in instance[k, GffList]:
            # THis isn't good enough.  Probably need to see what this is and recurse
            # also need to make this good for all lists.
            
            if $struct.fields["Name"] notin list.mapIt($(it.fields)["Name"]):
              list.add(struct)
          
          instance[k, GffList] = list
      else:
        if blueprint[k, GffList].len > 0:
          echo "if"
          instance[k, GffList] = blueprint[k, GffList]
        else:
          # need a seq to mark for deletion
          #instance.del(k)
          if k in OptionalFields:
            #mark for deletion
            echo fmt"marking {k} for deletion"

         
    #if report.oldvalue != report.newvalue:
    #  debug fmt"      field {k} updated from {report.oldvalue} to {report.newvalue}"
  #echo "dumping instance"
  #discard dump(instance)

#[
proc findX(s: var GffStruct, target: string, blueprint: GffStruct, indent = 0) =
  # TODO  need a counter to track the instances for debug readout.  This one don't work fix it TODO
  for k, v in s.fields:
    # we're really only interested in lists cuz we're only changing files like gits, which are all lists
    if v.fieldKind == GffFieldKind.List:
      for struct in v.getValue(GffList):
        # need something mutable -- no mutable iterator available for getValue?
        var fixit = struct
        if struct.hasField("TemplateResRef", GffResRef) and $struct["TemplateResRef", GffResRef] == target:
          update(fixit, blueprint, indent)
        else:
          findX(fixit, target, blueprint, indent + 1)
]#
const
  simpleType = ["byte", "char", "cexostring", "word", "short", "dword", "int", "float", "resref"]

proc updateNode(instanceNode: JsonNode, blueprintJson: JsonNode) =
  for k, v in instanceNode:
    if k.tolower in mapIt(split($args["--skip"], ","), it.toLower):
      echo fmt"skipping {k} at user request"
      continue

    if v.kind != JObject: continue

    if instanceNode[k]["type"].getStr() in simpleType:
      if blueprintJson.hasKey(k) and instanceNode[k]["value"] != blueprintJson[k]["value"]:
        instanceNode[k]["value"] = blueprintJson[k]["value"]
        echo fmt"update {k} from instance to blueprint - {blueprintJson[k][""value""]}"
    else:
      case instanceNode[k]["type"].getStr():
      of "cexolocstring":
        if instanceNode[k] != blueprintJson[k]:
          instanceNode[k] = blueprintJson[k]
      of "list":
        if k.tolower in mapIt(split($args["--merge"], ","), it.toLower):
          echo "merge the lists"
            #how the heck to we do that?
        else:
          #check for optional fields in blueprint.  if none, check for same
          # in instance.  Make instance look like blueprint for optional fields

          # just use what's there, but lists can have other lists, soooo.
          instanceNode[k].updateNode(blueprintJson[k])
      else: continue
  
  #echo instanceNode.pretty

proc updateInstance(instanceJson: JsonNode, blueprintJson: JsonNode, target: tuple) =
  for k, v in instanceJson:
    case v.kind:
    of JString: continue
    of JObject:
      if v{"type"}.getStr() == "list":
        v.updateInstance(blueprintJson, target)
      else:
        continue
    of JArray:
      for node in v:
        if node.hasKey(target.key):
          if node[target.key]["value"] == target.value:
            echo "SEND THIS NODE OUT FOR PROCESSING! ======================================="
            node.updateNode(blueprintJson)
          else:
            node.updateInstance(blueprintJson, target)
    else:
      continue

let
  dir = $args["--dirs"]

if not args["--file"]:
  quit("Blueprint file name(s) must be specified with -f or --file.")

#Let's start over using json cuz that shit didn't work
withDir(dir):
  for file in split($args["--file"], ","):
    let
      blueprintStream = openFileStream(file).readGffRoot(false)
      blueprintJson = blueprintStream.toJson()
      field = if getFileExt(file) == "utm": "ResRef" else: "TemplateResRef"

    if not blueprintStream.hasField(field, GffResRef):
      debug fmt"{file} does not have a resref field and may not a valid gff resource; skipping."
      continue

    let
      resRef = $blueprintStream[field, GffResRef]
      rm = newBasicResMan()

    var
      interest: seq[string]
      instanceStream: GffRoot
      instanceJson: JsonNode
      target: tuple[key: string, value: JsonNode]
      input, output: Stream
    
    #debug fmt"Searching {dir} for instances of {field} : {$resRef} (Note: some matches might be Tags)"
    
    target.key = field
    target.value = %($resRef)

    for res in filterByMatch(rm, resRef):
      interest.add($res.resRef)

    for file in interest:
      input = openFileStream(file)
      instanceStream = input.readGffRoot(false)
      input.close 
      instanceJson = instanceStream.toJson()
      instanceJson.updateInstance(blueprintJson, target)
      echo instanceJson

      instanceStream = instanceJson.gffRootFromJson()
      output = openFileStream(file, fmWrite)
      output.write(instanceStream)
   
#[
withDir(dir):
  for file in split($args["--file"], ","):
    let
      #Open blueprint file to find the resref, it's of type GffRoot
      blueprint = openFileStream(file).readGffRoot(false)
      field = if getFileExt(file) == "utm": "ResRef" else: "TemplateResRef"

    #Ensure the resref exists (to weed out unwanted files) and then skip that file if it
    # doesn't.  One bad file shouldn't stop the entire process.
    if not blueprint.hasField(field, GffResRef):
      debug fmt"File {file} does not have a resref field and may not be a valid file; skipping."
      continue

    #get the actual resref
    let 
      resRef = blueprint[field, GffResRef]  #GffField, I think.  It's only used as a string
                                          # from here on out, so doesn't really matter

    #start up a new resman to see which files we need to access for updates.  There is no
    #quicker way to search the target files for instances
      rm = newBasicResMan()

    var
      interest: seq[string] #this will be the list of files that are interesting for the current resref
      instance: GffRoot     #this will be the current file contents

    debug fmt"Searching {dir} for instances of {field} : {resRef} (Note: some matches might be Tags)"
    
    # some modifications were made to the niv's filterbymatch to only return files of interest
    # per command line arguments.
    for res in filterByMatch(rm, $resRef):
      interest.add($res.resRef)

    # loop the target files and update the instances
    for file in interest:
      #open up the file of interest
      instance = openFileStream(file).readGffRoot(false)
      #find the instances that we know are in there.  It's possible that some of the hits were
      #from tags that = resrefs.  So the count from filterbymatch doesn't mean a whole lot.
      # explicit change to gffstuct because it won't work otherwise
      findX(instance.GffStruct, $resRef, blueprint)
      openFileStream(file, fmWrite).write(instance)
      #strm.write(instance)
      #strm.close()
      discard dump(instance.GffStruct)
]#


  #[echo "in the update---------------"
  echo instanceNode.kind
  # this part only has to happen once per input file (.uti etc.)

  #var blueprintKeys = newSeq[string]()
  #for k, v in blueprintJson:
  #  if v.kind == JObject:
  #    blueprintKeys.add k

  #let finalSet = (blueprintJson.keys.toHashSet() + InstanceFields[target.extension].toHashSet()) - BlueprintFields.toHashSet()

  # this part has to happen for every updated node.

  #var instanceKeys = newSeq[string]()
  #for k, v in instanceNode:
  #  if v.kind == JObject:
  #    instanceKeys.add k
  #  else:
  #    echo fmt"FAIL FAIL FAIL {k} is of kind {$v.kind}"

  echo "BLUEPRINT KEYS " & $blueprintJson.keys.toHashSet()
  echo "INSTANCE FIELDS " & $InstanceFields[target.extension].toHashSet()
  echo "BLUEPRINT FIELDS " & $BlueprintFields.toHashSet()
  echo "FINAL SET " & $finalSet

  echo "INSTANCE KEYS " & $instanceNode.keys.toHashSet()
  echo "FINAL FINAL FINAL " & $(instanceNode.keys.toHashSet() - finalSet)
  let final = instanceNode.keys.toHashSet() - finalSet

  if final.len > 0:
    for k, _ in instanceNode:
      if k in final:
        instanceNode.delete(k)]#


        #[
  # if we roll through instanceNode
  for k, v in instanceNode:
    if k.tolower in mapIt(split($args["--skip"], ","), it.toLower):
      echo fmt"skipping {k} at user request"
      continue

    if k in InstanceFields[target.key]:
      # This entry is an instance-only field, so no need to compare it
      continue

    if v.kind != JObject: continue

    if instanceNode[k]["type"].getStr() in simpleType:
      if blueprintJson.hasKey(k) and instanceNode[k]["value"] != blueprintJson[k]["value"]:
        instanceNode[k]["value"] = blueprintJson[k]["value"]
        echo fmt"update {k} from instance to blueprint - {blueprintJson[k][""value""]}"
    else:
      case instanceNode[k]["type"].getStr():
      of "cexolocstring":
        if blueprintJson.hasKey(k) and instanceNode[k] != blueprintJson[k]:
          instanceNode[k] = blueprintJson[k]
      of "list":
        #if k notin <BlueprintFields> and not <mergelist>:
        #  instanceNoke{k} = blueprintJson[k]



        if k.tolower in mapIt(split($args["--merge"], ","), it.toLower):
          echo "merge the lists"
        else:
          instanceNode[k].updateNode(blueprintJson[k], target)
      else: continue      ]#
  
  # handle optional stuff here, see if it already exist
  #[[for key in OptionalFields[target.key]:
    if instanceNode.hasKey(key):
      echo "stuff"
      # this means it should've already been handled]#

  #echo instanceNode.pretty
