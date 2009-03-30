//
//  AQGLViewPixelFormat.m
//  BackRowTestHarness
//
//  Created by Alan Quatermain on 16/05/07.
//  Copyright 2007 Alan Quatermain. All rights reserved.
//

#import "AQGLViewPixelFormat.h"
#import <BackRow/BackRow.h>

@implementation AQGLViewPixelFormat

+ (AQGLViewPixelFormat *) doubleBuffered
{
    static NSOpenGLPixelFormatAttribute attrs[] =
    {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFANoRecovery,
        NSOpenGLPFAColorSize, 24,
        NSOpenGLPFAAlphaSize, 8,
        0
    };

    NSOpenGLPixelFormat * nsFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes: attrs];
    [nsFormat autorelease];

    return ( [[[self alloc] initWithNSFormat: nsFormat] autorelease] );
}

- (id) initWithNSFormat: (NSOpenGLPixelFormat *) nsFormat
{
    if ( [super init] == nil )
        return ( nil );

    _nsFormat = [nsFormat retain];

    return ( self );
}

- (void) dealloc
{
    [_nsFormat release];
    [super dealloc];
}

- (CGLPixelFormatObj) CGLPixelFormat
{
    return ( [_nsFormat CGLPixelFormatObj] );
}

- (NSOpenGLPixelFormat *) NSFormat
{
    return ( _nsFormat );
}

@end
