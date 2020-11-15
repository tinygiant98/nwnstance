import shared, debugprinter

let args = DOC """
Update instances of blueprints in a packed or unpacked nwn module

Note: this tool does not work on files that have been converted to json via
  tools such as neverwinter.nim.  Unpacked modules must be in gff formats.

Usage:
  $0 [options]
  $USAGE

Options:
  --filetypes TYPES           Comma delimited list of gff file extensions to search
                              for the instance to update [default: git]
  -f, --file FILES            Comma delimited list of blueprint files
  --skip SKIPS                Fields to skip modification of [Default: ]
  --set SETS                  Set Fields to specific values [Default: ]
  --merge MERGES              Fields to merge [Default: ]
  --erfs ERFS                 Load comma-separated erf files [default: ]
  --dirs DIRS                 Load comma-separated directories [default: ]
  $OPT
"""
const
  # Identifier list to simplify updating
  simpleType = @["byte", "char", "cexostring", "word", "short", "dword", "int", "float", "resref", "cexolocstring"]
  
  # Fields only found in blueprints
  BlueprintFields = @["Comment", "PaletteID"]
  
  # Not currently used, but good to have for future expansion
  CommonFields = {"utc": @["Appearance_Type", "BodyBag", "Cha", "ChallengeRating", "ClassList", "Con", "Conversation", "CRAdjust",
                          "CurrentHitPoints", "DecayTime", "Deity", "Description", "Dex", "Disarmable", "Equip_ItemList", "FactionID",
                          "FeatList", "FirstName", "fortbonus", "Gender", "GoodEvil", "HitPoints", "Int", "Interruptable",
                          "IsImmortal", "IsPC", "ItemList", "LastName", "LawfulChaotic", "Lootable", "MaxHitPoints", "NaturalAC",
                          "NoPermDeath", "PerceptionRange", "Phenotype", "Plot", "PortraitID", "Race", "refbonus", "ScriptAttacked",
                          "ScriptDamaged", "ScriptDeath", "ScriptDialogue", "ScriptDisturbed", "ScriptEndRound", "ScriptHeartbeat",
                          "ScriptOnBlocked", "ScriptOnNotice", "ScriptRested", "ScriptSpawn", "ScriptSpellAt", "ScriptUserDefine",
                          "SkillList", "SoundSetFile", "SpecAbilityList", "StartingPackage", "Str", "Subrace", "Tag", "Tail", "WalkRate",
                          "willbonus", "Wings", "VarTable"],
                  "utd": @["AnimationState", "Appearance", "AutoRemoveKey", "CloseLockDC", "Conversation", "CurrentHP",
                          "Description", "DisarmDC", "Faction", "Fort", "Hardness", "HP", "Interruptable", "Lockable",
                          "Locked", "LocName", "OnClosed", "OnDamaged", "OnDeath", "OnDisarm", "OnHeartbeat", "OnLock",
                          "OnMeleeAttacked", "OnOpen", "OnSpellCastAt", "OnTrapTriggered", "OnUnlock", "OnUserDefined",
                          "OpenLockDC", "Plot", "PortraitID", "Ref", "Tag", "TemplateResRef", "TrapDetectable", "TrapDetectDC",
                          "TrapDisarmable", "TrapFlag", "TrapOneShot", "TrapType", "Will", "VarTable",
                          "GenericType", "LinkedTo", "LinkedToFlags", "LoadScreenID", "OnClick", "OnFailToOpen"],
                  "ute": @["Active", "CreatureList", "Difficulty", "DifficultyIndex", "Faction", "LocalizedName",
                          "MaxCreatures", "OnEntered", "OnExhausted", "OnExit", "OnHeartbeat", "OnUserDefined", "PlayerOnly",
                          "RecCreatures", "Reset", "ResetTime", "Respawns", "SpawnOption", "Tag", "TemplateResref", "VarTable"],
                  "uti": @["AddCost", "BaseItem", "Charges", "Cost", "Cursed", "DescIdentified", "Description", "LocalizedName",
                          "Plot", "PropertiesList", "StackSize", "Stolen", "Tag", "TemplateResRef",
                          "Cloth1Color", "Cloth2Color", "Leather1Color", "Leather2Color", "Metal1Color", "Metal2Color",
                          "ModelPart1", "ModelPart2", "ModelPart3", "ArmorPart_Belt", "ArmorPart_LBicep", "ArmorPart_LFArm",
                          "ArmorPart_LFoot", "ArmorPart_LHand", "ArmorPart_LShin", "ArmorPart_LShoul", "ArmorPart_LThigh",
                          "ArmorPart_Neck", "ArmorPart_Pelvis", "ArmorPart_RBicep", "ArmorPart_RFArm", "ArmorPart_RFoot",
                          "ArmorPart_RHand", "ArmorPart_Robe", "ArmorPart_RShin", "ArmorPart_RShoul", "ArmorPart_RThigh",
                          "ArmorPart_Torso", "VarTable",
                          "Repos_PosX", "Repos_Posy"],                  
                  "utm": @["BlackMarket", "BM_Markdown", "IdentifyPrice", "LocName", "MarkDown", "MarkUp", "MaxBuyPrice",
                          "OnOpenStore", "OnCloseStore", "ResRef", "StoreGold", "StoreList", "WillNotBuy", "WillOnlyBuy", "Tag",
                          "ItemList", "VarTable"],
                  "utp": @["AnimationState", "Appearance", "AutoRemoveKey", "CloseLockDC", "Conversation", "CurrentHP",
                          "Description", "DisarmDC", "Faction", "Fort", "Hardness", "HP", "Interruptable", "Lockable",
                          "Locked", "LocName", "OnClosed", "OnDamaged", "OnDeath", "OnDisarm", "OnHeartbeat", "OnLock",
                          "OnMeleeAttacked", "OnOpen", "OnSpellCastAt", "OnTrapTriggered", "OnUnlock", "OnUserDefined",
                          "OpenLockDC", "Plot", "PortraitID", "Ref", "Tag", "TemplateResRef", "TrapDetectable", "TrapDetectDC",
                          "TrapDisarmable", "TrapFlag", "TrapOneShot", "TrapType", "Will",
                          "BodyBag", "HasInventory", "ItemList", "OnInvDisturbed", "OnUsed", "Static", "Type", "Useable",
                          "ItemList", "VarTable"],
                  "uts": @["Active", "Continuous", "Elevation", "Hours", "Interval", "IntervalVrtn", "LocName", "Looping",
                          "MaxDistance", "MinDistance", "PitchVariation", "Positional", "Priority", "Random", "RandomPosition",
                          "RandomRangeX", "RandomRangeY", "Sounds", "Tag", "TemplateResRef", "Times", "Volume", "VolumeVrtn", "VarTable"],
                  "utt": @["AutoRemoveKey", "Cursor", "DisarmDC", "Faction", "HighlightHeight", "KeyName", "LinkedTo",
                          "LinkedToFlags", "LoadScreenID", "LocalizedName", "OnClick", "OnDisarm", "OnTrapTriggered",
                          "PortraitID", "ScriptHeartbeat", "ScriptOnEnter", "ScriptOnExit", "ScriptUserDefine", "Tag",
                          "TemplateResRef", "TrapDetectable", "TrapDetectDC", "TrapDisarmable", "TrapFlag", "TrapOneShot",
                          "TrapType", "Type", "VarTable"],
                  "utw": @["Appearance", "Description", "HasMapNote", "LinkedTo", "LocalizedName", "MapNote", "MapNoteEnabled",
                          "Tag", "VarTable"],
                  }.toTable
  
  # Fields only found in instances
  InstanceFields = {"utc": @["TemplateResRef", "XOrientation", "YOrientation", "XPosition", "YPosition", "ZPosition"],
                    "utd": @["Bearing", "TemplateResRef", "X", "Y", "Z"],
                    "ute": @["Geometry", "SpawnPointList", "TemplateResRef", "XPosition", "YPosition", "ZPosition"],
                    "uti": @["TemplateResRef", "XOrientation", "YOrientation", "XPosition", "YPosition", "ZPosition",
                            "Repos_PosX", "Repos_Posy"],
                    "utm": @["TemplateResRef", "XOrientation", "YOrientation", "XPosition", "YPosition", "ZPosition"],
                    "utp": @["Bearing", "TemplateResRef", "X", "Y", "Z",
                            "ItemList"],
                    "uts": @["GeneratedType", "TemplateResRef", "XPosition", "YPosition", "ZPosition"],
                    "utt": @["Geometry", "TemplateResRef", "XOrientation", "YOrientation", "XPosition", "YPosition", "ZPosition"],
                    "utw": @["TemplateResRef", "XOrientation", "YOrientation", "XPosition", "YPosition", "ZPosition"],
                  }.toTable

  ListIdentifier = {"VarTable": "Name",
                    "ClassList": "Class",
                    "KnownList": "Spell",
                    "Equip_ItemList": "__struct_id",
                    "FeatList": "Feat"
                  }.toTable

