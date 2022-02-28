#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Rights.pm
# Description:  
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Thu Feb  6 14:07:19 CET 2003
# Revision:     
#
##############################################################################
#
#
package Accred::Rights;

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

sub getRights {
  my ($self, %args) = @_;
  my $args = \%args;
  my $fromaccreds = $self->getRightsFromAccreds       ($args) unless $args->{explicit};
  my  $fromrights = $self->getRightsFromRightsOrRoles ($args);
  #
  # Merge values.
  #
  my $values = $fromrights;
  foreach my $rightid (keys %$fromaccreds) {
    my $rvalues = $fromaccreds->{$rightid};
    foreach my $unitid (keys %$rvalues) {
      my $uvalues = $rvalues->{$unitid};
      foreach my $persid (keys %$uvalues) {
        my $accredvalue = $fromaccreds->{$rightid}->{$unitid}->{$persid};
        $values->{$rightid}->{$unitid}->{$persid} ||= $accredvalue;
      }
    }
  }
  return $values;
}

sub getRightsFromRightsOrRoles {
  my ($self, $args) = @_;
  importmodules ($self, 'Units', 'Roles', 'RightsAdmin');
  if ($args->{rightid} && ($args->{rightid} !~ /^\d+$/)) { # Accept right names.
    my $right = $self->{rightsadmin}->getRight ($args->{rightid});
    $args->{rightid} = $right->{id};
  }
  my $rootids;
  if ($args->{rootids}) {
    my @rootids = (ref $args->{rootids} eq 'ARRAY')
      ? @{$args->{rootids}}
      : ($args->{rootids})
      ;
    $rootids = [ $self->{units}->expandUnitsList (@rootids) ];
  }
  my @ancestorids;
  if ($args->{unitid}) {
    @ancestorids = $self->{units}->getAncestors ($args->{unitid});
  }
  #
  # Direct rights
  #
  my @allvalues;
  #
  # Special case, we must examine ancestors.
  #
  if ($args->{unitid}) {
    my $where = {
      unitid => [ $args->{unitid}, @ancestorids ],
    };
    $where->{persid}  = $args->{persid}  if $args->{persid};
    $where->{rightid} = $args->{rightid} if $args->{rightid};
    my @values =  $self->{accreddb}->dbselect (
      table => 'rights_persons',
       what => [ '*', ],
      where => $where,
    );
    my $rights;
    foreach my $value (@values) {
      my $rightid = $value->{rightid};
      my  $unitid = $value->{unitid};
      my  $persid = $value->{persid};
      $rights->{$rightid}->{$persid}->{$unitid} = $value->{value};
    }
    foreach my $rightid (keys %$rights) {
      foreach my $persid (keys %{$rights->{$rightid}}) {
        my $value;
        foreach my $ancestorid ($args->{unitid}, @ancestorids) {
          my $rightval = $rights->{$rightid}->{$persid}->{$ancestorid};
          my $rel = ($ancestorid == $args->{unitid}) ? 'D' : 'H';
          if ($rightval) {
            $value = {
              rightid => $rightid,
               unitid => $args->{unitid},
               persid => $persid,
                value => "$rightval:$rel:$ancestorid",
            };
            last;
          }
        }
        push (@allvalues, $value) if $value;
      }
    }
  } else {
    my $where = {};
    $where->{persid}  = $args->{persid}  if $args->{persid};
    $where->{rightid} = $args->{rightid} if $args->{rightid};
    $where->{unitid}  = $rootids if $rootids;
    my @rightpers =  $self->{accreddb}->dbselect (
      table => 'rights_persons',
       what => [ '*' ],
      where => $where,
    );
    foreach my $rpers (@rightpers) {
      $rpers->{value} .= ":D:$rpers->{unitid}";
      push (@allvalues, $rpers);
    }
  }
  goto aggregate if $args->{explicit};
  #
  # Via roles
  #
  my @rightsroles = $self->{accreddb}->dbselect (
    table => 'rights_roles',
     what => [ 'rightid', 'roleid' ],
  );
  my $rightsroles;
  foreach my $rightrole (@rightsroles) {
    my  $roleid = $rightrole->{roleid};
    my $rightid = $rightrole->{rightid};
    $rightsroles->{$rightid}->{$roleid} = 1;
  }
  my @rightids;
  if ($args->{rightid}) {
    @rightids = ($args->{rightid});
  } else {
    @rightids = $self->{accreddb}->dbselect (
      table => 'rights',
       what => 'id',    
    );
  }
  #
  # Fetch all applicable role and use it.
  #
  my $nroles = 0;
  foreach my $rightid (@rightids) {
    foreach my $roleid (keys %{$rightsroles->{$rightid}}) {
      $nroles++;
    }
  }
  my $rupall;
  if ($nroles > 3) {
    $rupall = $self->{roles}->getRoles (
        unitid => $args->{unitid},
        persid => $args->{persid},
       rootids => $args->{rootids},
      noexpand => $args->{noexpand},
    );
  }
  foreach my $rightid (@rightids) {
    foreach my $roleid (keys %{$rightsroles->{$rightid}}) {
      my $rup = $rupall ? $rupall : $self->{roles}->getRoles (
          roleid => $roleid,
          unitid => $args->{unitid},
          persid => $args->{persid},
         rootids => $args->{rootids},
        noexpand => $args->{noexpand},
      );
      foreach my $unitid (keys %{$rup->{$roleid}}) {
        foreach my $persid (keys %{$rup->{$roleid}->{$unitid}}) {
          my $value = $rup->{$roleid}->{$unitid}->{$persid};
          $value =~ s/^([yn]):./$1:R:$roleid/;
          push (@allvalues, {
            rightid => $rightid,
             unitid => $unitid,
             persid => $persid,
              value => $value,
          });
        }
      }
    }
  }
  #
  # Aggregate values.
  #
  aggregate:
  my $values;
  foreach my $value (@allvalues) {
    my $rightid = $value->{rightid};
    my  $unitid = $value->{unitid};
    my  $persid = $value->{persid};
    my   $value = $value->{value};
    $values->{$rightid}->{$unitid}->{$persid} ||= $value;
  }
  return $values if $args->{noexpand}; # No children heritage.
  #
  # Hands down to children units.
  #
  unless ($args->{unitid}) {
    my $children = $self->{units}->getAllChildren ();
    foreach my $rightid (keys %$values) {
      foreach my $unitid (keys %{$values->{$rightid}}) {
        $self->handsDownRights ($values, $rightid, $unitid, $children);
      }
    }
  }
  return $values;
}

