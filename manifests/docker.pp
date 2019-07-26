#docker
class kubernetes::docker {
### lint:ignore:variable_scope

  file { '/etc/docker':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0750',
  }

  if $kubernetes::docker_package_name == 'docker.io' {

    file { '/etc/docker/daemon.json':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => inline_template('<%= JSON.pretty_generate(scope["kubernetes::docker_daemon_options"]) %>'),
      require => File['/etc/docker'],
      notify  => Service['docker'],
    }

    package { $kubernetes::docker_package_name:
      ensure  => $kubernetes::docker_version,
      require => File['/etc/docker/daemon.json'],
      notify  => Service['docker'],
    }

    service { 'docker':
      ensure   => 'running',
      enable   => true,
      provider => 'systemd',
      require  => Package[$kubernetes::docker_package_name],
    }
  }
### lint:endignore
}
