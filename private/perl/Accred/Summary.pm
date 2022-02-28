#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Summary.pm
# Description:  Resume de gestion des droits et rôles
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Fri Sep 11 12:12:37 CEST 2015
# Version:      1.0
# Revision:     
#
##############################################################################
#
#
package Accred::Summary;

use strict;
use utf8;

use Accred::Utils;

sub new {
  my ($class, $req) = @_;
  my $self = {
         req => $req || {},
        utf8 => 1,
      errmsg => undef,
        fake => 0,
       debug => 0,
     verbose => 0,
       trace => 0,
  };
  bless $self;
  $self->{lang} = $req->{lang} || 'en';
  Accred::Utils::import ();
  importmodules ($self, 'AccredDB');
  $self->{rightsdb} = $self->loadRightsDB ();
  return $self;
}

sub loadRightsDB {
  my $self = shift;
  my %allrights = $self->{accreddb}->dbselect (
    table => 'rights',
     what => [ 'name', 'labelfr', 'labelen' ],
      key => 'id',
  );
  my $allrights = \%allrights;

  my  %allroles = $self->{accreddb}->dbselect (
    table => 'roles',
     what => [ 'name', 'labelfr', 'labelen', 'protected'],
      key => 'id',
  );
  map { $allroles{$_}->{protected} = ($allroles{$_}->{protected} eq 'y') } keys %allroles;
  my $allroles = \%allroles;

  my @rolespersons = $self->{accreddb}->dbselect (
    table => 'roles_persons',
     what => [ 'persid', 'unitid', 'roleid' ],
    where => {
      value => 'y',
    }
  );

  my @rightspersons = $self->{accreddb}->dbselect (
    table => 'rights_persons',
     what => [ 'persid', 'unitid', 'rightid' ],
    where => {
      value => 'y',
    }
  );
  my @rights_roles = $self->{accreddb}->dbselect (
    table => 'rights_roles',
     what => [ 'rightid', 'roleid' ],
  );

  my ($adminroles, $rightsadmd, $rightsadmdby);
  foreach my $right_role (@rights_roles) {
    my $rightid = $right_role->{rightid};
    my  $roleid = $right_role->{roleid};
    push (@{$adminroles->{$rightid}},   $roleid);
    push (@{$rightsadmd->{$roleid}},    $rightid);
    push (@{$rightsadmdby->{$rightid}}, $roleid);
  }

  my ($persroles, $unitroles);
  foreach my $rolepers (@rolespersons) {
    my $persid = $rolepers->{persid};
    my $unitid = $rolepers->{unitid};
    my $roleid = $rolepers->{roleid};
    push (@{$persroles->{$persid}->{$roleid}}, $unitid);
    push (@{$unitroles->{$unitid}->{$roleid}}, $persid);
  }

  my ($persrights, $unitrights);
  foreach my $rightpers (@rightspersons) {
    my  $persid = $rightpers->{persid};
    my  $unitid = $rightpers->{unitid};
    my $rightid = $rightpers->{rightid};
    push (@{$persrights->{$persid}->{$rightid}}, $unitid);
    push (@{$unitrights->{$unitid}->{$rightid}}, $persid);
  }
  return {
       allrights => $allrights,
        allroles => $allroles,
       persroles => $persroles,
       unitroles => $unitroles,
      persrights => $persrights,
      unitrights => $unitrights,
      adminroles => $adminroles,
      rightsadmd => $rightsadmd,
    rightsadmdby => $rightsadmdby,
  };
}

