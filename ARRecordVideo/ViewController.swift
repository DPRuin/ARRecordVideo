//
//  ViewController.swift
//  ARRecordVideo
//
//  Created by mac126 on 2018/3/13.
//  Copyright © 2018年 mac126. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Photos


class ViewController: UIViewController, ARSCNViewDelegate, RecordARDelegate, RenderARDelegate {

    @IBOutlet var sceneView: ARSCNView!
    var recorder:RecordAR?
    let recordingQueue = DispatchQueue(label: "recordingThread", attributes: .concurrent)

    @IBOutlet weak var segmentedControl: SegmentedControl!
    @IBOutlet weak var squishBtn: SquishButton!
    @IBOutlet weak var bgView: UIImageView!
    
    @IBOutlet weak var btnAfresh: UIButton!
    
    @IBOutlet weak var btnEnsure: UIButton!
    
    // var player: DPlayer?
    
    private var nowImage: UIImage!
    private var nowVedioUrl: URL!
    private var isVedio: Bool!
    
    fileprivate var player = Player()
    private weak var bgImageView: UIImageView!
    
    deinit {
        self.player.willMove(toParentViewController: self)
        self.player.view.removeFromSuperview()
        self.player.removeFromParentViewController()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlayer()
        
        sceneView.delegate = self
        sceneView.showsStatistics = true

        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        sceneView.scene = scene
        
        sceneView.scene.rootNode.scale = SCNVector3(0.1, 0.1, 0.1)
        
        // 录制
        setUpRecordVideo()
        
        // configureNavigationBelowSegmentedControl()
        configureSegmentedControl()
    }
    
