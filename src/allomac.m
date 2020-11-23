//
//  allomac.m
//  Alloverse
//
//  Created by Nevyn Bengtsson on 11/23/20.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>

bool AskMicrophonePermission(void)
{
    if(![AVCaptureDevice respondsToSelector:@selector(authorizationStatusForMediaType:)])
        return true;
    
    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio]) {
        case AVAuthorizationStatusAuthorized:
            return true;
        case AVAuthorizationStatusNotDetermined:
            printf("Requesting microphone access...\n");
            [AVCaptureDevice
                requestAccessForMediaType:AVMediaTypeAudio
                completionHandler:^(BOOL granted)
                {
                    printf("Microphone access was %sgranted\n", granted?"":"NOT ");
                }];
            return false;
        case AVAuthorizationStatusDenied:
            printf("Microphone access was denied.\n");
            return false;
        case AVAuthorizationStatusRestricted:
            printf("Microphone access was not user's to give\n");
            return false;
    }
}
