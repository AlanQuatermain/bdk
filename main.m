//
//  main.m
//  BackRowTestHarness
//
//  Created by Alan Quatermain on 06/05/07.
//  Copyright AwkwardTV 2007. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BackRow/BackRow.h>
#import <AppleTV/ATVSettingsFacade.h>
#import <AppleTV/ATVScreenSaverManager.h>

#import "AQHarnessController.h"
#import "AQAppManager.h"
#import "AQDisplayManager.h"

int main( int argc, const char *argv[] )
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    // get some things tucked in nicely now...
    (void) [AQAppManager sharedApplication];
    (void) [AQDisplayManager sharedInstance];
    [ATVSettingsFacade initializePlatformFacade];
    [BRBacktracingException install];
    [[ATVScreenSaverManager sharedInstance] enable];

    AQHarnessController * controller = [AQHarnessController sharedController];
    [controller setupRemoteHID];

    [[BREventManager sharedManager] setFirstResponder: controller];
    [BRIPConfiguration startMonitoringNetworkChanges];

    [pool release];

    // run the application
    /*
    pool = [[NSAutoreleasePool alloc] init];
    [mgr run];
    [pool release];

    [controller tearDownRemoteHID];
    return ( 0 );
    */
    return ( NSApplicationMain(argc, argv) );
}
