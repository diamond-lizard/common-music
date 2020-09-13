/*
  ==============================================================================

  Copyright 1999-2013 Rick Taube.  All rights reserved.

  Licensed under the "Attribution-NonCommercial-ShareAlike" Vizsage
  Public License, which says that non-commercial users may share and
  modify this code but must give credit and share improvements. For
  complete terms please read the text of the full license available at
  this link: http://vizsage.com/license/Vizsage-License-BY-NC-SA.html

  ==============================================================================
*/

#ifndef CM_OPENSOUNDCONTROL_H
#define CM_OPENSOUNDCONTROL_H

#include "Libraries.h"

class OpenSoundControl
{

public:
  enum {
    OSC_INT32 =     'i',	/// 32 bit signed integer.
    OSC_FLOAT =     'f',	/// 32 bit IEEE-754 float.
    OSC_STRING =    's',	/// Standard C, NULL terminated string.
    OSC_BLOB =      'b',	/// OSC binary blob type. 
    OSC_INT64 =     'h',	/// 64 bit signed integer.
    OSC_TIMETAG =   't',	/// OSC TimeTag type.
    OSC_DOUBLE =    'd',	/// 64 bit IEEE-754 double.
    OSC_SYMBOL =    'S',        /// OSC symbol
    OSC_CHAR =      'c',	/// Standard C, 8 bit, char variable.
    OSC_MIDI =      'm',	/// A 4 byte MIDI packet.
    OSC_TRUE =      'T',	/// OSC value True.
    OSC_FALSE =     'F',	/// OSC value False.
    OSC_NIL =       'N',	/// OSC value Nil.
    OSC_INFINITUM = 'I'	        /// OSC value Infinitum.
  };

  struct OscMessageData
  {
    ///The message path
    juce::String oscPath;
    ///Left to right Sequence of message's osc types. Some types hold
    ///associated data in the arrays. For midi and blob types the
    ///first value stored is always the length of the data
    juce::String oscTypes;
    ///Stores data for osc types 'sSc'
    juce::StringArray oscStrings;
    ///Stores data for osc types 'iIbm'
    juce::Array<juce::int64> oscInts;
    ///Stores data for osc types 'fdT'
    juce::Array<double> oscFloats;

    OscMessageData(juce::String path, juce::String types = "")
      : oscPath(path),
        oscTypes(types)
    {
    }

    ~OscMessageData()
    {
      oscStrings.clear();
      oscInts.clear();
      oscFloats.clear();
    }

    /**Convert data to string for input and output tracing.*/
    juce::String toString()
    {
      int S = 0, I = 0, F = 0;
      juce::String T;
      T << "[osc '" << oscPath << "'";
      for(int i = 0; i < oscTypes.length(); i++)
      {
        char c = oscTypes[i];
        switch (c)
        {
        case OSC_TRUE:
        case OSC_FALSE:
        case OSC_NIL:
        case OSC_INFINITUM:
          T << " [" << c << "]";
          break;
        case OSC_INT32:
        case OSC_INT64:
          T << " [" << c << " " << oscInts[I++] << "]";
          break;
        case OSC_FLOAT:
        case OSC_DOUBLE:
        case OSC_TIMETAG:
          T << " [" << c << " " << oscFloats[F++] << "]";
          break;
        case OSC_STRING:
        case OSC_SYMBOL:
        case OSC_CHAR:
          T << " [" << c << " '" << oscStrings[S++] << "']";
          break;
        case OSC_BLOB:
        case OSC_MIDI:
          {
            T << " [" << c;
            int s = (int)oscInts[I++];
            for (int j = 0; j < s ; j++)
            {
              T << " " << oscInts[I++];
            }          
            T << "]";
          }
          break;
        }
      }
      T << "]";
      return T;
    }

