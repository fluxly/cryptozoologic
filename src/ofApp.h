//  iOS version of Fluxly, the musical physics looper
//
//  Created by Shawn Wallace on 11/14/17.
//  Released April 2018 to the App Store
//  See the LICENSE file for copyright information

#pragma once

#include "ofxiOS.h"
#include "controlThread.h"
#include "ABiOSSoundStream.h"
#include "ofxBox2d.h"
#include "FluxlyClasses.h"
#include "PdExternals.h"
#include "ofxPd.h"
#include "ofxMidi.h"
#include "ofxXmlSettings.h"

#define IOS
//#define ANDROID

//#define FLUXLY_FREE (0)
#define FLUXLY_STANDARD (1)
//#define FLUXLY_PRO (2)

#define FLUXLY_MAJOR_VERSION (1)
#define FLUXLY_MINOR_VERSION (0)

//  Determine device
#define IS_IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#define IS_IPHONE (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
#define IS_IPHONE_5 (IS_IPHONE && [[UIScreen mainScreen] bounds].size.height == 568)
#define IS_IPHONE_6 (IS_IPHONE && [[UIScreen mainScreen] bounds].size.height == 667)
#define IS_IPHONE_6_PLUS (IS_IPHONE && [[UIScreen mainScreen] bounds].size.height == 736)
#define IS_IPHONE_X (IS_IPHONE && [[UIScreen mainScreen] bounds].size.height == 812)

// Defines for translating iPhone positioning to iPad
// 480 point wide -> 1024 points wide
// = 2.13 multiplier
#define IPAD_BOT_TRIM (45)

// States
#define PAUSE (0)
#define RUN (1)
#define CHOOSE_LOOP (2)

// Scenes
#define SPLASHSCREEN (0)
#define MENU_SCENE (1)
#define GAME_SCENE (2)
#define RECORDING_SCENE (3)
#define SAVE_EXIT_PART_1 (4)
#define SAVE_EXIT_PART_2 (5)
#define SELECT_SAMPLE_SCENE (6)

#define PHONE (0)
#define TABLET (1)

#define ONE_SECOND (60)
#define TWO_SECONDS (120)
#define THREE_SECONDS (180)
#define FOUR_SECONDS (240)

#define maxSamples (144)

#define MAIN_MENU (0)
#define SAMPLE_MENU (1)

#define maxTouches (11)
#define nScenes (6)

#define SCENES_IN_BUNDLE (3)
#define SAMPLES_IN_BUNDLE (15)

// Controls
#define EXIT_GAME (0)
#define DAMPEN (1)
#define HELP_GAME (2)
#define HELP_SAMPLE_SELECT (3)
#define EXIT_SAMPLE_SELECT (4)
#define PLAY_BUTTON (5)
#define REC_BUTTON (6)

#define PHONE_FONT_SIZE (12)
#define TABLET_FONT_SIZE (24)
#define PHONE_RETINA_FONT_SIZE (24)
#define TABLET_RETINA_FONT_SIZE (48)

// a namespace for the Pd types
using namespace pd;

class BoxData {
public:
    int boxId;
};

class FluxlyConnection {
public:
    int id1;
    int id2;
};

class FluxlyJointConnection {
public:
    int id1;
    int id2;
    ofxBox2dJoint *joint;
};

class FluxlyHint {
public:
    int hintX;
    int hintY;
    int timer;
    string hintText;
    vector <shared_ptr<FluxlyHint> >  showCircles;
};


