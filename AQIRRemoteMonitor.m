//
//  AQIRRemoteMonitor.m
//  BackRowTestHarness
//
//  Created by Alan Quatermain on 06/05/07.
//  Copyright 2007 AwkardTV. All rights reserved.
//

#import "AQIRRemoteMonitor.h"
#import <BackRow/BackRow.h>

#import <IOKit/IOKitLib.h>
#import <IOKit/IOCFPlugIn.h>
#import <IOKit/IOMessage.h>
#import <IOKit/hid/IOHIDLib.h>
#import <IOKit/hid/IOHIDKeys.h>
#import <IOKit/hid/IOHIDUsageTables.h>
#import <IOKit/hidsystem/IOHIDLib.h>
#import <IOKit/hidsystem/IOHIDShared.h>
#import <IOKit/hidsystem/IOHIDParameter.h>

typedef struct _HIDElement
{
    UInt16              usagePage;
    UInt16              usage;
    BOOL                isRelative;
    IOHIDElementType    type;
    IOHIDElementCookie  cookie;

} HIDElement;

static IONotificationPortRef    gNotifyPort = MACH_PORT_NULL;
static io_iterator_t            gAddedIter = MACH_PORT_NULL;

// things in BackRow.framework
extern NSString * const kBRUserActionNotification;
extern NSString * const kBRPairRemoteDisplayingUI;
extern NSString * const kBRPairRemoteNotification;
extern NSString * const kBRUnpairRemoteNotification;
extern NSString * const kBRStatusRemoteBatteryLowEvent;
extern BREventManager * BRSharedEventManager;

#pragma mark -

@interface AQIRRemoteMonitor (HIDClientGuts)

- (void) _initHIDNotifications;
- (void) _irRemoteDeviceAdded: (io_object_t) device;

- (void) _remoteDeviceNotification: (natural_t) messageType
                          userInfo: (void *) messageArg;
- (void) _setupElementTable;
- (void) _setupEventQueue;
- (void) _releaseEventQueue;

- (void) _tearDownHID;

- (void *) _queueInterface;
- (void) _handleIREvent;
- (void) _dispatchIREvent: (IOHIDEventStruct *) event
               forElement: (HIDElement *) element;

@end

#pragma mark -

static void _IOMatchCallback( void * refcon, io_iterator_t iterator )
{
    io_object_t device;
    AQIRRemoteMonitor * obj = (AQIRRemoteMonitor *) refcon;

    while ( device = IOIteratorNext(iterator) )
    {
        // see if it's the remote control device
        CFTypeRef prop = IORegistryEntryCreateCFProperty( device, CFSTR("HIDRemoteControl"),
            kCFAllocatorDefault, 0 );

        if ( prop != NULL )
        {
            if ( CFBooleanGetValue((CFBooleanRef)prop) )
                [obj _irRemoteDeviceAdded: device];

            CFRelease( prop );
        }

        IOObjectRelease( device );
    }
}

static void _IOQueueCallback( void * target, IOReturn result, void * refcon,
                              void * sender )
{
    AQIRRemoteMonitor * obj = (AQIRRemoteMonitor *) refcon;
    if ( (obj == nil) || (sender != [obj _queueInterface]) )
        return;

    [obj _handleIREvent];
}

static void _IOInterestCallback( void * refcon, io_service_t service,
                                 natural_t messageType, void * messageArgument )
{
    AQIRRemoteMonitor * obj = (AQIRRemoteMonitor *) refcon;
    if ( obj != nil )
        [obj _remoteDeviceNotification: messageType userInfo: messageArgument];
}

static void _PostLowBatteryAlert( void )
{
    [BRStatusAlertController postStatusAlertNotificationOfType: kBRStatusRemoteBatteryLowEvent];

    CFDateRef date = CFDateCreate( NULL, CFAbsoluteTimeGetCurrent( ) );
    CFPreferencesSetValue( CFSTR("LowBatteryNotificationDate"), date, 
                           CFSTR("com.apple.driver.AppleIRController.notification"),
                           kCFPreferencesCurrentUser, kCFPreferencesCurrentHost );
    CFPreferencesSynchronize( CFSTR("com.apple.driver.AppleIRController.notification"),
                              kCFPreferencesCurrentUser, kCFPreferencesCurrentHost );
    CFRelease( date );
}

