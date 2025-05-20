#!/bin/bash
set -x
kubectl delete namespace devtroncd --force --grace-period=0
helm  uninstall devtron --namespace devtroncd
# 提取 server URL
server_url=$(kubectl config view 2>&1 | grep -E '^\s*server:\s*http' | sed -E 's/^\s*server:\s*//')

# 验证 server_url 是否存在
if [[ -z "$server_url" ]]; then
    echo "Error: Missing 'server' field in kubeconfig" >&2
    exit 1
fi

# 提取 zoneID（从 vcluster. 后的第一个字段）
zoneID=$(echo "$server_url" | cut -d. -f2)  # 使用 cut 按点分割取第二部分[1,8](@ref)

# 提取 vksID（inCluster/ 后的部分）
vksID=$(echo "$server_url" | awk -F '/inCluster/' '{print $2}' | cut -d/ -f1)  # 二次分割确保精确[2](@ref)

# 验证提取结果
if [[ -z "$zoneID" ]]; then
    echo "Error: Failed to extract zone-id from URL" >&2
    echo "Expected format: https://vcluster.<zone-id>.alayanew.com:21443/inCluster/<vks-id>" >&2
    echo "Actual URL: $server_url" >&2
    exit 1
fi

if [[ -z "$vksID" ]]; then
    echo "Error: Failed to extract cluster-id from URL" >&2
    echo "Expected format: https://vcluster.<zone-id>.alayanew.com:21443/inCluster/<vks-id>" >&2
    echo "Actual URL: $server_url" >&2
    exit 1
fi

# 输出结果
echo "zoneID: $zoneID"
echo "vksID: $vksID"

# 清理命名空间的函数
cleanup_namespace() {
    echo "正在清理 devtroncd 命名空间..."
    kubectl delete namespace devtroncd --force --grace-period=0 2>/dev/null || true
    # 等待命名空间被删除
    for i in {1..10}; do
        if ! kubectl get namespace devtroncd 2>/dev/null; then
            echo "命名空间已成功删除"
            break
        fi
        echo "等待命名空间删除完成 ($i/10)..."
        sleep 3
    done
}

# 执行 Helm 安装命令，并添加重试逻辑
install_devtron() {
    echo "正在安装 Devtron..."
    helm install devtron . \
        --create-namespace \
        -n devtroncd \
        --values resources.yaml \
        --set zoneID=$zoneID \
        --set vksID=$vksID \
        --set global.containerRegistry=registry.${zoneID}.alayanew.com:8443/vc-app_market/devtron  --timeout 300s
    
    # 检查安装状态
    if ! helm status devtron -n devtroncd | grep -q "STATUS: deployed"; then
        return 1
    fi
    return 0
}

# 第一次尝试安装
if ! install_devtron; then
    echo "Devtron 首次安装失败，正在重试..."
    # 在重试前清理命名空间
    kubectl delete namespace devtroncd --force --grace-period=0
    helm  uninstall devtron --namespace devtroncd
    sleep 5
    # 重试安装
    if ! install_devtron; then
        echo "Error: Devtron 安装失败，请检查日志获取更多信息" >&2
        exit 1
    fi
fi

echo "Devtron 已成功安装！"
