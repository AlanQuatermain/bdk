#import "AQKeyboardNavigator.h"
#import <BackRow/BackRow.h>

@interface AQKeyboardNavigator (Private)

// these two have separate button down & button up events
- (void) _sendTapUpEventWithValue: (int) value;
- (void) _sendTapDownEventWithValue: (int) value;

// these all either don't send button-up, or always send a pair
- (void) _sendTapLeftEvent;
- (void) _sendTapRightEvent;
- (void) _sendPlayPauseTapEvent;
- (void) _sendMenuTapEvent;
- (void) _sendHoldMenuEvent;

- (void) _sendFastForwardEventWithValue: (int) value;
- (void) _sendRewindEventWithValue: (int) value;

- (void) _waitForHoldEvent: (NSEvent *) event;
- (void) _keyHeld: (NSTimer *) timer;

@end

@implementation AQKeyboardNavigator

- (BOOL) acceptsFirstResponder
{
    return ( YES );
}

- (void) keyDown: (NSEvent *) theEvent
{
    if ( [theEvent isARepeat] )
        return;

    NSString * chars = [theEvent charactersIgnoringModifiers];
    if ( [chars length] == 0 )
        return;

    unichar character = [chars characterAtIndex: 0];

    _inKeyDown = 1;

    switch ( character )
    {
        case NSUpArrowFunctionKey:
            [self _sendTapUpEventWithValue: 1];
            break;

        case NSDownArrowFunctionKey:
            [self _sendTapDownEventWithValue: 1];
            break;

        case NSLeftArrowFunctionKey:
            [self _waitForHoldEvent: theEvent];
            break;

        case NSRightArrowFunctionKey:
            [self _waitForHoldEvent: theEvent];
            break;

        case 0x20:  // space
        case 0x0D:  // return
            [self _sendPlayPauseTapEvent];
            break;

        case 0x1B:    // escape
            [self _waitForHoldEvent: theEvent];
            break;

        default:
            _inKeyDown = 0;
            break;
    }
}

- (void) keyUp: (NSEvent *) theEvent
{
    if ( _inKeyDown == 0 )
        return;

    NSString * chars = [theEvent charactersIgnoringModifiers];
    if ( [chars length] == 0 )
        return;

    unichar character = [chars characterAtIndex: 0];

    if ( _holdTimer != nil )
    {
        [_holdTimer invalidate];
        _holdTimer = nil;
    }

    _inKeyDown = 0;

    switch ( character )
    {
        case NSUpArrowFunctionKey:
            [self _sendTapUpEventWithValue: 0];
            break;

        case NSDownArrowFunctionKey:
            [self _sendTapDownEventWithValue: 0];
            break;

        case NSLeftArrowFunctionKey:
            if ( _inHoldEvent == 1 )
            {
                [self _sendRewindEventWithValue: 0];
                _inHoldEvent = 0;
            }
            else
            {
                [self _sendTapLeftEvent];
            }
            break;

        case NSRightArrowFunctionKey:
            if ( _inHoldEvent == 1 )
            {
                [self _sendFastForwardEventWithValue: 0];
                _inHoldEvent = 0;
            }
            else
            {
                [self _sendTapRightEvent];
            }
            break;

        case 0x1B:    // escape
            if ( _inHoldEvent == 1 )
            {
                [self _sendHoldMenuEvent];
                _inHoldEvent = 0;
            }
            else
            {
                [self _sendMenuTapEvent];
            }
            break;

        default:
            _inKeyDown = 1;     // not received one of *our* key-ups
            break;
    }
}

- (void) update
{
    if ( _context == nil )
    {
        [super update];
        return;
    }

    // all BackRow rendering syncs on the context object, so we'll do
    // the same here when the NSOpenGLView needs to update
    @synchronized(_context)
    {
        [super update];
    }
}

- (void) setBRRenderContext: (BRRenderContext *) context
{
    // don't retain -- we rely on the renderer to call this with nil
    // before it goes away
    _context = context;
}

@end

@implementation AQKeyboardNavigator (Private)

- (void) _sendTapUpEventWithValue: (int) value
{
    BREvent * event = [[BREvent alloc] initWithPage: kBREventPageBasic
                                              usage: kBREventBasicUp
                                              value: value];
    [[BREventManager sharedManager] postEvent: event];
    [event release];
}

- (void) _sendTapDownEventWithValue: (int) value
{
    BREvent * event = [[BREvent alloc] initWithPage: kBREventPageBasic
                                              usage: kBREventBasicDown
                                              value: value];
    [[BREventManager sharedManager] postEvent: event];
    [event release];
}

- (void) _sendTapLeftEvent
{
    BREvent * event = [[BREvent alloc] initWithPage: kBREventPageBasic
                                              usage: kBREventBasicLeft
                                              value: 1];
    [[BREventManager sharedManager] postEvent: event];
    [event release];
}

- (void) _sendTapRightEvent
{
    BREvent * event = [[BREvent alloc] initWithPage: kBREventPageBasic
                                              usage: kBREventBasicRight
                                              value: 1];
    [[BREventManager sharedManager] postEvent: event];
    [event release];
}

- (void) _sendPlayPauseTapEvent
{
    BREvent * event = [[BREvent alloc] initWithPage: kBREventPageBasic
                                              usage: kBREventBasicPlayPause
                                              value: 1];
    [[BREventManager sharedManager] postEvent: event];
    [event release];
}

- (void) _sendMenuTapEvent
{
    BREvent * event = [[BREvent alloc] initWithPage: kBREventPageBasic
                                              usage: kBREventBasicMenu
                                              value: 1];
    [[BREventManager sharedManager] postEvent: event];
    [event release];
}

- (void) _sendFastForwardEventWithValue: (int) value
{
    BREvent * event = [[BREvent alloc] initWithPage: kBREventPageAdvanced
                                              usage: kBREventContinualRight
                                              value: value];
    [[BREventManager sharedManager] postEvent: event];
    [event release];
}

- (void) _sendRewindEventWithValue: (int) value
{
    BREvent * event = [[BREvent alloc] initWithPage: kBREventPageAdvanced
                                              usage: kBREventContinualLeft
                                              value: value];
    [[BREventManager sharedManager] postEvent: event];
    [event release];
}

- (void) _sendHoldMenuEvent
{
    BREvent * event = [[BREvent alloc] initWithPage: kBREventPageAdvanced
                                              usage: kBREventAdvMenu
                                              value: 1];
    [[BREventManager sharedManager] postEvent: event];
    [event release];
}

- (void) _waitForHoldEvent: (NSEvent *) event
{
    if ( _holdTimer != nil )
        [_holdTimer invalidate];

    _holdTimer = [NSTimer scheduledTimerWithTimeInterval: 2.0
                                                  target: self
                                                selector: @selector(_keyHeld:)
                                                userInfo: event
                                                 repeats: NO];
}

- (void) _keyHeld: (NSTimer *) timer
{
    _holdTimer = nil;

    _inHoldEvent = 1;

    NSEvent * event = (NSEvent *) [timer userInfo];
    NSString * chars = [event charactersIgnoringModifiers];
    unichar character = [chars characterAtIndex: 0];

    switch ( character )
    {
        case NSLeftArrowFunctionKey:
            [self _sendRewindEventWithValue: 1];
            break;

        case NSRightArrowFunctionKey:
            [self _sendFastForwardEventWithValue: 1];
            break;

        case 0x1B:    // escape
            [self _sendHoldMenuEvent];
            break;

        default:
            _inHoldEvent = 0;
            break;
    }
}

@end
