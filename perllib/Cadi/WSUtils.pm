#!/usr/bin/perl
#
use strict;
use Encode;
use Crypt::Rijndael;

use lib qw(/opt/dinfo/lib/perl);
use Cadi::CadiDB;

package Cadi::WSUtils;

my $errmsg;

sub checkCaller {
  my ($req, $ws, $appname) = @_;
  error ($req, "No application.") unless $appname;
  my $appconf = loadApp ($ws, $appname);
  error ($req, "Unknown application : $appname.") unless $appconf;
  $req->    {app} = $appname;
  $req->{appconf} = $appconf;
  my $remaddr = $req->{remaddr}; # $ENV {REMOTE_ADDR};
  #
  # SSL protection.
  #
  my $sslcaller = getSSLUser ();
  if ($sslcaller) {
    my $sslcallers = $appconf->{sslcallers};
    error ($req, "$sslcaller is not allowed to use application $appname.")
      if $sslcallers->{$sslcaller};
    $req->{caller} = $sslcaller;
    return 1;
  }

  my $caller = $req->{caller} = $req->{args}->{caller};
  #
  # Check caller
  #
  my $allowedcallers = $appconf->{callers};
  if ($allowedcallers) { # Protection by caller.
    error ($req, "No caller.") unless $caller;
    error ($req, "You are not allowed to use caller $caller in application $appname.")
      unless $allowedcallers->{$caller};

    if ($req->{args}->{password}) {
      my $cryptedpasswd = $allowedcallers->{$caller}->{password};
      my  $userpassword = cryptpasswd ($req->{args}->{password});
      error ($req, "Bad password for $appname:$caller")
        unless ($userpassword eq $cryptedpasswd);
    }
  }
  #
  # Check host.
  #
  my $allowedhosts = $appconf->{hosts};
  if ($allowedhosts) { # Protection by host.
    my $ok;
    foreach my $host (keys %$allowedhosts) {
      if ($host =~ /^([\d\.]+)\/(\d+)$/) { # mask
        if (checkmask ($host, $remaddr)) {
          $ok = 1;
          last;
        }
      } else {
        if ($remaddr =~ /^\Q$host\E/) {
          $ok = 1;
          last;
        }
      }
    }
    error ($req, "Application $appname not allowed from $remaddr.")
      unless $allowedhosts->{$remaddr};
  }
  return 1;
}

sub checkmask {
  my ($mask, $remaddr) = @_;
  return unless ($mask =~ /^([\d\.]+)\/(\d+)$/); # Bad mask;
  my ($maskaddr, $masklen) = ($1, $2);
  my $nummask = unpack ("N", pack ("C4", split (/\./, $maskaddr)));
  my $onemask = unpack ('N', pack ('B32', '1'x$masklen));
  my $netmask = $nummask & $onemask;

  my $numaddr = unpack ("N", pack ("C4", split (/\./, $remaddr)));
  my $addmask = $numaddr & $onemask;
  
  return 1 if ($addmask == $netmask);
  return;
}

sub loadApp {
  my ($ws, $app) = @_;
  my $db = new Cadi::CadiDB (
    dbname => 'cadi',
      utf8 => 1,
     trace => 1,
  );
  return unless $db;
  #
  # Allowed hosts.
  #
  my $sql = qq{
    select *
      from WSAppsHosts
     where  ws = ?
       and app = ?
       and removed is null
  };
  my  $sth = $db->prepare ($sql);
  unless ($sth) {
    $errmsg = $db::errmsg;
    return;
  }
  my $rv = $sth->execute ($ws, $app);
  unless ($rv) {
    $errmsg = $db::errmsg;
    return;
  }
  my $hosts;
  while (my $host = $sth->fetchrow_hashref) {
    my $addr = $host->{addr};
    $hosts->{$addr} = $addr;
  }
  #
  # Allowed callers.
  #
  my $sql = qq{
    select *
      from WSAppsCallers
     where  ws = ?
       and app = ?
       and removed is null
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $errmsg = $db::errmsg;
    return;
  }
  my $rv = $sth->execute ($ws, $app);
  unless ($rv) {
    $errmsg = $db::errmsg;
    return;
  }
  my $callers;
  while (my $caller = $sth->fetchrow_hashref) {
    my $sciper = $caller->{sciper};
    $callers->{$sciper} = $caller;
  }
  return {
      hosts => $hosts,
    callers => $callers,
  }
}

