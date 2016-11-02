//
//  FSConfiguration.swift
//  Fusuma
//
//  Created by Sacha Durand Saint Omer on 24/10/16.
//  Copyright © 2016 ytakzk. All rights reserved.
//

import Foundation

public var fusumaBaseTintColor   = UIColor(r: 204, g: 204, b: 204)
public var fusumaCropImage: Bool = true


func fsLocalized(_ str: String) -> String {
    return NSLocalizedString(str,
                             tableName: nil,
                             bundle: Bundle(for:FusumaVC.self),
                             value: "",
                             comment: "")
}
