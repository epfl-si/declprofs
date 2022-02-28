#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Units.pm
# Description:  
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Wed Nov 12 10:51:22 CET 2014
# Revision:     
#
##############################################################################
#
#
package Accred::Units;

use strict;
use Carp;

use Accred::Utils;

my $errmsg;

sub new {
  my ($class, $req) = @_;
  my  $self = {
        req => $req || {},
    verbose => 0,
  };
  foreach my $arg (keys %$req) {
    $self->{$arg} = $req->{$arg};
  }
  my @utypes = ( 'Orgs', 'Funds', );
  push (@INC, '/opt/dinfo/lib/perl');
  foreach my $utype (@utypes) {
    my $pack;
    my $toeval = qq{
      require "Accred/Local/${utype}.pm";
      \$pack = "Accred::Local::$utype"->new (\$self);
    };
    eval $toeval || die "Unable to load Accred::Local::$utype : $@";
    $self->{$utype} = $pack;
  }
  $self->{utypes} = \@utypes;
  #setCache ();
  $self->{dateref} = $self->{req}->{dateref};
  bless $self, $class;
}

sub getUnits {
  my ($self, $unitid) = @_;
  my @unitids = (ref $unitid eq 'ARRAY') ? @$unitid : ( $unitid );
  my $in = join (', ', map { '?' } @unitids);
  my $utypes;
  foreach my $unitid (@unitids) {
    my $utype = $self->getUnitTypeId ($unitid);
    next unless $utype;
    push (@{$utypes->{$utype}}, $unitid);
  }
  my $units;
  foreach my $utype (keys %$utypes) {
    my @unitids = @{$utypes->{$utype}};
    my $utunits = $self->{$utype}->getUnits (\@unitids);
    foreach my $unitid (keys %$utunits) {
      $units->{$unitid} = $utunits->{$unitid};
      $units->{$unitid}->{type} = $utype;
    }
  }
  return (ref $unitid eq 'ARRAY') ? $units : $units->{$unitid};
}
*getUnit = \&getUnits;

sub getUnitType {
  my ($self, $unitid) = @_;
  my $utypeid = $self->getUnitTypeId ($unitid);
  return unless ($utypeid && $self->{$utypeid});
  return $self->{$utypeid}->getUnitType ();
}

sub getUnitTypeFromTypeId {
  my ($self, $utypeid) = @_;
  return $self->{$utypeid}->getUnitType ();
}

sub listUnitTypes {
  my ($self) = @_;
  my @unittypes;
  foreach my $utype (@{$self->{utypes}}) {
    my $unittype = $self->{$utype}->getUnitType ();
    push (@unittypes, $unittype);
  }
  return @unittypes;

}

sub getRoots {
  my ($self) = @_;
  my @allroots;
  foreach my $utype (@{$self->{utypes}}) {
    my @roots = $self->{$utype}->getRoots ();
    push (@allroots, @roots);
  }
  return @allroots;
}

sub expandUnitsList {
  my ($self, @unitids) = @_;
  my $utypes;
  foreach my $unitid (@unitids) {
    my $utype = $self->getUnitTypeId ($unitid);
    next unless $utype;
    push (@{$utypes->{$utype}}, $unitid);
  }
  my @retids;
  foreach my $utype (keys %$utypes) {
    my @unitids = @{$utypes->{$utype}};
    my    @uids = $self->{$utype}->expandUnitsList (@unitids);
    push (@retids, @uids);
  }
  return @retids;
}

sub getUnitFromName {
  my ($self, $name) = @_;
  foreach my $utype (@{$self->{utypes}}) {
    my $unit = $self->{$utype}->getUnitFromName ($name);
    return $unit if $unit;
  }
  return;
}

sub getAllUnits {
  my ($self, @utypes) = @_;
  @utypes = ('Orgs'); # TODO
  my $allunits;
  foreach my $utype (@utypes) {
    my $units = $self->{$utype}->getAllUnits ();
    map { $allunits->{$_} = $units->{$_} } keys %$units;
  }
  return $allunits;
}

sub getAllUnitsTree {
  my ($self, @utypes) = @_;
  @utypes = ('Orgs'); # TODO
  my $allunits;
  foreach my $utype (@utypes) {
    my $units = $self->{$utype}->getAllUnitsTree ();
    map { $allunits->{$_} = $units->{$_} } keys %$units;
  }
  return $allunits;
}

