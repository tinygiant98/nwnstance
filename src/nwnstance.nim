import shared, debugprinter

let args = DOC """
Update instances of blueprints in a packed or unpacked nwn module

Note: this tool does not work on files that have been converted to json via
  tools such as neverwinter.nim.  Unpacked modules must be in gff formats.

Usage:
  $0 [options]
  $0 (--dirs <dir> | --erfs <erf>) [-s <file>...] [--filtetypes <types>...] [options]
  $USAGE

Options:
  --filetypes TYPES           Comma delimited list of gff file extensions to search
                              for the instance to update [default: git]
  -f, --file FILES            Comma delimited list of blueprint files
  --skip SKIPS                Fields to skip modification of [Default: ]
  --merge MERGES              Fields to merge [Default: ]
  --erfs ERFS                 Load comma-separated erf files [default: ]
  --dirs DIRS                 Load comma-separated directories [default: """ & getCurrentDir() & """]
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
                           "willbonue", "Wings", "VarTable"],
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

let
  dir = $args["--dirs"]
  dbg = newDebugPrinter(stdout)

if not (args["--dirs"] or args["--erfs"]) and args["--file"]:
  quit("nwnstance requires reference to target folders and at least one blueprint file")

proc `[]=`(obj: JsonNode, idx: int, val: JsonNode) {.inline.} =
  ## Custom assignment required by keepItIf since this doesn't exist for JArrays
  assert(obj.kind == JArray)
  obj[idx] = val

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
  var key = k

  # Support KnownList*
  if key[key.high].isDigit:
    key = key[0 ..< key.high]

  if ListIdentifier.hasKey(key):
    let identifier = ListIdentifier[key]

    instanceList.keepItIf($it.fields[identifier] notin blueprintList.mapIt($(it.fields)[identifier]))

    for item in blueprintList:
      instanceList.add(item)

    dbg.emit "Merging", fmt"[{k}] merged at user request"
  else:
    dbg.emit "Error", fmt"merging {k} is not supported at this time"

proc updateNode(instanceNode: JsonNode, blueprintJson: JsonNode, target: tuple) =
  ## Update instanceNode with fields from blueprintJson
  for k, v in blueprintJson:
    if k.toLower in mapIt(split($args["--skip"], ","), it.toLower):
      dbg.emit "Skipping", fmt"[{k}] skipped at user request"
      continue

    if k in InstanceFields[target.extension]:
      dbg.emit "Ignoring", fmt"[{k}] is an instance-only field and will be ignored"
      continue

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
      interestingFiles: seq[string]
      instanceStream: GffRoot
      instanceJson: JsonNode
      target: tuple[key: string, value: JsonNode, extension: string]
      stream: Stream
    
    target.key = field
    target.value = %($resRef)
    target.extension = getFileExt(file)

    for res in filterByMatch(rm, resRef):
      interestingFiles.add($res.resRef)

    dbg.nest fmt"Updating instances of {resRef}":

      if interestingFiles.len > 0:
        # create the field comparison sequence and pass it along.
        let expectedNodes = (blueprintJson.objectKeys.toHashSet() + 
                            InstanceFields[target.extension].toHashSet()) - 
                            BlueprintFields.toHashSet()

        dbg.emit "Found", fmt"{interestingFiles.len} files that " &
                           fmt"are interesting for {resRef}"

        for file in interestingFiles:
          stream = openFileStream(file)
          instanceStream = stream.readGffRoot(false)
          stream.close 
          instanceJson = instanceStream.toJson()
          instanceJson.updateInstance(blueprintJson, target, expectedNodes)
          instanceStream = instanceJson.gffRootFromJson()

          stream = openFileStream(file, fmWrite)
          stream.write(instanceStream)
          stream.close
      else:
        dbg.emit "Info", fmt"No interesting files found for {resRef}"
   