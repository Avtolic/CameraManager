//
//  CameraManager+extentions.swift
//  camera
//
//  Created by Yury on 04/09/15.
//  Copyright © 2015 imaginaryCloud. All rights reserved.
//

import Foundation
import AVFoundation


extension CameraManager {

    /**
    Change current flash mode to next value from available ones.

    :returns: Current flash mode: Off / On / Auto
    */
    public func changeFlashMode() -> AVCaptureFlashMode
    {
        self.flashMode = AVCaptureFlashMode(rawValue: (self.flashMode.rawValue+1)%3)!
        return self.flashMode
    }
}
