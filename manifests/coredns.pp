# A description of what this class does
#
# @summary A short summary of the purpose of this class
#
# @example
#   include kubernetes::coredns
class kubernetes::coredns {

  if $kubernetes::coredns_type == 'addon' {
    file { '/etc/kubernetes/addons/coredns.rbak.yaml':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('kubernetes/addons/coredns.rbak.yaml.erb'),
    }

    file { '/etc/kubernetes/addons/kube-dns.service.yaml':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('kubernetes/addons/kube-dns.service.yaml.erb'),
    }

    file { '/etc/kubernetes/addons/coredns.configmap.yaml':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('kubernetes/addons/coredns.configmap.yaml.erb'),
    }

    file { '/etc/kubernetes/addons/coredns.deployment.yaml':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('kubernetes/addons/coredns.deployment.yaml.erb'),
    }
  } elsif $kubernetes::coredns_type == 'nodelocal-dns-cache' {

  }
}
