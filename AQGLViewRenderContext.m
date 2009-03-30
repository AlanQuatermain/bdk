//
//  AQGLViewRenderContext.m
//  BackRowTestHarness
//
//  Created by Alan Quatermain on 16/05/07.
//  Copyright 2007 Alan Quatermain. All rights reserved.
//

#import "AQGLViewRenderContext.h"
#import "AQGLViewPixelFormat.h"
#import <BackRow/BackRow.h>

@implementation AQGLViewRenderContext

- (id) initWithAQPixelFormat: (AQGLViewPixelFormat *) format
               sharedContext: (AQGLViewRenderContext *) shared
{
    if ( [super init] == nil )
        return ( nil );

    _nsContext = [[NSOpenGLContext alloc] initWithFormat: [format NSFormat]
                                            shareContext: [shared NSContext]];
    _format = [format retain];
    _shared = [shared retain];

    return ( self );
}

- (void) dealloc
{
    [_nsContext release];
    [super dealloc];
}

- (CGLContextObj) CGLContext
{
    return ( [_nsContext CGLContextObj] );
}

- (NSOpenGLContext *) NSContext
{
    return ( _nsContext );
}

@end
