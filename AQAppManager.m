//
//  AQAppManager.m
//  BackRowTestHarness
//
//  Created by Alan Quatermain on 15/05/07.
//  Copyright 2007 Alan Quatermain. All rights reserved.
//

#import "AQAppManager.h"
#import "AQNSWindowRenderer.h"
#import <BackRow/BackRow.h>

#import <objc/objc-class.h>
#import <objc/objc-auto.h>  // for objc_collecting_enabled

static AQAppManager * __aqAppManagerSingleton = nil;

static id __sharedApplicationOverride( id self, SEL _cmd )
{
    return ( [AQAppManager sharedApplication] );
}

@implementation AQAppManager

+ (void) initialize
{
    // skanky glue code here: all sorts of stuff in BackRow calls
    // [BRAppManager sharedApplication] to do stuff, so we want that to
    // return an instance of *this* object. So what we'll do is we'll
    // take this early opportunity to do a method-swizzle on the
    // bugger, so it actually calls our version of the function
    Method pMethod = class_getClassMethod( [BRAppManager class], @selector(sharedApplication) );
    if ( pMethod != NULL )
        pMethod->method_imp = (IMP) &__sharedApplicationOverride;
}

+ (id) sharedApplication
{
    if ( __aqAppManagerSingleton == nil )
        __aqAppManagerSingleton = [[AQAppManager alloc] init];

    return ( __aqAppManagerSingleton );
}

- (id) init
{
    if ( [super init] == nil )
        return ( nil );

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(_handleNSAppTermination:)
                                                 name: NSApplicationWillTerminateNotification
                                               object: nil];

    return ( self );
}

- (void) terminate
{
    [_windowRenderer shutdown];
    [_windowRenderer release];
    _windowRenderer = nil;
    [[BRDisplayManager sharedInstance] releaseAllDisplays];
}

- (void) _handleNSAppTermination: (NSNotification *) note
{
    // we only send this lot for real when the system is actually going
    // down...
    _isTerminating = YES;
    NSNotificationCenter * center = [NSNotificationCenter defaultCenter];

    [center postNotificationName: kBRMediaServerLost object: nil];
    [center postNotificationName: kBRApplicationWillTerminateNotification
                          object: self userInfo: nil];
    [center postNotificationName: kBRApplicationTearDownITunesNotification
                          object: self userInfo: nil];

    [_windowRenderer shutdown];
    [_windowRenderer release];
    _windowRenderer = nil;
}

- (void) run
{
    if ( _windowRenderer != nil )
        return;

    _windowRenderer = [[AQNSWindowRenderer loadNewInstanceFromNibNamed: @"BackRow"] retain];

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(_windowClosing:)
                                                 name: AQNSWindowRendererGoingAway
                                               object: _windowRenderer];
}

- (void) _windowClosing: (NSNotification *) note
{
    [_windowRenderer autorelease];
    _windowRenderer = nil;
    [[BRDisplayManager sharedInstance] releaseAllDisplays];
}

/*
- (void) run
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    // this is basically a reproduction of NSApplicationMain, without
    // the call to exit() at the end...
    NSDictionary * infoPlist = [[NSBundle mainBundle] infoDictionary];
    NSString * principalClass = [infoPlist objectForKey: @"NSPrincipalClass"];

    if ( (infoPlist != nil) && (principalClass != nil) )
    {
        // the code actually assumes this is NSApplication or a subclass
        Class principal = NSClassFromString( principalClass );
        if ( principal != Nil )
        {
            id obj = [principal sharedApplication];

            NSString * mainNibFile = [infoPlist objectForKey: @"NSMainNibFile"];
            if ( mainNibFile != nil )
            {
                // load the main nib file
                if ( [NSBundle loadNibNamed: mainNibFile owner: obj] == YES )
                {
                    // release that autorelease pool
                    [pool release];
                    pool = nil;

                    // if using garbage collection, don't do the next step
                    if ( objc_collecting_enabled( ) == NO )
                        [obj _installAutoreleasePoolsOnCurrentThreadIfNecessary];

                    // run the app
                    [obj run];

                    // release the object
                    [obj release];
                }
                else
                {
                    NSLog( @"Unable to load nib file: %@, exiting", mainNibFile );
                }
            }
            else
            {
                NSLog( @"No NSMainNibFile specified in dictionary, exiting" );
            }
        }
        else
        {
            NSLog( @"Unable to find class: %@, exiting", principalClass );
        }
    }
    else
    {
        NSLog( @"No Info.plist file in application bundle or no NSPrincipalClass in the Info.plist file, exiting" );
    }

    if ( pool != nil )
        [pool release];
}
*/

@end
