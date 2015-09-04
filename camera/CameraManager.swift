//
//  CameraManager.swift
//  camera
//
//  Created by Yury on 29/08/15.
//  Copyright (c). All rights reserved.
//

import UIKit
import AVFoundation
import AssetsLibrary

private let _singletonSharedInstance = CameraManager()

public enum CameraState {
    case Ready, AccessDenied, NoDeviceFound, NotDetermined
}

public enum CameraDevice {
    case Front, Back
}

public enum CameraOutputMode {
    case StillImage, VideoWithMic, VideoOnly
}

/// Class for handling iDevices custom camera usage
public class CameraManager {

    // MARK: - Public properties

    /// CameraManager singleton instance to use the camera.
    public class var sharedInstance: CameraManager {
        return _singletonSharedInstance
    }
    
    /// Capture session to customize camera settings.
    public var captureSession: AVCaptureSession = AVCaptureSession()
    
    /// Property to determine if the manager should show the error for the user. If you want to show the errors yourself set this to false. If you want to add custom error UI set showErrorBlock property. Default value is false.
    public var showErrorsToUsers = false
    
    /// Property to determine if the manager should show the camera permission popup immediatly when it's needed or you want to show it manually. Default value is true. Be carful cause using the camera requires permission, if you set this value to false and don't ask manually you won't be able to use the camera.
    public var showAccessPermissionPopupAutomatically = true
    
    /// A block creating UI to present error message to the user. This can be customised to be presented on the Window root view controller, or to pass in the viewController which will present the UIAlertController, for example.
    public var showErrorBlock:(erTitle: String, erMessage: String) -> Void = { (erTitle: String, erMessage: String) -> Void in
        
//        var alertController = UIAlertController(title: erTitle, message: erMessage, preferredStyle: .Alert)
//        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { (alertAction) -> Void in
//            //
//        }))
//        
//        let topController = UIApplication.sharedApplication().keyWindow?.rootViewController
//        
//        if (topController != nil) {
//            topController?.presentViewController(alertController, animated: true, completion: { () -> Void in
//                //
//            })
//        }
    }

    /// Property to determine if manager should write the resources to the phone library. Default value is true.
    public var writeFilesToPhoneLibrary = true

    /// The Bool property to determine if current device has front camera.
    public var hasFrontCamera: Bool = {
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as! [AVCaptureDevice]
        return devices.filter{$0.position == .Front}.count > 0
    }()
    
    /// The Bool property to determine if current device has flash.
    public var hasFlash: Bool = {
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as! [AVCaptureDevice]
        return devices.filter{$0.position == .Back && $0.hasFlash}.count > 0
    }()
    
    /// Property to change camera device between front and back.
    public var cameraDevice: CameraDevice = CameraDevice.Back {
        didSet {
            _setupInputs()
        }
    }

    /// Property to change camera flash mode.
    public var flashMode: AVCaptureFlashMode = .Off {
        didSet {
            setFlashMode(flashMode)
        }
    }

    /// Property to change camera output.
    public var cameraOutputMode: CameraOutputMode = CameraOutputMode.StillImage {
        didSet {
            _setupInputs() // To add a microphone if required
            _setupOutputs()
        }
    }
    
    // MARK: - Private properties

    private weak var embedingView: UIView?

    private let sessionQueue = dispatch_queue_create("CameraSessionQueue", DISPATCH_QUEUE_SERIAL)

    private var stillImageOutput = AVCaptureStillImageOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer
    private var library = ALAssetsLibrary()

    private var cameraIsObservingDeviceOrientation = false
    
    var cameraWriter: CameraWriter? = CameraWriter()
    
    
    // MARK: - CameraManager

    /**
    Inits a capture session and adds a preview layer to the given view. Preview layer bounds will automaticaly be set to match given view. Default session is initialized with still image output.

    :param: view The view you want to add the preview layer to
    :param: cameraOutputMode The mode you want capturesession to run image / video / video and microphone
    
    :returns: Current state of the camera: Ready / AccessDenied / NoDeviceFound / NotDetermined.
    */
    public func addPreviewLayerToView(view: UIView) -> CameraState
    {
        return addPreviewLayerToView(view, newCameraOutputMode: cameraOutputMode)
    }
    public func addPreviewLayerToView(view: UIView, newCameraOutputMode: CameraOutputMode) -> CameraState
    {
        if _canLoadCamera() {
            if let _ = previewLayer.superlayer {
                previewLayer.removeFromSuperlayer()
            }
            embedingView = view
            previewLayer.frame = view.layer.bounds
            view.clipsToBounds = true
            view.layer.addSublayer(previewLayer)
            cameraOutputMode = newCameraOutputMode
        }
        return _checkIfCameraIsAvailable()
    }

