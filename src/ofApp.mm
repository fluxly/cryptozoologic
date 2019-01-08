//  iOS version of Fluxly, the musical physics looper
//
//  Created by Shawn Wallace on 11/14/17.
//  Released April 2018 to the App Store
//  See the LICENSE file for copyright information

#include "ofApp.h"
#import <AVFoundation/AVFoundation.h>
//#import <sys/utsname.h>

ABiOSSoundStream* ofApp::getSoundStream(){
    return stream;
}

//--------------------------------------------------------------
void ofApp::setupAudioStream(){
    stream = new ABiOSSoundStream();
    stream->setup(this, 2, 1, 44100, 512, 3);
}

//--------------------------------------------------------------
void ofApp::setup(){
    ofSetLogLevel(OF_LOG_VERBOSE);       // OF_LOG_VERBOSE for testing, OF_LOG_SILENT for production
    ofSetLogLevel("Pd", OF_LOG_SILENT);  // see verbose info from Pd

   /* NSString *deviceOSVersion = [UIDevice currentDevice].systemVersion;
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *platform = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    int version = [[NSNumber numberWithChar:[platform characterAtIndex:(4)]] intValue] - 48;
    int subversion = [[NSNumber numberWithChar:[platform characterAtIndex:(6)]] intValue] - 48;
    
    NSLog(@"deviceOSVersion: %@", deviceOSVersion);
    NSLog(@"deviceOSVersion: %@", platform);
    NSLog(@"iPad version: %i", version);
    NSLog(@"iPad subversion: %i", subversion);
    
    */
    
    ofSetOrientation(OF_ORIENTATION_90_LEFT);
    
    // enables the network midi session between iOS and Mac OSX on a
    // local wifi network
    //
    // in ofxMidi: open the input/outport network ports named "Session 1"
    //
    // on OSX: use the Audio MIDI Setup Utility to connect to the iOS device
    //
    ofxMidi::enableNetworking();
    
    // list the number of available input & output ports
    ofxMidiIn input;
    input.listInPorts();

    // create and open input ports
    for (int i = 0; i < input.getNumInPorts(); ++i) {
        
        // new object
        inputs.push_back(new ofxMidiIn);
        
        // set this class to receive incoming midi events
        inputs[i]->addListener(this);
        
        // open input port via port number
        inputs[i]->openPort(i);
    }
    
    // set this class to receieve midi device (dis)connection events
    ofxMidi::setConnectionListener(this);
    
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    // Set screen height and width
    screenH = [[UIScreen mainScreen] bounds].size.height;
    screenW = [[UIScreen mainScreen] bounds].size.width;
    
    // For retina support
    retinaScaling = [UIScreen mainScreen].scale;
    //retinaScaling = 1.5;    // hack for iPad demo
    screenW *= retinaScaling;
    screenH *= retinaScaling;
    ofLog(OF_LOG_VERBOSE, "SCALING %f:",retinaScaling);
    
    documentsDir = ofxiOSGetDocumentsDirectory();
    
    worldW = screenW;
    worldH = screenH;
    ofLog(OF_LOG_VERBOSE, "W, H %d, %d:",screenW, screenH);
    
    if (IS_IPAD) {
        device = TABLET;
    }
    
    if (device == PHONE) {
        if (retinaScaling > 1) {
            helpFont.load("slkscr.ttf", PHONE_RETINA_FONT_SIZE);
        } else {
            helpFont.load("slkscr.ttf", PHONE_FONT_SIZE);
        }
    } else {
        if (retinaScaling > 1) {
            helpFont.load("slkscr.ttf", TABLET_RETINA_FONT_SIZE);
        } else {
            helpFont.load("slkscr.ttf", TABLET_FONT_SIZE);
        }
    }
    
    helpTextHeight = helpFont.getLineHeight() * 0.8;
    ofLog(OF_LOG_VERBOSE, "Text line height: %d", helpTextHeight);
    
    // Set control coordinates and dimensions
    for (int i=0; i< 5; i++) {
        controlW[i] = 32 * retinaScaling;
        controlHalfW[i] = 18 * retinaScaling;
    }
    
    controlX[EXIT_GAME] = screenW-controlHalfW[EXIT_GAME];
    controlY[EXIT_GAME] = screenH-controlHalfW[EXIT_GAME];
    
    controlX[DAMPEN] = controlHalfW[DAMPEN];
    controlY[DAMPEN] = screenH-controlHalfW[DAMPEN];
    
    controlX[HELP_GAME] = screenW/2;
    controlY[HELP_GAME] = screenH-controlHalfW[HELP_GAME];
    
    controlX[HELP_SAMPLE_SELECT] = screenW-controlHalfW[HELP_SAMPLE_SELECT];
    controlY[HELP_SAMPLE_SELECT] = controlHalfW[HELP_SAMPLE_SELECT];
    
    controlX[EXIT_SAMPLE_SELECT] = controlHalfW[EXIT_SAMPLE_SELECT];
    controlY[EXIT_SAMPLE_SELECT] = controlHalfW[EXIT_SAMPLE_SELECT];
    
    ofSetFrameRate(60);
    //ofEnableAntiAliasing();
    volume = 1.0f;
    myControlThread.setup(&volume);
    
    /* Moved this out of setup into its own state
     ofSetHexColor(0xFFFFFF);
     ofSetRectMode(OF_RECTMODE_CENTER);
     helpFont.drawString("fluxly.com", screenW/2 - helpFont.stringWidth("fluxly.com")/2, screenH/2) ;
     [ofxiPhoneGetGLView() finishRender];
     */
}

