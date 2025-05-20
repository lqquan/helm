import SwiftUI
import UniformTypeIdentifiers

struct KubeconfigSelectionView: View {
    @EnvironmentObject private var installationState: InstallationState
    @State private var isFilePickerPresented = false
    @State private var isValidating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 标题和说明
            VStack(alignment: .leading, spacing: 8) {
                Text("选择Kubeconfig文件")
                    .font(.system(size: 20, weight: .medium))
                
                Text("请选择有效的Kubeconfig文件，以便连接到您的Kubernetes集群")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            // 内容区域 - 使用固定高度的ScrollView容器
            ScrollView {
                if installationState.kubeconfigPath.isEmpty {
                    // 空白状态 - 显示居中的浏览按钮
                    VStack(spacing: 20) {
                        Spacer()
                        
                        VStack(spacing: 15) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(.blue.opacity(0.7))
                            
                            Text("请选择Kubeconfig文件")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                isFilePickerPresented = true
                            }) {
                                HStack {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.system(size: 13))
                                    Text("浏览文件")
                                        .font(.system(size: 13))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                openURL("https://www.alayanew.com/backend/register?id=AlayaNeWmac")
                            }) {
                                HStack(spacing: 4) {
                                    Text("没有账号？")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    
                                    Text("点击注册")
                                        .font(.system(size: 12))
                                        .foregroundColor(.blue)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.top, 10)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Spacer()
                    }
                    .frame(minHeight: 250)
                } else {
                    // 已选择文件 - 显示文件路径
                    VStack(alignment: .leading, spacing: 20) {
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("已选择文件")
                                .font(.system(size: 14, weight: .medium))
                            
                            HStack {
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(URL(fileURLWithPath: installationState.kubeconfigDisplayPath).lastPathComponent)
                                        .font(.system(size: 13, weight: .medium))
                                    
                                    Text(installationState.kubeconfigDisplayPath)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    installationState.setKubeconfigPath("", displayPath: "")
                                }) {
                                    Text("更换文件")
                                        .font(.system(size: 12))
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(12)
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(8)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Spacer()
                    }
                    .frame(minHeight: 250)
                }
            }
            
            Spacer()
            
            // 导航按钮 - 使用固定高度和边距
            HStack {
                Spacer()
                
                Button(action: {
                    if !installationState.kubeconfigPath.isEmpty {
                        isValidating = true
                        validateKubeconfigFile()
                    }
                }) {
                    if isValidating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                    } else {
                        Text("下一步")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .disabled(installationState.kubeconfigPath.isEmpty || isValidating)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(installationState.kubeconfigPath.isEmpty || isValidating ? Color.gray.opacity(0.3) : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .frame(height: 36)
        }
        .padding(30)
        .onChange(of: isFilePickerPresented) { newValue in
            if newValue {
                // 使用自定义的文件选择器替代fileImporter
                presentCustomFilePicker()
            }
        }
    }
    
    private func presentCustomFilePicker() {
        let openPanel = NSOpenPanel()
        openPanel.title = "选择Kubeconfig文件"
        openPanel.message = "请选择您的Kubeconfig配置文件"
        openPanel.showsResizeIndicator = true
        openPanel.showsHiddenFiles = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.yaml, .text]
        
        // 设置居中显示
        openPanel.center()
        
        // 设置合适的尺寸
        openPanel.setFrameOrigin(NSPoint(x: (NSScreen.main?.frame.width ?? 800) / 2 - 300, y: (NSScreen.main?.frame.height ?? 600) / 2 - 200))
        openPanel.setContentSize(NSSize(width: 600, height: 400))
        
        // 显示面板
        DispatchQueue.main.async {
            isFilePickerPresented = false // 重置状态
            
            let response = openPanel.runModal()
            if response == .OK, let fileURL = openPanel.url {
                // 处理所选文件 - 使用新的setKubeconfigPath方法
                installationState.setKubeconfigPath(fileURL.path, displayPath: fileURL.path)
                installationState.appendLog("用户选择了Kubeconfig文件: \(fileURL.lastPathComponent)")
            }
        }
    }
    
    private func validateKubeconfigFile() {
        // 模拟验证过程
        installationState.appendLog("开始验证Kubeconfig文件: \(URL(fileURLWithPath: installationState.kubeconfigPath).lastPathComponent)")
        
        DispatchQueue.global().async {
            let filePath = installationState.kubeconfigPath
            
            // 从文件读取内容
            do {
                installationState.appendLog("读取Kubeconfig文件内容...")
                let originalContent = try String(contentsOfFile: filePath, encoding: .utf8)
                
                // 定义kubeconfig关键字
                let kubeconfigKeywords = ["apiVersion", "kind", "clusters", "contexts", "current-context"]
                
                // 检查原始内容是否包含关键字
                var originalMatchCount = 0
                for keyword in kubeconfigKeywords {
                    if originalContent.contains(keyword) {
                        originalMatchCount += 1
                    }
                }
                
                //installationState.appendLog("原始文件包含 \(originalMatchCount)/\(kubeconfigKeywords.count) 个kubeconfig关键字")
                
                // 尝试解码
                var fileContent = originalContent
                var usedDecodedFile = false
                var tempFilePath: URL? = nil
                
                // 如果原始文件不包含足够的关键字，尝试base64解码
                if originalMatchCount < 3 {
                    installationState.appendLog("尝试解码文件内容...")
                    if let decodedContent = ShellUtils.decodeBase64(originalContent.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        // 计算解码内容包含的关键字数量
                        var decodedMatchCount = 0
                        for keyword in kubeconfigKeywords {
                            if decodedContent.contains(keyword) {
                                decodedMatchCount += 1
                            }
                        }
                        
                        //installationState.appendLog("解码后内容包含 \(decodedMatchCount)/\(kubeconfigKeywords.count) 个kubeconfig关键字")
                        
                        // 如果解码后的内容包含更多关键字，使用解码内容
                        if decodedMatchCount > originalMatchCount {
                            fileContent = decodedContent
                            usedDecodedFile = true
                            installationState.appendLog("检测到Base64编码的kubeconfig文件，解码成功")
                            
                            // 将解码后的内容保存到临时文件，统一命名为kubeconfig
                            let tempDir = FileManager.default.temporaryDirectory
                            tempFilePath = tempDir.appendingPathComponent("kubeconfig")
                            
                            do {
                                // 如果临时文件已存在，先删除
                                let fileManager = FileManager.default
                                if fileManager.fileExists(atPath: tempFilePath!.path) {
                                    try fileManager.removeItem(at: tempFilePath!)
                                }
                                
                                try fileContent.write(to: tempFilePath!, atomically: true, encoding: .utf8)
                                installationState.appendLog("已自动解码kubeconfig文件") // 不显示具体路径
                                
                                // 更新kubeconfigPath为解码后的文件路径，但保留原始显示路径
                                DispatchQueue.main.async {
                                    // 保留原始显示路径，仅更新实际路径
                                    let displayPath = installationState.kubeconfigDisplayPath
                                    installationState.setKubeconfigPath(tempFilePath!.path, displayPath: displayPath)
                                }
                            } catch {
                                installationState.appendLog("保存解码后的kubeconfig文件失败: \(error.localizedDescription)")
                                // 失败但继续使用原始解码内容进行验证
                            }
                        } else {
                            installationState.appendLog("解码后内容不是有效的kubeconfig格式，使用原始文件内容")
                        }
                    } else {
                        installationState.appendLog("Base64解码失败或内容不是Base64格式，使用原始文件内容")
                    }
                }
                
                // 记录文件大小
                let fileSize = fileContent.count
                installationState.appendLog("Kubeconfig文件大小: \(fileSize) 字节")
                
                // 简单验证Kubeconfig必要字段
                installationState.appendLog("检查Kubeconfig必要字段: \(kubeconfigKeywords.joined(separator: ", "))")
                
                var missingFields: [String] = []
                var foundFields: [String] = []
                
                for field in kubeconfigKeywords {
                    if fileContent.contains(field) {
                        foundFields.append(field)
                    } else {
                        missingFields.append(field)
                    }
                }
                
                let isValid = missingFields.isEmpty || foundFields.count >= 3
                
                // 记录验证结果
                if !foundFields.isEmpty {
                    //installationState.appendLog("找到字段: \(foundFields.joined(separator: ", "))")
                }
                
                if !missingFields.isEmpty {
                    installationState.appendLog("缺少字段: \(missingFields.joined(separator: ", "))")
                }
                
                // 尝试解析集群信息
                // 尝试解析集群信息
                if fileContent.contains("clusters:") {
                    if let clustersRange = fileContent.range(of: "clusters:") {
                        let clustersContent = fileContent[clustersRange.upperBound...]
                        
                        // 方法 1: 使用 String 的 `components(separatedBy:)`（最简单，无版本限制）
                        if let nameLine = clustersContent.components(separatedBy: .newlines)
                            .first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("name:") }) {
                            let clusterName = nameLine.replacingOccurrences(of: "name:", with: "").trimmingCharacters(in: .whitespaces)
                            installationState.appendLog("检测到集群名称: \(clusterName)")
                        }
                        
                        // 方法 2: 使用 NSRegularExpression（兼容 macOS 10.15+）
                        /*
                        let pattern = #"name:\s*([^\n]+)"#
                        if let regex = try? NSRegularExpression(pattern: pattern),
                           let match = regex.firstMatch(
                               in: String(clustersContent),
                               range: NSRange(location: 0, length: clustersContent.utf16.count)
                           ),
                           let range = Range(match.range(at: 1),
                           let clusterName = String(clustersContent).substring(with: range) {
                            installationState.appendLog("检测到集群名称: \(clusterName)")
                        }
                        */
                    }
                }
                
                DispatchQueue.main.async {
                    isValidating = false
                    
                    if isValid {
                        installationState.appendLog("Kubeconfig文件验证成功 ✓")
                        // 不再显示是否使用了解码文件的信息
                        installationState.moveToNextStep()
                    } else {
                        installationState.showError("无效的Kubeconfig文件。请确保包含所有必要字段: \(missingFields.joined(separator: ", "))。")
                    }
                }
            } catch {
                installationState.appendLog("读取Kubeconfig文件失败: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    isValidating = false
                    installationState.showError("无法读取Kubeconfig文件: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

// 为YAML文件添加UTType支持
// 添加兼容性检查，支持iOS 14/macOS 11之前的系统
#if os(macOS)
// UTType.yaml已在其他地方定义，不需要在这里重复声明
#else
// 对于不支持UTType的旧系统，提供CFString标识符替代方案
extension KubeconfigSelectionView {
    // 定义YAML文件类型标识符
    static let yamlUTI = "public.yaml" as CFString
    static let ymlUTI = "public.yml" as CFString
    static let textUTI = "public.plain-text" as CFString
    
    // 获取文件类型数组
    func getFileContentTypes() -> [Any] {
        return [Self.yamlUTI, Self.ymlUTI, Self.textUTI]
    }
}
#endif
