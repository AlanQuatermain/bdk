//
//  AQFakeMediaProvider.m
//  BackRowTestHarness
//
//  Created by Alan Quatermain on 07/05/07.
//  Copyright 2007 AwkwardTV. All rights reserved.
//

#import "AQFakeMediaProvider.h"
#import <BackRow/BackRow.h>

enum
{
    kBRMediaProviderNetworkWaitingState = 440,
    kBRMediaProviderNetworkDoneState,
    kBRMediaProviderLoadingState,
    kBRMediaProviderLoadedState,
    kBRMediaProviderUnloadingState,
    kBRMediaProviderUnloadedState

};

#if 0
# define LogObjCFunctionCall( )  NSLog(@"-[%@ %s] called", [self className], _cmd)
#else
# define LogObjCFunctionCall( )
#endif

@interface AQFakeMediaProvider (Private)

- (void) _loadTimerCallback: (NSTimer *) timer;
- (void) _unloadTimerCallback: (NSTimer *) timer;

@end

@implementation AQFakeMediaProvider

- (id) init
{
    if ( [super init] == nil )
        return ( nil );

    LogObjCFunctionCall( );

    [self load];

    return ( self );
}

- (void) dealloc
{
    [super dealloc];
}

- (NSString *) providerID
{
    LogObjCFunctionCall( );
    return ( @"org.quatermain.brharness.provider.fake" );
}

- (int) load
{
    LogObjCFunctionCall( );
    [self setStatus: kBRMediaProviderLoadingState];
    [NSTimer scheduledTimerWithTimeInterval: 0.5
                                     target: self
                                   selector: @selector(_loadTimerCallback:)
                                   userInfo: nil
                                    repeats: NO];
    return ( kBRMediaProviderLoadingState );
}

- (int) unload
{
    LogObjCFunctionCall( );
    [self setStatus: kBRMediaProviderUnloadingState];
    [NSTimer scheduledTimerWithTimeInterval: 0.5
                                     target: self
                                   selector: @selector(_unloadTimerCallback:)
                                   userInfo: nil
                                    repeats: NO];
    return ( kBRMediaProviderUnloadingState );
}

- (void) reset
{
    LogObjCFunctionCall( );
    [self unload];
    [self load];
}

- (NSSet *) mediaTypes
{
    LogObjCFunctionCall( );
    NSMutableArray * types = [[NSMutableArray alloc] init];

    // types handled by MEITunesMediaProvider
    [types addObject: [BRMediaType song]];
    [types addObject: [BRMediaType movie]];
    [types addObject: [BRMediaType podcast]];
    [types addObject: [BRMediaType audioBook]];
    [types addObject: [BRMediaType booklet]];
    [types addObject: [BRMediaType musicVideo]];
    [types addObject: [BRMediaType TVShow]];
    [types addObject: [BRMediaType interactiveBooklet]];
    [types addObject: [BRMediaType coachedAudio]];

    // types handled by MEIPhotoMediaProvider
    [types addObject: [BRMediaType photo]];

    NSSet * result = [NSSet setWithArray: types];
    [types release];

    return ( result );
}

@end

@implementation AQFakeMediaProvider (Private)

- (void) _loadTimerCallback: (NSTimer *) timer
{
    LogObjCFunctionCall( );
    [self setStatus: kBRMediaProviderLoadedState];
}

- (void) _unloadTimerCallback: (NSTimer *) timer
{
    LogObjCFunctionCall( );
    [self setStatus: kBRMediaProviderUnloadedState];
}

@end
