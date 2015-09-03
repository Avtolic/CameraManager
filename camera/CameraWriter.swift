//
//  CameraWriter.swift
//  camera
//
//  Created by Yury on 29/08/15.
//  Copyright © 2015 imaginaryCloud. All rights reserved.
//

import Foundation
import AVFoundation

class CameraWriter : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate{
    
    var assetWriter: AVAssetWriter? = nil
    var videoOutput: AVCaptureVideoDataOutput!
    var videoWriter: AVAssetWriterInput!
    
    private let queue = dispatch_queue_create("CameraWriterSessionQueue", DISPATCH_QUEUE_SERIAL)
    
    override init() {
        super.init()
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        videoOutput.videoSettings = captureOutputSettings
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        videoWriter = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoWriterSettings)
        videoWriter.expectsMediaDataInRealTime = true
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
        AVVideoWidthKey: NSNumber(int: 1280),
        AVVideoHeightKey: NSNumber(int: 720),
        AVVideoCodecKey: AVVideoCodecH264,
        AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
        AVVideoCompressionPropertiesKey :  [AVVideoAverageBitRateKey : NSNumber(int: 600000),
                                            AVVideoMaxKeyFrameIntervalKey : NSNumber(int: 40),
                                            AVVideoProfileLevelKey : AVVideoProfileLevelH264HighAutoLevel]
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
        
        writer.addInput(videoWriter)
        return writer
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    @objc func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        if let assetWriter = assetWriter where assetWriter.status == .Writing && shouldStartWriting
        {
            shouldStartWriting = false
            assetWriter.startSessionAtSourceTime(timestamp)
        }
        
        if let assetWriter = assetWriter where
            CMSampleBufferDataIsReady(sampleBuffer)
            && assetWriter.status == .Writing
            && videoWriter.readyForMoreMediaData
            && videoWriter.appendSampleBuffer(sampleBuffer) {
            print("didOutputSampleBuffer")
        }
        
        let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription!)
        
        
        print(CMTimeGetSeconds(timestamp))
    }
    
    @objc func captureOutput(captureOutput: AVCaptureOutput!, didDropSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        print("didDropSampleBuffer")
    }

}
