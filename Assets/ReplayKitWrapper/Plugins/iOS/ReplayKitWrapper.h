//
//  ReplayKitWrapper.h
//  ReplayKitWrapper
//
//  Created by sassembla on 2018/07/19.
//  Copyright © 2018年 sassembla. All rights reserved.
//

#ifndef ReplayKitWrapper_h
#define ReplayKitWrapper_h

#import <UIKit/UIkit.h>
#import <Foundation/Foundation.h>
#import "Unity-Swift.h"

@interface ReplayKitWrapper : NSObject{
    @private ReplayKitSwift* console;
}
@end

extern "C" {
    typedef void (*DATA_CALLBACK)(void *buffer, size_t length);
    void set_recurring_data_push(UInt32 hashCode, DATA_CALLBACK callback);
}


#endif /* ReplayKitWrapper_h */