#pragma mark -

@implementation AQIRRemoteMonitor

- (id) init
{
    if ( [super init] == nil )
        return ( nil );

    [self _initHIDNotifications];

    return ( self );
}

- (void) dealloc
{
    @synchronized(self)
    {
        [self _tearDownHID];
    }

    [super dealloc];
}

@end

@implementation AQIRRemoteMonitor (HIDClientGuts)

- (void) _initHIDNotifications
{
    CFMutableDictionaryRef matchDict;
    kern_return_t kr;
    mach_port_t masterPort;

    // create the IO master port
    kr = IOMasterPort( bootstrap_port, &masterPort );
    if ( (kr != KERN_SUCCESS) || (masterPort == MACH_PORT_NULL) )
        return;

    // create the notification port & attach to run loop
    gNotifyPort = IONotificationPortCreate( masterPort );
    CFRunLoopAddSource( CFRunLoopGetCurrent( ),
                        IONotificationPortGetRunLoopSource(gNotifyPort),
                        kCFRunLoopCommonModes );

    // create the notifications that we need
    matchDict = IOServiceMatching( kIOHIDDeviceKey );
    kr = IOServiceAddMatchingNotification( gNotifyPort, kIOMatchedNotification,
                                           matchDict, _IOMatchCallback, self, &gAddedIter );

    if ( kr != KERN_SUCCESS )
        return;

    _IOMatchCallback( self, gAddedIter );
}

- (void) _irRemoteDeviceAdded: (io_object_t) device
{
    IOCFPlugInInterface ** pluginInterface;
    IOReturn kr;
    HRESULT hr = S_FALSE;
    SInt32 score;

    // create the interface object
    kr = IOCreatePlugInInterfaceForService( device, kIOHIDDeviceUserClientTypeID,
                                            kIOCFPlugInInterfaceID, &pluginInterface, &score );
    if ( kr != kIOReturnSuccess )
        return;

    @synchronized(self)
    {
        // get a HID Interface object, version 1.2.2 (Mac OS X 10.3+)
        hr = (*pluginInterface)->QueryInterface( pluginInterface,
            CFUUIDGetUUIDBytes(kIOHIDDeviceInterfaceID122),
            (LPVOID) &_device );

        if ( (hr == S_OK) && (_device != NULL) )
        {
            // open the device
            hr = (*_device)->open( _device, kIOHIDOptionsTypeSeizeDevice );

            // dig out the list of elements & put into our lookup table
            [self _setupElementTable];

            // start listening for events from the device
            [self _setupEventQueue];

            // setup a notification so we can find out when the device goes
            // away
            IOServiceAddInterestNotification( gNotifyPort, device, kIOGeneralInterest,
                                              _IOInterestCallback, self, &_notification );
        }

        (*pluginInterface)->Release( pluginInterface );
    }
}

- (void) _remoteDeviceNotification: (natural_t) messageType
                          userInfo: (void *) messageArg
{
    if ( messageType == kIOMessageServiceIsTerminated )
    {
        @synchronized(self)
        {
            [self _tearDownHID];
        }
    }
}

