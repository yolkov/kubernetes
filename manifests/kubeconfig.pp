#define for generate kubeconfig
define kubernetes::kubeconfig (
  $cluster   = 'kubernetes',
  $apiserver = undef,
  $ca        = undef,
  $user      = undef,
  $token     = undef,
  $crt       = undef,
  $key       = undef,
) {

  file { $title:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => template('kubernetes/kubeconfig.yaml.erb'),
  }
}
