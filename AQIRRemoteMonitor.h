//
//  AQIRRemoteMonitor.h
//  BackRowTestHarness
//
//  Created by Alan Quatermain on 06/05/07.
//  Copyright 2007 AwkwardTV. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDLib.h>

@interface AQIRRemoteMonitor : NSObject
{
    io_object_t                 _notification;
    IOHIDDeviceInterface122 **  _device;
    IOHIDQueueInterface **      _queue;
    NSMapTable *                _elements;
    CFRunLoopSourceRef          _eventSource;
    NSTimeInterval              _lastEventTime;
}

- (id) init;
- (void) dealloc;

@end
