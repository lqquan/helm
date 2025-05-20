import SwiftUI
import AppKit
// KeychainAccess模块未找到，使用内置的钥匙串管理

// 内置的钥匙串服务类，替代外部KeychainAccess库
class KeychainManager {
    static let shared = KeychainManager()
    private let serviceName: String
    
    init(service: String = "com.alaya.newtools") {
        self.serviceName = service
    }
    
    func set(_ value: String, key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        
        // 查询钥匙串中是否已存在该项
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        // 如果已存在，先删除
        SecItemDelete(query as CFDictionary)
        
        // 添加新项
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            throw KeychainError.addFailed(status: status)
        }
    }
    
    func get(_ key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.getFailed(status: status)
        }
        
        guard let data = item as? Data, let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }
        
        return string
    }
    
    func delete(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.deleteFailed(status: status)
        }
    }
    
    enum KeychainError: Error {
        case encodingFailed
        case decodingFailed
        case addFailed(status: OSStatus)
        case getFailed(status: OSStatus)
        case deleteFailed(status: OSStatus)
    }
}

// 为了兼容原代码，创建一个Keychain类模拟KeychainAccess库的API
class Keychain {
    private let keychainManager: KeychainManager
    
    init(service: String) {
        self.keychainManager = KeychainManager(service: service)
    }
    
    func set(_ value: String, key: String) throws {
        try keychainManager.set(value, key: key)
    }
    
    func get(_ key: String) throws -> String? {
        return try keychainManager.get(key)
    }
    
    func remove(_ key: String) throws {
        try keychainManager.delete(key)
    }
}

struct CompletionView: View {
    @EnvironmentObject private var installationState: InstallationState
    @State private var showSuccessAnimation = true
    @State private var isPasswordVisible = false
    @State private var showSaveAlert = false
    @State private var showingLogViewer = false
    
    // 钥匙串
    private let keychain = Keychain(service: "com.alaya.newtools")
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题部分 - 固定在顶部
            VStack(alignment: .leading, spacing: 8) {
                Text("安装完成")
                    .font(.system(size: 20, weight: .medium))
                
                if !installationState.installationComplete {
                    Text("安装未能完全完成，部分功能可能不可用")
                        .font(.system(size: 13))
                        .foregroundColor(.orange)
                } else {
                    Text(installationState.installDevtron ? "Devtron和Kubernetes工具已安装配置完成" : "Kubernetes工具已完成配置")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 16)
            
            // 中间内容区域 - 可滚动
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 显示安装状态警告 - 仅在安装不完整时显示
                    if !installationState.installationComplete && installationState.installDevtron {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                                
                                Text("安装超时提醒")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.orange)
                                
                                Spacer()
                            }
                            
