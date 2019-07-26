# A description of what this class does
#
# @summary A short summary of the purpose of this class
#
# @example
#   include kubernetes::calico
class kubernetes::calico (
  Enum['daemonset', 'staticpod', 'systemd'] $type,
  String[1] $manifest_template,
  String $version,
  String $image,
  String $image_cni,
  Optional[String] $backend,
  Optional[Integer] $mtu,
  Optional[String] $update_strategy,
  Optional[String] $datastore_type,
  Variant[Integer, Undef] $as,
  Variant[String, Undef] $roiter_id,
  Optional[String] $ip_autodetection_method,
  Variant[Stdlib::IP::Address::V4, Undef] $ipv4pool_cidr,
  Variant[Stdlib::IP::Address::V4, Undef] $advertise_cluster_ips,
  Optional[Boolean] $felix_prometheusmetricsenabled,
  Optional[Boolean] $felix_prometheusgometricsenabled,
  String $bgp_configuration_template,
  Boolean $mesh_enabled,
  Variant[Array[Stdlib::IP::Address::V4], Undef] $route_reflector_ips,
  String $global_bgp_peer_template,
) {

  file { [ '/opt/cni', '/opt/cni/bin', '/opt/calico', '/etc/cni', '/etc/cni/net.d', '/etc/calico' ]:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

#to do: staticpod, systemd
  if $type == 'daemonset' {
    if any2bool($kubernetes::kube_master) {
      #'kubernetes/addons/calico/3.2/calico.yaml.erb'

      file { '/etc/kubernetes/addons/calico.yaml':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template($manifest_template),
      }

      include kubernetes::client

      $bgp_configuration_file = '/etc/calico/00_bgp_configuration.yaml'

      file { $bgp_configuration_file:
        ensure  => file,
        content => template($bgp_configuration_template),
      }

      exec { 'Calico set bgp configuration':
        command => "calicoctl apply -f ${bgp_configuration_file}",
        onlyif  => 'kubectl -n kube-system get po -o wide -l k8s-app=calico-node --no-headers | grep Running',
        unless  => "calicoctl get BGPConfiguration --output=custom-columns=MESHENABLED | grep ${mesh_enabled}",
      }

      if $route_reflector_ips.is_a(Array) and $route_reflector_ips.length >= 1 {

        $route_reflector_ips.each |Integer $index, Stdlib::IP::Address::V4 $rr_ip| {
          $global_bgp_peer_file = "/etc/calico/1${index}_global_bgp_peer.yaml"

          file { $global_bgp_peer_file:
            ensure  => file,
            owner   => 'root',
            group   => 'root',
            mode    => '0644',
            content => template($global_bgp_peer_template),
          }

          exec { "Calico enable route reflector peer #${index}":
            command => "calicoctl apply -f ${global_bgp_peer_file}",
            onlyif  => 'kubectl -n kube-system get po -o wide -l k8s-app=calico-node --no-headers | grep Running',
            unless  => "calicoctl get bgpPeer | grep bgppeer-${index}",
          }
        }
      }
    }
  }
}
