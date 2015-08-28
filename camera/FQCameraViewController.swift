//
//  FQCameraViewController.swift
//  FiddleQuest
//
//  Created by Yury on 25/08/15.
//  Copyright © 2015 Yury. All rights reserved.
//

import UIKit
import CoreMedia

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
    @IBOutlet weak var timerLabel: UILabel!

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

        cameraManager.writeFilesToPhoneLibrary = true
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
    
    override func prefersStatusBarHidden() -> Bool {
        return true;
    }
    
    @IBAction func recordingButtonPressed(sender: UIButton) {
        guard self.cameraManager.cameraOutputMode == .VideoWithMic
        || self.cameraManager.cameraOutputMode == .VideoOnly else {
            print("ERROR! Unexpected cameraManager.cameraOutputMode")
            self.delegate?.cameraControllerDidCancel?(self)
            return
        }
        
        sender.selected = !sender.selected
        if sender.selected {
            self.cameraManager.startRecordingVideo()
            startTimer()
        } else {
            stopTimer()
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
    }
    
    // MARK: - Autorotation
    override func shouldAutorotate() -> Bool {
        return true
    }

    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return .All
    }

    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        print("viewWillTransitionToSize \(size)")
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
    }
    
    // MARK: - Timer
    var timer: NSTimer? = nil
    func startTimer() {
        timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: Selector("timerUpdated:"), userInfo: nil, repeats: true)
        timerLabel.text = "00:00"
    }
    
    @objc func timerUpdated(timer: NSTimer) {
        let timestamp = cameraManager.recordedDuration
        let sec = Int(CMTimeGetSeconds(timestamp))
        let avg = cameraManager.recordedFileSize / Int64(1000 * max(1, sec))
        print(String(format: "%02d:%02d  size = %d   %d kB/sec", sec / 60, sec % 60, cameraManager.recordedFileSize, avg))
        timerLabel.text = String(format: "%02d:%02d", sec / 60, sec % 60)
    }
    
    func stopTimer() {
        timer?.invalidate()
    }
}
