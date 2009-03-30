//
//  AQWindowRenderer.h
//  BackRowTestHarness
//
//  Created by Alan Quatermain on 07/05/07.
//  Copyright 2007 AwkwardTV. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BackRow/BRWindowRenderer.h>

// this exists purely to set the _draggable member of the superclass
// prior to initialization
@interface AQWindowRenderer : BRWindowRenderer
{
}

- (id) init;
- (CGRect) _windowFrame;

@end
