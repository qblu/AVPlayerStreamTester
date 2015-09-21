//
//  CachingAVAssetResourceLoaderDelegate.swift
//  AVPlayerStreamTester
//
//  Created by Rusty Zarse on 9/18/15.
//  Copyright © 2015 Levous, LLC. All rights reserved.
// converted from this gist: https://gist.github.com/anonymous/83a93746d1ea52e9d23f
// and this blog post: http://vombat.tumblr.com/post/86294492874/caching-audio-streamed-using-avplayer


import Foundation
import AVFoundation
import MobileCoreServices

class After6AVAssetresourceLoaderDelagate: NSObject {
    
    var assetData = NSMutableData()
    var connection: NSURLConnection? //TODO: should this really be optional?
    var response: NSHTTPURLResponse?
    var pendingRequests = [AVAssetResourceLoadingRequest]()
    
    func processPendingRequests() {
    
        var requestsCompleted = [AVAssetResourceLoadingRequest]()
    
        for loadingRequest in self.pendingRequests {
            //NOTE:                                         is that syntactically correct ?!
            guard let contentInformationrequest = loadingRequest.contentInformationRequest else {
                // loading request did not provide expected information
                // TODO: log this
                continue
            }
            
            fillInContentInformation(contentInformationrequest)
    
            let didRespondCompletely = respondWithDataForRequest(loadingRequest.dataRequest!)
    
            if (didRespondCompletely) {
                requestsCompleted.append(loadingRequest)
                loadingRequest.finishLoading()
            }
        }
    
        pendingRequests = pendingRequests.filter({
            completed in
            requestsCompleted.contains({ pending -> Bool in pending === completed })
        })
        
    }
    
    func fillInContentInformation(contentInformationRequest: AVAssetResourceLoadingContentInformationRequest) {
        guard let response = self.response else {
            return
        }
        
        guard let mimeType = response.MIMEType,
            //TODO: read up on takeRetainedValue() swift 2.0
            let contentType: CFStringRef = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, mimeType, nil)?.takeRetainedValue()
            else {
                // content type did not resolve from response
                //TODO: log this
                return
        }
        
        contentInformationRequest.byteRangeAccessSupported = true
        contentInformationRequest.contentType = contentType as String
        contentInformationRequest.contentLength = response.expectedContentLength
    }
    
    
    //MARK: - KVO
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        
        
    }

    
}

extension After6AVAssetresourceLoaderDelagate: AVAssetResourceLoaderDelegate {

    //TODO: refactor to result type
    func respondWithDataForRequest(dataRequest: AVAssetResourceLoadingDataRequest) -> Bool {
        let startOffset: Int64 = (dataRequest.currentOffset == 0) ? dataRequest.requestedOffset : dataRequest.currentOffset
        let assetDataLength = Int64(assetData.length) // NSMutableData.length is NSUInteger and is a 64 bit int for 64 bit apps
        if (assetDataLength < startOffset) {
            return false
        }
    
        // no longer necessary to copute a range?
        // total data from startOffset to currently downloaded
        //let unreadBytes = assetDataLength - startOffset
        // let numberOfBytesToRespondWith = min(Int64(dataRequest.requestedLength), unreadBytes)
        dataRequest.respondWithData(assetData) //, subdataWithRange:NSMakeRange(startOffset, numberOfBytesToRespondWith))
        let endOffset = startOffset + dataRequest.requestedLength
        let didRespondFully = Int64(assetData.length) >= endOffset
        return didRespondFully
    }
    
    
    func resourceLoader(resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequest loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let _ = connection else {
            //TODO: asserts might be a little too aggressive.  If something goes bad on one video URL, we should not crash the app but show a failed download and log
            assert(loadingRequest.request.URL != nil, "loadingRequest.request.URL cannot be nil")
            let interceptedURL = loadingRequest.request.URL!
            let urlComponents = NSURLComponents(URL: interceptedURL, resolvingAgainstBaseURL:false)!
            urlComponents.scheme = "http"
            let downloadURL = urlComponents.URL
            assert(downloadURL != nil, "\(loadingRequest.request.URL) failed to translate to a downloadURL")
            let request = NSURLRequest(URL:downloadURL!)
            connection = NSURLConnection(request:request, delegate:self, startImmediately:false)
            connection!.setDelegateQueue(NSOperationQueue.mainQueue())
            connection!.start()
        }
    
        pendingRequests.append(loadingRequest)
    
        return true
    }
    
    func resourceLoader(resourceLoader: AVAssetResourceLoader, didCancelLoadingRequest loadingRequest: AVAssetResourceLoadingRequest){
        if let index = pendingRequests.indexOf({$0 == loadingRequest}) {
            pendingRequests.removeAtIndex(index)
        }
    }
}

extension After6AVAssetresourceLoaderDelagate: NSURLConnectionDataDelegate {
    
    
    
    func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        self.assetData = NSMutableData()
        self.response = (response as! NSHTTPURLResponse)
        self.processPendingRequests()
    }
    
    func connection(connection: NSURLConnection,  didReceiveData data: NSData) {
        self.assetData.appendData(data)
        self.processPendingRequests()
    }
    
    func connectionDidFinishLoading(connection: NSURLConnection) {
        self.processPendingRequests()
    
        //TODO: this is likely not going to work.  The HLS files live in a directory on S3 with matching file names between assets
        let fileName = connection.currentRequest.URL!.lastPathComponent!
        let cachedFileURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent("asset-cache").URLByAppendingPathComponent(fileName)
        do {
            try self.assetData.writeToURL(cachedFileURL, options: .DataWritingAtomic)
        }
        catch let error as NSError {
            //TODO: handle this error!
            print(error.localizedDescription)
        }
        
    }

}