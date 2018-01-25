//
//  ViewController.swift
//  VideoShortTest
//
//  Created by Mike Kholomeev on 1/23/18.
//  Copyright © 2018 NixSolutions Ltd. All rights reserved.
//

import UIKit
import Photos
import Alamofire
import PromiseKit
import SwiftyJSON
import GoogleAPIClientForREST

extension ViewController: GIDSignInDelegate, GIDSignInUIDelegate {}

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    let composer = ShortVideoComposer()
    let service =  GTLRYouTubeService()
    let apiKey = "AIzaSyCZZu4o_oM0QG6eCN-PKoFGf8eoTqsrMBc"
    var user: GIDGoogleUser?
    
    @IBOutlet weak var signInButton: GIDSignInButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        var configureError: NSError?
        GGLContext.sharedInstance().configureWithError(&configureError)
        assert(configureError == nil, "Error configuring Google services: \(configureError)")

        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().scopes = [kGTLRAuthScopeYouTube, kGTLRAuthScopeYouTubeUpload]
        GIDSignIn.sharedInstance().shouldFetchBasicProfile = true
        GIDSignIn.sharedInstance().signInSilently()
    }

    @IBAction func selectVideo() {
        guard !composer.hasVideo else {
            composer.createShortVideo(nil) { smalVideoUrl in
                mainAsync {
                    self.dismiss(animated: true, completion: nil)
                    self.view.isUserInteractionEnabled = true
                }
                guard let url = smalVideoUrl else { return }
                self.uploadVideo(from: url)
            }
            return
        }
        let imagePickerController = UIImagePickerController()
        
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self
        
        imagePickerController.mediaTypes = ["public.image", "public.movie"]
        present(imagePickerController, animated: true, completion: nil)
    }

    @IBAction func signOut() {
        GIDSignIn.sharedInstance().signOut()
    }

// MARK: - rest request for login with second code
//    fileprivate func loginGoogle() {
//        let body = ["client_id" : "681345708038-2utd09gfnhn125v75cucpkvsjj46hcj9.apps.googleusercontent.com",
//                    "scope" : "email profile"]
//
//        guard let url = URL(string: "https://accounts.google.com/o/oauth2/device/code") else { return }
//
//        Alamofire
//            .request(url, method: .post, parameters: body)
//            .validate()
//            .responseJSON() { response -> Void in
//                let rr = JSON(response.result.value!)
//                print(rr)
//        }
//    }

    func uploadVideo(from url: URL){
        service.authorizer = GIDSignIn.sharedInstance().currentUser.authentication.fetcherAuthorizer()
//        let query = GTLRYouTubeQuery_ActivitiesList.query(withPart: "snippet")
//        query.mine = true;
//
//        service.executeQuery(query) { (ticket, obj, error) in
//            print(ticket)
//            print(obj)
//            print(error)
//        }

        let status = GTLRYouTube_VideoStatus()
        status.privacyStatus = kGTLRYouTube_VideoStatus_PrivacyStatus_Public
        
        let snippet = GTLRYouTube_VideoSnippet()
        snippet.title = "Lalala"
        snippet.descriptionProperty = "TestUpload"
        snippet.tags = "test,video,upload".components(separatedBy: ",")
        
        let youtubeVideo = GTLRYouTube_Video()
        youtubeVideo.snippet = snippet
        youtubeVideo.status = status
        
        let uploadParams = GTLRUploadParameters(fileURL: url, mimeType: "video/mp4")
        
        let uploadQuery = GTLRYouTubeQuery_VideosInsert.query(withObject: youtubeVideo, part: "snippet,status", uploadParameters: uploadParams)
        
        uploadQuery.executionParameters.uploadProgressBlock = {(progressTicket, totalBytesUploaded, totalBytesExpectedToUpload) in
            print("Uploaded", totalBytesUploaded)
        }
        
//        let uploadQuery = GTLRYouTubeQuery_ActivitiesInsert.query(withObject: activObjec, part: "fileDetails")
        
        service.executeQuery(uploadQuery) { (ticket, obj, error) in
            print(ticket)
            print(obj)
            print(error)
        }
//        [self.service executeQuery:query completionHandler:^(GTLRServiceTicket *ticket, id object, NSError *error) {
//            NSLog(@"object is %@",object);
//            NSLog(@"error is %@",error);
//            }];
        
        // Set up your URL
    }
    
    // MARK: - UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        guard
            let type = info[UIImagePickerControllerMediaType] as? String,
            type == "public.movie"
            else {
                return
        }
        guard let url = info[UIImagePickerControllerMediaURL] as? URL else {
            return
        }

        view.isUserInteractionEnabled = false

        composer.createShortVideo(url) { smalVideoUrl in
            mainAsync {
                self.dismiss(animated: true, completion: nil)
                self.view.isUserInteractionEnabled = true
            }
            guard let url = smalVideoUrl else { return }
            self.uploadVideo(from: url)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - GIDSignInDelegate
    func signIn(signIn: GIDSignIn!, didSignInForUser user: GIDGoogleUser!,
                withError error: NSError!) {
        if (error == nil) {
            self.user = user
            let userId = user.userID                  // For client-side use only!
            let idToken = user.authentication.idToken // Safe to send to the server
            let fullName = user.profile.name
            let givenName = user.profile.givenName
            let familyName = user.profile.familyName
            let email = user.profile.email
        } else {
            print("\(error.localizedDescription)")
        }
    }

    func signIn(signIn: GIDSignIn!, didDisconnectWithUser user:GIDGoogleUser!,
                withError error: NSError!) {
    }
    
    // MARK: - GIDSignInUIDelegate
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if (error == nil) {
            self.user = user
            let userId = user.userID                  // For client-side use only!
            let idToken = user.authentication.idToken // Safe to send to the server
            let fullName = user.profile.name
            let givenName = user.profile.givenName
            let familyName = user.profile.familyName
            let email = user.profile.email
        } else {
            print("\(error.localizedDescription)")
        }
    }
}

