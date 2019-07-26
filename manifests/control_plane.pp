# A description of what this class does
#
# @summary A short summary of the purpose of this class
#
# @example
#   include kubernetes::control_plane
class kubernetes::control_plane (
###apiserver###
  Optional[String] $apiserver_image,
  Optional[String] $apiserver_version,
#generic flags
  Optional[String] $apiserver_advertise_address,
  Optional[Array] $apiserver_feature_gates,
  Optional[Integer] $apiserver_max_requests_inflight,
  Optional[Integer] $apiserver_target_ram_mb,
#Etcd flags
  Optional[Stdlib::Absolutepath] $apiserver_etcd_cafile,
  Optional[Stdlib::Absolutepath] $apiserver_etcd_certfile,
  Optional[Stdlib::Absolutepath] $apiserver_etcd_keyfile,
#Secure serving flags
  Optional[Stdlib::IP::Address::V4] $apiserver_bind_address,
  Optional[Integer] $apiserver_http2_max_streams,
  Optional[Integer] $apiserver_secure_port,
  Optional[Stdlib::Absolutepath] $apiserver_tls_cert_file,
  Optional[Stdlib::Absolutepath] $apiserver_tls_private_key_file,
#Insecure serving flags
  Optional[Integer] $apiserver_insecure_port,
#Auditing flags
  Optional[Integer] $apiserver_audit_log_batch_buffer_size,
  Optional[Integer] $apiserver_audit_log_batch_max_size,
  Optional[String] $apiserver_audit_log_batch_max_wait,
  Optional[Integer] $apiserver_audit_log_maxage,
  Optional[Integer] $apiserver_audit_log_maxsize,
  Optional[Stdlib::Absolutepath] $apiserver_audit_log_path,
  Optional[String] $apiserver_audit_log_mode,
  Optional[Stdlib::Absolutepath] $apiserver_audit_policy_file,
#Features flags
  Optional[Boolean] $apiserver_profiling,
  Optional[Boolean] $apiserver_swagger_ui,
#Authentication flags
  Optional[Boolean] $apiserver_anonymous_auth,
  Optional[Stdlib::Absolutepath] $apiserver_client_ca_file,
  Optional[Boolean] $apiserver_bootstrap_token_auth,
  Optional[Stdlib::Absolutepath] $apiserver_oidc_ca_file,
  Optional[String] $apiserver_oidc_client_id,
  Optional[String] $apiserver_oidc_groups_claim,
  Optional[String] $apiserver_oidc_issuer_url,
  Optional[String] $apiserver_oidc_username_claim,
  Optional[Array[Stdlib::Absolutepath]] $apiserver_service_account_key_files,
#Authorization flags
  Optional[String] $apiserver_authorization_mode,
#Api enablement flags
  Optional[String] $apiserver_runtime_config,
#Admission flags
  Optional[Stdlib::Absolutepath] $apiserver_admission_control_file,
  Optional[String] $apiserver_disable_admission_plugins,
  Optional[String] $apiserver_enable_admission_plugins,
#Misc flags
  Optional[Integer] $apiserver_count,
  Optional[String] $apiserver_endpoint_reconciler_type,
  Optional[Stdlib::Absolutepath] $apiserver_kubelet_ca,
  Optional[Stdlib::Absolutepath] $apiserver_kubelet_client_cert,
  Optional[Stdlib::Absolutepath] $apiserver_kubelet_client_key,
  Optional[String] $apiserver_kubelet_preferred_address_types,
#Global flags
  Optional[Integer] $apiserver_verbose,


###controller-manager
  Optional[String] $controller_image,
  Optional[String] $controller_version,
  Optional[Stdlib::IP::Address::V4] $controller_service_cluster_ip_range,
  Optional[Stdlib::Absolutepath] $controller_cluster_signing_cert_file,
  Optional[Stdlib::Absolutepath] $controller_cluster_signing_key_file,
  Optional[String] $controller_controllers,
  Optional[Array] $controller_feature_gates,
  Optional[Stdlib::Absolutepath] $controller_root_ca_file,
  Optional[Stdlib::Absolutepath] $controller_service_account_private_key_file,
  Optional[Boolean] $controller_use_service_account_credentials,
  Optional[String] $controller_node_monitor_period,
  Optional[String] $controller_node_monitor_grace_period,
  Optional[String] $controller_pod_eviction_timeout,
  Optional[Integer] $controller_http2_max_streams,
  Optional[Integer] $controller_verbose,

#scheduler
  Optional[String] $scheduler_image,
  Optional[String] $scheduler_version,
  Optional[Array] $scheduler_feature_gates,
  Optional[Integer] $scheduler_http2_max_streams,
  Optional[Integer] $scheduler_verbose,


  ###addon-manager
  Boolean $addon_manager_enable,
  String $addon_manager_image,
  String $addon_manager_version,
  Optional[Integer] $addon_manager_check_interval,
  Optional[String] $addon_manager_extra_prune_whitelist,

) {
  file { [ '/etc/kubernetes/audit', '/etc/kubernetes/addons' ]:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0750',
  }

  $apiserver_service_cluster_ip_range = $kubernetes::service_cluster_ip_range
  $apiserver_etcd_servers = $kubernetes::apiserver_etcd_servers

  file { '/etc/kubernetes/manifests/kube-apiserver.yaml':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => template('kubernetes/staticpods/apiserver.yaml.erb'),
  }
  if $apiserver_audit_policy_file {
    file { $apiserver_audit_policy_file:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => template('kubernetes/audit.policy.yaml.erb'),
    }
  }
  $controller_cluster_cidr = $kubernetes::cluster_cidr

  $controller_node_cidr_mask_size = $kubernetes::node_cidr_mask_size
  $controller_kubeconfig = any2bool($kubernetes::controller_kubeconfig)
  $controller_allocate_node_cidrs = any2bool($kubernetes::controller_allocate_node_cidrs)

  if $controller_kubeconfig {
    kubernetes::kubeconfig { '/etc/kubernetes/controller-manager.conf':
      ca        => $kubernetes::kube_ca,
      cluster   => $kubernetes::kube_cluster,
      apiserver => $kubernetes::kube_apiserver,
      user      => 'system:kube-controller-manager',
      crt       => $kubernetes::controller_kubeconfig_crt,
      key       => $kubernetes::controller_kubeconfig_key,
    }
  }
  file { '/etc/kubernetes/manifests/kube-controller-manager.yaml':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => template('kubernetes/staticpods/controller-manager.yaml.erb'),
  }

  $scheduler_kubeconfig = any2bool($kubernetes::scheduler_kubeconfig)

  if $scheduler_kubeconfig {
    kubernetes::kubeconfig { '/etc/kubernetes/scheduler.conf':
      ca        => $kubernetes::kube_ca,
      cluster   => $kubernetes::kube_cluster,
      apiserver => $kubernetes::kube_apiserver,
      user      => 'system:kube-scheduler',
      crt       => $kubernetes::scheduler_kubeconfig_crt,
      key       => $kubernetes::scheduler_kubeconfig_key,
    }
  }
  file { '/etc/kubernetes/manifests/kube-scheduler.yaml':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => template('kubernetes/staticpods/scheduler.yaml.erb'),
  }

  if any2bool($addon_manager_enable) {

    file { '/etc/kubernetes/manifests/addon-manager.yaml':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => template('kubernetes/staticpods/addon-manager.yaml.erb'),
    }
  }

  #for kubelet TLS bootstraping
  file { '/etc/kubernetes/addons/kubelet-bootstrap.clusterrolebindings.yaml':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('kubernetes/addons/kubelet-bootstrap.clusterrolebindings.yaml.erb'),
  }
  file { '/etc/kubernetes/addons/node-autoapprove-bootstrap.clusterrolebindings.yaml':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('kubernetes/addons/node-autoapprove-bootstrap.clusterrolebindings.yaml.erb'),
  }
  file { '/etc/kubernetes/addons/node-autoapprove-certificate-rotation.clusterrolebindings.yaml':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('kubernetes/addons/node-autoapprove-certificate-rotation.clusterrolebindings.yaml.erb'),
  }
  file { '/etc/kubernetes/addons/bootstrap.token.yaml':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => template('kubernetes/addons/bootstrap.token.yaml.erb'),
  }
}
