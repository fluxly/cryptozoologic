//  iOS version of Fluxly, the musical physics looper
//
//  Created by Shawn Wallace on 11/14/17.
//  Released April 2018 to the App Store
//  See the LICENSE file for copyright information

#include "ofApp.h"
#import <AVFoundation/AVFoundation.h>
//#import <sys/utsname.h>
#include <string>

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
    ofSetLogLevel("Pd", OF_LOG_VERBOSE);  // see verbose info from Pd

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
    clueOn = true;
    
    for (int i=0; i<numFiles; ++i) {
        if (dir.getName(i) == "menuSettings.xml") {
            firstRun = false;
            clueOn = false;
            helpOn = false;        // turn off help layer if not first run
            helpWasOn = false;
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
    scale_setup();

    
    midiChan = 1; // midi channels are 1-16
    
    // subscribe to receive source names
    pd.subscribe("noplay0");
    pd.subscribe("noplay1");
    pd.subscribe("noplay2");
    pd.subscribe("noplay3");
    pd.subscribe("play0");
    pd.subscribe("play1");
    pd.subscribe("play2");
    pd.subscribe("play3");
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
    
    // Visualizations setup
    
    for (int i=0; i < 5; i++) {
        if (device == PHONE) {
            game2ledX[i] = game2ledX[i] * 0.55f;
        }
        game2ledX[i] = game2ledX[i] * retinaScaling;
    }
    if (device == PHONE) {
        game2ledX[4] = 495 * retinaScaling;
    }
    
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
    timeInGame = 0;
    
    switch (gameId) {
        case 0: currentPatch = pd.openPatch("pd-bytebeat.pd"); break;
        case 1: currentPatch = pd.openPatch("pd-benjolin2.pd"); break;
        case 2: currentPatch = pd.openPatch("pd-irishYeti2.pd"); break;
        case 3: currentPatch = pd.openPatch("pd-vivianLoopBox.pd"); break;
    }
    
    //send screen width for panning calculation in Pd
    pd.sendFloat("screenW", screenW);
    
    ofxXmlSettings gameSettings;
    ofLog(OF_LOG_VERBOSE, ofxiOSGetDocumentsDirectory()+mainMenu->menuItems[gameId]->link);
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
            c->x = gameSettings.getValue("x", 0);
            c->y = gameSettings.getValue("y", 0);
            c->w = gameSettings.getValue("w", 0);
            c->density = gameSettings.getValue("density", 1);
            c->bounce = gameSettings.getValue("bounce", 1);
            c->friction = gameSettings.getValue("friction", 1);
            c->senseType = gameSettings.getValue("senseType", 0);
            c->displayW = c->w;
            c->retinaScale = retinaScaling;
            
            /* Now in toggleHelpBubbles()
             // Add a help bubble
            ofLog(OF_LOG_VERBOSE, "Adding Bubble" + to_string(c->id));
            bubbles.push_back(shared_ptr<FluxlyBubble>(new FluxlyBubble));
            FluxlyBubble * b = bubbles.back().get();
            b->id = gameSettings.getValue("id", 0);
            b->x =  gameSettings.getValue("bx", 0);
            b->y =  gameSettings.getValue("by", 0);
            b->w =  gameSettings.getValue("bw", 0);
            b->h =  gameSettings.getValue("bh", 0);
            b->bLabel = gameSettings.getValue("bLabel", to_string(b->id));
            b->bValue = gameSettings.getValue("bValue", "0");
            */
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
            c->soundWaveStep *= retinaScaling;
            c->soundWaveH *= retinaScaling;
            c->animationStep *=retinaScaling;
            c->displayW *= retinaScaling;
            c->bx =  gameSettings.getValue("bx", 0);
            c->by =  gameSettings.getValue("by", 0);
            c->bw =  gameSettings.getValue("bw", 0);
            c->bh =  gameSettings.getValue("bh", 0);
            c->bLabel = gameSettings.getValue("bLabel", to_string(c->id));
            c->bValue = gameSettings.getValue("bValue", "0");
            
            c->setPhysics(c->density/deviceScale/retinaScaling, c->bounce, c->friction);    // density, bounce, friction
            c->setup(box2d.getWorld(), c->x, c->y, (c->w/2)*deviceScale);
            c->setRotation(gameSettings.getValue("rotation", 0));
            BoxData * bd = new BoxData();
            bd->boxId = c->id;
            c->body->SetUserData(bd);
            c->init();
            
           /* Now in togglehelpBubble()
            b->setPhysics(c->density/deviceScale/retinaScaling, c->bounce, c->friction);
            b->setup(box2d.getWorld(), b->x, b->y, (b->w), (b->h));
            //b->setRotation(gameSettings.getValue("rotation", 0));
            BoxData * bd2 = new BoxData();
            bd2->boxId = b->id;
            b->body->SetUserData(bd2);
            b->init();
            */
            
            gameSettings.popTag();
        }
        ofLog(OF_LOG_VERBOSE, "Done with Circles" );
        
        // Process edges
        gameSettings.popTag();
        gameSettings.pushTag("edges");
        int nEdges = gameSettings.getNumTags("edge");
        
        for(int i = 0; i < nEdges; i++){
            edges.push_back(shared_ptr<ofxBox2dEdge>(new ofxBox2dEdge));
            ofxBox2dEdge * e = edges.back().get();
            gameSettings.pushTag("edge", i);
            e->addVertex(gameSettings.getValue("x1", 0)*retinaScaling, gameSettings.getValue("y1", 0)*retinaScaling);
            e->addVertex(gameSettings.getValue("x2", 0)*retinaScaling, gameSettings.getValue("y2", 0)*retinaScaling);
            e->setPhysics(0.0, 0.0, 0.0);
            e->create(box2d.getWorld());
            gameSettings.popTag();
        }
        gameSettings.popTag();
        ofLog(OF_LOG_VERBOSE, "Done with Edges" );
        
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
    
    if (helpOn) {
        toggleHelpBubbles();
    }
    pd.sendFloat("masterVolume", 1.0);
    gameState = RUN;
}