- (void) _setupElementTable
{
    // allocate the table
    _elements = NSCreateMapTableWithZone( NSNonOwnedPointerMapKeyCallBacks,
                                          NSObjectMapValueCallBacks,
                                          50, [self zone] );
    NSArray * elementList;

    IOReturn ret = (*_device)->copyMatchingElements( _device, NULL,
        (CFArrayRef *) &elementList );

    if ( (ret != kIOReturnSuccess) || (elementList == nil) )
    {
        NSFreeMapTable( _elements );
        _elements = NULL;
        return;
    }

    //printf( "Listing elements...\n" );

    unsigned i, count = [elementList count];
    for ( i = 0; i < count; i++ )
    {
        NSDictionary * obj = (NSDictionary *) [elementList objectAtIndex: i];
        if ( obj == nil )
            continue;

        HIDElement element;

        element.usagePage = [[obj objectForKey: @kIOHIDElementUsagePageKey] shortValue];
        //printf( "Usage page = %hd\n", element.usagePage );

        element.usage = [[obj objectForKey: @kIOHIDElementUsageKey] shortValue];
        //printf( "Usage = %hd\n", element.usage );

        element.isRelative = [[obj objectForKey: @kIOHIDElementIsRelativeKey] boolValue];
        //printf( "IsRelative = %hhd\n", element.isRelative );

        element.type = [[obj objectForKey: @kIOHIDElementTypeKey] intValue];
        //printf( "Type = %d\n", element.type );

        element.cookie = [[obj objectForKey: @kIOHIDElementCookieKey] pointerValue];
        //printf( "Cookie = %p\n", element.cookie );

        //printf( "\n" );

        // insert into the map table, using the cookie as its key
        NSMapInsert( _elements, element.cookie,
                     [NSValue value: &element withObjCType: @encode(HIDElement)] );
    }
}

- (void) _setupEventQueue
{
    if ( (_elements == NULL) || (NSCountMapTable(_elements) == 0) )
        return;

    // create the queue interface
    _queue = (*_device)->allocQueue( _device );
    if ( _queue == NULL )
        return;

    IOReturn ret;
    ret = (*_queue)->create( _queue, 0, 32 );
    if ( ret != kIOReturnSuccess )
    {
        [self _releaseEventQueue];
        return;
    }

    NSMapEnumerator enumerator = NSEnumerateMapTable( _elements );
    IOHIDElementCookie key;
    NSValue * value;
    BOOL cookieAdded = NO;

    while ( NSNextMapEnumeratorPair(&enumerator, (void **) &key, (void **) &value) )
    {
        HIDElement element;
        [value getValue: &element];

        // skip types that we're not interested in
        if ( (element.type < kIOHIDElementTypeInput_Misc) ||
             (element.type > kIOHIDElementTypeInput_ScanCodes) )
            continue;

        // skip certain device page/usage values
        BOOL notifyElement = NO;
        switch ( element.usagePage )
        {
            case kHIDPage_GenericDesktop:
            {
                switch ( element.usage )
                {
                    case kHIDUsage_GD_SystemMainMenu:
                    case kHIDUsage_GD_SystemAppMenu:
                    case kHIDUsage_GD_SystemMenu:
                    case kHIDUsage_GD_SystemMenuRight:
                    case kHIDUsage_GD_SystemMenuLeft:
                    case kHIDUsage_GD_SystemMenuUp:
                    case kHIDUsage_GD_SystemMenuDown:
                        notifyElement = YES;
                        break;

                    default:
                        break;
                }

                break;
            }

            case 6:     // header says 'reserved', HID spec says 'Generic Device Controls Page'
            {
                // Generic Device Controls Page, Wireless ID
                if ( element.usage == 34 )
                    notifyElement = YES;
                break;
            }

            case kHIDPage_Consumer:
            {
                if ( (element.usage > 0x20) && (element.usage < 0x300) )
                    notifyElement = YES;
                break;
            }

            case 0xff01:        // Apple custom values
            {
                switch ( element.usage )
                {
                    case 32:        // Pair Remote
                    case 33:        // Unpair Remote
                    case 34:        // Low Battery
                    case 35:        // Sleep Now (hold play button)
                    case 48:        // System Reset (not added in ATV Finder's HID monitor)
                    case 49:        // Black Screen Recovery
                        notifyElement = YES;
                        break;

                    default:
                        break;
                }

                break;
            }

            default:
                break;
        }

        if ( notifyElement )
        {
            // tell the queue that we're interested in this element
            ret = (*_queue)->addElement( _queue, element.cookie, 0 );

            if ( ret == kIOReturnSuccess )
                cookieAdded = YES;
        }
    }

    NSEndMapTableEnumeration( &enumerator );

    if ( cookieAdded )
    {
        // get a CFRunLoopSource for receiving the events
        ret = (*_queue)->createAsyncEventSource( _queue, &_eventSource );
        ret |= (*_queue)->setEventCallout( _queue, _IOQueueCallback, NULL, self );

        if ( _eventSource != NULL )
            CFRunLoopAddSource( CFRunLoopGetCurrent( ), _eventSource, kCFRunLoopDefaultMode );

        ret |= (*_queue)->start( _queue );
    }

    if ( ret != kIOReturnSuccess )
        [self _releaseEventQueue];
}

