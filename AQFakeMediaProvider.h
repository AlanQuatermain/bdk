//
//  AQFakeMediaProvider.h
//  BackRowTestHarness
//
//  Created by Alan Quatermain on 07/05/07.
//  Copyright 2007 AwkwardTV. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BackRow/BRBaseMediaProvider.h>

@interface AQFakeMediaProvider : BRBaseMediaProvider
{
}

- (id) init;
- (NSString *) providerID;
- (int) load;
- (int) unload;
- (void) reset;

- (NSSet *) mediaTypes;

@end