sub handsDownRights {
  my ($self, $values, $rightid, $unitid, $children) = @_;
  my $unitvalue = $values->{$rightid}->{$unitid};
  foreach my $childid (@{$children->{$unitid}}) {
    foreach my $persid (keys %{$values->{$rightid}->{$unitid}}) {
      my $value = $unitvalue->{$persid};
      $value =~ s/:D:/:H:/g;
      $values->{$rightid}->{$childid}->{$persid} ||= $value;
    }
    $self->handsDownRights ($values, $rightid, $childid, $children);
  }
}

sub getDeputiesOf {
  my ($self, $persid) = @_;
  $self->{deputies} ||= $self->{roles}->getDeputiesNow ();
  $self->{deputyseen}->{$persid} = 1; # Avoid loops.
  my @alldeputyids;
  foreach my $roleid (keys %{$self->{deputies}->{$persid}}) {
    foreach my $unitid (keys %{$self->{deputies}->{$persid}->{$roleid}}) {
      my @deputyids = @{$self->{deputies}->{$persid}->{$roleid}->{$unitid}};
      push (@alldeputyids, @deputyids);
      foreach my $deputyid (@deputyids) {
        my @deputyids = $self->getDeputiesOf ($deputyid);
        
      }
    }
  }
}

sub getRightsFromAccreds {
  my ($self, $args) = @_;

  importmodules ($self, 'Units', 'RightsAdmin');
  if ($args->{rightid} && ($args->{rightid}!~ /^\d+$/)) { # Accept right names.
    my $right = $self->{rightsadmin}->getRight ($args->{rightid});
    $args->{rightid} = $right->{id};
  }
  #
  # Preload tables.
  #
  my @allrights = $self->{rightsadmin}->listAllRights ();
  my $allrights = { map { $_->{id}, $_ } @allrights };
  my @rightstatuses = $self->{accreddb}->dbselect (
    table => 'rights_statuses',
     what => [ 'rightid', 'statusid' ],
  );
  my ($rightstatuses, $statusrights, $rightclasses, $classrights);
  foreach my $rightstatus (@rightstatuses) {
    my   $rightid = $rightstatus->{rightid};
    my  $statusid = $rightstatus->{statusid};
    push (@{$rightstatuses->{$rightid}}, $statusid);
    push (@{$statusrights->{$statusid}}, $rightid);
  }
  my @rightclasses = $self->{accreddb}->dbselect (
    table => 'rights_classes',
     what => [ 'rightid', 'classid' ],
  );
  foreach my $rightclass (@rightclasses) {
    my   $rightid = $rightclass->{rightid};
    my  $classid = $rightclass->{classid};
    push (@{$rightclasses->{$rightid}}, $classid);
    push (@{$classrights->{$classid}},  $rightid);
  }
  #
  # Check if applies
  #
  my $rightid = $args->{rightid};
  if ($rightid) {
    return unless (($rightstatuses->{$rightid} && @{$rightstatuses->{$rightid}}) ||
                   ($rightclasses->{$rightid}  && @{$rightclasses->{$rightid}}));
    @allrights = ($allrights->{$rightid});
    $allrights = {
      $rightid => $allrights->{$rightid},
    };
  }
  my ($statuses, $classes);
  foreach my $rightid (keys %$allrights) {
    $rightstatuses->{$rightid} ||= [];
    $rightclasses->{$rightid}  ||= [];
    if (@{$rightstatuses->{$rightid}}) {
      foreach my $status (@{$rightstatuses->{$rightid}}) {
        $statuses->{$status} = 1;
      }
    }
    if (@{$rightclasses->{$rightid}}) {
      foreach my $class (@{$rightclasses->{$rightid}}) {
        $classes->{$class} = 1;
      }
    }
  }
  my $accredwhere;
  my @statuses = keys %$statuses;
  if (@statuses) {
    if (@statuses == 1) {
      $accredwhere->{statusid} = $statuses [0];
    } else {
      $accredwhere->{statusid} = \@statuses;
    }
  }
  my @classes = keys %$classes;
  if (@classes) {
    if (@classes == 1) {
      $accredwhere->{classid} = $classes [0];
    } else {
      $accredwhere->{classid} = \@classes;
    }
  }
  #
  #
  #
  my @accreds;
  $accredwhere->{persid} = $args->{persid} if $args->{persid};
  my $unitid = $args->{unitid};
  if ($unitid) {
    my $unit = $self->{units}->getUnit ($unitid);
    return unless $unit;
    if ($unit->{type} eq 'Orgs') {
      $accredwhere->{unitid} = $unitid;
      @accreds = $self->{accreddb}->dbselect (
              table => 'accreds',
               what => [ 'persid', 'unitid', 'statusid', 'classid' ],
              where => $accredwhere,
        checkbounds => 1,
      );
      return unless @accreds;
    } else {
      return unless $unit->{orgid};
      $accredwhere->{unitid} = $unit->{orgid};
      @accreds = $self->{accreddb}->dbselect (
              table => 'accreds',
               what => [ 'persid', 'unitid', 'statusid', 'classid' ],
              where => $accredwhere,
        checkbounds => 1,
      );
      return unless @accreds;
      foreach my $accred (@accreds) {
        $accred->{unitid} = $unitid;
        $accred->{orgid}  = $unit->{orgid};
      }
    }
  } else {
    if ($args->{rootids}) {
      my @rootids = (ref $args->{rootids} eq 'ARRAY')
        ? @{$args->{rootids}}
        : ($args->{rootids})
        ;
      $accredwhere->{unitid} = [ $self->{units}->expandUnitsList (@rootids) ];
    }
    @accreds = $self->{accreddb}->dbselect (
            table => 'accreds',
             what => [ 'persid', 'unitid', 'statusid', 'classid' ],
            where => $accredwhere,
      checkbounds => 1,
    );
    return unless @accreds;
  }
  #
  #
  my $allunitids;
  foreach my $accred (@accreds) {
    next unless ($accred && $accred->{unitid});
    $allunitids->{$accred->{unitid}} = 1;
  }
  my $allunitids = [ keys %$allunitids ];
  my   $allunits = $self->{units}->getUnit ($allunitids);
  my   $unitdeps = $self->{units}->getDependsOnOrgUnits (
    noexpand => $args->{noexpand},
  );
  #
  my $allowedrights;
  if ($args->{rightid}) {
    my @allowedunits = $self->allowedRights (
       unitid => $allunitids,
      rightid => $args->{rightid},
    );
    map { $allowedrights->{$_}->{$args->{rightid}} = 1 } @allowedunits;
  } else {
    $allowedrights = $self->allowedRights (
       unitid => $allunitids,
    );
  }
  my $naccreds = 0;
  my $results;
  foreach my $accred (@accreds) {
    my   $persid = $accred->{persid};
    my   $unitid = $accred->{unitid};
    my $statusid = $accred->{statusid};
    my  $classid = $accred->{classid};
    #
    # Status
    #
    if ($statusrights->{$statusid}) {
      my @rightids = $args->{rightid}
        ? ($args->{rightid})
        : @{$statusrights->{$statusid}}
        ;
      my $unit = $allunits->{$unitid};
      foreach my $rightid (@rightids) {
        my $right = $allrights->{$rightid};
        if ($right->{unittype} eq 'Orgs') {
          next unless ($unit->{type} eq 'Orgs');
          next unless $allowedrights->{$unitid}->{$rightid};
          $results->{$rightid}->{$unitid}->{$persid} = "y:S:$statusid:$unitid";
        } else {
          if ($unit->{orgid}) {
            $results->{$rightid}->{$unitid}->{$persid} = "y:S:$statusid:$accred->{orgid}";
          }
          elsif ($unitdeps->{$unitid}) {
            my @extunits = @{$unitdeps->{$unitid}};
            foreach my $extunit (@extunits) {
              next unless ($extunit->{type} eq $right->{unittype});
              next if ($args->{unitid} && ($extunit->{id} ne $args->{unitid}));
              $results->{$rightid}->{$extunit->{id}}->{$persid} = "y:S:$statusid:$unitid";
            }
          }
        }
      }
    }
    #
    # Class
    #
    if ($classrights->{$classid}) {
      my @rightids = @{$classrights->{$classid}};
      foreach my $rightid (@rightids) {
        next unless $allowedrights->{$unitid}->{$rightid};
        $results->{$rightid}->{$unitid}->{$persid} = "y:C:$classid:$unitid";
      }
    }
  }
  return $results;
}

