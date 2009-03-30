#import "AQNSWindowRenderer.h"
#import "AQGLViewPixelFormat.h"
#import "AQGLViewRenderContext.h"
#import "AQGLViewScene.h"
#import "AQKeyboardNavigator.h"

#import <BackRow/BackRow.h>

NSString * const AQNSWindowRendererLoaded = @"AQNSWindowRendererLoaded";
NSString * const AQNSWindowRendererGoingAway = @"AQNSWindowRendererGoingAway";

@interface AQNSWindowRenderer (Private)

- (void) _updateSceneBounds;

@end

@implementation AQNSWindowRenderer

+ (AQNSWindowRenderer *) loadNewInstanceFromNibNamed: (NSString *) name
{
    // initialize an instance
    AQNSWindowRenderer * obj = [[AQNSWindowRenderer alloc] init];

    // load the given nib file from the main bundle
    if ( [NSBundle loadNibNamed: name owner: obj] == NO )
    {
        [obj release];
        obj = nil;
    }

    // return the renderer
    return ( [obj autorelease] );
}

- (void) awakeFromNib
{
    // setup our render context
    _scene = [[AQGLViewScene alloc] init];
    _context = [[AQGLViewRenderContext alloc] initWithAQPixelFormat: [AQGLViewPixelFormat doubleBuffered]
                                                      sharedContext: [_scene resourceContext]];
    [_scene setSize: [_glView bounds].size];
    [_glView setBRRenderContext: _context];
    [_glView setOpenGLContext: [_context NSContext]];

    // post a notification so the app controller knows it can start
    [[NSNotificationCenter defaultCenter] postNotificationName: AQNSWindowRendererLoaded
                                                        object: self];

    [_window makeKeyAndOrderFront: self];
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];

    [_glView setBRRenderContext: nil];
    [_scene release];
    [_context release];

    // we own the nib, so we have to release the top-level objects
    // within it -- i.e. the window instance
    [_window release];

    [super dealloc];
}

- (NSWindow *) window
{
    return ( _window );
}

- (void) windowWillClose: (NSNotification *) note
{
    [[NSNotificationCenter defaultCenter] postNotificationName: AQNSWindowRendererGoingAway
                                                        object: self];
}

- (void) shutdown
{
    [_window close];
    [[NSNotificationCenter defaultCenter] postNotificationName: AQNSWindowRendererGoingAway
                                                        object: self];
}

- (BRRenderScene *) scene
{
    return ( _scene );
}

- (void) orderIn
{
    if ( _orderedIn == NO )
    {
        _orderedIn = YES;
        [_scene setDrawableContext: _context];
        [self _updateSceneBounds];
        [_scene renderScene];
    }
}

- (void) orderOut
{
    if ( _orderedIn == YES )
    {
        [_scene setDrawableContext: nil];
        _orderedIn = NO;
    }
}

- (void) displayOnline
{
    if ( _orderedIn == YES )
        [_scene setDrawableContext: _context];
}

- (void) displayOffline
{
    // if we're not ordered in, we don't have to do anything
    // The BRFullscreenRenderer has a bug here -- it only removes the
    // drawable context if it's not ordered in, doh
    if ( _orderedIn == YES )
        [_scene setDrawableContext: nil];
}

- (void) displayCanvasChanged
{
    @synchronized(_context)
    {
        [[_context NSContext] clearDrawable];
        [_scene resetCachedTextures];

        [self _updateSceneBounds];
        //[_scene renderScene];
    }
}

@end

@implementation AQNSWindowRenderer (Private)

- (void) _updateSceneBounds
{
    NSSize size = [_glView bounds].size;
    [_scene setSize: size];

    NSRect frame = [_scene interfaceFrame];
    [[BRThemeInfo sharedTheme] setSize: frame.size];
}

@end
