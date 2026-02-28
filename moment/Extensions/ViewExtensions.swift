//
//  ViewExtensions.swift
//  moment
//
//  Created by wen li on 2026/1/4.
//

import SwiftUI

// MARK: - View Extensions

extension View {
    func hideTabBar() -> some View {
        self
            .toolbar(.hidden, for: .tabBar)
    }
    
    func showTabBar() -> some View {
        self
            .toolbar(.visible, for: .tabBar)
    }
}
