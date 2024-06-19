#!/usr/bin/perl
#
##############################################################################
#
# File Name:    PropsAdmin.pm
# Description:  
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Mon Nov  8 12:24:58 CET 2004
# Revision:     
#
##############################################################################
#
#
package Accred::PropsAdmin;

use strict;
use utf8;

use Accred::Utils;
use Accred::Messages;

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

sub listProperties {
  my ($self, %args) = @_;
  my @properties = $self->{accreddb}->listAllObjects (
    'properties', listold => $args {listold},
  );
  foreach my $property (@properties) {
    $property->{labelen} ||= $property->{labelfr};
    $property->{label} = ($self->{lang} eq 'en')
      ? $property->{labelen}
      : $property->{labelfr}
      ;
  }
  return @properties;
}

sub getProperty {
  my ($self, $propid) = @_;
  my $property = $self->{accreddb}->getObject (
    type => 'properties',
      id => $propid,
  );
  $property->{labelen} ||= $property->{labelfr};
  $property->{label} = ($self->{lang} eq 'en')
    ? $property->{labelen}
    : $property->{labelfr}
    ;
  return $property;
}

sub getPropertyFromName {
  my ($self, $propname) = @_;
  my $property = $self->{accreddb}->getObject (
    type => 'properties',
    name => $propname,
  );
  $property->{labelen} ||= $property->{labelfr};
  $property->{label} = ($self->{lang} eq 'en')
    ? $property->{labelen}
    : $property->{labelfr}
    ;
  return $property;
}

sub addProperty {
  my ($self, $name, $labelfr, $labelen, $description, $author) = @_;
  importmodules ($self, 'Logs');
  my $propid = $self->{accreddb}->dbinsert (
    table => 'properties',
      set => {
               name => $name,
            labelfr => $labelfr,
            labelen => $labelen,
        description => $description
      }
  );
  return unless $propid;
  
  $self->{logs}->log ($author, "addproperty", $propid, $name, $labelfr);
  return $propid;
}

sub modProperty {
  my ($self, $propid, $name, $labelfr, $labelen, $description, $author) = @_;
  importmodules ($self, 'Logs');
  my $oldprop = $self->getPosition ($propid);
  return unless $oldprop;

  $self->{accreddb}->dbrealupdate (
    table => 'properties',
      set => {
               name => $name,
            labelfr => $labelfr,
            labelen => $labelen,
        description => $description
      },
    where => { id => $propid },
  );

  my $newprop = $self->getPosition ($propid);
  return unless $newprop;

  my @logargs = ();
  foreach my $attr ('name', 'labelfr', 'labelxx', 'labelen', 'description') {
    push (@logargs, $attr, $oldprop->{$attr}, $newprop->{$attr})
      if ($newprop->{$attr} ne $oldprop->{$attr});
  }
  return unless @logargs;
  $self->{logs}->log ($author, 'modproperty', $propid, @logargs);
}

sub delProperty {
  my ($self, $propid, $author) = @_;
  importmodules ($self, 'Logs');
  return $self->{accreddb}->dbdelete (
    table => 'properties',
    where => { id => $propid }
  );
  $self->{logs}->log ($author, "deleteproperty", $propid);
}

#
# Status policies.
#

sub getStatusesPolicies {
  my $self = shift;
  my $args = { @_ };

  if ($args->{propid}) {
    if ($args->{statusid}) {
      my @policies = $self->{accreddb}->dbselect (
        table => 'properties_status',
         what => [ 'allowed', 'granted' ],
        where => {
            propid => $args->{propid},
          statusid => $args->{statusid},
        },
      );
      return unless @policies;
      my $policy = shift @policies;
      return {
        allowed => $policy->{allowed} . ':S' . $args->{statusid},
        granted => $policy->{granted} . ':S' . $args->{statusid},
      }
    } else {
      my @proppolicies = $self->{accreddb}->dbselect (
        table => 'properties_status',
         what => [ 'statusid', 'allowed', 'granted' ],
        where => {
           propid => $args->{propid},
        },
      );
      return unless @proppolicies;
      my $policies;
      foreach my $policy (@proppolicies) {
        my $statusid = $policy->{statusid};
        $policies->{$statusid} = {
          allowed => $policy->{allowed} . ':S' . $statusid,
          granted => $policy->{granted} . ':S' . $statusid,
        }
      }
      return $policies;
    }
  } else {
    if ($args->{statusid}) {
      my @statuspolicies = $self->{accreddb}->dbselect (
        table => 'properties_status',
         what => [ 'propid', 'allowed', 'granted' ],
        where => {
          statusid => $args->{statusid},
        },
      );
      return unless @statuspolicies;
      my $policies;
      foreach my $policy (@statuspolicies) {
        my $propid = $policy->{propid};
        $policies->{$propid} = {
          allowed => $policy->{allowed} . ':S' . $args->{statusid},
          granted => $policy->{granted} . ':S' . $args->{statusid},
        }
      }
      return $policies;
    } else {
      my $policies;
      my @allpolicies = $self->{accreddb}->dbselect (
        table => 'properties_status',
         what => [ 'propid', 'statusid', 'allowed', 'granted' ],
      );
      foreach my $policy (@allpolicies) {
        my   $propid = $policy->{propid};
        my $statusid = $policy->{statusid};
        my  $allowed = $policy->{allowed};
        my  $granted = $policy->{granted};
        $policies->{"$propid:$statusid"} = {
          allowed => $allowed . ':S' . $statusid,
          granted => $granted . ':S' . $statusid,
        } if ($allowed || $granted);
      }
      return $policies;
    }
  }
}

