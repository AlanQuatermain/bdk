//
//  AQGLViewRenderContext.h
//  BackRowTestHarness
//
//  Created by Alan Quatermain on 16/05/07.
//  Copyright 2007 Alan Quatermain. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BackRow/BRRenderContext.h>

@class AQGLViewPixelFormat;

@interface AQGLViewRenderContext : BRRenderContext
{
    NSOpenGLContext *_nsContext;
}

- (id) initWithAQPixelFormat: (AQGLViewPixelFormat *) format
               sharedContext: (AQGLViewRenderContext *) shared;
- (void) dealloc;

- (CGLContextObj) CGLContext;
- (NSOpenGLContext *) NSContext;

@end
