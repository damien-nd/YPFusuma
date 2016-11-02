//
//  FSVideoVC.swift
//  Fusuma
//
//  Created by Sacha Durand Saint Omer on 27/10/16.
//  Copyright © 2016 ytakzk. All rights reserved.
//


import UIKit
import AVFoundation

public class FSVideoVC: UIViewController {
    
    public var didCaptureVideo:((URL) -> Void)?
    
    fileprivate var session: AVCaptureSession?
    fileprivate var device: AVCaptureDevice?
    fileprivate var videoInput: AVCaptureDeviceInput?
    fileprivate var videoOutput: AVCaptureMovieFileOutput?
    fileprivate var focusView: UIView?
    fileprivate var timer = Timer()
    fileprivate var dateVideoStarted = Date()
    fileprivate var v = FSCameraView()
    
    override public func loadView() { view = v }
    
    convenience init() {
        self.init(nibName:nil, bundle:nil)
        title = "Video"
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        setupButtons()
        v.flashButton.tap(flashButtonTapped)
        v.flashButton.isHidden = true
        v.timeElapsedLabel.isHidden = false
        v.shotButton.tap(shotButtonTapped)
        v.flipButton.tap(flipButtonTapped)
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if #available(iOS 10.0, *) { //TODO remove
            Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
                self.startCaptureSession()
            }
        } else {
            // Fallback on earlier versions
        }
    }
    
    func setupButtons() {
        let flipImage = imageFromBundle("yp_iconLoop")
        videoStartImage = imageFromBundle("yp_iconVideoCapture")
        videoStopImage = imageFromBundle("yp_iconVideoCaptureRecording")
        v.flashButton.setImage(flashOffImage, for: .normal)
        v.flipButton.setImage(flipImage, for: .normal)
        v.shotButton.setImage(videoStartImage, for: .normal)
    }
    
    func imageFromBundle(_ named:String) -> UIImage {
        let bundle = Bundle(for: self.classForCoder)
        return UIImage(named: named, in: bundle, compatibleWith: nil) ?? UIImage()
    }
    
    
    fileprivate var isRecording = false
    
    
    private func startCaptureSession() {
        session = AVCaptureSession()
        for device in AVCaptureDevice.devices() {
            if let device = device as? AVCaptureDevice , device.position == AVCaptureDevicePosition.back {
                self.device = device
            }
        }
        do {
            if let session = session {
                videoInput = try AVCaptureDeviceInput(device: device)
                session.addInput(videoInput)
                videoOutput = AVCaptureMovieFileOutput()
                let totalSeconds = 30.0 //Total Seconds of capture time
                let timeScale: Int32 = 30 //FPS
                
                let maxDuration = CMTimeMakeWithSeconds(totalSeconds, timeScale)
                
                videoOutput?.maxRecordedDuration = maxDuration
                videoOutput?.minFreeDiskSpaceLimit = 1024 * 1024 //SET MIN FREE SPACE IN BYTES FOR RECORDING TO CONTINUE ON A VOLUME
                
                if session.canAddOutput(videoOutput) {
                    session.addOutput(videoOutput)
                }
                let videoLayer = AVCaptureVideoPreviewLayer(session: session)
                videoLayer?.frame = v.previewViewContainer.bounds
                videoLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
                v.previewViewContainer.layer.addSublayer(videoLayer!)
                session.startRunning()
                
            }
            
            // Focus View
            focusView = UIView(frame: CGRect(x: 0, y: 0, width: 90, height: 90))
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(focus(_:)))
            v.previewViewContainer.addGestureRecognizer(tapRecognizer)
        } catch {
        }
        disableFlash()
        startCamera()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func startCamera() {
        let status = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        if status == AVAuthorizationStatus.authorized {
            session?.startRunning()
        } else if status == AVAuthorizationStatus.denied || status == AVAuthorizationStatus.restricted {
            session?.stopRunning()
        }
    }
    
    func stopCamera() {
        if isRecording {
            toggleRecording()
        }
        session?.stopRunning()
    }
    
    func shotButtonTapped() {
        toggleRecording()
    }
    
    fileprivate func toggleRecording() {
        guard let videoOutput = videoOutput else {
            return
        }
        
        isRecording = !isRecording
        
        let shotImage: UIImage?
        if isRecording {
            shotImage = videoStopImage
        } else {
            shotImage = videoStartImage
        }
        v.shotButton.setImage(shotImage, for: .normal)
        
        if isRecording {
            let outputPath = "\(NSTemporaryDirectory())output.mov"
            let outputURL = URL(fileURLWithPath: outputPath)
            
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: outputPath) {
                do {
                    try fileManager.removeItem(atPath: outputPath)
                } catch {
                    print("error removing item at path: \(outputPath)")
                    isRecording = false
                    return
                }
            }
            v.flipButton.isEnabled = false
            v.flashButton.isEnabled = false
            videoOutput.startRecording(toOutputFileURL: outputURL, recordingDelegate: self)
        } else {
            videoOutput.stopRecording()
            v.flipButton.isEnabled = true
            v.flashButton.isEnabled = true
        }
        return
    }
    
    func flipButtonTapped() {
        if let deviceInput = videoInput, let s = session  {
            videoInput = flipCameraFor(captureDeviceInput: deviceInput, onSession: s)
        }
    }
    
    func flashButtonTapped() {
        device?.tryToggleFlash()
        refreshFlashButton()
    }
    
    func flashImage(forAVCaptureFlashMode:AVCaptureFlashMode) -> UIImage {
        switch forAVCaptureFlashMode {
        case .on: return flashOnImage!
        case .off: return flashOffImage!
        default: return flashOffImage!
        }
    }
}

extension FSVideoVC: AVCaptureFileOutputRecordingDelegate {
    
    public func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        print("started recording to: \(fileURL)")
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        dateVideoStarted = Date()
    }
    
    func tick() {
        let timeElapsed = Date().timeIntervalSince(dateVideoStarted)
        v.timeElapsedLabel.text = formattedStrigFrom(timeElapsed)
        let p:Float = Float(timeElapsed) / Float(30)
        DispatchQueue.main.async {
            self.v.progressBar.progress = p
            UIView.animate(withDuration: 1, animations: {
                self.v.layoutIfNeeded()
            })
        }
    }
    
    func foo(_ timeInterval:TimeInterval) -> String {
        let interval = Int(timeInterval)
        let seconds = interval % 60
        let r = timeInterval-Double(interval)
        let miliseconds:Int = Int(r*100)
        return String(format: "%02d:%02d", seconds, miliseconds)
    }
    
    public func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        print("finished recording to: \(outputFileURL)")
        didCaptureVideo?(outputFileURL)
        timer.invalidate()
    }
}

extension FSVideoVC {
    
    func focus(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: v)
        let viewsize = v.bounds.size
        let newPoint = CGPoint(x: point.y/viewsize.height, y: 1.0-point.x/viewsize.width)
        setFocusPointOnCurrentDevice(newPoint)

        
        if let fv = focusView {
            fv.center = point
            configureFocusView(fv)
            v.addSubview(fv)
            animateFocusView(fv)
        }
    }
    
    func disableFlash() {
        device?.disableFlash()
        refreshFlashButton()
    }
    
    func refreshFlashButton() {
        if let device = device {
            v.flashButton.setImage(flashImage(forAVCaptureFlashMode:device.flashMode), for: .normal)
        }
    }
}
