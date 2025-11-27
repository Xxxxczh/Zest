//
//  LaunchService.swift
//  Zest
//
//  Created by Claude on 2025-11-26.
//

import ServiceManagement
import SwiftUI

final class LaunchService {
    static let shared = LaunchService()
    
    private init() {}
    
    func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled {
                    print("✅ 应用已配置为登录启动")
                    return
                }
                
                try SMAppService.mainApp.register()
                print("✅ 已启用登录时启动")
            } else {
                if SMAppService.mainApp.status == .notFound {
                    return
                }
                
                try SMAppService.mainApp.unregister()
                print("⏹️ 已禁用登录时启动")
            }
        } catch {
            print("⚠️ 更改启动设置失败 (开发模式下通常不支持自启): \(error.localizedDescription)")
        }
    }
    
    func isLaunchAtLoginEnabled() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }
}
