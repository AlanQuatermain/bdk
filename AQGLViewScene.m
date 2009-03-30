//
//  AQGLViewScene.m
//  BackRowTestHarness
//
//  Created by Alan Quatermain on 16/05/07.
//  Copyright 2007 Alan Quatermain. All rights reserved.
//

#import "AQGLViewScene.h"
#import "AQGLViewRenderContext.h"
#import "AQGLViewPixelFormat.h"
#import <BackRow/BackRow.h>

@implementation AQGLViewScene

- (id) init
{
    if ( [super init] == nil )
        return ( nil );

    // replace the plain BRRenderContext with one of our own
    NSOpenGLPixelFormatAttribute attrs[] =
    {
        NSOpenGLPFANoRecovery,
        NSOpenGLPFAColorSize, 24,
        NSOpenGLPFAAlphaSize, 8,
        0
    };

    NSOpenGLPixelFormat * nsFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes: attrs];
    AQGLViewPixelFormat * format = [[AQGLViewPixelFormat alloc] initWithNSFormat: nsFormat];

    [_resourceContext release];
    _resourceContext = [[AQGLViewRenderContext alloc] initWithAQPixelFormat: format
                        sharedContext: nil];

    [nsFormat release];
    [format release];

    return ( self );
}

- (void) showFPS: (BOOL) flag
{
    _drawFrameRate = flag;
    [_displayLink setUpdateFramerate: flag];
}

- (void) printTree: (BOOL) flag
{
    _dumpTree = flag;
}

- (void) showSafeRegions: (BOOL) flag
{
    _drawSafeRegions = flag;
}

@end
