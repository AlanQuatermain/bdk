//
//  AQDisplayManager.h
//  BackRowTestHarness
//
//  Created by Alan Quatermain on 19/05/07.
//  Copyright 2007 Alan Quatermain. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BackRow/BRDisplayManager.h>

@interface AQDisplayManager : BRDisplayManager
{
}

+ (id) singleton;
+ (void) setSingleton: (id) singleton;

- (void) captureAllDisplays;
- (void) releaseAllDisplays;

@end
