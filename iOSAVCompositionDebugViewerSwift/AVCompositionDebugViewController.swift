import UIKit
import AVFoundation
import Foundation


class AVCompositionDebugViewController: UIViewController {

  // ============================================
  // MARK: -  Properties
  
  var playing = false
  var scrubInFlight = false
  var seekToZeroBeforePlayer = false
  var lastScrubSliderValue = 0
  var playRateToRestor = 0
  
  //  let timeObserver
  var transitionDuration = 2.0
  var transitionsEnabled = true
  
  let editor = SimpleEditor()
  let clips = []
  let clipTimeRanges = []
  
  let player = AVPlayer()
  let playerItem: AVPlayerItem? = nil
  
  var playerViewControllerKVOContext = 0
  
  // A token obtained from calling `player`'s `addPeriodicTimeObserverForInterval(_:queue:usingBlock:)` method.
 var timeObserverToken: AnyObject?
  
  // ============================================
  // MARK: -  Outlets
  
  @IBOutlet weak var playerView: APLPlayerView!
  @IBOutlet weak var compositionDebugView: AVCompositionDebugView!
  
  @IBOutlet weak var scrubber: UISlider!
  @IBOutlet weak var playPauseButton: UIButton!
  @IBOutlet weak var currentTimeLabel: UILabel!
  
  
  // ============================================
  // MARK: -  ViewController LifeCycle
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()

    updateScubber()
    updateTimeLabel()
  }
  
  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
    
    seekToZeroBeforePlayer = false
    player.addObserver(self, forKeyPath: "rate", options: [.Old, .New], context: &playerViewControllerKVOContext)
    playerView.player = player
    
    // TODO: Fill in the rest of this
  }
  
  override func viewWillDisappear(animated: Bool) {
    super.viewWillDisappear(animated)
    
    // TODO: Fill in the rest of this
  }
  
  // ============================================
  // MARK: -  Simple Editor
  
  func setupEditingAndPlayback(){
    
  }
  
  func loadAsset(){
    
  }

  func synchronizePlayerWithEditor() {
  
  }
  
  func synchronizeWithEditor(){
    
  }
  
  func synchronizeEditorClipsWithOurClips(){
  
  }
  
  func synchronizeEditorClipTimeRangesWithOurClipTimeRanges(){
    
  }

  // ============================================
  // MARK: -  Utilities
  
  func addTimeObserverToPlayer() {
    guard timeObserverToken == nil else { return }
    guard player.currentItem?.status == .ReadyToPlay else { return }
    
    let duration = CMTimeGetSeconds(playerItemDuration())
    
    if isfinite(duration) {
      let width = CGRectGetWidth(self.scrubber.bounds)
      // Make sure we don't have a strong reference cycle by only capturing self as weak.
      var interval = Int64(0.5 * duration / Double(width))
      if interval > 1 { interval = 1 }
      timeObserverToken = player.addPeriodicTimeObserverForInterval(CMTimeMake(interval, Int32(NSEC_PER_SEC)), queue: dispatch_get_main_queue()) {
        [weak self] time in
        self?.updateScubber()
        self?.updateTimeLabel()
      }
    }
    
  }
  
  func removeTimeObserverFromPlayer() {
    if let timeObserverToken = timeObserverToken {
      player.removeTimeObserver(timeObserverToken)
    }
    timeObserverToken = nil
  }
  
  func playerItemDuration() -> CMTime {
    guard let playerItem = player.currentItem else {
      return kCMTimeInvalid
    }

    return playerItem.status == .ReadyToPlay ? playerItem.duration : kCMTimeInvalid
  }
  
  // MARK: - KVO Observation
  // Update our UI when player or `player.currentItem` changes.
  override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
    // Make sure the this KVO callback was intended for this view controller.
    guard context == &playerViewControllerKVOContext else {
      super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
      return
    }

    if keyPath == "rate" {
      let newRate = (change?[NSKeyValueChangeNewKey] as! NSNumber).doubleValue
      if newRate == 1 {
        updatePlayePauseButton()
        updateScubber()
        updateTimeLabel()
      }
    }
    else if keyPath == "currentItem.status" {
      /* Once the AVPlayerItem becomes ready to play, i.e.
      [playerItem status] == AVPlayerItemStatusReadyToPlay,
      its duration can be fetched from the item. */
      let newStatus: AVPlayerItemStatus
      if let newStatusAsNumber = change?[NSKeyValueChangeNewKey] as? NSNumber {
        newStatus = AVPlayerItemStatus(rawValue: newStatusAsNumber.integerValue)!
        addTimeObserverToPlayer()
      } else {
        newStatus = .Unknown
      }
      
      if newStatus == .Failed {
        handleErrorWithMessage(player.currentItem?.error?.localizedDescription, error:player.currentItem?.error)
      }
    }
  }
  
  func handleErrorWithMessage(message: String?, error: NSError? = nil) {
    NSLog("Error occured with message: \(message), error: \(error).")
    
    let alertTitle = NSLocalizedString("alert.error.title", comment: "Alert title for errors")
    let defaultAlertMessage = NSLocalizedString("error.default.description", comment: "Default error message when no NSError provided")
    
    let alert = UIAlertController(title: alertTitle, message: message == nil ? defaultAlertMessage : message, preferredStyle: UIAlertControllerStyle.Alert)
    
    let alertActionTitle = NSLocalizedString("alert.error.actions.OK", comment: "OK on error alert")
    
    let alertAction = UIAlertAction(title: alertActionTitle, style: .Default, handler: nil)
    
    alert.addAction(alertAction)
    
    presentViewController(alert, animated: true, completion: nil)
  }
  
  func updatePlayePauseButton() {}
  
  func updateTimeLabel() {}

  func updateScubber() {}
  

  // ============================================
  // MARK: -  Actions
  
  @IBAction func togglePlayPause(sender: UIButton){}
  
  @IBAction func beginScrubbing(sender: UISlider){}
  
  @IBAction func scrub(sender: UISlider){}
  
  @IBAction func endScrubbing(sender: UISlider){}
  
  

}