void ofApp::setupPostSplashscreen() {
    ofLog(OF_LOG_VERBOSE, "Post splashscreen");
    ofLog(OF_LOG_VERBOSE, ofxiOSGetDocumentsDirectory());  // useful for accessing documents directory in simulator
    
    // On first run, check if settings files are in documents directory; if not, copy from the bundle
    dir.open(ofxiOSGetDocumentsDirectory());
    int numFiles = dir.listDir();
    firstRun = true;
    
    for (int i=0; i<numFiles; ++i) {
        if (dir.getName(i) == "menuSettings.xml") {
            firstRun = false;
            helpOn = false;        // turn off help layer if not first run
        }
        //cout << "Path at index " << i << " = " << dir.getName(i) << endl;
    }
   // if (firstRun) {
    // FIXME: overwrites each time
        // ofLog(OF_LOG_VERBOSE, "First Run: copies files to documents from bundle.");
        file.copyFromTo("menuSettings.xml", ofxiOSGetDocumentsDirectory()+"menuSettings.xml", true, true);
        file.copyFromTo("sampleSettings.xml", ofxiOSGetDocumentsDirectory()+"sampleSettings.xml", true, true);
        for (int i=0; i < SCENES_IN_BUNDLE; i++) {
            if (device == TABLET) {
                file.copyFromTo("game"+to_string(i)+"-ipad.xml", ofxiOSGetDocumentsDirectory()+"game"+to_string(i)+".xml", true, true);
                file.copyFromTo("game"+to_string(i)+"-ipad.png", ofxiOSGetDocumentsDirectory()+"game"+to_string(i)+".png", true, true);
            } else {
                file.copyFromTo("game"+to_string(i)+".xml", ofxiOSGetDocumentsDirectory()+"game"+to_string(i)+".xml", true, true);
                file.copyFromTo("game"+to_string(i)+".png", ofxiOSGetDocumentsDirectory()+"game"+to_string(i)+".png", true, true);
            }
        }
    //}
    ofLog(OF_LOG_VERBOSE, "set samplerate");
    // try to set the preferred iOS sample rate, but get the actual sample rate
    // being used by the AVSession since newer devices like the iPhone 6S only
    // want specific values (ie 48000 instead of 44100)
    //float sampleRate = setAVSessionSampleRate(44100);
    float sampleRate = 44100;
    
    ofLog(OF_LOG_VERBOSE, "end set samplerate");
    // the number of libpd ticks per buffer,
    // used to compute the audio buffer len: tpb * blocksize (always 64)
    int ticksPerBuffer = 8; // 8 * 64 = buffer len of 512
    
    // Pre-audiobus:
    //setup OF sound stream using the current *actual* samplerate
    // ofSoundStreamSetup(2, 1, this, sampleRate, ofxPd::blockSize()*ticksPerBuffer, 3);
    
    // setup Pd
    //
    // set 4th arg to true for queued message passing using an internal ringbuffer,
    // this is useful if you need to control where and when the message callbacks
    // happen (ie. within a GUI thread)
    //
    // note: you won't see any message prints until update() is called since
    // the queued messages are processed there, this is normal
    //
    ofLog(OF_LOG_VERBOSE, "init libPd");
    if(!pd.init(2, 1, sampleRate, ticksPerBuffer-1, false)) {
        OF_EXIT_APP(1);
    }
    
    // Setup externals
    freeverb_tilde_setup();
    bytebeat_tilde_setup();
    
    midiChan = 1; // midi channels are 1-16
    
    // subscribe to receive source names
    pd.subscribe("toOF");
    pd.subscribe("env");
    
    // add message receiver, required if you want to receieve messages
    pd.addReceiver(*this);   // automatically receives from all subscribed sources
    pd.ignoreSource(*this, "env");      // don't receive from "env"
    //pd.ignoreSource(*this);           // ignore all sources
    //pd.receiveSource(*this, "toOF");  // receive only from "toOF"
    
    // add midi receiver, required if you want to recieve midi messages
    pd.addMidiReceiver(*this);  // automatically receives from all channels
    //pd.ignoreMidiChannel(*this, 1);     // ignore midi channel 1
    //pd.ignoreMidiChannel(*this);        // ignore all channels
    pd.receiveMidiChannel(*this, 1);    // receive only from channel 1
    
    // add the data/pd folder to the search path
    //pd.addToSearchPath("pd/abs");
    
    ofSeedRandom();
    // audio processing on
    ofLog(OF_LOG_VERBOSE, "start libPd");
    pd.start();
    
    // Load all images
    for (int i=0; i<8; i++) {
        background[i].load("background" + std::to_string(i) + ".png");
        background[i].getTexture().setTextureMinMagFilter(GL_NEAREST,GL_NEAREST);    // for clean pixel scaling
    }
    //toolbar.load("toolbar.png");
    exitButton.load("navMenuExit.png");
    exitButton.getTexture().setTextureMinMagFilter(GL_NEAREST,GL_NEAREST);
    helpButton.load("helpButton.png");
    helpButton.getTexture().setTextureMinMagFilter(GL_NEAREST,GL_NEAREST);
    helpButtonGlow.load("helpButtonGlow.png");
    helpButtonGlow.getTexture().setTextureMinMagFilter(GL_NEAREST,GL_NEAREST);
    arrow.load("arrow.png");
    arrow.getTexture().setTextureMinMagFilter(GL_NEAREST,GL_NEAREST);
    arrowLeft.load("arrowLeft.png");
    arrowLeft.getTexture().setTextureMinMagFilter(GL_NEAREST,GL_NEAREST);
    icon.load("appIcon.png");
    
    bounds.set(0, 0, worldW, worldH-toolbarH);
    box2d.init();
    box2d.setFPS(60);
    box2d.setGravity(0, 0);
    box2d.createBounds(bounds);
    box2d.enableEvents();
    ofAddListener(box2d.contactStartEvents, this, &ofApp::contactStart);
    ofAddListener(box2d.contactEndEvents, this, &ofApp::contactEnd);
    
    box2d.registerGrabbing();
    
    mainMenu = new SlidingMenu();
    
    //mainMenu->menuTitleW = screenW;
    
    appIconW = 180*retinaScaling;
    appIconX = screenW/2;
    
    if (device==TABLET) {
        appIconY = screenH - helpTextHeight * 5 - appIconW/2;
    } else {
        appIconY = screenH - helpTextHeight * 3 - appIconW/2;
    }
    
    mainMenu->initMenu(MAIN_MENU, 0, 0, screenW, screenH);
    
    
    sampleMenu = new SlidingMenu();
    sampleMenu->retinaScale = retinaScaling;
    if (device==TABLET) {
        sampleMenu->bankTitleH *= 2;
        sampleMenu->bankTitleW *= 2;
    }
    
    consoleH *=retinaScaling;
    
    sampleMenu->menuTitleH *=retinaScaling;
    sampleMenu->initMenu(SAMPLE_MENU, 0, consoleH, screenW, screenH);
    
    
    playRecordConsole = new SampleConsole();
    playRecordConsole->retinaScale = retinaScaling;
    if (device==TABLET) {
        playRecordConsole->soundWaveH *= 2;
    }
    playRecordConsole->init(screenW, consoleH);
    
    // Do some scaling for tablet version
    if (device == TABLET) {
        deviceScale = 1.5;
        playRecordConsole->thumbW *= 2;
    }
    
    dampOnOff.load("dampOnOff.png");
    dampOnOffGlow.load("dampOnOffGlow.png");
    
    saving.load("saving.png");
    ofLog(OF_LOG_VERBOSE, "end Setup");
}

void ofApp::loadGame(int gameId) {
    //dir.open(ofxiOSGetDocumentsDirectory());
    //numFiles = dir.listDir();
    //for (int i=0; i<numFiles; ++i) {
    //    cout << "Path at index " << i << " = " << dir.getPath(i) << endl;
    //}
    
    // the world bounds
    currentGame = gameId;
    
    switch (gameId) {
        case 0: pd.openPatch("pd-bytebeat.pd"); break;
        case 1: pd.openPatch("pd-benjolin2.pd"); break;
        case 2: pd.openPatch("pd-vivianLoopBox.pd"); break;
        case 3: pd.openPatch("pd-irishYeti.pd"); break;
    }
    
    //send screen width for panning calculation in Pd
    pd.sendFloat("screenW", screenW);
    
    ofxXmlSettings gameSettings;
    if (gameSettings.loadFile(ofxiOSGetDocumentsDirectory()+mainMenu->menuItems[gameId]->link)) {
        string menuItemName = gameSettings.getValue("settings:menuItem", "defaultScene");
        backgroundId = gameSettings.getValue("settings:settings:backgroundId", 0);
        
        gameSettings.pushTag("settings");
        gameSettings.pushTag("circles");
        nCircles = gameSettings.getNumTags("circle");
        
        for(int i = 0; i < nCircles; i++){
            //ofLog(OF_LOG_VERBOSE, "Circle count: %d", i);
            circles.push_back(shared_ptr<FluxlyCircle>(new FluxlyCircle));
            FluxlyCircle * c = circles.back().get();
            gameSettings.pushTag("circle", i);
            c->id = gameSettings.getValue("id", 0);
            c->type =  gameSettings.getValue("type", 0);
            c->eyeState =  gameSettings.getValue("eyestate", true);
            c->onOffState = gameSettings.getValue("onOffState", true);
            c->spinning =  gameSettings.getValue("spinning", true);
            c->wasntSpinning =  gameSettings.getValue("wasntspinning", true);
            c->instrument =  gameSettings.getValue("instrument", 0);
            c->dampingX =  gameSettings.getValue("dampingX", 0);
            c->dampingY =  gameSettings.getValue("dampingY", 0);
            c->bx =  gameSettings.getValue("bx", 0);
            c->by =  gameSettings.getValue("by", 0);
            c->bw =  gameSettings.getValue("bw", 0);
            c->bh =  gameSettings.getValue("bh", 0);
            c->a1x =  gameSettings.getValue("a1x", 0);
            c->a1y =  gameSettings.getValue("a1y", 0);
            c->a2x =  gameSettings.getValue("a2x", 0);
            c->a2y =  gameSettings.getValue("a2y", 0);
            c->a3x =  gameSettings.getValue("a3x", 0);
            c->a3y =  gameSettings.getValue("a3y", 0);
            c->x = gameSettings.getValue("x", 0);
            c->y = gameSettings.getValue("y", 0);
            c->w = gameSettings.getValue("w", 0);
            c->displayW = c->w;
            c->retinaScale = retinaScaling;
            
            // Make some corrections for tablets
            if (device == TABLET) {
                c->soundWaveStep = 4;
                c->soundWaveH = 100;
                c->soundWaveStart = -1024;
                c->maxAnimationCount = 100;
                c->animationStep = 12;
                c->displayW *= deviceScale;
            }
            
            // Correct for retina displays
            c->x = c->x*retinaScaling;
            c->y = c->y*retinaScaling;
            c->w = c->w*retinaScaling;
            c->bx = c->bx*retinaScaling;
            c->by = c->by*retinaScaling;
            c->bw = c->bw*retinaScaling;
            c->bh = c->bh*retinaScaling;
            c->a1x = c->a1x*retinaScaling;
            c->a1y = c->a1y*retinaScaling;
            c->a2x = c->a2x*retinaScaling;
            c->a2y = c->a2y*retinaScaling;
            c->a3x= c->a3x*retinaScaling;
            c->a3y= c->a3y*retinaScaling;
            c->soundWaveStep *= retinaScaling;
            c->soundWaveH *= retinaScaling;
            c->animationStep *=retinaScaling;
            c->displayW *= retinaScaling;
            
            c->setPhysics(1/deviceScale/retinaScaling, 1, 1);    // density, bounce, friction
            c->setup(box2d.getWorld(), c->x, c->y, (c->w/2)*deviceScale);
            c->setRotation(gameSettings.getValue("rotation", 0));
            BoxData * bd = new BoxData();
            bd->boxId = c->id;
            c->body->SetUserData(bd);
            c->init();
            
            
            /*if ((c->type < SAMPLES_IN_BUNDLE)) {
                // The built-in samples are in the bundle
                pd.sendSymbol("filename"+to_string(circles[i].get()->instrument), sampleMenu->menuItems[circles[i].get()->type]->link);
            } else {
                if (c->type < 144) {
                    // Anything after that is in the documents directory
                    pd.sendSymbol("filename"+to_string(circles[i].get()->instrument),
                                  ofxiOSGetDocumentsDirectory()+sampleMenu->menuItems[circles[i].get()->type]->link);
                }
            }*/
            
           // pd.sendFloat("tempo8", 0.0);    // Set reverb to 0
            gameSettings.popTag();
        }
        gameSettings.popTag();
        gameSettings.pushTag("joints");
        int nJoints = gameSettings.getNumTags("joint");
        //ofLog(OF_LOG_VERBOSE, "nJoints: %d", nJoints);
        for(int i = 0; i < nJoints; i++){
            gameSettings.pushTag("joint", i);
           // int id1 = gameSettings.getValue("id1", 0);
           // int id2 = gameSettings.getValue("id2", 0);
            //ofLog(OF_LOG_VERBOSE, "Joint: id1, id2: %d, %d", id1, id2);
            gameSettings.popTag();
        }
    } else {
        ofLog(OF_LOG_VERBOSE, "Couldn't load file!");
    }
    applyDamping = true;
    
    pd.sendFloat("masterVolume", 1.0);
    gameState = RUN;
}

