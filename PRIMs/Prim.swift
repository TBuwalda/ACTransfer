//
//  Prim.swift
//  
//
//  Created by Niels Taatgen on 4/17/15.
//
//

import Foundation
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


/// Buffer mappings for buffers that can be used as source (in condition or lhs of action)
let bufferMappingC = ["V":"input","WM":"imaginal","G":"goal","C":"operator","AC":"action","RT":"retrievalH","GC":"constants"]
/// Buffer mappings for buffer that are used in the rhs of an action
let bufferMappingA = ["V":"input","WM":"imaginalN","G":"goal","C":"operator","AC":"action","RT":"retrievalR","GC":"constants"]
/// Buffer Order determines which buffer is preferred on the left side of a PRIM (lower is left)
let bufferOrder = ["input":1,"goal":2,"imaginal":3,"retrievalH":4,"constants":5,"operator":6]

/** 
This function takes a string that represents a PRIM, and translates it into its components

- returns: is a five-tuple with left-buffer-name left-buffer-slot, operator, right-buffer-name, right-buffer-slot, PRIM with reversed lhs and rhs if necessary
*/
func parseName(_ name: String) -> (String?,String?,String,String?,String?,String?) {
    var components: [String] = []
    var component = ""
    var prevComponentCat = 1
    for ch in name.characters {
        var componentCat: Int
        switch ch {
        case "A"..."Z":  componentCat = 1
        case "a"..."z": componentCat = 1
        case "0"..."9":  componentCat = 2
        case "<",">","=","-":  componentCat = 3
        default:  componentCat = -1
        }
        if prevComponentCat == componentCat {
            component += String(ch)
        } else {
            components.append(component)
            component = String(ch)
        }
        prevComponentCat = componentCat
    }
    components.append(component)
    let compareError = components.count < 4
    let parseError = compareError || (components[0] != "nil" && components[3] != "nil" && (components.count == 4 || bufferMappingC[components[3]] == "nil"))
    if  parseError || components[0] == "nil" && components[1] != "->" {
        return ("","","",nil,nil,nil)
    } else if components[0] == "nil" {
        let rightBuffer = bufferMappingA[components[2]]
        if rightBuffer == nil { return ("","","",nil,nil,nil) }
        return (nil,nil,"->",rightBuffer!,"slot" + components[3],nil)
    } else if components[3] == "nil" {
        let leftBuffer = bufferMappingC[components[0]]
        if leftBuffer == nil { return ("","","",nil,nil,nil) }
        return (leftBuffer!,"slot" + components[1],components[2],nil,nil,nil)
    } else {
        var rightBuffer = (components[2] == "->") ? bufferMappingA[components[3]] : bufferMappingC[components[3]]
        var leftBuffer = bufferMappingC[components[0]]
        if rightBuffer == nil || leftBuffer == nil {
            return ("","","",nil,nil,nil)
        } else {
            var newPrim: String? = nil
            if (components[2] == "=" || components[2] == "<>") && bufferOrder[leftBuffer!]! >= bufferOrder[rightBuffer!]! {
                if (bufferOrder[leftBuffer!]! > bufferOrder[rightBuffer!]!) || (Int(components[1]) > Int(components[4])) {
                    let tmp = rightBuffer
                    rightBuffer = leftBuffer
                    leftBuffer = tmp
                    let tmp2 = components[1]
                    components[1] = components[4]
                    components[4] = tmp2
                    newPrim = components[3] + components[1] + components[2] + components[0] + components[4]
                }
            }
            return (leftBuffer!,"slot" + components[1],components[2],rightBuffer!, "slot" + components[4],newPrim)
        }
    }
}

class Prim:NSObject, NSCoding {
    let lhsBuffer: String?
    let lhsSlot: String?
    let rhsBuffer: String? // Can be nil
    let rhsSlot: String?
    let op: String
    let model: Model
    let name: String
    
    override var description: String {
        get {
            return name
        }
    }
    
    init(name: String, model: Model) {
        self.name = name
        self.model = model
        (lhsBuffer,lhsSlot,op,rhsBuffer,rhsSlot,_) = parseName(name)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        guard let model = aDecoder.decodeObject(forKey: "model") as? Model,
            let name = aDecoder.decodeObject(forKey: "name") as? String
            else { return nil }
        self.init(name: name, model: model)
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(self.model, forKey: "model")
        coder.encode(self.name, forKey: "name")
    }
    
    /**
    Carry out the PRIM, either by checking its condition or by performing its action. 
    In the case of an action to an empty buffer, an empty fact chunk is created in that buffer.

    - returns: a Bool to indicate success
    */
    func fire() -> Bool {
        let lhsVal = lhsBuffer == nil ? nil :
        lhsBuffer! == "operator" ? model.buffers[lhsBuffer!]?.slotValue(lhsSlot!) : model.formerBuffers[lhsBuffer!]?.slotValue(lhsSlot!)

        switch op {
        case "=":
            if rhsBuffer == nil {
                return lhsVal == nil
            } else if lhsVal == nil {
                return false
            }
            let rhsVal = model.buffers[rhsBuffer!]?.slotValue(rhsSlot!)
            return rhsVal == nil ? false : lhsVal!.isEqual(rhsVal!)
        case "<>":
            if rhsBuffer == nil {
                return lhsVal != nil
            } else if lhsVal == nil {
                return false
            }
            let rhsVal = model.buffers[rhsBuffer!]?.slotValue(rhsSlot!)
            return rhsVal == nil ? false : !lhsVal!.isEqual(rhsVal!)
        case "->":
            if lhsBuffer != nil && lhsVal == nil {
                return false }
            if lhsSlot == nil && model.buffers[rhsBuffer!] != nil && model.buffers[rhsBuffer!]!.slotvals[rhsSlot!] != nil {
                model.buffers[rhsBuffer!]!.slotvals[rhsSlot!] = nil
                return true
            }
//            if rhsBuffer == nil || lhsVal == nil {return false}
            if model.buffers[rhsBuffer!] == nil {
                let chunk = model.generateNewChunk(rhsBuffer!)
                chunk.setSlot("isa",value: "fact")
                model.buffers[rhsBuffer!] = chunk
            }
            if lhsVal == nil {
                if rhsBuffer! == "imaginalN" {
                    model.buffers[rhsBuffer!]!.setSlot(rhsSlot!, value: "nil")
                }
                return true
            }
            model.buffers[rhsBuffer!]!.setSlot(rhsSlot!, value: lhsVal!)
            return true
        default: return false
        }
        
    }
    
    /**
    Test whether an action PRIM is applicable, if not return false
    This is the case if the lhs part doesn't resolve to nil
    */
    func testFire() -> Bool {
        if lhsSlot == nil { return true } else {
            let lhsVal = model.buffers[lhsBuffer!]?.slotValue(lhsSlot!)
            return lhsVal != nil
        }
    }
    
    
    
}
