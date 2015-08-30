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
    var videoOutput: AVCaptureOutput? = nil
    
    private let queue = dispatch_queue_create("CameraWriterSessionQueue", DISPATCH_QUEUE_SERIAL)
    
    override init() {
        super.init()
        videoOutput = createCaptureOutput()
    }
    
    
    deinit {
        stopWithCompletionHandler(nil)
    }
    
    func start() throws {
        assetWriter = try createAssetWriter()!
        guard let writer = assetWriter else {
            throw NSError(domain: "CameraWriter", code: 0, userInfo: nil)
        }
        if !writer.startWriting() {
            throw writer.error ?? NSError(domain: "CameraWriter", code: writer.status.rawValue, userInfo: nil)
        }
        assetWriter?.startSessionAtSourceTime(kCMTimeZero)
    }
    
    func stopWithCompletionHandler(handler: ((url: NSURL, error: NSError?) -> Void)?) {
        if let assetWriter = assetWriter where assetWriter.status == .Writing {
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
    let pixelBufferSettings = [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(int: Int32(kCVPixelFormatType_32BGRA))]
    
    let videoWriterSettings = [AVVideoWidthKey: NSNumber(int: 640),
        AVVideoHeightKey: NSNumber(int: 640),
        AVVideoCodecKey: AVVideoCodecH264]
    
    // does it needed to check .connectionWithMediaType(AVMediaTypeVideo) where connection.active somewhere?
    func createCaptureOutput() -> AVCaptureOutput {
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        videoOutput.videoSettings = captureOutputSettings
        videoOutput.alwaysDiscardsLateVideoFrames = true
        return videoOutput
    }
    
    var tempFileURL: NSURL = {
        let tempDirURL = NSURL(fileURLWithPath: NSTemporaryDirectory())
        return tempDirURL.URLByAppendingPathComponent("tempMovie", isDirectory: false).URLByAppendingPathExtension("mp4")
    }()
    
//        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput, sourcePixelBufferAttributes: pixelBufferSettings)
//    writer.startWriting()
//    writer.startSessionAtSourceTime(kCMTimeZero)

    
    func createAssetWriter() throws -> AVAssetWriter?
    {
        if NSFileManager.defaultManager().fileExistsAtPath(tempFileURL.path!) {
            try NSFileManager.defaultManager().removeItemAtURL(tempFileURL)
        }
        let writer = try AVAssetWriter(URL: tempFileURL, fileType: AVFileTypeMPEG4)
        
        let video:AVAssetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoWriterSettings)
        video.expectsMediaDataInRealTime = true
        writer.addInput(video)
        
        return writer
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    @objc func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        print("didOutputSampleBuffer")
    }
    
    @objc func captureOutput(captureOutput: AVCaptureOutput!, didDropSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        print("didDropSampleBuffer")
    }

}