sub addApp {
  my ($ws, $app) = @_;
  my  $db = new Cadi::CadiDB (
    dbname => 'cadi',
      utf8 => 1,
     trace => 1,
  );
  unless ($db) {
    $errmsg = $CadiDB::errmsg;
    return;
  }
  if ($app->{hosts}) {
    my $hosts = $app->{hosts};
    foreach my $addr (keys %$hosts) {
      my $sql = qq{
        insert into WSAppsHosts
           set    ws = ?,
                 app = ?,
                addr = ?,
             creator = '000000',
               added = now()
      };
      my  $sth = $db->prepare ($sql);
      unless ($sth) {
        $errmsg = $db::errmsg;
        return;
      }
      my $rv = $sth->execute ($ws, $app->{name}, $addr);
      unless ($rv) {
        $errmsg = $db::errmsg;
        return;
      }
    }
  }
  
  if ($app->{callers}) {
    my $callers = $app->{callers};
    foreach my $sciper (keys %$callers) {
      my $sql = qq{
        insert into WSAppsCallers
           set    ws = ?,
                 app = ?,
              sciper = ?,
             creator = '000000',
               added = now()
      };
      my  $sth = $db->prepare ($sql);
      unless ($sth) {
        $errmsg = $db::errmsg;
        return;
      }
      my $rv = $sth->execute ($ws, $app->{name}, $sciper);
      unless ($rv) {
        $errmsg = $db::errmsg;
        return;
      }
    }
  }
  return 1;
}

sub json_response {
  my $msg = shift;
  #$msg->{error} = 0;
  #$msg->{error_description} = '';
  my $json = json_encode ($msg);
  print qq{Access-Control-Allow-Origin: *\r\n};
  print qq{Content-type: application/json;charset=utf-8\r\n\r\n};
  print $json, "\n";
}

sub send_list {
  my ($req, $list) = @_;
  json_response ({ result => { count => scalar @$list } }) if $req->{modifiers}->{count};

  if (exists $req->{args}->{start} || exists $req->{args}->{length}) {
    my  $start = $req->{args}->{start} || 1;
    my $length = $req->{args}->{length} || 1000000;
    my  @range = splice (@$list, $start - 1, $length);
    json_response ({ result => \@range });
  } else {
    json_response ({ result => $list });
  }
}

sub json_encode {
  my $object = shift;
  if (ref $object eq 'HASH') {
    my @jsons;
    foreach my $key (sort keys %$object) {
      #next unless $object->{$key};
      $key =~ s/\\/\\\\/g;
      $key =~ s/\"/\\"/g;
      push (@jsons, '"' . $key . '":' . json_encode ($object->{$key}));
    }
    return '{' . join (', ', @jsons) . '}';
  }
  elsif (ref $object eq 'ARRAY') {
    return '[' . join (', ', map { json_encode ($_) } @$object) . ']';
  }
  # /!\ /!\ /!\ /!\ /!\ /!\ /!\ /!\
  elsif ($object =~ /^[123456789]\d*\.?\d*$/) {
    return $object;
  }
  elsif ($object eq '__TRUE__') {
    return 'true';
  }
  elsif ($object eq '__FALSE__') {
    return 'false';
  }
  else {
    $object =~ s/\\/\\\\/g;
    $object =~ s/\"/\\"/g;
    $object =~ s/\n/\\n/gs;
    $object =~ s/\t/\\t/gs;
    $object =~ s/\r//gs;
    return '"' . $object . '"';
  }
}

sub error {
  my  $req = shift;
  my  $msg = join (' ', @_);
  my $text = $req->{app}
    ? "RWS::$req->{app}::$req->{command}::error : $msg"
    : "RWS::$req->{command}::error : $msg"
    ;
  warn scalar localtime, $text, "\n";
  my $ret = {
    Status => 'ko',
    Error => {
      text => $text,
    },
  };
  $ret->{Details} = $req->{details} if $req->{details};
  my $json = json_encode ($ret);
  print qq{Access-Control-Allow-Origin: *\r\n};
  print qq{Content-type: application/json\r\n\r\n};
  print $json, "\n";
  exit unless $req->{noexitonerror};
}

