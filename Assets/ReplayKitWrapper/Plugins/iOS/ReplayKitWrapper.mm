
//
//  ReplayKitWrapper.m
//  ReplayKitWrapper
//
//  Created by sassembla on 2018/07/19.
//  Copyright © 2018年 sassembla. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ReplayKitWrapper.h"

@implementation ReplayKitWrapper

//swiftコードのインスタンス
ReplayKitSwift* replayKitSwift;

@end


// 関数はexternで定義する。
extern "C" {
    char* cStringCopy(NSString* baseString)
    {
        const char* string = [baseString UTF8String];
        if (string == NULL)
            return NULL;
        
        char* res = (char*)malloc(strlen(string) + 1);
        strcpy(res, string);
        
        return res;
    }
    
    //初期化
    int _alloc() {
        if (replayKitSwift == nil) {
            replayKitSwift = [[ReplayKitSwift alloc] init];
            return 0;
        } else {
            return 1;
        }
    }
    
    //解除
    int _dealloc() {
        if (replayKitSwift != nil) {
            replayKitSwift = nil;
            return 0;
        } else {
            return 1;
        }
    }
    
    //ここに、開始と完了(エラー)のコールバックを足したい。
    int _startRecording() {
        if (replayKitSwift == nil) {
            return false;
        }
        
        if (@available(iOS 11.0, *)) {
            [replayKitSwift startRecording];
            return 0;
        } else {
            // Fallback on earlier versions
        }
        return 1;
    }
    
    //ここに、完了(エラー)のコールバックを足したい。
    int _stopRecording ()
    {
        if (replayKitSwift == nil) {
            return 2;
        }
        
        if (@available(iOS 11.0, *)) {
            [replayKitSwift stopRecording];
            return 0;
        } else {
            // Fallback on earlier versions
        }
        return 1;
    }

    bool _isRecording () {
        if (replayKitSwift == nil) {
            return false;
        }

        return [replayKitSwift isRecording];
    }
    
    bool _failed () {
        if (replayKitSwift == nil) {
            return false;
        }
        
        return [replayKitSwift failed];
    }
    
    char* _failedReason () {
        if (replayKitSwift == nil) {
            return "";
        }
        
        return cStringCopy([replayKitSwift failedReason]);
    }
    
    
    
    //これでコールバック関数作れるっぽい、まじか。
    void set_recurring_data_push(UInt32 hashCode, DATA_CALLBACK callback)
    {
        NSLog(@"UnityPlugin: set_recurring_reply(%d,%p)", (unsigned int)hashCode, callback);
        
        if (callback) {
            void (^block)() = ^{
                // here we just create a 16-1024byte block of random data to push over
                // to the object. in the Real World we would probably check the status
                // of a larger data structure to see what data we have available for
                // this particular object and not bother calling it back if we don't.
                size_t length = 16 + (arc4random() % (1024-16));
                void *data = malloc(length);
                callback(data, length);
                free(data);
            };
        }
    }
    
}

