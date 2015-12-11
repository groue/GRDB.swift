//: Playground - noun: a place where people can play

import UIKit

let yesterdayArrivals = ["Thomas", "Sylvaine", "Pascal", "Pierlo", "Gwen", "Julien", "Alex"]
let todayArrivals = ["Guillaume", "Pascal", "Sylvaine", "Pierlo", "Gwen", "Alex", "Fabien", "Maxime", "Greg"]

enum Update<T> {
    case Insert(item:T, at: NSIndexPath)
    case Delete(item:T, from: NSIndexPath)
    case Move(item:T, from: NSIndexPath, to: NSIndexPath)
    case Reload(item:T, at: NSIndexPath)
    
    var description: String {
        switch self {
        case .Insert(let item, let at):
            return "\(item) inserted at \(at)"
            
        case .Delete(let item, let from):
            return "\(item) deleted from \(from)"
            
        case .Move(let item, let from, let to):
            return "\(item) moved from \(from) to \(to)"
            
        case .Reload(let item, let at):
            return "\(item) updated at \(at)"
        }
    }
}

func calculateUpdatesFrom(from: [String], to: [String]) -> [Update<String>] {
    
    var updates = [Update<String>]()
    var current = from
    let finalIndexPathForItem: [String:NSIndexPath]!
    var currentIndexPathForItem: [String:NSIndexPath]!

    func indexPaths(items: [String]) -> [String:NSIndexPath] {
        var indexPathForItem = [String:NSIndexPath]()
        for (index, item) in items.enumerate() {
            let indexPath = NSIndexPath(forItem: index, inSection: 0)
            indexPathForItem[item] = indexPath
        }
        return indexPathForItem
    }
    
    func apply(update: Update<String>) {
        current.applyUpdate(update)
        currentIndexPathForItem = indexPaths(current)
    }

    finalIndexPathForItem = indexPaths(to)
    currentIndexPathForItem = indexPaths(current)
    
    // 2 - INSERTS
    for item: String in to {
        if let _ = currentIndexPathForItem[item] {
            // item was there
        } else {
            // Insert
            let newIndexPath = finalIndexPathForItem[item]!
            let update = Update.Insert(item: item, at: newIndexPath)
            updates.append(update)
            apply(update)
        }
    }

    // 3 - DELETED & MOVES
    currentIndexPathForItem = indexPaths(current)
    for item: String in from {
        let oldIndexPath = currentIndexPathForItem[item]!
        if let newIndexPath = finalIndexPathForItem[item] {
            // item moved
            let update = Update.Move(item: item, from: oldIndexPath, to: newIndexPath)
            updates.append(update)
            apply(update)
        } else {
            // item deleted
            let update = Update.Delete(item: item, from: oldIndexPath)
            updates.append(update)
            apply(update)
        }
    }
    
//    // 4 - UPDATES
//    for item: String in from {
//        let oldIndexPath = currentIndexPathForItem[item]!
//        if (treatedIndexPaths.contains(oldIndexPath)) {
//            continue;
//        }
//        
//        if let newIndexPath = finalIndexPathForItem[item] where newIndexPath == oldIndexPath {
//            // item has not moved, just reload
//            updates.append(Update.Reload(item: item, at: oldIndexPath))
//        }
//    }
    
    return updates
}

extension Array {
    mutating func applyUpdate(update: Update<Array.Generator.Element>) {
        switch update {
        case .Insert(let item, let at):
            self.insert(item, atIndex: at.item)
            
        case .Delete(_, let from):
            self.removeAtIndex(from.item)
            
        case .Move(let item, let from, let to):
            self.removeAtIndex(from.item)
            self.insert(item, atIndex: to.item)
            
        case .Reload(_, _): break
        }
        print(update.description)
    }
}


var test = yesterdayArrivals
print(test)
let updates = calculateUpdatesFrom(yesterdayArrivals, to: todayArrivals)
for update: Update in updates {
    print(update.description)
    test.applyUpdate(update)
}
print(test)