sub rightsSummary {
  my ($self, $persid) = @_;
  importmodules ($self, 'Accreds', 'Units');
  my  $allrights = $self->{rightsdb}->{allrights};
  my  $persroles = $self->{rightsdb}->{persroles};
  my $unitrights = $self->{rightsdb}->{unitrights};
  my $adminroles = $self->{rightsdb}->{adminroles};
  return unless ($adminroles && keys %$adminroles);
  
  my $summary;
  foreach my $rightid (sort keys %$adminroles) {
    my @adminroles = @{$adminroles->{$rightid}};
    my $unitids;
    foreach my $roleid (sort @adminroles) {
      foreach my $unitid (@{$persroles->{$persid}->{$roleid}}) {
        $unitids->{$unitid} = 1;
      }
    }
    next unless $unitids && keys %$unitids;
    foreach my $unitid (keys %$unitids) {
      my $unitsummary;
      next unless $unitrights->{$unitid}->{$rightid};
      my @persids = @{$unitrights->{$unitid}->{$rightid}};
      map { $unitsummary->{byunits}->{$unitid}->{$rightid}->{$_} = 1; } @persids;
      map { $unitsummary->{byright}->{$rightid}->{$unitid}->{$_} = 1; } @persids;
      map { $unitsummary->{byperss}->{$_}->{$rightid}->{$unitid} = 1; } @persids;
      map { $unitsummary->{distanc}->{$_}->{$unitid} =
        $self->{accreds}->accredDistance ($_, $unitid) } @persids;
      $summary = mergesummary ($summary, $unitsummary);
      
      my $unit = $self->{units}->getUnit ($unitid);
      foreach my $child (@{$unit->{children}}) {
        my $childsummary = dorightmanager ($self, $child->{id}, $rightid);
        next unless $childsummary;
        $summary = mergesummary ($summary, $childsummary);
      }
    }
  }
  return $summary;
}

sub dorightmanager {
  my ($self, $unitid, $rightid) = @_;
  importmodules ($self, 'Accreds', 'Units');
  my $unitrights = $self->{rightsdb}->{unitrights};
  return if $self->hasrightmanager ($unitid, $rightid);
  my $summary;
  if ($unitrights->{$unitid}->{$rightid}) {
    my @persids = @{$unitrights->{$unitid}->{$rightid}};
    map { $summary->{byunits}->{$unitid}->{$rightid}->{$_} = 1; } @persids;
    map { $summary->{byright}->{$rightid}->{$unitid}->{$_} = 1; } @persids;
    map { $summary->{byperss}->{$_}->{$rightid}->{$unitid} = 1; } @persids;
    map { $summary->{distanc}->{$_}->{$unitid} =
      $self->{accreds}->accredDistance ($_, $unitid) } @persids;
  }
  my $unit = $self->{units}->getUnit ($unitid);
  foreach my $child (@{$unit->{children}}) {
    my $childsummary = $self->dorightmanager ($child->{id}, $rightid);
    next unless $childsummary;
    $summary = mergesummary ($summary, $childsummary);
  }
  return $summary;
}

sub rolesSummary {
  my ($self, $persid) = @_;
  importmodules ($self, 'Accreds', 'Units');
  return unless $self->isrolemanager ($persid);
  my   $allroles = $self->{rightsdb}->{allroles};
  my  $persroles = $self->{rightsdb}->{persroles};
  my $persrights = $self->{rightsdb}->{persrights};
  my  $unitroles = $self->{rightsdb}->{unitroles};

  my @respaccredunits =  @{$persroles->{$persid}->{2}}
    if $persroles->{$persid}->{2};
  my @adminrolesunits = @{$persrights->{$persid}->{2}}
    if $persrights->{$persid}->{2};
  my %units = map { $_, 1 } @respaccredunits, @adminrolesunits;
  return unless %units && keys %units;

  my $summary;
  foreach my $unitid (sort keys %units) {
    my $unitsummary;
    foreach my $roleid (keys %{$unitroles->{$unitid}}) {
      my $role = $allroles->{$roleid};
      next if $role->{protected};
      my @persids = @{$unitroles->{$unitid}->{$roleid}};
      map { $unitsummary->{byunits}->{$unitid}->{$roleid}->{$_} = 1; } @persids;
      map { $unitsummary->{byroles}->{$roleid}->{$unitid}->{$_} = 1; } @persids;
      map { $unitsummary->{byperss}->{$_}->{$roleid}->{$unitid} = 1; } @persids;
      map { $unitsummary->{distanc}->{$_}->{$unitid} =
        $self->{accreds}->accredDistance ($_, $unitid) } @persids;
    }
    $summary = mergesummary ($summary, $unitsummary);
    my $unit = $self->{units}->getUnit ($unitid);
    foreach my $child (@{$unit->{children}}) {
      my $childsummary = $self->dorolemanager ($child->{id});
      next unless $childsummary;
      $summary = mergesummary ($summary, $childsummary);
    }
  }
  return $summary;
}

