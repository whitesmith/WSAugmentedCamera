//
//  WSAugmentedCameraView.swift
//  WSAugmentedCamera
//
//  Created by Ricardo Pereira on 09/06/2017.
//  Copyright © 2017 Whitesmith. All rights reserved.
//

import UIKit
import AVFoundation

public class WSAugmentedCameraView: UIView {

    // MARK: - Session Management

    private let session = AVCaptureSession()
    // Communicate with the session and other session objects on this queue.
    private let sessionQueue = DispatchQueue(label: "co.whitesmith.WSAugmentedCameraView.session", attributes: [], target: nil)


    // MARK: - Inputs
    private var deviceInput: AVCaptureDeviceInput!

    // MARK: - Outputs
    private let photoOutput = AVCapturePhotoOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    fileprivate let context = CIContext()

    // MARK: - UI elements
    fileprivate let showcaseImageView = UIImageView()
    fileprivate let showcaseFrame = CALayer()

    // MARK: - Face detections
    fileprivate lazy var showcaseLeftEyeLayer: CALayer = { [unowned self] in
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        layer.borderColor = UIColor.red.cgColor
        layer.borderWidth = 1.0
        self.layer.addSublayer(layer)
        return layer
    }()
    fileprivate lazy var showcaseRightEyeLayer: CALayer = { [unowned self] in
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        layer.borderColor = UIColor.red.cgColor
        layer.borderWidth = 1.0
        self.layer.addSublayer(layer)
        return layer
    }()

    // Test
    var lastFace: CGRect?


    // MARK: - Initializers

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestures()
        setupUI()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    // MARK: - UIView

