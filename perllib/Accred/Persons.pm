#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Persons.pm
# Description:  Accès à la base de données CADI des personnes
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Wed Nov 12 12:07:13 CET 2014
# Revision:     
#
##############################################################################
#
package Accred::Persons;
#
use strict;
use utf8;

use Accred::Utils;
use Accred::Local::Persons;

our $errmsg;

sub new {
  my ($class, $req) = @_;
  my  $self = {
        test => undef,
        utf8 => 1,
      errmsg => undef,
        fake => 0,
       debug => 0,
     verbose => 0,
       trace => 1,
  };
  $self->{lang} = $req->{lang} || 'en';
  $self->{personsdb} = new Accred::Local::Persons ($self);
  unless ($self->{personsdb}) {
    $errmsg = $Accred::Local::Persons::errmsg;
    return;
  }
  Accred::Utils::import ();
  bless $self;
}

sub getPersons {
  my ($self, $persid) = @_;
  return unless $persid;
  if (ref $persid eq 'ARRAY') {
    return unless @$persid;
  }
  my $pers = $self->{personsdb}->getPerson ($persid);
  $self->{errmsg} = $self->{personsdb}->{errmsg};
  return $pers;
}
*getPerson = \&getPersons;

sub getPersonFromName {
  my ($self, $name) = @_;
  my @persids = $self->{personsdb}->getPersonFromName ($name);
  $self->{errmsg} = $self->{personsdb}->{errmsg};
  return @persids;
}

sub getPersonFromNameLike {
  my ($self, $name) = @_;
  my @persids = $self->{personsdb}->getPersonFromNameLike ($name);
  $self->{errmsg} = $self->{personsdb}->{errmsg};
  return @persids;
}

sub getPersonFromNameAndFirstname {
  my ($self, $firstname, $surname) = @_;
  my @persids = $self->{personsdb}->getPersonFromNameAndFirstname (
    $firstname, $surname,
  );
  $self->{errmsg} = $self->{personsdb}->{errmsg};
  return @persids;
}

sub AlreadyExists {
  my ($self, $firstname, $surname, $birthdate, $gender) = @_;
  my $alreadyexists = $self->{personsdb}->AlreadyExists (
    $firstname, $surname, $birthdate, $gender
  );
  return $alreadyexists;
}

sub addPerson {
  my ($self, $pers, $author) = @_;
  my $persid = $self->{personsdb}->addPerson ($pers, $author);
  unless ($persid) {
    $self->{errmsg} = $self->{personsdb}->{errmsg};
    return;
  }
  importmodules ($self, 'Logs');
  $self->{logs}->log ($author, "addscip",
    $pers->{firstname}, $pers->{surname},
    $pers->{birthdate}, $pers->{gender}, $persid,
  );
  return $persid;
}

sub modPerson {
  my ($self, $pers, $author) = @_;
  unless ($pers->{id}) {
    $self->{errmsg} = "No person Id";
    return;
  }
  my $status = $self->{personsdb}->modPerson ($pers, $author);
  unless ($status) {
    $self->{errmsg} = $self->{personsdb}->{errmsg};
    return;
  }
  importmodules ($self, 'Logs');
  $self->{logs}->log (
    $author, 'modscip', $pers->{id},
    $pers->{firstname}, $pers->{surname},
    $pers->{birthdate}, $pers->{gender},
  );
  return 1;
}

sub usePerson {
  my ($self, $persid) = @_;
  my $status = $self->{personsdb}->usePerson ($persid);
  unless ($status) {
    $self->{errmsg} = $self->{personsdb}->{errmsg};
    return;
  }
  return 1;
}

sub lookForDups {
  my ($self, $firstname, $surname, $birthdate) = @_;
  my @persons = $self->{personsdb}->lookForDups (
    $firstname, $surname, $birthdate
  );
  $self->{errmsg} = $self->{personsdb}->{errmsg};
  return @persons;
}

sub searchApprox {
  my ($self, $firstname, $surname, $birthdate, $gender) = @_;
  my @persons = $self->{personsdb}->searchApprox (
    $firstname, $surname, $birthdate, $gender
  );
  $self->{errmsg} = $self->{personsdb}->{errmsg};
  return @persons;
}

#
# Camipro
#

sub hasCamiproCard {
  my ($self, $persid) = @_;
  my $camipro = $self->{personsdb}->hasCamiproCard ($persid);
  $self->{errmsg} = $self->{personsdb}->{errmsg};
  return $camipro;
}

sub errmsg {
  my $self = shift;
  return $self->{errmsg};
}

sub setverbose {
  my ($self, $verbose) = @_;
  $self->{verbose} = $verbose;
}


1;

