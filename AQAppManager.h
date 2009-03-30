//
//  AQAppManager.h
//  BackRowTestHarness
//
//  Created by Alan Quatermain on 15/05/07.
//  Copyright 2007 Alan Quatermain. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BackRow/BRAppManager.h>

@class AQNSWindowRenderer;

@interface AQAppManager : BRAppManager
{
    AQNSWindowRenderer * _windowRenderer;
}

+ (id) sharedApplication;

- (void) terminate;
- (void) run;

@end
