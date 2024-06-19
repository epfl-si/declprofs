#!/usr/bin/perl
#

use strict;
use Encode;

package Cadi::Secrets;

use vars qw{$verbose $errmsg};
my $messages;

sub new { # Exported
  my $class = shift;
  my $args = (@_ == 1) ? shift : { @_ } ;
  my $self = {
        key => undef,
     noping => undef,
       utf8 => undef,
   language => 'en',
     errmsg => undef,
    errcode => undef,
    profile => undef,
      debug => 0,
    verbose => 0,
      trace => 0,
  };
  my $key = $args->{key};
  warn "New Secrets ($key)\n" if $self->{verbose};
  unless ($key) {
    $errmsg = "No key.";
    warn "$errmsg\n";
    return;
  }
  foreach my $arg (keys %$args) {
    $self->{$arg} = $args->{$arg};
  }
  my @secrets = loadsecrets ($key);
  unless (@secrets) {
    $errmsg = "Secret $key not found in Secrets config file.";
    warn "$errmsg\n";
    return;
  }
  $self->{secrets} = \@secrets;
  initmessages ($self);
  bless $self, $class;
}

sub loadsecrets {
  my $key = shift;
  my @confdirs = (
    '/etc',
    '/usr/local/etc',
    '/opt/dinfo/etc',
    '/var/www/vhosts/tequila.epfl.ch/private/Tequila'
  );
  my $confdir;
  if ($ENV {SECRETSCONFDIR}) {
    $confdir = $ENV {SECRETSCONFDIR};
    open (CONF, "$confdir/secrets.conf") || do {
      $errmsg = "Unable to read secrets config file ($confdir/secrets.conf) : $!";
      warn "$errmsg\n";
      return;
    };
  
  }
  unless ($confdir) {
    foreach my $confd (@confdirs) {
      if (open (CONF, "$confdir/secrets.conf")) {
        $confdir = $confd;
        last;
      }
    }
  }
  unless ($confdir) {
    $errmsg = "Unable to read DB config file (tried @confdirs) : $!";
    warn "$errmsg\n";
    return;
  }

  my @secrets;
  while (<CONF>) {
    chomp; next if /^#/;
    my @fields = split (/\t+/);
    my   $fkey = shift @fields;
    if ($fkey eq $key) {
      @secrets = @fields;
      last;
    }
  }
  close (CONF);
  return @secrets;
}

1;
