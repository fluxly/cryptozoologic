//
//
//

#import "MyAppDelegate.h"
#import "ofApp.h"

static NSString *const AUDIOBUS_API_KEY= @"H4sIAAAAAAAAA2WOy47CMAxF/8VrIJRXpW7nMwhCbmpKNG0TOfGIDOLfMaibGbb3+N7jO9Atei7QQLXf1btqc6hrWEArUzfQecKRFH1xiTn8hjCE3jvFwsM5uSu9qftDl9VqvULpfGglNdZYo/cxcE7QHO+QS3x1ULjXfN6/DHLDERv339NRcuxj9mH6EClO0s57QfJGgxEnuaDLwsRzQdMf4vReqB6nBfhOiTWZRv0KuSyZep8y48tizTcVa7br7QEeTyGAQJUdAQAA:WcLug3D/1Aak8vh/SvGbPq6lv8JkQdxMw/0qkl12ccjQfOI7L8kEDkLPw9qqOYgYiEHnHZ1+xYmEmhyLpM35wqRrHXWbk6PsgHKm8BWpF+wAC/mRnFoMP/aDlzHSFclh";

@implementation MyAppDelegate 

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // ofSetLogLevel(OF_LOG_VERBOSE); 
    ofLog(OF_LOG_VERBOSE, "Started App Delegate");
   
    [super applicationDidFinishLaunching:application];

    ofApp *app = new ofApp();
    self.glViewController = [[ofxiOSViewController alloc] initWithFrame:[[UIScreen mainScreen] bounds] app:app ];
    [self.window setRootViewController:self.glViewController];
    ofLog(OF_LOG_VERBOSE, "Set Orientation");
    ofOrientation requested = ofGetOrientation();
    UIInterfaceOrientation interfaceOrientation;
    interfaceOrientation = UIInterfaceOrientationLandscapeLeft;
    switch (requested) {
        case OF_ORIENTATION_DEFAULT:
            interfaceOrientation = UIInterfaceOrientationLandscapeLeft;
            break;
        case OF_ORIENTATION_180:
            interfaceOrientation = UIInterfaceOrientationLandscapeRight;
            break;
        case OF_ORIENTATION_90_RIGHT:
            interfaceOrientation = UIInterfaceOrientationLandscapeLeft;
            break;
        case OF_ORIENTATION_90_LEFT:
            interfaceOrientation = UIInterfaceOrientationLandscapeRight;
            break;
        case OF_ORIENTATION_UNKNOWN:
            interfaceOrientation = UIInterfaceOrientationLandscapeLeft;
            break;
    }
    ofLog(OF_LOG_VERBOSE, "Rotate to portrait");
    [self.glViewController rotateToInterfaceOrientation:UIInterfaceOrientationLandscapeLeft animated:false];
    ofLog(OF_LOG_VERBOSE, "Set up audio stream");
    app->setupAudioStream();
    SoundOutputStream *stream = app->getSoundStream()->getSoundOutStream();
    /* You need to set the AudioSession settings again, setupSoundStream() I think sets it to AVAudioSessionCategoryPlayAndRecord? In any case, without calling this after setupSoundStream i could not start from within Audiobus without sound issues. */

    [[AVAudioSession sharedInstance] setActive:YES error:NULL];
    AudioOutputUnitStart(stream.audioUnit);
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayAndRecord
                                     withOptions: AVAudioSessionCategoryOptionAllowBluetooth|
                                                  AVAudioSessionCategoryOptionMixWithOthers|
                                                  AVAudioSessionCategoryOptionDefaultToSpeaker
                                     error:  NULL];
   
    self.audiobusController = [[ABAudiobusController alloc] initWithApiKey:AUDIOBUS_API_KEY];

    self.audiobusSender = [[ABAudioSenderPort alloc]
                           initWithName:@"fluxama:cryptozoologic"
                                   title:NSLocalizedString(@"cryptozoologic", @"")
                                   audioComponentDescription:(AudioComponentDescription) {
                                        .componentType = kAudioUnitType_RemoteGenerator,
                                        .componentSubType = 'out2', // Note single quotes
                                        //this needs to match the audioComponents entry
                                        .componentManufacturer = 'cryp' }
                                   audioUnit:stream.audioUnit];
    [_audiobusController addAudioSenderPort:_audiobusSender];
    
    if (IS_IPHONE) self.audiobusController.connectionPanelPosition = ABConnectionPanelPositionRight;
    if (IS_IPAD) self.audiobusController.connectionPanelPosition = ABConnectionPanelPositionTop;
    ofLog(OF_LOG_VERBOSE, "Finished Audiobus Controller");
    return YES;
    
}

//- (void)applicationDidEnterBackground:(UIApplication *)application {
-(void)applicationDidEnterBackground:(NSNotification *)notification {
    [ofxiOSGetGLView() stopAnimation];
    glFinish();
    //only continue to generate sound when not connected to anything, maybe this needs a check for inter app audio too, but it works with garageband
    if ((dynamic_cast<ofApp*>(ofGetAppPtr())->instrumentIsOff())
        && !_audiobusController.connected && !_audiobusController.memberOfActiveAudiobusSession) {
       // AudioOutputUnitStop(dynamic_cast<ofApp*>(ofGetAppPtr())->getSoundStream()->getSoundOutStream().audioUnit);
       AudioOutputUnitStop(_audiobusSender.audioUnit);
        [[AVAudioSession sharedInstance] setActive:NO error:NULL];
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    if ((dynamic_cast<ofApp*>(ofGetAppPtr())->instrumentIsOff())) {
      [[AVAudioSession sharedInstance] setActive:YES error:NULL];
      AudioOutputUnitStart(_audiobusSender.audioUnit);
      [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayAndRecord
                                       withOptions:AVAudioSessionCategoryOptionAllowBluetooth|
                                                   AVAudioSessionCategoryOptionMixWithOthers|
                                                   AVAudioSessionCategoryOptionDefaultToSpeaker
                                            error:  NULL];
    }
}

//check for iia connection, i had a problem with fbos not working when started from inside garageband...
-(void) checkIAACon:(int *)iaaCon{
    UInt32 connected;
    UInt32 dataSize = sizeof(UInt32);
    AudioUnitGetProperty(_audiobusSender.audioUnit,
                         kAudioUnitProperty_IsInterAppConnected,
                         kAudioUnitScope_Global, 0, &connected, &dataSize);
    *iaaCon = connected;
}

//can be called from controlThread.h to test for connection
-(void) checkCon:(bool *)iaaCon{
    UInt32 connected;
    UInt32 dataSize = sizeof(UInt32);
    AudioUnitGetProperty(_audiobusSender.audioUnit,
                         kAudioUnitProperty_IsInterAppConnected,
                         kAudioUnitScope_Global, 0, &connected, &dataSize);
    if(_audiobusController.connected || connected == 1){
        *iaaCon = true;
    } else {
        *iaaCon = false;
    }
}
-(void)applicationWillTerminate:(UIApplication *)application {
    [super applicationWillTerminate:application];
}


@end