static bool shouldRemoveConnection(shared_ptr<FluxlyConnection>shape) {
    return true;
}
static bool shouldRemoveJoint(shared_ptr<FluxlyJointConnection>shape) {
    return true;
}
static bool shouldRemoveCircle(shared_ptr<FluxlyCircle>shape) {
    return true;
}

//--------------------------------------------------------------
void ofApp::update() {
    switch (scene) {
        case MENU_SCENE:
            if (totallySetUp) mainMenu->updateScrolling();
            instrumentOn = false;
            break;
        case GAME_SCENE:
            instrumentOn = true;
            if (gameState == RUN) {
                // since this is a test and we don't know if init() was called with
                // queued = true or not, we check it here
                if(pd.isQueued()) {
                    // process any received messages, if you're using the queue and *do not*
                    // call these, you won't receieve any messages or midi!
                    pd.receiveMessages();
                    pd.receiveMidi();
                }
                
                box2d.update();
                
                globalTick++;
                
                // only update one pan channel each tick
                int panChannel = globalTick % nCircles;
                pd.sendFloat("pan"+to_string(panChannel), circles[panChannel]->x);
                
                for (int i=0; i<circles.size(); i++) {
                    if ((circles[i]->spinning) && (circles[i]->wasntSpinning)) {
                        circles[i]->onOffState = true;
                        circles[i]->wasntSpinning = false;
                    }
                    if (circles[i]->spinning) {
                        if (circles[i]->onOffState) {
                            circles[i]->eyeState = true;
                        } else {
                            circles[i]->eyeState = false;
                        }
                    } else {
                        circles[i]->onOffState = false;
                        circles[i]->eyeState = false;
                        circles[i]->wasntSpinning = true;
                    }
                }
                
                for (int i=0; i < circles.size(); i++) {
                    circles[i].get()->setRotationFriction(1);
                    if (applyDamping) circles[i].get()->setDamping(0, 0);
                    circles[i].get()->checkToSendNote();
                    circles[i].get()->checkToSendTempo();
                    if (circles[i]->tempo != 0) midiSavedAngularVelocity[i] = circles[i]->body->GetAngularVelocity();
                    if (circles[i].get()->sendTempo) {
                       
                        if ((currentGame == 0) && (i==2)) {
                            ofLog(OF_LOG_VERBOSE, "Changed x %d: %f", i, ((float)circles[i]->x/screenW)*94);
                            pd.sendFloat("control"+to_string(circles[i].get()->id), ((float)circles[i]->x/screenW)*94);    // HACK: FIXME
                        } else {
                             ofLog(OF_LOG_VERBOSE, "Changed tempo %d: %f", i, circles[i]->tempo);
                            pd.sendFloat("control"+to_string(circles[i].get()->id), circles[i]->tempo);
                        }
                        circles[i].get()->sendTempo = false;
                    }
                    if (circles[i].get()->sendOn) {
                        pd.sendFloat("toggle"+to_string(circles[i].get()->instrument), 1.0);
                        circles[i].get()->sendOn = false;
                    }
                    if (circles[i].get()->sendOff) {
                        pd.sendFloat("toggle"+to_string(circles[i].get()->instrument), 0.0);
                        circles[i].get()->sendOff = false;
                    }
                   // if (circles[i].get()->type < 144) pd.readArray("scope"+to_string(circles[i].get()->instrument), circles[i].get()->scopeArray);
                }
                // Get scopes
            }
            switch (currentGame) {
                case 0:
                    pd.readArray("scope0", backgroundScopeArray);
                    break;
                case 1:
                    break;
                case 2:
                    break;
                case 3:
                    break;
            }
            break;
    }
    if ((helpOn) || (helpOn2)) {
        helpLayerScript();     // update the help layer
    }
}

