//
//  AQHarnessController.h
//  BackRowTestHarness
//
//  Created by Alan Quatermain on 06/05/07.
//  Copyright 2007 AwkwardTV. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BackRow/BackRow.h>

@class AQIRRemoteMonitor;

@interface AQHarnessController : NSObject <BREventResponder>
{
    BRControllerStack * _stack;
    BRRenderer *        _renderer;
    AQIRRemoteMonitor * _hidMonitor;
    NSDictionary *      _rootItem;

    BOOL                _showFPS;
    BOOL                _printTree;
    BOOL                _showSafeAreas;
}

+ (AQHarnessController *) sharedController;

- (id) init;
- (void) dealloc;
- (void) setupRemoteHID;
- (void) tearDownRemoteHID;
- (BOOL) brEventAction: (BREvent *) event;

- (BOOL) setRootItemByPath: (NSString *) path;

- (void) setSceneShowsFPS: (BOOL) flag;
- (void) setScenePrintsRenderTree: (BOOL) flag;
- (void) setSceneShowsSafeAreas: (BOOL) flag;
- (void) setMainMenuFixEnabled: (BOOL) flag;

@end
