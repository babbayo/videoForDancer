//
//  ViewController.swift
//  videoForDancer
//
//  Created by USER on 2020/01/08.
//  Copyright © 2020 erin. All rights reserved.
//

import UIKit
import Photos
import Foundation
import AVFoundation

class ViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate, ABVideoRangeSliderDelegate {
    
    let imageManager = PHCachingImageManager()
    let player = AVPlayer()
    
    private var speedRate: Float = 1.0
    private var delaySeconds: Int = 0
    
    var timerForHide: Timer?
    
    var alertAudioPlayer: AVAudioPlayer? = {
        guard let delaySoundEffectURL =
            Bundle.main.url(forResource: "timerSoundEffect", withExtension: "mp3") else {
                print("no sound")
                return nil
        }
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: delaySoundEffectURL)
            audioPlayer.prepareToPlay()
            return audioPlayer
        } catch let error {
            print("no AVAudioPlayer")
            return nil
        }
    }()
    
    let timeRemainingFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        return formatter
    }()
    
    lazy var imagePicker: UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.mediaTypes = ["public.movie"]
        if #available(iOS 11.0, *) {
            picker.videoExportPreset = AVAssetExportPresetPassthrough
        }
//        picker.videoQuality = .typeHigh
        return picker
    }()
    
    lazy var pauseButtonImage = UIImage(named: "pause")
    lazy var playButtonImage = UIImage(named: "play")
    lazy var timerButtonImage = UIImage(named: "clock")
    
    /**
     A token obtained from the player's
     `addPeriodicTimeObserverForInterval(_:queue:usingBlock:)` method.
     */
    private var timeObserverToken: Any?
    
    /**
     The `NSKeyValueObservation` for the KVO on `\AVPlayer.currentItem?.status`.
     */
    private var playerItemStatusObserver: NSKeyValueObservation?
    
    /**
     The `NSKeyValueObservation` for the KVO on `\AVPlayer.timeControlStatus`.
     */
    private var playerTimeControlStatusObserver: NSKeyValueObservation?
    
    // MARK: - IBOutlet properties
    @IBOutlet weak var playerView: PlayerView!
