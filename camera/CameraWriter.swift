//
//  CameraWriter.swift
//  camera
//
//  Created by Yury on 29/08/15.
//  Copyright © 2015 imaginaryCloud. All rights reserved.
//

import Foundation
import AVFoundation

class CameraWriter : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate{
    
    var assetWriter: AVAssetWriter? = nil
    var videoOutput: AVCaptureVideoDataOutput!
    var videoWriter: AVAssetWriterInput!
    var audioOutput: AVCaptureAudioDataOutput!
    var audioWriter: AVAssetWriterInput!
    
    private let queue = dispatch_queue_create("CameraWriterSessionQueue", DISPATCH_QUEUE_SERIAL)
    
    override init() {
        super.init()
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        videoOutput.videoSettings = captureOutputSettings
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: queue)
        
        
        videoWriter = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoWriterSettings)
        videoWriter.expectsMediaDataInRealTime = true
        
        audioWriter = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: audioWriterSettings)
        audioWriter.expectsMediaDataInRealTime = true
    }
    
    deinit {
        stopWithCompletionHandler(nil)
    }
    
    var shouldStartWriting = false
    func start() throws {
        assetWriter = try createAssetWriter()!
        guard let writer = assetWriter else {
            throw NSError(domain: "CameraWriter", code: 0, userInfo: nil)
        }
        if !writer.startWriting() {
            throw writer.error ?? NSError(domain: "CameraWriter", code: writer.status.rawValue, userInfo: nil)
        }
        shouldStartWriting = true
    }
    
    func stopWithCompletionHandler(handler: ((url: NSURL, error: NSError?) -> Void)?) {
        if let assetWriter = assetWriter where assetWriter.status == .Writing {
            videoWriter.markAsFinished()
            audioWriter.markAsFinished()
            assetWriter.finishWritingWithCompletionHandler({ () -> Void in
                if let handler = handler {
                    handler(url: self.tempFileURL, error: self.assetWriter?.error)
                }
            })
        }
        else if let handler = handler {
            handler(url: self.tempFileURL, error: self.assetWriter?.error ?? NSError(domain: "CameraWriter - Already stopped", code: 0, userInfo: nil))
        }
    }
    
    // MARK: - Encoding settings
    let captureOutputSettings = [kCVPixelBufferPixelFormatTypeKey as NSString : NSNumber(int: Int32(kCVPixelFormatType_32BGRA))]
    
    let videoWriterSettings = [
        AVVideoWidthKey : NSNumber(int: 1280),
        AVVideoHeightKey : NSNumber(int: 720),
        AVVideoCodecKey : AVVideoCodecH264,
        AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
        AVVideoCompressionPropertiesKey :  [AVVideoAverageBitRateKey : NSNumber(int: 700000),
                                            AVVideoMaxKeyFrameIntervalKey : NSNumber(int: 40),
                                            AVVideoProfileLevelKey : AVVideoProfileLevelH264HighAutoLevel]
    ]
    
    
    let audioWriterSettings : [String : AnyObject] = [
        AVFormatIDKey : NSNumber(unsignedInt: kAudioFormatMPEG4AAC as UInt32), //kAudioFormatAppleIMA4
        AVNumberOfChannelsKey : 1,
        AVSampleRateKey : 24000, // 44100
        AVEncoderBitRateKey : 64000 //128000
    ]
    
    var tempFileURL: NSURL = {
        let tempDirURL = NSURL(fileURLWithPath: NSTemporaryDirectory())
        return tempDirURL.URLByAppendingPathComponent("tempMovie", isDirectory: false).URLByAppendingPathExtension("mp4")
    }()

    func createAssetWriter() throws -> AVAssetWriter?
    {
        if NSFileManager.defaultManager().fileExistsAtPath(tempFileURL.path!) {
            try NSFileManager.defaultManager().removeItemAtURL(tempFileURL)
        }
        let writer = try AVAssetWriter(URL: tempFileURL, fileType: AVFileTypeMPEG4)
        
        if writer.canApplyOutputSettings(videoWriterSettings, forMediaType: AVMediaTypeVideo)
        && writer.canApplyOutputSettings(audioWriterSettings, forMediaType: AVMediaTypeAudio)
        && writer.canAddInput(videoWriter)
        && writer.canAddInput(audioWriter)
        {
            writer.addInput(videoWriter)
            writer.addInput(audioWriter)
        }
        else {
            throw NSError(domain: "CameraWriter", code: 0, userInfo: nil)
        }
        return writer
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    @objc func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        print(CMTimeGetSeconds(timestamp))
        
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        
        if let assetWriter = assetWriter where assetWriter.status == .Writing && shouldStartWriting
        {
            shouldStartWriting = false
            assetWriter.startSessionAtSourceTime(timestamp)
            print("startSessionAtSourceTime")
        }
        
        if let assetWriter = assetWriter where
            CMSampleBufferDataIsReady(sampleBuffer)
            && assetWriter.status == .Writing
            && captureOutput == videoOutput
            && videoWriter.readyForMoreMediaData
            && videoWriter.appendSampleBuffer(sampleBuffer) {
            print("Video added")
        }
        else if let assetWriter = assetWriter where
            CMSampleBufferDataIsReady(sampleBuffer)
            && assetWriter.status == .Writing
            && captureOutput == audioOutput
            && audioWriter.readyForMoreMediaData
            && audioWriter.appendSampleBuffer(sampleBuffer) {
                print("Audion added")
        }
        else
        {
            print("\(assetWriter?.status.rawValue) , \(assetWriter?.error)")
        }
        
//        let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
//        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription!)
        
        
        
    }
    
    @objc func captureOutput(captureOutput: AVCaptureOutput!, didDropSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        print("didDropSampleBuffer")
    }

}
