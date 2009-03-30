//
//  AQHarnessController.m
//  BackRowTestHarness
//
//  Created by Alan Quatermain on 06/05/07.
//  Copyright 2007 AwkwardTV. All rights reserved.
//

#import "AQHarnessController.h"
#import "AQIRRemoteMonitor.h"
#import "AQFakeMediaProvider.h"
#import "AQNSWindowRenderer.h"
#import "AQGLViewScene.h"
#import "QuIntroMovieController.h"

#import <AppleTV/ATVSettingsFacade.h>
#import <Quartz/Quartz.h>       // for QCPatch
#import <objc/objc-class.h>

extern NSBundle * backRowFramework( void );
extern void QTSetProcessProperty( OSType type, OSType var, unsigned length, void * info );
extern NSString * const kBRPairRemoteNotification;
extern CGImageRef CreateImageForURL( NSURL * url );
extern NSData * CreateBitmapDataFromImage( CGImageRef image, int width, int height );

static AQHarnessController * __sharedHarnessController = nil;

static void TweakMainMenu( BOOL scrollable )
{
    static IMP __origIMP = (IMP)0;

    Method mmMethod = class_getInstanceMethod( [BRMainMenuController class],
                                               @selector(listFrameForBounds:) );
    if ( mmMethod != NULL )
    {
        if ( __origIMP == (IMP)0 )
            __origIMP = mmMethod->method_imp;

        if ( scrollable )
        {
            Method mcMethod = class_getInstanceMethod( [BRMenuController class],
                @selector(listFrameForBounds:) );
            if ( mcMethod != NULL )
                mmMethod->method_imp = mcMethod->method_imp;
        }
        else
        {
            mmMethod->method_imp = __origIMP;
        }
    }
}

#pragma mark -

static void AQBRUncaughtExceptionHandler( NSException * exception )
{
    [BRPostedAlertController postModalAlertNotificationOfType: kBRFatalExceptionOccurred
                                                     withInfo: exception];
}

#pragma mark -

@interface AQHarnessController (BackRowInitialization)

- (BRLayerController *) _introMovieController;
- (void) _showStartupUI;
- (void) _showMainMenu;

@end

@interface AQHarnessController (Notifications)

- (void) _appLaunched: (NSNotification *) note;
- (void) _appWillHide: (NSNotification *) note;
- (void) _appDidReveal: (NSNotification *) note;
- (void) _windowResized: (NSNotification *) note;
- (void) _introMovieComplete: (NSNotification *) note;

@end

@interface AQHarnessController (QuickTimeFeatures)

- (void) _enableQTRingBuffer;

@end

@interface AQHarnessController (Registration)

- (void) _registerPlayers;
- (void) _registerMediaProviders;
- (void) _checkReadyState: (NSTimer *) timer;
- (void) _registerPatches;

@end

@interface AQHarnessController (SceneManagement)

- (void) _makeScene: (AQNSWindowRenderer *) renderer;
- (void) _destroyScene;

@end

#pragma mark -

@implementation AQHarnessController

+ (AQHarnessController *) sharedController
{
    if ( __sharedHarnessController == nil )
        __sharedHarnessController = [[AQHarnessController alloc] init];

    return ( __sharedHarnessController );
}

- (id) init
{
    if ( [super init] == nil )
        return ( nil );

    NSSetUncaughtExceptionHandler( AQBRUncaughtExceptionHandler );
    EnterMovies( );

    // before loading any external code, ensure we have the mein menu's
    // real implementation of listFrameForBounds: cached
    TweakMainMenu( NO );

    // an appliance may change that itself...
    [[BRApplianceManager sharedManager] loadAppliances];

    [self _registerPlayers];
    [self _registerPatches];
    [self _enableQTRingBuffer];

    NSNotificationCenter * center = [NSNotificationCenter defaultCenter];
    
    [center addObserver: self
               selector: @selector(_appLaunched:)
                   name: AQNSWindowRendererLoaded
                 object: nil];
    [center addObserver: self
               selector: @selector(_appWillHide:)
                   name: NSApplicationWillHideNotification
                 object: nil];
    [center addObserver: self
               selector: @selector(_appDidReveal:)
                   name: NSApplicationDidUnhideNotification
                 object: nil];
    
    _stack = [[BRControllerStack alloc] init];

    return ( self );
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [_stack release];
    [self tearDownRemoteHID];
    [self _destroyScene];

    [_rootItem release];

    [super dealloc];
}

