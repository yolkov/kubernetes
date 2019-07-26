# A description of what this class does
#
# @summary A short summary of the purpose of this class
#
# @example
#   include kubernetes::etcd_kube
class kubernetes::etcd_kube {

  exec { "systemctl-daemon-reload-${name}":
    path        => ['/usr/bin', '/bin'],
    command     => 'systemctl daemon-reload',
    refreshonly => true,
  }

  $ver = $kubernetes::etcd_kube_version
  $etcd_archive = "etcd-v${ver}-linux-amd64.tar.gz"

  archive { "${etcd_archive}-etcdctl":
    path            => "/opt/${etcd_archive}",
    source          => "https://github.com/coreos/etcd/releases/download/v${ver}/${etcd_archive}",
    extract         => true,
    extract_command => "tar xfz %s --strip-components=1 -C /usr/local/bin/ etcd-v${ver}-linux-amd64/etcdctl",
    extract_path    => '/usr/local/bin',
    cleanup         => false,
    creates         => '/usr/local/bin/etcdctl'
  }

  if $kubernetes::etcd_kube_type == 'staticpod' {
    service { 'etcd-kube':
      ensure => 'stopped',
      enable => false,
    }
    file { '/usr/local/bin/etcd':
      ensure => absent,
    }
    file { '/etc/systemd/system/etcd-kube.service':
      ensure => absent,
    }

    file { '/etc/kubernetes/manifests/etcd.yaml':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('kubernetes/staticpods/etcd.yaml.erb'),
    }

  } elsif $kubernetes::etcd_kube_type == 'systemd' {
    file { '/etc/kubernetes/manifests/etcd.yaml':
      ensure => absent,
    }

    #$etcd_archive = "etcd-v${ver}-linux-amd64.tar.gz"

    #archive { "/opt/${etcd_archive}-etcd":
    #  path            => "/opt/${etcd_archive}",
    #  source          => "file:///opt/${etcd_archive}",
    #  extract         => true,
    #  extract_command => "tar xfz %s --strip-components=1 -C /usr/local/bin/ etcd-v${ver}-linux-amd64/etcd",
    #  extract_path    => '/usr/local/bin',
    #  cleanup         => false,
    #  creates         => '/usr/local/bin/etcd'
    #}

    exec { 'extract etcd':
      command => "tar xfz /opt/${etcd_archive} --strip-components=1 -C /usr/local/bin/ etcd-v${ver}-linux-amd64/etcd",
      cwd     => '/opt',
      creates => '/usr/local/bin/etcd',
      notify  => Service['etcd-kube'],
    }

    file { '/etc/systemd/system/etcd-kube.service':
      ensure  => file,
      content => template('kubernetes/systemd/etcd.systemd.erb'),
      notify  => [ Exec["systemctl-daemon-reload-${name}"], Service['etcd-kube'], ],
    }

    service { 'etcd-kube':
      ensure  => running,
      enable  => true,
      require => File['/etc/systemd/system/etcd-kube.service']
    }

  } elsif $kubernetes::etcd_kube_type == 'external' {
    service { 'etcd-kube':
      ensure => 'stopped',
      enable => false,
    }
    #file { '/usr/local/bin/etcd':
    #  ensure => absent,
    #}
    file { '/etc/systemd/system/etcd-kube.service':
      ensure => absent,
    }
    file { '/etc/kubernetes/manifests/etcd.yaml':
      ensure => absent,
    }

    notify {'Use external etcd for kubernetes': }
  } else {
    fail(sprintf('%s are not supported', $kubernetes::etcd_kube_type))
  }

  file_line { 'add etcdctl environment file':
    ensure => present,
    path   => '/root/.bashrc',
    line   => '. ~/.etcdctlrc',
  }

  file { '/root/.etcdctlrc':
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => template('kubernetes/etcdctlrc.erb'),
  }
}