//    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var startTimeLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var speedRateButton: UIButton!
    @IBOutlet weak var delayButton: UIButton!
    @IBOutlet weak var mirrorModeButton: UIButton!
    @IBOutlet weak var photoAccessButton: UIButton!
    @IBOutlet weak var videoRangeSlider: ABVideoRangeSlider!

    
    // MARK: - View Controller
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let movieURL =
            Bundle.main.url(forResource: "video", withExtension: "m4v") else {
                print("no video")
                return
        }
        // Create an asset instance to represent the media file.
        let asset = AVURLAsset(url: movieURL, options: nil)
        
        loadPropertyValues(forAsset: asset)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleControls))
        view.addGestureRecognizer(tapGesture)
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        }
        catch {
            print("Setting category to AVAudioSessionCategoryPlayback failed.")
        }
    }
    
    @objc func toggleControls() {
//        timeSlider.isHidden = !timeSlider.isHidden
        startTimeLabel.isHidden = !startTimeLabel.isHidden
        durationLabel.isHidden = !durationLabel.isHidden
        playPauseButton.isHidden = !playPauseButton.isHidden
        speedRateButton.isHidden = !speedRateButton.isHidden
        delayButton.isHidden = !delayButton.isHidden
        mirrorModeButton.isHidden = !mirrorModeButton.isHidden
        photoAccessButton.isHidden = !photoAccessButton.isHidden
        resetTimer()
    }
    
    @objc func hideControls() {
//        timeSlider.isHidden = true
        startTimeLabel.isHidden = true
        durationLabel.isHidden = true
        playPauseButton.isHidden = true
        speedRateButton.isHidden = true
        delayButton.isHidden = true
        mirrorModeButton.isHidden = true
        photoAccessButton.isHidden = true
    }
    
    func resetTimer() {
        timerForHide?.invalidate()
        timerForHide = Timer.scheduledTimer(timeInterval: 10.0, target: self, selector: #selector(hideControls), userInfo: nil, repeats: false)
    }
    
    // MARK: imagePickerController handling
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let url = info[.mediaURL] as? URL {
            let asset = AVURLAsset(url:url, options: nil)
            loadPropertyValues(forAsset: asset)
        } else {
            print("temp")
        }
        
        picker.dismiss(animated: true, completion: nil)
    }
    
    
    // MARK: - Asset Property Handling
    
    func playVideo(asset:PHAsset) {
        guard (asset.mediaType == .video) else {
            print("Not a valid video media type")
            return
        }
        imageManager.requestAVAsset(forVideo: asset, options: nil, resultHandler: {(asset: AVAsset?, audioMix: AVAudioMix?, info: [AnyHashable : Any]?) in
            guard let newAsset = asset as? AVURLAsset else {
                print("is not avurl asset")
                return
            }
            self.loadPropertyValues(forAsset: newAsset)
        })
    }
    
    func loadPropertyValues(forAsset newAsset: AVURLAsset) {
        videoRangeSlider.setAsset(asset: newAsset)
        videoRangeSlider.delegate = self
        
        print("load: "+newAsset.url.path)
        let assetKeysRequiredToPlay = [
            "playable",
            "hasProtectedContent"
        ]
        
        newAsset.loadValuesAsynchronously(forKeys: assetKeysRequiredToPlay) {
            
            DispatchQueue.main.async {
                if self.validateValues(forKeys: assetKeysRequiredToPlay, forAsset: newAsset) {
                    self.setupPlayerObservers()
                    self.playerView.player = self.player
                    self.player.replaceCurrentItem(with: AVPlayerItem(asset: newAsset))
                }
            }
        }
    }
    
    func validateValues(forKeys keys: [String], forAsset newAsset: AVAsset) -> Bool {
        for key in keys {
            var error: NSError?
            if newAsset.statusOfValue(forKey: key, error: &error) == .failed {
                let stringFormat = NSLocalizedString("The media failed to load the key \"%@\"",
                                                     comment: "You can't use this AVAsset because one of it's keys failed to load.")
                
                let message = String.localizedStringWithFormat(stringFormat, key)
                self.handleErrorWithMessage(message, error: error)
                
                return false
            }
        }
        
        if !newAsset.isPlayable || newAsset.hasProtectedContent {
            let message = NSLocalizedString("The media isn't playable or it contains protected content.",
                                            comment: "You can't use this AVAsset because it isn't playable or it contains protected content.")
            self.handleErrorWithMessage(message)
            return false
        }
        
        return true
    }
    
    // MARK: - ABVideoRangeSlider handling
    func didChangeValue(videoRangeSlider: ABVideoRangeSlider, startTime: Float64, endTime: Float64) {
//        print("didChangeValue : \(startTime) - \(endTime)")
    }
    
    func indicatorDidChangePosition(videoRangeSlider: ABVideoRangeSlider, position: Float64) {
        let current = player.currentTime()
        let newTime = CMTime(seconds: Double(position), preferredTimescale: 600)
        if current != newTime {
            print("position of indicator: \(position)|\(current)|\(newTime)")
            player.seek(to: newTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
        }
    }
    
    // MARK: - Key-Value Observing
    
    /**
     Setup some key-value observers on the various player and player item
     properties required by the app such as the ability to play fast forward,
     reverse, and so on.
     
     The observers adjust the state of the sample's user interface elements
     based on the values of the observed properties.
     */
    /// - Tag: PeriodicTimeObserver
    func setupPlayerObservers() {
        /*
         Create an observer to toggle the play/pause button control icon to
         reflect the playback state of the player's `timeControStatus` property.
         */
        self.playerTimeControlStatusObserver =
            self.player.observe(\AVPlayer.timeControlStatus, options: [.initial, .new]) { [unowned self]
                (player, change) in
                self.setPlayPauseButtonImage()
        }
     
        /*
         Create a periodic observer to update the movie player time slider
         during playback.
         */
        let interval = CMTime(value: 1, timescale: 2)
        self.timeObserverToken =
            self.player.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) { [unowned self] time in
                
                let timeElapsed = Float64(time.seconds)
                let start = self.videoRangeSlider.getStartPosition()
                let end = self.videoRangeSlider.getEndPosition()
                if end < timeElapsed {
//                    print("time chekcer : \(start) < \(timeElapsed) < \(end) ")
                    let newTime = CMTime(seconds: Double(start), preferredTimescale: 600)
                    self.player.seek(to: newTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
                    return
                }
                
//                self.timeSlider.value = Float(timeElapsed)
                self.videoRangeSlider.setProgressPosition(seconds: Float(timeElapsed))
                self.startTimeLabel.text = self.createTimeString(time: Float(timeElapsed))
        }
        
        playerItemStatusObserver =
            player.observe(\AVPlayer.currentItem?.status, options: [.new, .initial]) { [unowned self] (player, change) in
                DispatchQueue.main.async {
                    /*
                     Configure the user interface elements for playback when the
                     player item's `status` changes to `readyToPlay`.
                     */
                    self.updateUIforPlayerItemStatus()
                }
        }
    }
    
    // MARK: - IBActions
    @IBAction func tapModal(_ sender: UIButton) {
        self.present(imagePicker, animated: true, completion: nil)
    }
    
    @IBAction func togglePlay(_ sender: UIButton) {
        switch player.timeControlStatus {
        case .playing:
            // If the player is currently playing, pause it.
            player.pause()
        case .paused:
            /*
             If the player item already played to its end time, seek back to
             the beginning.
             */
            if player.currentItem?.currentTime() == player.currentItem?.duration {
                player.currentItem?.seek(to: CMTime.zero, completionHandler: nil)
            }
            // The player is currently paused. Begin playback.
            if delaySeconds > 0 {
                nextDelay(delaySeconds)
            } else {
                player.play()
            }
        default:
            player.pause()
        }
    }
    
    func nextDelay(_ remainSeconds: Int) {
        let alert = UIAlertController(title: "\(remainSeconds)", message: "", preferredStyle: .alert)

        self.alertAudioPlayer?.play()
        self.present(alert, animated: true, completion: nil)

        // change to desired number of seconds
        let now = DispatchTime.now()
        DispatchQueue.main.asyncAfter(deadline: now + 0.7) {
            alert.dismiss(animated: true, completion: {() in
                let nextRemainSecond = remainSeconds - 1
                if nextRemainSecond <= 0 {
                    self.player.play()
                } else {
                    self.nextDelay(nextRemainSecond)
                }
            })
        }
    }
    
    @objc func togglePlay() {
        player.play()
    }
    
    @IBAction func toggleSpeedRate(_ sender: UIButton) {
        print("toogleSpeedRate: \(self.player.rate)")
        speedRate = speedRate == 1.0 ? 1.3 : (speedRate > 1.0 ? 0.7 : 1.0)
        if self.player.timeControlStatus == .playing {
            self.player.rate = speedRate
        }
        
        let title = "\(speedRate)x"
        self.speedRateButton.setTitle(title, for: .normal)
    }
    
    @IBAction func toggleDelay(_ sender: UIButton) {
        print("toogleSpeedRate: \(self.player.rate)")
        delaySeconds = delaySeconds == 0 ? 3 : (delaySeconds == 3 ? 5 : 0)
        let delayText = delaySeconds == 0 ? "" : "\(delaySeconds)";
         self.delayButton.setTitle(delayText, for: .normal)
    }
    
    /// - Tag: TimeSliderDidChange
    @IBAction func timeSliderDidChange(_ sender: UISlider) {
        print("timeSliderDidChange")
        let newTime = CMTime(seconds: Double(sender.value), preferredTimescale: 600)
        player.seek(to: newTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
    }
    
    @IBAction func flipHorizontallyBarButtonItemTouched(_ sender: UIBarButtonItem) {
        UIView.animate(withDuration: 0.2) { [unowned self] in
            self.playerView.transform = self.playerView.transform.concatenating(CGAffineTransform(scaleX: -1, y: 1))
        }
    }
    // MARK: - Error Handling
    func handleErrorWithMessage(_ message: String, error: Error? = nil) {
        if let err = error {
            print("Error occurred with message: \(message), error: \(err).")
        }
        let alertTitle = NSLocalizedString("Error", comment: "Alert title for errors")
        
        let alert = UIAlertController(title: alertTitle, message: message,
                                      preferredStyle: UIAlertController.Style.alert)
        let alertActionTitle = NSLocalizedString("OK", comment: "OK on error alert")
        let alertAction = UIAlertAction(title: alertActionTitle, style: .default, handler: nil)
        alert.addAction(alertAction)
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: - Utilities
    
    func createTimeString(time: Float) -> String {
        let components = NSDateComponents()
        components.second = Int(max(0.0, time))
        
        return timeRemainingFormatter.string(from: components as DateComponents)!
    }
    
    /// Adjust the play/pause button image to reflect the current play state.
    func setPlayPauseButtonImage() {
        DispatchQueue.main.async {
            var buttonImage: UIImage?
            
            switch self.player.timeControlStatus {
            case .playing:
                if self.player.rate != self.speedRate {
                    self.player.rate = self.speedRate;
                }
                buttonImage = self.pauseButtonImage
            case .paused, .waitingToPlayAtSpecifiedRate:
                buttonImage = self.playButtonImage
            @unknown default:
                buttonImage = self.pauseButtonImage
                return
            }
            guard let image = buttonImage else { return }
            self.playPauseButton.setImage(image, for: UIControl.State())
        }
    }
    
    func updateUIforPlayerItemStatus() {
        guard let currentItem = self.player.currentItem else {
            return
        }
        switch currentItem.status {
        case .failed:
            /*
             Display an error if the player item status property equals
             `.failed`.
             */
            self.playPauseButton.isEnabled = false
            self.startTimeLabel.isEnabled = false
            self.durationLabel.isEnabled = false
            self.handleErrorWithMessage(currentItem.error!.localizedDescription, error: currentItem.error)
            
        case .readyToPlay:
            /*
             The player item status equals `readyToPlay`. Enable the play/pause
             button.
             */
            self.playPauseButton.isEnabled = true
            
            /*
             Update the time slider control, start time and duration labels for
             the player duration.
             */
            let newDurationSeconds = currentItem.duration.seconds
            
            let curTime = Float(CMTimeGetSeconds(self.player.currentTime()))
            self.startTimeLabel.isEnabled = true
            self.startTimeLabel.text = self.createTimeString(time: curTime)
            self.durationLabel.isEnabled = true
            self.durationLabel.text = self.createTimeString(time: Float(newDurationSeconds))
            
        default:
            self.playPauseButton.isEnabled = false
            self.startTimeLabel.isEnabled = false
            self.durationLabel.isEnabled = false
        }
    }
}

