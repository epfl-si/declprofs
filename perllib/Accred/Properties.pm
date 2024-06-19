#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Properties.pm
# Description:  
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Mon May 17 15:12:15 CEST 2004
# Revision:     
#
##############################################################################
#
#
package Accred::Properties;

use strict;
use utf8;

use Accred::Utils;

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

sub setAccredProperty {
  my ($self, $accred, $propid, $value, $author) = @_;
  importmodules ($self, 'Logs', 'Notifier');
  my $persid = $accred->{persid};
  my $unitid = $accred->{unitid};
  my @oldval = $self->{accreddb}->dbselect (
    table => 'accreds_properties',
     what => 'value',
    where => {
      propid => $propid,
      unitid => $unitid,
      persid => $persid,
    },
  );
  if (@oldval) {
    if ($value eq 'd') {
      $self->{accreddb}->dbdelete (
        table => 'accreds_properties',
        where => {
          persid => $persid,
          unitid => $unitid,
          propid => $propid
        }
      );
    } else {
      $self->{accreddb}->dbupdate (
        table => 'accreds_properties',
          set => { value => $value },
        where => {
          persid => $persid,
          unitid => $unitid,
          propid => $propid
        }
      );
    }
  } else {
    return 1 if ($value eq 'd');
    $self->{accreddb}->dbinsert (
      table => 'accreds_properties',
        set => {
          persid => $persid,
          unitid => $unitid,
          propid => $propid,
           value => $value,
        }
    );
  }
  
  my $oldval = @oldval ? $oldval [0] : 'd';
  $self->{logs}->log (
    $author, "setaccprop",
    $persid, $unitid, $propid, $oldval, $value
  );
  $self->{notifier}->setAccredProperty ($persid, $unitid, $propid, $author)
    if $self->{notifier};

  return 1;
}

sub hasProperty {
  my ($self, $accred, $propid) = @_;
  my $policy = $self->getAccredProperty ($accred, $propid);
  if ($policy->{defined}) {
    return ($policy->{defined} eq 'y');
  }
  if ($policy->{allowed}) {
    return if ($policy->{allowed} =~ /^n/);
  }
  if ($policy->{granted}) {
    return ($policy->{granted} =~ /^y/);
  }
  return;
}

sub getAccredProperty {
  my ($self, $accred, $propid) = @_;
  my $props = $self->getAccredProperties ($accred);
  return $props->{$propid};
}

sub getAccredProperties {
  my ($self, $accred) = @_;
  importmodules ($self, 'PropsAdmin');
  my   $persid = $accred->{persid};
  my   $unitid = $accred->{unitid};
  my $statusid = $accred->{statusid};
  my  $classid = $accred->{classid};

  my %accredpolicy = $self->{accreddb}->dbselect (
    table => 'accreds_properties',
     what => [ 'propid', 'value' ],
    where => {
      unitid => $unitid,
      persid => $persid,
    },
      key => 'propid',
  );
  my $accredpolicy = \%accredpolicy;
  my   @properties = $self->{propsadmin}->listProperties ();
  my   $unitpolicy = $self->{propsadmin}->getUnitsPolicies    (  unitid => $unitid);
  my $statuspolicy = $self->{propsadmin}->getStatusesPolicies (statusid => $statusid);
  my  $classpolicy = $self->{propsadmin}->getClassesPolicies  ( classid => $classid);

  my $policies;
  foreach my $property (@properties) {
    my $propid = $property->{id};
    #
    # Defined.
    #
    my $value = $accredpolicy->{$propid}->{value};
    $policies->{$propid}->{defined} = $value;
    #
    # Allowed. One 'No' implies 'No'.
    #
    if (!$unitpolicy->{$propid}->{allowed} &&
        !$classpolicy->{$propid}->{allowed} &&
        !$statuspolicy->{$propid}->{allowed}) {
      $policies->{$propid}->{allowed} = 'n:A';
    }
    
    if ($unitpolicy->{$propid}->{allowed}      =~ /^n/) {
      $policies->{$propid}->{allowed} = $unitpolicy->{$propid}->{allowed};
    }
    elsif ($classpolicy->{$propid}->{allowed}  =~ /^n/) {
      $policies->{$propid}->{allowed} = $classpolicy->{$propid}->{allowed};
    }
    elsif ($statuspolicy->{$propid}->{allowed} =~ /^n/) {
      $policies->{$propid}->{allowed} = $statuspolicy->{$propid}->{allowed};
    }
    #
    # Granted.
    #
    #if ($unitpolicy->{$propid}->{granted} =~ /^y/) {
    #  $policies->{$propid}->{granted} = $unitpolicy->{$propid}->{granted};
    #}
    #elsif ($classpolicy->{$propid}->{granted} =~ /^y/) {
    #  $policies->{$propid}->{granted} = $classpolicy->{$propid}->{granted};
    #}
    #elsif ($statuspolicy->{$propid}->{granted} =~ /^y/) {
    #  $policies->{$propid}->{granted} = $statuspolicy->{$propid}->{granted};
    #}
    #
    if ($unitpolicy->{$propid}->{granted} =~ /^n/) {
      $policies->{$propid}->{granted} = $unitpolicy->{$propid}->{granted};
    }
    elsif ($classpolicy->{$propid}->{granted} =~ /^n/) {
      $policies->{$propid}->{granted} = $classpolicy->{$propid}->{granted};
    }
    elsif ($statuspolicy->{$propid}->{granted} =~ /^n/) {
      $policies->{$propid}->{granted} = $statuspolicy->{$propid}->{granted};
    } else {
      $policies->{$propid}->{granted} = $unitpolicy->{$propid}->{granted};
    }
  }
  return $policies;
}