    override public class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    fileprivate var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer")
        }
        layer.videoGravity = AVLayerVideoGravityResizeAspectFill
        return layer
    }

    // MARK: - Setup

    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }

    private var setupResult: SessionSetupResult = .success

    private func setupSession() {
        if setupResult != .success {
            return
        }

        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }

        /*
         We do not create an AVCaptureMovieFileOutput when setting up the session because the
         AVCaptureMovieFileOutput does not support movie recording with AVCaptureSessionPresetPhoto.
         */
        session.sessionPreset = AVCaptureSessionPresetiFrame960x540 //1000x750
        videoPreviewLayer.session = session

        // Add video input.
        do {
            var defaultVideoDevice: AVCaptureDevice?

            // Choose the back dual camera if available, otherwise default to a wide angle camera.
            if let dualCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInDualCamera, mediaType: AVMediaTypeVideo, position: .back) {
                defaultVideoDevice = dualCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInTelephotoCamera, mediaType: AVMediaTypeVideo, position: .back) {
                // If the back dual camera is not available, default to the back wide angle camera.
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .front) {
                /*
                 In some cases where users break their phones, the back wide angle camera is not available.
                 In this case, we should default to the front wide angle camera.
                 */
                defaultVideoDevice = frontCameraDevice
            }

            // OR choose from a list of available camera devices
            let deviceDiscoverySession = AVCaptureDeviceDiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaTypeVideo, position: .unspecified)
            // Found the proper camera device
            guard let availableCameraDevices = deviceDiscoverySession?.devices else {
                assert(false, "Invalid devices")
            }

            var cameraBackDevice: AVCaptureDevice?
            var cameraFrontDevice: AVCaptureDevice?

            for device in availableCameraDevices {
                if device.position == .back {
                    cameraBackDevice = device
                }
                else if device.position == .front {
                    cameraFrontDevice = device
                }
            }

            // Use
            defaultVideoDevice = cameraFrontDevice

            let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice!)

            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.deviceInput = videoDeviceInput

                DispatchQueue.main.async {
                    /*
                     Why are we dispatching this to the main queue?
                     Because AVCaptureVideoPreviewLayer is the backing layer for PreviewView and UIView
                     can only be manipulated on the main thread.
                     Note: As an exception to the above rule, it is not necessary to serialize video orientation changes
                     on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.

                     Use the status bar orientation as the initial video orientation. Subsequent orientation changes are
                     handled by CameraViewController.viewWillTransition(to:with:).
                     */
                    let statusBarOrientation = UIApplication.shared.statusBarOrientation
                    var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                    if statusBarOrientation != .unknown {
                        if let videoOrientation = statusBarOrientation.videoOrientation {
                            initialVideoOrientation = videoOrientation
                        }
                    }

                    self.videoPreviewLayer.connection?.videoOrientation = initialVideoOrientation
                }
            } else {
                print("Could not add video device input to the session")
                setupResult = .configurationFailed
                return
            }
        } catch {
            print("Could not create video device input: \(error)")
            setupResult = .configurationFailed
            return
        }

        // Add audio input.
        do {
            let audioDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice!)

            if session.canAddInput(audioDeviceInput) {
                session.addInput(audioDeviceInput)
            } else {
                print("Could not add audio device input to the session")
            }
        } catch {
            print("Could not create audio device input: \(error)")
        }
        
        // Add photo output.
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
            //livePhotoMode = photoOutput.isLivePhotoCaptureSupported ? .on : .off
        } else {
            print("Could not add photo output to the session")
            setupResult = .configurationFailed
            return
        }

        // Add meta output.
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.metadataObjectTypes = [AVMetadataObjectTypeFace] //more types like: AVMetadataObjectTypeQRCode
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        } else {
            print("Could not add meta output to the session")
            setupResult = .configurationFailed
            return
        }

        // Add video frames output.
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: Int(CInt(kCVPixelFormatType_32BGRA))]
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)

            let videoDataOutputConnection = videoDataOutput.connection(withMediaType: AVMediaTypeVideo)
            videoDataOutputConnection?.videoOrientation = .portrait
        }

        // Video dimensions
        let videoDimensions = CMVideoFormatDescriptionGetDimensions(deviceInput.device.activeFormat.formatDescription)
        print(videoDimensions) //should be same as sessionPreset ie: AVCaptureSessionPreset640x480 then CMVideoDimensions is 640x480.
    }

    private func setupGestures() {
        let doubleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleGestureCameraDoubleTap))
        doubleTapGestureRecognizer.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTapGestureRecognizer)
    }

    private func setupUI() {
        showcaseImageView.contentMode = .scaleAspectFit
        showcaseImageView.backgroundColor = .white
        showcaseImageView.clipsToBounds = true
        showcaseImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(showcaseImageView)
        NSLayoutConstraint.activate([
            showcaseImageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            showcaseImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            showcaseImageView.heightAnchor.constraint(equalToConstant: 100),
            showcaseImageView.widthAnchor.constraint(equalToConstant: 100),
        ])

        showcaseFrame.borderColor = UIColor.red.cgColor
        showcaseFrame.borderWidth = 1.0
        //layer.addSublayer(showcaseFrame)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        //showcaseFrame.frame = CGRect(x: 0, y: 83, width: 375, height: 501)
        showcaseFrame.frame = CGRect(x: 75, y: 284, width: 300, height: 300)
    }

    private func setupObservers() {

    }

    private func removeObservers() {

    }

    // MARK: - Setup

    public func requestAccess() {
        /*
         Check video authorization status. Video access is required and audio
         access is optional. If audio access is denied, audio is not recorded
         during movie recording.
         */
        switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
        case .authorized:
            // The user has previously granted access to the camera.
            break
        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant
             video access. We suspend the session queue to delay session
             setup until the access request has completed.

             Note that audio access will be implicitly requested when we
             create an AVCaptureDeviceInput for audio during session setup.
             */
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { [unowned self] granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })

        default:
            // The user has previously denied access.
            setupResult = .notAuthorized
        }

        /*
         Setup the capture session.
         In general it is not safe to mutate an AVCaptureSession or any of its
         inputs, outputs, or connections from multiple threads at the same time.

         Why not do all of this on the main queue?
         Because AVCaptureSession.startRunning() is a blocking call which can
         take a long time. We dispatch session setup to the sessionQueue so
         that the main queue isn't blocked, which keeps the UI responsive.
         */
        sessionQueue.async { [unowned self] in
            self.setupSession()
        }
    }

    public func start() {
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                // Only setup observers and start the session running if setup succeeded.
                self.setupObservers()
                self.session.startRunning()
            case .notAuthorized:
                DispatchQueue.main.async {
                    print("Doesn't have permission to use the camera, please change privacy settings")
                }
            case .configurationFailed:
                DispatchQueue.main.async {
                    print("Unable to capture media")
                }
            }
        }
    }

    public func stop() {
        sessionQueue.async { [unowned self] in
            if self.setupResult == .success {
                self.session.stopRunning()
                self.removeObservers()
            }
        }
    }

    // MARK: Actions

    func handleGestureCameraDoubleTap(gesture: UITapGestureRecognizer) {

    }

}

