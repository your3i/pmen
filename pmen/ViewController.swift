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
    static let avatar = "avatar"

    static let staticKeys = [Key.name, Key.nickname, Key.romaji, Key.hirakana, Key.team, Key.floor, Key.avatar]
}

class ViewController: UIViewController, GIDSignInUIDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()

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

        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        Alamofire.request(url).responseData { [weak self] response in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false

            guard let data = response.result.value else {
                print("@DD Error request failure.")
                return
            }

            do {
                guard
                    let jsonDic = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any],
                    let feedDic = jsonDic["feed"] as? [String: Any],
                    let entryDicArray = feedDic["entry"] as? [[String: Any]],
                    let parsedEntryDicArray = self?.parse(with: entryDicArray) else {
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
            let man = dicArray[i]
            guard let attributeSet = buildAttributeSet(forMan: man) else {
                continue
            }

            let aItem = CSSearchableItem(uniqueIdentifier: "com.your3i.pmen.pmanNo\(i)",
                domainIdentifier: "pmen", attributeSet: attributeSet)
            items.append(aItem)
        }

        CSSearchableIndex.default().indexSearchableItems(items) { (error) -> Void in
            if error != nil {
                print(error?.localizedDescription ?? "")
            }
        }
    }

    private func buildAttributeSet(forMan man: [String: String]) -> CSSearchableItemAttributeSet? {
        guard
            let name = man[Key.name],
            let nickname = man[Key.nickname],
            let team = man[Key.team],
            let floor = man[Key.floor],
            let romaji = man[Key.romaji],
            let hiragana = man[Key.hirakana] else {
            return nil
        }

        let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)

        attributeSet.title = name + " " + nickname + " @ " + team

        var otherDescription = ""
        if !floor.isEmpty {
            otherDescription += "/ \(floor) "
        }
        if !hiragana.isEmpty {
            otherDescription += "/ \(hiragana) "
        }
        if !romaji.isEmpty {
            otherDescription += "/ \(romaji) "
        }

        for (key, value) in man {
            guard !Key.staticKeys.contains(key), !value.isEmpty else {
                continue
            }
            otherDescription += "/ \(key): \(value) "
        }
        attributeSet.contentDescription = otherDescription

        if let avatar = man[Key.avatar], !avatar.isEmpty,
            let avatarURL = URL(string: avatar) {

            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            if let data = try? Data(contentsOf: avatarURL) {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                attributeSet.thumbnailData = data
            }
        }

        var keywords = ["ppp", nickname, name, romaji]
        keywords.append(contentsOf: (nickname.characters).map { String($0) })
        keywords.append(contentsOf: (name.characters).map { String($0) })
        keywords.append(contentsOf: (hiragana.characters).map { String($0) })
        attributeSet.keywords = keywords

        return attributeSet
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