sub addStatusPolicy {
  my ($self, $propid, $statusid, $allowed, $granted) = @_;
  $self->{accreddb}->dbupdate (
    table => 'properties_status',
      set => {
        granted => $granted,
        allowed => $allowed,
      },
    where => {
        propid => $propid,
      statusid => $statusid,
    },
  );
  return 1;
}

sub delStatusPolicy {
  my ($self, $propid, $statusid) = @_;
  $self->{accreddb}->dbdelete (
    table => 'properties_status',
    where => {
        propid => $propid,
      statusid => $statusid,
    },
  );
  return 1;
}

#
# Class policies.
#

sub getClassesPolicies {
  my $self = shift;
  my $args = { @_ };
  if ($args->{propid}) {
    if ($args->{classid}) {
      my @policies = $self->{accreddb}->dbselect (
        table => 'properties_classes',
         what => [ 'allowed', 'granted' ],
        where => {
           propid => $args->{propid},
          classid => $args->{classid},
        },
      );
      return unless @policies;
      my $policy = shift @policies;
      return {
        allowed => $policy->{allowed} . ':C' . $args->{classid},
        granted => $policy->{granted} . ':C' . $args->{classid},
      }
    } else {
      my @proppolicies = $self->{accreddb}->dbselect (
        table => 'properties_classes',
         what => [ 'classid', 'allowed', 'granted' ],
        where => {
           propid => $args->{propid},
        },
      );
      return unless @proppolicies;
      my $policies;
      foreach my $policy (@proppolicies) {
        my $classid = $policy->{classid};
        $policies->{$classid} = {
          allowed => $policy->{allowed} . ':C' . $classid,
          granted => $policy->{granted} . ':C' . $classid,
        }
      }
      return $policies;
    }
  } else {
    if ($args->{classid}) {
      my @classpolicies = $self->{accreddb}->dbselect (
        table => 'properties_classes',
         what => [ 'propid', 'allowed', 'granted' ],
        where => {
          classid => $args->{classid},
        },
      );
      return unless @classpolicies;
      my $policies;
      foreach my $policy (@classpolicies) {
        my $propid = $policy->{propid};
        $policies->{$propid} = {
          allowed => $policy->{allowed} . ':C' . $args->{classid},
          granted => $policy->{granted} . ':C' . $args->{classid},
        }
      }
      return $policies;
    } else {
      my $policies;
      my @allpolicies = $self->{accreddb}->dbselect (
        table => 'properties_classes',
         what => [ 'propid', 'classid', 'allowed', 'granted' ],
      );
      foreach my $policy (@allpolicies) {
        my  $propid = $policy->{propid};
        my $classid = $policy->{classid};
        my $allowed = $policy->{allowed};
        my $granted = $policy->{granted};
        $policies->{"$propid:$classid"} = {
          allowed => $allowed . ':C' . $classid,
          granted => $granted . ':C' . $classid,
        } if ($allowed || $granted);
      }
      return $policies;
    }
  }
}

sub addClassPolicy {
  my ($self, $propid, $classid, $allowed, $granted) = @_;
  $self->{accreddb}->dbupdate (
    table => 'properties_classes',
      set => {
        granted => $granted,
        allowed => $allowed,
      },
    where => {
       propid => $propid,
      classid => $classid,
    },
  );
  return 1;
}

sub delClassPolicy {
  my ($self, $propid, $classid) = @_;
  $self->{accreddb}->dbdelete (
    table => 'properties_classes',
    where => {
       propid => $propid,
      classid => $classid,
    },
  );
  return 1;
}

#
# Units policies.
#

sub getUnitsPolicies {
  my $self = shift;
  my $args = { @_ };

  if ($args->{unitid}) {
    return $self->inheritPolicies ($args);
  }
  if ($args->{propid}) {
    my $policies;
    my @policies = $self->{accreddb}->dbselect (
      table => 'properties_units',
       what => [ 'unitid', 'allowed', 'granted' ],
      where => {
        propid => $args->{propid},
      },
    );
    my $policies = { map { $_->{unitid}, $_ } @policies };
    return $policies;
  } else {
    my $policies;
    my @policies = $self->{accreddb}->listAllObjects (
      'properties_units',
    );
    foreach my $policy (@policies) {
      my  $propid = $policy->{propid};
      my  $unitid = $policy->{unitid};
      my $allowed = $policy->{allowed};
      my $granted = $policy->{granted};
      $policies->{"$propid:$unitid"} = {
        allowed => $allowed . ':U' . $args->{unitid},
        granted => $granted . ':U' . $args->{unitid},
      } if ($allowed || $granted);
    }
    return $policies;
  }
  return;
}