    /**
    Asks the user for camera permissions. Only works if the permissions are not yet determined. Note that it'll also automaticaly ask about the microphone permissions if you selected VideoWithMic output.
    
    :param: completition Completition block with the result of permission request
    */
    public func askUserForCameraPermissions(completition: Bool -> Void)
    {
        AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { (alowedAccess) -> Void in
            if self.cameraOutputMode == .VideoWithMic {
                AVCaptureDevice.requestAccessForMediaType(AVMediaTypeAudio, completionHandler: { (alowedAccess) -> Void in
                    dispatch_sync(dispatch_get_main_queue(), { () -> Void in
                        completition(alowedAccess)
                    })
                })
            } else {
                dispatch_sync(dispatch_get_main_queue(), { () -> Void in
                    completition(alowedAccess)
                })

            }
        })
    }

    /**
    Stops running capture session but all setup devices, inputs and outputs stay for further reuse.
    */
    public func stopCaptureSession()
    {
        captureSession.stopRunning()
        _stopFollowingDeviceOrientation()
    }

    /**
    Resumes capture session.
    */
    public func resumeCaptureSession()
    {
        if !captureSession.running {
            captureSession.startRunning()
            _startFollowingDeviceOrientation()
        }
//        } else {
//            if self._canLoadCamera() {
//                if self.cameraIsSetup {
//                    self.stopAndRemoveCaptureSession()
//                }
//                self._setupCamera({Void -> Void in
//                    if let validEmbedingView = self.embedingView {
//                        self._addPreeviewLayerToView(validEmbedingView)
//                    }
//                    self._startFollowingDeviceOrientation()
//                })
//            }
//        }
    }

    /**
    Captures still image from currently running capture session.

    :param: imageCompletition Completition block containing the captured UIImage
    */
    public func capturePictureWithCompletition(imageCompletition: (UIImage?, NSError?) -> Void)
    {
        if cameraOutputMode == .StillImage {
            dispatch_async(self.sessionQueue, {
                self.stillImageOutput.captureStillImageAsynchronouslyFromConnection(self.stillImageOutput.connectionWithMediaType(AVMediaTypeVideo), completionHandler: { [weak self] (sample: CMSampleBuffer!, error: NSError!) -> Void in
                    if (error != nil) {
                        dispatch_async(dispatch_get_main_queue(), {
                            if let weakSelf = self {
                                weakSelf._show(NSLocalizedString("Error", comment:""), message: error.localizedDescription)
                            }
                        })
                        imageCompletition(nil, error)
                    } else {
                        let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sample)
                        if let weakSelf = self {
                            if weakSelf.writeFilesToPhoneLibrary {
                                weakSelf.library.writeImageDataToSavedPhotosAlbum(imageData, metadata:nil) {
                                    (picUrl, error) -> Void in
                                    if (error != nil) {
                                        dispatch_async(dispatch_get_main_queue(), {
                                            weakSelf._show(NSLocalizedString("Error", comment:""), message: error.localizedDescription)
                                        })
                                    }
                                }
                            }
                        }
                        imageCompletition(UIImage(data: imageData), nil)
                    }
                })
            })
        } else {
            _show(NSLocalizedString("Capture session output mode video", comment:""), message: NSLocalizedString("I can't take any picture", comment:""))
        }
    }

    /**
    Starts recording a video with or without voice as in the session preset.
    */
    public func startRecordingVideo()
    {
        if cameraOutputMode != .StillImage {
            do {
                try cameraWriter?.start()
            } catch let error {
                _showError(error as NSError)
            }
        } else {
            _show(NSLocalizedString("Capture session output still image", comment:""), message: NSLocalizedString("I can only take pictures", comment:""))
        }
    }

    /**
    Stop recording a video. Save it to the cameraRoll and give back the url.
    */
    public func stopRecordingVideo(completition:(videoURL: NSURL?, error: NSError?) -> Void)
    {
        cameraWriter?.stopWithCompletionHandler{ (url, error) -> Void in
            if let error = error
            {
                self._show(NSLocalizedString("Unable to save video to the iPhone", comment:""), message: error.localizedDescription)
                completition(videoURL: nil, error: error)
            }
            else if self.writeFilesToPhoneLibrary
            {
                self.library.writeVideoAtPathToSavedPhotosAlbum(url){ (assetURL, error) -> Void in
                    if let error = error {
                        self._show(NSLocalizedString("Unable to save video to the iPhone.", comment:""), message: error.localizedDescription)
                    }
                    completition(videoURL: assetURL, error: error)
                }
            } else
            {
                completition(videoURL: url, error: error)
            }
        }
    }

    /**
    Current camera status.
    
    :returns: Current state of the camera: Ready / AccessDenied / NoDeviceFound / NotDetermined
    */
    public func currentCameraStatus() -> CameraState
    {
        return _checkIfCameraIsAvailable()
    }
            
    // MARK: - CameraManager()
    
    @objc private func _orientationChanged()
    {
        var currentConnection: AVCaptureConnection?;
        switch cameraOutputMode {
        case .StillImage:
            currentConnection = stillImageOutput.connectionWithMediaType(AVMediaTypeVideo)
        case .VideoOnly, .VideoWithMic:
            currentConnection = cameraWriter?.videoOutput.connectionWithMediaType(AVMediaTypeVideo)
        }
        if let validPreviewLayerConnection = previewLayer.connection {
            if validPreviewLayerConnection.supportsVideoOrientation {
                validPreviewLayerConnection.videoOrientation = _currentVideoOrientation()
            }
        }
        if let validOutputLayerConnection = currentConnection {
            if validOutputLayerConnection.supportsVideoOrientation {
                validOutputLayerConnection.videoOrientation = _currentVideoOrientation()
            }
        }
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            if let validEmbedingView = self.embedingView {
                self.previewLayer.frame = validEmbedingView.bounds
            }
        })
    }

    private func _currentVideoOrientation() -> AVCaptureVideoOrientation
    {
//        return .LandscapeRight
        switch UIDevice.currentDevice().orientation {
        case .LandscapeLeft:
            return .LandscapeRight
        case .LandscapeRight:
            return .LandscapeLeft
        default:
            return .Portrait
        }
    }

    private func _canLoadCamera() -> Bool
    {
        let currentCameraState = _checkIfCameraIsAvailable()
        return currentCameraState == .Ready || (currentCameraState == .NotDetermined && showAccessPermissionPopupAutomatically)
    }

    init () {
        captureSession.beginConfiguration()
        
        let sessionPreset = AVCaptureSessionPresetHigh
        if captureSession.canSetSessionPreset(sessionPreset) {
            captureSession.sessionPreset = sessionPreset
        } else {
            print("Camera preset not supported - \(sessionPreset)")
        }
        
        captureSession.commitConfiguration()
        
        previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        _setupOutputs()
        setFlashMode(self.flashMode)
        
        _startFollowingDeviceOrientation()
        _orientationChanged()
    }
    
    public func startCamera()
    {
        captureSession.startRunning()
    }
    
    public func startCameraAsynchWithCompletion(completition: Void -> Void)
    {
        dispatch_async(sessionQueue, {
            self.captureSession.startRunning()
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                completition()
            })
        })
    }

    private func _startFollowingDeviceOrientation()
    {
        if !cameraIsObservingDeviceOrientation {
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "_orientationChanged", name: UIDeviceOrientationDidChangeNotification, object: nil)
            cameraIsObservingDeviceOrientation = true
        }
    }

    private func _stopFollowingDeviceOrientation()
    {
        if cameraIsObservingDeviceOrientation {
            NSNotificationCenter.defaultCenter().removeObserver(self, name: UIDeviceOrientationDidChangeNotification, object: nil)
            cameraIsObservingDeviceOrientation = false
        }
    }

    private func _checkIfCameraIsAvailable() -> CameraState
    {
        let deviceHasCamera = UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.Rear) || UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.Front)
        if deviceHasCamera {
            let authorizationStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
            let userAgreedToUseIt = authorizationStatus == .Authorized
            if userAgreedToUseIt {
                return .Ready
            } else if authorizationStatus == AVAuthorizationStatus.NotDetermined {
                return .NotDetermined
            } else {
                _show(NSLocalizedString("Camera access denied", comment:""), message:NSLocalizedString("You need to go to settings app and grant acces to the camera device to use it.", comment:""))
                return .AccessDenied
            }
        } else {
            _show(NSLocalizedString("Camera unavailable", comment:""), message:NSLocalizedString("The device does not have a camera.", comment:""))
            return .NoDeviceFound
        }
    }

    func deviceInputFromDevice(device: AVCaptureDevice) -> AVCaptureDeviceInput? {
        do {
            return try AVCaptureDeviceInput(device: device)
        } catch let outError {
            _show(NSLocalizedString("Device setup error occured", comment:""), message: "\(outError)")
            return nil
        }
    }
    
    lazy var frontCameraDevice: AVCaptureDevice? = {
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as! [AVCaptureDevice]
        return devices.filter{$0.position == .Front}.first
    }()
    
    lazy var backCameraDevice: AVCaptureDevice? = {
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as! [AVCaptureDevice]
        return devices.filter{$0.position == .Back}.first
    }()

    lazy var mic: AVCaptureDevice? = {
        return AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio)
    }()
    
    private func _setupInputs() {
        captureSession.beginConfiguration()
        let inputs = captureSession.inputs.flatMap{$0 as? AVCaptureDeviceInput}
        
        var requiredDevices : [AVCaptureDevice] = []
        if let videoDevice = cameraDevice == .Front ? frontCameraDevice : backCameraDevice {
            requiredDevices.append(videoDevice)
        }
        if cameraOutputMode == .VideoWithMic, let mic = mic {
            requiredDevices.append(mic)
        }
        
        for input in inputs where !requiredDevices.contains(input.device) {
            captureSession.removeInput(input)
        }
        for device in requiredDevices where (inputs.filter{$0.device == device}.count == 0) {
            if let deviceInput = deviceInputFromDevice(device) {
                captureSession.addInput(deviceInput)
            }
        }
        captureSession.commitConfiguration()
    }
    
    private func _setupOutputs()
    {
        captureSession.beginConfiguration()
        
        var requiredOutputs : [AVCaptureOutput] = []
        switch cameraOutputMode {
        case .StillImage:
            requiredOutputs.append(stillImageOutput)
        case .VideoOnly:
            requiredOutputs.append(cameraWriter!.videoOutput)
        case .VideoWithMic:
            requiredOutputs.append(cameraWriter!.videoOutput)
            requiredOutputs.append(cameraWriter!.audioOutput)
        }

        let outputs = captureSession.outputs.flatMap{$0 as? AVCaptureOutput}
        for output in outputs where !requiredOutputs.contains(output) {
            captureSession.removeOutput(output)
        }
        for output in requiredOutputs where !outputs.contains(output) {
            captureSession.addOutput(output)
        }

        captureSession.commitConfiguration()
        _orientationChanged()
    }
    
    func setTorchLevel(torchLevel: Float)
    {
        captureSession.beginConfiguration()
        defer {
            captureSession.commitConfiguration()
        }
        
        if let device = backCameraDevice where device.hasTorch && device.torchAvailable {
            do {
                try device.lockForConfiguration()
                defer {
                    device.unlockForConfiguration()
                }
            
                if torchLevel <= 0.0 {
                    device.torchMode = .Off
                }
                else if torchLevel >= 1.0 {
                    try device.setTorchModeOnWithLevel(min(torchLevel, AVCaptureMaxAvailableTorchLevel))
                }
            }
            catch let error {
                print("Failed to set up torch level with error \(error)")
                return
            }
        }
    }

    private func setFlashMode(flashMode: AVCaptureFlashMode)
    {
        captureSession.beginConfiguration()
        defer {
            captureSession.commitConfiguration()
        }
        
        if let device = backCameraDevice where device.hasFlash && device.flashAvailable && device.isFlashModeSupported(flashMode) {
            do {
                try device.lockForConfiguration()
                defer {
                    device.unlockForConfiguration()
                }
                device.flashMode = flashMode
            }
            catch let error {
                print("Failed to set up flash mode with error \(error)")
                return
            }
        }
    }
    
    private func _showError(error: NSError)
    {
        _show(error.domain, message: error.description)
    }
    
    private func _show(title: String, message: String)
    {
        if showErrorsToUsers {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                print("CameraManager error - \(title): \(message)")
                self.showErrorBlock(erTitle: title, erMessage: message)
            })
        }
    }
    
    deinit {
        stopCaptureSession()
    }
}
