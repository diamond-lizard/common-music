--------------------------------------------------------------------------------
--                              Command Line
--------------------------------------------------------------------------------

newoption({trigger = "with-oscpack", description = "Optionally include oscpack."})
newoption({trigger = "with-fomus", description = "Optionally include fomus, using the specified the fomus installation prefix."})
newoption({trigger = "with-sdif", description = "Optional sdif install prefix."})
newoption({trigger = "with-jack", description = "Enable jack support on linux."})
newoption({trigger = "macappstore", description = "Experimental build for mac app store."})
newaction({trigger = "cleanall", description = "Cleans all generated files, directories and scripts.",
           execute = function()
                        premake.action.call("clean")
                        os.rmdir(FromRoot("lib"))
                        os.rmdir(FromRoot("bin"))
                        os.rmdir(FromRoot("obj"))
                     end})

-- if true build with xcode for iTunes mac app store
MacAppStore = false

if (not _ACTION) then
   if (os.is("windows")) then
      _ACTION = "vs2010"
   else if (os.is("macosx")) then
         if (_OPTIONS["macappstore"]) then
            MacAppStore = true;
            _ACTION = "xcode4"
         else
            _ACTION = "gmake"
         end
      else
         _ACTION = "gmake"
      end
   end
end

--------------------------------------------------------------------------------
--                              Global Config
--------------------------------------------------------------------------------

--General
DebugFlags = {"Symbols", "NoPCH", "NoManifest"}
ReleaseFlags = {"NoPCH", "NoManifest"}
SpeedFlags = {"OptimizeSpeed", "NoPCH", "NoManifest"}

--Warnings
StandardGCCWarnings = {"-Wall"}

--Mac
MacFrameworks = {"-framework AudioToolbox", "-framework AudioUnit",
                 "-framework Carbon", "-framework Cocoa", "-framework CoreServices",
                 "-framework CoreAudio", "-framework CoreAudioKit", "-framework CoreMidi",
                 "-framework ApplicationServices", "-framework AGL", -- "-framework QTKit",
                 "-framework IOKit", "-framework QuartzCore", "-framework WebKit",
                 "-framework Accelerate","-framework DiscRecording"} --maybe dont need this one?
--MacTarget = "-mmacosx-version-min=10.6" -mmacosx-version-min=10.8
MacTarget = "-Wno-c++11-extensions -mmacosx-version-min=10.6"

--JUCE
JUCEDefines = {"JUCE_IOS=0", "AU_LOGGING=0",
               "JUCE_QUICKTIME=0", "JUCE_OPENGL=0", 
               "JUCE_USE_FLAC=1",
               "JUCE_USE_OGGVORBIS=1",
               "JUCE_USE_MP3AUDIOFORMAT=1",
               "JUCE_USE_WINDOWS_MEDIA_FORMAT=1",
               "JUCE_USE_CDBURNER=0", "JUCE_USE_CDREADER=0",
               "JUCE_WEBBROWSER=0", "JUCE_CHECK_MEMORY_LEAKS=0", "JUCE_SUPPORT_CARBON=0"}
--
--------------------------------------------------------------------------------
--                                  Paths
--------------------------------------------------------------------------------

PathToRoot = ""
PathToSrc = "src/"
PathToJUCE =  "juce/"
PathToSndlib = "sndlib/"
PathToSndlibLib = "sndlib/lib/"
PathToOscPack = "oscpack/"
PathToLib = "lib/"
PathToBin = "bin/"
PathToObj = "obj/"
PathToRes = "res/"
PathToX11 = "/usr/X11R6/lib/"

--------------------------------------------------------------------------------
--                             Helper Functions
--------------------------------------------------------------------------------

--Get the correct relative path from the current location.
function FromRoot(PathFromRoot)
   return PathToRoot .. PathFromRoot
end

--Get path to juce module.
function JUCEModule(name)
   local ext = ((os.get() == "macosx") and "mm" or "cpp")
   return FromRoot(PathToJUCE) .. "modules/" .. name .. "/" .. name .. "." .. ext
end