- (void) setupRemoteHID
{
    if ( _hidMonitor == nil )
    {
        _hidMonitor = [[AQIRRemoteMonitor alloc] init];

        id obj = (id) CFPreferencesCopyValue( CFSTR("UIDFilter"),
                                              CFSTR("com.apple.driver.AppleIRController"),
                                              kCFPreferencesCurrentUser,
                                              kCFPreferencesCurrentHost );
        [obj autorelease];

        if ( [obj isKindOfClass: [NSNumber class]] == NO )
            return;
        if ( [obj intValue] < 0 )
            return;

        NSDictionary * userInfo = [NSDictionary dictionaryWithObject: [NSNumber numberWithBool: NO]
                                                              forKey: obj];
        [[NSNotificationCenter defaultCenter] postNotificationName: kBRPairRemoteNotification
                                                            object: nil
                                                          userInfo: userInfo];
    }
}

- (void) tearDownRemoteHID
{
    if ( _hidMonitor != nil )
    {
        [_hidMonitor release];
        _hidMonitor = nil;
    }
}

- (BOOL) brEventAction: (BREvent *) event
{
    BOOL result = NO;

    @try
    {
        result = [_stack brEventAction: event];

        if ( (result == NO) && (_rootItem != nil) )
        {
            switch ( [event pageUsageHash] )
            {
                case kBREventHoldMenu:
                case kBREventTapMenu:
                case kBREventPageAdvanced|kBREventBasicMenu:
                {
                    if ( [event usage] != kBREventBasicMenu )
                    {
                        [RUISoundHandler playSound: 3];
                        [_stack popToControllerWithLabel: @"AQTestHarnessRootController"];
                        result = YES;
                    }
                    else
                    {
                        id controller = [_stack peekController];
                        if ( [controller isLabelled: @"AQTestHarnessRootController"] )
                        {
                            [RUISoundHandler playSound: 16];
                        }
                        else
                        {
                            [RUISoundHandler playSound: 2];
                            [_stack popController];
                            [[_renderer scene] renderScene];
                        }
                    }

                    result = YES;
                    break;
                }

                default:
                    break;
            }
        }
    }
    @catch(NSException * exception)
    {
        [BRPostedAlertController postModalAlertNotificationOfType: kBRFatalExceptionOccurred
                                                         withInfo: exception];
    }

    return ( result );
}

- (BOOL) setRootItemByPath: (NSString *) path
{
    if ( path == nil )
    {
        [_rootItem release];
        _rootItem = nil;
        return ( YES );     // successfully set to main menu
    }

    NSBundle * bundle = [NSBundle bundleWithPath: path];
    if ( bundle == nil )
        return ( NO );

    Class cls = [bundle principalClass];
    if ( cls == Nil )
        return ( NO );

    if ( [cls conformsToProtocol: @protocol(BRApplianceProtocol)] == NO )
        return ( NO );

    NSMutableDictionary * dict = [NSMutableDictionary dictionaryWithDictionary: [bundle infoDictionary]];

    [dict setObject: bundle forKey: @"FRApplianceBundle"];
    [dict setObject: [bundle bundleIdentifier] forKey: @"CFBundleIdentifier"];

    NSString * locName = [BRLocalizedStringManager localizedStringForKey: @"CFBundleName"
                                                                  inFile: @"infoPlist"
                                                              fromBundle: bundle];
    if ( locName != nil )
        [dict setObject: locName forKey: @"FRApplianceName"];

    NSString * str = [bundle objectForInfoDictionaryKey: @"FRApplianceIconPath"];
    if ( str == nil )
        str = @"ApplianceIcon.png";
    str = [bundle pathForResource: str ofType: nil];
    if ( str != nil )
        [dict setObject: str forKey: @"FRApplianceIconPath"];

    NSArray * a = [bundle objectForInfoDictionaryKey: @"FRApplianceSupportedMediaTypes"];
    if ( a != nil )
        [dict setObject: [NSSet setWithArray: a] forKey: @"FRApplianceSupportedMediaTypes"];

    _rootItem = [dict copy];

    return ( YES );
}

- (void) setSceneShowsFPS: (BOOL) flag
{
    _showFPS = flag;
    if ( _renderer != nil )
        [[_renderer scene] showFPS: flag];
}

- (void) setScenePrintsRenderTree: (BOOL) flag
{
    _printTree = flag;
    if ( _renderer != nil )
        [[_renderer scene] printTree: flag];
}

- (void) setSceneShowsSafeAreas: (BOOL) flag
{
    _showSafeAreas = flag;
    if ( _renderer != nil )
        [[_renderer scene] showSafeRegions: flag];
}

- (void) setMainMenuFixEnabled: (BOOL) flag
{
    TweakMainMenu( flag );
}

@end

@implementation AQHarnessController (BackRowInitialization)

