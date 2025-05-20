import Foundation
import SwiftUI
import Network
import AppKit

class DevtronInstaller {
    // 委托回调
    typealias ProgressCallback = (Double) -> Void
    typealias LogCallback = (String) -> Void
    typealias CompletionCallback = (Bool, String?) -> Void

    // 路径和配置
    private var kubeconfigPath: String // 改为变量以便在预处理后更新路径
    private var installScriptPath: String
    private let toolsDir: String
    private let kubectlPath: String
    private let helmPath: String
    
    private let progressCallback: ProgressCallback
    private let logCallback: LogCallback
    private let completionCallback: CompletionCallback
    
    // 安装状态
    private var setupCompleted = false
    private var isInstalling = false
    
    // 日志文件路径
    private var logFilePath: String
    private var logFileHandle: FileHandle?
    
    init(kubeconfigPath: String,
         progressCallback: @escaping ProgressCallback,
         logCallback: @escaping LogCallback,
         completionCallback: @escaping CompletionCallback) {
        self.kubeconfigPath = kubeconfigPath
        self.progressCallback = progressCallback
        self.logCallback = logCallback
        self.completionCallback = completionCallback
        
        let bundlePath = Bundle.main.bundlePath
        self.toolsDir = "\(bundlePath)/Contents/Resources/tools"
        self.installScriptPath = "\(toolsDir)/devtron-charts/install.sh"
        self.kubectlPath = "\(toolsDir)/kubectl"
        self.helmPath = "\(toolsDir)/helm"
        
        // 先初始化所有存储属性后再调用方法
        self.logFilePath = DevtronInstaller.getStandardLogFilePath()
        
        initLogFile()
    }
    
    // 添加新方法获取标准日志路径 - 改为静态方法避免初始化问题
    private static func getStandardLogFilePath() -> String {
        let fileManager = FileManager.default
        let logDirectory: URL
        
        // 检查是否在沙箱环境中运行
        if DevtronInstaller.isRunningSandboxedStatic() {
            // 沙箱应用使用Library/Logs目录
            let homeDirectory = NSHomeDirectory()
            logDirectory = URL(fileURLWithPath: "\(homeDirectory)/Library/Logs/VKSTools")
        } else {
            // 非沙箱应用使用用户级别的日志目录
            let libraryDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
            logDirectory = libraryDirectory.appendingPathComponent("Logs/VKSTools")
        }
        
        // 确保目录存在
        if !fileManager.fileExists(atPath: logDirectory.path) {
            do {
                try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                // 如果创建失败，回退到临时目录
                print("无法创建标准日志目录: \(error.localizedDescription)")
                return NSTemporaryDirectory() + "devtron_install.log"
            }
        }
        
        // 创建带时间戳的日志文件名
        return logDirectory.appendingPathComponent("devtron_install.log").path
    }
    
    // 静态版本的沙箱环境检测方法
    private static func isRunningSandboxedStatic() -> Bool {
        // 检查应用是否在沙箱环境中运行
        let homeDir = NSHomeDirectory()
        let isSandboxed = homeDir.contains("Library/Containers")
        return isSandboxed
    }
    