- (void) _releaseEventQueue
{
    if ( _queue == NULL )
        return;

    (*_queue)->stop( _queue );

    if ( _eventSource != NULL )
    {
        CFRunLoopRemoveSource( CFRunLoopGetCurrent( ), _eventSource, kCFRunLoopDefaultMode );
        CFRunLoopSourceInvalidate( _eventSource );
        CFRelease( _eventSource );
        _eventSource = NULL;
    }

    (*_queue)->dispose( _queue );
    (*_queue)->Release( _queue );
    _queue = NULL;
}

- (void) _tearDownHID
{
    [self _releaseEventQueue];

    if ( _device != NULL )
    {
        (*_device)->close( _device );
        (*_device)->Release( _device );
        _device = NULL;
    }

    if ( _notification != MACH_PORT_NULL )
    {
        IOObjectRelease( _notification );
        _notification = MACH_PORT_NULL;
    }

    if ( _elements != NULL )
    {
        NSFreeMapTable( _elements );
        _elements = NULL;
    }
}

- (void *) _queueInterface
{
    return ( (void *) _queue );
}

- (void) _handleIREvent
{
    IOReturn result = kIOReturnSuccess;
    IOHIDEventStruct event;
    AbsoluteTime zeroTime = { 0, 0 };

    //printf( "Received event:\n" );

    [self retain];

    do
    {
        result = (*_queue)->getNextEvent( _queue, &event, zeroTime, 0 );

        if ( result != kIOReturnSuccess )
            break;
/*
        printf( "\ttype = %d\n", event.type );
        printf( "\telementCookie = %p\n", event.elementCookie );
        printf( "\tvalue = %d\n", event.value );
        printf( "\ttimestamp = {%u,%u}\n", event.timestamp.hi, event.timestamp.lo );
        printf( "\tlongValueSize = %u\n", event.longValueSize );

        if ( (event.longValueSize > 0) && (event.longValue != NULL) )
        {
            printf( "\tlongValue follows:\n" );
            NSLog( @"%@", [NSData dataWithBytesNoCopy: event.longValue length: event.longValueSize] );
        }
        else
        {
            printf( "\tlongValue = NULL\n" );
        }
*/

        // look up the element in our lookup table
        HIDElement element;
        NSValue * val = (NSValue *) NSMapGet( _elements, event.elementCookie );
        if ( val != nil )
            [val getValue: &element];
/*
        printf( "\ttype = %d\n", element.type );
        printf( "\tusagePage = %hx\n", element.usagePage );
        printf( "\tusage = %hx\n", element.usage );
        printf( "\tisRelative = %hhd", element.isRelative );
        printf( "\tvalue = %d\n", event.value );
        printf( "\ttimestamp = {%u,%u}\n", event.timestamp.hi, event.timestamp.lo );
        printf( "\n" );
*/
        // the system seems to re-post some events; since we're
        // filtering a number of them, the only one we'll see is
        // 0xC/0x40 (Consumer, Menu), and we'll see it once or even
        // twice each time an event comes in. However, the timestamp
        // will be the time of the last *real* such event, so we'll
        // record the last time seen and ignore anything with an
        // earlier timestamp

        // we'll also do a heuristic, because we know how some of these
        // things work: The hold menu & hold play/pause will never send
        // a 'button up' event (i.e. with a value of zero) so we can
        // ignore those, too...

        if ( (element.usagePage == kHIDPage_Consumer) &&
             (element.usage == kHIDUsage_Csmr_Menu) &&
             (event.value == 0) )
            continue;

        // ignore Wireless ID commands
        if ( (element.usagePage == 6) && (element.usage == 0x22) )
            continue;

        // ignore button-up events in the Apple Custom page
        if ( (element.usagePage == 0xff01) && (event.value == 0) )
            continue;

        Nanoseconds nano = AbsoluteToNanoseconds( event.timestamp );
        UInt64 nano64 = *((UInt64 *) &nano);
        NSTimeInterval eventTime = (double)nano64;
        if ( eventTime < _lastEventTime )
            continue;

        // another heuristic: BackRow doesn't seem to pass on the
        // button-up events for anything on page 1, except for the
        // up/down buttons
        if ( (element.usagePage == kHIDPage_GenericDesktop) &&
             (event.value == 0) &&
             (element.usage != kHIDUsage_GD_SystemMenuUp) &&
             (element.usage != kHIDUsage_GD_SystemMenuDown) )
            continue;


        _lastEventTime = eventTime;

        // okay, done all our filtering, let's dispatch whatever
        // remains
        [self _dispatchIREvent: &event forElement: &element];

    } while ( result == kIOReturnSuccess );

    [self release];
}

