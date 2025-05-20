import SwiftUI
import AppKit

@main
struct AlayaNeWApp: App {
    @StateObject private var installationState = InstallationState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(installationState)
                .frame(width: 800, height: 460, alignment: .center)
                .onAppear {
                    // 将installationState引用传递给AppDelegate
                    (NSApplication.shared.delegate as? AppDelegate)?.setInstallationState(installationState)
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}

// 使用应用代理调整窗口大小
class AppDelegate: NSObject, NSApplicationDelegate {
    // 使用弱引用避免引用循环
    private weak var _installationState: InstallationState?
    
    // 保存应用最小化前的状态
    private var savedState: [String: Any]?
    
    func setInstallationState(_ state: InstallationState) {
        _installationState = state
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            // 设置窗口固定尺寸
            window.setContentSize(NSSize(width: 800, height: 460))
            
            // 禁止改变窗口大小
            window.styleMask.remove(.resizable)
            
            // 将窗口居中显示
            window.center()
        }
    }
    
    // 应用失去焦点（包括最小化）
    func applicationDidResignActive(_ notification: Notification) {
        guard let state = _installationState else { return }
        
        // 保存当前状态
        savedState = [
            "currentStep": state.currentStep.rawValue,
            "kubeconfigPath": state.kubeconfigPath,
            "kubeconfigDisplayPath": state.kubeconfigDisplayPath,
            "installDevtron": state.installDevtron,
            "installationProgress": state.installationProgress,
            "isInstalling": state.isInstalling
        ]
    }
    
    // 应用获得焦点（从最小化恢复）
    func applicationDidBecomeActive(_ notification: Notification) {
        guard let state = _installationState, let savedState = self.savedState else { return }
        
        // 确保不会干扰正在进行的安装
        if !state.isInstalling {
            // 恢复保存的状态
            if let stepRawValue = savedState["currentStep"] as? Int,
               let step = InstallationStep(rawValue: stepRawValue) {
                state.currentStep = step
            }
            
            if let kubeconfigPath = savedState["kubeconfigPath"] as? String,
               let kubeconfigDisplayPath = savedState["kubeconfigDisplayPath"] as? String {
                // 使用setKubeconfigPath方法同时设置两个路径
                state.setKubeconfigPath(kubeconfigPath, displayPath: kubeconfigDisplayPath)
            }
            
            if let installDevtron = savedState["installDevtron"] as? Bool {
                state.installDevtron = installDevtron
            }
        }
    }
} 
