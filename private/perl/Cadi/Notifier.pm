#!/usr/bin/perl
#
use strict;
use Cadi::Notifier::Fuse;
use Cadi::Notifier::WS;

# FIXME: change to Cadi::Notifier, but beware of the consequences
package Notifier;


my $execmode;
if (-f '/opt/dinfo/etc/MASTER') {
  $execmode = 'prod';
} elsif (-f '/opt/dinfo/etc/SCRATCH') {
  $execmode = 'test';
} else {
  $execmode = 'dev';
}

my $configs = {
  prod => {
    wsserver => 'notifier.epfl.ch',
      wsport => 80,
      wsfile => '/cgi-bin/notify',
     verbose => 0,
    },
  test => {
    wsserver => 'test-notifier.epfl.ch',
      wsport => 80,
      wsfile => '/cgi-bin/notify',
     verbose => 1,
  },
  dev => {
    wsserver => 'dev-notifier',
      wsport => 80,
      wsfile => '/cgi-bin/notify',
     verbose => 1,
  },
};

my $errmsg;


sub notify {
  my $args = (@_ == 1) ? shift : { @_ };

  my $config = $configs->{$execmode};
  $config->{execmode} = $execmode;

  my $event = $args->{event};

  my @list = ('Cadi::Notifier::Fuse', 'Cadi::Notifier::WS');
  if ($args->{only}) {
    @list = ($args->{only})
  }

  foreach my $Notifier (@list) {
    if ($Notifier->supports ($event)) {
      my $n = $Notifier->new ($config);
      $n->call ($event, $args);
    }
  }
}


1;
