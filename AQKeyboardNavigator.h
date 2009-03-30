/* AQKeyboardNavigator */

#import <Cocoa/Cocoa.h>

@class BRRenderContext;

@interface AQKeyboardNavigator : NSOpenGLView
{
    NSTimer *           _holdTimer;
    BRRenderContext *   _context;
    unsigned            _inKeyDown:1;
    unsigned            _inHoldEvent:1;
    unsigned            __RESERVED:30;
}

- (void) keyDown: (NSEvent *) theEvent;
- (void) keyUp: (NSEvent *) theEvent;

// override this method in NSOpenGLView to try and avoid the nasty
// crashes
- (void) update;

// used by the renderer to let this subclass lock the BRRenderContext
// object in the method above
- (void) setBRRenderContext: (BRRenderContext *) ctx;

@end
