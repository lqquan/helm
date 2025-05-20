import SwiftUI

struct DevtronChoiceView: View {
    @EnvironmentObject private var installationState: InstallationState
    @State private var isTesting: Bool = false
    @State private var testResult: TestResult?
    @State private var showTestFailAlert: Bool = false
    @State private var alertMessage: String = ""
    
    enum TestResult: Equatable {
        case success
        case failure(message: String)
        
        static func == (lhs: TestResult, rhs: TestResult) -> Bool {
            switch (lhs, rhs) {
            case (.success, .success):
                return true
            case (.failure(let lhsMessage), .failure(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    var body: some View {
        // 将视图分解为多个组件以减少复杂性
        VStack(alignment: .leading, spacing: 24) {
            // 标题部分
            headerView
            
            // 内容区域
            contentScrollView
            
            Spacer()
            
            // 导航按钮
            navigationButtonsView
        }
        .padding(30)
        .onAppear {
            // 重置测试状态，确保每次进入页面都是新的状态
            testResult = nil
        }
        .alert(isPresented: $showTestFailAlert) {
            Alert(
                title: Text("集群连接测试失败"),
                message: Text(alertMessage),
                primaryButton: .default(Text("我知道了")),
                secondaryButton: .cancel(Text("返回上一步")) {
                    installationState.currentStep = .kubeconfigSelection
                }
            )
        }
    }
    
    // MARK: - 子视图组件
    
    // 标题部分
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("安装选项")
                .font(.system(size: 20, weight: .medium))
            
            Text("请选择是否要安装Devtron平台，无论您的选择如何，我们都将配置必要的命令行工具")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
    
    // 内容区域
    private var contentScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Devtron选择开关
                Toggle("安装Devtron平台", isOn: $installationState.installDevtron)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .font(.system(size: 14))
                
                // Devtron功能介绍
                if installationState.installDevtron {
                    devtronFeaturesView
                }
                
                // 工具配置信息
                configToolsView
                
                // 测试中状态显示
                if isTesting {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.7)
                        
                        Text("正在测试集群连接...")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
                
                // 添加底部空间，确保内容足够高度
                Spacer(minLength: 20)
            }
        }
    }
    
    // Devtron功能介绍
    private var devtronFeaturesView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Devtron功能")
                .font(.system(size: 13, weight: .medium))
                .padding(.bottom, 2)
            
            FeatureRow(icon: "cube.box.fill", text: "一键部署镜像文件")
            FeatureRow(icon: "chart.xyaxis.line", text: "完整的应用监控和可观测性")
            FeatureRow(icon: "gearshape.2", text: "简化的Kubernetes配置管理")
        }
        .padding(14)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
    
    // 环境变量配置信息
    private var configToolsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("将配置的工具")
                .font(.system(size: 13, weight: .medium))
                .padding(.bottom, 2)
            
            ConfigItemRow(icon: "helm", text: "Helm")
            ConfigItemRow(icon: "kubectl", text: "Kubectl")
            ConfigItemRow(icon: "doc.fill", text: "Kubeconfig (~/.kube/config)")
        }
        .padding(14)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    // 导航按钮
    private var navigationButtonsView: some View {
        HStack {
            // 上一步按钮
            previousButton
            
            Spacer()
            
            // 下一步按钮
            nextButton
        }
        .frame(height: 36)
    }
    
