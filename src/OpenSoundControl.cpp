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

#include "OpenSoundControl.h"
#include "Scheme.h"
#include "Console.h"
#include "Preferences.h"

juce_ImplementSingleton(OpenSoundControl) ;

OpenSoundControl::OpenSoundControl()
  : available (false),
    traceInput (false),
    traceOutput (false),
    lastOscError (""),
    connection (0)
{
#if defined(WITH_OSCPACK)
  available = true;
#endif
}

//#if !defined(WITH_OSCPACK)
//bool OpenSoundControl::openConnection(int a, juce::String b, int c){return false;}
//bool OpenSoundControl::closeConnection(){return false;}
//#endif

OpenSoundControl::~OpenSoundControl()
{
  if (connection)
    delete connection;
  connection = 0;
}

bool OpenSoundControl::isAvailable()
{
  juce::ScopedLock lock (safetyLock);
  return available;
}

bool OpenSoundControl::isConnected()
{
  juce::ScopedLock lock (safetyLock);
  return (0 != connection);
}

int OpenSoundControl::getConnectedPort(bool output)
{
  juce::ScopedLock lock (safetyLock);
  if (0 == connection)
    return 0;
  return (output) ? connection->outputPort : connection->inputPort;
}

bool OpenSoundControl::isTracingActive(bool output)
{
  juce::ScopedLock lock (safetyLock);
  return (output) ? traceOutput : traceInput;
}

void OpenSoundControl::setTracingActive(bool isActive, bool output)
{
  juce::ScopedLock lock (safetyLock);
  if (output) 
    traceOutput = isActive;
  else
    traceInput = isActive;
}

juce::String OpenSoundControl::getLastOscError()
{
  juce::ScopedLock lock (safetyLock);
  return lastOscError;
}

// This should only be called by scheme thread.
bool OpenSoundControl::sendMessage(juce::String path, s7_pointer message)
{
  if (0 == connection)
  {
    lastOscError = "OSC not open";
    return false;
  }
  if (OscMessageData* d = parseMessage(message, path))
  {
    if (traceOutput)
    {
      juce::String msg = d->toString();
      msg << "\n";
      Console::getInstance()->printOutput(msg);
    }
    bool success = connection->sendMessage(*d);
    delete d;
    return success;
  }
  else 
    return false;
}

// This should only be called by scheme thread.
bool OpenSoundControl::sendBundle(double time, s7_pointer bundle)
{
  if (0 == connection)
  {
    lastOscError = "OSC not open.";
    return false;
  }
  juce::OwnedArray<OscMessageData> data;
  if (parseBundle(bundle, time, data))
  {
    if (traceOutput)
    {
      juce::String msg ("[osc ");
      msg << time;
      for (int i = 0; i < data.size(); i++)
        msg << " " << data[i]->toString();
      msg << "]\n";
      Console::getInstance()->printOutput(msg);
    }
    if (connection->sendBundle(time, data))
      return true;
    else
      return false;
  }
  else
    return false;
}