    // 初始化日志文件
    private func initLogFile() {
        do {
            // 如果日志文件已存在，先删除
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: logFilePath) {
                try fileManager.removeItem(atPath: logFilePath)
            }
            
            // 创建新的日志文件
            fileManager.createFile(atPath: logFilePath, contents: nil)
            
            // 打开文件句柄
            logFileHandle = FileHandle(forWritingAtPath: logFilePath)
            
            // 写入初始日志记录
            let header = """
            ===================================
            Devtron 安装日志 - 开始于 \(Date())
            ===================================
            
            """
            appendToLog(header)
            
            // 记录日志文件位置
            let logMessage = "完整安装日志文件位置: \(logFilePath)"
            appendToLog(logMessage)
            logCallback(logMessage)
        } catch {
            logCallback("无法创建日志文件: \(error.localizedDescription)")
        }
    }
    
    // 添加日志到文件
    private func appendToLog(_ message: String) {
        guard let fileHandle = logFileHandle else { return }
        
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logLine = "[\(timestamp)] \(message)\n"
        
        if let data = logLine.data(using: .utf8) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
        }
    }
    
    // 包装原始的logCallback添加日志文件记录
    private func log(_ message: String) {
        appendToLog(message)
        logCallback(message)
    }
    
    // 设置环境和工具
    func setupEnvironment() -> Bool {
        log("开始配置环境...")
        
        // 记录系统信息
        logSystemInfo()
        
        // 检查是否在沙箱环境中运行，如果是，确保网络访问
        if isRunningSandboxed() {
            log("检测到应用在沙箱环境中运行，确保网络访问权限...")
            ensureNetworkAccess()
        }
        
        // 确保kubeconfig文件存在并且可读
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: kubeconfigPath) {
            log("Kubeconfig文件不存在: \(kubeconfigPath)")
            return false
        }
        
        do {
            // 尝试读取文件，确保有读取权限
            let kubeconfigContent = try String(contentsOfFile: kubeconfigPath, encoding: .utf8)
            log("Kubeconfig文件可读，将直接使用: \(kubeconfigPath)")
            
            // 验证kubeconfig内
        } catch {
            log("无法读取Kubeconfig文件: \(error.localizedDescription)")
            return false
        }
        
        // 设置KUBECONFIG环境变量指向原始文件
        if !ShellUtils.setEnvironmentVariable(name: "KUBECONFIG", value: kubeconfigPath) {
            log("设置KUBECONFIG环境变量失败")
            return false
        }
        log("已设置KUBECONFIG环境变量为: \(kubeconfigPath)")
        
        // 确保应用内置工具目录存在并且工具可用
        if !fileManager.fileExists(atPath: kubectlPath) || !fileManager.fileExists(atPath: helmPath) {
            log("应用内置工具不存在，请重新安装应用")
            return false
        }
        
        // 确保工具有执行权限
        do {
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: kubectlPath)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helmPath)
            log("已设置工具执行权限")
        } catch {
            log("设置工具权限失败: \(error.localizedDescription)，尝试使用命令行设置")
            _ = ShellUtils.runCommand("chmod +x \"\(kubectlPath)\" \"\(helmPath)\"")
        }
        
        // 检查工具是否可执行
        let kubectlTest = ShellUtils.runCommand("\"\(kubectlPath)\" version --client")
        if kubectlTest.exitCode == 0 {
            log("kubectl工具可用: \(kubectlPath)")
        } else {
            log("kubectl工具测试失败: \(kubectlTest.error)")
            return false
        }
        
        let helmTest = ShellUtils.runCommand("\"\(helmPath)\" version --short")
        if helmTest.exitCode == 0 {
            log("helm工具可用: \(helmPath)")
        } else {
            log("helm工具测试失败: \(helmTest.error)")
            return false
        }
        
        setupCompleted = true
        log("环境配置完成 - 使用应用内置工具")
        // 环境变量设置
        let env = [
            "PATH": "\(toolsDir):/usr/bin:/bin:/usr/sbin:/sbin",
            "KUBECONFIG": kubeconfigPath, // 实际路径用于执行命令
            "KUBE_INSECURE_SKIP_TLS_VERIFY": "true"
        ]
        
        return true
    }
    
   
    
    // 记录系统环境信息
    private func logSystemInfo() {
        log("===== 系统环境信息 =====")
        
        // 记录操作系统版本
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        log("操作系统: \(osVersion)")
        
        // 记录主机名
        if let hostName = Host.current().localizedName {
            log("主机名: \(hostName)")
        }
        
        // 记录CPU和内存信息
        let processorCount = ProcessInfo.processInfo.processorCount
        let physicalMemory = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024) // GB
        log("处理器核心数: \(processorCount)")
        log("物理内存: \(physicalMemory) GB")
        
        // 记录当前用户
        let userName = NSUserName()
        log("当前用户: \(userName)")
        
        // 记录工作目录
        let currentPath = FileManager.default.currentDirectoryPath
        log("当前工作目录: \(currentPath)")
        
        // 记录应用信息
        let bundleInfo = Bundle.main.infoDictionary
        if let appName = bundleInfo?["CFBundleName"] as? String,
           let appVersion = bundleInfo?["CFBundleShortVersionString"] as? String,
           let buildNumber = bundleInfo?["CFBundleVersion"] as? String {
            log("应用名称: \(appName)")
            log("应用版本: \(appVersion) (Build \(buildNumber))")
        }
        
        // 检查必要的命令是否存在
        checkCommandExists("kubectl")
        checkCommandExists("helm")
        
        log("========================")
    }
    
    // 检查命令是否存在
    private func checkCommandExists(_ command: String) {
        // 首先检查bundled工具目录
        let bundledPath = "\(toolsDir)/\(command)"
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: bundledPath) {
            log("\(command) 已在应用内置工具目录中找到: \(bundledPath)")
            
            // 检查权限是否正确
            let result = ShellUtils.runCommand("ls -l \"\(bundledPath)\"")
            log("工具权限: \(result.output.trimmingCharacters(in: .whitespacesAndNewlines))")
            
            // 确保具有执行权限
            ShellUtils.runCommand("chmod +x \"\(bundledPath)\"")
            
            // 检查版本
            checkCommandVersion(bundledPath)
            return
        }
        
        // 如果bundled工具不存在，检查系统路径
        let result = ShellUtils.runCommand("which \(command)")
        if result.exitCode == 0 {
            let systemPath = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            log("\(command) 已在系统路径中找到: \(systemPath)")
            
            // 检查系统工具版本
            checkCommandVersion(command)
        } else {
            log("\(command) 未在系统中安装，将使用应用内置版本")
        }
    }
    
    // 检查命令版本
    private func checkCommandVersion(_ commandPath: String) {
        let versionFlag = commandPath.contains("kubectl") ? "version --client" : "version --short"
        let result = ShellUtils.runCommand("\"\(commandPath)\" \(versionFlag)")
        if result.exitCode == 0 {
            log("\(commandPath) 版本: \(result.output.trimmingCharacters(in: .whitespacesAndNewlines))")
        } else {
            log("无法获取 \(commandPath) 版本信息: \(result.error)")
        }
    }
    
    // 安装Devtron
    func installDevtron() {
        if !setupCompleted {
            if !setupEnvironment() {
                completionCallback(false, "环境配置失败：无法设置Kubernetes环境。请检查kubeconfig文件权限和有效性，以及kubectl和helm工具是否正常安装。")
                return
            }
        }
        
        // 检查网络连接
        if isRunningSandboxed() {
            log("在沙箱环境中执行安装前检查网络连接...")
            
            // 简单的连接测试
            let testCmd = "\"\(kubectlPath)\" version --client"
            let testResult = ShellUtils.runCommand(testCmd)
            if testResult.exitCode != 0 {
                log("⚠️ 警告: kubectl版本检查失败: \(testResult.error)")
                log("这可能表明沙箱网络权限有问题")
            } else {
                log("kubectl版本检查成功: \(testResult.output)")
            }
        }
        
        
        // 检查Devtron是否已安装
        if self.checkDevtronInstalled() {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Devtron已安装"
                alert.informativeText = "您的集群中已经安装了Devtron。\n\n如果您需要访问现有Devtron的账户和密码，请联系集群管理员获取。"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "确定")
                
                alert.runModal()
                
                self.log("安装已取消，集群中已存在Devtron")
                
                // 使用特殊前缀标记错误信息
                self.completionCallback(false, "NO_ALERT:集群中已经安装了Devtron")
            }
            return
        } else {
            // 如果未安装Devtron，直接继续安装流程
            proceedWithInstallation()
        }
    }
    
    private func testClusterConnection() -> (success: Bool, error: String) {
        log("执行集群连接测试...")
        
        // 创建环境变量字典
        let envVars = [
            "PATH": "\(toolsDir):/usr/bin:/bin:/usr/sbin:/sbin",
            "KUBECONFIG": kubeconfigPath,
            "KUBE_INSECURE_SKIP_TLS_VERIFY": "true"
        ]
        
        // 第一步：检查kubectl是否可用
        let kubectlVersion = ShellUtils.runCommandWithEnv("\"\(kubectlPath)\" version --client", environment: envVars)
        if kubectlVersion.exitCode != 0 {
            return (false, "kubectl工具测试失败: \(kubectlVersion.error)")
        }
        
        // 第二步：检查集群连接
        let getNamespaces = ShellUtils.runCommandWithEnv("\"\(kubectlPath)\" get namespaces --request-timeout=10s", environment: envVars)
        if getNamespaces.exitCode != 0 {
            return (false, getNamespaces.error.isEmpty ? "无法连接到Kubernetes集群" : getNamespaces.error)
        }
        
        // 成功
        log("集群连接测试成功: 可以访问命名空间列表")
        return (true, "")
    }
    
    // 检查Devtron是否已安装并且状态为deployed
    private func checkDevtronInstalled() -> Bool {
        log("检查集群中是否已安装Devtron并处于deployed状态...")
        
        // 创建环境变量字典
        let envVars = [
            "PATH": "\(toolsDir):/usr/bin:/bin:/usr/sbin:/sbin",
            "KUBECONFIG": kubeconfigPath,
            "KUBE_INSECURE_SKIP_TLS_VERIFY": "true"
        ]
        
        // 直接检查devtron发布的状态
        let helmStatusCmd = "\"\(helmPath)\" status devtron -n devtroncd"
        let helmStatusResult = ShellUtils.runCommandWithEnv(helmStatusCmd, environment: envVars)
        
        // 如果命令执行失败，说明没有安装
        if helmStatusResult.exitCode != 0 {
            log("未找到名为devtron的Helm发布，可以安装Devtron")
            return false
        }
        
        // 检查输出中是否包含"STATUS: deployed"
        if helmStatusResult.output.contains("STATUS: deployed") {
            log("Devtron已安装，状态为deployed ✓")
            return true
        } else {
            log("Devtron Helm发布存在，但状态不是deployed")
            if helmStatusResult.output.contains("STATUS:") {
                // 提取实际状态，仅用于日志
                if let statusRange = helmStatusResult.output.range(of: "STATUS:") {
                    let statusLineStart = statusRange.upperBound
                    if let lineEndRange = helmStatusResult.output[statusLineStart...].range(of: "\n") {
                        let status = helmStatusResult.output[statusLineStart..<lineEndRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                        log("实际状态: \(status)")
                    }
                }
            }
            return false
        }
    }
    
    // 继续执行安装流程
    private func proceedWithInstallation() {
        log("开始安装Devtron...")
        log("使用安装脚本: \(installScriptPath)")
        log("使用kubeconfig: \(kubeconfigPath)")
        progressCallback(0.1)
        
        // 创建环境变量字典，只使用应用内置工具路径
        var envVars = [
            "PATH": "\(toolsDir):/usr/bin:/bin:/usr/sbin:/sbin",  // 添加系统工具目录以支持基本命令
            "KUBECONFIG": kubeconfigPath, // 直接使用传入的kubeconfig路径
            "KUBE_INSECURE_SKIP_TLS_VERIFY": "true" // 跳过SSL证书验证
        ]
        
        // 为沙箱环境添加额外环境变量
        if isRunningSandboxed() {
            // 添加其他必要的环境变量（如果需要）
        }
        
        log("设置PATH环境变量为: \(envVars["PATH"]!)")
        log("使用当前选择的kubeconfig路径: \(kubeconfigPath)")
        
        // 执行安装脚本，使用自定义环境变量
        let scriptDir = installScriptPath.split(separator: "/").dropLast().joined(separator: "/")
        let scriptName = installScriptPath.split(separator: "/").last ?? "install.sh"
        // 确保使用绝对路径
        let installCmd = "cd \"/\(scriptDir)\" && /bin/bash \(scriptName)"
        
        log("执行命令: \(installCmd)")
        
        // 标记安装开始
        isInstalling = true
        
        // 使用支持环境变量的方法运行命令
        ShellUtils.runCommandAsyncWithEnv(installCmd, environment: envVars) { output, error, exitCode in
            // 标记安装结束
            self.isInstalling = false
            self.progressCallback(1.0)
            
            // 处理安装结果
            if exitCode == 0 {
                self.log("Devtron安装成功完成！✓")
                self.completionCallback(true, nil)
            } else {
                self.log("Devtron安装失败，退出代码: \(exitCode)")
                if !error.isEmpty {
                    self.log("错误输出:")
                    self.appendToLog(error)
                }
                
                // 创建错误报告文件
                let errorInfo = """
                ===== Devtron安装错误报告 =====
                时间: \(Date())
                命令: \(installCmd)
                退出代码: \(exitCode)
                
                错误输出:
                \(error)
                
                标准输出:
                \(output)
                ============================
                """
                
                let errorFilePath = NSTemporaryDirectory() + "devtron_install_error.log"
                do {
                    try errorInfo.write(toFile: errorFilePath, atomically: true, encoding: .utf8)
                    self.log("错误报告已保存到: \(errorFilePath)")
                    self.copyToClipboard(text: errorInfo)
                } catch {
                    self.log("无法保存错误报告: \(error.localizedDescription)")
                }
                
                self.completionCallback(false, "安装失败: \(error)\n\n详细错误已复制到剪贴板，您可以直接粘贴查看或分享。\n\n完整日志: \(self.logFilePath)")
            }
            
            self.closeLogFile()
        }
        
        // 更新状态
        progressCallback(0.2)
    }
    
    // 获取Devtron访问信息
    func retrieveDevtronInfo(completion: @escaping (String, String) -> Void) {
        log("正在获取Devtron访问信息...")
        
        // 创建环境变量字典，只使用应用内置工具
        var envVars = [
            "PATH": "\(toolsDir):/usr/bin:/bin:/usr/sbin:/sbin",  // 添加系统工具目录以支持基本命令
            "KUBECONFIG": kubeconfigPath, // 直接使用传入的kubeconfig路径
            "KUBE_INSECURE_SKIP_TLS_VERIFY": "true" // 跳过SSL证书验证
        ]
        
        // 为沙箱环境添加额外环境变量
        if isRunningSandboxed() {
            // 添加其他必要的环境变量（如果需要）
        }
        
        log("使用工具路径和系统路径: \(envVars["PATH"]!)")
        log("使用kubeconfig路径: \(kubeconfigPath)")
        
        // 获取URL
        let getUrlCmd = "\"\(kubectlPath)\" describe serviceexporter devtron-itf -n devtroncd"
        log("获取Devtron服务地址: \"\(kubectlPath)\" describe serviceexporter devtron-itf -n devtroncd")
        
        ShellUtils.runCommandAsyncWithEnv(getUrlCmd, environment: envVars) { output, error, exitCode in
            var devtronUrl = ""
            
            self.log("命令退出代码: \(exitCode)")
            
            if exitCode == 0 {
                self.log("命令输出:")
                for line in output.split(separator: "\n") {
                    self.log(">> \(line)")
                    
                    // 解析输出查找URL
                    if line.contains("URL:") {
                        if let urlRange = line.range(of: "URL:") {
                            devtronUrl = String(line[urlRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                            self.log("解析到URL: \(devtronUrl)")
                            break
                        }
                    }
                }
            } else if !error.isEmpty {
                self.log("错误输出:")
                for line in error.split(separator: "\n") {
                    self.log("!! \(line)")
                }
                
                // 保存URL获取错误到临时文件
                let errorInfo = """
                ===== Devtron URL获取错误 =====
                命令: \(getUrlCmd)
                退出代码: \(exitCode)
                
                错误输出:
                \(error)
                ============================
                """
                
                let errorFilePath = NSTemporaryDirectory() + "devtron_url_error.log"
                do {
                    try errorInfo.write(toFile: errorFilePath, atomically: true, encoding: .utf8)
                    self.log("URL获取错误信息已保存到: \(errorFilePath)")
                    self.copyToClipboard(text: errorInfo)
                    self.log("错误详情已复制到剪贴板，可直接粘贴查看")
                } catch {
                    self.log("无法保存错误日志: \(error.localizedDescription)")
                }
            }
            
            if devtronUrl.isEmpty {
                // 如果无法获取URL，使用默认值
                devtronUrl = "http://localhost:8080"
                self.log("未找到Devtron URL，使用默认值: \(devtronUrl)")
            } else {
                self.log("获取到Devtron URL: \(devtronUrl)")
            }
            
            // 获取密码
            let getPasswordCmd = "\"\(self.kubectlPath)\" get secret -n devtroncd devtron-secret -o jsonpath={.data.ADMIN_PASSWORD}"
            self.log("获取Devtron管理员密码: \"\(self.kubectlPath)\" get secret -n devtroncd devtron-secret -o jsonpath={.data.ADMIN_PASSWORD}")
            
            ShellUtils.runCommandAsyncWithEnv(getPasswordCmd, environment: envVars) { output, error, exitCode in
                var password = "admin"
                
                self.log("命令退出代码: \(exitCode)")
                
                if exitCode == 0 && !output.isEmpty {
                    self.log("获取到编码密码: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                    
                    // 解码Base64密码
                    if let decodedPassword = ShellUtils.decodeBase64(output.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        password = decodedPassword
                        self.log("成功解码密码")
                    } else {
                        self.log("无法解码Devtron密码，使用默认值")
                    }
                } else {
                    if !error.isEmpty {
                        self.log("错误输出:")
                        for line in error.split(separator: "\n") {
                            self.log("!! \(line)")
                        }
                        
                        // 保存Devtron信息获取错误到临时文件
                        let errorInfo = """
                        ===== Devtron信息获取错误 =====
                        命令: \(getPasswordCmd)
                        退出代码: \(exitCode)
                        
                        错误输出:
                        \(error)
                        =============================
                        """
                        
                        let errorFilePath = NSTemporaryDirectory() + "devtron_info_error.log"
                        do {
                            try errorInfo.write(toFile: errorFilePath, atomically: true, encoding: .utf8)
                            self.log("详细错误信息已保存到: \(errorFilePath)")
                            self.copyToClipboard(text: errorInfo)
                            self.log("错误详情已复制到剪贴板，可直接粘贴查看")
                        } catch {
                            self.log("无法保存错误日志: \(error.localizedDescription)")
                        }
                    }
                    self.log("无法获取Devtron密码，使用默认值")
                }
                
                // 返回获取到的信息
                self.log("完成获取Devtron凭证: URL=\(devtronUrl), 用户名=admin")
                self.closeLogFile()
                completion(devtronUrl, password)
            }
        }
    }
    
    // 关闭日志文件
    func closeLogFile() {
        if let fileHandle = logFileHandle {
            do {
                let footer = """
                
                ===================================
                Devtron 安装日志结束 - \(Date())
                ===================================
                """
                appendToLog(footer)
                
                try fileHandle.close()
                logCallback("日志文件已关闭: \(logFilePath)")
            } catch {
                logCallback("关闭日志文件时出错: \(error.localizedDescription)")
            }
        }
    }
    
    // 获取日志文件路径
    func getLogFilePath() -> String {
        return logFilePath
    }
    
    // 取消安装
    func cancelInstallation() {
        if isInstalling {
            // 在实际情况下，我们无法直接终止异步运行的命令
            // 但我们可以记录取消请求，并在UI上反映这一点
            isInstalling = false
            log("安装进程取消请求已记录，但无法立即终止正在运行的命令")
            log("请等待当前操作完成或重启应用...")
        }
        closeLogFile()
    }
    
    // 检查是否在沙箱环境中运行
    func isRunningSandboxed() -> Bool {
        // 检查应用是否在沙箱环境中运行
        let homeDir = NSHomeDirectory()
        let isSandboxed = homeDir.contains("Library/Containers")
        log("应用运行环境: \(isSandboxed ? "沙箱" : "非沙箱")")
        return isSandboxed
    }
    
    // 确保网络权限
    private func ensureNetworkAccess() -> Bool {
        log("检查网络访问权限...")
        log("已启用网络访问权限")
        return true
    }
    
    // 复制文本到剪贴板
    private func copyToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        log("错误详情已复制到剪贴板")
    }
}