                            Text("Devtron服务启动超时，访问凭证可能不完整或不可用。您可以：")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("• 稍后手动检查服务状态")
                                Text("• 查看安装日志了解详细信息")
                                Text("• 如需重新安装，请重启应用")
                            }
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        }
                        .padding(14)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                    }
                
                    // 1. Devtron访问信息区 - 仅在安装了Devtron且安装完整时显示完整信息
                    if installationState.installDevtron {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("访问信息")
                                .font(.system(size: 14, weight: .medium))
                            
                            VStack(spacing: 6) {
                                if installationState.installationComplete {
                                    CompletionInfoRow(label: "地址", value: installationState.devtronUrl, showCopy: true, showOpen: true)
                                    CompletionInfoRow(label: "用户名", value: installationState.devtronUsername, showCopy: true)
                                    
                                    HStack(alignment: .center) {
                                        Text("密码")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                            .frame(width: 60, alignment: .leading)
                                        
                                        if isPasswordVisible {
                                            Text(installationState.devtronPassword)
                                                .font(.system(size: 12))
                                        } else {
                                            Text("••••••")
                                                .font(.system(size: 12))
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: { isPasswordVisible.toggle() }) {
                                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                                .font(.system(size: 11))
                                                .foregroundColor(.gray)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        
                                        Button(action: { copyToClipboard(installationState.devtronPassword) }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 11))
                                                .foregroundColor(.gray)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    .padding(.vertical, 2)
                                } else {
                                    Text("服务启动超时，无法获取完整访问信息")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(10)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .padding(12)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(6)
                        
                        // 安全提示 - 简化为一行，只在安装完整时显示
                        if installationState.installationComplete {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                                
                                Text("请妥善保存访问信息，丢失后需要重新安装才能恢复")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                            .padding(.top, 4)
                        }
                    }
                    
                    // 2. 命令行环境配置 - 简化为一行显示
                    VStack(alignment: .leading, spacing: 10) {
                        Text("配置命令行环境")
                            .font(.system(size: 14, weight: .medium))
                        
                        // 系统权限提示
                        Text("因macOS系统权限限制，需在终端中执行以下命令以使用kubectl和helm工具：")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        let toolsPath = Bundle.main.bundlePath + "/Contents/Resources/tools"
                        let scriptCommand = "sudo cp \"\(toolsPath)/kubectl\" \"\(toolsPath)/helm\" /usr/local/bin/ && mkdir -p ~/.kube && cp \"\(installationState.kubeconfigPath)\" ~/.kube/config"
                        
                        HStack {
                            Text(scriptCommand)
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            Spacer()
                            
                            Button(action: {
                                copyToClipboard(scriptCommand)
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(6)
                    }
                    .padding(12)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(6)
                    
                    // 3. 已安装工具显示 - 每行显示2个
                    VStack(alignment: .leading, spacing: 10) {
                        Text("已安装工具")
                            .font(.system(size: 14, weight: .medium))
                        
                        VStack(spacing: 8) {
                            // 第一行工具
                            HStack(spacing: 16) {
                                InstalledToolRow(name: "Kubectl", version: "已安装")
                                    .frame(maxWidth: .infinity)
                                
                                InstalledToolRow(name: "Helm", version: "已安装")
                                    .frame(maxWidth: .infinity)
                            }
                            
                            // 第二行工具
                            HStack(spacing: 16) {
                                InstalledToolRow(name: "Kubeconfig", version: "已配置")
                                    .frame(maxWidth: .infinity)
                                
                                if installationState.installDevtron {
                                    InstalledToolRow(
                                        name: "Devtron",
                                        version: installationState.installationComplete ? "已安装" : "安装中断",
                                        showWarning: !installationState.installationComplete
                                    )
                                    .frame(maxWidth: .infinity)
                                } else {
                                    Spacer()
                                        .frame(maxWidth: .infinity)
                                }
                                
                                
                            }
                        }
                        .padding(12)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(6)
                    }
                    
                    // 4. 查看安装日志按钮
                    Button(action: {
                        showingLogViewer = true
                    }) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 12))
                            
                            Text("查看安装日志")
                                .font(.system(size: 13))
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 安装时间信息
                    if installationState.installationTime > 0 {
                        HStack {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            Text("安装用时: \(formatTime(installationState.installationTime))")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                    
                    // 添加底部空间，确保滚动视图中的所有内容都能完整显示（考虑到底部固定按钮的高度）
                    Spacer(minLength: 24)
                }
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            
            Spacer(minLength: 16)
            
            // 底部固定按钮区域 - 使用与下一步按钮相同的样式和宽度
            HStack {
                Spacer()
                
                Button(action: {
                    // 仅在安装Devtron且安装完整时显示保存提示，否则直接退出
                    if installationState.installDevtron && installationState.installationComplete {
                        showSaveAlert = true
                    } else {
                        NSApplication.shared.terminate(nil)
                    }
                }) {
                    Text("完成")
                        .font(.system(size: 13, weight: .medium))
                        .frame(minWidth: 56) // 确保按钮宽度足够显示三个汉字
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .frame(height: 36)
        }
        .padding(30)
        .sheet(isPresented: $showingLogViewer) {
            LogViewerView(logs: installationState.logs)
        }
        .alert(isPresented: $showSaveAlert) {
            Alert(
                title: Text("保存访问信息"),
                message: Text("访问信息丢失后需要重新安装才能恢复。现在要复制这些信息到剪贴板吗？"),
                primaryButton: .default(Text("复制信息")) {
                    copyAllInfo()
                },
                secondaryButton: .default(Text("直接完成")) {
                    saveToKeychain()
                    NSApplication.shared.terminate(nil)
                }
            )
        }
    }
    
    // 复制所有信息到剪贴板
    private func copyAllInfo() {
        let infoText = """
        Devtron访问信息:
        地址: \(installationState.devtronUrl)
        用户名: \(installationState.devtronUsername)
        密码: \(installationState.devtronPassword)
        
        请妥善保管此信息，这些信息丢失后需要重新安装才能恢复。
        """
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(infoText, forType: .string)
        
        // 简化通知
        let notification = NSUserNotification()
        notification.title = "已复制所有访问信息"
        NSUserNotificationCenter.default.deliver(notification)
        
        // 复制完成后保存并退出
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            saveToKeychain()
            NSApplication.shared.terminate(nil)
        }
    }
    
    // 实用函数
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // 简化通知
        let notification = NSUserNotification()
        notification.title = "已复制"
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    private func saveToKeychain() {
        do {
            try keychain.set(installationState.devtronUrl, key: "devtronUrl")
            try keychain.set(installationState.devtronUsername, key: "devtronUsername")
            try keychain.set(installationState.devtronPassword, key: "devtronPassword")
            
            let notification = NSUserNotification()
            notification.title = "已保存"
            NSUserNotificationCenter.default.deliver(notification)
        } catch {
            print("保存到钥匙串失败: \(error)")
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d分%d秒", minutes, seconds)
    }
}

// 已安装工具显示组件
struct InstalledToolRow: View {
    let name: String
    let version: String
    var showWarning: Bool = false
    
    var body: some View {
        HStack {
            if name == "Kubectl" || name == "Helm" || name == "Devtron" {
                Text(name.prefix(1).uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .background(Color.gray.opacity(0.8))
                    .cornerRadius(3)
            } else {
                Image(systemName: "doc.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .frame(width: 16, height: 16)
            }
            
            Text(name)
                .font(.system(size: 11))
                .frame(width: 90, alignment: .leading)
            
            Spacer()
            
            HStack {
                if showWarning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                }
                
                Text(version)
                    .font(.system(size: 11))
                    .foregroundColor(showWarning ? .orange : .green)
            }
        }
    }
}

struct CompletionInfoRow: View {
    let label: String
    let value: String
    var showCopy: Bool = false
    var showOpen: Bool = false
    
    var body: some View {
        HStack(alignment: .center) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Text(value)
                .font(.system(size: 12, design: label == "地址" ? .monospaced : .default))
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            if showCopy {
                Button(action: { copyToClipboard(value) }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if showOpen {
                Button(action: { openURL(value) }) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 2)
    }
    
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

// 日志查看器视图
struct LogViewerView: View {
    let logs: String
    @Environment(\.presentationMode) private var presentationMode
    @State private var searchText = ""
    @State private var selectedLogLevel: LogLevel = .all
    
    enum LogLevel: String, CaseIterable, Identifiable {
        case all = "全部"
        case info = "信息"
        case error = "错误"
        case command = "命令"
        case result = "结果"
        
        var id: String { self.rawValue }
    }
    
    var filteredLogs: String {
        if searchText.isEmpty && selectedLogLevel == .all {
            return logs
        }
        
        let lines = logs.split(separator: "\n")
        let filteredLines = lines.filter { line in
            let lineString = String(line)
            let matchesSearch = searchText.isEmpty || lineString.lowercased().contains(searchText.lowercased())
            let matchesLevel: Bool
            
            switch selectedLogLevel {
            case .all:
                matchesLevel = true
            case .info:
                matchesLevel = !lineString.contains("错误") && !lineString.contains("命令") && !lineString.contains(">>") && !lineString.contains("!!")
            case .error:
                matchesLevel = lineString.contains("错误") || lineString.contains("失败") || lineString.contains("!!")
            case .command:
                matchesLevel = lineString.contains("执行命令")
            case .result:
                matchesLevel = lineString.contains(">>") || lineString.contains("!!")
            }
            
            return matchesSearch && matchesLevel
        }
        
        return filteredLines.joined(separator: "\n")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("安装日志详情")
                    .font(.headline)
                
                Spacer()
                
                Button("关闭") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            
            HStack {
                TextField("搜索日志内容", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Picker("日志级别", selection: $selectedLogLevel) {
                    ForEach(LogLevel.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 300)
            }
            .padding()
            
            ScrollView {
                Text(filteredLogs)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            
            HStack {
//                Button(action: exportLogsFromViewer) {
//                    Label("导出日志", systemImage: "arrow.down.doc")
//                }
                
                Spacer()
                
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(filteredLogs, forType: .string)
                }) {
                    Label("复制到剪贴板", systemImage: "doc.on.doc")
                }
            }
            .padding()
        }
        .frame(width: 800, height: 600)
    }
    
    private func exportLogsFromViewer() {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "VKSTools.log"
        savePanel.allowedContentTypes = [.plainText]
        savePanel.canCreateDirectories = true
        
        savePanel.beginSheetModal(for: NSApp.keyWindow!) { response in
            if response == .OK, let targetURL = savePanel.url {
                do {
                    try filteredLogs.write(to: targetURL, atomically: true, encoding: .utf8)
                } catch {
                    print("导出日志失败: \(error.localizedDescription)")
                }
            }
        }
    }
}