sub loadreq {
  my $req;
  return if ($ENV {REQUEST_METHOD} eq 'OPTIONS');
  my  $get = $ENV {QUERY_STRING};
  my $post = '';
  if ($ENV {REQUEST_METHOD} && $ENV {REQUEST_METHOD} eq 'POST') {
    read (STDIN, $post, $ENV {CONTENT_LENGTH});
  }
  my    $all = $get . '&' . $post;
  my @fields = split (/&/, $all);
  foreach (@fields) {
    s/\+/ /g;
    s/%([0-9a-f]{2,2})/pack ("C", hex ($1))/gie;
  }
  my $args;
  foreach my $field (@fields) {
    next unless ($field =~ /=/);
    my ($name, $value) = split(/=/, $field, 2);
    $value =~ s/\s*$//; $value =~ s/^\s*//;
    $value = Encode::decode ('UTF-8', $value);
    $args->{$name} = $args->{$name} ? $args->{$name} . '|' . $value : $value;
  }
  $req->{args} = $args;
  my  $pi = $ENV {PATH_INFO}; $pi =~ s/^(\/*)//;
  my ($command, @modifiers) = split (/\//, $pi);
  $req->{command}   = $command;
  $req->{modifiers} = { map { $_, 1 } @modifiers };
  $req->{us} = $ENV {SERVER_NAME};
  $req->{me} = $ENV {SCRIPT_NAME};
  $req->{remaddr} = $ENV {REMOTE_ADDR};
  return $req;
}

sub getSSLUser {
  #warn "getSSLUser: SSL_CLIENT_VERIFY = $ENV{SSL_CLIENT_VERIFY}\n";
  return unless ($ENV {SSL_CLIENT_VERIFY} eq 'SUCCESS');
  my  $cn = $ENV {SSL_CLIENT_S_DN_CN};
  my $org = $ENV {SSL_CLIENT_S_DN_O};
  unless ($cn =~ /^[^\(]*\(CAMIPRO=(\d\d\d\d\d\d)\)$/) {
    warn "rwsgroups:getSSLUser: Invalid cn : $cn\n";
    return;
  }
  my $sciper = $1;
  return $sciper;
}

my $aeskey = '1AB3H56FF09AEF6E1AB3H56EF09AEF6E';

sub cryptpasswd {
  my $pwd = shift;
  my $aes = new Crypt::Rijndael (pack 'H*', $aeskey);
  my $padlen = 16 - (length ($pwd) % 16);
  $padlen = 0 if ($padlen == 16);
  $pwd   .= "\0" x $padlen;
  my  $c2 = $aes->encrypt ($pwd);
  return unpack ('H*', $c2);
}

sub uncryptpasswd {
  my $cpwd = shift;
  my $aes = new Crypt::Rijndael (pack 'H*', $aeskey);
  my $packed = pack 'H*', $cpwd;
  my $pwd = $aes->decrypt (pack ('H*', $cpwd));
  $pwd =~ s/\0//g;
  return $pwd;
}

my $createtables = qq{
  create table WSApps (
             id int not null auto_increment,
           name varchar(64),
         isroot char(1),
        created datetime,
        removed datetime,
    primary key (id), index (name)
  );

  create table WSAppsHosts (
             ws varchar(16) not null,
            app varchar(16) not null,
           addr varchar(16) not null,
        creator char(6)     not null,
          added datetime,
        removed datetime,
    index (ws, app)
  );
  create table WSAppsCallers (
             ws varchar(16) not null,
            app varchar(16) not null,
         sciper char(16)    not null,
       password varchar(64),
        creator char(6)     not null,
          added datetime,
        removed datetime,
    index (ws, app)
  );

  drop table WSApps, WSAppsHosts, WSAppsCallers;
  drop table WSAppsHosts, WSAppsCallers;
};

1;















