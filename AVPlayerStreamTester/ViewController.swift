//
//  ViewController.swift
//  AVPlayerStreamTester
//
//  Created by Rusty Zarse on 9/16/15.
//  Copyright © 2015 Levous, LLC. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class ViewController: UIViewController {

    enum SaveURLResult {
        case Success(NSURL)
        case Failure
    }
    
    @IBOutlet weak var streamUrlTextField: UITextField!
    @IBOutlet weak var infoTextView: UITextView!
    var avPlayerViewController: AVPlayerViewController?
    let resourceLoader = After6AVAssetresourceLoaderDelagate()

    var streamURL: NSURL?
    let userDefaultsKeyStream = "testStreamURL"
    
    @IBAction func loadStreamButtonTapped(sender: AnyObject) {
        switch saveValidUrlString(streamUrlTextField.text) {
        case .Success(let url):
            startAVPlayerWithURL(url)
        default:
            let alertController = UIAlertController(title: "Bad URL", message: "That doesn't appear to be a valid URL.  Please provide a valid stream url?", preferredStyle: UIAlertControllerStyle.Alert)
            alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(alertController, animated: true) {
                
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let lastLoadedStream = NSUserDefaults.standardUserDefaults().URLForKey(userDefaultsKeyStream) {
            streamURL = lastLoadedStream
        } else {
            streamURL = NSURL(string: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8")
        }
        
        streamUrlTextField.text = streamURL?.absoluteString
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "embedAVPlayer", let avPlayerVC = segue.destinationViewController as? AVPlayerViewController {
            avPlayerViewController = avPlayerVC
            self.addChildViewController(avPlayerVC)
        }
    }
    
    func saveValidUrlString(urlString: String?) -> SaveURLResult {
        guard let urlText = urlString,
            let url = NSURL(string: urlText) else {
                return .Failure
        }
        
        streamURL = url
        NSUserDefaults.standardUserDefaults().setURL(streamURL, forKey: userDefaultsKeyStream)
        return .Success(url)
    }
    
    func startAVPlayerWithURL(url:NSURL) {
        let asset = AVURLAsset(URL: url)
        asset.resourceLoader.setDelegate(resourceLoader, queue:dispatch_get_main_queue())
        let playerItem = AVPlayerItem(asset: asset)
        avPlayerViewController!.player = AVPlayer(playerItem: playerItem)
    }
}