//--------------------------------------------------------------
void ofApp::draw() {
    switch (scene) {
        case SPLASHSCREEN:
            ofSetHexColor(0x000000);
            ofSetRectMode(OF_RECTMODE_CORNER);
            ofDrawRectangle(0, 0, screenW, screenH);
            ofSetHexColor(0xFFFFFF);
            ofSetRectMode(OF_RECTMODE_CENTER);
            helpFont.drawString("cryptozoologic.org", screenW/2 - helpFont.stringWidth("cryptozoologic.org")/2, screenH/2);
            totallySetUp = false;
            scene = MENU_SCENE;
            break;
        case MENU_SCENE:
            if (!totallySetUp) {
                ofLog(OF_LOG_VERBOSE, "Totally Not Set Up");
                setupPostSplashscreen();
                totallySetUp = true;
            }
            mainMenu->draw();
            mainMenu->drawBorder(currentGame);
            break;
        case GAME_SCENE:
            //ofTranslate(0, screenH*.3); // Hack for iPad demo
            ofSetHexColor(0xFFFFFF);
            ofSetRectMode(OF_RECTMODE_CORNER);
            background[backgroundId].draw(0, 0, screenW, screenH);
            if ((globalTick % 1) == 0) drawVisualization(currentGame);
            
            ofSetRectMode(OF_RECTMODE_CENTER);
            
            if (helpOn) {
                for (int i=0; i<circles.size(); i++) {
                    circles[i].get()->drawHelpBubble();
                }
            }
            //if (device == PHONE) {
            
            for (int i=0; i<circles.size(); i++) {
              //  circles[i].get()->drawSoundWave(1);
            }
            // }
            ofSetRectMode(OF_RECTMODE_CENTER);
            ofSetHexColor(0xFFFFFF);
            
            for (int i=0; i<circles.size(); i++) {
                if (midiSaveState[i] || midiPlayState[i]) circles[i].get()->drawBlueGlow();
                circles[i].get()->draw();
            }
            
            for (int i=0; i<joints.size(); i++) {
                ofSetColor( ofColor::fromHex(0xff0000) );
                joints[i]->joint->draw();
            }
            ofSetHexColor(0xFFFFFF);
            exitButton.draw(controlX[EXIT_GAME], controlY[EXIT_GAME], controlW[EXIT_GAME], controlW[EXIT_GAME]);
            if (applyDamping) {
                dampOnOff.draw(controlX[DAMPEN], controlY[DAMPEN], controlW[DAMPEN], controlW[DAMPEN]);
            } else {
                dampOnOffGlow.draw(controlX[DAMPEN], controlY[DAMPEN], controlW[DAMPEN], controlW[DAMPEN]);
            }
            if (!helpOn) {
                helpButton.draw(controlX[HELP_GAME], controlY[HELP_GAME], controlW[HELP_GAME], controlW[HELP_GAME]);
            } else {
                helpButtonGlow.draw(controlX[HELP_GAME], controlY[HELP_GAME], controlW[HELP_GAME], controlW[HELP_GAME]);
            }
            //helpFont.drawString(ofToString(ofGetFrameRate()), 10,20);
            break;
        case SELECT_SAMPLE_SCENE:
            ofSetHexColor(0xFFFFFF);
            ofSetRectMode(OF_RECTMODE_CORNER);
            background[backgroundId].draw(0, 0, worldW, worldH);
            ofSetRectMode(OF_RECTMODE_CENTER);
            for (int i=0; i<circles.size(); i++) {
                circles[i].get()->draw();
            }
            
            ofSetColor(25, 25, 25, 200);
            ofDrawRectangle(screenW/2, screenH/2, screenW, screenH);
            ofSetRectMode(OF_RECTMODE_CENTER);
            ofSetColor(255, 255, 255, 255);
            sampleMenu->draw();
            playRecordConsole->draw();
            ofSetColor(255, 255, 255, 200);
            ofDrawRectangle(controlX[EXIT_SAMPLE_SELECT], controlY[EXIT_SAMPLE_SELECT],
                            controlW[EXIT_SAMPLE_SELECT], controlW[EXIT_SAMPLE_SELECT]);     //exit
            // ofDrawRectangle(screenW-18, 18, 30, 30);   // help
            ofSetColor(255, 255, 255, 255);
            exitButton.draw(controlX[EXIT_SAMPLE_SELECT], controlY[EXIT_SAMPLE_SELECT],
                            controlW[EXIT_SAMPLE_SELECT], controlW[EXIT_SAMPLE_SELECT]);
            /* if (!helpOn2) {
             helpButton.draw(controlX[HELP_SAMPLE_SELECT], controlY[HELP_SAMPLE_SELECT], controlW[HELP_SAMPLE_SELECT], controlW[HELP_SAMPLE_SELECT]);
             } else {
             helpButtonGlow.draw(controlX[HELP_SAMPLE_SELECT], controlY[HELP_SAMPLE_SELECT], controlW[HELP_SAMPLE_SELECT], controlW[HELP_SAMPLE_SELECT]);
             }*/
            
#ifdef FLUXLY_FREE
            icon.draw(appIconX, appIconY, appIconW, appIconW);
            
            helpFont.drawString("Record Your Own samples",
                                screenW/2 - helpFont.stringWidth("Record Your Own samples")/2,
                                appIconY + appIconW/2 + helpTextHeight) ;
            helpFont.drawString("with the full version",
                                screenW/2 - helpFont.stringWidth("with the full version")/2,
                                appIconY + appIconW/2 + helpTextHeight*2) ;
            helpFont.drawString("in the App Store",
                                screenW/2 - helpFont.stringWidth("in the App Store")/2,
                                appIconY + appIconW/2 + helpTextHeight*3 ) ;
#endif
            break;
        case SAVE_EXIT_PART_1:
            ofSetHexColor(0xFFFFFF);
            ofSetRectMode(OF_RECTMODE_CORNER);
            background[backgroundId].draw(0, 0, worldW, worldH);
            ofSetRectMode(OF_RECTMODE_CENTER);
            for (int i=0; i<circles.size(); i++) {
               // circles[i].get()->drawSoundWave(3);
            }
            for (int i=0; i<circles.size(); i++) {
                circles[i].get()->draw();
            }
            for (int i=0; i<joints.size(); i++) {
                ofSetColor( ofColor::fromHex(0xff0000) );
                joints[i]->joint->draw();
            }
            ofSetHexColor(0xFFFFFF);
            //screenshot.grabScreen(0, 0, screenW, screenH);
            //saving.draw(screenW/2, screenH/2);
            scene = SAVE_EXIT_PART_2;
            break;
        case SAVE_EXIT_PART_2:
           // screenshot.save( mainMenu->menuItems[currentGame]->filename);
            //ofLog(OF_LOG_VERBOSE, "Screenshot");
            saveGame();
            destroyGame();
            scene = MENU_SCENE;
           // mainMenu->menuItems[currentGame]->reloadThumbnail();
            break;
    }
    if (helpOn && (scene == GAME_SCENE)) helpLayerDisplay(currentHelpState);
    if (helpOn2 && (scene == SELECT_SAMPLE_SCENE)) helpLayerDisplay(currentHelpState2);
}

void ofApp::drawVisualization(int gameId) {
    int radius = screenW / 48;
    
    int dw = 0;
    int dh = 0;
    
    switch (gameId) {
        case 0:
            for (int i=0; i<8; i++) {
                int t = (int)(backgroundScopeArray[i*2] * 255);
                for (int j=0; j<8; j++) {
                    if (((t >> j) & 0x01) == 1) {
                   // if (backgroundScopeArray[i*j+j] > .5)
                        ofSetColor(255);
                        //dw = (int)ofRandom(-10, 10);
                        //dh = (int)ofRandom(-10, 10);
                        //dw = j;
                    } else {
                        ofSetColor(0);
                        //dw = 10; dh=10;
                    }
                    if (circles[0]->tempo == 0) ofSetColor(0);
                    /*
                    ofDrawEllipse(radius+i*2*radius, radius+j*2*radius, radius+dw, radius+dh);
                    ofDrawEllipse(17*radius+i*2*radius, radius+j*2*radius, radius+dw, radius+dh);
                    ofDrawEllipse(33*radius+i*2*radius, radius+j*2*radius, radius+dw, radius+dh);
                    ofDrawEllipse(radius+i*2*radius,   17*radius+j*2*radius, radius+dw, radius+dh);
                    ofDrawEllipse(17*radius+i*2*radius, 17*radius+j*2*radius, radius+dw, radius+dh);
                    ofDrawEllipse(33*radius+i*2*radius, 17*radius+j*2*radius, radius+dw, radius+dh);*/
                    ofDrawRectangle(radius+i*2*radius, radius+j*2*radius, radius+dw, radius+dh);
                    ofDrawRectangle(17*radius+i*2*radius, radius+j*2*radius, radius+dw, radius+dh);
                    ofDrawRectangle(33*radius+i*2*radius, radius+j*2*radius, radius+dw, radius+dh);
                    ofDrawRectangle(radius+i*2*radius,   17*radius+j*2*radius, radius+dw, radius+dh);
                    ofDrawRectangle(17*radius+i*2*radius, 17*radius+j*2*radius, radius+dw, radius+dh);
                    ofDrawRectangle(33*radius+i*2*radius, 17*radius+j*2*radius, radius+dw, radius+dh);
                }
            }
            break;
        case 1:
            break;
        case 2:
            break;
        case 3:
            break;
    }
}

//--------------------------------------------------------------
void ofApp::exit(){
    pd.sendFloat("masterVolume", 0.0);
    myControlThread.stopThread();
    ofSoundStreamClose();
}

void ofApp::saveGame() {
    ofxXmlSettings outputSettings;
    
    outputSettings.addTag("settings");
    outputSettings.pushTag("settings");
    outputSettings.setValue("settings:fluxlyMajorVersion", FLUXLY_MAJOR_VERSION);
    outputSettings.setValue("settings:fluxlyMinorVersion", FLUXLY_MINOR_VERSION);
    outputSettings.setValue("settings:backgroundId", backgroundId);
    outputSettings.addTag("circles");
    outputSettings.pushTag("circles");
    for (int i = 0; i < nCircles; i++){
        outputSettings.addTag("circle");
        outputSettings.pushTag("circle", i);
        outputSettings.setValue("id", circles[i]->id);
        outputSettings.setValue("type", circles[i]->type);
        outputSettings.setValue("eyeState", false);
        outputSettings.setValue("onOffState", false);
        outputSettings.setValue("spinning", false);
        outputSettings.setValue("wasntSpinning", false);
        outputSettings.setValue("dampingX", circles[i]->dampingX);
        outputSettings.setValue("dampingY", circles[i]->dampingY);
        outputSettings.setValue("instrument", circles[i]->instrument);
        outputSettings.setValue("connection1", circles[i]->connections[0]);
        outputSettings.setValue("connection2", circles[i]->connections[1]);
        outputSettings.setValue("connection3", circles[i]->connections[2]);
        outputSettings.setValue("connection4", circles[i]->connections[3]);
        outputSettings.setValue("x", circles[i]->x/retinaScaling);
        outputSettings.setValue("y", circles[i]->y/retinaScaling);
        outputSettings.setValue("w", circles[i]->w/retinaScaling);
        outputSettings.setValue("rotation", circles[i]->rotation);
        outputSettings.popTag();
    }
    outputSettings.popTag();
    outputSettings.addTag("joints");
    outputSettings.pushTag("joints");
    for(int i = 0; i < joints.size(); i++){
        outputSettings.addTag("joint");
        outputSettings.pushTag("joint", i);
        outputSettings.setValue("id1", 0);
        outputSettings.setValue("id2", 0);
        outputSettings.popTag();
    }
    outputSettings.popTag();
    outputSettings.popTag();
    outputSettings.saveFile(ofxiOSGetDocumentsDirectory()+"game"+to_string(currentGame)+".xml");
    
}

