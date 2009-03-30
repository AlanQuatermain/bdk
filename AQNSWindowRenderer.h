/* AQNSWindowRenderer */

#import <Cocoa/Cocoa.h>
#import <BackRow/BRRenderer.h>

@class AQGLViewRenderContext, BRRenderScene, AQKeyboardNavigator;

@interface AQNSWindowRenderer : BRRenderer
{
    IBOutlet AQKeyboardNavigator *_glView;  // actually an NSOpenGLView subclass
    IBOutlet NSWindow *_window;

    BRRenderScene *_scene;
    AQGLViewRenderContext *_context;
    BOOL _orderedIn;
}

+ (AQNSWindowRenderer *) loadNewInstanceFromNibNamed: (NSString *) name;

- (void) awakeFromNib;
- (void) dealloc;

- (NSWindow *) window;
- (void) shutdown;

// BRRenderer overrides
- (BRRenderScene *) scene;
- (void) orderIn;
- (void) orderOut;
- (void) displayOnline;
- (void) displayOffline;
- (void) displayCanvasChanged;

@end

extern NSString * const AQNSWindowRendererLoaded;
extern NSString * const AQNSWindowRendererGoingAway;
