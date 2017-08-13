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

    let collectionFlowLayout = UICollectionViewFlowLayout()
    fileprivate lazy var collectionView: UICollectionView = { [unowned self] in
        return UICollectionView(frame: .zero, collectionViewLayout: self.collectionFlowLayout)
    }()

    fileprivate lazy var glasses: [UIImage] = {
        var list = [UIImage]()
        var i = 1
        while let image = UIImage(named: "glasses-\(i)") {
            list.append(image)
            i += 1
        }
        return list
    }()
    
    fileprivate var currentGlasses: Int = 0 {
        didSet {
            if currentGlasses < 0 {
                currentGlasses = glasses.count - 1
            }
            if currentGlasses >= glasses.count {
                currentGlasses = 0
            }
        }
    }

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
        cameraView.debugMode = false

        cameraView.delegate = self
        cameraView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cameraView)
        NSLayoutConstraint.activate([
            cameraView.topAnchor.constraint(equalTo: view.topAnchor),
            cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        collectionFlowLayout.scrollDirection = .horizontal

        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceHorizontal = true
        collectionView.register(GlassesCollectionViewCell.self, forCellWithReuseIdentifier: String(describing: GlassesCollectionViewCell.self))
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.heightAnchor.constraint(equalToConstant: 65),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
        ])
    }

}

extension CameraViewController: UICollectionViewDelegate {



}

extension CameraViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return glasses.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: GlassesCollectionViewCell.self), for: indexPath)
        guard let glassesCell = cell as? GlassesCollectionViewCell else {
            return cell
        }
        glassesCell.imageView.image = glasses[indexPath.row]
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        currentGlasses = indexPath.row
    }

}

extension CameraViewController: WSAugmentedCameraViewDelegate {

    func augmentedCameraView(_ augmentedCameraView: WSAugmentedCameraView, imageForEyesRect: CGRect) -> CGImage? {
        return glasses[currentGlasses].cgImage
    }

    func augmentedCameraView(_ augmentedCameraView: WSAugmentedCameraView, didDetectFaceFeature faceFeature: CIFaceFeature) {

    }

}

class GlassesCollectionViewCell: UICollectionViewCell {

    let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.layer.cornerRadius = contentView.bounds.size.width/2
    }

    func setupUI() {
        contentView.backgroundColor = .clear

        imageView.image = #imageLiteral(resourceName: "glasses-7")

        imageView.backgroundColor = .white
        imageView.layer.shadowColor = UIColor.black.cgColor
        imageView.layer.shadowOpacity = 0.5
        imageView.layer.shadowRadius = 3
        imageView.layer.shadowOffset = CGSize(width: 1, height: 3)
        imageView.layer.borderColor = UIColor.black.cgColor
        imageView.layer.borderWidth = 0.5
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

}
