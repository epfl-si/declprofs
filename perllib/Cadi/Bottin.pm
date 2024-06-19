#!/usr/bin/perl
#
use strict;
use Cadi::CadiDB;
use Cadi::Notifier;

package Cadi::Bottin;

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

sub getPerson {
  my ($self, $persid) = @_;
  my  $db = $self->{db};
  my $sql = qq{
    select *
      from dinfo.annu
     where sciper = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Bottin::getPerson : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $persid);
  unless ($rv) {
    $self->{errmsg} = "Bottin::getPerson : $db->{errmsg}";
    return;
  }
  my @bottins;
  while (my $bottin = $sth->fetchrow_hashref) {
    push (@bottins, $bottin);
  }
  return @bottins;
}

sub getPersonUnit {
  my ($self, $persid, $unitid) = @_;
  my  $db = $self->{db};
  my $sql = qq{
    select *
      from dinfo.annu
     where sciper = ?
       and  unite = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Bottin::getPersonUnit : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $persid, $unitid);
  unless ($rv) {
    $self->{errmsg} = "Bottin::getPersonUnit : $db->{errmsg}";
    return;
  }
  my $bottin = $sth->fetchrow_hashref;
  $sth->finish;
  return $bottin;
}



1;
