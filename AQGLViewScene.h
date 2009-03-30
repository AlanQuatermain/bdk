//
//  AQGLViewScene.h
//  BackRowTestHarness
//
//  Created by Alan Quatermain on 16/05/07.
//  Copyright 2007 Alan Quatermain. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BackRow/BRRenderScene.h>

@interface AQGLViewScene : BRRenderScene
{
}

- (id) init;

- (void) showFPS: (BOOL) flag;
- (void) printTree: (BOOL) flag;
- (void) showSafeRegions: (BOOL) flag;

@end
