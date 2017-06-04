//
//  ViewController.swift
//  pmen
//
//  Created by your3i on 2017/06/02.
//  Copyright © 2017 your3i. All rights reserved.
//

import MobileCoreServices
import CoreSpotlight
import GoogleSignIn
import Alamofire
import UIKit

enum Key {
    static let nickname = "nickname"
    static let name = "name"
    static let romaji = "romaji"
    static let hirakana = "hirakana"
    static let team = "team"
    static let floor = "floor"
    static let extensionNo = "extensionNo"
}

class ViewController: UIViewController, GIDSignInUIDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize sign-in
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().uiDelegate = self

        if GIDSignIn.sharedInstance().hasAuthInKeychain() {
            GIDSignIn.sharedInstance().signInSilently()
        } else {
            GIDSignIn.sharedInstance().signIn()
        }
    }

    fileprivate func loadJSONData(withToken token: String) {
        let url = "https://spreadsheets.google.com/feeds/list/1A2hgSyw4uaj0v5j01FSPw92mbm7qoqRlNOKQ-Ijv9x0/od6/public/values?alt=json&access_token=\(token)"
        Alamofire.request(url).responseData { [weak self] response in
            guard let data = response.result.value else {
                print("@DD Request failure.")
                return
            }
            guard let utf8Text = String(data: data, encoding: .utf8) else {
                return
            }
            print("@DD data: \(utf8Text)")

            do {
                guard let jsonDic = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any],
                let feedDic = jsonDic["feed"] as? [String: Any] else {
                    return
                }
                guard let entryDicArray = feedDic["entry"] as? [[String: Any]] else {
                    return
                }
                guard let parsedEntryDicArray = self?.parse(with: entryDicArray) else {
                    return
                }

                self?.setupSearchableItems(with: parsedEntryDicArray)

                let alertController = UIAlertController(title: "おめでとう", message: "セットアップできたよ", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "やった!", style: .default, handler: nil))
                self?.present(alertController, animated: true, completion: nil)
            } catch {
                print("Error deserializing JSON: \(error)")
            }
        }
    }

    private func parse(with dicArray: [[String: Any]]) -> [[String: String]] {
        var array = [[String: String]]()

        dicArray.forEach {
            var dic = [String: String]()
            for (key, value) in $0 {
                guard key.hasPrefix("gsx$"), let valueDic = value as? [String: Any] else {
                    continue
                }

                let newKey = key.replacingOccurrences(of: "gsx$", with: "")
                let newValue = valueDic["$t"]
                dic[newKey] = newValue as? String ?? ""
            }
            array.append(dic)
        }

        return array
    }

    private func setupSearchableItems(with dicArray: [[String: String]]) {
        guard dicArray.count > 0 else {
            return
        }

        var items = [CSSearchableItem]()
        for i in 0 ..< dicArray.count {
            let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)

            let man = dicArray[i]
            let name = man[Key.name]!
            let nickname = man[Key.nickname]!

            attributeSet.title = name + " " + nickname

            var otherDescription = ""
            for (key, value) in man {
                guard key != Key.name, key != Key.nickname else {
                    continue
                }
                otherDescription += "/ \(key): \(value) "
            }
            attributeSet.contentDescription = otherDescription

            var keywords = ["ppp", nickname, man[Key.romaji]!]
            keywords.append(contentsOf: (name.characters).map { String($0) })
            keywords.append(contentsOf: (man[Key.hirakana]!.characters).map { String($0) })
            attributeSet.keywords = keywords

            let aItem = CSSearchableItem(uniqueIdentifier: "com.your3i.pmen.pmanNo\(i)", domainIdentifier: "pmen", attributeSet: attributeSet)
            items.append(aItem)
        }

        CSSearchableIndex.default().indexSearchableItems(items) { (error) -> Void in
            if error != nil {
                print(error?.localizedDescription ?? "")
            }
        }
    }
}

extension ViewController: GIDSignInDelegate {
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        guard error == nil else {
            print("@DD Error: \(error)")
            return
        }

        print("@DD Token: \(user.authentication.accessToken)")
        loadJSONData(withToken: user.authentication.accessToken)
    }

    func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: Error!) {
        print("@DD didDisconnectWithUser: \(user.profile.name)")
    }
}