    /**Convert ahead factor to absolute OSC time tag.*/
    static juce::uint64 toTimeTag(double ahead)
    {
      // osc's immediate time tag is 1
      if (ahead == 0.0)
        return 0x0000000000000001;
      // juce timer based on 1970 not 1900 this is difference in secs
      static const juce::uint64 JAN_1_1970 = 0x83aa7e80;
      // absolute ahead time in msecs
      juce::uint64 when = (juce::uint64)(juce::Time::currentTimeMillis() + ((juce::int64)(ahead * 1000)));
      // number of secs
      juce::uint64 secs = when / 1000;
      // fractional remainder in msecs
      juce::uint64 frac = when - (secs * 1000);
      // add in differnce
      secs += JAN_1_1970;
      // osc time tag: upper holds secs lower holds fractional msecs
      return (((secs & 0xFFFFFFFF) << 32) | (frac & 0xFFFFFFFF));
    }
  };

  /**Each OSC implementation (OscPack or Liblo) must subclass
     Connection and also implement the
     OpenSoundControl::openConnection and
     OpenSoundControl::closeConnection methods below.*/
  struct Connection
  {
    OpenSoundControl* osc;
    int inputPort;
    juce::String outputHost;
    int outputPort;
    
    Connection(OpenSoundControl* osc, int inputPort, juce::String outputHost, int outputPort)
      : osc(osc),
        inputPort(inputPort),
        outputHost(outputHost),
        outputPort(outputPort)
    {
    }
    virtual ~Connection() {}
    virtual bool sendMessage(OscMessageData& data) {return false;}
    virtual bool sendBundle(double time, juce::OwnedArray<OscMessageData>& bund) {return false;}
  };

private:
  juce::CriticalSection safetyLock;
  bool available;
  bool traceInput;
  bool traceOutput;
  juce::String lastOscError;
  Connection* connection;

public:
  ///Constuctor
  OpenSoundControl();

  ///Destructor
  ~OpenSoundControl();

  /**Returns true if OSC is avaiable else false.*/
  bool isAvailable();

  /**Returns true if an OSC connection is open else false.*/
  bool isConnected();

  /**Returns the open port number for input or output port, or 0 if
     its not open.*/
  int getConnectedPort(bool output);

  /**Returns the string associated with the last osc error.*/
  juce::String getLastOscError();

  /**Returns true if tracing is active for input or output port.*/
  bool isTracingActive(bool output);

  /**Sets tracing active or inactive for input or output port.*/
  void setTracingActive(bool isActive, bool output);

  /**Called by Scheme thread to send a message.*/
  bool sendMessage(juce::String path, s7_pointer message);

  /**Called by Scheme thread to send a bundle.*/
  bool sendBundle(double time, s7_pointer bundle);

  /**Parse a Scheme osc message into arrays of OSC data. Returns
     pointer to data if successful else null. If parsing fails then
     lastOscError will hold the error string.*/
  OscMessageData* parseMessage(s7_pointer list, juce::String path);

  /**Parse a scheme osc bundle and fills array with message
     data. Returns true if successful.*/
  bool parseBundle(s7_pointer list, double ahead, juce::OwnedArray<OscMessageData>& data);

  /**Opens an Osc connection. This method must be defined by each Osc
     implemention. Returns true if connection was opened else
     false. If opening was not successful then lastOscError holds the
     error message. If opening was successful then the connection is
     set and preferences updated.*/
  bool openConnection(int inputPort, juce::String outputHost, int outputPort)
#if defined(WITH_OSCPACK)
  ;
#else
  {return false;}
#endif

  /**Closes an Osc connection. This method must be defined by each Osc
     implementation. Returns true if connection was closed else
     false. If closing was not successful then lastOscError
     holds the error messsage. If closing was scuccessful then current
     connection should be deleted and zerored.*/
  bool closeConnection()
#if defined(WITH_OSCPACK)
    ;
#else 
  {return false;}
#endif

  /**Opens the OSC Connections dialog.*/
  static void openConnectionDialog();

  juce_DeclareSingleton(OpenSoundControl, true)
};

#endif