- (BRLayerController *) _introMovieController
{
    NSError * error = nil;
    BRMediaPlayer * player = [BRMediaPlayerManager playerForContentType: 1 error: &error];
    if ( error != nil )
        return ( nil );

    NSString * path = [backRowFramework( ) pathForResource: @"Intro" ofType: @"mov"];
    if ( path == nil )
        return ( nil );

    BRSimpleMediaAsset * asset = [[BRSimpleMediaAsset alloc] initWithMediaURL: [NSURL fileURLWithPath: path]];
    [player setMedia: asset error: &error];
    [asset release];

    if ( error != nil )
        return ( nil );

    QuIntroMovieController * obj = [QuIntroMovieController layerControllerWithScene: [_renderer scene]];
    [obj setVideoPlayer: player];
    [obj setAllowsResume: NO];

    return ( obj );
}

- (void) _showStartupUI
{
    BOOL skipIntroMovie = [[RUIPreferences sharedFrontRowPreferences] boolForKey: kRUISkipIntroMovie
                           withValueForMissingPrefs: NO];

    if ( skipIntroMovie == NO )
    {
        // check the environment
        char * env = getenv( "BDKSkipIntroMovie" );
        if ( env != NULL )
        {
            NSLog( @"Got BDKSkipIntroMovie = %s", env );

            NSString * str = [NSString stringWithUTF8String: env];
            if ( [str caseInsensitiveCompare: @"YES"] == NSOrderedSame )
                skipIntroMovie = YES;
            else if ( [str intValue] == 1 )
                skipIntroMovie = YES;
        }
        else
        {
            NSLog( @"BDKSkipIntroMovie = NULL" );
        }
    }

    if ( skipIntroMovie == NO )
    {
        id controller = [self _introMovieController];
        if ( controller != nil )
        {
            [_stack pushController: controller];
            [[NSNotificationCenter defaultCenter] addObserver: self
                                                     selector: @selector(_introMovieComplete:)
                                                         name: kQuIntroMovieControllerWasPopped
                                                       object: nil];
        }
        else
        {
            skipIntroMovie = YES;
        }
    }

    if ( skipIntroMovie )
        [self _registerMediaProviders];
}

- (void) _showMainMenu
{
    if ( _rootItem == nil )
    {
        // ensure the appliances are loaded, even if the contents of
        // the folder has changed (due to ATV Loader, perhaps)
        [[BRApplianceManager sharedManager] loadAppliances];

        [[BRMusicStore sharedInstance] musicStoreRootCollection];

        BRMainMenuController * obj = [[BRMainMenuController alloc] initWithScene: [_renderer scene]
                                      delegate: nil];
        [_stack pushController: obj];
        [obj release];
    }
    else
    {
        NSBundle * bundle = [_rootItem objectForKey: @"FRApplianceBundle"];
        id app = [[[bundle principalClass] alloc] init];
        if ( app == nil )
        {
            [[BRAppManager sharedApplication] terminate];
            return;
        }

        // this is autoreleased
        id obj = [app applianceControllerWithScene: [_renderer scene]];
        if ( obj == nil )
        {
            [[BRAppManager sharedApplication] terminate];
            return;
        }

        if ( [obj conformsToProtocol: @protocol(BRApplianceControllerIconProtocol)] )
        {
            NSString * iconPath = [_rootItem objectForKey: @"FRApplianceIconPath"];
            if ( iconPath != nil )
            {
                CGImageRef image = CreateImageForURL( [NSURL fileURLWithPath: iconPath] );
                if ( image != NULL )
                {
                    struct BRBitmapDataInfo info = { GL_RGBA, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, 512, 512 };
                    BRRenderContext * context = [[_renderer scene] resourceContext];

                    NSData * data = CreateBitmapDataFromImage( image, info.width, info.height );
                    BRBitmapTexture * icon = [[BRBitmapTexture alloc] initWithBitmapData: data
                                              bitmapInfo: &info context: context mipmap: YES];
                    [data release];

                    [obj setApplianceIcon: icon];
                    [icon release];

                    CFRelease( image );
                }
            }
        }

        [obj addLabel: @"AQTestHarnessRootController"];
        [_stack pushController: obj];
    }
}

@end

@implementation AQHarnessController (Notifications)

- (void) _appLaunched: (NSNotification *) note
{
    [self _makeScene: (AQNSWindowRenderer *) [note object]];
    [_renderer displayOnline];
}

- (void) _appStopped: (NSNotification *) note
{
    [_renderer displayOffline];
    [_renderer release];
    _renderer = nil;
}

- (void) _appWillHide: (NSNotification *) note
{
    [_renderer displayOffline];
}

