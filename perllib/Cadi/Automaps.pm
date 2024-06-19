#!/usr/bin/perl
#
use strict;
use Cadi::CadiDB;
use Cadi::Notifier;

package Cadi::Automaps;

my $messages;

sub new { # Exported
  my $class = shift;
  my  $args = (@_ == 1) ? shift : { @_ } ;
  my $self = {
      caller => undef,
          db => undef,
      errmsg => undef,
     errcode => undef,
    language => 'fr',
      notify => 1,
        fake => 0,
       debug => 0,
     verbose => 0,
       trace => 0,
    tracesql => 0,
  };
  foreach my $arg (keys %$args) {
    $self->{$arg} = $args->{$arg};
  }
  $self->{db} = new Cadi::CadiDB (
    dbname => 'dinfo',
     trace => $self->{trace},
  );
  bless $self, $class;
}

sub getAutomap {
  my ($self, $sciper) = @_;
  my  $db = $self->{db};
  my $sql = qq{
    select *
      from dinfo.automaps
     where sciper = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Automaps::getAutomap : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $sciper);
  unless ($rv) {
    $self->{errmsg} = "Automaps::getAutomap : $db->{errmsg}";
    return;
  }
  my $automap = $sth->fetchrow_hashref;
  $sth->finish;
  return $automap;
}

sub addAutomap {
  my ($self, $automap) = @_;
  my  $db = $self->{db};
  my $sql = qq{
    insert into dinfo.automaps
       set   sciper = ?,
           protocol = ?,
             server = ?,
               path = ?,
           security = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Automaps::addAutomap : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute (
    $sth,
    $automap->{sciper},
    $automap->{protocol},
    $automap->{server},
    $automap->{path},
    $automap->{security}
  );
  unless ($rv) {
    $self->{errmsg} = "Automaps::addAutomap : $db->{errmsg}";
    return;
  }
  $sth->finish;
  Notifier::notify (
     event => 'changeaccount',
    sciper => $automap->{sciper},
  ) if $self->{notify};
  return 1;
}

sub modifyAutomap {
  my ($self, $automap) = @_;
  return unless $automap->{sciper};
  return 1 unless ($automap->{protocol} ||
                   $automap->{server}   ||
                   $automap->{path}     ||
                   $automap->{security}
  );

  my @args;
  my  $db = $self->{db};
  my $sql = qq{update dinfo.automaps set};
  if ($automap->{protocol}) {
    push (@args, $automap->{protocol});
    $sql .= " protocol = ?,";
  }
  if ($automap->{server}) {
    push (@args, $automap->{server});
    $sql .= " server = ?,";
  }
  if ($automap->{path}) {
    push (@args, $automap->{path});
    $sql .= " path = ?,";
  }
  if ($automap->{security}) {
    push (@args, $automap->{security});
    $sql .= " security = ?,";
  }
  $sql =~ s/,$/ where sciper = \?/;

  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "modifyAutomap : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, @args, $automap->{sciper});
  unless ($rv) {
    $self->{errmsg} = "modifyAutomap : $db->{errmsg}";
    return;
  }
  $sth->finish;
  Notifier::notify (
     event => 'changeaccount',
    sciper => $automap->{sciper},
  ) if $self->{notify};
  return 1;
}

sub deleteAutomap {
  my ($self, $sciper) = @_;
  my  $db = $self->{db};
  my $sql = qq{delete from automaps where sciper = ?};
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "deleteAutomap : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $sciper);
  unless ($rv) {
    $self->{errmsg} = "deleteAutomap : $db->{errmsg}";
    return;
  }
  $sth->finish;
  Notifier::notify (
     event => 'changeaccount',
    sciper => $sciper,
  ) if $self->{notify};
  return 1;
}

sub errmsg {
  my $self = shift;
  return $self->{errmsg};
}

sub error {
  my ($self, $sub, $msgcode, @args) = @_;
  my  $msghash = $messages->{$msgcode};
  my $language = $self->{language} || 'en';
  my  $message = $msghash->{$language};
  $self->{errmsg} = sprintf ("$sub : $message", @args);
}


1;
