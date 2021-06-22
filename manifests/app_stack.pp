#
# This class takes care of configuring a node to run HDP.
#
# @param [Boolean] create_docker_group
#   Ensure the docker group is present.
#
# @param [Boolean] manage_docker
#   Install and manage docker as part of app_stack
#
# @param [Integer] hdp_port
#   Port to access HDP service
#
# @param [String[1]] hdp_user
#   User to run HDP + all infra services as. Also owns mounted volumes
#   
# @param [String[1]] compose_version
#   The version of docker-compose to install
#
# @param [String[1]] image_repository
#   Image repository to pull images from - defaults to dockerhub.
#   Can be used for airgapped environments/testing environments
#
# @param [String[1]] image_prefix
#   Prefix that comes before each image
#   Can be used for easy name spacing under the same repository
#
# @param [String[1]] ca_server
#   URL of Puppet CA Server. If no keys/certs are provided, then 
#   HDP will attempt to provision its own certs and get them signed.
#   Either this or ca_cert_file/key_file/cert_file can be specified.
#   If autosign is not enabled, HDP will wait for the certificate to be signed
#   by a puppet administrator
#
# @param [String[1]] ca_cert_file
#   CA certificate to validate connecting clients
#   This or ca_server can be specified
#
# @param [String[1]] key_file
#   Private key for cert_file - pem encoded.
#   This or ca_server can be specified
#
# @param [String[1]] cert_file
#   Puppet PKI cert file - pem encoded.
#   This or ca_server can be specified
#
# @param [String[1]] dns_name
#   Name that puppet server will find HDP at.
#   Should match the names in cert_file if provided.
#   If ca_server is used instead, this name will be used as certname.
#
# @param [String[1]] hdp_version
#   The version of the HDP containers to use
#
# @param [String[1]] hdp_version
#   The version of the HDP containers to use
#
# @param [String[1]] log_driver
#   The log driver Docker will use
#
# @param [Optional[Array[String[1]]]] docker_users
#   Users to be added to the docker group on the system
#
# @param [String[1]] max_es_memory
#   Max memory for ES to use - in JVM -Xmx{$max_es_memory} format.
#   Example: 4G, 1024M. Defaults to 4G.
#
# @example Use defalts or configure via Hiera
#   include hdp::app_stack
#
# @example Manage the docker group elsewhere
#   realize(Group['docker'])
#
#   class { 'hdp::app_stack':
#     create_docker_group => false,
#     require             => Group['docker'],
#   }
#
class hdp::app_stack (
  Boolean $create_docker_group = true,
  Boolean $manage_docker = true,
  Integer $hdp_port = 9091,
  String[1] $hdp_user = '11223',
  String[1] $compose_version = '1.25.0',
  Optional[String[1]] $image_repository = undef,

  ## Either one of these two options can be configured
  Optional[String[1]] $ca_server = undef,

  Optional[String[1]] $ca_cert_file = undef,
  Optional[String[1]] $key_file = undef,
  Optional[String[1]] $cert_file = undef,


  String[1] $dns_name = "hdp.puppet",
  String[1] $image_prefix = 'puppet/hdp-',
  String[1] $hdp_version = '0.0.1',
  String[1] $log_driver = 'journald',
  String[1] $max_es_memory = '4G',
  Optional[Array[String[1]]] $docker_users = undef,
){
  if $create_docker_group {
    ensure_resource('group', 'docker', {'ensure' => 'present' })
  }

  if $manage_docker {

    class { 'docker':
      docker_users => $docker_users,
      log_driver   => $log_driver,
    }

    class { 'docker::compose':
      ensure  => present,
      version => $compose_version,
    }

  }

  file {
    default:
      owner   => 'root',
      group   => 'docker',
      require => Group['docker'],
      before  => Docker_compose['hdp'],
    ;
    '/opt/puppetlabs/hdp':
      ensure => directory,
      mode   => '0775',
      owner   => $hdp_user,
      group   => $hdp_user,
    ;
    '/opt/puppetlabs/hdp/ssl':
      ensure => directory,
      mode   => '0700',
      owner   => $hdp_user,
      group   => $hdp_user,
    ;
    '/opt/puppetlabs/hdp/docker-compose.yaml':
      ensure  => file,
      mode    => '0440',
      content => epp('hdp/docker-compose.yaml.epp', {
        'hdp_version'      => $hdp_version,
        'image_prefix'     => $image_prefix,
        'image_repository' => $image_repository,
        'hdp_port'         => $hdp_port,
        'ca_server'        => $ca_server,
        'dns_name'         => $dns_name,
        'hdp_user'         => $hdp_user,
        'root_dir'          => '/opt/puppetlabs/hdp',
        'max_es_memory'    => $max_es_memory,
      }),
    ;
  }

  docker_compose { 'hdp':
    ensure        => present,
    compose_files => [ '/opt/puppetlabs/hdp/docker-compose.yaml', ],
  }
}
