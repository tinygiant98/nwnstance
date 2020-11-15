import strformat, strutils, algorithm, os, streams, json, sequtils, logging, times, tables, sets, strutils
export strformat, strutils, algorithm, os, streams, json, sequtils, logging, times, tables, sets, strutils

import neverwinter/util, neverwinter/resman,
  neverwinter/resref, neverwinter/key,
  neverwinter/resfile, neverwinter/resmemfile, neverwinter/resdir,
  neverwinter/resdir, neverwinter/erf, neverwinter/gff, neverwinter/gffjson
  #neverwinter/languages

# The things we do to cut down import hassle in tools.
# Should clean this up at some point and let the utils deal with it.
export util, resman, gff, erf, gffjson, resdir, resmemfile, resfile, resref, key
#export util, resman, resref, key, resfile, resmemfile, resdir, erf, gff, gffjson,
#  languages

import terminal

when defined(profiler):
  import nimprof

const GffExtensions* = @[
  "utc", "utd", "ute", "uti", "utm", "utp", "uts", "utt", "utw",
  "git", "are", "gic", "ifo", "fac", "dlg", "itp", "bic",
  "jrl", "gff", "gui"
]

addHandler newFileLogger(stderr, fmtStr = "$levelid [$datetime] ")

if isatty(stdout):
  hideCursor()
  system.addQuitProc do () -> void {.noconv.}:
    resetAttributes()
    showCursor()

import docopt as docopt_internal
export docopt_internal

const GlobalUsage = """
  $0 -h | --help
  $0 --version
""".strip

# Options common to ALL utilities
let GlobalOpts = """

Logging:
  --verbose                   Turn on debug logging
  --quiet                     Turn off all logging except errors
  --version                   Show program version and licence info

Encoding:
  --nwn-encoding CHARSET      Sets the nwn encoding [default: """ & getNwnEncoding() & """]
  --other-encoding CHARSET    Sets the "other" file formats encoding, where
                              supported; see docs. Defaults to your current
                              shell/platform charset: [default: """ & getNativeEncoding() & """]
Resources:
  --add-restypes TUPLES       Add a restype. TUPLES is a comma-separated list
                              of colon-separated restypes. You do not need to do this
                              unless you want to handle files NWN does not know about
                              yet.
                              Example: txt:10,mdl:2002
"""

var Args: Table[string, docopt_internal.Value]

proc DOC*(body: string): Table[string, docopt_internal.Value] =
  let body2 = body.replace("$USAGE", GlobalUsage).
                   replace("$0", getAppFilename().extractFilename()).
                   replace("$OPT", GlobalOpts)

  result = docopt_internal.docopt(body2)
  Args = result

  #[if Args["--version"]:
    printVersion()
    quit()]#

  if Args.hasKey("--verbose") and Args["--verbose"]: setLogFilter(lvlDebug)
  elif Args.hasKey("--quiet") and Args["--quiet"]: setLogFilter(lvlError)
  else: setLogFilter(lvlInfo)

  setNwnEncoding($Args["--nwn-encoding"])
  setNativeEncoding($Args["--other-encoding"])

  debug("NWN file encoding: " & getNwnEncoding())
  debug("Other file encoding: " & getNativeEncoding())

  if Args.hasKey("--add-restypes") and Args["--add-restypes"]:
    let types = ($Args["--add-restypes"]).split(",").mapIt(it.split(":"))
    for ty in types:
      if ty.len != 2:
        raise newException(ValueError,
          "Could not parse --add-restypes: '" & ($Args["--add-restypes"]) & "'")

      let (rt, ext) = (ty[1].parseInt, ty[0])

      if rt < low(uint16).int or rt > high(uint16).int:
        raise newException(ValueError, "Integer " & $rt & " out of range for ResType")

      registerResType(ResType rt, ext)
      debug "Registering custom ResType ", ext, " -> ", rt

proc findNwnRoot*(): string =
  if Args["--root"]:
    result = $Args["--root"]
  elif getEnv("NWN_ROOT") != "":
    result = getEnv("NWN_ROOT")
  else:
    when defined(macosx):
      let settingsFile = r"~/Library/Application Support/Beamdog Client/settings.json".expandTilde
    elif defined(linux):
      let settingsFile = r"~/.config/Beamdog Client/settings.json".expandTilde
    elif defined(windows):
      let settingsFile = getHomeDir() / r"AppData\Roaming\Beamdog Client\settings.json"
    else: {.fatal: "Unsupported os for findNwnRoot"}

    let data = readFile(settingsFile)
    let j = data.parseJson
    doAssert(j.hasKey("folders"))
    doAssert(j["folders"].kind == JArray)

    # Which NWN release do we want? So many questions. We pick the first one available, in order:
    # 00840: Digital Deluxe Beta (Head Start)
    # 00829: Normal Beta (Head Start)
    # TODO:
    #   00839: Digital Deluxe
    #   00832: Nightly
    const releases = ["00840", "00829"]
    for torrentId in releases:
      var fo = j["folders"].mapIt(it.str / torrentId)

      fo.keepItIf(dirExists(it))
      if fo.len > 0:
        result = fo[0]
        break

  if result == "" or not dirExists(result): raise newException(ValueError,
    "Could not locate NWN; try --root")
  debug "NWN root: ", result