static bool shouldRemoveJoint(shared_ptr<FluxlyJointConnection>shape) {
    return true;
}
static bool shouldRemoveCircle(shared_ptr<FluxlyCircle>shape) {
    return true;
}
static bool shouldRemoveBubble(shared_ptr<FluxlyBubble>shape) {
    return true;
}
static bool shouldRemoveEdge(shared_ptr<ofxBox2dEdge>shape) {
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
            if ((helpOn != helpWasOn)) {
                toggleHelpBubbles();
            }
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
                if ((globalTick % 60) == 0) timeInGame++;
                
                // only update one pan channel each tick
                int panChannel = globalTick % nCircles;
                pd.sendFloat("pan"+to_string(panChannel), circles[panChannel]->x);
                
                for (int i=0; i<circles.size(); i++) {
                    
                    // damp all the help bubbles
                    if (helpOn) bubbles[i]->setRotation(0);
                    
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
                    //circles[i].get()->checkToSendNote();
                    circles[i].get()->checkToSendControl();
                    if (circles[i]->tempo != 0) midiSavedAngularVelocity[i] = circles[i]->body->GetAngularVelocity();
                    if (circles[i].get()->sendControl) {
                        switch (circles[i].get()->senseType) {
                            case (0): {
                                ofLog(OF_LOG_VERBOSE, "Sent angular of %d: %f", circles[i].get()->id, circles[i]->tempo);
                                pd.sendFloat("control"+to_string(circles[i].get()->id), circles[i]->tempo);
                                if (helpOn) bubbles[i].get()->bValue = to_string((int)(circles[i]->tempo*100));
                                break;
                            }
                            case (1): {
                                float val = ((float)circles[i]->x/screenW);
                                ofLog(OF_LOG_VERBOSE, "Sent x of %d: %f", circles[i].get()->id, val);
                                pd.sendFloat("control"+to_string(circles[i].get()->id), val);
                                if (helpOn) bubbles[i].get()->bValue = formulaStr[(int)(val*94)];   // FIXME: Hardcoded for game 0
                                break;
                            }
                            case (2): {
                                float val = (float)circles[i]->y/screenH;
                                ofLog(OF_LOG_VERBOSE, "Sent y of %d: %f", circles[i].get()->id, val);
                                pd.sendFloat("control"+to_string(circles[i].get()->id), val);
                                if (helpOn) bubbles[i].get()->bValue = to_string((int)(val*17)); // FIXME: HARDCODED FOR GAME 2
                                if ((i > 4) && ((i % 2) == 1)) game2Steps[(i-5)/2] = (int)(val*17);// FIXME: HARDCODED FOR GAME 2
                                break;
                            }
                        }
                        circles[i].get()->sendControl = false;
                    }
                }
            }
            
            switch (currentGame) {
                case 0:
                    pd.readArray("scope0", backgroundScopeArray);
                    break;
                case 1:
                  /*  for (int i=0; i<8; i++) {
                         pd.readArray("scope"+to_string(i), circles[i].get()->scopeArray);
                    }*/
                     pd.readArray("scope7", backgroundScopeArray1);
                    break;
                case 2:
                    pd.readArray("scope4", backgroundScopeArray1);
                    break;
                case 3:
                    break;
            }
            break;
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
                for (int i=0; i<bubbles.size(); i++) {
                    bubbles[i].get()->drawBubbleStem(circles[i].get()->x, circles[i].get()->y);
                    bubbles[i].get()->draw();
                }
            }

            ofSetRectMode(OF_RECTMODE_CENTER);
            ofSetHexColor(0xFFFFFF);
            
            for (int i=0; i<circles.size(); i++) {
                if (midiSaveState[i] || midiPlayState[i]) circles[i].get()->drawBlueGlow();
                circles[i].get()->draw();
            }
            
        /*    for (int i=0; i<joints.size(); i++) {
                ofSetColor( ofColor::fromHex(0xff0000) );
                joints[i]->joint->draw();
            }*/
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
            
            break;
        case SAVE_EXIT_PART_1:
            ofLog(OF_LOG_VERBOSE, "Time in Game: %d sec", timeInGame);
            pd.sendBang("onExit");
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
          /*  for (int i=0; i<joints.size(); i++) {
                ofSetColor( ofColor::fromHex(0xff0000) );
                joints[i]->joint->draw();
            }*/
            ofSetHexColor(0xFFFFFF);
            //screenshot.grabScreen(0, 0, screenW, screenH);
            //saving.draw(screenW/2, screenH/2);
            scene = SAVE_EXIT_PART_2;
            break;
        case SAVE_EXIT_PART_2:
           // screenshot.save( mainMenu->menuItems[currentGame]->filename);
            //ofLog(OF_LOG_VERBOSE, "Screenshot");
            //saveGame();
            destroyGame();
            scene = MENU_SCENE;
           // mainMenu->menuItems[currentGame]->reloadThumbnail();
            break;
    }
    if (firstRun && (scene == GAME_SCENE)) helpLayerDisplay(currentClueState);
}

