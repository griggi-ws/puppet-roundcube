# @summary custom roundcube module
# Assumes the use of puppet-php, no management within
# @param [String] php_extension_dir Extensions directory used by php
# @param [String] chartdir_version Version to install
class roundcube (
  String $roundcube_package = 'roundcube',
  Array[String] $additional_packages = ['roundcube-mysql'],
  Boolean $manage_dirs = true,
  String $configdir = '/etc/roundcube',
  String $webroot = '/var/lib/roundcube',
  String $web_owner = 'www-data',
  String $web_group = 'www-data',
  String[24] $des_key,
  Boolean $manage_preseed = false, # not implemented
  Hash $options = {},
  Hash $default_options = {
    default_host => '',
    smtp_server => 'localhost',
    smtp_port => 587,
    smtp_user => '%u',
    smtp_pass => '%p',
    support_url => '',
    product_name => 'Roundcube Webmail',
    des_key => 'O9hvdOo7glIfAEOL4ughYbw0', #Sample value provided by package, must be overridden for secure install
    plugins => [],
    skin => 'elastic',
    enable_spellcheck => 'false',
    db_dsnw => '$dbtype://$dbuser:$dbpass@$dbserver$dbport/$dbname', # values provided in dpkg-reconfigure prompts
  },
) {
  stdlib::ensure_packages($additional_packages << $roundcube_package)
  # stdlib docs indicate + operator achieves the same as merge(), but we end up with duplicated values
  $_merged_config = stdlib::merge($default_options + $options + { des_key => $des_key })

  if $manage_dirs {
    file { [$configdir, $webroot]:
      ensure => directory,
      owner  => $web_owner,
      group  => $web_group,
      mode   => '0755',
    }
  }
  file { "${configdir}/config.inc.php":
    ensure  => file,
    owner   => $web_owner,
    group   => $web_group,
    mode    => '0640',
    content => template('roundcube/config.php.erb'),
  }
}
