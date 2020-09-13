--
-- Creates an xcode project in the parent director for building an
-- appstore version of Grace
--

newoption({trigger = "with-fomus", description = "Optionally include fomus"})

_ACTION = "xcode4"

function FromRoot(PathFromRoot)
   --Get the correct relative path from the current location.
   return PathToRoot .. PathFromRoot
end

DebugFlags = {"Symbols", "NoPCH", "NoManifest"}
ReleaseFlags = {"NoPCH", "NoManifest"}
SpeedFlags = {"OptimizeSpeed", "NoPCH", "NoManifest"}
StandardGCCWarnings = {"-Wall"}
MacFrameworks = {"-framework AudioToolbox", "-framework AudioUnit",
                 "-framework Carbon", "-framework Cocoa", "-framework CoreServices",
                 "-framework CoreAudio", "-framework CoreAudioKit", "-framework CoreMidi",
                 "-framework ApplicationServices", "-framework AGL", "-framework QTKit",
                 "-framework IOKit", "-framework QuartzCore", "-framework WebKit",
                 "-framework Accelerate","-framework DiscRecording"} --maybe dont need this one?
MacTarget = "-Wno-c++11-extensions -mmacosx-version-min=10.6"

JUCEDefines = {"JUCE_IOS=0", "AU_LOGGING=0",
               "JUCE_QUICKTIME=0", "JUCE_OPENGL=0", 
               "JUCE_USE_FLAC=1",
               "JUCE_USE_OGGVORBIS=1",
               "JUCE_USE_MP3AUDIOFORMAT=1",
               "JUCE_USE_WINDOWS_MEDIA_FORMAT=1",
               "JUCE_USE_CDBURNER=0", "JUCE_USE_CDREADER=0",
               "JUCE_WEBBROWSER=0", "JUCE_CHECK_MEMORY_LEAKS=0", "JUCE_SUPPORT_CARBON=0"}

PathToRoot = "./"
PathToSrc = "src/"
PathToJUCE =  "juce/"
PathToSndlib = "sndlib/"
PathToSndlibLib = "sndlib/lib/"
PathToOscPack = "oscpack/"
PathToLib = "lib/"
PathToBin = "bin/"
PathToObj = "obj/"
PathToRes = "res/"

solution("Grace")
location("../")  -- project locate in parent dir (eg ../appstore)
targetdir("../build")
objdir("../build")
--targetdir("appstore")
--objdir("appstore")


configurations({"Debug", "Release" , "Speed"})
project("Grace")
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
       FromRoot(PathToSrc) .. "OscPack.*",
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
       FromRoot(PathToSrc) .. "PlotWindow.*",
       FromRoot(PathToRes) .. "app/Info.plist",
       FromRoot(PathToRes) .. "app/Grace.icns"
    })

defines(JUCEDefines)
defines({"HAVE_SCHEME=1"})
defines({"MACAPPSTORE=1"})
defines({"WITH_OSCPACK"})
includedirs({FromRoot(PathToSrc),
             FromRoot(PathToJUCE),
             FromRoot(PathToSndlib),
             FromRoot(PathToOscPack)
          })

libdirs({FromRoot(PathToLib), 
         FromRoot(PathToSndlibLib)
      })

if (_OPTIONS["with-fomus"]) then
   includedirs({"/usr/local/include"})
   libdirs({"/usr/local/lib"})
   files({FromRoot(PathToSrc) .. "Fomus.*"})
   defines({"WITH_FOMUS"})
end

links({"c++", "juce", "sndlib", "oscpack"})
buildoptions(MacTarget)
buildoptions(StandardGCCWarnings)
linkoptions(MacFrameworks)
linkoptions(MacTarget)

configuration "Debug" flags(DebugFlags) defines("DEBUG")
configuration "Release" flags(ReleaseFlags) defines({"NDEBUG", "_NDEBUG"})
configuration "Speed" flags(SpeedFlags) defines({"NDEBUG", "_NDEBUG"})

