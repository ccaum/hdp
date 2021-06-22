class { 'hdp::app_stack':
  create_docker_group => false,
  require             => Group['docker'],
}