class ofApp : public ofxiOSApp, public PdReceiver, public PdMidiReceiver,
              public ofxMidiListener, public ofxMidiConnectionListener{
	
  public:
        void setup();
        void setupPostSplashscreen();
        void update();
        void draw();
        void drawVisualization(int gameId);
        void exit();
	         
        void loadMenu();
        void loadGame(int gameId);
        void loadGameSettings();
        void saveGame();
    
        void touchDown(ofTouchEventArgs & touch);
        void touchMoved(ofTouchEventArgs & touch);
        void touchUp(ofTouchEventArgs & touch);
        void touchDoubleTap(ofTouchEventArgs & touch);
        void touchCancelled(ofTouchEventArgs & touch);
        void lostFocus();
        void gotFocus();
        void gotMemoryWarning();
        void deviceOrientationChanged(int newOrientation);
    
        void setupAudioStream();
        ABiOSSoundStream* stream;
        ABiOSSoundStream* getSoundStream();
        controlThread myControlThread;
    
        // midi message callback
        void newMidiMessage(ofxMidiMessage& msg);
       
        void receiveBang(const std::string& dest);
                  
        // midi device (dis)connection event callbacks
        void midiInputAdded(string name, bool isNetwork);
        void midiInputRemoved(string name, bool isNetwork);
        vector<ofxMidiIn*> inputs;
                  
        void reloadSamples();
        void takeScreenshot();
        void contactStart(ofxBox2dContactArgs &e);
        void contactEnd(ofxBox2dContactArgs &e);

        void destroyGame();
        void toggleHelpBubbles();
        void helpLayerScript();
        void helpLayerDisplay();
        void drawHelpString(string s, int x1, int y1, int yOffset, int row);
    
        bool controlInBounds(int i, int x1, int y1);
        bool notConnectedYet(int n1, int n2);
        bool complementaryColors(int n1, int n2);
        bool bothTouched(int n1, int n2);
        bool drawForScreenshot = false;
        bool doubleTapped = false;
    
    string errorMsg;
    
    ofxPd pd;
    ofxXmlSettings globalSettings;
    ofxXmlSettings sampleList;
    
    vector<Patch> instances;
    
    // audio callbacks
    void audioReceived(float * input, int bufferSize, int nChannels);
    void audioRequested(float * output, int bufferSize, int nChannels);
    
    // sets the preferred sample rate, returns the *actual* samplerate
    // which may be different ie. iPhone 6S only wants 48k
    float setAVSessionSampleRate(float preferredSampleRate);
    
    Boolean instrumentIsOff();
    
    int startTouchId = 0;
    int startTouchX = 0;
    int startTouchY = 0;
    int hintTimer = 0;
    int currentHintState = -1;
    int hintsSeen = 0;
    bool hintOn = false;
    bool totallySetUp = false;
    
    int timeInGame = 0;
                  
    float volume;
    Boolean instrumentOn;
    
    int device = PHONE;
    float deviceScale = 1.0;
    int nIcons = 6;
    int nCircles;
    int scene = SPLASHSCREEN;;
    int gameState = 0;
    bool firstRun = true;
    bool helpOn = true;
    bool helpOn2 = true;
    bool helpWasOn = false;
                  
    int selected = -1;
    int midiChan;
    int tempo = 1;
    
    int controls[5];
    int controlX[5];
    int controlY[5];
    int controlW[5];
    int controlHalfW[5];
    
    int X_OFFSET;
    int Y_OFFSET;
    float retinaScaling = 1.0;
    
    /*int HITSPOT_X;
    int HITSPOT_Y;
    int HITSPOT_W;
    float SCALING;
    int IPAD_MARGIN;*/
    
    float backgroundX = 0;
    float prevBackgroundX = 0;
    float backgroundY = 0;
    int menuScreen = 0;
    int menuOrigin = 0;

    //The iPhone supports 5 simultaneous touches, and cancels them all on the 6th touch.
    //Current iPad models (through Air 2) support 11 simultaneous touches, and do nothing on a 12th
    //iPad Pro has 17?
    
    int touchX[maxTouches] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    int touchY[maxTouches] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    int touchControl[maxTouches] = {-1, -1,-1,-1,-1,-1,-1,-1,-1,-1,-1};
                  
    ofDirectory dir;
    ofFile file;
    string documentsDir;
    int numFiles;
    int currentGame = -1;   // index in menu
    
    int touchMargin = 2;
    
    ofTrueTypeFont helpFont;
    string eventString;
    
    int worldW = 320;
    int worldH = 568;
    int screenW = 320;
    int screenH = 568;
    int toolbarH = 30;
    int consoleH = 200;
    int appIconX;
    int appIconY;
    int appIconW = 90;
    int helpTextHeight;
    
    int iconW = 65;
    int menuItemsPerRow = 3;
    
    int globalTick = 0;
    int tempId1;
    int tempId2;
    int maxJoints = 3;
    int backgroundId = 0;
    bool applyDamping = true;
    
    ofImage background[8];
    ofImage foreground;
    ofImage pauseMotion;
    ofImage screenshot;
    ofImage exitButton;
    ofImage dampOnOff;
    ofImage dampOnOffGlow;
    ofImage saving;
    ofImage helpButton;
    ofImage helpButtonGlow;
    ofImage arrow;
    ofImage arrowLeft;
    ofImage icon;
                  
    ofxBox2d box2d;
    
    SlidingMenu * mainMenu;
    SlidingMenu * sampleMenu;
    SampleConsole * playRecordConsole;
    
    vector <shared_ptr<FluxlyCircle> > circles;
    vector <shared_ptr<FluxlyBubble> > bubbles;
    vector <shared_ptr<FluxlyJointConnection> > joints;
    vector <shared_ptr<FluxlyConnection> > connections;
    vector <shared_ptr<ofxBox2dEdge> >  edges;
    vector <shared_ptr<FluxlyHint> >  hints;
                  
    vector<float> backgroundScopeArray{0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0};
    vector<float> backgroundScopeArray1;
    vector<float> backgroundScopeArray2;
    vector<float> backgroundScopeArray3;
    vector<float> game3Scopes[11];
                  
    bool midiSaveState[8] = { false, false, false, false, false, false, false, false };
    bool midiPlayState[8] = { false, false, false, false, false, false, false, false };
    int midiSavedAngularVelocity[8] = { 1, 1, 1, 1, 1, 1, 1, 1 };
                  
    int midiSaveKeys[8] = { 48, 50, 52, 53, 55, 57, 59, 60 };
    int midiPlayKeys[8] = { 60, 62, 64, 65, 67, 69, 71, 72 };
                  
    float game2ledX[5] = { 267, 405, 543, 682, 904 };
    //float game2ledX[5] = { 133.5, 202.5, 271.5, 341 };
    int game2Steps[4] = {8, 8, 8, 8 };
    int game2Pulses[4] = { 4, 4, 4, 4 };
    int currentPulse[4] = { 0, 0, 0, 0 };
    int currentPulseOn[4] = { 0, 0, 0, 0 };
                  
    ofImage toolbar;
    
    Patch currentPatch;
                  
    ofRectangle bounds;
                  
    const char *noChar = "no";
                  
    string formulaStr[94] = {
        "t&(t>>4)>>3&t>>7",
        "(((((t>>12)^(t>>12)-2)%11*t)/4|t>>13)&127)",
        "((t*(36364689[t>>13&7]&15))/12&128)",
        "(t>>5)|(t>>4)|((t%42)*(t>>4)|(0x15483113)-(t>>4))/(t>>16)^(t|(t>>4))",
        "((t*5/53)|t*5+(t<<1))",
        "(t<65536)?((2*t*(t>>11)&(t-1)|(t>>4)-1)%64):(((t%98304)>65536)?((17*t*(t*t>>8)&(t-1)|(t>>7)-1)%128|(t>>4)):((13*t*(2*t>>16)&(t-1)|(t>>8)-1)%32|(t>>4)))",
        "t>>16|((t>>4)%16)|((t>>4)%192)|(t*t%64)|(t*t%96)|(t>>16)*(t|t>>5)",
        "t>>6^t&37|t+(t^t>>11)-t*((t%24?2:6)&t>>11)^t<<1&(t&598?t>>4:t>>10)",
        "((t/2*(15&(0x234568a0>>(t>>8&28))))|t/2>>(t>>11)^t>>12)+(t/16&t&24)",
        "(t<65536)?((2*t*(t>>11)&(t-1)|(t>>4)-1)%64):(((t%98304)>65536)?((17*t*(2*t>>8)&(t-1)|(t>>6)-1)%64|(t>>4)):((15*t*(2*t>>16)&(t-1)|(t>>8)-1)%64|(t>>4)))",
        "((t>>4)*(13&(0x8898a989>>(t>>11&30)))&255)+((((t>>9|(t>>2)|t>>8)*10+4*((t>>2)&t>>15|t>>8))&255)>>1)",
        "t*(((t>>12)|(t>>8))&(63&(t>>4)))",
        "(t*(t>>5|t>>8))>>(t>>16)",
        "t*(((t>>9)|(t>>13))&(25&(t>>6)))",
        "t*(((t>>11)&(t>>8))&(123&(t>>3)))",
        "t*(t>>8*((t>>15)|(t>>8))&(20|(t>>19)*5>>t|(t>>3)))",
        "(t*t/256)&(t>>((t/1024)%16))^t%64*(0xC0D3DE4D69>>(t>>9&30)&t%32)*t>>18",
        "t*(t>>((t>>9)|(t>>8))&(63&(t>>4)))",
        "(t>>6|t|t>>(t>>16))*10+((t>>11)&7)",
        "(t%25-(t>>2|t*15|t%227)-t>>3)|((t>>5)&(t<<5)*1663|(t>>3)%1544)/(t%17|t%2048)",
        "(t|(t>>9|t>>7))*t&(t>>11|t>>9)",
        "t*5&(t>>7)|t*3&(t*4>>10)",
        "(t>>7|t|t>>6)*10+4*(t&t>>13|t>>6)",
        "((t&4096)?((t*(t^t%255)|(t>>4))>>1):(t>>3)|((t&8192)?t<<2:t))",
        "((t*(t>>8|t>>9)&46&t>>8))^(t&t>>13|t>>6)",
        "(t*5&t>>7)|(t*3&t>>10)",
        "(int)(t/1e7*t*t+t)%127|t>>4|t>>5|t%127+(t>>16)|t",
        "((t/2*(15&(0x234568a0>>(t>>8&28))))|t/2>>(t>>11)^t>>12)+(t/16&t&24)",
        "(t&t%255)-(t*3&t>>13&t>>6)",
        "(t&t%255)-(t*3&t>>13&t>>6)",
        "((t*(36364689[t>>13&7]&15))/12&128)+(((((t>>12)^(t>>12)-2)%11*t)/4|t>>13)&127)",
        "(t*9&t>>4|t*5&t>>7|t*3&t/1024)",
        "((t*(t>>12)&(201*t/100)&(199*t/100))&(t*(t>>14)&(t*301/100)&(t*399/100)))+((t*(t>>16)&(t*202/100)&(t*198/100))-(t*(t>>17)&(t*302/100)&(t*298/100)))",
        "((t*(t>>12)&(201*t/100)&(199*t/100))&(t*(t>>14)&(t*301/100)&(t*399/100)))+((t*(t>>16)&(t*202/100)&(t*198/100))-(t*(t>>18)&(t*302/100)&(t*298/100)))",
        "((t*(36364689[t>>13&7]&15))/12&128)+(((((t>>12)^(t>>12)-2)%11*t)/4|t>>13)&127)",
        "t*(t^t+(t>>15|1)^(t-1280^t)>>10)",
        "((1-(((t+10)>>((t>>9)&((t>>14))))&(t>>4&-2)))*2)*(((t>>10)^((t+((t>>6)&127))>>10))&1)*32+128",
        "((t>>1%128)+20)*3*t>>14*t>>18",
        "t*(((t>>9)&10)|((t>>11)&24)^((t>>10)&15&(t>>15)))",
        "(t*t/256)&(t>>((t/1024)%16))^t%64*(0xC0D3DE4D69>>(t>>9&30)&t%32)*t>>18",
        "t&t>>8",
        "t*(42&t>>10)",
        "t|t%255|t%257",
        "t>>6&1?t>>5:-t>>4",
        "t*(t>>9|t>>13)&16",
        "(t&t>>12)*(t>>4|t>>8)",
        "(t*5&t>>7)|(t*3&t>>10)",
        "(t*(t>>5|t>>8))>>(t>>16)",
        "t*5&(t>>7)|t*3&(t*4>>10)",
        "(t>>13|t%24)&(t>>7|t%19)",
        "(t*((t>>9|t>>13)&15))&129",
        "(t&t%255)-(t*3&t>>13&t>>6)",
        "(t&t>>12)*(t>>4|t>>8)^t>>6",
        "t*(((t>>9)^((t>>9)-1)^1)%13)",
        "t*(0xCA98>>(t>>9&14)&15)|t>>8",
        "(t/8)>>(t>>9)*t/((t>>14&3)+4)",
        "(~t/100|(t*3))^(t*3&(t>>5))&t",
        "(t|(t>>9|t>>7))*t&(t>>11|t>>9)",
        "((t>>1%128)+20)*3*t>>14*t>>18",
        "((t&4096)?((t*(t^t%255)|(t>>4))>>1):(t>>3)|((t&8192)?t<<2:t))",
        "t*(((t>>12)|(t>>8))&(63&(t>>4)))",
        "t*(((t>>9)|(t>>13))&(25&(t>>6)))",
        "t*(t^t+(t>>15|1)^(t-1280^t)>>10)",
        "t*(((t>>11)&(t>>8))&(123&(t>>3)))",
        "(t>>7|t|t>>6)*10+4*(t&t>>13|t>>6)",
        "(t*9&t>>4|t*5&t>>7|t*3&t/1024)-t*(t>>((t>>9)|(t>>8))&(63&(t>>4)))",
        "(t>>6|t|t>>(t>>16))*10+((t>>11)&7)",
        "(t>>1)*(0xbad2dea1>>(t>>13)&3)|t>>5",
        "(t>>4)*(13&(0x8898a989>>(t>>11&30)))",
        "(t>>(t&7))|(t<<(t&42))|(t>>7)|(t<<5)",
        "(t>>7|t%45)&(t>>8|t%35)&(t>>11|t%20)",
        "(t>>6|t<<1)+(t>>5|t<<3|t>>3)|t>>2|t<<t+(t&t^t>>6)-t*((t>>9)&(t%16?2:6)&t>>9)",
        "((t*(t>>8|t>>9)&46&t>>8))^(t&t>>13|t>>6)",
        "t*(((t>>9)^((t>>9)-1)^1)%13)",
        "(t>>5)|(t<<4)|((t&1023)^1981)|((t-67)>>4)",
        "(t>>5)|(t<<4)|((t&1023)^1981)|((t-67)>>4)",
        "t*(t/256)-t*(t/255)+t*(t>>5|t>>6|t<<2&t>>1)",
        "((t>>5&t)-(t>>5)+(t>>5&t))+(t*((t>>14)&14))",
        "(t*((3+(1^t>>10&5))*(5+(3&t>>14))))>>(t>>8&3)",
        "((t>>4)*(13&(0x8898a989>>(t>>11&30)))&255)+((((t>>9|(t>>2)|t>>8)*10+4*((t>>2)&t>>15|t>>8))&255)>>1)",
        "(int)(t/1e7*t*t+t)%127|t>>4|t>>5|t%127+(t>>16)|t",
        "t*(((t>>9)&10)|((t>>11)&24)^((t>>10)&15&(t>>15)))",
        "(~t>>2)*((127&t*(7&t>>10))<(245&t*(2+(5&t>>14))))",
        "(t+(t>>2)|(t>>5))+(t>>3)|((t>>13)|(t>>7)|(t>>11))",
        "t*(t>>8*((t>>15)|(t>>8))&(20|(t>>19)*5>>t|(t>>3)))",
        "(t>>4)|(t%10)|(((t%101)|(t>>14))&((t>>7)|(t*t%17)))",
        "((t&((t>>5)))+(t|((t>>7))))&(t>>6)|(t>>5)&(t*(t>>7))",
        "((t&((t>>23)))+(t|(t>>2)))&(t>>3)|(t>>5)&(t*(t>>7))",
        "(((((t*((t>>9|t>>13)&15))&255/15)*9)%(1<<7))<<2)%6<<4",
        "((t%42)*(t>>4)|(0x15483113)-(t>>4))/(t>>16)^(t|(t>>4))",
        "t*(t>>((t&4096)?((t*t)/4096):(t/4096)))|(t<<(t/256))|(t>>4)",
        "((t&4096)?((t*(t^t%255)|(t>>4))>>1):(t>>3)|((t&8192)?t<<2:t))",
        "t*((0xbadbea75>>((t>>12)&30)&3)*0.25*(0x5afe5>>((t>>16)&28)&3))"
    };
};


