#kubelet
class kubernetes::kubelet {

  exec { "systemctl-daemon-reload-${name}":
    path        => ['/usr/bin', '/bin'],
    command     => 'systemctl daemon-reload',
    refreshonly => true,
  }

  $kube_dirs = [
    '/etc/kubernetes',
    '/etc/kubernetes/manifests',
    '/var/lib/kubelet',
    '/var/lib/kubelet/pki',
    '/opt/kubernetes',
  ]

  file { $kube_dirs:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0750',
  }

  if ! defined(File[$kubernetes::kube_pki_path]) {
    file { $kubernetes::kube_pki_path:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0750',
    }
  }

  #https://github.com/kubernetes/kubernetes/blob/master/cmd/kubelet/app/server.go#L748-L763
  #Rules for client rotation and the handling of kube config files:
  #
  #1. If the client provides only a kubeconfig file, we must use that as the initial client
  #   kubeadm needs the initial data in the kubeconfig to be placed into the cert store
  #2. If the client provides only an initial bootstrap kubeconfig file, we must create a
  #   kubeconfig file at the target location that points to the cert store, but until
  #   the file is present the client config will have no certs
  #3. If the client provides both and the kubeconfig is valid, we must ignore the bootstrap
  #   kubeconfig.
  #4. If the client provides both and the kubeconfig is expired or otherwise invalid, we must
  #   replace the kubeconfig with a new file that points to the cert dir
  #
  #The desired configuration for bootstrapping is to use a bootstrap kubeconfig and to have
  #the kubeconfig file be managed by this process. For backwards compatibility with kubeadm,
  #which provides a high powered kubeconfig on the master with cert/key data, we must
  #bootstrap the cert manager with the contents of the initial client config.

  #bootstrap kubeconfig for kubelet
  unless any2bool($kubernetes::kube_master) {
    kubernetes::kubeconfig { $kubernetes::kubelet_kubeconfig_bootstrap:
      ca        => $kubernetes::kube_ca,
      cluster   => $kubernetes::kube_cluster,
      apiserver => $kubernetes::kube_apiserver,
      user      => 'tls-bootstrap-token-user',
      token     => "${kubernetes::token_id}.${kubernetes::token_secret}",
    }
  } else {
    #kubeconfig for kubelet
    kubernetes::kubeconfig { $kubernetes::kubelet_kubeconfig:
      ca        => $kubernetes::kube_ca,
      cluster   => $kubernetes::kube_cluster,
      apiserver => $kubernetes::kube_apiserver,
      user      => $kubernetes::kubelet_kubeconfig_user,
      token     => $kubernetes::kubelet_kubeconfig_token,
      crt       => $kubernetes::kubelet_kubeconfig_crt,
      key       => $kubernetes::kubelet_kubeconfig_key,
    }
  }

  ###install kubelet
  if any2bool($kubernetes::kubelet_package_manage) {
    file { '/usr/local/bin/kubelet':
      ensure => absent,
    }

    package { 'kubelet':
      ensure => "${kubernetes::kube_version}-${kubernetes::kube_package_postfix}",
    }

    File[$kube_dirs] -> Package['kubelet'] -> Service['kubelet']

    $kubelet_bin = '/usr/bin/kubelet'

  } else {
    package { 'kubelet':
      ensure => absent,
    }

    $kubelet_dirs = [
      '/opt/kubernetes',
      "/opt/kubernetes/${kubernetes::kube_version}",
      "/opt/kubernetes/${kubernetes::kube_version}/bin/",
    ]

    file { $kubernetes::kubelet_dirs:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }

    $kubeletfile = "/opt/kubernetes/${kubernetes::kube_version}/bin/kubelet"

    File[$kube_dirs]
      -> File["/opt/kubernetes/${kubernetes::kube_version}/bin/"]
      -> Archive[$kubeletfile]
      -> Service['kubelet']

    archive { $kubeletfile:
      path    => $kubeletfile,
      source  => "https://storage.googleapis.com/kubernetes-release/release/v${kubernetes::kube_version}/bin/linux/amd64/kubelet",
      cleanup => false,
      user    => 'root',
      group   => 'root',
      creates => $kubeletfile,
      notify  => Service['kubelet'],
    }

    exec { 'kubectl +x':
      command     => "chmod +x ${kubeletfile}",
      subscribe   => Archive[$kubeletfile],
      refreshonly => true,
    }

    file { '/usr/local/bin/kubelet':
      ensure => link,
      target => $kubeletfile,
      notify => Service['kubelet'],
    }

    $kubelet_bin = '/usr/local/bin/kubelet'

  }

  file { '/etc/systemd/system/kubelet.service':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('kubernetes/systemd/kubelet.systemd.erb'),
    notify  => [ Exec["systemctl-daemon-reload-${name}"], Service['kubelet'], ],
  }

  file { '/var/lib/kubelet/config.yaml':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template("kubernetes/kubelet.config.${kubernetes::kubelet_config_version}.erb"),
    notify  => Service['kubelet'],
  }

  file { '/etc/systemd/system/kubelet.service.d/10-kubeadm.conf':
    ensure => absent,
    notify => [ Exec["systemctl-daemon-reload-${name}"], Service['kubelet'], ],
  }

  service { 'kubelet':
    ensure => 'running',
    enable => true,
  }

  unless $kubernetes::kubelet_registry_auth {
    file { $kubernetes::kubelet_config_json:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0600',
      content => inline_template('<%= JSON.pretty_generate(scope["kubernetes::kubelet_registry_auth"]) %>'),
      notify  => Service['kubelet'],
    }
  }
}