#if not args["--file"]:
#  quit("Blueprint file name(s) must be specified with -f or --file.")

let dbg = newDebugPrinter(stdout)

proc `[]=`(obj: JsonNode, idx: int, val: JsonNode) {.inline.} =
  ## Custom assignment required by keepItIf since this doesn't exist for JArrays
  assert(obj.kind == JArray)
  obj[idx] = val

proc isResDir(c: ResContainer): bool = startsWith($c, "ResDir:")
  ## Determines if a container is a ResDir

proc resRefToFullPath(self: ResContainer, rr: ResolvedResRef): string =
  ## Provides full file pathing to rr in self, only works with ResDirs
  let path = split($self, ":", 1)
  result = path[path.high] & DirSep & rr.toFile

proc resContainerToFullPath(self: ResContainer): string =
  ## Provides full files pathing to self, only works with erfs
  let path = split($self, ":", 1)
  result = path[path.high]

proc openErf(filename: string): Erf =
  ## reads an Erf into memory.
  ## Copy of openErf from nwn_erf.nim since it's not a library
  let infile = openFileStream(filename)
  doAssert(infile != nil, "Could not open " & filename & " for reading")
  result = infile.readErf(filename = filename.splitPath.tail)

template keepItIf(node: JsonNode, keep: untyped) =
  ## Custom template to keep specific elements of a JArray
  var pos = 0

  for i in 0 ..< node.len:
    let it {.inject.} = node[i]
    if keep:
      if pos != i:
        when defined(gcDestructors):
          node[pos] = node[i].move()
        else:
          node[pos] = node[i].copy()
      inc(pos)
  
  setLen(node.elems, pos)

