#!/usr/bin/perl
#
##############################################################################
#
# File Name:    UnitsAdmin.pm
# Description:  
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Fri Jan 17 17:34:12 CET 2014
# Revision:     
#
##############################################################################
#
#
package Accred::UnitsAdmin;

use strict;
use utf8;

use Accred::Utils;

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

my  $cmpltypes = {
  S => "Unité structurelle",
  F => "Unité financière",
  E => "Unité d'enseignement",
  A => "Autre unité",

  O => "Uniquement visible dans l'Organigramme officiel",
  X => "Visible uniquement dans Annuaire WEB + ACCRED",
  Z => "Non visible Annuaire WEB, mais visible ACCRED",
};

my $structtypes = {
  struct => "Unité structurelle",
  financ => "Unité financière",
  enseig => "Unité d'enseignement",
  autres => "Autre unité",
};

my $affichages = {
    F => 'Faculté, 1e niveau',
  COL => 'Collège, 1e niveau',
    S => 'Section, 2e niveau',
  PRG => 'Programme, 2e niveau',
    I => 'Institut, 3e niveau',
    C => 'Centre, 4e niveau',
    P => 'Présidence, 1e niveau',
  PAI => 'Affaires institutionnelles, 1e niveau',
  PIV => 'Innovation et Valorisation, 1e niveau',
  PAA => 'Affaires académique, 1e niveau',
  PSI => 'Systèmes d’information, 1e niveau',
   PL => 'Planification et Logistique, 1e niveau',
};

my $visitypes = {
  organi => "Visible dans l'Organigramme officiel",
     web => "Visible dans l'annuaire Web",
  accred => "Visible dans Accred",
};

sub getUnit {
  my ($self, $unitid) = @_;
  my $field = ($unitid =~ /^\d.*$/) ? 'id' : 'name';
  my  $unit = $self->{accreddb}->getObject (
      type => 'orgs',
    $field => $unitid,
  );
  return $unit;
}

sub loadChildren {
  my ($self, $unitid) = @_;
  my @children = ();
  return @children;
}

sub loadHierarchy {
  my ($self, $unit) = @_;
  return ();
}

sub loadAllUnits {
  my $self = shift;
  return ();
}

sub addUnit {
  my ($self, $unit) = @_;
  importmodules ($self, 'Persons');
  error ($self, msg('NoName'))  unless $unit->{name};
  error ($self, msg('NoLabel')) unless $unit->{labelfr};
  error ($self, msg('InvalidManagerSciper', $unit->{respid}))
    if ($unit->{respid} && !$self->{persons}->getPerson ($unit->{respid}));
  return 1;
}

sub modUnit {
  my ($self, $unit, $author) = @_;
  importmodules ($self, 'Logs');
  #$self->{logs}->log ($author, "modifyunit", $mods);
  return 1;
}

sub delUnit {
  my ($self, $unitid) = @_;
  return 1;
}

sub listunittypes {
  my $self = shift;
  return ();
}

sub listlanguages {
  my $self = shift;
  return;;

}

sub error {
  my ($self, @msgs) = @_;
  $errmsg = "Accred::UnitsAdmin::error::" . join (' ', @msgs);
  warn "$errmsg\n";
  return;
}


1;


