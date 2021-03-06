//
//  CameraController.swift
//  saycheese
//
//  Created by Jovin Kyenkungu on 2018-02-28.
//  Copyright © 2018 Jovin K. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit


class CameraController : NSObject {
    
    var captureSession: AVCaptureSession?
    var frontCamera: AVCaptureDevice?
    var rearCamera: AVCaptureDevice?
    
    var currentCameraPosition: CameraPosition?
    var frontCameraInput: AVCaptureDeviceInput?
    var rearCameraInput: AVCaptureDeviceInput?
    
    var outputURL: URL! //URL path video is stored
    
    //Flash
    var flashMode = AVCaptureDevice.FlashMode.off
    
    //For camera output
    var photoOutput: AVCapturePhotoOutput?
    
    //Video output
    var movieOutput: AVCaptureMovieFileOutput?
    
    //Preview Screen
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    //
    var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?
    
    
    //Handle capture session, call completionHandler when done
   
    func prepare() {
        
        func createCaptureSession() {
            
            self.captureSession = AVCaptureSession()
            
            
            
        }
        
        
        func configureCaptureDevices() throws {
            
            //init session to find ALL cameras available
            let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified)
            
            let cameras = (session.devices.flatMap { $0 })
            if cameras.isEmpty { throw CameraControllerError.noCamerasAvailable }
            
            //Search for camera and init them
            for camera in cameras {
                if camera.position == .front {
                    self.frontCamera = camera
                }
                
                if camera.position == .back {
                    self.rearCamera = camera
                    //Configure rear for auto-focus
                    try camera.lockForConfiguration()
                    camera.focusMode = .continuousAutoFocus
                    camera.unlockForConfiguration()
                }
            }
            
            
            
        }
        
        
        
        
        func configureDeviceInputs() throws {
            //capture device inputs, which take capture devices and connect them to our capture session
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            
            //Set capture devices to accept/take pictures
            
            //AV only allows one camera input at a time - try rear first then front, else throw err
            //CanAddInput
            
            
            if let frontCamera = self.frontCamera {
                self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                
                if captureSession.canAddInput(self.frontCameraInput!) { captureSession.addInput(self.frontCameraInput!) }
                
                self.currentCameraPosition = .front
                
            } else if let rearCamera = self.rearCamera {
                self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
                
                if captureSession.canAddInput(self.rearCameraInput!) { captureSession.addInput(self.rearCameraInput!) } else { throw CameraControllerError.inputsAreInvalid }
                
                self.currentCameraPosition = .rear
            }
                
            else { throw CameraControllerError.noCamerasAvailable }
        }
        
        
        func configurePhotoOutput() throws {
            
            /*guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            //CanAddOutput
            self.photoOutput = AVCapturePhotoOutput()
            self.photoOutput!.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecJPEG])], completionHandler: nil)
            
            if captureSession.canAddOutput(self.photoOutput!) { captureSession.addOutput(self.photoOutput!) }*/
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            //CanAddOutput
            self.movieOutput = AVCaptureMovieFileOutput()
            //self.photoOutput!.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecJPEG])], completionHandler: nil)
            
            if captureSession.canAddOutput(self.movieOutput!) { captureSession.addOutput(self.movieOutput!) }
            
            captureSession.startRunning()
            
            
            
        }
        
        DispatchQueue(label: "prepare").async {
            do {
                createCaptureSession()
                try configureCaptureDevices()
                try configureDeviceInputs()
                try configurePhotoOutput()
            }
                
            catch {
                print(error)
                /*DispatchQueue.main.async {
                    //completionHandler(error)
                    return false
                }*/
                
            }
        }
            /*DispatchQueue.main.async {
                //completionHandler(nil)
            }*/
       // }
        
        
    }
    
    
    
   
    
    
    
    
}

extension CameraController {
    
    //Show output of captureLayer
    func displayPreview(on view: UIView) throws {
        
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.previewLayer?.connection?.videoOrientation = .portrait
        
        view.layer.insertSublayer(self.previewLayer!, at: 0)
        self.previewLayer?.frame = view.frame
        
        
    }
    