sub printResults {
  my ($self, $results) = @_;
  foreach my $rightid (keys %$results) {
    foreach my $unitid (keys %{$results->{$rightid}}) {
      foreach my $persid (keys %{$results->{$rightid}->{$unitid}}) {
        my $value = $results->{$rightid}->{$unitid}->{$persid};
        print STDERR "$rightid:$unitid:$persid/$value ";
      }
    }
  }
}

sub getExplicitRights { # OK
  my ($self, %args) = @_;
  importmodules ($self, 'Units');
  my $args = \%args;

  my $rootids;
  if ($args->{rootids}) {
    my @rootids = (ref $args->{rootids} eq 'ARRAY')
      ? @{$args->{rootids}}
      : ($args->{rootids})
      ;
    $rootids = [ $self->{units}->expandUnitsList (@rootids) ];
  }
  my $where;
  $where->{rightid} = $args->{rightid} if $args->{rightid};
  $where->{unitid}  = $args->{unitid}  if $args->{unitid};
  $where->{persid}  = $args->{persid}  if $args->{persid};
  $where->{unitid}  = $rootids         if $rootids;
  my @results = $self->{accreddb}->dbselect (
    table => 'rights_persons',
     what => [ '*' ],
    where => $where,
  );
  my $rights;
  foreach my $result (@results) {
    my $rightid = $result->{rightid};
    my  $unitid = $result->{unitid};
    my  $persid = $result->{persid};
    my   $value = $result->{value};
    $rights->{$rightid}->{$unitid}->{$persid} = $value;
  }
  return $rights;
}

