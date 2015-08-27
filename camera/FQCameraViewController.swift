//
//  FQCameraViewController.swift
//  FiddleQuest
//
//  Created by Yury on 25/08/15.
//  Copyright © 2015 Yury. All rights reserved.
//

import UIKit

@objc protocol FQCameraControllerDelegate : NSObjectProtocol {
    
    // The controller does not dismiss itself; the client dismisses it in these callbacks.
    // The delegate will receive one or the other, but not both, depending whether the user
    // confirms or cancels.
    
    optional func cameraController(controller: FQCameraViewController, didFinishRecordingVideoAtURL url: NSURL)
    optional func cameraControllerDidCancel(controller: FQCameraViewController)
}

class FQCameraViewController: UIViewController {
    
    weak var delegate:FQCameraControllerDelegate?
    
    @IBOutlet weak var cameraView: UIView!

    let cameraManager = CameraManager.sharedInstance
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        // Workaround for iOS 9 Simulator bug
        let name = NSStringFromClass(self.dynamicType).componentsSeparatedByString(".").last!
        super.init(nibName: nibNameOrNil ?? name, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        cameraManager.writeFilesToPhoneLibrary = false
        cameraManager.addPreviewLayerToView(self.cameraView, newCameraOutputMode: CameraOutputMode.VideoWithMic)
        CameraManager.sharedInstance.showErrorBlock = { (erTitle: String, erMessage: String) -> Void in
            let alertController = UIAlertController(title: erTitle, message: erMessage, preferredStyle: .Alert)
            alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { (alertAction) -> Void in }))
            self.presentViewController(alertController, animated: true, completion: { () -> Void in })
        }
    }
 
    override func viewWillAppear(animated: Bool)
    {
        super.viewWillAppear(animated)
        
        cameraManager.resumeCaptureSession()
    }
    
    override func viewWillDisappear(animated: Bool)
    {
        super.viewWillDisappear(animated)
        cameraManager.stopCaptureSession()
    }
    
    @IBAction func recordingButtonPressed(sender: UIButton) {
        switch (self.cameraManager.cameraOutputMode) {
        case .VideoWithMic, .VideoOnly:
            sender.selected = !sender.selected
            if sender.selected {
                self.cameraManager.startRecordingVideo()
            } else {
                self.cameraManager.stopRecordingVideo({ (videoURL, error) -> Void in
                    if let errorOccured = error {
                        self.cameraManager.showErrorBlock(erTitle: "Error occurred", erMessage: errorOccured.localizedDescription)
                    }
                    else
                    {
                        self.delegate?.cameraController?(self, didFinishRecordingVideoAtURL:videoURL)
                    }
                })
            }
        default:
            print("ERROR! Unexpected cameraManager.cameraOutputMode")
            self.delegate?.cameraControllerDidCancel?(self)
        }
    }
    
    override func shouldAutorotate() -> Bool {
        return false
    }
    
    override func preferredInterfaceOrientationForPresentation() -> UIInterfaceOrientation {
        return .LandscapeRight
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return .LandscapeRight
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        print("viewWillTransitionToSize")
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
    }
    
    override func willAnimateRotationToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
        print("willAnimateRotationToInterfaceOrientation")
        super.willAnimateRotationToInterfaceOrientation(toInterfaceOrientation, duration: duration)
    }
}
