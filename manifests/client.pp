# A description of what this class does
#
# @summary A short summary of the purpose of this class
#
# @example
#   include kubernetes::client
#kubectl and calicoctl
class kubernetes::client (
  Boolean $kubectl_package,
  Optional[String] $kubectl_binary,
  Optional[String] $kubectl_hash,
  String $calicoctl_binary,
  String $calicoctl_hash,
) {

  if any2bool($kubectl_package) {
    file { '/usr/local/bin/kubectl':
      ensure => absent,
    }

    package { 'kubectl':
      ensure => "${kubernetes::kube_version}-${kubernetes::kube_package_postfix}",
    }

  } elsif $kubectl_binary and $kubectl_hash {
    package { 'kubectl':
      ensure => absent,
    }

    $kubectl_dirs = [
      "/opt/kubernetes/${kubectl_binary}",
      "/opt/kubernetes/${kubectl_binary}/bin",
    ]

    file { $kubectl_dirs:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }

    $kubectlfile = "/opt/kubernetes/${kubectl_binary}/bin/kubectl"

    archive { $kubectlfile:
      path          => $kubectlfile,
      source        => "https://storage.googleapis.com/kubernetes-release/release/${kubectl_binary}/bin/linux/amd64/kubectl",
      checksum_type => 'sha256',
      checksum      => $kubectl_hash,
      cleanup       => false,
      user          => 'root',
      group         => 'root',
      creates       => $kubectlfile,
    }
    exec { 'kubectl +x':
      command     => "chmod +x ${kubectlfile}",
      subscribe   => Archive[$kubectlfile],
      refreshonly => true,
    }

    file { '/usr/local/bin/kubectl':
      ensure => link,
      target => $kubectlfile,
    }

  } else {
    warning('Need kubectl_package or kubectl_binary with kubectl_hash')
  }

  if $kubernetes::networking_model == 'calico' and $calicoctl_binary and $calicoctl_hash {

    $calico_dirs = [
      "/opt/calico/${calicoctl_binary}",
      "/opt/calico/${calicoctl_binary}/bin",
    ]

    file { $calico_dirs:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }

    $calicoctlfile = "/opt/calico/${calicoctl_binary}/bin/calicoctl"

    #install calicoctl
    archive { $calicoctlfile:
      path          => $calicoctlfile,
      source        => "https://github.com/projectcalico/calicoctl/releases/download/${calicoctl_binary}/calicoctl",
      checksum_type => 'sha256',
      checksum      => $calicoctl_hash,
      cleanup       => false,
      user          => 'root',
      group         => 'root',
      creates       => $calicoctlfile,
    }
    exec { 'calicoctl +x':
      command     => "chmod +x ${calicoctlfile}",
      subscribe   => Archive[$calicoctlfile],
      refreshonly => true,
    }
    file { '/usr/local/bin/calicoctl':
      ensure => link,
      target => $calicoctlfile,
    }
    file { '/etc/calico/calicoctl.cfg':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0640',
      content => template('kubernetes/calicoctl.cfg.erb'),
    }
  }
}
