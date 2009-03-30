//
//  AQDisplayManager.m
//  BackRowTestHarness
//
//  Created by Alan Quatermain on 19/05/07.
//  Copyright 2007 Alan Quatermain. All rights reserved.
//

#import "AQDisplayManager.h"
#import <BackRow/BackRow.h>

static AQDisplayManager * __aqDisplayManagerSingleton = nil;

#if 0
# define LogFunctionCall(s, c) NSLog( @"[%@ %@]", [(s) className], NSStringFromSelector(c) )
#else
# define LogFunctionCall(s, c)
#endif

@implementation AQDisplayManager

+ (id) singleton
{
    return ( __aqDisplayManagerSingleton );
}

+ (void) setSingleton: (id) singleton
{
    __aqDisplayManagerSingleton = singleton;
    [BRDisplayManager setSingleton: singleton];    // override [BRDisplayManager sharedInstance]
    id test = [BRDisplayManager singleton];
    if ( test == __aqDisplayManagerSingleton )
        NSLog( @"BRDisplayManager overridden" );
    else
        NSLog( @"BRDisplayManager override failed" );
}

- (void) captureAllDisplays
{
    LogFunctionCall(self, _cmd);
}

- (void) releaseAllDisplays
{
    LogFunctionCall(self, _cmd);
}

- (void) _windowServerCallbackHandler
{
    // do nothing
}

@end