#proc newBasicResMan*(root = findNwnRoot(), language = "", cacheSize = 0): ResMan =
proc newBasicResMan*(root = "", language = "", cacheSize = 0): ResMan =
  ## Sets up a resman that defaults to what 1.8 looks like.
  ## Will load an additional language directory, if language is given.
#[
  let resolvedLanguage = if language == "": $Args["--language"] else: language
  let resolvedLanguageRoot = root / "lang" / resolvedLanguage

  # 1.6
  let legacyLayout = fileExists(root / "chitin.key")
  if legacyLayout: debug("legacy resman layout detected (1.69)")
  else: debug("new resman layout detected (1.8 w/ nwn_base & _loc)")

  doAssert(dirExists(resolvedLanguageRoot), "language " & resolvedLanguageRoot & " not found")

  # Attempt to auto-detect the resman type we have.
  let actualKeys =
    if $Args["--keys"] == "autodetect":
      # 1.6:
      if legacyLayout: "chitin,xp1,xp2,xp3,xp2patch"
      # 1.8:
      #else: "nwn_base,nwn_base_loc,xp1,xp2,xp3,xp2patch"
      else: "nwn_base" #,nwn_base_loc"
    else: $Args["--keys"]

  let keys =        actualKeys.split(",").mapIt(it.strip).filterIt(it.len > 0)]#

  let erfs = ($Args["--erfs"]).split(",").mapIt(it.strip).filterIt(it.len > 0)
  let dirs = ($Args["--dirs"]).split(",").mapIt(it.strip).filterIt(it.len > 0)

  for e in erfs:
    if not fileExists(e): quit("requested --erfs not found: " & e)

  for d in dirs:
    if not dirExists(d): quit("requested --dirs not found: " & d)
#[
  proc loadKey(into: ResMan, key: string) =
    let keyFile = if legacyLayout: key & ".key"
                  else: "data" / key & ".key"

    let fn = if fileExists(resolvedLanguageRoot / keyFile): resolvedLanguageRoot / keyFile
             else: root / keyFile

    if not fileExists(fn):
      warn("  key not found, skipping: ", fn)
      return
    let ktfn = openFileStream(fn)

    debug("  key: ", fn)

    let kt = readKeyTable(ktfn, fn) do (fn: string) -> Stream:
      let otherBifFn = resolvedLanguageRoot / "data" / fn.extractFilename()
      let bifFn = if fileExists(otherBifFn): otherBifFn
                  else: root / fn

      debug("    bif: ", bifFn)
      result = openFileStream(bifFn)

    into.add(kt)

  debug "Resman (language=", resolvedLanguage, ")"]#
  result = resman.newResMan(cacheSize)
#[#
  if not Args["--no-keys"]:
    for k in keys: #.withProgressBar("load key: "):
      result.loadKey(k)]#

  for e in erfs: #.withProgressBar("load erf: "):
    let fs = openFileStream(e)
    let erf = fs.readErf(e)
    debug "  ", erf
    result.add(erf)

#[
  if not legacyLayout and not Args["--no-ovr"]:
    let c = newResDir(root / "ovr")
    debug "  ", c
    result.add(c)
  if not legacyLayout and not Args["--no-ovr"]:
    let c = newResDir(resolvedLanguageRoot / "data" / "ovr")
    debug "  ", c
    result.add(c)]#

  for d in dirs: #.withProgressBar("load resdir: "):
    let c = newResDir(d)
    debug "  ", c
    result.add(c)

proc ensureValidFormat*(format, filename: string,
                       supportedFormats: Table[string, seq[string]]): string =
  result = format
  if result == "autodetect" and filename != "-":
    let ext = splitFile(filename).ext.strip(true, false, {'.'})
    for fmt, exts in supportedFormats:
      if exts.contains(ext):
        result = fmt
        break

  if result == "autodetect":
    quit("Cannot detect file format from filename: " & filename)

  if not supportedFormats.hasKey(result):
    quit("Not a supported file format: " & result)

template withDir*(dir: string, body: untyped): untyped =
  let curDir = getCurrentDir()
  try:
    setCurrentDir(dir)
    body
  finally:
    setCurrentDir(curDir)

proc getFileExt*(file: string): string =
  ## Returns the file extension without the leading "."
  file.splitFile.ext.strip(chars = {ExtSep})

iterator filterByType*(rm: ResMan): Res =
  for o in rm.contents:
    let res = rm[o].get()

    if getFileExt($res.resRef) in split($Args["--filetypes"], ","):
      if Args["--only"] and $res.resRef in split($Args["--only"]):
        yield(res)
      elif $res.resRef notin split($Args["--skip"]):
        yield(res)

iterator filterByMatch*(rm: ResMan, binaryMatch: string): Res =
  for o in rm.contents:
    let res = rm[o].get()

    if getFileExt($res.resRef) notin split($Args["--filetypes"], ","):
      continue

    let match = res.readAll(useCache = false).count(binaryMatch)
    let plurality = if match != 1: "s" else: ""

    if match > 0:
      debug fmt"Found {$match} instance{plurality} of {binaryMatch} in {$res.resRef}"
      yield(res)