OpenSoundControl::OscMessageData* OpenSoundControl::parseMessage(s7_pointer pair, juce::String oscPath)
{
  OscMessageData* data = new OscMessageData(oscPath);
  for (s7_pointer p = pair; s7_is_pair(p); p = s7_cdr(p))
  {
    char t = 0;               // message type
    s7_pointer x = s7_car(p); // message data
    if (s7_is_keyword(x))     // keyword == explicit type tag
    {
      juce::String s (s7_symbol_name(x));
      if (s.length() == 2 && juce::String("ifsbhtdScmTFNI").containsChar(s[1]))
      {
        // a few OSC tags have no data
        switch (s[1])
        {
        case OSC_TRUE:
        case OSC_FALSE:
        case OSC_NIL:
        case OSC_INFINITUM:
          data->oscTypes << s[1];
          continue;
        }
        // advance p to start of message data
        p = s7_cdr(p);
        if (s7_is_pair(p))
          x = s7_car(p);
        else
        {
          lastOscError << "incomplete OSC message after " << s;
          delete data;
          return 0;
        }
        t = s[1];
      }
      else
      {
        lastOscError << "invalid OSC type " <<  s;
        delete data;
        return 0;
      }
    }
    // at this point we have data in 'x' and (possibly) an explicit
    // type in 't'. determine t if missing and add array data
    if (s7_is_integer(x))
    {
      juce::int64 i = (juce::int64)s7_integer(x);
      if (0 == t) t = OSC_INT32;
      switch (t)
      {
      case OSC_INT32:
      case OSC_INT64:
      case OSC_TIMETAG:
        data->oscTypes << t;
        data->oscInts.add(i);
        break;
      default:
        lastOscError << "invalid data for OSC type " << t << ": " << juce::String(i);
        delete data;
        return 0;
      }
    }
    else if (s7_is_real(x))
    {
      double d = (double)s7_real(x);
      if (0 == t) t = OSC_FLOAT;
      switch (t)
      {
      case OSC_FLOAT:
      case OSC_DOUBLE:
      case OSC_TIMETAG:
        data->oscTypes << t;
        data->oscFloats.add(d);
        break;
      default:
        lastOscError << "invalid data for OSC type " << t << ": " << d;
        delete data;
        return 0;
      }   
    }
    else if (s7_is_string(x))
    {
      juce::String s (s7_string(x));
      if (0 == t) t = OSC_STRING;
      if (s.isEmpty()) 
      {
        lastOscError << "missing data for OSC type " << t;
        delete data;
        return 0;
      }
      switch (t)
      {
      case OSC_STRING:
      case OSC_SYMBOL:
      case OSC_CHAR:
        data->oscTypes << t;
        data->oscStrings.add(s);
        break;
      default:
        lastOscError << "invalid data for OSC type " << t << ": \"" << s << "\"";
        delete data;
        return 0;
      }
    }
    else if (s7_is_symbol(x))
    {
      juce::String s (s7_symbol_name(x));
      if (0 == t) t = OSC_SYMBOL;
      switch (t)
      {
      case OSC_SYMBOL:
      case OSC_STRING:
        data->oscTypes << t;
        data->oscStrings.add(s);
        break;
      default:
        lastOscError << "invalid data for OSC type " << t << ": \"" << s << "\"";
        delete data;
        return 0;
      }           
    }
    else if (s7_is_character(x))
    {
      juce::String s;
      char c = s7_character(x);
      s << c;
      if (0 == t) t = OSC_CHAR;
      switch (t)
      {
      case OSC_CHAR:
        data->oscTypes << t;
        data->oscStrings.add(s);
        break;
      default:
        lastOscError << "invalid data for OSC type " << t << ": '" << s << "'";
        delete data;
        return 0;
      }
    }
    else if (s7_is_boolean(x))
    {
      if (t != 0) 
      {
        lastOscError << "explicit OSC type " << t << " used with #t or #f";
        delete data;
        return 0;
      }
      else if (x == s7_f(SchemeThread::getInstance()->scheme))
        data->oscTypes << "F";
      else
        data->oscTypes << "T";
    }          
    // list is either midi or blob
    else if (s7_is_pair(x)) 
    {
      if ((OSC_MIDI != t) && (OSC_BLOB != t))
      {
        lastOscError = "invalid OSC data: list without midi or blob tag";
        delete data;
        return 0;
      }
      s7_scheme *sc = SchemeThread::getInstance()->scheme;
      int siz = s7_list_length(sc, x);
      if (0 == siz)
      {
        lastOscError = "invalid OSC data: empty list";        
        delete data;
        return 0;
      }
      if ((OSC_MIDI == t) && (siz != 4))
      {
        lastOscError = "invalid OSC data: midi list is not 4 bytes";
        delete data;
        return 0;
      }
      data->oscTypes << t;
      data->oscInts.add(siz); // first position stores length of data
      for (s7_pointer m = x; s7_is_pair(m); m = s7_cdr(m))
      {
        if (s7_is_integer(s7_car(m)))
          data->oscInts.add( (juce::int64)(s7_integer(s7_car(m)) & 0xFF));
        else 
        {
          lastOscError << "invalid OSC data: midi list contains non-integer";
          delete data;
          return 0;
        }
      }
    }
    else
    {
      lastOscError = "unparseable OSC message";
      delete data;
      return 0;
    }
  }
  return data;
}

