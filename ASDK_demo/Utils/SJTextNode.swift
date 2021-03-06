//
//  SJTextNode.swift
//  ASDK_demo
//
//  Created by Shi Jian on 2017/8/2.
//  Copyright © 2017年 Shi Jian. All rights reserved.
//

import UIKit
import AsyncDisplayKit

let patternUrl = "(https?|ftp|file)://[-A-Za-z0-9+&@#/%?=~_|!:,.;]+[-A-Za-z0-9+&@#/%=~_|]"

enum SJLinkStyle: String {
    case atPerson = "atPerson"
    case topic = "topic"
    case custom = "custom"
    
    static func getNames() -> [String] {
    
        return [SJLinkStyle.atPerson.rawValue, SJLinkStyle.topic.rawValue, SJLinkStyle.custom.rawValue]
    }
    
    func pattern() -> SJTextRegular {
    
        switch self {
        case .atPerson:
            
            return SJTextRegular(type: self, start: "@", end: "\\s")
    
        case .topic:
            
            return SJTextRegular(type: self, start: "#", end: "#")
            
        case .custom:
            
            return SJTextRegular(pattern: patternUrl)
        }
    }
}

class SJTextNode: ASTextNode {

    var text: String = ""
    
    var displaySignal = true
    
    var patterns: [SJTextRegular]?
    
    init(text: String, displaySignal: Bool = true, patterns: [SJTextRegular]? = nil) {
        super.init()
        
        self.text = text
        self.displaySignal = displaySignal
        
        if let aPattern = patterns {
        
            self.patterns = aPattern
            
        } else {
        
            self.patterns = [SJLinkStyle.topic.pattern(), SJLinkStyle.atPerson.pattern(), SJLinkStyle.custom.pattern()]
        }
        
        // 设置相关属性
        self.layer.as_allowsHighlightDrawing = true
        self.isUserInteractionEnabled = true
        self.delegate = self
        self.linkAttributeNames = SJLinkStyle.getNames()
        
        matchRegular()
    }
    
    func matchRegular() {
        let range = NSRange(location: 0, length: text.characters.count)

        if displaySignal {
        
            let attriStr = NSMutableAttributedString(string: text, attributes: SJTextNodeConfig.normalAttri())
            patterns?.forEach { [weak self] in
                self?.normal(pattern: $0, range: range, matches: attriStr)
            }
            
            self.attributedText = attriStr
            return
        }
        // 屏蔽掉信号符号
        
        let attriStr = NSMutableAttributedString(string: text, attributes: SJTextNodeConfig.normalAttri())
        
        var matchKeys = [SJMatchKey]()
        
        patterns?.forEach { [weak self] in
            
            guard let aSelf = self else { return }
            matchKeys.append(contentsOf: aSelf.noSignal(pattern: $0, range: range, matches: attriStr))
        }
        
        // sort key
        matchKeys.sort { (first, second) -> Bool in
            return first.range.location < second.range.location
        }
        
        let aCount = matchKeys.count - 1
        for i in 0...aCount {
            
            let matchKey = matchKeys[aCount - i]
            let title = matchKey.pattern.pickUp(source: matchKey.title)
            let str = NSAttributedString(string: title, attributes: SJTextNodeConfig.highlightAttri(style: matchKey.pattern.type, title: title))
            attriStr.replaceCharacters(in: matchKey.range, with: str)
        }
        
        self.attributedText = attriStr
    }
    
//    fileprivate func convert(range: NSRange, pattern: SJTextRegular, index: Int) -> NSRange {
//
//        let sigCount = pattern.startLength() + pattern.endLength()
//        let location = range.location + pattern.startLength() - sigCount * index
//       // let length = range.length - sigCount
//        return NSRange(location: max(location, 0), length: range.length)
//    }

    fileprivate func normal(pattern: SJTextRegular, range: NSRange, matches: NSMutableAttributedString) {
        let regular = try! NSRegularExpression(pattern: pattern.pattern, options: .caseInsensitive)

        regular.enumerateMatches(in: text, options: .reportCompletion, range: range) { [weak self] (result, flags, stop) in
            guard let aResult = result, let aSelf = self else { return }
            let title = (aSelf.text as NSString).substring(with: aResult.range)
            matches.addAttributes(SJTextNodeConfig.highlightAttri(style: pattern.type, title: title), range: aResult.range)
        }
    }
    
    fileprivate func noSignal(pattern: SJTextRegular, range: NSRange, matches: NSMutableAttributedString) ->  [SJMatchKey] {
        let regular = try! NSRegularExpression(pattern: pattern.pattern, options: .caseInsensitive)
        
        var matchKey = [SJMatchKey]()
        regular.enumerateMatches(in: text, options: .reportCompletion, range: range) { [weak self] (result, flags, stop) in
            guard let aResult = result, let aSelf = self else { return }
            let title = (aSelf.text as NSString).substring(with: aResult.range)
            
            matchKey.append(SJMatchKey(range: aResult.range, title: title, pattern: pattern))
            matches.addAttributes(SJTextNodeConfig.highlightAttri(style: pattern.type, title: title), range: aResult.range)
        }
        
        return matchKey
    }
    
    
    struct SJMatchKey {
        
        var range: NSRange
        
        var title: String
        
        var pattern: SJTextRegular
        
        init(range: NSRange, title: String, pattern: SJTextRegular) {
            self.range = range
            self.title = title
            self.pattern = pattern
        }
    }

}

extension SJTextNode: ASTextNodeDelegate {

    func textNode(_ textNode: ASTextNode, shouldHighlightLinkAttribute attribute: String, value: Any, at point: CGPoint) -> Bool {
        return true
    }
    
    func textNode(_ textNode: ASTextNode, tappedLinkAttribute attribute: String, value: Any, at point: CGPoint, textRange: NSRange) {
        
        guard let clickStr = value as? String, let type = SJLinkStyle(rawValue: attribute) else { return }
        
        self.view.makeToast(type.rawValue + ":  " + clickStr)

    }
}


struct SJTextRegular {
    
    var pattern: String
    var start: String
    var end: String
    
    var type: SJLinkStyle
    
    init(type: SJLinkStyle, start: String, end: String) {
        self.type = type
        self.start = start
        self.end = end
        
        self.pattern = start + ".*?" + end
    }
    
    init(pattern: String) {
        self.pattern = pattern
        self.type = .custom
        self.start = ""
        self.end = ""
    }

    func pickUp(source: String) -> String {
    
        if type == .custom { return source }
        
        let endTip = end == "\\s" ? " " : end
        
        if source.hasPrefix(start) && source.hasSuffix(endTip) {
            return source.replacingOccurrences(of: start, with: "").replacingOccurrences(of: end, with: "")
        }
        
        return source
    }
    
}

struct SJTextNodeConfig {
    
    static func normalAttri() -> [String: Any] {
    
        return defaultAttri()
    }
    
    static func highlightAttri(style: SJLinkStyle, title: String) -> [String: Any] {
        
        return [style.rawValue: title,
                NSFontAttributeName: UIFont.systemFont(ofSize: 16),
                NSForegroundColorAttributeName: SJColor(20, green: 130, blue: 240),
                NSUnderlineStyleAttributeName: 1
                ]
    }
    
}
