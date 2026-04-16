#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
NC='\033[0m'

# 默认版本
K8S_VERSION=""
K8S_MAJOR_VERSION=""
K8S_FULL_VERSION=""
NODE_ROLE=""
POD_NETWORK_CIDR="10.244.0.0/16"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Simple execution with clean output
run_cmd() {
    local cmd="$1"
    local msg="$2"

    echo -e "${BLUE}[INFO]${NC} $msg..."

    if eval "$cmd" 2>&1 | while IFS= read -r line; do
        echo -e "${GRAY}  $line${NC}"
    done; then
        log_success "$msg"
        return 0
    else
        log_error "Failed: $msg"
        return 1
    fi
}

# Silent execution for simple commands
run_silent() {
    local cmd="$1"
    local msg="$2"

    if eval "$cmd" >/dev/null 2>&1; then
        log_success "$msg"
        return 0
    else
        log_error "Failed: $msg"
        return 1
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Root privileges required"
        exit 1
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        log_error "Cannot detect OS version"
        exit 1
    fi

    log_info "Detected OS: $OS $OS_VERSION"

    case $OS in
        ubuntu|debian)
            ;;
        *)
            log_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac
}

# 选择K8s版本
select_k8s_version() {
    echo
    log_info "Available Kubernetes versions:"
    echo "  1) v1.28.x"
    echo "  2) v1.29.x"
    echo "  3) v1.30.x"
    echo "  4) v1.31.x"
    echo "  5) v1.32.x"
    echo "  6) Custom version"
    echo

    read -p "Select version (1-6) [default: 3]: " choice
    choice=${choice:-3}

    case $choice in
        1)
            K8S_MAJOR_VERSION="1.28"
            ;;
        2)
            K8S_MAJOR_VERSION="1.29"
            ;;
        3)
            K8S_MAJOR_VERSION="1.30"
            ;;
        4)
            K8S_MAJOR_VERSION="1.31"
            ;;
        5)
            K8S_MAJOR_VERSION="1.32"
            ;;
        6)
            read -p "Enter custom version (e.g., 1.30): " K8S_MAJOR_VERSION
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac

    # 获取该版本的具体版本号
    log_info "Fetching available versions for v${K8S_MAJOR_VERSION}..."

    # 先添加临时源以获取版本信息
    apt-get update -y >/dev/null 2>&1 || true

    read -p "Enter specific version (e.g., ${K8S_MAJOR_VERSION}.0) or press Enter for latest ${K8S_MAJOR_VERSION}.x: " specific_version

    if [[ -n "$specific_version" ]]; then
        K8S_VERSION="$specific_version"
    else
        K8S_VERSION="${K8S_MAJOR_VERSION}"
    fi

    log_info "Selected Kubernetes version: v${K8S_VERSION}"
}

# 检查已安装的K8s版本
check_existing_k8s() {
    local installed_version=""

    if command -v kubeadm >/dev/null 2>&1; then
        installed_version=$(kubeadm version -o short 2>/dev/null | sed 's/v//' || echo "")

        if [[ -n "$installed_version" ]]; then
            log_warning "Found existing Kubernetes installation: v${installed_version}"
            log_warning "Target version: v${K8S_VERSION}"

            echo
            echo "Options:"
            echo "  1) Remove existing installation and install v${K8S_VERSION}"
            echo "  2) Keep existing installation and exit"
            echo "  3) Force reinstall/downgrade to v${K8S_VERSION}"
            echo

            read -p "Select option (1-3) [default: 2]: " option
            option=${option:-2}

            case $option in
                1)
                    remove_existing_k8s
                    ;;
                2)
                    log_info "Keeping existing installation. Exiting."
                    exit 0
                    ;;
                3)
                    log_warning "Force reinstalling to v${K8S_VERSION}"
                    remove_existing_k8s
                    ;;
                *)
                    log_error "Invalid option"
                    exit 1
                    ;;
            esac
        fi
    else
        log_info "No existing Kubernetes installation found"
    fi
}

