//
//  Avatar.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 06/05/26.
//

import SwiftUI

struct Avatar: View {
    var imageURL: String?
    var initials: String = "?"
    var size: CGFloat = 80
    
    var body: some View {
        ZStack {
            if let urlString = imageURL,
               let url = URL(string: urlString) {
                
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    placeholderView
                }
                
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(Color.white, lineWidth: 2)
        )
        .shadow(
            color: Color(hex: "76B7B7").opacity(0.10),
            radius: 1.5,
            x: 0,
            y: 1
        )
    }
    
    var placeholderView: some View {
        ZStack {
            Color.white.opacity(0.6)
            
            Text(initials)
                .font(.system(size: size * 0.35, weight: .bold))
                .foregroundColor(Color.soulaceAccent)
        }
    }
}