{
  my ($allowedrights, $whenfilled);
  sub allowedRights { # OK
    my ($self, %args) = @_;

    importmodules ($self, 'Units');
    my $args = \%args;
    #
    # Load cache.
    #
    if (!$allowedrights || ($whenfilled < time - 3600)) {
      #warn "INFO:allowedRights:Loading cache.\n";
      my @rightvals = $self->{accreddb}->dbselect (
        table => 'rights_units',
         what => [ '*' ],
      );
      foreach my $rightval (@rightvals) {
        my $rightid = $rightval->{rightid};
        my  $unitid = $rightval->{unitid};
        $allowedrights->{$rightid}->{$unitid} = $rightval->{value};
      }
      $whenfilled = time;
    }
    #
    my @unitids;
    if ($args->{unitid}) {
      @unitids = (ref $args->{unitid} eq 'ARRAY')
        ? @{$args->{unitid}}
        : ($args->{unitid})
        ;
    } else {
      my $allunits = $self->{units}->getAllUnits ();
      @unitids = keys %$allunits;
    }
    my $allancestorids;
    if (@unitids > 30) {
      $allancestorids = $self->{units}->getAllAncestors ();
    } else {
      foreach my $unitid (@unitids) {
        my @ancestorids = $self->{units}->getAncestors ($unitid);
        $allancestorids->{$unitid} = \@ancestorids;
      }
    }
    my $allowed;
    foreach my $unitid (@unitids) {
      my @ancestorids = $allancestorids->{$unitid}
        ? @{$allancestorids->{$unitid}} : ();
      foreach my $ancestorid ($unitid, @ancestorids) {
        if ($args->{rightid}) {
          if ($allowedrights->{$args->{rightid}}->{$ancestorid}) {
            $allowed->{$unitid} = $allowedrights->{$args->{rightid}}->{$ancestorid};
            last;
          }
        } else {
          foreach my $rightid (sort keys %$allowedrights) {
            next if exists $allowed->{$unitid}->{$rightid};
            if ($allowedrights->{$rightid}->{$ancestorid}) {
              $allowed->{$unitid}->{$rightid} = 
                ($allowedrights->{$rightid}->{$ancestorid} eq 'y');
            }
          }
        }
      }
    }
    if ($args->{rightid}) {
      if ($args->{unitid}) {
        return (ref $args->{unitid} eq 'ARRAY')
            ? keys %$allowed
            : $allowed->{$args->{unitid}};
            ;
      } else {
        return keys %$allowed;
      }
    } else {
      if ($args->{unitid}) {
        return (ref $args->{unitid} eq 'ARRAY')
            ? $allowed
            : keys %{$allowed->{$args->{unitid}}};
            ;
      } else {
        return $allowed;
      }
    }
  }
}