proc objectKeys(node: JsonNode): seq[string] =
  ## Returns all keys in node that are of type JObject
  for k, v in node:
    if v.kind == JObject:
      result.add k

proc mergeLists(instanceList, blueprintList: JsonNode, k: string) =
  ## Merges two JArrays
  ## On conflict, elements from blueprintList win
  var key = k

  # Support KnownList*
  if key[key.high].isDigit:
    key = key[0 ..< key.high]

  # The I'm-a-hack method, just delete any list entries from
  # instanceList that blueprintList already has, then copy everything
  # from blueprintList
  if ListIdentifier.hasKey(key):
    let identifier = ListIdentifier[key]

    instanceList.keepItIf($it.fields[identifier] notin blueprintList.mapIt($(it.fields)[identifier]))

    for item in blueprintList:
      instanceList.add(item)

    dbg.emit "Merging", fmt"[{k}] merged at user request"
  else:
    dbg.emit "Skipping", fmt"merging [{k}] is not supported at this time"

proc updateNode(instanceNode: JsonNode, blueprintJson: JsonNode, target: tuple) =
  ## Update instanceNode with fields from blueprintJson
  for k, v in blueprintJson:
    if k.toLower in mapIt(split($args["--skip"], ","), it.toLower):
      dbg.emit "Skipping", fmt"[{k}] skipped at user request"
      continue

    # don't modify instance-only fields
    if k in InstanceFields[target.extension]:
      dbg.emit "Ignoring", fmt"[{k}] is an instance-only field and will be ignored"
      continue

    # don't add blueprint-only fields
    if k in BlueprintFields:
      dbg.emit "Ignoring", fmt"[{k}] is a blueprint-only field and will be ignored"
      continue

    # we only expect objects and, possible JINTs
    if v.kind != JObject:
      dbg.emit "Ignoring", fmt"[{k}] is not interesting and will not be modified"
      continue

    let nodeType = blueprintJson[k]["type"].getStr()

    if nodeType in simpleType:
      if instanceNode{k}["value"] != blueprintJson[k]["value"]:
        dbg.emit "Updating", fmt"[{k}] udpated to blueprint field"
        instanceNode{k} = blueprintJson[k]
    elif nodeType == "list":
      if instanceNode{k} == blueprintJson[k]:
        continue

      if k.toLower in mapIt(split($args["--merge"], ","), it.toLower):
        if instanceNode.hasKey(k):
          mergeLists(instanceNode[k]["value"], blueprintJson[k]["value"], k)
          continue

      if instanceNode.hasKey(k):
        updateNode(instanceNode[k], blueprintJson[k], target)
      else:
        dbg.emit "Updating", fmt"[{k}] updated to blueprint field"
        instanceNode{k} = blueprintJson[k]

