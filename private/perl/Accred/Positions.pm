#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Positions.pm
# Description:  
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Thu Feb  6 14:07:19 CET 2003
# Revision:     
#
##############################################################################
#
#
package Accred::Positions;

use strict;
use utf8;

use Accred::Utils;
use Accred::Messages;

our $errmsg;

sub new {
  my ($class, $req) = @_;
  my  $self = {
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
  return $self;
}

sub listPositions {
  my ($self) = @_;
  my @positions = $self->{accreddb}->dbselect (
    table => 'positions',
     what => [ '*' ],
  );
  foreach my $position (@positions) {
    $position->{label} = ($self->{lang} eq 'en')
      ? $position->{labelen}
      : $position->{labelfr}
      ;
    $position->{restricted} = ($position->{restricted} eq 'y')
  }
  return @positions
}

sub getPosition {
  my ($self, $posid) = @_;
  return unless $posid;
  my $position = $self->{accreddb}->getObject (
     type => 'positions',
       id => $posid,
    noval => 1,
  );
  $position->{labelxx} ||= $position->{labelfr};
  $position->{labelen} ||= $position->{labelfr};

  my @posunits = $self->dbgetpositionsunits ($posid);
  foreach my $posunit (@posunits) {
    my $unitid = $posunit->{unitid};
    my  $value = $posunit->{value};
    next unless ($unitid && $value);
    $position->{authunits}->{$unitid} = $value;
  }
  $position->{label} = ($self->{lang} eq 'en')
    ? $position->{labelen}
    : $position->{labelfr}
    ;
  $position->{restricted} = ($position->{restricted} eq 'y');
  return $position;
}

sub getManyPositions {
  my ($self, @posids) = @_;
  my  $in = join (', ', map { '?' } @posids);
  my $sql = qq{
    select *
      from positions
     where id in ($in)
  };
  my $sth = $self->{accreddb}->dbsafequery ($sql, @posids) || return;
  my $positions;
  while (my $position = $sth->fetchrow_hashref) {
    my $posid = $position->{id};
    $position->{label} = ($self->{lang} eq 'en')
      ? $position->{labelen}
      : $position->{labelfr}
      ;
    $position->{restricted} = ($position->{restricted} eq 'y');
    $positions->{$posid} = $position;
  }
  $sth->finish;
  return $positions;
}

sub addPosition {
  my ($self, $labelfr, $labelxx, $labelen, $restricted, $authroots, $author) = @_;
  importmodules ($self, 'Logs');
  return unless $labelfr;
  my @positions = $self->{accreddb}->dbselect (
    table => 'positions',
     what => 'id',
    where => {
      labelfr => $labelfr,
    },
  );
  if (@positions) { # Already exists.
    $self->{errmsg} = 'Position already exists';
    return;
  }
  my $restrictval = $restricted ? 'y' : 'n';
  my $posid = $self->{accreddb}->dbinsert (
    table => 'positions',
      set => {
           labelfr => $labelfr,
           labelxx => $labelxx,
           labelen => $labelen,
        restricted => $restrictval,
    }
  );
  
  if ($authroots && @$authroots) {
    foreach my $root (@$authroots) {
      $self->{accreddb}->dbinsert (
        table => 'units_positions',
          set => {
            unitid => $root,
             posid => $posid,
             value => 'y',
          },
      );
    }
  };
  $self->{logs}->log ($author, 'addposition', $labelfr, $labelxx, $labelen, $restrictval);
  return $posid;
}

sub modifyPosition {
  my ($self, $posid, $labelfr, $labelxx, $labelen, $restricted, $author) = @_;
  importmodules ($self, 'Logs');
  return unless $posid;

  my $oldpos = $self->getPosition ($posid);
  return unless $oldpos;

  my $restrictval = $restricted ? 'y' : 'n';
  $self->{accreddb}->dbrealupdate (
    table => 'positions',
      set => {
           labelfr => $labelfr,
           labelxx => $labelxx,
           labelen => $labelen,
        restricted => $restrictval,
      },
      where => {
        id => $posid,
      },
  );
  my $newpos = $self->getPosition ($posid);
  return unless $newpos;

  my @logargs = ();
  foreach my $attr ('labelfr', 'labelxx', 'labelen', 'restricted') {
    if ($attr eq 'restricted') {
      $oldpos->{$attr} = $oldpos->{$attr} ? 'y' : 'n';
      $newpos->{$attr} = $newpos->{$attr} ? 'y' : 'n';
    }
    push (@logargs, $attr, $oldpos->{$attr}, $newpos->{$attr})
      if ($newpos->{$attr} ne $oldpos->{$attr});
  }
  return 1 unless @logargs;
  $self->{logs}->log ($author, 'modifyposition', $posid, @logargs);
  return 1;
}

sub addUnitPolicy {
  my ($self, $posid, $unitid, $value) = @_;
  if ($value eq 'd') {
    $self->{accreddb}->dbdelete (
      table => 'units_positions',
      where => {
         posid => $posid,
        unitid => $unitid,
      }
    );
  } else {
    $self->{accreddb}->dbupdate (
      table => 'units_positions',
        set => {
          value => $value,
        },
      where => {
         posid => $posid,
        unitid => $unitid,
      }
    );
  }
  return 1;
}

sub delUnitPolicy {
  my ($self, $posid, $unitid) = @_;
  $self->{accreddb}->dbdelete (
    table => 'units_positions',
    where => {
       posid => $posid,
      unitid => $unitid,
    }
  );
  return 1;
}

sub deletePosition {
  my ($self, $posid, $author) = @_;
  importmodules ($self, 'Logs');
  return unless $posid;

  my $position = $self->getPosition ($posid);
  return unless $position;

  $self->{accreddb}->dbdelete (
    table => 'positions',
    where => { id => $posid }
  );
  $self->{accreddb}->dbdelete (
    table => 'units_positions',
    where => {
      posid => $posid,
    }
  );
  $self->{logs}->log ($author, 'deleteposition', $position->{labelfr});
  return 1;
}

sub changePositions {
  my ($self, $oldposid, $newposid, $author) = @_;
  importmodules ($self, 'Logs');
  return unless ($oldposid && $newposid);
  return if ($oldposid == $newposid);

  my $position = $self->getPosition ($oldposid);
  return unless $position;
  
  my @accreds = $self->{accreddb}->dbselect (
    table => 'accreds',
     what => [ 'persid', 'unitid' ],
    where => { posid => $oldposid }
  );

  $self->{accreddb}->dbupdate (
    table => 'accreds',
      set => { posid => $newposid },
    where => { posid => $oldposid }
  );
  foreach my $accred (@accreds) {
    $self->{logs}->log ($author, "modaccr", $accred->{persid},
                        $accred->{unitid}, 'posid', $oldposid, $newposid);
  }
  return 1;
}

sub positionUsedBy {
  my ($self, $posid) = @_;
  importmodules ($self, 'Persons', 'Units');
  my @accreds = $self->{accreddb}->dbselect (
    table => 'accreds',
     what => [ 'persid', 'unitid' ],
    where => { posid => $posid },
  );
  my @ret;
  foreach my $accred (@accreds) {
    my $persid = $accred->{persid};
    my   $pers = $self->{persons}->getPerson ($persid);
    my $unitid = $accred->{unitid};
    my   $unit = $self->{units}->getUnit ($unitid);
    push (@ret, { pers => $pers, unit => $unit, });
  }
  return @ret;
}

sub positionsIsAllowedInUnit {
  my ($self, $posid, $unitid) = @_; 
  importmodules ($self, 'Units');
  my $parent = $unitid;
  while ($parent && ($parent > 0)) {
    my $value = $self->dbgetunitpositionpolicy ($posid, $parent);
    return 1 if ($value eq 'y');
    return 0 if ($value eq 'n');
    last if ($parent == -1);
    $parent = $self->{units}->getUnitParent ($parent) || -1;
  }
  return 0;
}

sub listPositionsAllowedInUnit {
  my ($self, $unitid) = @_;
  importmodules ($self, 'Units');
  return $self->listPositions () unless $unitid;
 
  my $values;
  my $parent = $unitid;
  while ($parent && ($parent > 0)) {
    my @unitspos = $self->dbgetunitspositions ($parent);
    foreach my $unitpos (@unitspos) {
      my $posid = $unitpos->{posid};
      my $value = $unitpos->{value};
      next unless ($posid && $value);
      $values->{$posid} ||= $value;
    }
    last if ($parent == -1);
    $parent = $self->{units}->getUnitParent ($parent) || -1;
  }

  my $posids;
  foreach my $posid (keys %$values) {
    next unless ($values->{$posid} eq 'y');
    $posids->{$posid} = 1;
  }
  my $positions = $self->getManyPositions (keys %$posids);
  return values %$positions;
}

sub setPositionsOfUnit {
  my ($self, $unitid, $values) = @_;

  foreach my $posid (keys %$values) {
    my $value = $values->{$posid};
    next unless (($value eq 'y') || ($value  eq 'n') || ($value  eq 'd'));
    my @oldvalues = $self->{accreddb}->dbselect (
      table => 'units_positions',
       what => 'value',
      where => {
        unitid => $unitid,
         posid => $posid,
      }
    );
    if (@oldvalues) { # update or remove
      if ($value eq 'd') { # remove
        $self->{accreddb}->dbdelete (
          table => 'units_positions',
          where => {
            unitid => $unitid,
             posid => $posid,
          }
        );
      } else { # update
        $self->{accreddb}->dbupdate (
           table => 'units_positions',
             set => { value => $value },
          where => {
            unitid => $unitid,
             posid => $posid,
          }
        );
      }
    } else { # insert
      next if ($value eq 'd');
      $self->{accreddb}->dbinsert (
        table => 'units_positions',
          set => {
            unitid => $unitid,
             posid => $posid,
             value => $value,
          },
      );
    }
  }
  return 1;
}

sub dbgetunitpositionpolicy {
  my ($self, $posid, $unitid) = @_;
  my @values = $self->{accreddb}->dbselect (
    table => 'units_positions',
     what => 'value',
    where => {
      unitid => $unitid,
       posid => $posid,
    }
  );
  return unless @values;
  return $values [0];
}

sub dbgetunitspositions {
  my ($self, $unitid) = @_;
  my @unitspos = $self->{accreddb}->dbselect (
    table => 'units_positions',
     what => [ '*' ],
    where => {
      unitid => $unitid,
    }
  );
  return @unitspos;
}

sub dbgetpositionsunits {
  my ($self, $posid) = @_;
  my @unitspos = $self->{accreddb}->dbselect (
    table => 'units_positions',
     what => [ '*' ],
    where => {
       posid => $posid,
    }
  );
  return @unitspos;
}

1;


