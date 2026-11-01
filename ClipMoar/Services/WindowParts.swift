import CompanionKit
import Foundation

struct WindowPartNode {
    let role: String
    let title: String
    let rect: CGRect
    let children: [WindowPartNode]
}

func windowParts(_ nodes: [WindowPartNode], parent: CGRect, app: String) -> [WindowFrame] {
    let roles: Set = ["AXSplitGroup", "AXScrollArea", "AXWebArea", "AXGroup", "AXTabGroup", "AXTable", "AXOutline", "AXList", "AXBrowser", "AXTextArea", "AXLayoutArea"]
    var count = 0
    func collect(_ nodes: [WindowPartNode], parent: CGRect, depth: Int) -> [WindowFrame] {
        var result: [WindowFrame] = []
        for node in nodes {
            guard count < 40 else { break }
            let rect = node.rect.intersection(parent)
            guard !rect.isNull, !rect.isEmpty else { continue }
            let include = roles.contains(node.role) && rect.width >= 120 && rect.height >= 120 && rect.width * rect.height < parent.width * parent.height * 0.95
            if include {
                guard depth <= 4 else { continue }
                count += 1
                let children = depth < 4 ? collect(node.children, parent: rect, depth: depth + 1) : []
                result.append(WindowFrame(x: Int(rect.minX), y: Int(rect.minY), width: Int(rect.width), height: Int(rect.height), app: app, title: node.title.isEmpty ? node.role : node.title, children: children))
            } else {
                result.append(contentsOf: collect(node.children, parent: parent, depth: depth))
            }
        }
        return result
    }
    return collect(nodes, parent: parent, depth: 1)
}