--Make sure directory component ends with a slash
function insure_slash(dir) 
  --insure slash at end of directory so concatenation works
  if not (string.sub(dir, string.len(dir)) == "/")  then
     dir = dir .. "/"
  end
  return dir
end

-- Return true if file exists
function file_exists(path)
   local f=io.open(path,"r")
   if f ~= nil then 
      io.close(f)
      return true
   else
      return false
   end
end

--------------------------------------------------------------------------------
--                              PREMAKE CONFIG
--------------------------------------------------------------------------------

solution("Common Music")
--Create a release, debug, and speed configuration for each project.
configurations({"Debug", "Release" , "Speed"})

--------------------------------------------------------------------------------
--                                   S7
--------------------------------------------------------------------------------

if (MacAppStore) then
   location("xcode")
end
-- unused
if (false) then
   project("s7")
   language("C++")
   kind("ConsoleApp")
   files({FromRoot(PathToSrc) .. "s7.cpp"})
   includedirs({FromRoot(PathToSrc), FromRoot(PathToSndlib)})
   libdirs({FromRoot(PathToSndlibLib)})
   objdir(FromRoot(PathToObj) .. "s7")
   targetdir(FromRoot(PathToBin))
   links({"sndlib"})
   defines({"HAVE_SCHEME=1"})
   configuration("not windows")
   --dowload sndlib now
   if (not os.isdir(FromRoot("sndlib"))) then
      os.execute("res/bin/sndlib.sh --nobuild")
   end
  prebuildcommands("res/bin/sndlib.sh")

   configuration("macosx")
   linkoptions({"-framework CoreAudio", "-framework CoreFoundation", "-framework CoreMidi"})
   configuration("linux")
   links({"asound"})   
   configuration("windows")
   links({"winmm"})
   linkoptions({"/nodefaultlib:libcmt.lib"}) -- stop libcmt.lib from complaining
end

--------------------------------------------------------------------------------
--                                  OSCPACK
--------------------------------------------------------------------------------

if (_OPTIONS["with-oscpack"])  then
   -- need to recompile all of Grace if we are including oscpack into
   -- a code base that currently doesnt contain it
   local check = FromRoot("obj/Grace")
   if (os.isdir(check) and table.getn(os.matchfiles(check .. "/**/OscPack.*")) == 0) then
      -- force full recompile of Grace when newly adding oscpack
      os.rmdir(check)
   end

   -- if oscpack source directory doesnt exist then download
   -- immediately so files() command can add its sources to the
   -- project
   if (not os.isdir(FromRoot("oscpack"))) then
      os.execute("res/bin/oscpack.sh")
   end

   project("oscpack")
   language("C++")
   kind("StaticLib")
   flags({"StaticRuntime"})
   objdir(FromRoot(PathToObj) .."oscpack")
   targetdir(FromRoot(PathToLib))
   includedirs({FromRoot(PathToOscPack)})
 
   files({FromRoot(PathToOscPack) .. "osc/*.h",
          FromRoot(PathToOscPack) .. "osc/*.cpp",
          FromRoot(PathToOscPack) .. "ip/*.h",
          FromRoot(PathToOscPack) .. "ip/*.cpp"})

   -----------------------Configuration Dependent Settings-----------------------

   configuration("not windows")

   defines({"OSC_DETECT_ENDIANESS=1"})
   files({FromRoot(PathToOscPack) .. "ip/posix/*.h",
          FromRoot(PathToOscPack) .. "ip/posix/*.cpp"})

   configuration("windows")
   defines({"OSC_HOST_LITTLE_ENDIAN=1"})
   files({FromRoot(PathToOscPack) .. "ip/win32/*.h",
          FromRoot(PathToOscPack) .. "ip/win32/*.cpp"})
   linkoptions({"/nodefaultlib:libcmt.lib"}) -- stop libcmt.lib from complaining
elseif (_ACTION == "gmake" or _ACTION == "xcode4") then
   -- check .o files to see if code base currently includes oscpack
   local check = FromRoot("obj/Grace")
   if (os.isdir(check) and table.getn(os.matchfiles(check .. "/**/OscPack.*")) > 0) then
      -- force full recompile of Grace when removing oscpack
      os.rmdir(check)
   end
end

