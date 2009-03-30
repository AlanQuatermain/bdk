//
//  AQGLViewPixelFormat.h
//  BackRowTestHarness
//
//  Created by Alan Quatermain on 16/05/07.
//  Copyright 2007 Alan Quatermain. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BackRow/BRRenderPixelFormat.h>

@interface AQGLViewPixelFormat : BRRenderPixelFormat
{
    NSOpenGLPixelFormat *   _nsFormat;
}

+ (AQGLViewPixelFormat *) doubleBuffered;

- (id) initWithNSFormat: (NSOpenGLPixelFormat *) nsFormat;
- (NSOpenGLPixelFormat *) NSFormat;

@end
