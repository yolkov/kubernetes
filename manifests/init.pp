# Class: kubernetes
# ===========================
#
# A module to build a Kubernetes cluster https://kubernetes.io/
# Main class, includes all other classes.
#
# @param kube_version
#   Version kubernetes cluster
#
# @param kube_package_version
#   Optional. Package version...
#
# @param kube_image
#
# @param kube_apiserver
#   Virtual dns name, which resolve IP apiserver
#
# @param kube_cluster
#   Cluster name
#
# @kube_pki_path
#   Path, where certs
#
# @kube_ca
#   main CA cert
#
#
class kubernetes (
  #common params
  String $kube_version,
  String[1] $kube_package_postfix,
  String[1] $kube_image_prefix,
  String $kube_apiserver,
  String $kube_cluster,
  String $kube_cluster_zone,
  String $kube_dns,
  Stdlib::Absolutepath $kube_pki_path,
  Stdlib::Absolutepath $kube_ca,
  Optional[Boolean] $kube_master,
  Stdlib::IP::Address::V4 $service_cluster_ip_range,
  Stdlib::IP::Address::V4 $cluster_cidr,
  Optional[Integer] $node_cidr_mask_size,
  String $apiserver_etcd_servers,
  String $token_id,
  String $token_secret,
  #docker params
  Enum['docker', 'containerd', 'manual'] $container_runtime,
  Optional[String] $docker_package_name,
  Optional[String] $docker_version,
  Hash $docker_daemon_options,
  #kubelet params
  Optional[String] $kubernetes_cni_version,

  Optional[String] $kubelet_domain, # $kube_cluster.kube
  Array[Stdlib::IP::Address::V4] $kubelet_dns_ip, # = cluster_dns from coredns svc or local dns
  Optional[Stdlib::IP::Address::V4] $kubelet_node_ip,
  Boolean $kubelet_package_manage,
  Optional[String] $kubelet_config_version,
  Optional[String] $kubelet_config_json,
  Optional[String] $kubelet_cgroup_driver,
  Optional[String] $kubelet_cpu_cfs_quota_period,
  Optional[String] $kubelet_cpu_manager_policy,
  Optional[Stdlib::Absolutepath] $kubelet_kubeconfig,
  Optional[String] $kubelet_kubeconfig_user,
  Optional[String] $kubelet_kubeconfig_token,
  Optional[Stdlib::Absolutepath] $kubelet_kubeconfig_crt,
  Optional[Stdlib::Absolutepath] $kubelet_kubeconfig_key,
  Optional[Stdlib::Absolutepath] $kubelet_kubeconfig_bootstrap,
  Optional[Boolean] $controller_allocate_node_cidrs,
  Variant[Boolean, Enum['true', 'false']] $controller_kubeconfig, # lint:ignore:quoted_booleans
  Optional[Stdlib::Absolutepath] $controller_kubeconfig_crt,
  Optional[Stdlib::Absolutepath] $controller_kubeconfig_key,
  Variant[Boolean, Enum['true', 'false']] $scheduler_kubeconfig, # lint:ignore:quoted_booleans
  Optional[Stdlib::Absolutepath] $scheduler_kubeconfig_crt,
  Optional[Stdlib::Absolutepath] $scheduler_kubeconfig_key,
  #Optional[String] $kubelet_tls_cert_file,
  #Optional[String] $kubelet_tls_key_file,
  Optional[Array[String]] $kubelet_register_with_taints,
  Optional[Array[String]] $kubelet_node_labels,
  Hash $kubelet_registry_auth,
  Optional[Integer] $kubelet_api_burst,
  Optional[Integer] $kubelet_api_qps,
  Optional[Integer] $kubelet_registry_burst,
  Optional[Integer] $kubelet_registry_pull_qps,
  #$kubelet_client_ca_file,
  #$kubelet_disable_readonly_port,
  Optional[Integer] $kubelet_max_pods,
  Optional[String] $kubelet_node_status_update_frequency,
  Optional[String] $kubelet_allowed_unsafe_sysctls,
  Optional[Integer] $kubelet_verbose,
  Optional[Integer] $kubelet_oom_score_adj,
#  $kubelet_system_reserved,
  Hash $kubelet_eviction_hard,
  Optional[Hash] $kubelet_feature_gates,
#  $kubelet_eviction_soft,
#  $kubelet_eviction_soft_grace_period,
#  $kubelet_eviction_max_pod_grace_period,
#  $kubelet_eviction_minimum_reclaim,
#  $kubelet_eviction_pressure_transition_period,
  Boolean $kubelet_rotate_certs,
  Boolean $server_tls_bootstrap,

#  Optional $proxy_via,


  #etcd kube
  Enum['external', 'staticpod', 'systemd'] $etcd_kube_type,
  String $etcd_kube_version,
  String $etcd_kube_image,
  Stdlib::Absolutepath $etcd_kube_datapath,
  Stdlib::Absolutepath $etcd_kube_pki_path,
  String $etcd_kube_postfix,
  Integer $etcd_kube_peerport,
  Integer $etcd_kube_clientport,
  Boolean $etcd_kube_client_cert_auth,
  Optional[Stdlib::Absolutepath] $etcd_kube_key_file,
  Optional[Stdlib::Absolutepath] $etcd_kube_cert_file,
  Optional[Stdlib::Absolutepath] $etcd_kube_trusted_ca_file,
  Boolean $etcd_kube_peer_client_cert_auth,
  Optional[Stdlib::Absolutepath] $etcd_kube_peer_key_file,
  Optional[Stdlib::Absolutepath] $etcd_kube_peer_cert_file,
  Optional[Stdlib::Absolutepath] $etcd_kube_peer_trusted_ca_file,
  Optional[String] $etcd_kube_cluster,
  Optional[String] $etcd_kube_cluster_token,
  Optional[String] $etcd_kube_initial_cluster_state,
  Integer $etcd_kube_heartbeat_interval,
  Integer $etcd_kube_election_timeout,
  Integer $etcd_kube_snapshot_count,
  Optional[String] $etcd_kube_peer_name,

  Enum['calico', 'manual'] $networking_model,

  Enum['addon', 'dns-horizontal-autoscaling', 'nodelocal-dns-cache' ] $coredns_type,
  String $coredns_image,
  String $coredns_version,
  Integer $coredns_replicas,
  String $coredns_config,

  ) {

  exec { "systemctl-daemon-reload-${name}":
    path        => ['/usr/bin', '/bin'],
    command     => 'systemctl daemon-reload',
    refreshonly => true,
  }

  package { 'iproute2': }
  package { 'ipvsadm': }
  package { 'iptables': }
  package { 'socat': }
  package { 'cri-tools': }
  #package { 'conntrack': }

#  kmod::load { 'ip_vs': }
#  kmod::load { 'ip_vs_rr': }
#  kmod::load { 'ip_vs_wrr': }
#  kmod::load { 'ip_vs_sh': }

  if $container_runtime == 'docker' {
    include kubernetes::docker
  } elsif $container_runtime == 'manual' {
    notify {'Install container runtime manualy': }
  } else {
    fail(sprintf('%s are not supported, only docker now', $container_runtime))
  }

  if $kubernetes_cni_version {
    package {'kubernetes-cni': ensure => $kubernetes_cni_version}
  }

#  if $proxy_via {
#    include kubernetes::proxy
#  }

  include kubernetes::kubelet

  include kubernetes::kubeproxy

  if any2bool($kube_master) {
    include kubernetes::control_plane

    include kubernetes::client
    include kubernetes::coredns
    include kubernetes::addons
  }

  if $etcd_kube_peer_name {
    include kubernetes::etcd_kube
  }

  if $networking_model == 'calico' {
    include kubernetes::calico
  } elsif $networking_model == 'manual' {
    notify {'Install networking model manually': }
  } else {
    fail(sprintf('%s are not supported, only calico now', $networking_model))
  }

#node-role.kubernetes.io/master=""

}