sub listChildren {
  my ($self, $unitid) = @_;
  return unless $unitid;
  my $utype = $self->getUnitTypeId ($unitid);
  return unless $utype;
  return $self->{$utype}->listChildren ($unitid);
}

sub getAllChildren {
  my $self = shift;
  return $self->{allchildren} if $self->{allchildren};
  #warn scalar localtime, " INFO:getAllChildren:Loading cache.\n";
  my $children;
  foreach my $utype (@{$self->{utypes}}) {
    my $uchildren = $self->{$utype}->getAllChildren ();
    map { $children->{$_} = $uchildren->{$_} } keys %$uchildren;
  }
  $self->{allchildren} = $children;
  #warn scalar localtime, " INFO:getAllChildren:Cache loaded.\n";
  return unless $children;
}

sub listDescendantsIds {
  my ($self, $unitid) = @_;
  my $utype = $self->getUnitTypeId ($unitid);
  return unless $utype;
  return $self->{$utype}->listDescendantsIds ($unitid);
}

sub getAllParents {
  my ($self) = @_;
  my $parents;
  foreach my $utype (@{$self->{utypes}}) {
    my $uparent = $self->{$utype}->getAllParents ();
    map { $parents->{$_} = $uparent->{$_} } keys %$uparent;
  }
  return $parents;
}

sub getAncestors {
  my ($self, $unitid) = @_;
  my $utype = $self->getUnitTypeId ($unitid);
  return unless $utype;
  return $self->{$utype}->getAncestors ($unitid);
}

sub getAllAncestors {
  my ($self) = @_;
  my $ancestors;
  foreach my $utype (@{$self->{utypes}}) {
    my $uancestors = $self->{$utype}->getAllAncestors ();
    foreach my $unitid (keys %$uancestors) {
      $ancestors->{$unitid} = $uancestors->{$unitid};
    }
  }
  return $ancestors;
}

sub getUnitParent {
  my ($self, $unitid) = @_;
  my $utype = $self->getUnitTypeId ($unitid);
  return unless $utype;
  return $self->{$utype}->getUnitParent ($unitid);
}

sub getUnitSubtree {
  my ($self, $unitid) = @_;
  my $utype = $self->getUnitTypeId ($unitid);
  return unless $utype;
  return $self->{$utype}->getUnitSubtree ($unitid);
}

sub getUnitSubtreeAsSubtree {
  my ($self, $unitid) = @_;
  my $utype = $self->getUnitTypeId ($unitid);
  return unless $utype;
  return $self->{$utype}->getUnitSubtreeAsSubtree ($unitid);
}

sub getUnitTypeId {
  my ($self, $unitid) = @_;
  return unless $unitid;
  return 'Orgs'  if ($unitid =~ /^\d+/);
  return 'Funds' if ($unitid =~ /^F/);
  return;
}

sub getDependsOnOrgUnits {
  my ($self, %optargs) = @_;
  my $allunitdeps;
  foreach my $utype (@{$self->{utypes}}) {
    next if ($utype eq 'Orgs');
    my $unitdeps = $self->{$utype}->getDependsOnOrgUnits (%optargs);
    foreach my $orgid (keys %$unitdeps) {
      push (@{$allunitdeps->{$orgid}}, @{$unitdeps->{$orgid}});
    }
  }
  return $allunitdeps;
}

sub getDependsOnOrgUnit {
  my ($self, $unitid, %optargs) = @_;
  my $utype = $self->getUnitTypeId ($unitid);
  return unless ($utype eq 'Orgs');
  my @dependson;
  foreach my $utype (@{$self->{utypes}}) {
    next if ($utype eq 'Orgs');
    my @dounits = $self->{$utype}->getDependsOnOrgUnit ($unitid, %optargs);
    push (@dependson, @dounits) if @dounits;
  }
  return @dependson;
}

sub setCache {
  *getAllChildren = Accred::Utils::cache (\&getAllChildren, 3600);
}

sub error {
  my $msg = shift;
  my $i = 0;
  my $client = $ENV {REMOTE_ADDR};
  my $stack = "@_ from $client, stack = \n";
  while (my ($pack, $file, $line, $subname, $hasargs, $wanrarray) = caller ($i++)) {
    $stack .= "$file:$line\n";
  }
  my $now = scalar localtime;
  $errmsg = "[$now] [Accred warning] : $msg : $stack";
  warn "[$now] $errmsg\n";
  return;
}

1;
