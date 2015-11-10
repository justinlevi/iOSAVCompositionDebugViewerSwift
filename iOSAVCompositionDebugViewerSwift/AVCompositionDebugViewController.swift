//
//  AVCompositionDebugViewController.swift
//  iOSAVCompositionDebugViewerSwift
//
//  Created by Justin Winter on 11/9/15.
//  Copyright © 2015 soundslides. All rights reserved.
//

import UIKit
import AVFoundation

/*
    Player view backed by an AVPlayerLayer
*/
class APLPlayerView: UIView {
  var player = AVPlayer()
  
  override var layer: AVPlayerLayer {
    get{ return self.layer }
    set{ self.layer = newValue }
  }
  
  override func awakeFromNib() {
    super.awakeFromNib()
    
    layer.player = player
  }
}


class AVCompositionDebugViewController: UIViewController {

  // ============================================
  // MARK: -  Properties
  
  var playing = false
  var scrubInFlight = false
  var seekToZeroBeforePlayer = false
  var lastScrubSliderValue = 0
  var playRateToRestor = 0
  
  //  let timeObserver
  var transitionDuration = 0
  var transitionsEnabled = true
  
  let player: AVPlayer? = nil
  let playerItem: AVPlayerItem? = nil
  
  
  // ============================================
  // MARK: -  Outlets
  
  @IBOutlet weak var playerView: APLPlayerView!
  @IBOutlet weak var compositionDebugView: AVCompositionDebugView!
  
  @IBOutlet weak var scrubber: UISlider!
  @IBOutlet weak var playPauseButton: UIButton!
  @IBOutlet weak var currentTimeLabel: UILabel!
  
  
  // ============================================
  // MARK: -  Actions
  
  @IBAction func togglePlayPause(sender: UIButton){}
  
  @IBAction func beginScrubbing(sender: UISlider){}
  @IBAction func scrub(sender: UISlider){}
  @IBAction func endScrubbing(sender: UISlider){}
  
  
  // ============================================
  // MARK: -  ViewController LifeCycle
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()

  }


  // ============================================
  // MARK: -  Imperitives
  
  func updatePlayePauseButton() {}
  
  func updateScubber() {}
  
  func updateTimeLabel() {}
  
  func playerItemDuration() -> CMTime { return kCMTimeZero }
  
  func synchronizePlayerWithEditor() {}

}