# 移除已安装的K8s
remove_existing_k8s() {
    log_info "Removing existing Kubernetes installation..."

    # 停止服务
    systemctl stop kubelet 2>/dev/null || true

    # 如果是集群节点，先重置
    if [[ -f /etc/kubernetes/kubelet.conf ]] || [[ -f /etc/kubernetes/admin.conf ]]; then
        log_info "Resetting Kubernetes cluster configuration..."
        kubeadm reset -f 2>/dev/null || true
    fi

    # 取消hold
    apt-mark unhold kubelet kubeadm kubectl 2>/dev/null || true

    # 卸载K8s组件
    log_info "Uninstalling Kubernetes packages..."
    apt-get remove -y kubelet kubeadm kubectl 2>/dev/null || true
    apt-get purge -y kubelet kubeadm kubectl 2>/dev/null || true
    apt-get autoremove -y 2>/dev/null || true

    # 清理配置文件
    log_info "Cleaning up Kubernetes configuration files..."
    rm -rf /etc/kubernetes
    rm -rf /var/lib/kubelet
    rm -rf /var/lib/etcd
    rm -rf ~/.kube
    rm -rf /root/.kube

    # 清理所有用户的 .kube 目录
    for user_home in /home/*; do
        if [[ -d "$user_home/.kube" ]]; then
            rm -rf "$user_home/.kube"
        fi
    done

    # 清理CNI
    rm -rf /etc/cni/net.d
    rm -rf /opt/cni/bin

    # 清理 iptables 规则
    log_info "Cleaning up iptables rules..."
    iptables -F 2>/dev/null || true
    iptables -t nat -F 2>/dev/null || true
    iptables -t mangle -F 2>/dev/null || true
    iptables -X 2>/dev/null || true

    log_success "Existing Kubernetes installation removed"
}

update_system() {
    log_info "Updating package list..."
    apt-get update -y
    log_success "Package list updated"

    log_info "Installing dependencies..."
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release net-tools
    log_success "Dependencies installed"
}

add_gpg_keys() {
    run_silent "mkdir -p /etc/apt/keyrings" "Keyring directory created"

    if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
        log_info "Adding Docker GPG key..."
        curl -fsSL https://mirrors.ustc.edu.cn/docker-ce/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        log_success "Docker GPG key added"
    else
        log_info "Docker GPG key already exists"
    fi

    # 删除旧的K8s GPG key以更新版本
    if [[ -f /etc/apt/keyrings/kubernetes.gpg ]]; then
        log_info "Removing old Kubernetes GPG key..."
        rm -f /etc/apt/keyrings/kubernetes.gpg
    fi

    log_info "Adding Kubernetes GPG key for v${K8S_MAJOR_VERSION}..."
    curl -fsSL https://mirrors.ustc.edu.cn/kubernetes/core:/stable:/v${K8S_MAJOR_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg
    chmod a+r /etc/apt/keyrings/kubernetes.gpg
    log_success "Kubernetes GPG key added"
}

add_apt_sources() {
    CODENAME=$(lsb_release -cs)
    ARCH=$(dpkg --print-architecture)

    log_info "Adding Docker APT source..."
    echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.ustc.edu.cn/docker-ce/linux/$OS $CODENAME stable" > /etc/apt/sources.list.d/docker.list
    log_success "Docker APT source added"

    log_info "Adding Kubernetes APT source for v${K8S_MAJOR_VERSION}..."
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://mirrors.ustc.edu.cn/kubernetes/core:/stable:/v${K8S_MAJOR_VERSION}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
    log_success "Kubernetes APT source added"

    log_info "Refreshing package list..."
    apt-get update -y
    log_success "Package list refreshed"
}

install_packages() {
    log_info "Disabling swap..."
    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    log_success "Swap disabled"

    # 检查containerd
    if ! command -v containerd >/dev/null 2>&1; then
        log_info "Installing containerd.io..."
        apt-get install -y containerd.io
        log_success "Installed containerd.io"
    else
        log_info "Containerd already installed"
    fi

    # 查找可用的K8s版本
    log_info "Finding available Kubernetes ${K8S_VERSION} packages..."

    # 获取可用版本列表
    available_versions=$(apt-cache madison kubeadm | grep "${K8S_VERSION}" | head -5 || true)

    if [[ -z "$available_versions" ]]; then
        log_error "No packages found for version ${K8S_VERSION}"
        log_info "Available versions:"
        apt-cache madison kubeadm | head -10
        exit 1
    fi

    # 选择最新的匹配版本
    PKG_VERSION=$(echo "$available_versions" | head -1 | awk '{print $3}')

    # 从包版本中提取 Kubernetes 版本号 (例如: 1.28.15-1.1 -> 1.28.15)
    K8S_FULL_VERSION=$(echo "$PKG_VERSION" | cut -d'-' -f1)

    log_info "Installing Kubernetes version: $PKG_VERSION (k8s: v$K8S_FULL_VERSION)"

    # 安装指定版本的K8s组件
    local packages=("kubelet=$PKG_VERSION" "kubeadm=$PKG_VERSION" "kubectl=$PKG_VERSION")

    for package in "${packages[@]}"; do
        log_info "Installing $package..."
        apt-get install -y "$package"
        log_success "Installed $package"
    done

    log_info "Marking Kubernetes packages as hold..."
    apt-mark hold kubelet kubeadm kubectl
    log_success "Kubernetes packages marked hold"
}

configure_system() {
    log_info "Configuring kernel parameters..."
    cat <<EOF > /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

    # Load br_netfilter module
    modprobe br_netfilter 2>/dev/null || true

    sysctl --system >/dev/null
    log_success "Kernel parameters configured"
}

configure_containerd() {
    log_info "Generating containerd config..."
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml

    log_info "Configuring SystemdCgroup..."
    sed -i 's|SystemdCgroup = false|SystemdCgroup = true|' /etc/containerd/config.toml

    log_info "Updating pause image..."
    sed -i 's|sandbox_image = "registry.k8s.io/pause:[^"]*"|sandbox_image = "registry.k8s.io/pause:3.10"|' /etc/containerd/config.toml

    log_info "Enabling and restarting containerd..."
    systemctl enable containerd
    systemctl restart containerd
    log_success "Containerd configured and started"

    # 配置 crictl
    log_info "Configuring crictl..."
    cat <<EOF > /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF
    log_success "Crictl configured"
}

enable_services() {
    log_info "Enabling kubelet service..."
    systemctl enable kubelet
    log_success "Kubelet service enabled"
}

verify_installation() {
    log_info "Verifying installation..."

    # Check versions
    if command -v containerd >/dev/null; then
        version=$(containerd --version 2>/dev/null | cut -d' ' -f3 || echo "unknown")
        log_info "Containerd: $version"
    fi

    if command -v kubeadm >/dev/null; then
        version=$(kubeadm version -o short 2>/dev/null || echo "unknown")
        log_info "Kubeadm: $version"
    fi

    if command -v kubelet >/dev/null; then
        version=$(kubelet --version 2>/dev/null | cut -d' ' -f2 || echo "unknown")
        log_info "Kubelet: $version"
    fi

    if command -v kubectl >/dev/null; then
        version=$(kubectl version --client -o short 2>/dev/null || echo "unknown")
        log_info "Kubectl: $version"
    fi

    # Check services
    if systemctl is-active --quiet containerd; then
        log_success "Containerd service is active"
    else
        log_warning "Containerd service is not active"
    fi

    if systemctl is-enabled --quiet kubelet; then
        log_success "Kubelet service is enabled"
    else
        log_warning "Kubelet service is not enabled"
    fi
}

# 选择节点角色
select_node_role() {
    echo
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Node Configuration"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "Select node role:"
    echo "  1) Master Node (Control Plane)"
    echo "  2) Worker Node"
    echo "  3) Skip configuration (manual setup later)"
    echo

    read -p "Select option (1-3) [default: 3]: " role_choice
    role_choice=${role_choice:-3}

    case $role_choice in
        1)
            NODE_ROLE="master"
            configure_master_node
            ;;
        2)
            NODE_ROLE="worker"
            configure_worker_node
            ;;
        3)
            NODE_ROLE="none"
            show_manual_steps
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
}

# 强制终止占用端口的进程
kill_port_process() {
    local port=$1
    local process_name=$2

    log_info "Checking processes using port $port..."

    # 查找占用端口的进程
    local pids=""
    if command -v lsof >/dev/null 2>&1; then
        pids=$(lsof -ti:$port 2>/dev/null || true)
    elif command -v ss >/dev/null 2>&1; then
        pids=$(ss -lptn "sport = :$port" 2>/dev/null | grep -oP 'pid=\K[0-9]+' || true)
    elif command -v netstat >/dev/null 2>&1; then
        pids=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1 || true)
    fi

    if [[ -n "$pids" ]]; then
        log_warning "Found processes using port $port: $pids"
        for pid in $pids; do
            if [[ -n "$pid" ]] && [[ "$pid" =~ ^[0-9]+$ ]]; then
                local cmd=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
                log_info "Killing process $pid ($cmd)..."
                kill -9 $pid 2>/dev/null || true
            fi
        done
        sleep 2
        log_success "Processes killed"
    else
        log_info "No process found using port $port"
    fi

    # 总是返回成功，避免触发 set -e
    return 0
}

# 检查并清理初始化前的残留配置
cleanup_before_init() {
    log_info "Checking for existing cluster configuration..."

    local need_cleanup=false
    local issues=()

    # 检查配置文件
    if [[ -d /etc/kubernetes/manifests ]] && [[ -n "$(ls -A /etc/kubernetes/manifests 2>/dev/null)" ]]; then
        issues+=("Existing Kubernetes manifests found")
        need_cleanup=true
    fi

    if [[ -f /etc/kubernetes/admin.conf ]]; then
        issues+=("Existing admin.conf found")
        need_cleanup=true
    fi

    # 检查端口占用
    local port_in_use=false
    if command -v netstat >/dev/null 2>&1; then
        if netstat -tulpn 2>/dev/null | grep -q ":10250 "; then
            issues+=("Port 10250 is in use")
            port_in_use=true
            need_cleanup=true
        fi
    elif command -v ss >/dev/null 2>&1; then
        if ss -tulpn 2>/dev/null | grep -q ":10250 "; then
            issues+=("Port 10250 is in use")
            port_in_use=true
            need_cleanup=true
        fi
    fi

    # 检查 kubelet 状态
    if systemctl is-active --quiet kubelet 2>/dev/null; then
        issues+=("Kubelet service is running")
        need_cleanup=true
    fi

    # 如果发现问题
    if [[ "$need_cleanup" == true ]]; then
        log_warning "Found existing cluster configuration or resources:"
        for issue in "${issues[@]}"; do
            echo -e "  ${YELLOW}•${NC} $issue"
        done
        echo
        echo "Options:"
        echo "  1) Clean up and continue (recommended)"
        echo "  2) Skip cleanup and try to initialize anyway"
        echo "  3) Exit and manual cleanup"
        echo

        read -p "Select option (1-3) [default: 1]: " cleanup_choice
        cleanup_choice=${cleanup_choice:-1}

        case $cleanup_choice in
            1)
                perform_cleanup "$port_in_use"
                ;;
            2)
                log_warning "Skipping cleanup, initialization may fail"
                ;;
            3)
                log_info "Exiting. Run 'kubeadm reset -f' to clean up manually"
                exit 0
                ;;
            *)
                log_error "Invalid choice"
                exit 1
                ;;
        esac
    else
        log_success "No existing cluster configuration found"
    fi
}

# 执行清理
perform_cleanup() {
    local check_port=${1:-false}

    log_info "Performing cleanup..."

    # 强制停止 kubelet
    log_info "Stopping kubelet service..."
    systemctl stop kubelet 2>/dev/null || true
    systemctl disable kubelet 2>/dev/null || true

    # 强制杀掉所有 kubelet 进程
    log_info "Killing any remaining kubelet processes..."
    pkill -9 kubelet 2>/dev/null || true

    # 等待进程完全终止
    sleep 3

    # 检查并杀死占用端口 10250 的进程
    if [[ "$check_port" == true ]]; then
        kill_port_process 10250 "kubelet"
        # 再等待一下
        sleep 2
    fi

    # 重置 kubeadm
    log_info "Resetting kubeadm configuration..."
    kubeadm reset -f 2>/dev/null || true

    # 清理配置文件
    log_info "Removing configuration files..."
    rm -rf /etc/kubernetes/ 2>/dev/null || true
    rm -rf /var/lib/kubelet/ 2>/dev/null || true
    rm -rf /var/lib/etcd/ 2>/dev/null || true
    rm -rf ~/.kube/ 2>/dev/null || true
    rm -rf /root/.kube/ 2>/dev/null || true

    # 清理所有用户的 .kube 目录
    for user_home in /home/*; do
        if [[ -d "$user_home/.kube" ]]; then
            rm -rf "$user_home/.kube" 2>/dev/null || true
        fi
    done

    # 清理 CNI
    log_info "Removing CNI configuration..."
    rm -rf /etc/cni/net.d/ 2>/dev/null || true

    # 清理 iptables 规则
    log_info "Cleaning up iptables rules..."
    iptables -F 2>/dev/null || true
    iptables -t nat -F 2>/dev/null || true
    iptables -t mangle -F 2>/dev/null || true
    iptables -X 2>/dev/null || true

    # 重启 containerd
    log_info "Restarting containerd..."
    systemctl restart containerd

    # 重新启用 kubelet
    log_info "Re-enabling kubelet..."
    systemctl enable kubelet 2>/dev/null || true

    # 等待系统稳定
    log_info "Waiting for system to stabilize..."
    sleep 5

    # 最后一次检查端口
    if [[ "$check_port" == true ]]; then
        if command -v netstat >/dev/null 2>&1; then
            if netstat -tulpn 2>/dev/null | grep -q ":10250 "; then
                log_warning "Port 10250 still in use, attempting final cleanup..."
                kill_port_process 10250 "kubelet"
                sleep 3
            fi
        elif command -v ss >/dev/null 2>&1; then
            if ss -tulpn 2>/dev/null | grep -q ":10250 "; then
                log_warning "Port 10250 still in use, attempting final cleanup..."
                kill_port_process 10250 "kubelet"
                sleep 3
            fi
        fi
    fi

    log_success "Cleanup completed"
}

# 配置 Master 节点
configure_master_node() {
    log_info "Configuring Master Node..."

    # 确保有完整版本号
    if [[ -z "$K8S_FULL_VERSION" ]]; then
        K8S_FULL_VERSION=$(kubeadm version -o short 2>/dev/null | sed 's/v//')
    fi

    # 初始化前检查和清理
    cleanup_before_init

    # 获取配置参数
    read -p "Pod network CIDR [default: 10.244.0.0/16]: " pod_cidr
    POD_NETWORK_CIDR=${pod_cidr:-10.244.0.0/16}

    read -p "API Server advertise address (leave empty for auto-detect): " api_addr

    # 构建 kubeadm init 命令
    local init_cmd="kubeadm init --pod-network-cidr=${POD_NETWORK_CIDR} --kubernetes-version=v${K8S_FULL_VERSION}"

    if [[ -n "$api_addr" ]]; then
        init_cmd="$init_cmd --apiserver-advertise-address=${api_addr}"
    fi

    # 使用国内镜像源
    init_cmd="$init_cmd --image-repository=registry.aliyuncs.com/google_containers"

    echo
    log_info "Initializing Kubernetes cluster with version v${K8S_FULL_VERSION}..."
    log_warning "This may take several minutes..."
    echo

    if $init_cmd; then
        log_success "Cluster initialized successfully!"

        # 配置 kubectl
        setup_kubectl

        # 安装网络插件
        install_network_plugin

        # 显示 join 命令
        show_join_command

    else
        log_error "Cluster initialization failed"
        log_info "Check logs with: journalctl -xeu kubelet"
        log_info "Or run with verbose output: kubeadm init --v=5"
        echo
        log_info "You can also try manual cleanup:"
        echo "  sudo kubeadm reset -f"
        echo "  sudo systemctl stop kubelet"
        echo "  sudo pkill -9 kubelet"
        echo "  sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd"
        exit 1
    fi
}

# 配置 kubectl
setup_kubectl() {
    log_info "Configuring kubectl..."

    # 为 root 用户配置
    if [[ ! -d /root/.kube ]]; then
        mkdir -p /root/.kube
        cp -i /etc/kubernetes/admin.conf /root/.kube/config
        chown root:root /root/.kube/config
        log_success "Kubectl configured for root user"
    fi

    # 为当前用户配置（如果通过 sudo 运行）
    if [[ -n "${SUDO_USER:-}" ]]; then
        local user_home=$(eval echo ~$SUDO_USER)
        if [[ ! -d "$user_home/.kube" ]]; then
            mkdir -p "$user_home/.kube"
            cp -i /etc/kubernetes/admin.conf "$user_home/.kube/config"
            chown -R $SUDO_USER:$SUDO_USER "$user_home/.kube"
            log_success "Kubectl configured for user: $SUDO_USER"
        fi
    fi

    # 设置环境变量
    export KUBECONFIG=/etc/kubernetes/admin.conf
}

# 安装网络插件
install_network_plugin() {
    echo
    log_info "Select network plugin:"
    echo "  1) Flannel (recommended for beginners)"
    echo "  2) Calico"
    echo "  3) Skip (install manually later)"
    echo

    read -p "Select option (1-3) [default: 1]: " cni_choice
    cni_choice=${cni_choice:-1}

    case $cni_choice in
        1)
            log_info "Installing Flannel..."
            kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
            log_success "Flannel installed"
            ;;
        2)
            log_info "Installing Calico..."
            kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
            log_success "Calico installed"
            ;;
        3)
            log_info "Skipping CNI installation"
            log_warning "Remember to install a CNI plugin manually"
            ;;
        *)
            log_warning "Invalid choice, skipping CNI installation"
            ;;
    esac

    echo
    log_info "Waiting for cluster to be ready..."
    sleep 10

    echo
    log_info "Current cluster status:"
    kubectl get nodes
    echo
    kubectl get pods -A
}

# 显示 join 命令
show_join_command() {
    echo
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "Master Node Setup Complete!"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    log_info "To add worker nodes, run this command on them:"
    echo
    kubeadm token create --print-join-command
    echo
    log_info "To regenerate this command later, run on master:"
    echo "  kubeadm token create --print-join-command"
    echo
    log_info "To check cluster status:"
    echo "  kubectl get nodes"
    echo "  kubectl get pods -A"
    echo
}

# 配置 Worker 节点
configure_worker_node() {
    log_info "Configuring Worker Node..."

    # 检查并清理残留配置
    cleanup_before_init

    echo
    log_warning "You need the 'kubeadm join' command from your master node"
    echo
    log_info "Example format:"
    echo "  kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
    echo
    read -p "Paste the complete 'kubeadm join' command: " join_cmd

    if [[ -z "$join_cmd" ]]; then
        log_error "No join command provided"
        show_manual_steps
        return
    fi

    log_info "Joining cluster..."
    if eval "$join_cmd"; then
        log_success "Successfully joined cluster!"
        echo
        log_info "To verify, run on master node:"
        echo "  kubectl get nodes"
    else
        log_error "Failed to join cluster"
        log_info "Check logs with: journalctl -xeu kubelet"
    fi
}

# 显示手动配置步骤
show_manual_steps() {
    echo
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "Installation completed successfully!"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    log_info "Installed version: v${K8S_FULL_VERSION}"
    echo
    log_info "Next steps for MASTER node:"
    echo
    echo "  1. Initialize cluster:"
    echo "     kubeadm init --pod-network-cidr=10.244.0.0/16 \\"
    echo "       --kubernetes-version=v${K8S_FULL_VERSION} \\"
    echo "       --image-repository=registry.aliyuncs.com/google_containers"
    echo
    echo "  2. Configure kubectl:"
    echo "     mkdir -p \$HOME/.kube"
    echo "     sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config"
    echo "     sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
    echo
    echo "  3. Install network plugin (Flannel):"
    echo "     kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml"
    echo
    echo "  4. Get join command for worker nodes:"
    echo "     kubeadm token create --print-join-command"
    echo
    log_info "Next steps for WORKER node:"
    echo
    echo "  Run the 'kubeadm join' command from master node"
    echo
}

main() {
    log_info "Starting Kubernetes environment initialization"
    echo

    check_root
    detect_os
    select_k8s_version
    check_existing_k8s
    update_system
    add_gpg_keys
    add_apt_sources
    install_packages
    configure_system
    configure_containerd
    enable_services
    verify_installation
    select_node_role
}

# Simple error trap
trap 'log_error "Script failed at line $LINENO"; exit 1' ERR

main "$@"
