//
//  ShortVideoComposer.swift
//  RealEstate
//
//  Created by Mike Kholomeev on 1/23/18.
//  Copyright © 2018 NIX. All rights reserved.
//
import Photos
import AVFoundation

class ShortVideoComposer {

    fileprivate let shortTime: Int64 = 30
    fileprivate let shortName = "ShortMotion.mov"
    fileprivate var images: Array<CGImage> = []
    
    fileprivate lazy var docsDir: URL = {
        let dirPaths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let docsDir = URL(fileURLWithPath:dirPaths[0])
        return docsDir
    }()

    fileprivate func deleteFileUrl(_ fileUrl:URL) -> Bool? {
        if FileManager.default.fileExists(atPath: fileUrl.path) {
            do {
                try FileManager.default.removeItem(at: fileUrl)
            } catch {
                return nil
            }
        }
        return true
    }

    func createShortVideo(_ url:URL, complition: @escaping ()->()) {
        let currentAsset = AVAsset(url: url)
        let mixComposition = AVMutableComposition()
        CMTimeMake(shortTime, 1)
        
        let compositionShortVideoTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.video,
                                                                   preferredTrackID: kCMPersistentTrackID_Invalid)
        let videoTrack = currentAsset.tracks(withMediaType: AVMediaType.video)[0]
        
        let frameDuration: Int64 = currentAsset.duration.value / (Int64(currentAsset.duration.timescale) * shortTime)
//        let shortTrackDuration = CMTimeMake(shortTime, currentAsset.duration.timescale);

        Array<Int64>(0...shortTime - 1).forEach { multiplier in
            let durationRange = CMTimeRangeMake(CMTimeMake(frameDuration * multiplier, 1), CMTimeMake(1, 1))

            do {
                _ = try compositionShortVideoTrack?.insertTimeRange(durationRange, of: videoTrack, at: CMTimeMake(multiplier, 1))
            } catch {
                return
            }
        }

        let times = Array<Int64>(0...shortTime - 1).map({  num -> NSValue in
            NSValue(time: CMTimeMake(frameDuration * num, 1))
        })

        let lastTime = times.last!.timeValue
        
        AVAssetImageGenerator(asset: currentAsset)
            .generateCGImagesAsynchronously(forTimes: times) { (time, cgImage, time2, result, error) in
                guard let cgImage = cgImage else { return }
                self.images.append(cgImage)

                guard
                    time == lastTime
                    else {
                        return
                }

                self.savePhotosToDeviceGallery()

                switch result {
                case .succeeded:
                    return
                case .failed:
                    print()
                case .cancelled:
                    print()
                }
        }
        guard let shortExportSession = AVAssetExportSession.init(asset: mixComposition,
                                                                  presetName: AVAssetExportPreset960x540) else {
                                                                    complition()
                                                                    return }
        shortExportSession.outputFileType = AVFileType.mov
        shortExportSession.shouldOptimizeForNetworkUse = true
        guard let slowmoTempURL = self.urlForSavingSlowedVideo(name:"") else {
            complition()
            return
        }
        shortExportSession.outputURL = slowmoTempURL
        
        shortExportSession.exportAsynchronously {
            switch shortExportSession.status {
            case .completed:
                mainAsync {
                    self.saveToDeviceGallery(slowmoTempURL, completion: { (url) in
                        print(url as Any)
                        complition()
                    })
                }
            case .failed: print("failed = \(shortExportSession.error as Any)")
            case .cancelled: print("cancelled = \(shortExportSession.error as Any)")
            case .exporting: print("exporting = \(shortExportSession.error as Any)")
            case .waiting: print("waiting = \(shortExportSession.error as Any)")
            case .unknown: print("unknown = \(shortExportSession.error as Any)")
            }
        }
    }
    
    fileprivate func urlForSavingSlowedVideo(name:String) -> URL? {
        let outputFilePath = docsDir.appendingPathComponent(shortName)
        guard let _ = deleteFileUrl(outputFilePath) else { return nil }
        return outputFilePath
    }
    
    fileprivate func savePhotosToDeviceGallery() {
        PHPhotoLibrary.requestAuthorization { (status) in
            switch status {
            case .authorized:
                self.images.map({ UIImage(cgImage: $0) }).forEach { image in
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAsset(from: image)
                    }) { saved, error in
                    }
                }
            case .denied:
                return
            default:
                return
            }
        }
    }

    fileprivate func saveToDeviceGallery(_ url:URL, completion:@escaping (_ url:URL?)->()) {
        var placeHolder: PHObjectPlaceholder?
        var changeRequest: PHAssetChangeRequest?
        PHPhotoLibrary.requestAuthorization { (status) in
            switch status {
            case .authorized:
                PHPhotoLibrary.shared().performChanges({
                    changeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                    placeHolder = changeRequest?.placeholderForCreatedAsset
                }) { saved, error in
                    guard let ddd = placeHolder?.localIdentifier else { return }
                    completion(URL(string: ddd))
                }
            case .denied:
                return
            default:
                return
            }
        }
    }
}

internal func mainAsync(block:@escaping ()->()) {
    DispatchQueue.main.async {
        block()
    }
}