void ofApp::destroyGame() {
    
    pd.sendFloat("masterVolume", 0.0);
    
    for (int i=0; i < circles.size(); i++) {
        pd.sendFloat("toggle"+to_string(circles[i].get()->instrument), 0.0);
    }
    
    for (int i=0; i < joints.size(); i++) {
        // remove joint from world
        joints[i]->joint->destroy();
    }
    
    for (int i=0; i < circles.size(); i++) {
        delete (BoxData *)circles[i]->body->GetUserData();
        circles[i]->destroy();
    }
    
    ofRemove(joints, shouldRemoveJoint);
    ofRemove(circles, shouldRemoveCircle);
}


void ofApp::reloadSamples() {
    for (int i=0; i<circles.size(); i++) {
        if ((circles[i]->type < SAMPLES_IN_BUNDLE)) {
            pd.sendSymbol("filename"+to_string(circles[i].get()->instrument), sampleMenu->menuItems[circles[i].get()->type]->link);
        } else {
            if (circles[i]->type < 144) {
                // Anything after that is in the documents directory
                pd.sendSymbol("filename"+to_string(circles[i].get()->instrument),
                              ofxiOSGetDocumentsDirectory()+sampleMenu->menuItems[circles[i].get()->type]->link);
            }
        }
    }
}

//--------------------------------------------------------------
void ofApp::touchDown(ofTouchEventArgs & touch){
    ofLog(OF_LOG_VERBOSE, "TOUCH DOWN!");
    // MENU SCENE: Touched and not already moving: save touch down location and id
    if ((scene == MENU_SCENE) && (mainMenu->scrollingState == 0)) {
        mainMenu->scrollingState = -1;  // wait for move state
        //ofLog(OF_LOG_VERBOSE, "Scrolling State %d", mainMenu->scrollingState);
        //startBackgroundY = backgroundY;
        startTouchId = touch.id;
        startTouchX = (int)touch.x;
        startTouchY = (int)touch.y;
    }
    
    // SELECT SAMPLE SCENE: Touched and not already moving: save touch down location and id
    if ((scene == SELECT_SAMPLE_SCENE) && (sampleMenu->scrollingState == 0)) {
        sampleMenu->scrollingState = -1;  // wait for move state
        ofLog(OF_LOG_VERBOSE, "TOUCH DOWN Scrolling State %d", sampleMenu->scrollingState);
        //startBackgroundY = backgroundY;
        startTouchId = touch.id;
        startTouchX = (int)touch.x;
        startTouchY = (int)touch.y;
    }
    
    if (scene == GAME_SCENE) {
        startTouchId = touch.id;
        startTouchX = (int)touch.x;
        startTouchY = (int)touch.y;
        
        for (int i=0; i<circles.size(); i++) {
            if (circles[i]->inBounds(touch.x, touch.y) && !circles[i]->touched) {
                circles[i]->touched = true;
                circles[i]->touchId = touch.id;
                //ofLog(OF_LOG_VERBOSE, "Touched %d", i);
            }
        }
    }
    /*
     if (scene == SELECT_SAMPLE_SCENE) {
     startTouchId = touch.id;
     startTouchX = (int)touch.x;
     startTouchY = (int)touch.y;
     }
     */
}


//--------------------------------------------------------------
void ofApp::touchMoved(ofTouchEventArgs & touch){
    // ofLog(OF_LOG_VERBOSE, "touch %d move at (%i,%i)", touch.id, (int)touch.x, (int)touch.y);
    
    // MENU SCENE: no longer in same place as touch down
    // added a bit to the bounds to account for higher res digitizers
    if (scene == MENU_SCENE) {
        if ((mainMenu->scrollingState == -1) && (startTouchId == touch.id)) {
            
            if ((touch.y < (startTouchY - touchMargin*2)) || (touch.y > (startTouchY + touchMargin*2))) {
                mainMenu->scrollingState = 1;
            }
        }
        
        // MENU SCENE: Moving with finger down: slide menu up and down
        if ((mainMenu->scrollingState == 1)  && (startTouchId == touch.id)) {
            mainMenu->menuY = mainMenu->menuOriginY + ((int)touch.y - startTouchY);
        }
    }
    
    // SELECT SAMPLE SCENE
    if (scene == SELECT_SAMPLE_SCENE) {
        if ((sampleMenu->scrollingState == -1) && (startTouchId == touch.id)) {
            if ((touch.y < (startTouchY - touchMargin*2)) || (touch.y > (startTouchY + touchMargin*2))) {
                sampleMenu->scrollingState = 1;
                ofLog(OF_LOG_VERBOSE, "Scrolling State, %i",sampleMenu->scrollingState);
            }
        }
        ofLog(OF_LOG_VERBOSE, "menuY before, touch.y, startTouchY %f, %f, %f, %i", sampleMenu->menuY, sampleMenu->menuOriginY, touch.y, startTouchY);
        // SELECT SAMPLE SCENE: Moving with finger down: slide menu up and down
        if ((sampleMenu->scrollingState == 1)  && (startTouchId == touch.id)) {
            sampleMenu->menuY = sampleMenu->menuOriginY + (touch.y - startTouchY);
        }
        ofLog(OF_LOG_VERBOSE, "menuY after %f", sampleMenu->menuY);
    }
}