    func switchCameras() throws {
        
        //Make sure we have a running session
        guard let currentCameraPosition = currentCameraPosition, let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        //beginConfig
        captureSession.beginConfiguration()
        
        func switchToFrontCamera() throws {
            guard let inputs = captureSession.inputs as? [AVCaptureInput], let rearCameraInput = self.rearCameraInput, inputs.contains(rearCameraInput),
                let frontCamera = self.frontCamera else { throw CameraControllerError.invalidOperation }
            
            self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            
            captureSession.removeInput(rearCameraInput)
            
            if captureSession.canAddInput(self.frontCameraInput!) {
                captureSession.addInput(self.frontCameraInput!)
                
                self.currentCameraPosition = .front
            }
                
            else { throw CameraControllerError.invalidOperation }
        }
        
        func switchToRearCamera() throws {
            guard let inputs = captureSession.inputs as? [AVCaptureInput], let frontCameraInput = self.frontCameraInput, inputs.contains(frontCameraInput),
                let rearCamera = self.rearCamera else { throw CameraControllerError.invalidOperation }
            
            self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
            
            captureSession.removeInput(frontCameraInput)
            
            if captureSession.canAddInput(self.rearCameraInput!) {
                captureSession.addInput(self.rearCameraInput!)
                
                self.currentCameraPosition = .rear
            }
                
            else { throw CameraControllerError.invalidOperation }
        }
        
        //
        switch currentCameraPosition {
        case .front:
            try switchToRearCamera()
            
        case .rear:
            try switchToFrontCamera()
        }
        
        //Save change - configuration
        captureSession.commitConfiguration()
        
        
        
    }
    
    func captureImage(completion: @escaping (UIImage?, Error?) -> Void) {
        guard let captureSession = captureSession, captureSession.isRunning else { completion(nil, CameraControllerError.captureSessionIsMissing); return }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
        
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
        
        self.photoCaptureCompletionBlock = completion
    }
    
    
    
}

extension CameraController {
    
    //Create tempURL for video to buffer to
    func tempURL() -> URL? {
        let directory = NSTemporaryDirectory() as NSString
        
        if directory != "" {
            let path = directory.appendingPathComponent(NSUUID().uuidString + ".mp4")
            return URL(fileURLWithPath: path)
        }
        
        return nil
    }
    
    
    
    func startRecording() {
        
        if movieOutput?.isRecording == false {
            
            let connection = movieOutput?.connection(with: AVMediaType.video)
            /*if (connection?.isVideoOrientationSupported)! {
                connection?.videoOrientation = currentVideoOrientation()
            }*/
            
            
            if (connection?.isVideoStabilizationSupported)! {
                connection?.preferredVideoStabilizationMode = AVCaptureVideoStabilizationMode.auto
            }
            let device = (self.currentCameraPosition == CameraPosition.rear) ? self.rearCameraInput?.device : self.frontCameraInput?.device
            
            //let device = activeInput.device
            if (device?.isSmoothAutoFocusSupported)! {
                do {
                    try device?.lockForConfiguration()
                    device?.isSmoothAutoFocusEnabled = false
                    device?.unlockForConfiguration()
                } catch {
                    print("Error setting configuration: \(error)")
                }
                
            }
            
            //Output video
            outputURL = tempURL()
            movieOutput?.startRecording(to: outputURL, recordingDelegate: self as! AVCaptureFileOutputRecordingDelegate)
            
        }
        else {
            stopRecording()
        }
        
    }
    
    func stopRecording() {
        
        if movieOutput?.isRecording == true {
            movieOutput?.stopRecording()
        }
    }
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        
    }
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        if (error != nil) {
            print("Error recording movie: \(error!.localizedDescription)")
        } else {
            
            let videoRecorded = outputURL! as URL
            
            print(videoRecorded)
            
            
        }
        outputURL = nil
    }

    
    
    
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    //Photo saving function
    public func photoOutput(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?,
                        resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Swift.Error?) {
        if let error = error { self.photoCaptureCompletionBlock?(nil, error) }
            
        else if let buffer = photoSampleBuffer, let data = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: buffer, previewPhotoSampleBuffer: nil),
            let image = UIImage(data: data) {
            
            self.photoCaptureCompletionBlock?(image, nil)
        }
            
        else {
            self.photoCaptureCompletionBlock?(nil, CameraControllerError.unknown)
        }
    }
}

//ENUMs

extension CameraController {
    
    enum CameraControllerError: Swift.Error {
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }
    
    public enum CameraPosition {
        case front
        case rear
    }
    
}