sub unitRightPolicy { # OK
  my ($self) = @_;
  importmodules ($self, 'Units', 'RightsAdmin');
  my @unitrights = $self->{accreddb}->dbselect (
    table => 'rights_units',
     what => [ 'rightid', 'unitid', 'value' ], 
  );
  my $allunits = $self->{units}->getAllUnits ();
  my $unitval;
  foreach my $uval (@unitrights) {
    my $rightid = $uval->{rightid};
    my  $unitid = $uval->{unitid};
    my  $value = $uval->{value};
    $unitval->{$unitid}->{$rightid} = $value;
  }
  foreach my $unitid (keys %$allunits) {
    my     $utype = $self->{units}->getUnitType ($unitid);
    my   $utypeid = $utype->{id};
    my @allrights = $self->{rightsadmin}->listAllRights ($utypeid);
    my      $unit = $allunits->{$unitid};
    my @ancestors = $unit->{ancestors} ? @{$unit->{ancestors}} : ();
    unshift (@ancestors, $unitid);
    foreach my $right (@allrights) {
      my $rightid = $right->{id};
      foreach my $ancestor (@ancestors) {
        my $ancestorval = $unitval->{$ancestor}->{$rightid};
        if ($ancestorval) {
          $unitval->{$unitid}->{$rightid} = $ancestorval;
          last;
        }
      }
      $unitval->{$unitid}->{$rightid} ||= 'y';
    }
  }
  my $result;
  foreach my $unitid (keys %$allunits) {
    foreach my $rightid (keys %{$unitval->{$unitid}}) {
      $result->{$unitid}->{$rightid} = $unitval->{$unitid}->{$rightid} eq 'y' ? 1 : 0;
    }
  }
  return $result;
}