proc updateInstance(instanceJson: JsonNode, blueprintJson: JsonNode, target: tuple, expectedNodes: HashSet) =
  # loops through instanceJson to determine if any updates are required from blueprintJson
  for _, v in instanceJson:
    case v.kind:
    of JString: continue
    of JObject:
      if v{"type"}.getStr() == "list":
        v.updateInstance(blueprintJson, target, expectedNodes)
      else:
        continue
    of JArray:
      for node in v:
        if node.hasKey(target.key):
          if node[target.key]["value"] == target.value:
            let excessNodes = node.objectKeys.toHashSet() - expectedNodes

            if excessNodes.len > 0:
              echo fmt"trimming excess nodes {excessNodes}"
              for k, _ in node:
                if k in excessNodes:
                  node.delete(k)
            
            dbg.nest fmt"Updating instance of {target.value}":
              node.updateNode(blueprintJson, target)
          else:
            node.updateInstance(blueprintJson, target, expectedNodes)
    else:
      continue

proc updateField(blueprintJson: JsonNode) =
  for kvp in split($args["--set"], ","):
    let kv = kvp.split(":")
    if blueprintJson.hasKey(kv[0]):
      let key = blueprintJson[kv[0]]["type"].getStr()
      case key
      of "dword", "short", "int", "byte", "word":
        blueprintJson[kv[0]]["value"] = %kv[1].parseInt()

# create the base resman that has all the erfs/dirs in it
let rm = newBasicResMan()

if args["--set"]:
  var
    dir = $args["--dirs"]
    blueprintRoot: GffRoot
    blueprintJson: JsonNode
    stream: Stream

  # update individual files
  for file in filterByType(rm):
    echo $file.resRef
    echo dir / $file.resRef
    stream = newFileStream(dir / $file.resRef, fmRead)
    blueprintRoot = stream.readGffRoot(false)
    stream.close()

    blueprintJson = blueprintRoot.toJson()
    blueprintJson.updateField()
    blueprintRoot = blueprintJson.gffRootFromJson()

    stream = newFileStream(dir / $file.resRef, fmWrite)
    #stream.setPosition(0)
    stream.write(blueprintRoot)
    stream.close()

  quit("done with blueprint stuff!")

