//
//  QuIntroMovieController.h
//  BackRowTestHarness
//
//  Created by Alan Quatermain on 20/06/07.
//  Copyright 2007 Alan Quatermain. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BackRow/BRVideoPlayerController.h>

@class BRRenderScene, BREvent;

extern NSString * const kQuIntroMovieControllerWasPopped;

@interface QuIntroMovieController : BRVideoPlayerController

- (id) initWithScene: (BRRenderScene *) scene;
- (BOOL) brEventAction: (BREvent *) event;
- (void) wasPushed;
- (void) wasPopped;
- (void) wasExhumedByPoppingController: (BRLayerController *) controller;
- (void) _startPlaying: (NSTimer *) timer;

@end
