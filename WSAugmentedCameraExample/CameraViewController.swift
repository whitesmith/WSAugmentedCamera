//
//  CameraViewController.swift
//  WSAugmentedCameraExample
//
//  Created by Ricardo Pereira on 09/06/2017.
//  Copyright © 2017 Whitesmith. All rights reserved.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController {

    let cameraView = WSAugmentedCameraView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        cameraView.requestAccess()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraView.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        cameraView.stop()
        super.viewWillDisappear(animated)
    }

    override var shouldAutorotate: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }

    func setupUI() {
        view.addSubview(cameraView)
        cameraView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cameraView.topAnchor.constraint(equalTo: view.topAnchor),
            cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

}