# Don't cross the streams
for c in rm.containers:
  let rmc = newResMan()
  var modifiedFiles = initTable[string, ResMemFile]()

  # rmc is a container that only contains a single erf/dir so we don't update
  # and instance in one erf/dir with a blueprint in a different erf/dir
  # This methos is used because ResContainer implementation isn't complete
  rmc.add(c)

  for fileName in split($args["--file"], ","):
    let rr = newResolvedResRef(fileName)
    var blueprintResRef: string

    # ensure blueprint file exists in container
    if not c.contains(rr):
      echo fmt"{rr} could not be found in {c}"
      continue

    # could just use file name, but let's be thorough in case there are changes later
    let blueprint = rmc[rr].get()
    blueprint.seek()

    let
      blueprintStream = blueprint.io.readGffRoot(false)
      blueprintJson = blueprintStream.toJson()
      field = if rr.resExt() == "utm": "ResRef" else: "TemplateResRef"

    if not blueprintStream.hasField(field, GffResRef):
      debug fmt"{fileName} does not have a resref field and may not be a valid gff resource; skipping"
      continue

    # target is the old resRef, or the stringified data from TemplateResRef field in the .ut*
    blueprintResRef = $blueprintStream[field, GffResRef]

    var
      interestingFiles: seq[string]
      instanceStream: GffRoot
      instanceJson: JsonNode
      target: tuple[key: string, value: JsonNode, extension: string]
      stream: Stream
    
    # values used by procedures that update the instances
    target.key = field
    target.value = %($blueprintResRef)
    target.extension = getFileExt(fileName)

    # figure out which files have the instances in them
    # filterByMatch is a customized version of that same proc from neverwinter.nim
    # that only looks at files of type --fileTypes (defaults to .git)
    for res in filterByMatch(rmc, blueprintResRef):
      interestingFiles.add($res.resRef)

    # found some files that *might* need updating
    if interestingFiles.len > 0:
      dbg.nest fmt"Updating instances of {blueprintResRef}":
        # create the field comparison sequence and pass it along.  Done here
        # to prevent repitition in modification procedures
        let expectedNodes = (blueprintJson.objectKeys.toHashSet() + 
                            InstanceFields[target.extension].toHashSet()) - 
                            BlueprintFields.toHashSet()

        dbg.emit "Found", fmt"{interestingFiles.len} files that " &
                          fmt"are interesting for {blueprintResRef}"

        # update individual files
        for file in interestingFiles:
          let 
            rr = newResolvedResRef(file)
            instance = rmc[rr].get()

          # prep for ResDir is slightly different than erfs
          if c.isResDir():
            stream = openFileStream(c.resRefToFullPath(rr))
            instanceStream = stream.readGffRoot(false)
            stream.close
          else: 
            instance.seek()
            instanceStream = instance.io.readGffRoot(false)

          # this is where all the work is done, the rest is just making shit smell nice
          instanceJson = instanceStream.toJson()
          instanceJson.updateInstance(blueprintJson, target, expectedNodes)
          instanceStream = instanceJson.gffRootFromJson()

          # if ResDir, write back to the file, for erfs ... hold in memory until write time
          if c.isResDir():
            stream = openFileStream(c.resRefToFullPath(rr), fmWrite)
            stream.write(instanceStream)
            stream.close
          else:
            stream = newStringStream()
            stream.write(instanceStream)
            stream.setPosition(0)
            
            # save the changed file to a resmemfile for later use
            let rmf = newResMemFile(stream.readAll(), newResRef(rr.resRef, rr.resType), rr.toFile)
            modifiedFiles.add(rr.toFile, rmf)
    else:
      dbg.emit "Info", fmt"No interesting files found for {blueprintResRef}"

  debug fmt"Total modified files - {modifiedFiles.len}"

  # modifiedFiles.len > 0 implies this is an erf
  if modifiedFiles.len > 0:
    let erfPath = resContainerToFullPath(c) # the .mod file pathing
    #let oldErf = openErf(erfPath)           # the opened .mod file
    let newErf = erfPath.splitPath.head / "_temp_build." & getFileExt(erfPath)

    let newStream = openFileStream(newErf, fmWrite)


    writeErf(io = newStream,
             fileType = "MOD",
             locStrings = initTable[int, string](),
             strRef = 0,
             entries = toSeq(c.contents)) do (r: ResRef, io: Stream):

      if modifiedFiles.hasKey($r):
        let res = modifiedFiles[$r].demand(r)
        echo fmt"Writing modified resource {r}"
        io.write(res.readAll())
      else:
        let res = c.demand(r)
        res.seek()
        echo fmt"Writing unmodified resource {r}"
        io.write(res.readAll())

      discard

    # for some reason, not able to release the lock on erfPath
    # removing the containers doesn't work.  Maybe have to move to
    # single resman, then closing the ios on every resref?  That would suck
    rmc.del(c)
    rm.del(c)

    newStream.close
    moveFile(newErf, erfPath)
    #removeFile(newErf)

when false:
    writeErf(newStream,
             oldErf.fileType,
             oldErf.locStrings,
             oldErf.strRef,
             toSeq(oldErf.contents)) do (r: ResRef, io: Stream):
      
      if modifiedFiles.hasKey($r):
        let res = modifiedFiles[$r].demand(r)
        echo fmt"Writing modified resource {r}"
        io.write(res.readAll())
      else:
        let res = oldErf.demand(r)
        echo fmt"writing unmodified resource {r}"
        io.write(res.readAll())

      discard
  