--------------------------------------------------------------------------------
--                                   JUCE
--------------------------------------------------------------------------------

if (not os.isdir(FromRoot("juce"))) then
   os.execute("res/bin/juce.sh")
end

project("juce")
language("C++")
kind("StaticLib")
flags( {"StaticRuntime"})
includedirs({FromRoot(PathToJUCE)})
includedirs({FromRoot(PathToSrc)}) --For AppConfig.h
objdir(FromRoot(PathToObj) .. "juce")
targetdir(FromRoot(PathToLib))
files({JUCEModule("juce_audio_basics"),
       JUCEModule("juce_audio_devices"),
       JUCEModule("juce_audio_formats"),
       JUCEModule("juce_audio_processors"),
       JUCEModule("juce_audio_utils"),
       JUCEModule("juce_core"),
       JUCEModule("juce_data_structures"),
       JUCEModule("juce_events"),
       JUCEModule("juce_graphics"),
       JUCEModule("juce_gui_basics"),
       JUCEModule("juce_gui_extra")})

-----------------------Configuration Dependent Settings-----------------------

configuration("not windows")
--prebuildcommands("res/bin/juce.sh")

-- Mac
configuration("macosx")
buildoptions(MacTarget)
-- if (_ACTION == "gmake") then buildoptions("-Wno-c++11-extensions") end
table.insert(JUCEDefines, "JUCE_PLUGINHOST_AU=1")
defines(JUCEDefines)

-- Linux
configuration("linux")
buildoptions({"`pkg-config --cflags freetype2`"})
table.insert(JUCEDefines, "JUCE_ALSA=1")
if (_OPTIONS["jack"]) then table.insert(JUCEDefines, "JUCE_JACK=1") end
defines(JUCEDefines)

-- Windows
configuration("windows")
defines(JUCEDefines)

--Set debug and non-debug flags which JUCE requires.
configuration "Debug" flags(DebugFlags) defines("DEBUG")
configuration "Release" flags(ReleaseFlags) defines({"NDEBUG", "_NDEBUG"})
configuration "Speed" flags(SpeedFlags) defines({"NDEBUG", "_NDEBUG"})

--------------------------------------------------------------------------------
--                                   GRACE
--------------------------------------------------------------------------------

ProjectName = "Grace"

project(ProjectName)
language("C++")
kind("WindowedApp")
flags({"StaticRuntime", "WinMain"})
files({FromRoot(PathToSrc) .. "AppConfig.h",
       FromRoot(PathToSrc) .. "Metronome.*",
       FromRoot(PathToSrc) .. "Syntax.*",
       FromRoot(PathToSrc) .. "CmSupport.*",
       FromRoot(PathToSrc) .. "Console.*",
       FromRoot(PathToSrc) .. "Scheme.*",
       FromRoot(PathToSrc) .. "Preferences.*",
       FromRoot(PathToSrc) .. "SchemeSources.*",
       FromRoot(PathToSrc) .. "Midi.*",
       FromRoot(PathToSrc) .. "OpenSoundControl.*",
       FromRoot(PathToSrc) .. "Csound.*",
       FromRoot(PathToSrc) .. "Main.*",
       FromRoot(PathToSrc) .. "Resources.*",
       FromRoot(PathToSrc) .. "SndLib.*",
       FromRoot(PathToSrc) .. "SndLibBridge.*",
       FromRoot(PathToSrc) .. "Instruments.*",
       FromRoot(PathToSrc) .. "Fonts.*",
       FromRoot(PathToSrc) .. "Help.*",
       FromRoot(PathToSrc) .. "Commands.*",
       FromRoot(PathToSrc) .. "CodeEditor.*",
       FromRoot(PathToSrc) .. "Documentation.*",
       FromRoot(PathToSrc) .. "Audio.*",
       FromRoot(PathToSrc) .. "AudioFilePlayer.*",
       FromRoot(PathToSrc) .. "MidiFilePlayer.*",
       FromRoot(PathToSrc) .. "Cells.*",
       FromRoot(PathToSrc) .. "Plot.*",
       FromRoot(PathToSrc) .. "PlotEditor.*",
       FromRoot(PathToSrc) .. "PlotWindow.*" })

