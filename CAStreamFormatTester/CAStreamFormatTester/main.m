//
//  main.m
//  CAStreamFormatTester
//
//  Created by Romain SOMMERARD on 06/08/2015.
//  Copyright (c) 2015 Romain SOMMERARD. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

int main(int argc, const char * argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    AudioFileTypeAndFormatID fileTypeAndFormat;
    
    //fileTypeAndFormat.mFileType = kAudioFileAIFFType;
    //fileTypeAndFormat.mFileType = kAudioFileWAVEType;
    fileTypeAndFormat.mFileType = kAudioFileCAFType;
    //fileTypeAndFormat.mFileType = kAudioFileMP3Type;
    
    //fileTypeAndFormat.mFormatID = kAudioFormatLinearPCM;
    fileTypeAndFormat.mFormatID = kAudioFormatMPEG4AAC;
    
    OSStatus audioErr = noErr;
    UInt32 infoSize = 0;
    
    audioErr = AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat, sizeof(fileTypeAndFormat), &fileTypeAndFormat, &infoSize);
    assert(audioErr == noErr);
    
    AudioStreamBasicDescription *asbds = malloc(infoSize);
    audioErr = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat, sizeof(fileTypeAndFormat), &fileTypeAndFormat, &infoSize, asbds);
    assert(audioErr == noErr);
    
    int asbdCount = infoSize/sizeof(AudioStreamBasicDescription);
    
    for(int i=0; i < asbdCount; i++) {
        UInt32 format4cc = CFSwapInt32HostToBig(asbds[i].mFormatID);
        
        NSLog(@"%d: mFormatId: %4.4s, mFormatFlags: %d, mBitsPerChannel: %d", i, (char*)&format4cc, asbds[i].mFormatFlags, asbds[i].mBitsPerChannel);
    }
    
    free(asbds);
    
    [pool drain];
    
    return 0;
}