void ofApp::drawVisualization(int gameId) {
    switch (gameId) {
        case 0: {
            int w = screenH/16;
            ofSetLineWidth(2*retinaScaling*deviceScale);
            for (int i=0; i<256; i++) {
                int t = (int)(backgroundScopeArray[i] * 255);
                int w1 =w*1.5;
                for (int j=0; j<8; j++) {
                    if (((t >> j) & 0x01) == 1) {
                        ofSetColor(255);
                         if (circles[0]->tempo == 0) ofSetColor(0);
                        ofNoFill();
                        ofDrawRectangle(i*w, screenH/2-j*(w)-w/2, w1, w1);
                        ofDrawRectangle(i*w, screenH/2+j*(w)-w/2, w1, w1);
                        ofFill();
                    } else {
                        ofSetColor(0);
                        //dw = 10; dh=10;
                    }
                }
            }
            break;
        }
        case 1: {
            ofSetLineWidth(4*retinaScaling);
            float x1 = 0;
            float h =screenH/2;
            float step = screenW/backgroundScopeArray1.size();
            ofSetColor(ofColor::fromHex(0xffffff));
            
            for (int j = 0; j < backgroundScopeArray1.size()-1; j++) {
                ofDrawLine(x1,backgroundScopeArray1[j]*h+h, x1+step, backgroundScopeArray1[j+1]*h+h);
                x1 += step;
            }
            ofFill();
            break;
        }
        case 2: {
            float y1 = 0;
            float h =screenH/2;
            float w1 = 100*retinaScaling;
            float step = (screenH*retinaScaling)/backgroundScopeArray1.size();
            ofSetLineWidth(2*deviceScale*retinaScaling);
            ofSetColor(ofColor::fromHex(0xffffff));
            ofNoFill();
            for (int j = 0; j < backgroundScopeArray1.size()-1; j++) {
                ofDrawLine(backgroundScopeArray1[j]*w1+game2ledX[4], y1, backgroundScopeArray1[j+1]*w1+game2ledX[4], y1+step);
                y1 += step;
            }
            for (int i=0; i<4; i++) {
                int r =screenH/(game2Steps[i]);
                for (int j=0; j<game2Steps[i]; j++) {
                    ofSetColor(ofColor::fromHex(0xffffff));
                    if (j == currentPulse[i]) {
                        if (currentPulseOn[i] == 1) {
                            ofFill();
                             ofDrawEllipse(game2ledX[i], r * (j+1)-r/2, r, r);
                            ofNoFill();
                        } else {
                            //ofDrawRectangle(game2ledX[i]-r/2, r * (j), r, r);
                            ofDrawEllipse(game2ledX[i], r * (j+1)-r/2, r, r);
                           // ofFill();
                           // ofSetColor(ofColor::fromHex(0x333333));
                           // ofDrawRectangle(game2ledX[i]-r/2, r * (j), r, r);
                           // ofNoFill();
                        }
                    } else {
                        ofDrawRectangle(game2ledX[i]-r/2, r * (j), r, r);
                        //ofDrawEllipse(game2ledX[i], r * (j+1)-r/2, r, r);
                    }
                }
            }
            ofFill();
            break;
        }
    }
}

