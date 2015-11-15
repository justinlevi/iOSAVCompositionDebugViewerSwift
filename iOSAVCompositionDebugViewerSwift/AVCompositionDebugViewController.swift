import UIKit
import AVFoundation
import Foundation
import Dispatch

enum AVCompositionError: ErrorType, CustomStringConvertible{
  case NoMediaData
  case NotComposable
  
  var description: String {
    switch self {
    case .NoMediaData: return "No Media Data"
    case .NotComposable: return "Not Composable"
    }
  }
}

class AVCompositionDebugViewController: UIViewController {
  

  // ============================================
  // MARK: -  Properties
  
  let editor = SimpleEditor()
  let player = AVPlayer()
  
  var playerItem: AVPlayerItem? = nil
  
  var playing = false
  var scrubInFlight = false
  var seekToZeroBeforePlaying = false
  var lastScrubSliderValue: Float = 0
  var playRateToRestore: Float = 0
  
  //  let timeObserver
  var transitionDuration = 2.0
  var transitionsEnabled = true
  
  var clips = [AVAsset]()
  var clipTimeRanges = [CMTimeRange]()
 
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
    
    setupEditingAndPlayback()
  }
  
  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
    
    seekToZeroBeforePlaying = false
    player.addObserver(self, forKeyPath: "rate", options: [.Old, .New], context: &playerViewControllerKVOContext)
    playerView.player = player
    
    addTimeObserverToPlayer()
    
    // Build AVComposition and AVVideoComposition objects for playback
    editor.buildCompositionObjectsForPlayback()
    synchronizePlayerWithEditor()
    
    // Set our AVPlayer and all composition objects on the AVCompositionDebugView
    compositionDebugView.player = player
    compositionDebugView.synchronizeToComposition(editor.composition, videoComposition: editor.videoComposition, audioMix: editor.audioMix)
    compositionDebugView.setNeedsDisplay()
  }
  
  override func viewWillDisappear(animated: Bool) {
    super.viewWillDisappear(animated)
    
    player.pause()
    removeTimeObserverFromPlayer()
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

        updatePlayePauseButton()
        updateScubber()
        updateTimeLabel()
      
    }
    else if keyPath == "status" {
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

  
  // ============================================
  // MARK: -  Simple Editor
  
  func setupEditingAndPlayback(){
    
    let asset1 = AVURLAsset(URL: NSURL.fileURLWithPath(NSBundle.mainBundle().pathForResource("sample_clip1", ofType: "m4v")!))
    let asset2 = AVURLAsset(URL: NSURL.fileURLWithPath(NSBundle.mainBundle().pathForResource("sample_clip2", ofType: "mov")!))
    
    let dispatchGroup = dispatch_group_create()
    let assetKeysToLoadAndTest = ["tracks", "duration", "composable"]
    
    loadAsset(asset1, withKeys: assetKeysToLoadAndTest, usingDispatchGroup: dispatchGroup)
    loadAsset(asset2, withKeys: assetKeysToLoadAndTest, usingDispatchGroup: dispatchGroup)
    
    dispatch_group_notify(dispatchGroup, dispatch_get_main_queue()){ [weak self] in
      self?.synchronizeWithEditor()
    }
  }
  
  func loadAsset(asset: AVAsset, withKeys assetKeysToLoad: [String], usingDispatchGroup dispatchGroup: dispatch_group_t){
    
    dispatch_group_enter(dispatchGroup)
    asset.loadValuesAsynchronouslyForKeys(assetKeysToLoad) {
      
      do {
        for key in assetKeysToLoad {
          var trackLoadingError: NSError?
          guard asset.statusOfValueForKey(key, error: &trackLoadingError) == .Loaded else {
            throw trackLoadingError!
          }
        }
        
        guard asset.composable else { throw AVCompositionError.NotComposable }
        
        self.clips.append(asset)
        // TODO: This code assumes that both assets are atleast 5 seconds long... this doesn't seem like a good idea...
        self.clipTimeRanges.append(CMTimeRangeMake(CMTimeMakeWithSeconds(0,1), CMTimeMakeWithSeconds(5, 1)))
      } catch {
        fatalError("\((error as? AVCompositionError)?.description)")
      }
      dispatch_group_leave(dispatchGroup)
    }
  }

  func synchronizePlayerWithEditor() {
    
    if self.playerItem != editor.playerItem() {
      if let playerItem = playerItem {
        playerItem.removeObserver(self, forKeyPath: "status")
        NSNotificationCenter.defaultCenter().removeObserver(self, name: AVPlayerItemDidPlayToEndTimeNotification, object: playerItem)
      }

      playerItem = editor.playerItem()
      
      if let playerItem = playerItem {
        // Observe the player item "status" key to determine when it is ready to play
        playerItem.addObserver(self, forKeyPath: "status", options: [.New, .Initial], context: &playerViewControllerKVOContext)
        
        // When the player item has played to its end time we'll set a flag
        // so that the next time the play method is issued the player will
        // be reset to time zero first.
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "playerItemDidReachEnd:", name: AVPlayerItemDidPlayToEndTimeNotification, object: self.playerItem)
      }
      
      player.replaceCurrentItemWithPlayerItem(playerItem)
    }
  }
  
  func synchronizeWithEditor(){
    
    // Clips
    editor.clips = clips
    synchronizeEditorClipTimeRangesWithOurClipTimeRanges()
    
    // Transitions
    if transitionsEnabled {
      editor.transitionDuration = CMTimeMakeWithSeconds(transitionDuration, 600)
    } else {
      editor.transitionDuration = kCMTimeInvalid
    }
    
    // Build AVComposition and AVVideoComposition objects for playback
    editor.buildCompositionObjectsForPlayback()
    synchronizePlayerWithEditor()
    
    // Set our AVPlayer and all composition objects on the AVCompositionDebugView
    compositionDebugView.player = player
    compositionDebugView.synchronizeToComposition(editor.composition, videoComposition:editor.videoComposition, audioMix:editor.audioMix)
    compositionDebugView.setNeedsDisplay()
  }
  
  func synchronizeEditorClipTimeRangesWithOurClipTimeRanges(){
    
    var validClipTimeRanges = [CMTimeRange]()
    for timeRange in clipTimeRanges {
      if timeRange.isValid {
        validClipTimeRanges.append(timeRange)
      }
    }
    
    editor.clipTimeRanges = validClipTimeRanges
  }

  // ============================================
  // MARK: -  Utilities
  
  func addTimeObserverToPlayer() {
    
    guard timeObserverToken == nil else { return }
    guard player.currentItem?.status == .ReadyToPlay else { return }
    
    let duration = CMTimeGetSeconds(playerItemDuration())
    
    if isfinite(duration) {
      let interval = CMTimeMake(1, 60)
      
      // Make sure we don't have a strong reference cycle by only capturing self as weak.
      timeObserverToken = player.addPeriodicTimeObserverForInterval(interval, queue: dispatch_get_main_queue()) {
        [weak self] time in
        
        if self?.player.rate == 1 {
          self?.updateScubber()
          self?.updateTimeLabel()
        }
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
  
  func updatePlayePauseButton() {
    let buttonImageName = playing ? "pause" : "play"
    let buttonImage = UIImage(named: buttonImageName)
    playPauseButton.setImage(buttonImage, forState: .Normal)
  }
  
  func updateTimeLabel() {
    
    var seconds = CMTimeGetSeconds(self.player.currentTime())
    if (!isfinite(seconds)) {
      seconds = 0
    }
    
    self.currentTimeLabel.textColor = UIColor(white: 1, alpha: 1)
    self.currentTimeLabel.textAlignment = NSTextAlignment.Center
    
    self.currentTimeLabel.text = stringFromTimeInterval(seconds)
  }
  
  func stringFromTimeInterval(interval: NSTimeInterval) -> String {
    
    let ti = NSInteger(interval)
    let seconds = ti % 60
    let minutes = (ti / 60) % 60
    let hours = (ti / 3600)
    
    if hours > 0 {
      return NSString(format: "%.2i:%.2i:%.2i", hours, minutes, seconds) as String
    }else {
      return String(format:"%.2i:%.2i", minutes, seconds)
    }
  }

  func updateScubber() {

    let duration = CMTimeGetSeconds(playerItemDuration())
    
    if (isfinite(duration)) {
      let time = CMTimeGetSeconds(player.currentTime())
      scrubber.setValue(Float(time / duration), animated: false)
    }
    else {
      scrubber.setValue(0, animated: false)
    }
  }
  

  // ============================================
  // MARK: -  Actions
  
  @IBAction func togglePlayPause(sender: UIButton){
    playing = !playing;
    if playing  {
      if seekToZeroBeforePlaying {
        player.seekToTime(kCMTimeZero)
        seekToZeroBeforePlaying = false
      }
      player.play()
    } else {
      player.pause()
    }

  }
  
  @IBAction func beginScrubbing(sender: UISlider){
    seekToZeroBeforePlaying = false
    playRateToRestore = player.rate
    player.rate = 0
    
    removeTimeObserverFromPlayer()
  }
  
  @IBAction func scrub(sender: UISlider){
    lastScrubSliderValue = scrubber.value
    
    if !scrubInFlight {
      scrubToSliderValue(lastScrubSliderValue)
    }
  }
  
  func scrubToSliderValue(sliderValue: Float) {
    let duration = CMTimeGetSeconds(playerItemDuration())
    
    if isfinite(duration) {
      let width = CGRectGetWidth(scrubber.bounds)
      
      let time = duration * Double(sliderValue)
      let tolerance = 1.0 * duration / Double(width)
      
      scrubInFlight = true
      
      player.seekToTime(CMTimeMakeWithSeconds(time, Int32(NSEC_PER_SEC)),
        toleranceBefore: CMTimeMakeWithSeconds(tolerance, Int32(NSEC_PER_SEC)),
        toleranceAfter: CMTimeMakeWithSeconds(tolerance, Int32(NSEC_PER_SEC)),
        completionHandler: { finished in
          self.scrubInFlight = false
          self.updateTimeLabel()
      })
    
    }
  }
  
  @IBAction func endScrubbing(sender: UISlider){
  
  }
  
  func playerItemDidReachEnd(notification: NSNotification) {
    seekToZeroBeforePlaying = true
  }

}

