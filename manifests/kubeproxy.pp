# A description of what this class does
#
# @summary A short summary of the purpose of this class
#
# @example
#   include kubernetes::kubeproxy
class kubernetes::kubeproxy (

  # kube-proxy
  String $version,
  String $image,
  Optional[String] $hash,
  Enum['daemonset', 'staticpod', 'systemd'] $type,
  Enum['v1alpha1', 'v1alpha3', 'v1beta1'] $config_version,
  Optional[Stdlib::Absolutepath] $kubeconfig,
  Optional[String] $kubeconfig_user,
  Optional[String] $kubeconfig_token,
  Optional[Stdlib::Absolutepath] $kubeconfig_crt,
  Optional[Stdlib::Absolutepath] $kubeconfig_key,
  Optional[String] $mode,
  Optional[Integer] $oom_score_adj,
  Optional[String] $metrics_bind_address,
  Optional[Integer] $conntrack_max_per_core,
  Optional[Integer] $conntrack_min,
  Optional[String] $conntrack_tcp_timeout_close_wait,
  Optional[String] $conntrack_tcp_timeout_established,
  Optional[Integer] $burst,
  Optional[Integer] $qps,
  Optional[Hash[String, Boolean]] $feature_gates,
  #Variant[Stdlib::IP::Address::V4, String[0]] $cluster_cidr,
  Variant[Stdlib::IP::Address::V4, Pattern[/^null$/]] $ipvs_exclude_cidr,
  Optional[String] $update_strategy,

) {

  exec { "systemctl-daemon-reload-${name}":
    path        => ['/usr/bin', '/bin'],
    command     => 'systemctl daemon-reload',
    refreshonly => true,
  }
  if $type != 'daemonset' {
    #kubeconfig for proxy
    kubernetes::kubeconfig { $kubeconfig:
      ca        => $kubernetes::kube_ca,
      cluster   => $kubernetes::kube_cluster,
      apiserver => $kubernetes::kube_apiserver,
      user      => $kubeconfig_user,
      token     => $kubeconfig_token,
      crt       => $kubeconfig_crt,
      key       => $kubeconfig_key,
    }
  }

  $cluster_cidr = $kubernetes::cluster_cidr

  if $type == 'staticpod' {
    $daemonset_files = [
      '/etc/kubernetes/addons/kube-proxy.serviceaccount.yaml',
      '/etc/kubernetes/addons/kube-proxy.clusterrolebindings.yaml',
      '/etc/kubernetes/addons/kube-proxy.config.yaml',
      '/etc/kubernetes/addons/kube-proxy.daemonset.yaml',
    ]
    file { $daemonset_files:
      ensure => absent,
    }
    service { 'kube-proxy':
      ensure => 'stopped',
      enable => false,
    }
    file { '/usr/local/bin/kube-proxy':
      ensure => absent,
    }
    file { '/etc/systemd/system/kube-proxy.service':
      ensure => absent,
    }
    file { '/etc/kubernetes/manifests/proxy.yaml':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('kubernetes/staticpods/kube-proxy.yaml.erb'),
    }
  } elsif $type == 'systemd' {
    $daemonset_files = [
      '/etc/kubernetes/addons/kube-proxy.serviceaccount.yaml',
      '/etc/kubernetes/addons/kube-proxy.clusterrolebindings.yaml',
      '/etc/kubernetes/addons/kube-proxy.config.yaml',
      '/etc/kubernetes/addons/kube-proxy.daemonset.yaml',
    ]
    file { $daemonset_files:
      ensure => absent,
    }
    file { '/etc/kubernetes/manifests/proxy.yaml':
      ensure => absent,
    }

    $kubeproxy_dirs = [
      "/opt/kubernetes/${version}",
      "/opt/kubernetes/${version}/bin",
    ]

    file { $kubeproxy_dirs:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }

    $kubeproxyfile = "/opt/kubernetes/${version}/bin/kube-proxy"

    archive { $kubeproxyfile:
      path          => $kubeproxyfile,
      source        => "https://storage.googleapis.com/kubernetes-release/release/${version}/bin/linux/amd64/kube-proxy",
      checksum_type => 'sha256',
      checksum      => $hash,
      cleanup       => false,
      user          => 'root',
      group         => 'root',
      creates       => $kubeproxyfile,
    }

    exec { 'kubectl +x':
      command     => "chmod +x ${kubeproxyfile}",
      subscribe   => Archive[$kubeproxyfile],
      refreshonly => true,
    }

    file { '/usr/local/bin/kube-proxy':
      ensure => link,
      target => $kubeproxyfile,
      notify => Service['kube-proxy'],
    }

    file { '/etc/systemd/system/kube-proxy.service':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      notify  => [ Exec["systemctl-daemon-reload-${name}"], Service['kube-proxy'] ],
      content => template('kubernetes/systemd/kube-proxy.systemd.erb'),
    }
    service { 'kube-proxy':
      ensure => 'running',
      enable => true,
    }
  } elsif $type == 'daemonset' {
    service { 'kube-proxy':
      ensure => 'stopped',
      enable => false,
    }
    file { '/usr/local/bin/kube-proxy':
      ensure => absent,
    }
    file { '/etc/systemd/system/kube-proxy.service':
      ensure => absent,
    }
    file { '/etc/kubernetes/manifests/proxy.yaml':
      ensure => absent,
    }

    if any2bool($kubernetes::kube_master) {

      File['/etc/kubernetes/addons'] -> File['/etc/kubernetes/addons/kube-proxy.daemonset.yaml']

      $apiserver = $kubernetes::kube_apiserver

      file { '/etc/kubernetes/addons/kube-proxy.serviceaccount.yaml':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('kubernetes/addons/kube-proxy.serviceaccount.yaml.erb'),
      }

      file { '/etc/kubernetes/addons/kube-proxy.clusterrolebindings.yaml':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('kubernetes/addons/kube-proxy.clusterrolebindings.yaml.erb'),
      }

      file { '/etc/kubernetes/addons/kube-proxy.config.yaml':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template("kubernetes/addons/kube-proxy.config.${config_version}.yaml.erb"),
      }

      file { '/etc/kubernetes/addons/kube-proxy.daemonset.yaml':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('kubernetes/addons/kube-proxy.daemonset.yaml.erb'),
      }
    }

  } else {
    fail(sprintf('%s are not supported, only daemonset,systemd,staticpod', $type))
  }

}