sub isRightAdmin { # OK
  my ($self, %args) = @_;
  importmodules ($self, 'Units', 'Roles', 'RolesAdmin');
  my $args = \%args;
  return unless $args->{persid};
  my $rup = $self->{roles}->getRoles (
      unitid => $args->{unitid},
      persid => $args->{persid},
    noexpand => $args->{noexpand},
  );
  my $where;
  $where->{rightid} = $args->{rightid} if $args->{rightid};
  my @adminroles = $self->{accreddb}->dbselect (
    table => 'rights_roles',
     what => [ '*' ],
    where => $where
  );
  my $adminroles;
  foreach my $rightsroles (@adminroles) {
    my  $roleid = $rightsroles->{roleid};
    my $rightid = $rightsroles->{rightid};
    push (@{$adminroles->{$rightid}}, $roleid);
  }
  my $results;
  if ($args->{rightid} && $adminroles->{$args->{rightid}}) {
    my @roleids = @{$adminroles->{$args->{rightid}}};
    if ($args->{unitid}) {
      foreach my $roleid (@roleids) {
        return 1
          if ($rup->{$roleid}->{$args->{unitid}}->{$args->{persid}} =~ /^y/);
      }
    } else {
      my $unitids;
      foreach my $roleid (@roleids) {
        foreach my $unitid (keys %{$rup->{$roleid}}) {
          $unitids->{$unitid} = 1
            if ($rup->{$roleid}->{$unitid}->{$args->{persid}} =~ /^y/);;
        }
      }
      return $unitids;
    }
  } else {
    my @allroles = $self->{rolesadmin}->listAllRoles ();
    if ($args->{unitid}) {
      my $rightids;
      foreach my $rightid (keys %$adminroles) {
        next unless $adminroles->{$rightid};
        my @roleids = @{$adminroles->{$rightid}};
        foreach my $roleid (@roleids) {
          if ($rup->{$roleid}->{$args->{unitid}}->{$args->{persid}} =~ /^y/) {
            $rightids->{$rightid} = 1;
            last;
          }
        }
      }
      return $rightids;
    } else {
      my $rightunits;
      foreach my $rightid (keys %$adminroles) {
        my @roleids = @{$adminroles->{$rightid}};
        foreach my $roleid (@roleids) {
          foreach my $unitid (keys %{$rup->{$roleid}}) {
            $rightunits->{$rightid}->{$unitid} = 1
              if ($rup->{$roleid}->{$unitid}->{$args->{persid}} =~ /^y/);
          }
        }
      }
      return $rightunits;
    }
  }
}

