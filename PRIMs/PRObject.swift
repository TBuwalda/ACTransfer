//
//  PRObject.swift
//  PRIMs
//
//  Created by Niels Taatgen on 5/11/15.
//  Copyright (c) 2015 Niels Taatgen. All rights reserved.
//

import Foundation

class PRObject{
    /// Attributes of the object. These will be put in V1..Vn
    let attributes: [String]
    /// The object that this object is part of, if any
    let superObject: PRObject?
    /// Name of the object
    let name: String
    /// List of component objects of the object, if any
    var subObjects: [PRObject] = []
    /// How many of the subObjects have already been attended?
    var attended = 0
    
    init(name: String, attributes: [String], superObject: PRObject?) {
        self.name = name
        self.attributes = attributes
        self.superObject = superObject
        if superObject != nil {
            superObject!.subObjects.append(self)
        }
    }
 
    /** 
    Convert the current object into a chunk that can be put into the input buffer

    :returns: A chunk representing this object
    */
    func chunk(model: Model) -> Chunk {
        let chunk = model.generateNewChunk(s1: "perception")
        chunk.setSlot("isa", value: "fact")
        for i in 0..<attributes.count {
            chunk.setSlot("slot\(i + 1)", value: attributes[i])
        }
        return chunk
    }
    
}