sub dorolemanager {
  my ($self, $unitid) = @_;
  importmodules ($self, 'Accreds', 'Units');
  my $unitroles = $self->{rightsdb}->{unitroles};
  return if $self->hasrolemanager ($unitid);
  my $summary;
  if ($unitroles->{$unitid}) {
    foreach my $roleid (keys %{$unitroles->{$unitid}}) {
      my @persids = @{$unitroles->{$unitid}->{$roleid}};
      map { $summary->{byunits}->{$unitid}->{$roleid}->{$_} = 1; } @persids;
      map { $summary->{byroles}->{$roleid}->{$unitid}->{$_} = 1; } @persids;
      map { $summary->{byperss}->{$_}->{$roleid}->{$unitid} = 1; } @persids;
      map { $summary->{distanc}->{$_}->{$unitid} =
        $self->{accreds}->accredDistance ($_, $unitid) } @persids;
    }
  }
  my $unit = $self->{units}->getUnit ($unitid);
  foreach my $child (@{$unit->{children}}) {
    my $childsummary = $self->dorolemanager ($child->{id});
    next unless $childsummary;
    $summary = mergesummary ($summary, $childsummary);
  }
  return $summary;
}

sub hasrolemanager {
  my ($self, $unitid) = @_;
  my  $unitroles = $self->{rightsdb}->{unitroles};
  my $unitrights = $self->{rightsdb}->{unitrights};
  my $ret = $unitroles->{$unitid}->{2} || $unitrights->{$unitid}->{2};
  return $ret;
}

sub isrolemanager {
  my ($self, $persid) = @_;
  my  $persroles = $self->{rightsdb}->{persroles};
  my $persrights = $self->{rightsdb}->{persrights};
  return $persroles->{$persid}->{2} || $persrights->{$persid}->{2};
}

sub hasrightmanager {
  my ($self, $unitid, $rightid) = @_;
  my    $unitroles = $self->{rightsdb}->{unitroles};
  my $rightsadmdby = $self->{rightsdb}->{rightsadmdby};
  foreach my $roleid (@{$rightsadmdby->{$rightid}}) {
    return 1 if $unitroles->{$unitid}->{$roleid}
  }
  return;
}

sub isrightmanager {
  my ($self, $persid, $rightid) = @_;
  my    $persroles = $self->{rightsdb}->{persroles};
  my   $persrights = $self->{rightsdb}->{persrights};
  my $rightsadmdby = $self->{rightsdb}->{rightsadmdby};
  my $isrightmanager;
  foreach my $roleid (@{$rightsadmdby->{$rightid}}) {
    return 1 if $persroles->{$persid}->{roleid};
  }
  return;
}

sub mergesummary {
  my ($sum, $merge) = @_;
  foreach my $type (keys %$merge) {
    if (ref $merge->{$type} ne 'HASH') {
      $sum->{$type} = $merge->{$type};
      next;
    }
    foreach my $val1 (keys %{$merge->{$type}}) {
      if (ref $merge->{$type}->{$val1} ne 'HASH') {
        $sum->{$type}->{$val1} = $merge->{$type}->{$val1};
        next;
      }
      foreach my $val2 (keys %{$merge->{$type}->{$val1}}) {
        if (ref $merge->{$type}->{$val1}->{$val2} ne 'HASH') {
          $sum->{$type}->{$val1}->{$val2} = $merge->{$type}->{$val1}->{$val2};
          next;
        }
        foreach my $val3 (keys %{$merge->{$type}->{$val1}->{$val2}}) {
          $sum->{$type}->{$val1}->{$val2}->{$val3} = $merge->{$type}->{$val1}->{$val2}->{$val3};
        }
      }
    }
  }
  return $sum;
}


1;