void ofApp::receiveBang(const std::string& dest) {
    //cout << "OF: bang " << dest << endl;

    if (dest.substr(0, 2) == noChar) {
        int n = stoi(dest.substr(6,1));
        currentPulse[n] = (currentPulse[n]+1) % game2Steps[n];
        currentPulseOn[n] = 0;
       // ofLog(OF_LOG_VERBOSE, "Bang NoPlay %d %d", currentPulse[n], currentPulseOn[n]);
    } else {
        int n = stoi(dest.substr(4,1));
        currentPulse[n] = (currentPulse[n]+1) % game2Steps[n];
        currentPulseOn[n] = 1;
      //  ofLog(OF_LOG_VERBOSE, "Bang Play %d %d", currentPulse[n], currentPulseOn[n]);
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
        outputSettings.setValue("bx", circles[i]->bx/retinaScaling);
        outputSettings.setValue("by", circles[i]->by/retinaScaling);
        outputSettings.setValue("bw", circles[i]->bw/retinaScaling);
        outputSettings.setValue("bh", circles[i]->bh/retinaScaling);
        outputSettings.setValue("bLabel", circles[i]->bLabel);
        outputSettings.setValue("bValue", circles[i]->bValue);
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
    
    pd.closePatch(currentPatch);
    
    for (int i=0; i < circles.size(); i++) {
        pd.sendFloat("toggle"+to_string(circles[i].get()->instrument), 0.0);
    }
    
    for (int i=0; i < joints.size(); i++) {
        // remove joint from world
        joints[i]->joint->destroy();
    }
    
    for (int i=0; i < edges.size(); i++) {
        // remove edge from world
        edges[i]->destroy();
    }
    
    for (int i=0; i < circles.size(); i++) {
        delete (BoxData *)circles[i]->body->GetUserData();
        circles[i]->destroy();
    }
    
    for (int i=0; i < bubbles.size(); i++) {
        //delete (BoxData *)bubbles[i]->body->GetUserData();
        bubbles[i]->destroy();
    }
    
    ofRemove(joints, shouldRemoveJoint);
    ofRemove(edges, shouldRemoveEdge);
    ofRemove(circles, shouldRemoveCircle);
    ofRemove(bubbles, shouldRemoveBubble);
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
                    helpWasOn = helpOn;
                    helpOn = !helpOn;
                    startTouchId = -1;
                    startTouchX = 0;
                    startTouchY = 0;
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
                currentClueState = -1;
                clueTimer = (clueTimer + 1) % (THREE_SECONDS * 4);
                currentClueState = clueTimer / THREE_SECONDS;
                if (currentClueState == 1) {
                    clueTimer = 0;
                    currentClueState = -1;
                    clueOn = false;
                    cluesSeen++;
                }
                ofLog(OF_LOG_VERBOSE, "timer %i", currentClueState);
                break;
            case (GAME_SCENE) :
                currentClueState = -1;
                clueTimer = (clueTimer + 1) % (THREE_SECONDS * 4);
                 currentClueState = clueTimer / THREE_SECONDS;
                 if (currentClueState == 3) {
                     clueTimer = 0;
                     currentClueState = -1;
                     clueOn = false;
                     cluesSeen++;
                 }
                ofLog(OF_LOG_VERBOSE, "timer %i", currentClueState);
                break;
            case (SAVE_EXIT_PART_1):
                
                break;
        }
    }
    
    void ofApp::toggleHelpBubbles() {
        // Called once when/after help button changes state
        helpWasOn = helpOn;
        if (helpOn) {
            for (int i=0; i<circles.size(); i++) {
                ofLog(OF_LOG_VERBOSE, "Adding Bubble" + to_string(circles[i]->id));
                bubbles.push_back(shared_ptr<FluxlyBubble>(new FluxlyBubble));
                FluxlyBubble * b = bubbles.back().get();

                bubbles[i]->x =  circles[i]->bx * retinaScaling;
                bubbles[i]->y =  circles[i]->by * retinaScaling;
                bubbles[i]->w =  circles[i]->bw * retinaScaling;
                bubbles[i]->h =  circles[i]->bh * retinaScaling;
                bubbles[i]->bLabel = circles[i]->bLabel;
                bubbles[i]->bValue = circles[i]->bValue;
                bubbles[i]->setPhysics(circles[i]->density/deviceScale/retinaScaling, circles[i]->bounce, circles[i]->friction);
                bubbles[i]->setup(box2d.getWorld(), bubbles[i]->x, bubbles[i]->y, (bubbles[i]->w), (bubbles[i]->h));
                //b->setRotation(gameSettings.getValue("rotation", 0));
                bubbles[i]->init();
                

                if ((currentGame == 0) && (i == 2)) {
                    // FIXME: move to game object init at some point
                    bubbles[i]->fontSize = 0;
                    bubbles[i]->bValue = formulaStr[(int)((float)(circles[i]->x/screenW)*94)];
                }
                if (currentGame == 0) {
                    if (i != 2) {
                        shared_ptr<FluxlyJointConnection> jc = shared_ptr<FluxlyJointConnection>(new FluxlyJointConnection);
                        ofxBox2dJoint *j = new ofxBox2dJoint;
                        j->setup(box2d.getWorld(), circles[i].get()->body, bubbles[i].get()->body);
                        if (device == PHONE) j->setLength(circles[i]->w/2 + 100*deviceScale);
                        if (device == TABLET) j->setLength(circles[i]->w/2 + 100*deviceScale);
                        jc.get()->id1 = i;
                        jc.get()->id2 = i;
                        jc.get()->joint = j;
                        joints.push_back(jc);
                    }
                }
            }
        } else {
            for (int i=0; i < joints.size(); i++) {
                // remove joint from world
                joints[i]->joint->destroy();
            }
           for (int i=0; i < bubbles.size(); i++) {
               ofLog(OF_LOG_VERBOSE, "Destroying Bubble" + to_string(circles[i]->id));
               
                //delete (BoxData *)bubbles[i]->body->GetUserData();
                bubbles[i]->destroy();
            }
            ofRemove(joints, shouldRemoveJoint);
            ofRemove(bubbles, shouldRemoveBubble);
        }
    }
    
    void ofApp::helpLayerDisplay(int n) {
        if (scene == MENU_SCENE) {
            ofSetColor(255, 255, 255);
            drawHelpString("(Scroll down for more)", screenW/2, screenH/2-40, 0, 0);
        }
        if (scene == GAME_SCENE) {
            ofSetColor(0, 0, 0);
            int yOffset = circles[0]->w/2+helpTextHeight*(1+device*.8)*deviceScale;  // add space if tablet
            
            int x1;
            int y1;
            switch (n) {
                case -1:
                    break;
                case 0:
                    // e.g. drawHelpString("These are fluxum", screenW/2, screenH/2-40, 0, 0);
                   //
                    break;
                case 1:
                    break;
                case 2:
                    break;
                case 3:
                case 4:
                case 5:
                    break;
                case 6:
                case 7:
                case 8:
                    break;
                case 9:
                    break;
                case 10:
                case 11:
                     break;
                case 12:
                case 13:
                    break;
                case 14:
                case 15:
                    break;
                case 16:
                case 17:
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
    
    
