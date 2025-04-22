## 如何查看 vksID 已经保存到 configmap

kubectl get configmap devtron-global-config -n devtroncd -o yaml

## 没有创建 可以给用户创建一个 "vksID" 需要修改为用户的vkdID

create configmap devtron-global-config -n devtroncd --from-literal=vksID="vksID"