#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Config.pm
# Description:  Accreds cinfig
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Wed Nov 12 10:43:34 CET 2014
# Revision:     
#
##############################################################################
#
package Accred::Config;
#
use strict;
use utf8;
#
# TODO : read config in file.
#
sub new {
  my $class = shift;
  my  %args = @_;
  my  $self = {
             verbose => undef,
            language => 'fr',
    internalworkflow => undef,
  };
  foreach my $arg (keys %args) {
    $self->{$arg} = $args {$arg};
  }
  $self->{internalworkflow} = undef;
  
  my $fr = ($self->{language} eq 'fr');
  $self->{unittypes} = {
    Orgs => {
                id => 'Orgs',
           package => 'Accred::Local::Orgs',
              name => $fr ? 'Unités' : 'Units',
          leftname => $fr ? 'Unités' : 'Units',
           myunits => $fr ? 'Mes unités': 'My units',
       lookforunit => $fr ? 'Rechercher une unité' : 'Search for an unit',
              icon => '/images/ic-unites.gif',
             order => 1,
      rolesmanager => 'adminroles',
    },
    Funds => {
                id => 'Funds',
           package => 'Accred::Local::Funds',
             title => $fr ? 'Registre des signatures' : 'Signature register',
              name => $fr ? 'Fonds' : 'Funds',
          leftname => $fr ? 'Registre' : 'Register',
           myunits => $fr ? 'Registre des signatures' : 'Signature register',
       lookforunit => $fr ? 'Rechercher un CF' : 'Search for an account',
              icon => '/images/funds.gif',
             order => 2,
      rolesmanager => 'fundadminroles',
    },
  };
  $self->{localpackages}   = {
    Notifier => {
      path => '/opt/dinfo/lib/perl',
      pack => 'Accred::Local::Notifier',
    }
  };
  bless $self, $class;
}

sub getUnitTypes {
  my $self = shift;
  return $self->{unittypes};
}


1;