- (void) _appDidReveal: (NSNotification *) note
{
    [[_renderer scene] renderScene];
}

- (void) _windowResized: (NSNotification *) note
{
    [_renderer displayCanvasChanged];
    [_stack resizeControllers];
    [[_renderer scene] renderScene];
}

- (void) _introMovieComplete: (NSNotification *) note
{
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                    name: kQuIntroMovieControllerWasPopped
                                                  object: nil];
    [self _registerMediaProviders];
}

@end

@implementation AQHarnessController (QuickTimeFeatures)

- (void) _enableQTRingBuffer
{
    if ( [[RUIPreferences sharedFrontRowPreferences] boolForKey: @"DisableRingBuffer"] )
        return;

    BOOL enabled = YES;
    QTSetProcessProperty( 'qges', 'htra', 1, &enabled );

    unsigned long long size = [ATVSettingsFacade mediaReservedStreamingBufferBytes];
    QTSetProcessProperty( 'dhlr', 'dcsm', 8, &size );

    BOOL async = [[RUIPreferences sharedFrontRowPreferences] boolForKey: @"EnableRingBufferAsyncLoading"];
    QTSetProcessProperty( 'qges', 'alht', 1, &async );
}

@end

@implementation AQHarnessController (Registration)

- (void) _registerPlayers
{
    // no music player -- that's implemented in the Finder app
    NSError * error = nil;

    [BRMediaPlayerManager registerPlayerClass: [BRPhotoPlayer class]
                                      forType: 3
                       allowMultipleInstances: NO
                                        error: &error];
    [BRMediaPlayerManager registerPlayerClass: [BRQTKitVideoPlayer class]
                                      forType: 1
                       allowMultipleInstances: YES
                                        error: &error];
}

- (void) _registerMediaProviders
{
    static BOOL _initializedProviders = NO;

    BRMediaHost * host = [[BRMediaHost mediaHosts] objectAtIndex: 0];

    if ( !_initializedProviders )
    {
        // make sure this is initialized
        (void) [[BRMusicStore sharedInstance] musicStoreRootCollection];

        // okay, so, we need to install at least one provider which will
        // post a 'loaded' notification, so we'll use our fake one which
        // will pretend to cover everything done by the
        // MEITunesMediaProvider and the MEIPhotoMediaProvider
        BRBaseMediaProvider * provider = [[AQFakeMediaProvider alloc] init];
        [host addMediaProvider: provider];
        [provider release];

        _initializedProviders = YES;
    }

    // wait for the host to load its stuff...
    [NSTimer scheduledTimerWithTimeInterval: 0.01
                                     target: self
                                   selector: @selector(_checkReadyState:)
                                   userInfo: nil
                                    repeats: YES];

    [host postEvent: [BRMediaHostEvent mount]];
}

- (void) _checkReadyState: (NSTimer *) timer
{
    BRMediaHostState * state = [[[BRMediaHost mediaHosts] objectAtIndex: 0] state];
    if ( state != [BRMediaHostState mounted] )
        return;

    [timer invalidate];
    [self _showMainMenu];
}

- (void) _registerPatches
{
    [QCPatch loadPlugInsInFolder: [[[NSBundle mainBundle] bundlePath]
                                   stringByAppendingPathComponent: @"Contents/Patches"]];
}

@end

@implementation AQHarnessController (SceneManagement)

- (void) _makeScene: (AQNSWindowRenderer *) renderer
{
    if ( _renderer != nil )
        return;
/*
    if ( [[BRDisplayManager sharedManager] displayOnline] == NO )
    {
        NSLog( @"No display online, so I can't create the scene" );
        return;
    }
*/
    NSLog( @"Making a new scene" );

    //_renderer = [[AQWindowRenderer alloc] init];
    _renderer = [renderer retain];

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(_windowResized:)
                                                 name: NSWindowDidResizeNotification
                                               object: [renderer window]];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(_appStopped:)
                                                 name: AQNSWindowRendererGoingAway
                                               object: renderer];

    AQGLViewScene * scene = (AQGLViewScene *) [_renderer scene];
    BRRootLayer * root = [[BRRootLayer alloc] initWithScene: scene];
    [scene setRoot: root];
    [root release];

    [scene printTree: _printTree];
    [scene showFPS: _showFPS];
    [scene showSafeRegions: _showSafeAreas];

//    [self _displayOnline: nil];
    [self _showStartupUI];

    //[_renderer displayOnline];
    [_renderer orderIn];
    [scene renderScene];
}

- (void) _destroyScene
{
    [_renderer orderOut];
    [_renderer release];
    _renderer = nil;
}

@end
