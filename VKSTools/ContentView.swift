import SwiftUI

struct DetailedErrorView: View {
    @Binding var isPresented: Bool
    let errorMessage: String
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 22))
                
                Text("安装错误")
                    .font(.headline)
                    .foregroundColor(.red)
                
                Spacer()
                
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 4)
            
            // 错误消息内容
            ScrollView {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 100)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(6)
            
            // 确定按钮
            Button(action: {
                isPresented = false
            }) {
                Text("确定")
                    .frame(width: 80)
            }
            .buttonStyle(BorderedButtonStyle())
            .controlSize(.small)
        }
        .padding()
        .frame(width: 400)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct ContentView: View {
    @EnvironmentObject private var installationState: InstallationState
    @State private var isShowingDetailedError = false

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                // 左侧步骤导航栏
                VStack(alignment: .leading, spacing: 16) {
                    // 应用标志
                    Text("VKSTools")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary.opacity(0.7))
                        .padding(.bottom, 24)
                    
                    // 步骤列表
                    StepListView(currentStep: installationState.currentStep)
                    
                    Spacer()
                    
                    // 版本信息
                    Text("v1.0.0")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 170)
                .padding(.vertical, 30)
                .padding(.horizontal, 20)
                .background(Color(.windowBackgroundColor).opacity(0.5))
                
                // 右侧主内容区域
                ZStack {
                    switch installationState.currentStep {
                    case .kubeconfigSelection:
                        KubeconfigSelectionView()
                    case .devtronChoice:
                        DevtronChoiceView()
                    case .installation:
                        InstallationView()
                    case .waitingForServices:
                        WaitingForServicesView()
                    case .completion:
                        CompletionView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.01))  // 几乎透明的背景
            }
            
            // 自定义错误对话框
            if installationState.isShowingError {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        // 点击背景可关闭对话框
                        installationState.isShowingError = false
                    }
                
                DetailedErrorView(
                    isPresented: $installationState.isShowingError,
                    errorMessage: installationState.errorMessage ?? "未知错误"
                )
                .transition(.scale)
                .zIndex(100)
            }
        }
        .onChange(of: installationState.isShowingError) { newValue in
            isShowingDetailedError = newValue
        }
    }
}

struct StepListView: View {
    let currentStep: InstallationStep
    @EnvironmentObject private var installationState: InstallationState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepRow(
                step: 1,
                title: "选择配置文件",
                isActive: currentStep == .kubeconfigSelection,
                isCompleted: currentStep != .kubeconfigSelection
            )
            
            StepRow(
                step: 2,
                title: "选择安装选项",
                isActive: currentStep == .devtronChoice,
                isCompleted: [.installation, .waitingForServices, .completion].contains(currentStep)
            )
            
            StepRow(
                step: 3,
                title: "安装组件",
                isActive: currentStep == .installation,
                isCompleted: [.waitingForServices, .completion].contains(currentStep)
            )
            
            // 仅在安装Devtron时显示等待服务启动步骤
            if installationState.installDevtron {
                StepRow(
                    step: 4,
                    title: "等待服务启动",
                    isActive: currentStep == .waitingForServices,
                    isCompleted: currentStep == .completion
                )
            }
            
            StepRow(
                step: installationState.installDevtron ? 5 : 4,
                title: "安装完成",
                isActive: currentStep == .completion,
                isCompleted: false
            )
        }
    }
}

struct StepRow: View {
    let step: Int
    let title: String
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            // 步骤标志
            ZStack {
                Circle()
                    .fill(isActive ? Color.blue : (isCompleted ? Color.green : Color.gray.opacity(0.3)))
                    .frame(width: 20, height: 20)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(step)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            
            // 步骤标题
            Text(title)
                .font(.system(size: 12, weight: isActive ? .medium : .regular))
                .foregroundColor(isActive ? .primary : .secondary)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(InstallationState())
    }
} 