sub getAllAccredProperties {
  my ($self) = @_;
  importmodules ($self, 'PropsAdmin');
  my @accreds = $self->{accreddb}->dbselect (
    table => 'accreds',
     what => [ 'persid', 'unitid', 'statusid', 'classid' ],
  );
  my @results;
  my @properties = $self->{propsadmin}->listProperties ();
  foreach my $accred (@accreds) {
    my $accprops = $self->getAccredProperties ($accred);
    foreach my $property (@properties) {
      my $propid = $property->{id};
      my $defined = $accprops->{$propid}->{defined};
      my $allowed = $accprops->{$propid}->{allowed};
      my $granted = $accprops->{$propid}->{granted};
      my $value;
      if    ($defined)          { $value = $defined; }
      elsif ($allowed =~ /^n:/) { $value = 'n'; }
      elsif ($granted =~ /^y:/) { $value = 'y'; }
      else                  { $value = 'n'; }
      push (@results, [$accred->{persid}, $accred->{unitid}, $propid, $value]);
    }
  }
  return @results;
}

sub getAllAccredsProperty {
  my ($self, $propid) = @_;
  importmodules ($self, 'Units', 'PropsAdmin');
  my @accreds = $self->{accreddb}->dbselect (
    table => 'accreds',
     what => [ 'persid', 'unitid', 'statusid', 'classid' ],
  );

  my @accprop = $self->{accreddb}->dbselect (
    table => 'accreds_properties',
     what => [ 'persid', 'unitid', 'value', ],
    where => { propid => $propid, },
  );
  my $accprop;
  foreach my $ap (@accprop) {
    $accprop->{"$ap->{persid}:$ap->{unitid}"} = $ap->{value};
  }

  my  $uniprop = $self->{propsadmin}->getUnitsPolicies (propid => $propid);
  my $children = $self->{units}->getAllChildren ();
  foreach my $unitid (keys %$uniprop) {
    $self->handsDownUnitPolicy ($uniprop, $unitid, $children);
  }

  my %staprop = $self->{accreddb}->dbselect (
    table => 'properties_status',
     what => [ 'statusid', 'allowed', 'granted' ],
    where => { propid => $propid, },
      key => 'statusid',
  );
  my $staprop = \%staprop;

  my %claprop = $self->{accreddb}->dbselect (
    table => 'properties_classes',
     what => [ 'classid', 'allowed', 'granted' ],
    where => { propid => $propid, },
      key => 'classid',
  );
  my $claprop = \%claprop;
  
  my $result;
  foreach my $accred (@accreds) {
    my   $persid = $accred->{persid};
    my   $unitid = $accred->{unitid};
    my $statusid = $accred->{statusid};
    my  $classid = $accred->{classid};
    if ($accprop->{"$persid:$unitid"}) {
      my $value = $accprop->{"$persid:$unitid"};
      $result->{"$persid:$unitid"} = $value eq 'y';
      next;
    }
    my $uniaut = $uniprop->{$unitid}->{allowed};
    my $unidef = $uniprop->{$unitid}->{granted};
    my $staaut = $staprop->{$statusid}->{allowed} || 'n';
    my $stadef = $staprop->{$statusid}->{granted} || 'n';
    my $claaut = $claprop->{$classid}->{allowed};
    my $cladef = $claprop->{$classid}->{granted};
    $claaut = $staaut if (!$claaut || $claaut eq 'd');
    $cladef = $stadef if (!$cladef || $cladef eq 'd');

    my ($aut, $def);
    $aut = (($claaut eq 'y') && ($uniaut eq 'y')) ? 1 : 0;
    $def = (($cladef eq 'y') && ($unidef eq 'y')) ? 1 : 0;

    $result->{"$persid:$unitid"} = $aut && $def ? 1 : 0;
  }
  return $result;
}

sub handsDownUnitPolicy {
  my ($self, $policies, $unitid, $children) = @_;
  foreach my $child (@{$children->{$unitid}}) {
    $policies->{$child} ||= $policies->{$unitid};
    $self->handsDownUnitPolicy ($policies, $child, $children);
  }
}



1;

