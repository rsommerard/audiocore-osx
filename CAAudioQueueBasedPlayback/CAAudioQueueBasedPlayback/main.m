//
//  main.m
//  CAAudioQueueBasedPlayback
//
//  Created by Romain SOMMERARD on 06/08/2015.
//  Copyright (c) 2015 Romain SOMMERARD. All rights reserved.
//

#include <AudioToolbox/AudioToolbox.h>

#define kPlaybackFileLocation CFSTR("/Users/Romain/Lab/sample.mp3")
#define kNumberPlaybackBuffers 3

#pragma mark user data struct

typedef struct MyPlayer {
    AudioFileID playbackFile;
    SInt64 packetPosition;
    UInt32 numPacketsToRead;
    AudioStreamPacketDescription *packetDescs;
    Boolean isDone;
} MyPlayer;


#pragma mark utility functions

static void CheckError(OSStatus error, const char *operation) {
    if(error == noErr)
        return;
    
    char errorString[20];
    // See if it appears to be a 4-char-code
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
    if(isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4])) {
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    } else {
        // No, format it as an integer
        sprintf(errorString, "%d", (int)error);
    }
    
    fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
    
    exit(1);
}

static void MyCopyEncoderCookieToQueue(AudioFileID theFile, AudioQueueRef queue) {
    UInt32 propertySize;
    OSStatus result = AudioFileGetPropertyInfo(theFile, kAudioFilePropertyMagicCookieData, &propertySize, NULL);
    
    if(result == noErr && propertySize > 0) {
        Byte* magicCookie = (UInt8 *)malloc(sizeof(UInt8) * propertySize);
        CheckError(AudioFileGetProperty(theFile, kAudioFilePropertyMagicCookieData, &propertySize, magicCookie), "Get cookie from file failed");
        CheckError(AudioQueueSetProperty(queue, kAudioQueueProperty_MagicCookie, magicCookie, propertySize), "Set cookie on queue failed");
        free(magicCookie);
    }
}

void CalculateBytesForTime(AudioFileID inAudioFile, AudioStreamBasicDescription inDesc, Float64 inSeconds, UInt32 *outBufferSize, UInt32 *outNumPackets) {
    UInt32 maxPacketSize;
    UInt32 propSize = sizeof(maxPacketSize);
    
    CheckError(AudioFileGetProperty(inAudioFile, kAudioFilePropertyPacketSizeUpperBound, &propSize, &maxPacketSize), "Couldn't get file's max packet size");
    
    static const int maxBufferSize = 0x10000;
    static const int minBufferSize = 0x4000;
    
    if(inDesc.mFramesPerPacket) {
        Float64 numPacketsForTime = inDesc.mSampleRate / inDesc.mFramesPerPacket * inSeconds;
        *outBufferSize = numPacketsForTime * maxPacketSize;
    } else {
        *outBufferSize = maxBufferSize > maxPacketSize ? maxBufferSize : maxPacketSize;
    }
    
    if(*outBufferSize > maxBufferSize && *outBufferSize > maxPacketSize) {
        *outBufferSize = maxBufferSize;
    } else {
        if(*outBufferSize < minBufferSize)
            *outBufferSize = minBufferSize;
    }
    
    *outNumPackets = *outBufferSize / maxPacketSize;
}


#pragma mark playback callback function

static void MyAQOutputCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inCompleteAQBuffer) {
    MyPlayer *aqp = (MyPlayer*)inUserData;
    
    if(aqp->isDone)
        return;
    
    UInt32 numBytes;
    UInt32 nPackets = aqp->numPacketsToRead;
    
    CheckError(AudioFileReadPackets(aqp->playbackFile, false, &numBytes, aqp->packetDescs, aqp->packetPosition, &nPackets, inCompleteAQBuffer->mAudioData), "AudioFileReadPackets failed");
    
    if(nPackets > 0) {
        
        inCompleteAQBuffer->mAudioDataByteSize = numBytes;
        AudioQueueEnqueueBuffer(inAQ, inCompleteAQBuffer, (aqp->packetDescs ? nPackets : 0), aqp->packetDescs);
        aqp->packetPosition += nPackets;
    } else {
        CheckError(AudioQueueStop(inAQ, false), "AudioQueueStop failed");
        aqp->isDone = true;
    }
}


#pragma mark main function

int main(int argc, const char * argv[]) {
    // Open an audio file
    
    MyPlayer player = {0};
    
    CFURLRef myFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, kPlaybackFileLocation, kCFURLPOSIXPathStyle, false);
    CheckError(AudioFileOpenURL(myFileURL, kAudioFileReadPermission, 0, &player.playbackFile), "AudioFileOpenURL failed");
    CFRelease(myFileURL);
    
    
    // Set up format
    
    AudioStreamBasicDescription dataFormat;
    UInt32 propSize = sizeof(dataFormat);
    CheckError(AudioFileGetProperty(player.playbackFile, kAudioFilePropertyDataFormat, &propSize, &dataFormat), "Couldn't get file's data format");
    
    
    // Set up queue
    
    AudioQueueRef queue;
    CheckError(AudioQueueNewOutput(&dataFormat, MyAQOutputCallback, &player, NULL, NULL, 0, &queue), "AudioQueueNewOutput failed");
    
    UInt32 bufferByteSize;
    CalculateBytesForTime(player.playbackFile, dataFormat, 0.5, &bufferByteSize, &player.numPacketsToRead);
    
    bool isFormatVBR = (dataFormat.mBytesPerPacket == 0 || dataFormat.mFramesPerPacket ==0);
    if(isFormatVBR) {
        player.packetDescs = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription) * player.numPacketsToRead);
    } else {
        player.packetDescs = NULL;
    }
    
    MyCopyEncoderCookieToQueue(player.playbackFile, queue);
    
    AudioQueueBufferRef buffers[kNumberPlaybackBuffers];
    player.isDone = false;
    player.packetPosition = 0;
    int i;
    for(i = 0; i < kNumberPlaybackBuffers; i++) {
        CheckError(AudioQueueAllocateBuffer(queue, bufferByteSize, &buffers[i]), "AudioQueueAllocateBuffer failed");
        
        MyAQOutputCallback(&player, queue, buffers[i]);
        
        if(player.isDone)
            break;
    }
    
    
    // Start queue
    
    CheckError(AudioQueueStart(queue, NULL), "AudioQueueStart failed");
    printf("Playing...\n");
    do {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.25, false);
    } while(!player.isDone);
    
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 2, false);
    
    
    // Clean up queue when finished
    
    player.isDone = true;
    CheckError(AudioQueueStop(queue, TRUE), "AudioQueueStop failed");
    AudioQueueDispose(queue, TRUE);
    AudioFileClose(player.playbackFile);
    
    return 0;
}