sub addUnitPolicy {
  my ($self, $propid, $unitid, $allowed, $granted, $author) = @_;
  importmodules ($self, 'Logs');
  $self->{accreddb}->dbupdate (
    table => 'properties_units',
      set => { 
        allowed => $allowed,
        granted => $granted,
      },
    where => {
      unitid => $unitid,
      propid => $propid
    }
  );
  $self->{logs}->log ($author, "setdefprop", $unitid, $propid, $allowed, $granted);
}

sub delUnitPolicy {
  my ($self, $propid, $unitid, $author) = @_;
  importmodules ($self, 'Logs');
  $self->{accreddb}->dbdelete (
    table => 'properties_units',
    where => {
      unitid => $unitid,
      propid => $propid
    }
  );
  $self->{logs}->log ($author, "setdefprop", $unitid, $propid, 'd', 'd');
}

sub getAllUnitsProperty {
  my ($self, $propid) = @_;
  importmodules ($self, 'Units', 'Logs');
  my  $parents = $self->{units}->getAllParents ();
  my %uniprops = $self->{accreddb}->dbselect (
    table => 'properties_units',
     what => [ 'allowed', 'granted' ],
    where => { propid => $propid },
      key => 'unitid',
  );
  my $uniprops = \%uniprops;
  my $result;
  foreach my $unitid (keys %$parents) {
    next if $result->{unitid};
    my ($allowed, $granted);
    my $parent = $unitid;
    while ($parent) {
      $allowed ||= $uniprops->{$parent}->{allowed};
      $granted ||= $uniprops->{$parent}->{granted};
      last if ($allowed && $granted);
      $parent = $parents->{$parent}->{parent};
    }
    $allowed ||= 'n';
    $granted ||= 'n';
    $result->{$unitid} = {
      allowed => $allowed,
      granted => $granted,
    };
  }
  return $result;
}

sub setUnitProperty {
  my ($self, $unitid, $propid, $allowed, $granted, $author) = @_;
  importmodules ($self, 'Logs');
  $allowed = 'n' unless ($allowed =~ /^[ynd]$/);
  $granted = 'n' unless ($granted =~ /^[ynd]$/);

  my @olddef = $self->{accreddb}->dbselect (
    table => 'properties_units',
     what => [ 'allowed', 'granted' ],
    where => {
      unitid => $unitid,
      propid => $propid,
    },
  );
  my $olddef = @olddef ? $olddef [0] : undef;
  $olddef->{granted} = $olddef->{granted};
  if ($olddef) {
    return 1 if ($olddef->{allowed} eq $allowed &&
                 $olddef->{granted} eq $granted);
    if (($allowed eq 'd') && ($granted eq 'd')) {
      $self->{accreddb}->dbdelete (
        table => 'properties_units',
        where => {
          unitid => $unitid,
          propid => $propid
        }
      );
    } else {
      $self->{accreddb}->dbupdate (
        table => 'properties_units',
          set => {
            allowed => $allowed,
            granted => $granted,
          },
        where => {
          unitid => $unitid,
          propid => $propid
        }
      );
    }
  } else {
    return 1 if (($allowed eq 'd') && ($granted eq 'd'));
    $self->{accreddb}->dbinsert (
      table => 'properties_units',
        set => {
           unitid => $unitid,
           propid => $propid,
          allowed => $allowed,
          granted => $granted,
        }
    );
  }
  $self->{logs}->log ($author, "setdefprop", $unitid, $propid, $allowed, $granted);
}

sub inheritPolicies {
  my ($self, $args) = @_;
  return unless $args->{unitid};
  importmodules ($self, 'Units');
  
  my $policies;
  my @ancestors = $self->{units}->getAncestors ($args->{unitid});
  foreach my $ancestorid ($args->{unitid}, @ancestors) {
    my $where = { unitid => $ancestorid };
    $where->{propid} = $args->{propid} if $args->{propid};
    my @ancestorpolicies = $self->{accreddb}->dbselect (
      table => 'properties_units',
       what => [ 'propid', 'allowed', 'granted' ],
      where => $where,
    );
    foreach my $policy (@ancestorpolicies) {
      my  $propid = $policy->{propid};
      my $allowed = $policy->{allowed};
      my $granted = $policy->{granted};

      if ($allowed && ($allowed ne 'd')) {
        $policies->{$propid}->{allowed} ||= $allowed . ':U' . $ancestorid;
      }
      if ($granted && ($granted ne 'd')) {
        $policies->{$propid}->{granted} ||= $granted . ':U' . $ancestorid;
      }
    }
  }
  return $policies;
}



1;

