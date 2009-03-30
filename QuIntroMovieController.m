//
//  QuIntroMovieController.m
//  BackRowTestHarness
//
//  Created by Alan Quatermain on 20/06/07.
//  Copyright 2007 Alan Quatermain. All rights reserved.
//

#import "QuIntroMovieController.h"
#import <BackRow/BackRow.h>

NSString * const kQuIntroMovieControllerWasPopped = @"QuIntroMovieControllerWasPopped";

@implementation QuIntroMovieController

- (id) initWithScene: (BRRenderScene *) scene
{
    if ( [super initWithScene: scene] == nil )
        return ( nil );

    [self setTransportControlInhibited: YES];

    return ( self );
}

- (BOOL) brEventAction: (BREvent *) event
{
    if ( [self firstResponder] == NO )
        return ( NO );

    switch ( [event pageUsageHash] )
    {
        BREVENT_MENU:
        {
            [[self player] stop];
            return ( YES );
        }

        default:
            break;
    }

    return ( NO );
}

- (void) wasPushed
{
    (void) [NSTimer scheduledTimerWithTimeInterval: 1.0
                                            target: self
                                          selector: @selector(_startPlaying:)
                                          userInfo: nil
                                           repeats: NO];
}

- (void) wasPopped
{
    [super wasPopped];
    [[NSNotificationCenter defaultCenter] postNotificationName: kQuIntroMovieControllerWasPopped
                                                        object: self];
}

- (void) wasExhumedByPoppingController: (BRLayerController *) controller
{
    [super wasExhumedByPoppingController: controller];
    [[self player] play];
}

- (void) _startPlaying: (NSTimer *) timer
{
    [super wasPushed];
}

@end
