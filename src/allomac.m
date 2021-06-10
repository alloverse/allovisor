//
//  allomac.m
//  Alloverse
//
//  Created by Nevyn Bengtsson on 11/23/20.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#include "modules/event/event.h"

@interface AlloMac : NSObject
@end

@implementation AlloMac
- (id)init
{
    if((self = [super init]) == nil) return nil;
    [self registerURLHandler];
    
    return self;
}
- (void)registerURLHandler
{
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

- (void)handleURLEvent:(NSAppleEventDescriptor *)theEvent withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    NSString *urlString = [[[theEvent paramDescriptorForKeyword:keyDirectObject] stringValue] stringByRemovingPercentEncoding];
  CustomEvent eventData;
  strcpy(eventData.name, "handleurl");
  
  eventData.count = 1;
  eventData.data[0].type = TYPE_STRING;
  eventData.data[0].value.string = strdup([urlString UTF8String]);

  // XXX<nevyn>: Ugh. Sorry about this. First-launch URL opening is of COURSE not working,
  // and xcode on my M1 won't let me attach-on-launch so finding the cause of the bug is a pain.
  // A short delay on opening a place shouldn't be too much of a worry, so it's an okay workaround
  // for now imho.
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    lovrEventPush((Event) { .type = EVENT_CUSTOM, .data.custom = eventData });
  });
}
@end

AlloMac *allo;

void AlloPlatformInit()
{
    allo = [AlloMac new];
}