    // 上一步按钮
    private var previousButton: some View {
        Button(action: {
            installationState.currentStep = .kubeconfigSelection
        }) {
            Text("上一步")
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .foregroundColor(.primary)
        .cornerRadius(6)
    }
    
    // 下一步按钮
    private var nextButton: some View {
        Button(action: {
//            if !installationState.installDevtron {
//                // 如果不安装Devtron，无需测试连接，直接进入下一步
//                setupEnvironment()
//            } else
            if testResult == .success {
                // 如果已经测试成功，直接进入下一步
                setupEnvironment()
            } else {
                // 需要安装Devtron但还没测试成功，先进行测试
                if !isTesting { // 避免重复测试
                    installationState.appendLog("需要测试集群连接才能安装Devtron")
                    
                    // 显示测试中状态
                    testClusterConnection { success in
                        if success {
                            // 测试成功才进入下一步
                            self.setupEnvironment()
                        } else {
                            // 测试失败显示弹窗
                            if case .failure(let message) = self.testResult {
                                self.alertMessage = formatErrorMessageForAlert(message)
                                self.showTestFailAlert = true
                            }
                        }
                    }
                }
            }
        }) {
            Text("下一步")
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(6)
        .disabled(isTesting)
    }
    
    // 判断下一步按钮是否可用
    private var isNextButtonEnabled: Bool {
        if isTesting {
            // 测试中不可点击
            return false
        }
        
        if !installationState.installDevtron {
            // 不安装Devtron时始终可用
            return true
        }
        
        // 安装Devtron时，只有测试成功才可用
        return testResult == .success
    }
    
    // 格式化错误信息，使其更适合在弹窗中显示
    private func formatErrorMessageForAlert(_ message: String) -> String {
        // 移除特殊格式和多余的换行符
        var formattedMessage = message
            .replacingOccurrences(of: "\n\n", with: "\n")
        
        // 提取核心错误信息
        
        if formattedMessage.contains("the server is currently unable to handle the request") {
            return  "无法连接到Kubernetes服务器。请检查:\n1. 集群是否运行\n2. 网络连接是否正常\n3. Kubeconfig是否正确"
        } else if formattedMessage.contains("Unauthorized") || formattedMessage.contains("authorization") {
            return  "授权失败。请检查:\n1. Kubeconfig中的证书是否有效\n2. 用户凭证是否正确\n3. 您是否有访问集群的权限"
        } else if formattedMessage.contains("certificate") || formattedMessage.contains("x509") {
            return  "证书错误。请检查:\n1. Kubeconfig中的证书是否有效\n2. 集群证书是否已过期\n3. 集群服务器地址与证书是否匹配"
        }
        
        // 通用错误信息
        return "连接Kubernetes集群失败。\n\n错误详情:\n\(formattedMessage)\n\n请检查您的kubeconfig文件和集群状态，确保集群可正常访问。"
    }
    
    // MARK: - 集群连接测试逻辑
    
    private func testClusterConnection(completion: ((Bool) -> Void)? = nil) {
        guard !isTesting else { return }
        
        isTesting = true
        testResult = nil
        
        // 获取应用资源路径
        let bundlePath = Bundle.main.bundlePath
        let toolsDir = "\(bundlePath)/Contents/Resources/tools"
        let kubectlPath = "\(toolsDir)/kubectl"
        
        // 环境变量设置
        let env = [
            "PATH": "\(toolsDir):/usr/bin:/bin:/usr/sbin:/sbin",
            "KUBECONFIG": installationState.kubeconfigPath, // 实际路径用于执行命令
            "KUBE_INSECURE_SKIP_TLS_VERIFY": "true"
        ]
        
        installationState.appendLog("开始测试集群连接...")
        // 使用显示路径记录日志，避免泄露解码后的实际路径
        let displayFileName = URL(fileURLWithPath: installationState.kubeconfigDisplayPath).lastPathComponent
        installationState.appendLog("使用kubeconfig: \(displayFileName)")
        
        DispatchQueue.global().async {
            // 测试1: 检查kubectl是否可用
            let kubectlTest = ShellUtils.runCommandWithEnv("\"\(kubectlPath)\" version --client", environment: env)
            
            if kubectlTest.exitCode != 0 {
                DispatchQueue.main.async {
                    self.isTesting = false
                    self.testResult = .failure(message: "kubectl工具测试失败: \(kubectlTest.error)")
                    self.installationState.appendLog("kubectl工具测试失败: \(kubectlTest.error)")
                    completion?(false)
                }
                return
            }
            
            // 测试2: 连接集群，获取节点信息
            let getNodesCmd = "\"\(kubectlPath)\" get namespaces --request-timeout=10s"
            self.installationState.appendLog("正在执行集群连接测试: \(getNodesCmd)")
            let getNodesResult = ShellUtils.runCommandWithEnv(getNodesCmd, environment: env)
            
            if getNodesResult.exitCode == 0 {
                // 成功连接集群
                DispatchQueue.main.async {
                    self.isTesting = false
                    self.testResult = .success
                    self.installationState.appendLog("集群连接测试成功 ✓")
                    self.installationState.appendLog("namespace信息:\n\(getNodesResult.output)")
                    completion?(true)
                }
            } else {
                // 连接失败，尝试获取更详细的错误信息
                let getComponentsCmd = "\"\(kubectlPath)\" get componentstatuses --request-timeout=10s"
                let componentsResult = ShellUtils.runCommandWithEnv(getComponentsCmd, environment: env)
                
                var errorMsg = getNodesResult.error.isEmpty ? "无法连接到Kubernetes集群" : getNodesResult.error
                
                // 处理常见错误
                if errorMsg.contains("Unable to connect to the server") {
                    errorMsg = "无法连接到Kubernetes服务器。请检查:\n1. 集群是否运行\n2. 网络连接是否正常\n3. Kubeconfig中的服务器地址是否正确"
                } else if errorMsg.contains("Unauthorized") || errorMsg.contains("authorization") {
                    errorMsg = "授权失败。请检查:\n1. Kubeconfig中的证书是否有效\n2. 用户凭证是否正确\n3. 您是否有访问集群的权限"
                } else if errorMsg.contains("certificate") || errorMsg.contains("x509") {
                    errorMsg = "证书错误。请检查:\n1. Kubeconfig中的证书是否有效\n2. 集群证书是否已过期\n3. 集群服务器地址与证书是否匹配"
                }
                
                DispatchQueue.main.async {
                    self.isTesting = false
                    self.testResult = .failure(message: errorMsg)
                    self.installationState.appendLog("集群连接测试失败: \(errorMsg)")
                    
                    // 提示用户在测试失败时不能继续安装Devtron
                    if self.installationState.installDevtron {
                        self.installationState.appendLog("警告: 安装Devtron需要先成功连接到Kubernetes集群")
                    }
                    
                    completion?(false)
                }
            }
        }
    }
    
    private func setupEnvironment() {
        // 先更新UI状态，减少界面卡顿感
        DispatchQueue.main.async {
            // 先记录选择，确保即使异步操作慢也能保持选择
            let willInstallDevtron = self.installationState.installDevtron
            
            // 记录配置日志
            self.installationState.appendLog("开始配置环境...")
            self.installationState.appendLog("配置项目: Kubeconfig, kubectl, helm")
            
            if willInstallDevtron {
                self.installationState.appendLog("用户选择安装Devtron ✓")
            } else {
                self.installationState.appendLog("用户选择不安装Devtron ✓")
            }
            
            // 立即跳转到下一步，而不等待后台配置完成
            // 这会立即更新界面，减少卡顿感
            self.installationState.moveToNextStep()
            
            // 环境配置不需要特殊处理，在安装视图中会处理
            self.installationState.appendLog("环境配置将在安装步骤中完成 ✓")
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 16, height: 16)
                .font(.system(size: 11))
            
            Text(text)
                .foregroundColor(.primary)
                .font(.system(size: 12))
            
            Spacer()
        }
    }
}

struct ConfigItemRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            if icon == "helm" || icon == "kubectl" {
                Text(icon.prefix(1).uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .background(Color.gray.opacity(0.8))
                    .cornerRadius(3)
            } else {
                Image(systemName: icon)
                    .foregroundColor(.gray)
                    .frame(width: 16, height: 16)
                    .font(.system(size: 11))
            }
            
            Text(text)
                .foregroundColor(.primary)
                .font(.system(size: 12))
            
            Spacer()
        }
    }
}
