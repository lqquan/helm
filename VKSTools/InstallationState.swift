import Foundation
import SwiftUI

enum InstallationStep: Int {
    case kubeconfigSelection = 0
    case devtronChoice = 1
    case installation = 2
    case waitingForServices = 3
    case completion = 4
}

class InstallationState: ObservableObject {
    @Published var currentStep: InstallationStep = .kubeconfigSelection
    @Published var kubeconfigPath: String = ""  // 实际文件路径（可能是解码后的路径）
    @Published var kubeconfigDisplayPath: String = ""  // 用于显示的路径（用户上传的原始路径）
    @Published var installDevtron: Bool = true
    @Published var installationProgress: Double = 0.0
    @Published var installationStartTime: Date?
    @Published var errorMessage: String?
    @Published var isShowingError: Bool = false
    @Published var isInstalling: Bool = false
    
    // Devtron相关信息
    @Published var devtronUrl: String = ""
    @Published var devtronUsername: String = "admin"
    @Published var devtronPassword: String = ""
    @Published var installationTime: TimeInterval = 0
    
    // 安装状态标记
    @Published var installationComplete: Bool = true
    
    // 日志相关
    @Published var logs: String = ""
    @Published var logFilePath: String = ""
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    init() {
        // 创建日志文件
        createLogFile()
    }
    
    // 设置Kubeconfig路径的方法，同时更新显示路径
    func setKubeconfigPath(_ path: String, displayPath: String? = nil) {
        kubeconfigPath = path
        // 如果未提供显示路径，则使用实际路径
        kubeconfigDisplayPath = displayPath ?? path
        appendLog("设置Kubeconfig路径")
    }
    
    func appendLog(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let logEntry = "[\(timestamp)] \(message)"
        
        DispatchQueue.main.async {
            self.logs += logEntry + "\n"
            // 写入日志文件
            self.writeToLogFile(logEntry)
        }
    }
    
    private func createLogFile() {
        let fileManager = FileManager.default
        
        // 统一使用标准日志目录路径
        let logDirectory: URL
        
        // 检查是否在沙箱环境中运行
        let homeDir = NSHomeDirectory()
        let isSandboxed = homeDir.contains("Library/Containers")
        
        if isSandboxed {
            // 沙箱应用使用Library/Logs目录
            logDirectory = URL(fileURLWithPath: "\(homeDir)/Library/Logs/VKSTools")
        } else {
            // 非沙箱应用使用用户级别的日志目录
            let libraryDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
            logDirectory = libraryDirectory.appendingPathComponent("Logs/VKSTools")
        }
        
        do {
            // 创建日志目录
            if !fileManager.fileExists(atPath: logDirectory.path) {
                try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
            }
            
            // 创建唯一的日志文件名
         
            let logFileName = "devtron_install.log"
            let logFileURL = logDirectory.appendingPathComponent(logFileName)
            
            // 创建空日志文件
            if !fileManager.fileExists(atPath: logFileURL.path) {
                fileManager.createFile(atPath: logFileURL.path, contents: nil)
            }
            
            logFilePath = logFileURL.path
            appendLog("=== VKSTools 安装日志 ===")
            appendLog("日志文件位置: \(logFilePath)")
            appendLog("安装会话开始")
        } catch {
            print("创建日志文件失败: \(error.localizedDescription)")
        }
    }
    
    private func writeToLogFile(_ logEntry: String) {
        guard !logFilePath.isEmpty else { return }
        
        do {
            let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: logFilePath))
            fileHandle.seekToEndOfFile()
            if let data = (logEntry + "\n").data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        } catch {
            print("写入日志文件失败: \(error.localizedDescription)")
        }
    }
    
    func exportLogs() -> URL? {
        guard !logFilePath.isEmpty, FileManager.default.fileExists(atPath: logFilePath) else {
            return nil
        }
        return URL(fileURLWithPath: logFilePath)
    }
    
    func resetState() {
        kubeconfigPath = ""
        kubeconfigDisplayPath = ""
        installDevtron = true
        installationProgress = 0.0
        installationStartTime = nil
        errorMessage = nil
        isShowingError = false
        isInstalling = false
        devtronUrl = ""
        devtronPassword = ""
        // 不清除日志，而是记录新的会话开始
        appendLog("=== 新安装会话开始 ===")
    }
    
    func showError(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.isShowingError = true
            self.appendLog("错误: \(message)")
        }
    }
    
    func moveToNextStep() {
        DispatchQueue.main.async {
            switch self.currentStep {
            case .kubeconfigSelection:
                self.appendLog("进入步骤: 选择是否安装Devtron")
                self.currentStep = .devtronChoice
            case .devtronChoice:
                self.appendLog("进入步骤: 开始安装过程")
                self.currentStep = .installation
                self.installationStartTime = Date()
                self.isInstalling = true
            case .installation:
                // 如果不安装Devtron，直接跳转到完成页面
                if !self.installDevtron {
                    self.appendLog("未安装Devtron，跳过等待服务启动步骤")
                    self.currentStep = .completion
                    self.isInstalling = false
                    if let startTime = self.installationStartTime {
                        self.installationTime = Date().timeIntervalSince(startTime)
                        self.appendLog("总安装时间: \(self.formatTime(self.installationTime))")
                    }
                } else {
                    self.appendLog("进入步骤: 等待服务启动")
                    self.currentStep = .waitingForServices
                }
            case .waitingForServices:
                self.appendLog("进入步骤: 安装完成")
                self.currentStep = .completion
                self.isInstalling = false
                if let startTime = self.installationStartTime {
                    self.installationTime = Date().timeIntervalSince(startTime)
                    self.appendLog("总安装时间: \(self.formatTime(self.installationTime))")
                }
            case .completion:
                self.resetState()
                self.currentStep = .kubeconfigSelection
            }
        }
    }
    
    func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d分%d秒", minutes, seconds)
    }
}