- (void) _dispatchIREvent: (IOHIDEventStruct *) event
               forElement: (HIDElement *) element
{
    UpdateSystemActivity( UsrActivity );
    [[NSNotificationCenter defaultCenter] postNotificationName: kBRUserActionNotification
                                                        object: nil];

    Nanoseconds nano = AbsoluteToNanoseconds( event->timestamp );
    UInt64 nano64 = *((UInt64 *) &nano);
    NSTimeInterval eventTime = (double)nano64;

    BOOL done = NO;
    if ( element->usagePage == 0xff01 )
    {
        done = YES;
        switch ( element->usage )
        {
            case 0x20:
            {
                NSLog( @"IRRemoteMonitor: Remote Pairing message received" );
                [[NSNotificationCenter defaultCenter] postNotificationName: kBRPairRemoteNotification
                 object: nil
               userInfo: [NSDictionary dictionaryWithObject: [NSNumber numberWithBool: YES]
                                                     forKey: kBRPairRemoteDisplayingUI]];
                break;
            }

            case 0x21:
            {
                NSLog( @"IRRemoteMonitor: Remote Unpairing message received" );
                [[NSNotificationCenter defaultCenter] postNotificationName: kBRUnpairRemoteNotification
                 object: nil userInfo: nil];
                break;
            }

            case 0x22:
            {
                NSLog( @"IRRemoteMonitor: Low Battery message received" );
                CFDateRef lastNotified = CFPreferencesCopyValue( CFSTR("LowBatteryNotificationDate"),
                    CFSTR("com.apple.driver.AppleIRController.notification"),
                    kCFPreferencesCurrentUser, kCFPreferencesCurrentHost );

                if ( lastNotified != NULL )
                {
                    CFDateRef now = CFDateCreate( NULL, CFAbsoluteTimeGetCurrent( ) );
                    CFTimeInterval since = CFDateGetTimeIntervalSinceDate( now, lastNotified );

                    if ( since >= 86400.0 )
                        _PostLowBatteryAlert( );
                }
                else
                {
                    _PostLowBatteryAlert( );
                }

                break;
            }

            case 0x23:
            {
                NSLog( @"Sleep Now message received" );
                NSLog( @"Custom handling for BackRowTextHarness: Terminate Application" );
                // fall through
            }

            case 0x30:      // system reset
            case 0x31:      // black screen recovery
            {
                [[BRAppManager sharedApplication] terminate];
                break;
            }

            default:
                done = NO;
                break;
        }
    }

    if ( done )
        return;

    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    @try
    {
        BREvent * obj = [[BREvent alloc] initWithPage: element->usagePage
                                                usage: element->usage
                                                value: event->value
                                               atTime: eventTime];
        [[BREventManager sharedManager] postEvent: obj];
        [obj release];
    }
    @catch(NSException * e)
    {
        NSLog( @"IRRemoteMonitor: Caught exception while posting event: page = %hd, usage = %hd, value = %d: %@",
               element->usagePage, element->usage, event->value, [e description] );
    }
    @finally
    {
        [pool release];
    }
}

@end