sub rightsAdministeredBy { # OK
  my ($self, $persid) = @_;
  importmodules ($self, 'Roles', 'RightsAdmin');
  my $adminsrights;
  my @allrights = $self->{rightsadmin}->listAllRights ();
  foreach my $right (@allrights) {
    my $rightid = $right->{id};
    my @adminroles = $self->{accreddb}->dbselect (
      table => 'rights_roles',
       what => 'roleid',
      where => {
        rightid => $rightid,
      },
    );
    foreach my $roleid (@adminroles) {
      my $rup = $self->{roles}->getRoles (
        roleid => $roleid,
        persid => $persid,
      );
      my @unitids = keys %{$rup->{$roleid}};
      if (@unitids) {
        $adminsrights->{$rightid} = 1;
        last;
      }
    }
  }
  return unless $adminsrights;
  return keys %$adminsrights;
}

sub setPersonRight { # OK
  my ($self, $persid, $unitid, $rightid, $newval, $author) = @_;
  importmodules ($self, 'Logs', 'Notifications', 'Notifier', 'RightsAdmin');
  if ($newval !~ /^[ynd]$/) {
    $self->{errmsg} = "Bad value for new value : $newval";
    return;
  }
  my $rup = $self->getExplicitRights (
    rightid => $rightid,
     unitid => $unitid,
     persid => $persid,
  );
  # since we use getExplicitRights, may be empty and not considered 'n' as we did in the previous version
  my $oldval = $rup->{$rightid}->{$unitid}->{$persid};
  if ($newval eq $oldval) {
    $self->{errmsg} = "New value identical to old value : $newval";
    return;
  }

  my $oldval = ($oldval =~ /^y/) ? 'y' : 'n';

  if (($newval eq 'y') || ($newval eq 'n')) {
    $self->{accreddb}->dbupdate (
      table => 'rights_persons',
        set => {
           value => $newval,
          respid => $author,
        },
      where => {
         unitid => $unitid,
        rightid => $rightid,
         persid => $persid,
      },
    );
    $self->{logs}->log ($author, "setrightpers", $rightid, $persid, $unitid, $newval);
    my $right = $self->{rightsadmin}->getRight ($rightid);
    return unless $right;
    if ($newval eq 'y') {
      $self->{notifications}->notify (
        action => 'grantright',
        unitid => $unitid,
        object => $right->{name},
        persid => $persid,
        author => $author,
      );
    }
    elsif ($newval eq 'n') {
      $self->{notifications}->notify (
        action => 'revokeright',
        unitid => $unitid,
        object => $right->{name},
        persid => $persid,
        author => $author,
      );
    }
    if ($self->{notifier}) {
      if ($newval eq 'y') {
        $self->{notifier}->addRightToPerson ($persid, $unitid, $rightid, $author);
      } else {
        $self->{notifier}->delRightOfPerson ($persid, $unitid, $rightid, $author);
      }
    }
  } else { # newval eq 'd'
    $self->{accreddb}->dbdelete (
      table => 'rights_persons',
      where => {
        rightid => $rightid,
         persid => $persid,
         unitid => $unitid,
       },
    );
    $self->{logs}->log ($author, "deleterightpers", $rightid, $persid, $unitid);
    my $rup = $self->getRights (
      rightid => $rightid,
       unitid => $unitid,
       persid => $persid,
    );
    my  $nval = $rup->{$rightid}->{$unitid}->{$persid};
    my $right = $self->{rightsadmin}->getRight ($rightid);
    return unless $right;
    if ($oldval =~ /^n/) {
      if ($nval) {
        $self->{notifications}->notify (
          action => 'grantright',
          unitid => $unitid,
          object => $right->{name},
          persid => $persid,
          author => $author,
        );
      }
    }
    else { # oldval =~ /^y/
      if (!$nval) {
        $self->{notifications}->notify (
          action => 'revokeright',
          unitid => $unitid,
          object => $right->{name},
          persid => $persid,
          author => $author,
        );
      }
    }
    if ($self->{notifier}) {
      if ($oldval eq 'n') {
        if ($nval) {
          $self->{notifier}->addRightToPerson ($persid, $unitid, $rightid, $author);
        }
      } else { # oldval = 'y'
        if (!$nval) {
          $self->{notifier}->delRightOfPerson ($persid, $unitid, $rightid, $author);
        }
      }
    }
  }
  return 1;
}

