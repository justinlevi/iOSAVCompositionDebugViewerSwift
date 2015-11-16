import Foundation
import AVFoundation

// Default cross fade duration is set to 2.0 seconds
let kDefaultTransitionDuration: Double = 2.0

class SimpleEditor {
  
  var clips = [AVAsset]()
  var clipTimeRanges = [CMTimeRange]()
  var transitionDuration = CMTimeMakeWithSeconds(kDefaultTransitionDuration, 600)

  var composition = AVMutableComposition()
  var videoComposition = AVMutableVideoComposition()
  var audioMix = AVMutableAudioMix()
  
  func buildTransitionComposition(composition: AVMutableComposition, andVideoComposition: AVMutableVideoComposition, andAudioMix audioMix: AVMutableAudioMix){
    
    var nextClipStartTime = kCMTimeZero
    let clipsCount = clips.count
    
    // Make transitionDuration no greater than half the shortest clip duration.
    var transitionDuration = self.transitionDuration
    for i in 0..<clipsCount {
      if let clipTimeRange = clipTimeRanges[safe: i] {
        var halfClipDuration = clipTimeRange.duration
        halfClipDuration.timescale *= 2 // You can halve a rational by doubling its denominator.
        transitionDuration = CMTimeMinimum(transitionDuration, halfClipDuration)
      }
    }
    
    var compositionVideoTracks = [AVMutableCompositionTrack]()
    var compositionAudioTracks = [AVMutableCompositionTrack]()
    
    // Add two video tracks and two audio tracks.
    compositionVideoTracks.append(composition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid))
    compositionVideoTracks.append(composition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid))
    compositionAudioTracks.append(composition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid))
    compositionAudioTracks.append(composition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid))
    
    var passThroughTimeRanges = [CMTimeRange]()
    var transitionTimeRanges = [CMTimeRange]()
    
    // Place clips into alternating video & audio tracks in composition, overlapped by transitionDuration.
    for i in 0..<clipsCount {
      let alternatingIndex = i % 2
      guard let asset = clips[safe: i] else { break }
      
      var timeRangeInAsset = CMTimeRangeMake(kCMTimeZero, asset.duration)
      if let clipTimeRange = clipTimeRanges[safe: i] {
        timeRangeInAsset = clipTimeRange
      }
      
      guard let clipVideoTrack = asset.tracksWithMediaType(AVMediaTypeVideo).first else { fatalError("\(__LINE__) \(__FUNCTION__)") }
      try? compositionVideoTracks[alternatingIndex].insertTimeRange(timeRangeInAsset, ofTrack: clipVideoTrack, atTime: nextClipStartTime)
      
      guard let clipAudioTrack = asset.tracksWithMediaType(AVMediaTypeAudio).first else { fatalError("\(__LINE__) \(__FUNCTION__)") }
      try? compositionAudioTracks[alternatingIndex].insertTimeRange(timeRangeInAsset, ofTrack: clipAudioTrack, atTime: nextClipStartTime)
      
      // Remember the time range in which this clip should pass through.
      // Second clip begins with a transition.
      // First clip ends with a transition.
      // Exclude those transitions from the pass through time ranges.
      passThroughTimeRanges.append(CMTimeRangeMake(nextClipStartTime, timeRangeInAsset.duration))
      if i > 0 {
        passThroughTimeRanges[i].start = CMTimeAdd(passThroughTimeRanges[i].start, transitionDuration)
        passThroughTimeRanges[i].duration = CMTimeSubtract(passThroughTimeRanges[i].duration, transitionDuration)
      }
      if i+1 < clipsCount {
        passThroughTimeRanges[i].duration = CMTimeSubtract(passThroughTimeRanges[i].duration, transitionDuration)
      }
      
      // The end of this clip will overlap the start of the next by transitionDuration.
      // (Note: this arithmetic falls apart if timeRangeInAsset.duration < 2 * transitionDuration.)
      // TODO: The arithmetic here needs to be be more flexible. 
      nextClipStartTime = CMTimeAdd(nextClipStartTime, timeRangeInAsset.duration)
      nextClipStartTime = CMTimeSubtract(nextClipStartTime, transitionDuration)
      
      // Remember the time range for the transition to the next item.
      if i+1 < clipsCount {
        transitionTimeRanges.append(CMTimeRangeMake(nextClipStartTime, transitionDuration))
      }
    }
    
    // Set up the video composition if we are to perform crossfade transitions between clips.
    var instructions = [AVMutableVideoCompositionInstruction]()
    var trackMixArray = [AVMutableAudioMixInputParameters]()
    
    // Cycle between "pass through A", "transition from A to B", "pass through B"
    for i in 0..<clipsCount {
      let alternatingIndex = i % 2
      
      // Pass through clip i
      let passThroughInstruction = AVMutableVideoCompositionInstruction()
      passThroughInstruction.timeRange = passThroughTimeRanges[i]
      let passThroughLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTracks[alternatingIndex])
      passThroughInstruction.layerInstructions = [passThroughLayer]
      instructions.append(passThroughInstruction)
      
      if i+1 < clipsCount {
        let transitionInstruction = AVMutableVideoCompositionInstruction()
        transitionInstruction.timeRange = transitionTimeRanges[i]
        let fromLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTracks[alternatingIndex])
        let toLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTracks[1-alternatingIndex])
        // Fade in the toLayer by setting a ramp from 0.0 to 1.0
        toLayer.setOpacityRampFromStartOpacity(0, toEndOpacity: 1, timeRange: transitionTimeRanges[i])
        
        transitionInstruction.layerInstructions = [toLayer, fromLayer]
        instructions.append(transitionInstruction)
        
        // Add AudioMix to fade in the valume ramps
        let trackMix1 = AVMutableAudioMixInputParameters(track: compositionAudioTracks[0])
        
        trackMix1.setVolumeRampFromStartVolume(1, toEndVolume: 0, timeRange: transitionTimeRanges[0])
        
        trackMixArray.append(trackMix1)
        
        let trackMix2 = AVMutableAudioMixInputParameters(track: compositionAudioTracks[1])
        
        trackMix2.setVolumeRampFromStartVolume(0, toEndVolume: 1, timeRange: transitionTimeRanges[0])
        trackMix2.setVolumeRampFromStartVolume(1, toEndVolume: 1, timeRange: passThroughTimeRanges[1])
        
        trackMixArray.append(trackMix2)
      }
      
    }
    
    audioMix.inputParameters = trackMixArray
    videoComposition.instructions = instructions
  }
  
  func buildCompositionObjectsForPlayback(){
    if clips.count == 0 { return }
    
    guard let videoSize = clips[0].tracksWithMediaType(AVMediaTypeVideo).first?.naturalSize else { fatalError("\(__LINE__) \(__FUNCTION__)") }
    
    composition.naturalSize = videoSize
    // With transitions:
    // Place clips into alternating video & audio tracks in composition, overlapped by transitionDuration.
    // Set up the video composition to cycle between "pass through A", "transition from A to B",
    // "pass through B"

    buildTransitionComposition(composition, andVideoComposition: videoComposition, andAudioMix: audioMix)
    
    // Every videoComposition needs these properties to be set:
    videoComposition.frameDuration = CMTimeMake(1, 30); // 30 fps
    videoComposition.renderSize = videoSize;
  }
  
  func playerItem() -> AVPlayerItem? {
    guard composition.tracks.count > 0 else { return nil }
    
    let playerItem = AVPlayerItem(asset: self.composition)
    playerItem.videoComposition = self.videoComposition
    playerItem.audioMix = self.audioMix
    
    return playerItem
  }
  
}