extension WSAugmentedCameraView: AVCaptureMetadataOutputObjectsDelegate {

    public func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        lastFace = nil
        for metadataObject in metadataObjects as! [AVMetadataObject] {
            if metadataObject.type == AVMetadataObjectTypeFace, let metadataFaceObject = metadataObject as? AVMetadataFaceObject {
                let transformedMetadataObject = videoPreviewLayer.transformedMetadataObject(for: metadataFaceObject)
                lastFace = transformedMetadataObject?.bounds
            }
        }
    }

}

extension WSAugmentedCameraView: AVCaptureVideoDataOutputSampleBufferDelegate {

    public func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        // Preview layer/Full screen: (w:375.0, h:667.0) = iPhone 6/6S/7
        // Video output/Image buffer: (w:480.0, h:640.0) = AVCaptureSessionPreset640x480, Portrait

        // Core Video
        guard let imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // Dimensions
        let videoRect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(imageBuffer), height: CVPixelBufferGetHeight(imageBuffer))
        let previewRect = CGRect(x: 0, y: 0, width: videoPreviewLayer.frame.width, height: videoPreviewLayer.frame.height)
        // Format description of the samples in the CMSampleBuffer. i.e.: mediaType, mediaSpecific dimensions, etc.
        let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
        // A rectangle that defines the portion of the encoded pixel dimensions that represents image data valid for display. Should be same of `videoRect`.
        let cleanAperture = CMVideoFormatDescriptionGetCleanAperture(formatDescription!, false)

        // Core Image
        var image = CIImage(cvPixelBuffer: imageBuffer) //CIImage: a representation of an image to be processed or produced by Core Image filters. CIImage object has image data associated with it, it is not an image.

        if videoPreviewLayer.contentsAreFlipped() {
            // Flip horizontally
            image = image.applying(CGAffineTransform(scaleX: -1, y: 1))
        }

        // Transform video output dimension matching the preview layer
        image = image.applying(transformMakeKeepAspectRatio(from: videoRect, to: previewRect))

        // Filter effect
        let comicEffect = CIFilter(name: "CIComicEffect")!
        comicEffect.setValue(image, forKey: kCIInputImageKey)

        // Core Graphics
        guard let graphicImage = context.createCGImage(comicEffect.value(forKey: kCIOutputImageKey) as! CIImage, from: image.extent) else {
            return
        }

        var renderedFaceImage: UIImage? = nil
        if let face = lastFace, let faceImage = graphicImage.cropping(to: face) {
            renderedFaceImage = UIImage(cgImage: faceImage)
        }

        DispatchQueue.main.async {
            self.showcaseImageView.image = renderedFaceImage
        }

        return;

        // Face Detection
        let faceOptions: [String: Any] = [CIDetectorAccuracy: CIDetectorAccuracyHigh, CIDetectorImageOrientation: 6 /*Portrait*/]
        let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: faceOptions)
        // Face detections
        if let features = faceDetector?.features(in: image) {
            for faceFeature in features.flatMap({ $0 as? CIFaceFeature }) {
                if faceFeature.hasLeftEyePosition {
                    let isMirrored = videoPreviewLayer.contentsAreFlipped()
                    let previewBox = videoPreviewLayer.frame
                    let eyeFrame = transformFaceFeaturePosition(
                        faceFeature: faceFeature,
                        position: faceFeature.leftEyePosition,
                        videoRect: cleanAperture,
                        previewRect: previewBox,
                        isMirrored: isMirrored
                    )
                    showcaseLeftEyeLayer.frame = eyeFrame
                }
                if faceFeature.hasRightEyePosition {
                    let isMirrored = videoPreviewLayer.contentsAreFlipped()
                    let previewBox = videoPreviewLayer.frame
                    let eyeFrame = transformFaceFeaturePosition(
                        faceFeature: faceFeature,
                        position: faceFeature.rightEyePosition,
                        videoRect: cleanAperture,
                        previewRect: previewBox,
                        isMirrored: isMirrored
                    )
                    showcaseRightEyeLayer.frame = eyeFrame
                }
            }
        }

        return;

        let textOptions: [String: Any] = [CIDetectorAccuracy: CIDetectorAccuracyHigh, CIDetectorAspectRatio: 1.0]
        let textDetector = CIDetector(ofType: CIDetectorTypeText, context: nil, options: textOptions)
        // Text detections
        if let features = textDetector?.features(in: image) {
            for textFeature in features.flatMap({ $0 as? CITextFeature }) {
                print("We have text", textFeature.bounds)
                let textImage = image.applyingFilter(
                    "CIPerspectiveCorrection",
                    withInputParameters: [
                        "inputTopLeft": CIVector(cgPoint: textFeature.topLeft),
                        "inputTopRight": CIVector(cgPoint: textFeature.topRight),
                        "inputBottomLeft": CIVector(cgPoint: textFeature.bottomLeft),
                        "inputBottomRight": CIVector(cgPoint: textFeature.bottomRight),
                    ]
                )
                print(textImage)
            }
        }
    }

    func transformMake(from rectSource: CGRect, to rectTarget: CGRect) -> CGAffineTransform {
        let sx = rectTarget.size.width/rectSource.size.width
        let sy = rectTarget.size.height/rectSource.size.height

        // We need to fix the scale ratio, i.e.: from (w:540 h:960) -> to (w:375, h:667), the result will be (w:376, h:668)
        //So we will substract the `fixScale` value to `sx` and `sy` and the result should be (w:375, h:667).
        let fixScale: CGFloat = 0.001
        let scaleTransform = CGAffineTransform(scaleX: sx - fixScale /*remove one pixel ahead*/, y: sy - fixScale /*remove one pixel ahead*/)

        let heightDiff = rectSource.size.height - rectTarget.size.height
        let widthDiff = rectSource.size.width - rectTarget.size.width

        let dx = rectTarget.origin.x - widthDiff/2 - rectSource.origin.x
        let dy = rectTarget.origin.y - heightDiff/2 - rectSource.origin.y

        let translationTransfrom = CGAffineTransform(translationX: dx, y: dy)
        return scaleTransform.concatenating(translationTransfrom)
    }

    func transformMakeKeepAspectRatio(from rectSource: CGRect, to rectTarget: CGRect) -> CGAffineTransform {
        let aspectRatio = rectSource.size.width/rectSource.size.height

        var finalRectTarget: CGRect
        if aspectRatio > rectTarget.size.width/rectTarget.size.height {
            finalRectTarget = rectTarget.insetBy(dx: 0, dy: (rectTarget.size.height - rectTarget.size.width / aspectRatio) / 2)
        }
        else {
            finalRectTarget = rectTarget.insetBy(dx: (rectTarget.size.width - rectTarget.size.height * aspectRatio) / 2, dy: 0)
        }

        return transformMake(from: rectSource, to: finalRectTarget)
    }

    private func transformFaceFeaturePosition(faceFeature: CIFaceFeature, position: CGPoint, videoRect: CGRect, previewRect: CGRect, isMirrored: Bool) -> CGRect {
        // CoreImage coordinate system origin is at the bottom left corner
        // and UIKit is at the top left corner. So we need to translate
        // features positions before drawing them to screen. In order to do
        // so we make an affine transform
        var transform = CGAffineTransform(scaleX: 1, y: -1)
        transform = transform.translatedBy(x: 0, y: -previewRect.height)

        // Get the left eye position: Convert CoreImage to UIKit coordinates
        let convertedPosition = position.applying(transform)

        // If you want to add this to the the preview layer instead of the video we need to translate its
        // coordinates a bit more {-x, -y} in other words: {-faceFeature.bounds.origin.x, -faceFeature.bounds.origin.y}
        let faceWidth = faceFeature.bounds.size.width

        // Create an UIView to represent the left eye, its size depend on the width of the face.
        var featureRect = CGRect(
            x: convertedPosition.x,
            y: convertedPosition.y,
            width: 20,
            height: 20
        )
        featureRect = featureRect.offsetBy(dx: previewRect.origin.x, dy: previewRect.origin.y)

        return featureRect;

        let widthScale = previewRect.size.width / videoRect.size.height
        let heightScale = previewRect.size.height / videoRect.size.width

        let featureTransform = isMirrored ? CGAffineTransform(a: 0, b: heightScale, c: -widthScale, d: 0, tx: previewRect.size.width, ty: 0) : CGAffineTransform(a: 0, b: heightScale, c: widthScale, d: 0, tx: 0, ty: 0)

        featureRect = featureRect.applying(featureTransform)
        featureRect = featureRect.offsetBy(dx: previewRect.origin.x, dy: previewRect.origin.y)
        
        return featureRect
    }

}

extension UIDeviceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        default: return nil
        }
    }
}

extension UIInterfaceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return nil
        }
    }
}