sub deletePersonRightEveryWhere { # OK
  my ($self, $rightid, $persid) = @_;
  $self->{accreddb}->dbdelete (
    table => 'rights_persons',
    where => {
      rightid => $rightid,
       persid => $persid,
    },
  );
}

sub rightIsUsedBy { # OK
  my ($self, $rightid) = @_;
  return $self->{accreddb}->dbselect (
    table => 'rights_persons',
     what => 'persid',
    where => {
      rightid => $rightid,
    },
  );
}

sub ListFirstAccreditors { # OK
  my $self = shift;  
  importmodules ($self, 'Units', 'RightsAdmin');
  my   $right = $self->{rightsadmin}->getRight ('accreditation');
  my $rightid = $right->{id};
  my $rup = $self->getRights (
    rightid => $rightid,
  );
  my $units = $self->{units}->getUnits ([keys %{$rup->{$rightid}}]);
  
  my $bylevel;
  foreach my $unitid (keys %{$rup->{$rightid}}) {
    next unless $units->{$unitid}->{level} == 4;
    foreach my $persid (keys %{$rup->{$rightid}->{$unitid}}) {
      my  $value = $rup->{$rightid}->{$unitid}->{$persid};
      next unless ($value =~ /^y/);
      my  @fields = split (/:/, $value);
      my   $defid = pop @fields;
      my $defunit = $units->{$defid};
      next unless $defunit;
      my $level = $defunit->{level};
      $bylevel->{$unitid}->{$level}->{$persid} = 1;
    }
  }
  my $accreditors;
  foreach my $unitid (keys %$bylevel) {
    $accreditors->{$unitid} =
      $bylevel->{$unitid}->{4} ||
      $bylevel->{$unitid}->{3} ||
      $bylevel->{$unitid}->{2} ||
      $bylevel->{$unitid}->{1};
  }
  return $accreditors;
}

sub ListFirstRightAdmins { # OK
  my ($self, $rightid, $unitid) = @_;
  return unless ($rightid && $unitid);
  importmodules ($self, 'Units', 'Roles');
  my @adminroles = $self->{accreddb}->dbselect (
    table => 'rights_roles',
     what => 'roleid',
    where => {
      rightid => $rightid,
    },
  );
  my $bylevel;
  foreach my $roleid (@adminroles) {
    my $rup = $self->{roles}->getRoles (
      roleid => $roleid,
      unitid => $unitid,
    );
    foreach my $persid (keys %{$rup->{$rightid}->{$unitid}}) {
      my  $value = $rup->{$rightid}->{$unitid}->{$persid};
      next unless ($value =~ /^y/);
      my  @fields = split (/:/, $value);
      my   $defid = pop @fields;
      my $defunit = $self->{units}->getUnit ($defid);
      next unless $defunit;
      my $level = $defunit->{level};
      push (@{$bylevel->{$level}}, {
        roleid => $roleid,
        unitid => $defid,
        persid => $persid,
      });
    }
  }
  return @{$bylevel->{4}} if $bylevel->{4};
  return @{$bylevel->{3}} if $bylevel->{3};
  return @{$bylevel->{2}} if $bylevel->{2};
  return @{$bylevel->{1}} if $bylevel->{1};
  return ();
}


1;