//--------------------------------------------------------------
void ofApp::touchUp(ofTouchEventArgs & touch){
    ofLog(OF_LOG_VERBOSE, "touch %d up at (%i,%i)", touch.id, (int)touch.x, (int)touch.y);
    if ((scene == SELECT_SAMPLE_SCENE) && (doubleTapped)) {
        doubleTapped = false;
        sampleMenu->scrollingState = 0;
        startTouchId = -1;
        startTouchX = 0;
        startTouchY = 0;
        ofLog(OF_LOG_VERBOSE, "----> %f, %f", touch.x, touch.y);
    } else {
        // MENU SCENE: Touched but not moved: load instrument
        if ((scene == MENU_SCENE) && (mainMenu->scrollingState == -1) && (startTouchId == touch.id)) {
            //ofLog(OF_LOG_VERBOSE, "scrollingState? %i", mainMenu->scrollingState);
            mainMenu->scrollingState = 0;
            startTouchId = -1;
            startTouchX = 0;
            startTouchY = 0;
            //ofLog(OF_LOG_VERBOSE, "checking %f, %f", touch.x, touch.y);
            int selectedGame = mainMenu->checkMenuTouch(touch.x, touch.y);
            if ( selectedGame > -1) {
                loadGame(selectedGame);
                scene = GAME_SCENE;
            }
        }
        // MENU SCENE: Touch up after moving
        if ((scene == MENU_SCENE) && (mainMenu->scrollingState == 1) && (startTouchId == touch.id)) {
            // If moved sufficiently, switch to next or previous state
            if ((int)touch.y < startTouchY-75) {
                mainMenu->changePaneState(-1);
            } else {
                if ((int)touch.y > startTouchY+75) {
                    mainMenu->changePaneState(1);
                }
            }
            mainMenu->scrollingState = 2;
            /*menuOrigin = -screenH*scrollingState;
             
             startBackgroundY = backgroundY;*/
            mainMenu->menuMoveStep = abs(mainMenu->menuY - mainMenu->menuOriginY)/8;
            startTouchId = -1;
            startTouchX = 0;
            startTouchY = 0;
            //ofLog(OF_LOG_VERBOSE, "New State: %i", mainMenu->scrollingState);
        }
        
        // SELECT SAMPLE SCENE: Touched but not moved
        if ((scene == SELECT_SAMPLE_SCENE) && (sampleMenu->scrollingState == -1) && (startTouchId == touch.id)) {
            ofLog(OF_LOG_VERBOSE, "scrollingState? %i", sampleMenu->scrollingState);
            sampleMenu->scrollingState = 0;
            startTouchId = -1;
            startTouchX = 0;
            startTouchY = 0;
            ofLog(OF_LOG_VERBOSE, "checking %f, %f", touch.x, touch.y);
            // Check if touched
            int selectedSample = sampleMenu->checkMenuTouch(touch.x, touch.y);
#ifndef FLUXLY_FREE
            if (selectedSample > -1)  {
#endif
#ifdef FLUXLY_FREE
                if ((selectedSample > -1) && (selectedSample < 15))  {
#endif
                    //ofLog(OF_LOG_VERBOSE, "Selected: %i", selectedSample);
                    sampleMenu->selected = selectedSample;
                    playRecordConsole->setSelected(sampleMenu->menuItems[selectedSample]->id);
                    sampleMenu->updateEyeState();
                    if ((sampleMenu->menuItems[selectedSample]->id < SAMPLES_IN_BUNDLE)) {
                        //ofLog(OF_LOG_VERBOSE, "Load preview buffer: %i", selectedSample);
                        //ofLog(OF_LOG_VERBOSE, sampleMenu->menuItems[selectedSample]->link);
                        pd.sendSymbol("previewFilename", sampleMenu->menuItems[selectedSample]->link);
                    } else {
                        if (sampleMenu->menuItems[selectedSample]->id < 144) {
                            // Anything after that is in the documents directory
                            pd.sendSymbol("previewFilename",
                                          ofxiOSGetDocumentsDirectory()+sampleMenu->menuItems[selectedSample]->link);
                        }
                    }
                }
            }
            
            // SELECT SAMPLE SCENE: Touch up after moving
            if ((scene == SELECT_SAMPLE_SCENE) && (sampleMenu->scrollingState == 1) && (startTouchId == touch.id)) {
                ofLog(OF_LOG_VERBOSE, "scrollingState? %i", sampleMenu->scrollingState);
                // If moved sufficiently, switch to next or previous state
                if ((int)touch.y < startTouchY-75) {
                    sampleMenu->changePaneState(-1);
                } else {
                    if ((int)touch.y > startTouchY+75) {
                        sampleMenu->changePaneState(1);
                    }
                }
                sampleMenu->scrollingState = 2;
                sampleMenu->menuMoveStep = abs(sampleMenu->menuY - sampleMenu->menuOriginY)/8;
                startTouchId = -1;
                startTouchX = 0;
                startTouchY = 0;
                ofLog(OF_LOG_VERBOSE, "New State: %i", sampleMenu->scrollingState);
            }
            
            // GAME SCENE
            if (scene == GAME_SCENE) {
                for (int i=0; i<circles.size(); i++) {
                    if (circles[i]->touchId == touch.id) {
                        circles[i]->touched = false;
                        circles[i]->touchId = -1;
                    }
                }
                //ofLog(OF_LOG_VERBOSE, "Checking exit: %i, %i, %f, %f", startTouchX, startTouchY, touch.x, touch.y);
                // Check to see if exit pushed
                if (controlInBounds(EXIT_GAME, touch.x, touch.y)) {
                    scene = SAVE_EXIT_PART_1;
                    startTouchId = -1;
                    startTouchX = 0;
                    startTouchY = 0;
                    //ofLog(OF_LOG_VERBOSE, "EXIT SCENE: %i", scene);
                }
                // Check to see if dampOnOff pushed
                if (controlInBounds(DAMPEN, touch.x, touch.y)) {
                    applyDamping = !applyDamping;
                    startTouchId = -1;
                    startTouchX = 0;
                    startTouchY = 0;
                    //ofLog(OF_LOG_VERBOSE, "DAMP ON OFF ");
                }
                // Check to see if helpOn pushed
                if (controlInBounds(HELP_GAME, touch.x, touch.y)) {
                    helpOn = !helpOn;
                    startTouchId = -1;
                    startTouchX = 0;
                    startTouchY = 0;
                    //ofLog(OF_LOG_VERBOSE, "DAMP ON OFF ");
                }
            }
            
            ofLog(OF_LOG_VERBOSE, "State before button check: %i", sampleMenu->scrollingState);
            // SAMPLE_SELECT_SCENE: Check all buttons
            if ((scene == SELECT_SAMPLE_SCENE) && (sampleMenu->scrollingState == 0)) {
                ofLog(OF_LOG_VERBOSE, "Checking exit: %i, %i, %f, %f", startTouchX, startTouchY, touch.x, touch.y);
                // Check to see if exit pushed
                if (controlInBounds(EXIT_SAMPLE_SELECT, touch.x, touch.y)) {
                    ofLog(OF_LOG_VERBOSE, "Exit!");
                    scene = GAME_SCENE;
                    pd.sendFloat("masterVolume", 1.0);
                    startTouchId = -1;
                    startTouchX = 0;
                    startTouchY = 0;
                    ofLog(OF_LOG_VERBOSE, "EXIT SCENE: %i", scene);
                    circles[sampleMenu->circleToChange]->type = sampleMenu->selected;
                    circles[sampleMenu->circleToChange]->setMesh();
                    reloadSamples();
                    playRecordConsole->playing = false;
                    playRecordConsole->recording = false;
                    pd.sendFloat("togglePreview", 0.0);
                    //ofLog(OF_LOG_VERBOSE, "Changing: %i, %i", sampleMenu->circleToChange,sampleMenu->selected);
                }
                
                // Check appIcon click
                int button = playRecordConsole->checkConsoleButtons(touch.x, touch.y);
                if (button == 1) {  //Play button
                    ofLog(OF_LOG_VERBOSE, "Yup, play pressed");
                    if (playRecordConsole->playing) {
                        pd.sendFloat("previewTempo", 1.0);
                        pd.sendFloat("togglePreview", 1.0);
                    } else {
                        pd.sendFloat("previewTempo", 1.0);
                        pd.sendFloat("togglePreview", 0.0);
                    }
                }
                if (button == 2) {  // Record button
                    ofLog(OF_LOG_VERBOSE, "Yup, record pressed");
                    if (playRecordConsole->selected >= SAMPLES_IN_BUNDLE) {
                        if (playRecordConsole->recording) {
                            pd.sendBang("startRecording");
                            ofLog(OF_LOG_VERBOSE, "Start recording");
                        } else {
                            ofLog(OF_LOG_VERBOSE, "Stop recording");
                            pd.sendBang("stopRecording");
                            pd.sendSymbol("writeRecordingToFilename", ofxiOSGetDocumentsDirectory()+sampleMenu->menuItems[playRecordConsole->selected]->link);
                            pd.sendSymbol("previewFilename",
                                          ofxiOSGetDocumentsDirectory()+sampleMenu->menuItems[playRecordConsole->selected]->link);
                            ofLog(OF_LOG_VERBOSE, ofxiOSGetDocumentsDirectory()+sampleMenu->menuItems[playRecordConsole->selected]->link);
                        }
                    }
                }
            }
        }
    }
    
    //--------------------------------------------------------------
    void ofApp::touchDoubleTap(ofTouchEventArgs & touch) {
        ofLog(OF_LOG_VERBOSE, "TOUCH DOUBLE TAP!");
      /*  doubleTapped = true;
     
        if (scene == GAME_SCENE) {
            ofLog(OF_LOG_VERBOSE, "1. State %d", gameState);
            
            int retval = -1;
            for (int i=0; i<circles.size(); i++) {
                if (circles[i]->inBounds(touch.x, touch.y) && (circles[i]->type < 144)) {
                    if (circles[i]->onOffState == false) retval = i;
                    if (circles[i]->onOffState == true) circles[i]->onOffState = false;
                }
            }
            if (retval > -1) {
                scene = SELECT_SAMPLE_SCENE;
                pd.sendFloat("masterVolume", 0.0);
                playRecordConsole->playing = false;
                playRecordConsole->recording = false;
                sampleMenu->selected = circles[retval]->type;
                playRecordConsole->setSelected(circles[retval]->type);
                sampleMenu->circleToChange = retval;
                if ((sampleMenu->menuItems[retval]->id < SAMPLES_IN_BUNDLE)) {
                    ofLog(OF_LOG_VERBOSE, "Load preview buffer: %i", retval);
                    ofLog(OF_LOG_VERBOSE, sampleMenu->menuItems[circles[retval]->type]->link);
                    pd.sendSymbol("previewFilename", sampleMenu->menuItems[circles[retval]->type]->link);
                } else {
                    if (sampleMenu->menuItems[retval]->id < 144) {
                        // Anything after that is in the documents directory
                        pd.sendSymbol("previewFilename",
                                      ofxiOSGetDocumentsDirectory()+sampleMenu->menuItems[circles[retval]->type]->link);
                    }
                }
            } else {
                selected = -1;
            }
            
        }
      */
    }
    
    //--------------------------------------------------------------
    void ofApp::touchCancelled(ofTouchEventArgs & touch){
        
    }
    
    //--------------------------------------------------------------
    void ofApp::lostFocus(){
        
    }
    
    //--------------------------------------------------------------
    void ofApp::gotFocus(){
        
    }
    
    //--------------------------------------------------------------
    void ofApp::gotMemoryWarning(){
        
    }
    
    //--------------------------------------------------------------
    void ofApp::deviceOrientationChanged(int newOrientation){
        if ((newOrientation == OF_ORIENTATION_90_RIGHT) || (newOrientation == OF_ORIENTATION_90_LEFT)) {
            ofSetOrientation((ofOrientation)newOrientation);
        }
    }
    
    void ofApp::contactStart(ofxBox2dContactArgs &e) {
        if(e.a != NULL && e.b != NULL) {
        }
    }
    
    //--------------------------------------------------------------
    void ofApp::contactEnd(ofxBox2dContactArgs &e) {
     /*   if(e.a != NULL && e.b != NULL) {
            b2Body *b1 = e.a->GetBody();
            BoxData *bd1 = (BoxData *)b1->GetUserData();
            if (bd1 !=NULL) {
                b2Body *b2 = e.b->GetBody();
                BoxData *bd2 = (BoxData *)b2->GetUserData();
                if (bd2 !=NULL) {
                    // Add to list of connections to make in the update
                    connections.push_back(shared_ptr<FluxlyConnection>(new FluxlyConnection));
                    FluxlyConnection * c = connections.back().get();
                    c->id1 = bd1->boxId;
                    c->id2 = bd2->boxId;
                }
            }
        }*/
    }
    
    //--------------------------------------------------------------
    
    bool ofApp::notConnectedYet(int n1, int n2) {
        bool retVal = true;
        int myId1;
        int myId2;
        for (int i=0; i < joints.size(); i++) {
            myId1 = joints[i]->id1;
            myId2 = joints[i]->id2;
            if (((n1 == myId1) && (n2 == myId2)) || ((n2 == myId1) && (n1 == myId2))) {
                //  ofLog(OF_LOG_VERBOSE, "Checking box %d connection list (length %d): %d == %d, %d == %d: Already connected",
                //  n1, boxen[n1]->nJoints, n1, myId1, n1, myId2);
                retVal = false;
            } else {
                // ofLog(OF_LOG_VERBOSE, "Checking box %d connection list (length %d): %d == %d, %d == %d: Not Yet connected",
                //      n1, boxen[n1]->nJoints, n1, myId1, n1, myId2);
            }
        }
        return retVal;
    }
    
    bool ofApp::complementaryColors(int n1, int n2) {
        bool retVal = false;
        if ((abs(circles[n1]->type - circles[n2]->type) == 1) || ((n1 == 0) || (n2 == 0))) {
            // ofLog(OF_LOG_VERBOSE, "    CORRECT COLOR");
            retVal = true;
        } else {
            // ofLog(OF_LOG_VERBOSE, "    WRONG COLOR");
        }
        return retVal;
    }
    
    bool ofApp::bothTouched(int n1, int n2) {
        bool retVal = false;
        if (circles[n1]->touched && circles[n2]->touched) {
            //ofLog(OF_LOG_VERBOSE, "    BOTH TOUCHED");
            retVal = true;
        } else {
            //ofLog(OF_LOG_VERBOSE, "    NOT BOTH TOUCHED");
        }
        return retVal;
    }
    
    bool ofApp::controlInBounds(int i, int x1, int y1) {
        if ((startTouchX < (controlX[i]+controlHalfW[i])+1) &&
            (startTouchX > (controlX[i]-controlHalfW[i]-1)) &&
            (startTouchY < (controlY[i]+controlHalfW[i])+1) &&
            (startTouchY > (controlY[i]-controlHalfW[i])-1) &&
            (x1 < (controlX[i]+controlHalfW[i])) &&
            (x1 > (controlX[i]-controlHalfW[i])) &&
            (y1 < (controlY[i]+controlHalfW[i])) &&
            (y1 > (controlY[i]-controlHalfW[i]))) {
            return true;
        } else {
            return false;
        }
    }
    
    //--------------------------------------------------------------
    void ofApp::audioReceived(float * input, int bufferSize, int nChannels) {
        pd.audioIn(input, bufferSize, nChannels);
    }
    
    //--------------------------------------------------------------
    void ofApp::audioRequested(float * output, int bufferSize, int nChannels) {
        pd.audioOut(output, bufferSize, nChannels);
    }
    
    //--------------------------------------------------------------
    // set the samplerate the Apple approved way since newer devices
    // like the iPhone 6S only allow certain sample rates,
    // the following code may not be needed once this functionality is
    // incorporated into the ofxiOSSoundStream
    // thanks to Seth aka cerupcat
    float ofApp::setAVSessionSampleRate(float preferredSampleRate) {
        
        NSError *audioSessionError = nil;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        
        // disable active
        [session setActive:NO error:&audioSessionError];
        if (audioSessionError) {
            NSLog(@"Error %ld, %@", (long)audioSessionError.code, audioSessionError.localizedDescription);
        }
        
        // set category
        [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionAllowBluetooth|AVAudioSessionCategoryOptionMixWithOthers|AVAudioSessionCategoryOptionDefaultToSpeaker error:&audioSessionError];
        if(audioSessionError) {
            NSLog(@"Error %ld, %@", (long)audioSessionError.code, audioSessionError.localizedDescription);
        }
        
        // try to set the preferred sample rate
        [session setPreferredSampleRate:preferredSampleRate error:&audioSessionError];
        if(audioSessionError) {
            NSLog(@"Error %ld, %@", (long)audioSessionError.code, audioSessionError.localizedDescription);
        }
        
        // *** Activate the audio session before asking for the "current" values ***
        [session setActive:YES error:&audioSessionError];
        if (audioSessionError) {
            NSLog(@"Error %ld, %@", (long)audioSessionError.code, audioSessionError.localizedDescription);
        }
        ofLogNotice() << "AVSession samplerate: " << session.sampleRate << ", I/O buffer duration: " << session.IOBufferDuration;
        
        // our actual samplerate, might be differnt eg 48k on iPhone 6S
        return session.sampleRate;
    }
    
    Boolean ofApp::instrumentIsOff() {
        return !instrumentOn;
    }
    
    void ofApp::helpLayerScript() {
        switch (scene) {
            case (MENU_SCENE) :
            case (SELECT_SAMPLE_SCENE) :
                currentHelpState2 = -1;
                /*helpTimer2 = (helpTimer2 + 1) % (THREE_SECONDS * 4);
                 currentHelpState2 = helpTimer2 / THREE_SECONDS;
                 if (currentHelpState2 == 3) {
                 helpTimer2 = 0;
                 currentHelpState2 = -1;
                 helpOn2 = false;
                 }*/
                //ofLog(OF_LOG_VERBOSE, "timer %i", currentHelpState);
                break;
            case (SAVE_EXIT_PART_1):
                
                break;
            case (GAME_SCENE) :
                helpTimer = (helpTimer + 1) % (THREE_SECONDS * 19);
                currentHelpState = helpTimer / THREE_SECONDS;
                if (currentHelpState == 18) {
                    helpTimer = 0;
                    currentHelpState = -1;
                    helpOn = false;
                }
                //ofLog(OF_LOG_VERBOSE, "timer %i", currentHelpState);
                break;
        }
    }
    
    void ofApp::helpLayerDisplay(int n) {
        if (scene == GAME_SCENE) {
            ofSetColor(0, 0, 0);
            int yOffset = circles[0]->w/2+helpTextHeight*(1+device*.8)*deviceScale;  // add space if tablet
            
            int x1;
            int y1;
            switch (n) {
                case -1:
                    break;
                case 0:
                    drawHelpString("These are fluxum", screenW/2, screenH/2-40, 0, 0);
                    //helpFont.drawString("These are fluxum", screenW/2-helpFont.stringWidth("These are fluxum")/2, screenH/2);
                    break;
                case 1:
                    drawHelpString("These are fluxum", screenW/2, screenH/2-40, 0, 0);
                    //helpFont.drawString("These are fluxum", screenW/2-helpFont.stringWidth("These are fluxum")/2, screenH/2);
                    for (int i=0; i<circles.size()-1; i++) {
                        drawHelpString("fluxum", circles[i]->x, circles[i]->y, yOffset, 0);
                        /*helpFont.drawString("fluxum", circles[i]->x-helpFont.stringWidth("fluxum")/2, circles[i]->y+circles[i]->w/2+25*deviceScale);*/
                    }
                    break;
                case 2:
                    drawHelpString("Fluxum are sound loopers", screenW/2, screenH/2-40, 0, 0);
                    //helpFont.drawString("Fluxum are sound loopers", screenW/2-helpFont.stringWidth("Fluxum are sound loopers")/2, screenH/2);
                    break;
                case 3:
                case 4:
                case 5:
                    drawHelpString("Fluxum are sound loopers", screenW/2, screenH/2-40, 0, 0);
                    for (int i=0; i<circles.size()-1; i++) {
                        drawHelpString("spin me", circles[i]->x, circles[i]->y, yOffset, 0);
                    }
                    break;
                case 6:
                case 7:
                case 8:
                    for (int i=0; i<circles.size()-1; i++) {
                        drawHelpString("spin me", circles[i]->x, circles[i]->y, yOffset, 0);
                        drawHelpString("backward", circles[i]->x, circles[i]->y, yOffset, 1);
                        /*helpFont.drawString("spin me", circles[i]->x-helpFont.stringWidth("spin me")/2, circles[i]->y+circles[i]->w/2+20*deviceScale);
                         helpFont.drawString("backward", circles[i]->x-helpFont.stringWidth("backward")/2, circles[i]->y+circles[i]->w/2+20*deviceScale + helpTextHeight+4);
                         */
                    }
                    break;
                case 9:
                    drawHelpString("(The white one is", circles[circles.size()-1]->x, circles[circles.size()-1]->y, yOffset, 0);
                    drawHelpString("a reverb effect)", circles[circles.size()-1]->x, circles[circles.size()-1]->y, yOffset, 1);
                    break;
                case 10:
                case 11:
                    arrowLeft.draw(45*retinaScaling, screenH-20*retinaScaling, 20*retinaScaling, 22*retinaScaling );
                    x1 = 4*retinaScaling+(helpFont.stringWidth("them to move around"))/2;
                    y1 = screenH-25*retinaScaling-helpTextHeight*2;
                    drawHelpString("This button allows", x1, y1, 0, 0);
                    drawHelpString("them to move around", x1, y1, 0, 1);
                    break;
                case 12:
                case 13:
                    arrow.draw(screenW-45*retinaScaling, screenH-20*retinaScaling, 20*retinaScaling, 22*retinaScaling );
                    x1 = screenW-(helpFont.stringWidth("(don't leave yet)"))/2-8*retinaScaling;
                    y1 = screenH-25*retinaScaling-helpTextHeight*3;
                    drawHelpString("This button", x1, y1, 0, 0);
                    drawHelpString("exits to menu", x1, y1, 0, 1);
                    drawHelpString("(don't leave yet)", x1, y1, 0, 2);
                    /*helpFont.drawString("This button", screenW-helpFont.stringWidth("(don't leave yet)")-4, screenH-70);
                     helpFont.drawString("exits to menu", screenW-helpFont.stringWidth("(don't leave yet)")-4, screenH-55);
                     helpFont.drawString("(don't leave yet)", screenW-helpFont.stringWidth("(don't leave yet)")-4, screenH-40);*/
                    break;
                case 14:
                case 15:
                    for (int i=0; i<2; i++) {
                        drawHelpString("Touch two and", circles[i]->x, circles[i]->y, yOffset, 0);
                        drawHelpString("bring together", circles[i]->x, circles[i]->y, yOffset, 1);
                        drawHelpString("to join", circles[i]->x, circles[i]->y, yOffset, 2);
                    }
                    break;
                case 16:
                case 17:
                    drawHelpString("Double tap", circles[1]->x, circles[1]->y, yOffset, 0);
                    drawHelpString("while sleeping", circles[1]->x, circles[1]->y, yOffset, 1);
                    drawHelpString("to change sound", circles[1]->x, circles[1]->y, yOffset, 2);
                    break;
            }
            ofSetColor(255, 255, 255);
        }
        
        if (scene == SELECT_SAMPLE_SCENE) {
            ofSetColor(0, 0, 0);
            int yOffset = circles[0]->w/2+helpTextHeight*(1+device*.8)*deviceScale;  // add space if tablet
            
            int x1;
            int y1;
            switch (n) {
                case -1:
                    break;
                case 0:
                    drawHelpString("Help1", screenW/2, screenH/2-40, 0, 0);
                    //helpFont.drawString("These are fluxum", screenW/2-helpFont.stringWidth("These are fluxum")/2, screenH/2);
                    break;
                case 1:
                    drawHelpString("Help2", screenW/2, screenH/2-40, 0, 0);
                    //helpFont.drawString("These are fluxum", screenW/2-helpFont.stringWidth("These are fluxum")/2, screenH/2);
                    break;
                case 2:
                    drawHelpString("Help3", screenW/2, screenH/2-40, 0, 0);
                    //helpFont.drawString("Fluxum are sound loopers", screenW/2-helpFont.stringWidth("Fluxum are sound loopers")/2, screenH/2);
                    break;
                case 3:
                    drawHelpString("Help4", screenW/2, screenH/2-40, 0, 0);
                    break;
            }
            ofSetColor(255, 255, 255);
        }
    }
    
    void ofApp::drawHelpString(string s, int x1, int y1, int yOffset, int row) {
        helpFont.drawString(s, x1 - helpFont.stringWidth(s)/2, y1 + yOffset + helpTextHeight * row) ;
    }
    
    //--------------------------------------------------------------
    void ofApp::newMidiMessage(ofxMidiMessage& msg) {
        
        float bend = msg.bytes[1] + msg.bytes[2];
        
        for (int i=0; i < nCircles; i++) {
            if ((msg.status == MIDI_NOTE_ON) && (msg.pitch == midiSaveKeys[i])) {
                midiSaveState[i] = true;
            }
            if ((msg.status == MIDI_NOTE_OFF) && (msg.pitch == midiSaveKeys[i])) {
                midiSaveState[i] = false;
            }
            if ((msg.status == MIDI_NOTE_ON) && (msg.pitch == midiPlayKeys[i])) {
                midiPlayState[i] = true;
                circles[i]->setAngularVelocity(0);
            }
            if ((msg.status == MIDI_NOTE_OFF) && (msg.pitch == midiPlayKeys[i])) {
                midiPlayState[i] = false;
                circles[i]->setAngularVelocity(midiSavedAngularVelocity[i]);
            }
           if ((msg.status == MIDI_PITCH_BEND) && (midiSaveState[i])) {
                // map bend = 0 to 64 -> -8 to 0
                // map bend = 64 to 255 -> 0 to 8
                if (bend < 64) bend = ofMap(bend, 0, 64, -8, 0);
                if (bend >= 64) bend = ofMap(bend, 64, 255, 0, 8);
                midiSavedAngularVelocity[i] = bend;
                circles[i]->setAngularVelocity(bend);
            }
        }
        ofLog(OF_LOG_VERBOSE, msg.toString());
        ofLog(OF_LOG_VERBOSE, "Status %i", msg.status);
        ofLog(OF_LOG_VERBOSE, "Pitch %i", msg.pitch);
        ofLog(OF_LOG_VERBOSE, "Bend %f", bend);
    }
    
    //--------------------------------------------------------------
    void ofApp::midiInputAdded(string name, bool isNetwork) {
        stringstream msg;
        msg << "ofxMidi: input added: " << name << " network: " << isNetwork;
        ofLog(OF_LOG_VERBOSE, msg.str());
        
        // create and open a new input port
        ofxMidiIn *newInput = new ofxMidiIn;
        newInput->openPort(name);
        newInput->addListener(this);
        inputs.push_back(newInput);
    }
    
    //--------------------------------------------------------------
    void ofApp::midiInputRemoved(string name, bool isNetwork) {
        stringstream msg;
        msg << "ofxMidi: input removed: " << name << " network: " << isNetwork << endl;
        ofLog(OF_LOG_VERBOSE, msg.str());
        
        // close and remove input port
        vector<ofxMidiIn*>::iterator iter;
        for(iter = inputs.begin(); iter != inputs.end(); ++iter) {
            ofxMidiIn *input = (*iter);
            if(input->getName() == name) {
                input->closePort();
                input->removeListener(this);
                delete input;
                inputs.erase(iter);
                break;
            }
        }
    }
    
    