    func setupPlayer() {
        self.player.view.frame = self.view.bounds
        self.addChildViewController(self.player)
        self.view.addSubview(self.player.view)
        self.player.didMove(toParentViewController: self)
        
        self.player.playbackLoops = true
        
        let bgImageView = UIImageView(frame: self.view.bounds)
        bgImageView.isHidden = true
        self.bgImageView = bgImageView
        
        self.player.view.addSubview(bgImageView)
        
        let cancelBtn = UIButton(type: .custom)
        cancelBtn.setImage(UIImage(named: "btn_cancel"), for: UIControlState.normal)
        cancelBtn.addTarget(self, action: #selector(self.btnAfreshDidClick(_:)), for: .touchUpInside)

        let insert:CGFloat = 50.0
        let y = self.view.bounds.height - 44/2 - insert
        cancelBtn.frame = CGRect(x: insert, y: y, width: 44, height: 44)
        self.player.view.addSubview(cancelBtn)
        
        let confirmBtn = UIButton(type: .custom)
        confirmBtn.setImage(UIImage(named: "btn_confirm"), for: UIControlState.normal)
        confirmBtn.addTarget(self, action: #selector(self.btnEnsureDidClick(_:)), for: .touchUpInside)
        
        let x = self.view.bounds.width - 44/2 - insert
        confirmBtn.frame = CGRect(x: x, y: y, width: 44, height: 44)
        self.player.view.addSubview(confirmBtn)
    }
    
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
        
        
        // Prepare the recorder with sessions configuration
        recorder?.prepare(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
        
        if recorder?.status == .recording {
            recorder?.stopAndExport()
        }
        recorder?.onlyRenderWhileRecording = true
        recorder?.prepare(ARWorldTrackingConfiguration())
        
        // Switch off the orientation lock for UIViewControllers with AR Scenes
        recorder?.rest()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    // MARK: - Hide Status Bar
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // MARK: - 初始化
    func setUpRecordVideo() {
        // Initialize ARVideoKit recorder
        recorder = RecordAR(ARSceneKit: sceneView)
        
        /*----👇---- ARVideoKit Configuration ----👇----*/
        
        // Set the recorder's delegate
        recorder?.delegate = self
        
        // Set the renderer's delegate
        recorder?.renderAR = self
        
        // Configure the renderer to perform additional image & video processing 👁
        recorder?.onlyRenderWhileRecording = false
        
        // Configure ARKit content mode. Default is .auto
        recorder?.contentMode = .aspectFill
        
        // Set the UIViewController orientations
        recorder?.inputViewOrientations = [.landscapeLeft, .landscapeRight, .portrait]
        // Configure RecordAR to store media files in local app directory
        recorder?.deleteCacheWhenExported = false
    }
    
    // MARK: - SegmentedControl

    fileprivate func configureSegmentedControl() {
        let titleStrings = ["可拍照", "录视频"]
        let titles: [NSAttributedString] = {
            let attributes: [NSAttributedStringKey: Any] = [.font: UIFont.systemFont(ofSize: 15), .foregroundColor: UIColor.lightGray]
            var titles = [NSAttributedString]()
            for titleString in titleStrings {
                let title = NSAttributedString(string: titleString, attributes: attributes)
                titles.append(title)
            }
            return titles
        }()
        let selectedTitles: [NSAttributedString] = {
            let attributes: [NSAttributedStringKey: Any] = [.font: UIFont.systemFont(ofSize: 15), .foregroundColor: UIColor.white]
            var selectedTitles = [NSAttributedString]()
            for titleString in titleStrings {
                let selectedTitle = NSAttributedString(string: titleString, attributes: attributes)
                selectedTitles.append(selectedTitle)
            }
            return selectedTitles
        }()
        segmentedControl.setTitles(titles, selectedTitles: selectedTitles)
        segmentedControl.delegate = self
        segmentedControl.selectionBoxStyle = .none
        segmentedControl.minimumSegmentWidth = 375.0 / 4.0
        segmentedControl.selectionBoxColor = UIColor.clear
        segmentedControl.selectionIndicatorStyle = .none

        // segmentedControl.selectionIndicatorColor = UIColor(white: 0.3, alpha: 1)
    }
    
    // MARK: - Exported UIAlert present method
    func exportMessage(success: Bool, status:PHAuthorizationStatus) {
        if success {
            let alert = UIAlertController(title: "导出", message: "导出相册成功", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "ok", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }else if status == .denied || status == .restricted || status == .notDetermined {
            let errorView = UIAlertController(title: "😅", message: "相册权限", preferredStyle: .alert)
            let settingsBtn = UIAlertAction(title: "OpenSettings", style: .cancel) { (_) -> Void in
                guard let settingsUrl = URL(string: UIApplicationOpenSettingsURLString) else {
                    return
                }
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    if #available(iOS 10.0, *) {
                        UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                        })
                    } else {
                        UIApplication.shared.openURL(URL(string:UIApplicationOpenSettingsURLString)!)
                    }
                }
            }
            errorView.addAction(UIAlertAction(title: "Later", style: UIAlertActionStyle.default, handler: {
                (UIAlertAction)in
            }))
            errorView.addAction(settingsBtn)
            self.present(errorView, animated: true, completion: nil)
        }else{
            let alert = UIAlertController(title: "Exporting Failed", message: "There was an error while exporting your media file.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }

    // MARK: - 按钮点击
    @IBAction func recordVideo(_ sender: SquishButton) {

        if sender.type == ButtonType.camera {
            isVedio = false
            
            nowImage = self.recorder?.photo()
            self.player.url = Bundle.main.url(forResource: "a", withExtension: "mp4")
            self.player.playFromBeginning()
            self.player.pause()
            bgImageView.isHidden = false
            bgImageView.image = nowImage
            
        } else if sender.type == ButtonType.video {
            isVedio = true
            //Record
            if recorder?.status == .readyToRecord {
                sender.setTitle("停止", for: .normal)
                
                recordingQueue.async {
                    self.recorder?.record()
                }
            }else if recorder?.status == .recording {
                sender.setTitle("录制", for: .normal)
                recorder?.stop({ (url) in
                    DispatchQueue.main.async {
                        self.bgImageView.isHidden = true
                    }
                    
                    self.nowVedioUrl = url
                    self.player.url = url
                    self.player.playFromBeginning()
                })
            }
        }

        
    }
    
    @objc func btnAfreshDidClick(_ sender: UIButton) {
        self.player.pause()
        self.player.view.isHidden = true
    }
    
    @objc func btnEnsureDidClick(_ sender: UIButton) {
        if isVedio {
            recorder?.export(video: nowVedioUrl, { (saved, status) in
                DispatchQueue.main.sync {
                    self.exportMessage(success: saved, status: status)
                }
            })
            
        } else {
            self.recorder?.export(UIImage: nowImage) { saved, status in
                if saved {
                    self.exportMessage(success: saved, status: status)
                }
            }
        }
        
        self.player.pause()
        self.player.view.isHidden = true

    }
    
    func showBtn() {
        DispatchQueue.main.sync {
            self.btnEnsure.isHidden = false
            self.btnAfresh.isHidden = false
        }
    }
    
    func hideBtn() {
        DispatchQueue.main.sync {
            self.btnEnsure.isHidden = true
            self.btnAfresh.isHidden = true
        }
    }
    
    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
//    func session(_ session: ARSession, didFailWithError error: Error) {
//        // Present an error message to the user
//
//    }
//
//    func sessionWasInterrupted(_ session: ARSession) {
//        // Inform the user that the session has been interrupted, for example, by presenting an overlay
//
//    }
//
//    func sessionInterruptionEnded(_ session: ARSession) {
//        // Reset tracking and/or remove existing anchors if consistent tracking is required
//
//    }
}

// MARK: - ARVideoKit Delegate Methods

extension ViewController {
    func frame(didRender buffer: CVPixelBuffer, with time: CMTime, using rawBuffer: CVPixelBuffer) {
        // Do some image/video processing.
    }
    
    func recorder(didEndRecording path: URL, with noError: Bool) {
        if noError {
            // Do something with the video path.
            print("---", path)
        }
    }
    
    func recorder(didFailRecording error: Error?, and status: String) {
        // Inform user an error occurred while recording.
    }
    
    func recorder(willEnterBackground status: RecordARStatus) {
        // Use this method to pause or stop video recording. Check [applicationWillResignActive(_:)](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1622950-applicationwillresignactive) for more information.
        if status == .recording {
            recorder?.stopAndExport()
        }
    }
}

// MARK: - SegmentedControlDelegate

extension ViewController: SegmentedControlDelegate {
    func segmentedControl(_ segmentedControl: SegmentedControl, didSelectIndex selectedIndex: Int) {
        print("Did select index \(selectedIndex)")
        switch segmentedControl.style {
        case .text:
            print("The title is “\(segmentedControl.titles[selectedIndex].string)”\n")
        case .image:
            print("The image is “\(segmentedControl.images[selectedIndex])”\n")
        }
        
        switch selectedIndex {
        case 0: //
            squishBtn.type = ButtonType.camera
        case 1:
            squishBtn.type = ButtonType.video
        default:
            print("hhhhh")
        }
    }
    
    func segmentedControl(_ segmentedControl: SegmentedControl, didLongPressIndex longPressIndex: Int) {
        print("Did long press index \(longPressIndex)")
        if UIDevice.current.userInterfaceIdiom == .pad {
            let viewController = UIViewController()
            viewController.modalPresentationStyle = .popover
            viewController.preferredContentSize = CGSize(width: 200, height: 300)
            if let popoverController = viewController.popoverPresentationController {
                popoverController.sourceView = view
                let yOffset: CGFloat = 10
                popoverController.sourceRect = view.convert(CGRect(origin: CGPoint(x: 70 * CGFloat(longPressIndex), y: yOffset), size: CGSize(width: 70, height: 30)), from: navigationItem.titleView)
                popoverController.permittedArrowDirections = .any
                present(viewController, animated: true, completion: nil)
            }
        } else {
            let message = segmentedControl.style == .text ? "Long press title “\(segmentedControl.titles[longPressIndex].string)”" : "Long press image “\(segmentedControl.images[longPressIndex])”"
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)
            let cancelAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
            alert.addAction(cancelAction)
            present(alert, animated: true, completion: nil)
        }
    }
}

