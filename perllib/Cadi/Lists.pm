#!/usr/bin/perl
#

use strict;
use Net::LDAP;
use Net::LDAPS;
use Cadi::CadiDB;

package Lists;

my $debug = 0;
my $trace = 0;
my $listserver = 'listes.epfl.ch';
my   $listport = (-f '/opt/dinfo/etc/MASTER') ? 4321 : 4322;

sub addGroup {
  updateGroup  (@_);
}

sub deleteGroup {
  my $group = shift;
  removeList ($group->{name});
}

sub updateGroup {
  my $group = shift;
  my $gname = $group->{name};
  $gname =~ tr/A-Z/a-z/;
  error ('updateGroup', "gname = $gname") if $trace;

  return unless ($group->{persons} && @{$group->{persons}});
  my $emails;
  foreach my $person (@{$group->{persons}}) {
    my $sciper = $person->{id};
    my  $email = $person->{email};
    next unless $email;
    $emails->{$sciper} ||= $email;
  }
  my @emails = values %$emails;
  updateList   ($gname, @emails);
  updateStatus ($group);
}

sub checkGroup {
  my $group = shift;
  my $gname = $group->{name};
  $gname =~ tr/A-Z/a-z/;
  error ('checkGroup', "gname = $gname") if $trace;

  return unless ($group->{persons} && @{$group->{persons}});
  my @scipers = map { $_->{id} } @{$group->{persons}};
  my %scipers = map { $_, 1    } @scipers;
  my  @inlist = getList ($group);
  my  %inlist = map { $_, 1 } @inlist;
  
  my $ok = 1;
  foreach my $sciper (@scipers) {
    if (!$inlist {$sciper}) { $ok = 0; last; }
  }
  if ($ok) {
    foreach my $sciper (@inlist) {
      if (!$scipers {$sciper}) { $ok = 0; last; }
    }
  }
  if (!$ok) {
    error ('checkGroup', "List differs for group $gname");
    return;
  }
}

sub addMember {
  updateGroup (@_);
}

sub deleteMember {
  updateGroup (@_);
}

use IO::Socket::INET;

sub updateList {
  my ($gname, @emails) = @_;
  error ('updateList', "gname = $gname, emails = @emails") if $trace;
  my $sock = new IO::Socket::INET (
    PeerAddr => $listserver,
    PeerPort => '$listport',
  );
  unless ($sock) {
    error ('updateList', "Unable to open socket to listes.epfl.ch : $!");
    return;
  }
  $gname =~ tr/A-Z/a-z/;
  print $sock "UPDATE $gname\n";
  foreach my $email (@emails) {
    print $sock "$email\n";
  }
  print $sock "\n";
  my $rep = <$sock>;
  close ($sock);
}

sub updateStatus {
  my  $group = shift;
  my  $gname = $group->{name};
  my $status = $group->{listext} ? 'open' : 'close';
  $gname =~ tr/A-Z/a-z/;
  
  error ('updateStatus', "gname = $gname, status = $status") if $trace;
  my $sock = IO::Socket::INET->new (
    PeerAddr => $listserver,
    PeerPort => $listport,
       Proto => 'tcp',
  );
  unless ($sock) {
    error ('updateStatus', "Unable to open socket to listes.epfl.ch : $!");
    return;
  }
  $sock->print ("STATUS $gname $status\n");
  $sock->close;
}

sub removeList {
  my $gname = shift;
  error ('removeList', "gname = $gname") if $trace;
  my $sock = new IO::Socket::INET (
    PeerAddr => $listserver,
    PeerPort => '$listport',
  );
  return unless $sock;
  $gname =~ tr/A-Z/a-z/;
  print $sock "UPDATE $gname\n\n";
  my $rep = <$sock>;
  close ($sock);
}

sub getList {
  my $group = shift;
  my $sock = new IO::Socket::INET (
    PeerAddr => $listserver,
    PeerPort => '$listport',
  );
  return unless $sock;

  my ($status, @emails);
  my $gname = $group->{name};
  $gname =~ tr/A-Z/a-z/;
  my $inheader = 1;
  print $sock "LIST $gname\n";
  while (<$sock>) {
    chomp;
    if ($inheader) {
      if (/^status:\s+(.*)$/) {
        $status = $1;
        next;
      }
      unless ($_) {
        $inheader = 0;
        next;
      }
    }
    last unless $_;
    push (@emails, $_);
  }
  close ($sock);
  my $db = new Cadi::CadiDB (dbname => 'dinfo');
  return unless $db;

  my $in = join (', ', map { '?' } @emails);
  my $sql = qq{
    select sciper
      from dinfo.emails
     where addrlog in ($in)
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    error ('getList', $db->{errmsg});
    return;
  }
  my $rv = $db->execute ($sth, @emails);
  unless ($rv) {
    error ('getList', $db->{errmsg});
    return;
  }
  my $scipers = $sth->fetchall_arrayref ([0]);
  my @scipers = map { $_->[0] } @$scipers;
  return @scipers;
}

sub error {
  my ($sub, $msg) = @_;
  warn scalar localtime, "Lists::$sub $msg.";
}

1;




