# @summary custom roundcube module
# Assumes the use of puppet-php, no management within
# TODO: Add logrotate
class roundcube (
  String $roundcube_package = 'roundcube',
  Array[String] $additional_packages = ['roundcube-mysql'],
  Boolean $manage_dirs = true,
  Boolean $init_db = true,
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
  Optional[String] $db_type = 'mysql',
  Optional[String] $db_host,
  Optional[String] $db_name,
  Optional[String] $db_user,
  Optional[Variant[String,Sensitive]] $db_pass,
) {
  stdlib::ensure_packages($additional_packages << $roundcube_package)

  $_unwrapped = if $db_pass.is_a(Deferred) { Deferred('unwrap', [$db_pass]) }
  $_dsnw = if $db_pass {
    if $db_pass.is_a(Deferred) {
      { db_dsnw => Deferred('sprintf', ['%s://%s:%s@%s/%s', $db_type, $db_user, $_unwrapped, $db_host, $db_name]) }
    }
    else {
      { db_dsnw => "${db_type}://${db_user}:${db_pass.unwrap}@${db_host}/${db_name}" }
    }
  } else {
    {}
  }
  $_merged_config = $default_options + $options + { des_key => $des_key } + $_dsnw
  if $init_db {
    exec { '/usr/share/roundcube/bin/initdb.sh --dir SQL':
      cwd         => '/usr/share/roundcube',
      refreshonly => true,
      subscribe   => Package[$roundcube_package],
    }
  }
  if $manage_dirs {
    file { [$configdir, $webroot]:
      ensure => directory,
      owner  => $web_owner,
      group  => $web_group,
      mode   => '0755',
    }
  }
  cron { 'roundcube: database cleanup':
    command => '/usr/share/roundcube/bin/cleandb.sh',
    user    => 'root',
    hour    => 2,
    minute  => 0,
  }
  file { "${configdir}/config.inc.php":
    ensure  => file,
    owner   => $web_owner,
    group   => $web_group,
    mode    => '0640',
    content => stdlib::deferrable_epp('roundcube/config.php.epp', { config => $_merged_config }),
  }
}
