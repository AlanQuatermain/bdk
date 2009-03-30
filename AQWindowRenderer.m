//
//  AQWindowRenderer.m
//  BackRowTestHarness
//
//  Created by Alan Quatermain on 07/05/07.
//  Copyright 2007 AwkwardTV. All rights reserved.
//

#import "AQWindowRenderer.h"

// let's see if we can take over the window rendering....
/*
CGSServerPort();
CGSDefaultConnectionForThread();
CFSGetEventPort();
CFMachPortCreateWithPort();
*/
// event tap perhaps ?

@implementation AQWindowRenderer

- (id) init
{
    _draggable = 1;
    return ( [super init] );
}

- (CGRect) _windowFrame
{
    CGRect result = { 0.0f, 0.0f, 1280.0f * 0.8f, 760.0f * 0.8f };
    return ( result );
}

@end
