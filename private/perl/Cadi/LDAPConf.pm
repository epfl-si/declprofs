#!/usr/bin/perl
#
use strict;
use lib qw(/opt/dinfo/lib/perl);
use Net::LDAPS;
use Net::LDAP;

package Cadi::LDAPConf;

use vars qw{$errmsg};

sub new { # Exported
  my $class = shift;
  my  $args = (@_ == 1) ? shift : { @_ } ;
  my $self = {
      errmsg => undef,
       debug => 0,
     verbose => 0,
       trace => 0,
  };
  foreach my $arg (keys %$args) {
    $self->{$arg} = $args->{$arg};
  }
  $self->{verbose} = 1 if $self->{fake};

  my $name = $args->{name};
  unless ($name) {
    $errmsg = "No name.";
    warn "$errmsg\n";
    return;
  }
  bless $self, $class;
  return unless $self->loadconf ($name);
  return $self;
}

sub bind {
  my $self = shift;
  $self->{ldap} = $self->{nossl}
    ? new Net::LDAP  ($self->{host})
    : new Net::LDAPS ($self->{host})
    ;
  return $self->error ("Unable to contact LDAP server $self-{host}")
    unless $self->{ldap};
  
  my $status = $self->{ldap}->bind (
          dn => $self->{user},
    password => $self->{password},
     version => 3,
  );
  return $self->error ("Unable to bind to LDAP server $self->{host} : ", $status->error)
    if $status->code;
  return $self->{ldap};
}

sub search {
  my ($self, %args) = @_;
  my $status = $self->{ldap}->search (
    base => $self->{base},
    %args, 
  );
  return $status;
}

sub loadconf {
  my ($self, $confkey) = @_;
  my @confdirs = (
    '/etc',
    '/usr/local/etc',
    '/opt/dinfo/etc',
    '/var/www/vhosts/tequila.epfl.ch/private/Tequila'
  );
  my $confdir;
  if ($ENV {CONFDIR}) {
    $confdir = $ENV {CONFDIR};
    open (CONF, "$confdir/ldapconf.conf") || 
      return $self->error ("Unable to read LDAPConf config file ($confdir/ldapconf.conf) : $!");
    close (CONFDIR);
  } else {
    foreach my $dir (@confdirs) {
      if (open (CONF, "$dir/ldapconf.conf")) {
        $confdir = $dir;
        last;
      }
    }
    return $self->error ("Unable to read LDAPConf config file (tried @confdirs) : $!")
      unless $confdir;
  }
  while (<CONF>) {
    chomp; next if /^#/;
    my ($key, $host, $base, $user, $password) = split (/\s+/);
    if ($key eq $confkey) {
          $self->{host} = $host;
          $self->{base} = $base;
          $self->{user} = $user;
      $self->{password} = $password;
      return 1;
    }
  }
  close (CONF);
  return $self->error ("Unable to find key $confkey in LDAPConf config file")
}

sub error {
  my $self = shift;
  $self->{errmsg} = join (' ', @_);
  my $now = scalar localtime;
  warn "[$now] [LDAPConf] $self->{errmsg}.\n";
  return;
}


1;