bool OpenSoundControl::parseBundle(s7_pointer list, double ahead, juce::OwnedArray<OscMessageData>& data)
{
  for (s7_pointer p = list; s7_is_pair(p); p = s7_cdr(p))
  {
    s7_pointer x = s7_car(p);
    if (s7_is_pair(x) && s7_is_string(s7_car(x)))
    {
      juce::String path ((char*)s7_string(s7_car(x)));
      s7_pointer list = s7_cdr(x); // possibly empty
      if (OscMessageData* d = parseMessage(list, path))
      {
        //        std::cout << "adding data: " << d->toString() <<"\n";
        data.add(d);
      }
      else
        return false;
    }
    else
    {
      lastOscError = "bundle value is not an OSC message";
      return false;
    }
  }
  //  std::cout << "OpenSoundControl::parseBundle, bundle size=" << data.size() << "\n";
  return true;
}

/* ==============================================================================
   OSC Connection Dialog
   =============================================================================*/

class OscConnectionDialog : public juce::Component, 
                            public juce::ButtonListener,
                            public juce::TextEditorListener
{
public:
  OscConnectionDialog ()
  : serverGroup (0),
    targetGroup (0),
    openButton (0),
    serverPortLabel (0),
    targetHostLabel (0),
    targetPortLabel (0),
    serverProtocolLabel (0),
    serverPortEditor (0),
    serverProtocolEditor (0),
    targetHostEditor (0),
    targetPortEditor (0)
  {
    OpenSoundControl* osc = OpenSoundControl::getInstance();
    bool isOpen = osc->isConnected();
    bool enable = !isOpen;
    juce::Colour tcolor = (isOpen) ? juce::Colours::grey : juce::Colours::black;

    addAndMakeVisible(serverGroup = new juce::GroupComponent("", "Input Connection"));
    addAndMakeVisible(targetGroup = new juce::GroupComponent("", "Output Connection"));
  
    addAndMakeVisible(serverProtocolLabel = new juce::Label("", "Protocol:"));
    serverProtocolLabel->setFont (juce::Font (15.0f, juce::Font::plain));
    serverProtocolLabel->setJustificationType (juce::Justification::centredLeft);
    serverProtocolLabel->setEditable(false, false, false);
    serverProtocolLabel->setEnabled(false);
  
    addAndMakeVisible(serverProtocolEditor = new juce::TextEditor());
    serverProtocolEditor->setMultiLine(false);
    serverProtocolEditor->setReturnKeyStartsNewLine(false);
    serverProtocolEditor->setReadOnly(true);
    serverProtocolEditor->setScrollbarsShown(true);
    serverProtocolEditor->setCaretVisible(true);
    serverProtocolEditor->setPopupMenuEnabled(false );
    serverProtocolEditor->setSelectAllWhenFocused(false );
    serverProtocolEditor->setColour(juce::TextEditor::textColourId, juce::Colours::grey);
    serverProtocolEditor->setText("UDP");
    serverProtocolEditor->setEnabled(false);
    serverProtocolEditor->setReadOnly(true);
 
    addAndMakeVisible(serverPortLabel = new juce::Label("", "Port:"));
    serverPortLabel->setFont(juce::Font (15.0000f, juce::Font::plain));
    serverPortLabel->setJustificationType(juce::Justification::centredLeft);
    serverPortLabel->setEditable(false, false, false);
    serverPortLabel->setEnabled(enable);

    addAndMakeVisible(serverPortEditor = new juce::TextEditor());
    serverPortEditor->setMultiLine(false);
    serverPortEditor->setReturnKeyStartsNewLine(false);
    serverPortEditor->setReadOnly(false);
    serverPortEditor->setScrollbarsShown(true);
    serverPortEditor->setCaretVisible(true);
    serverPortEditor->setPopupMenuEnabled(true);
    // if open use existing input port else use preference
    int port = (isOpen) ? osc->getConnectedPort(false)
      : Preferences::getInstance()->getIntProp("OscServerPort", 7779);
    serverPortEditor->setColour(juce::TextEditor::textColourId, tcolor);
    serverPortEditor->setText(juce::String(port));
    serverPortEditor->setEnabled(!isOpen);

    addAndMakeVisible(targetHostLabel = new juce::Label("", "Host:"));
    targetHostLabel->setFont(juce::Font(15.0000f, juce::Font::plain));
    targetHostLabel->setJustificationType(juce::Justification::centredLeft);
    targetHostLabel->setEditable(false, false, false);
    targetHostLabel->setEnabled(!isOpen);

    addAndMakeVisible(targetHostEditor = new juce::TextEditor());
    targetHostEditor->setMultiLine(false);
    targetHostEditor->setReturnKeyStartsNewLine(false);
    targetHostEditor->setReadOnly(false);
    targetHostEditor->setScrollbarsShown(true);
    targetHostEditor->setCaretVisible(true);
    targetHostEditor->setPopupMenuEnabled(true);
    juce::String host = Preferences::getInstance()->getStringProp("OscTargetHost", "localhost");
    targetHostEditor->setColour(juce::TextEditor::textColourId, tcolor);
    targetHostEditor->setText(host);
    targetHostEditor->setEnabled(!isOpen);
    targetHostEditor->setCaretPosition(0);
    
    addAndMakeVisible(targetPortLabel = new juce::Label("", "Port:"));
    targetPortLabel->setFont(juce::Font(15.0f, juce::Font::plain));
    targetPortLabel->setJustificationType(juce::Justification::centredLeft);
    targetPortLabel->setEditable(false, false, false);
    targetPortLabel->setEnabled(!isOpen);
  
    addAndMakeVisible (targetPortEditor = new juce::TextEditor());
    targetPortEditor->setMultiLine(false);
    targetPortEditor->setReturnKeyStartsNewLine (false);
    targetPortEditor->setReadOnly(false);
    targetPortEditor->setScrollbarsShown(true);
    targetPortEditor->setCaretVisible(true);
    targetPortEditor->setPopupMenuEnabled(true);
    // if open use existing output port else use preference
    port = (isOpen) ? osc->getConnectedPort(true)
      : Preferences::getInstance()->getIntProp("OscTargetPort", 57120);
    targetPortEditor->setColour(juce::TextEditor::textColourId, tcolor);
    targetPortEditor->setText(juce::String(port));
    targetPortEditor->setEnabled(!isOpen);
  
    addAndMakeVisible(openButton = new juce::TextButton());
    openButton->setButtonText(isOpen ? "Close" : "Open");
    openButton->addListener(this);
    serverPortEditor->addListener(this);
    targetHostEditor->addListener(this);
    targetPortEditor->addListener(this);
    setSize (392, 144);
  }

  ~OscConnectionDialog()
  {
    deleteAllChildren();
  }

private:
  juce::GroupComponent* serverGroup;
  juce::GroupComponent* targetGroup;
  juce::TextButton* openButton;
  juce::Label* serverPortLabel;
  juce::Label* targetHostLabel;
  juce::Label* targetPortLabel;
  juce::Label* serverProtocolLabel;
  juce::TextEditor* serverPortEditor;
  juce::TextEditor* serverProtocolEditor;
  juce::TextEditor* targetHostEditor;
  juce::TextEditor* targetPortEditor;

  void resized()
  {
    serverGroup->setBounds (8, 8, 184, 96);
    targetGroup->setBounds (199, 8, 185, 96);
    openButton->setBounds (152, 112, 96, 24);
    serverPortLabel->setBounds (16, 64, 48, 24);
    targetHostLabel->setBounds (207, 32, 56, 24);
    targetPortLabel->setBounds (207, 64, 48, 24);
    serverProtocolLabel->setBounds (16, 32, 64, 24);
    serverPortEditor->setBounds (88, 64, 88, 24);
    serverProtocolEditor->setBounds (88, 32, 88, 24);
    targetHostEditor->setBounds (256, 32, 112, 24);
    targetPortEditor->setBounds (256, 64, 88, 24);
  }

  void textEditorReturnKeyPressed(juce::TextEditor& editor)
  {
    openButton->triggerClick();
  }
  
  void buttonClicked (juce::Button* buttonThatWasClicked)
  {
    bool ok = true;
    if (buttonThatWasClicked == openButton && openButton->getButtonText() == "Close")
    {
      ok = OpenSoundControl::getInstance()->closeConnection();
      if (ok)
      {
        if (juce::Component* c = juce::Component::getCurrentlyModalComponent())
        {
          c->exitModalState(1);
        }
      }
      else
      {
        juce::String err (">>> Error: ");
        err << OpenSoundControl::getInstance()->getLastOscError() << "\n";
        Console::getInstance()->printError(err);
      }
    }
    else if (buttonThatWasClicked == openButton && openButton->getButtonText() == "Open")
    {
      juce::String sp = serverPortEditor->getText().trim();
      juce::String th = targetHostEditor->getText().trim();
      juce::String tp = targetPortEditor->getText().trim();
      juce::Range<int> rn (0, 10000);
      if (!isValidPortString(sp))
      {
        serverPortEditor->grabKeyboardFocus();
        serverPortEditor->setHighlightedRegion(rn);
        ok = false;
      }
      else if (!isValidHostString(th))
      {
        if (th.isEmpty())            
        {
          th = "localhost";
          targetHostEditor->setText(th);
          targetHostEditor->setHighlightedRegion(rn);
        }
        else
        {
          targetHostEditor->grabKeyboardFocus();
          targetHostEditor->setHighlightedRegion(rn);
          ok = false;
        }
      }
      else if (!isValidPortString(tp))
      {
        targetPortEditor->grabKeyboardFocus();
        targetPortEditor->setHighlightedRegion(rn);
        ok = false;
      }
      if (ok)
      {
        ok = OpenSoundControl::getInstance()->openConnection(sp.getIntValue(), th, tp.getIntValue());
        if (!ok)
        {
          juce::String err (">>> Error: ");
          err << OpenSoundControl::getInstance()->getLastOscError() << "\n";
          Console::getInstance()->printError(err);
        }
        else
        {
          if (juce::Component* c = juce::Component::getCurrentlyModalComponent())
          {
            c->exitModalState(1);
          }
        }
      }
    }
  }

  bool isValidPortString(juce::String text)
  {
    if (text.isNotEmpty() && text.containsOnly("012345679"))
      return (text.getIntValue() > 0);
    else
      return false;
  }

  bool isValidHostString(juce::String text)
  {
    if (text.isEmpty())
      return false;
    if (text.containsOnly(".0123456789"))
    {
      if (text.matchesWildcard("*.*.*.*", true))
        return true;
      else
        return false;
    }
    else if (text.containsOnly("0123456789AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz.-"))
      return true;
    else
      return false;
  }
};

void OpenSoundControl::openConnectionDialog()
{
  OscConnectionDialog* comp = new OscConnectionDialog();
  juce::DialogWindow::LaunchOptions dw;
  dw.useNativeTitleBar = true;
  dw.resizable = false;
  dw.dialogTitle = "OSC Connections";
  dw.dialogBackgroundColour = ColorThemeIDs::getWindowBackgroundColor();
  dw.content.setOwned(comp);
  dw.runModal();
}