defines(JUCEDefines)
defines({"HAVE_SCHEME=1"})

if (MacAppStore) then
   defines({"MACAPPSTORE=1"})
   files( FromRoot(PathToRes) .. "app/Info.plist")
   files( FromRoot(PathToRes) .. "app/Grace.icns")
end

includedirs({FromRoot(PathToSrc),
             FromRoot(PathToJUCE),
             FromRoot(PathToSndlib)})
libdirs({PathToLib, FromRoot(PathToSndlibLib)})
objdir(FromRoot(PathToObj) .. ProjectName)
targetdir(FromRoot(PathToBin))

--links({"c++", "juce", "sndlib"})
links({ "juce", "sndlib"})

if _OPTIONS["with-oscpack"] then
   defines({"WITH_OSCPACK"})
   includedirs({FromRoot(PathToOscPack)})
   files({FromRoot(PathToSrc) .. "OscPack.*"})
   links({"oscpack"})
end

if _OPTIONS["with-fomus"] then
   -- if no path given, default to standard directory for OS
   if (_OPTIONS["with-fomus"] == "") then
      if (WINDOWS) then
         _OPTIONS["with-fomus"] = "/usr/local/"
      else
         _OPTIONS["with-fomus"] = "/usr/local/"
   end
end

   fomus = insure_slash(_OPTIONS["with-fomus"])
   if not file_exists(fomus .. "include/fomus.h") then
      error("\nBuild option --with-fomus=" .. fomus ..
            " is incorrect: the file " .. fomus .. "include/fomus.h does not exist.")
   end
   includedirs({fomus .. "include"})
   files({"src/Fomus.cpp", "src/Fomus.h"})
   defines({"WITH_FOMUS"})
   defines({"FOMUSLIBPATH=\\\"" .. fomus .. "lib\\\""})
   libdirs({fomus .. "lib"})
   --linkoptions({"-v"})
end

if _OPTIONS["with-sdif"] then
   sdif = insure_slash(_OPTIONS["with-sdif"])
   if not file_exists(sdif .. "include/sdif.h") then
      error("\nBuild option --with-sdif=" .. sdif ..
            " is incorrect: the file " .. sdif .. "include/sdif.h does not exist.")
   end
   includedirs({sdif .. "include"})
   defines({"WITH_SDIF"})
   libdirs({sdif .. "lib"})
   links({"sdif"})
end

-----------------------Configuration Dependent Settings-----------------------

configuration("not windows")
prebuildcommands("res/bin/sndlib.sh")

-- Mac
configuration({"macosx"})
links({"c++"}) -- clang needs explicit link toc++ lib 
linkoptions(MacFrameworks)
buildoptions(MacTarget)
buildoptions(StandardGCCWarnings)
-- if (_ACTION == "gmake") then buildoptions("-Wno-c++11-extensions") end
linkoptions(MacTarget)
--Copy plist and icons
postbuildcommands({"cp res/app/Info.plist bin/" .. ProjectName .. ".app/Contents/Info.plist",
                   "mkdir -p bin/" .. ProjectName ..  ".app/Contents/Resources",
                   "cp res/app/Grace.icns bin/" .. ProjectName .. ".app/Contents/Resources"})

-- Linux
configuration({"linux"})
links({"dl", "pthread", "rt", "X11","GL","GLU","Xinerama",
       "asound","freetype", "Xext"})
if _OPTIONS["with-fomus"] then
   links({"gsl", "gslcblas", "m"}) 
end

-- Windows
configuration({"windows"})
files({FromRoot(PathToRes) .. "app/Grace.rc"})

--Debug and Optimization Configuration
configuration "Debug" flags(DebugFlags) defines("DEBUG")
configuration "Release" flags(ReleaseFlags) defines({"NDEBUG", "_NDEBUG"})
configuration "Speed" flags(SpeedFlags) defines({"NDEBUG", "_NDEBUG"})

if (_ACTION == "clean" or _ACTION == "cleanall") then
   os.remove(FromRoot("oscpack.make"))
   os.rmdir(FromRoot("oscpack.xcodeproj"))
   os.rmdir(FromRoot("Common Music.xcworkspace"))
end
