#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Roles.pm
# Description:  
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Wed Sep 25 15:36:33 CEST 2002
# Revision:     
#
##############################################################################
#
#
package Accred::Roles;

use strict;
use utf8;
use Carp;
$Carp::Verbose = 1;

use LWP::UserAgent;
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
  unless (eval "use JSON; 1;") {
    $self->{nojson} = 1;
  }
  #setCache ();
  return $self;
}

sub getRoles {
  my ($self, %args) = @_;
  my $args = \%args;  
  importmodules ($self, 'Units', 'RolesAdmin');
  
  if ($args->{roleid} && ($args->{roleid} !~ /^\d+$/)) { # Accept role names.
    my $role = $self->{rolesadmin}->getRole ($args->{roleid});
    $args->{roleid} = $role->{id};
  }
  my $deputies = {};
  my  $holders = {};
  my  @holders = ();
  if ($args->{persid}) {
    $self->fillHoldersTree ($holders, $args->{persid}, $args);
    foreach my $deputyid (keys %$holders) {
      foreach my $roleid (keys %{$holders->{$deputyid}}) {
        foreach my $unitid (keys %{$holders->{$deputyid}->{$roleid}}) {
          foreach my $holderid (@{$holders->{$deputyid}->{$roleid}->{$unitid}}) {
            push (@{$deputies->{$holderid}->{$roleid}->{$unitid}}, $deputyid);
          }
        }
      }
    }
    @holders = keys %$deputies;
  } else {
    $deputies = $self->getDeputiesNow ($args);
    $self->fillDeputiesTree ($deputies,
      {
          persid => $args->{persid},
        initpers => $args->{persid},
      }
    );
    @holders = keys %$deputies;
  }
  #printholders  ($holders);
  #printdeputies ($deputies);
  #
  my @roleids;
  if ($args->{roleid}) {
    @roleids = ($args->{roleid});
  } else {
    @roleids = $self->{accreddb}->dbselect (
      table => 'roles',
       what => 'id',    
    );
  }
  my $rootids;
  if ($args->{rootids}) {
    my @rootids = (ref $args->{rootids} eq 'ARRAY')
      ? @{$args->{rootids}}
      : ($args->{rootids})
      ;
    $rootids = [ $self->{units}->expandUnitsList (@rootids) ];
  }
  #
  my @ancestorids;
  if ($args->{unitid}) {
    @ancestorids = $self->{units}->getAncestors ($args->{unitid});
  }
  #
  # Calculate SQL query
  #
  my $where = {};
  $where->{roleid} = $args->{roleid} if $args->{roleid};
  if ($args->{unitid}) {
    unless ($args->{noinherit}) {
      $where->{unitid} = [ $args->{unitid}, @ancestorids ];
    } else {
      $where->{unitid} = [ $args->{unitid} ];
    }
  } else {
    $where->{unitid} = $rootids if $rootids;
  }
  if ($args->{persid}) {
    $where->{persid} = [ $args->{persid}, @holders ];
  }
  #
  my @allrolepers =  $self->{accreddb}->dbselect (
    table => 'roles_persons',
     what => [ '*', ],
    where => $where,
  );
  my $allrolepers;
  foreach my $rolepers (@allrolepers) {
    my $rroleid = $rolepers->{roleid};
    my $runitid = $rolepers->{unitid};
    my $rpersid = $rolepers->{persid};
    my  $rvalue = $rolepers->{value};
    $allrolepers->{$rroleid}->{$runitid}->{$rpersid} = $rvalue;
    #$allrolepers->{$rroleid}->{$runitid}->{$rpersid} = "$rvalue:D:$runitid";
  }
  if ($args->{persid}) {
    $args->{origid} = $args->{persid};
    $self->fillDeputiesPersValues ($allrolepers, $args->{persid}, $holders, $args);
  } else {
    $self->fillDeputiesValues ($allrolepers, $deputies, $args);
  }
  #
  # Calculate roles.
  #
  my @allvalues;
  foreach my $roleid (sort @roleids) {
    if ($args->{unitid}) {
      my $found;
      foreach my $ancestorid ($args->{unitid}, @ancestorids) {
        foreach my $persid (keys %{$allrolepers->{$roleid}->{$ancestorid}}) {
          next if $found->{$persid};
          my $value = $allrolepers->{$roleid}->{$ancestorid}->{$persid};
          next unless $value;
          if (!$args->{persid} || ($persid == $args->{persid})) {
            $value = ($ancestorid eq $args->{unitid})
              ? $value . ':D:' . $ancestorid
              : $value . ':H:' . $ancestorid
              ;
            push (@allvalues, {
              roleid => $roleid,
              unitid => $args->{unitid},
              persid => $persid,
               value => $value,
            });
            $found->{$persid} = 1;
          }
        }
      }
    } # End if $args->{unitid}.
    else {
      foreach my $unitid (keys %{$allrolepers->{$roleid}}) {
        foreach my $persid (keys %{$allrolepers->{$roleid}->{$unitid}}) {
          if (!$args->{persid} || ($persid == $args->{persid})) {
            my $value = $allrolepers->{$roleid}->{$unitid}->{$persid};
            if ($value) {
              push (@allvalues, {
                roleid => $roleid,
                unitid => $unitid,
                persid => $persid,
                 value => $value . ':D:' . $unitid,
              });
            }
          }
        }
      }
    }
  }
  #
  # Aggregate values.
  #
  my $values;
  foreach my $value (@allvalues) {
    my $roleid = $value->{roleid};
    my $unitid = $value->{unitid};
    my $persid = $value->{persid};
    my  $value = $value->{value};
    $values->{$roleid}->{$unitid}->{$persid} = $value;
  }
  return $values if $args->{noexpand}; # No children heritage.
  #
  # Hands down to children units.
  #
  unless ($args->{unitid}) {
    my $children = $self->{units}->getAllChildren ();
    foreach my $roleid (keys %$values) {
      foreach my $unitid (keys %{$values->{$roleid}}) {
        $self->handsDownRoles ($values, $roleid, $unitid, $children);
      }
    }
  }
  return $values;
}

sub handsDownRoles {
  my ($self, $values, $roleid, $unitid, $children) = @_;
  my $unitvalue = $values->{$roleid}->{$unitid};
  foreach my $childid (@{$children->{$unitid}}) {
    foreach my $persid (keys %{$values->{$roleid}->{$unitid}}) {
      my $value = $unitvalue->{$persid};
      $value =~ s/:D:/:H:/g;
      $values->{$roleid}->{$childid}->{$persid} ||= $value;
    }
    $self->handsDownRoles ($values, $roleid, $childid, $children);
  }
}

#
#
#

sub getExplicitRoles { # OK
  my ($self, %args) = @_;
  my $args = \%args;
  importmodules ($self, 'Units');

  my $rootids;
  if ($args->{rootids}) {
    my @rootids = (ref $args->{rootids} eq 'ARRAY')
      ? @{$args->{rootids}}
      : ($args->{rootids})
      ;
    $rootids = [ $self->{units}->expandUnitsList (@rootids) ];
  }
  my $where;
  $where->{roleid} = $args->{roleid} if $args->{roleid};
  $where->{unitid} = $args->{unitid} if $args->{unitid};
  $where->{persid} = $args->{persid} if $args->{persid};
  $where->{unitid} = $rootids        if $rootids;
  my @results = $self->{accreddb}->dbselect (
    table => 'roles_persons',
     what => [ 'roleid', 'unitid', 'persid', 'value' ],
    where => $where,
  );
  my $roles;
  foreach my $result (@results) {
    my $roleid = $result->{roleid};
    my $unitid = $result->{unitid};
    my $persid = $result->{persid};
    my  $value = $result->{value};
    $roles->{$roleid}->{$unitid}->{$persid} = $value;
  }
  return $roles;
}

sub isRolesManager {
  my ($self, %args) = @_;
  my   $args = \%args;
  my $persid = $args->{persid};
  return unless $persid;
  importmodules ($self, 'Rights', 'Units', 'RolesAdmin');

  my @allroles = $self->{rolesadmin}->listRoles ();
  my $allroles = { map { $_->{id} => $_ } @allroles };
  my  @roleids = $args->{roleid} ? ($args->{roleid}) : keys %$allroles;
  my $managingrights = $self->{rolesadmin}->getAllManagingRights ();
  my $rolesmanaged;
  foreach my $roleid (sort @roleids) {
    next unless $managingrights->{$roleid};
    my @rightids = @{$managingrights->{$roleid}};
    map { push (@{$rolesmanaged->{$_}}, $roleid) } @rightids;
  }
  my $results;
  foreach my $rightid (keys %$rolesmanaged) {
    my @roleids = @{$rolesmanaged->{$rightid}};
    my $rup = $self->{rights}->getRights (
       rightid => $rightid,
        unitid => $args->{unitid},
        persid => $args->{persid},
      noexpand => $args->{noexpand},
    );
    foreach my $unitid (keys %{$rup->{$rightid}}) {
      next unless $rup->{$rightid}->{$unitid};
      foreach my $roleid (@roleids) {
        next if $results->{$roleid}->{$unitid};
        $results->{$roleid}->{$unitid} = ($rup->{$rightid}->{$unitid}->{$args->{persid}} =~ /^y/);
      }
    }
  }
  return $results;
}

sub ListFirstRolesAdmins { # OK
  my ($self, $roleid, $unitid) = @_;
  return unless ($roleid && $unitid);
  importmodules ($self, 'Rights', 'Units', 'RolesAdmin');
  
  my       @allroles = $self->{rolesadmin}->listRoles ();
  my       $allroles = { map { $_->{id} => $_ } @allroles };
  my $managingrights = $self->{rolesadmin}->getAllManagingRights ();
  my $rolesmanaged;
  my $admins;

  my @rightids = @{$managingrights->{$roleid}};
  foreach my $rightid (@rightids) {
    my $rup = $self->{rights}->getRights (
      rightid => $rightid,
       unitid => $unitid,
    );
    my $adminids = $rup->{$rightid}->{$unitid};
    next unless $adminids;
    foreach my $adminid (keys %$adminids) {
      my $value = $adminids->{$adminid};
      next unless ($value =~ /^y/);
      my @fields = split (/:/, $value);
      my $unitid = pop @fields;
      push (@{$admins->{$roleid}->{$unitid}}, $adminid);
    }
  }
  my @admins;
  my @ancestorids = $self->{units}->getAncestors ($unitid);
  foreach my $ancestorid ($unitid, @ancestorids) {
    if ($admins->{$ancestorid}) {
      foreach my $persid (@{$admins->{$ancestorid}}) {
        push (@admins, {
          unitid => $ancestorid,
          persid => $persid,
        });
      }
    }
    last if @admins;
  }
  return @admins;
}

sub ListRolesAdmins { # OK
  my ($self, $unitid) = @_;
  importmodules ($self, 'Rights', 'Units');
  my   $unittype = $self->{units}->getUnitType ($unitid);
  my $rolesadmin = $self->{accreddb}->getObject (
    type => 'rights',
    name => $unittype->{rolesmanager},
  );
  my $rightid = $rolesadmin->{id};
  my $rup = $self->{rights}->getRights (
    rightid => $rightid,
     unitid => $unitid,
  );
  my $adminids = $rup->{$rightid}->{$unitid};
  return unless $adminids;
  my $admins;
  foreach my $adminid (keys %$adminids) {
    my  $value = $adminids->{$adminid};
    next unless ($value =~ /^y/);
    my @fields = split (/:/, $value);
    my $unitid = pop @fields;
    push (@{$admins->{$unitid}}, $adminid);
  }
  
  my @admins;
  my @ancestorids = $self->{units}->getAncestors ($unitid);
  foreach my $ancestorid ($unitid, @ancestorids) {
    if ($admins->{$ancestorid}) {
      foreach my $persid (@{$admins->{$ancestorid}}) {
        push (@admins, {
          unitid => $ancestorid,
          persid => $persid,
        });
      }
    }
  }
  return @admins;
}

sub roleIsUsedBy { # OK
  my ($self, $roleid) = @_;
  return $self->{accreddb}->dbselect (
    table => 'roles_persons',
     what => 'persid',
    where => {
      roleid => $roleid,
       value => 'y',
    },
  );
}

sub setPersonRole { # OK
  my ($self, $roleid, $persid, $unitid, $value, $author) = @_;
  importmodules ($self, 'Logs', 'Notifications', 'Notifier', 'RolesAdmin');
  if ($value !~ /^[ynd]$/) {
    $self->{errmsg} = "Bad value for new value : $value";
    return;
  }
  
  my $rup = $self->getExplicitRoles (
    roleid => $roleid,
    unitid => $unitid,
    persid => $persid,
  );
  my $oldval = ($rup->{$roleid}->{$unitid}->{$persid} =~ /^y/) ? 'y' : 'n';
  if ($value eq $oldval) {
    $self->{errmsg} = "New value identical to old value : $value";
    return;
  }
  if ($value eq 'd') {
    $self->{accreddb}->dbdelete (
      table => 'roles_persons',
      where => {
        roleid => $roleid,
        persid => $persid,
        unitid => $unitid,
      }
    );
  } else {
    $self->{accreddb}->dbupdate (
      table => 'roles_persons',
        set => {
           value => $value,
          respid => $author,
        },
      where => {
        unitid => $unitid,
        roleid => $roleid,
        persid => $persid,
      }
    );
  }
  #
  # Remove deputations if any.
  #
  if ($value =~ /^[nd]$/) { # Remove role.
    my $deputations = $self->getDeputations ($persid, $roleid, $unitid);
    if ($deputations) {
      foreach my $deputation (@{$deputations->{$persid}}) {
        $self->remDeputation ($deputation->{id}, $author);
      }
    }
  }
  #
  # Logs, Notifications, Notifier.
  #
  $self->{logs}->log ($author, "setrolepers", $roleid, $persid, $unitid, $value);
  
  my $rup = $self->getRoles (
    roleid => $roleid,
    unitid => $unitid,
    persid => $persid,
  );
  my $newval = ($rup->{$roleid}->{$unitid}->{$persid} =~ /^y/) ? 'y' : 'n';
  my   $role = $self->{rolesadmin}->getRole ($roleid);
  return unless $role;
  if ($newval ne $oldval) {
    if ($newval eq 'y') {
      $self->{notifications}->notify (
          action => 'grantrole',
          unitid => $unitid,
          object => $role->{name},
          persid => $persid,
          author => $author,
      );
    }
    elsif ($newval eq 'n') {
      $self->{notifications}->notify (
          action => 'revokerole',
          unitid => $unitid,
          object => $role->{name},
          persid => $persid,
          author => $author,
      );
    }
  }
  if ($self->{notifier}) {
    if ($newval ne $oldval) {
      if ($newval eq 'y') {
        $self->{notifier}->addRoleToPerson ($persid, $unitid, $roleid, $author);
      }
      elsif ($newval eq 'n') {
        $self->{notifier}->delRoleOfPerson ($persid, $unitid, $roleid, $author);
      }
    }
  }
}

#
# Deputations / Suppléances
#

sub getDeputiesNow {
  my ($self, $args) = @_;
  my $persid = $args->{persid};
  my $roleid = $args->{roleid};
  
  my $deputations = $self->getDeputations ($persid, $roleid);
  my    $deputies;
  foreach my $holderid (keys %$deputations) {
    my @deputations = @{$deputations->{$holderid}};
    foreach my $deputation (@deputations) {
      my   $roleid = $deputation->{roleid};
      my   $unitid = $deputation->{unitid};
      my  $deputid = $deputation->{deputid};
      if ($deputation->{cond} eq 'p') {
        push (@{$deputies->{$holderid}->{$roleid}->{$unitid}}, $deputid);
      }
      elsif ($deputation->{cond} eq 'd') {
        my ($ydeb, $mdeb, $ddeb) = ($deputation->{datedeb} =~ /^(\d+)-(\d+)-(\d+)$/);
        my ($yfin, $mfin, $dfin) = ($deputation->{datefin} =~ /^(\d+)-(\d+)-(\d+)$/);
        next unless ($ydeb && $yfin);
        my @now = localtime;
        my ($ynow, $mnow, $dnow) = ($now [5] + 1900, $now [4] + 1, $now [3]);
        if (($ynow >= $ydeb) && ($ynow <= $yfin) &&
            ($mnow >= $mdeb) && ($mnow <= $mfin) &&
            ($dnow >= $ddeb) && ($dnow <= $dfin)) {
          push (@{$deputies->{$holderid}->{$roleid}->{$unitid}}, $deputid);
        }
      }
      elsif ($deputation->{cond} eq 'w') {
        my $allabsents = $self->getAbsences ();
        if ($allabsents->{$holderid}) {
          push (@{$deputies->{$holderid}->{$roleid}->{$unitid}}, $deputid);
        }
      }
    }
  }
  return $deputies;
}

sub getHoldersNow {
  my ($self, $deputid, $roleid) = @_;
  my $deputations = $self->getHolders ($deputid, $roleid);
  my $holders;
  foreach my $deputid (keys %$deputations) {
    my @deputations = @{$deputations->{$deputid}};
    foreach my $deputation (@deputations) {
      my $holderid = $deputation->{persid};
      my   $roleid = $deputation->{roleid};
      my   $unitid = $deputation->{unitid};
      if ($deputation->{cond} eq 'p') {
        push (@{$holders->{$deputid}->{$roleid}->{$unitid}}, $holderid);
      }
      elsif ($deputation->{cond} eq 'd') {
        my ($ydeb, $mdeb, $ddeb) = ($deputation->{datedeb} =~ /^(\d+)-(\d+)-(\d+)$/);
        my ($yfin, $mfin, $dfin) = ($deputation->{datefin} =~ /^(\d+)-(\d+)-(\d+)$/);
        next unless ($ydeb && $yfin);
        my @now = localtime;
        my ($ynow, $mnow, $dnow) = ($now [5] + 1900, $now [4] + 1, $now [3]);
        if (($ynow >= $ydeb) && ($ynow <= $yfin) &&
            ($mnow >= $mdeb) && ($mnow <= $mfin) &&
            ($dnow >= $ddeb) && ($dnow <= $dfin)) {
          push (@{$holders->{$deputid}->{$roleid}->{$unitid}}, $holderid);
        }
      }
      elsif ($deputation->{cond} eq 'w') {
        my $allabsents = $self->getAbsences ();
        if ($allabsents->{$holderid}) {
          push (@{$holders->{$deputid}->{$roleid}->{$unitid}}, $holderid);
        }
      }
    }
  }
  return $holders;
}

sub fillDeputiesTree {
  my ($self, $deputies, $args) = @_;
  my   $persid = $args->{persid};
  my   $unitid = $args->{unitid};
  my   $roleid = $args->{roleid};
  my $initpers = $args->{initpers};

  my @holderids = $persid ? ($persid) : keys %$deputies;
  foreach my $holderid (@holderids) {
    my @roleids = $roleid ? ($roleid) : keys %{$deputies->{$holderid}};
    foreach my $roleid (@roleids) {
      my @unitids = $unitid ? ($unitid) : keys %{$deputies->{$holderid}->{$roleid}};
      foreach my $unitid (@unitids) {
        foreach my $deputyid (@{$deputies->{$holderid}->{$roleid}->{$unitid}}) {
          if ($initpers && ($initpers != $deputyid)) {
            push (@{$deputies->{$holderid}->{$roleid}->{$unitid}}, $initpers);
          }
          $self->fillDeputiesTree ($deputies,
            {
                persid => $deputyid,
                unitid => $unitid,
                roleid => $roleid,
              initpers => $initpers,
            }
          ) unless ($deputyid == $initpers);
        }
      }
    }
  }
}

# $holders->{$deputid}->{$roleid}->{$unitid}} => $holderid;
sub fillHoldersTree {
  my ($self, $holders, $persid, $args) = @_;
  my $holdersof = $self->getHoldersNow ($persid, $args->{roleid});

  foreach my $deputyid (keys %$holdersof) {
    foreach my $roleid (keys %{$holdersof->{$deputyid}}) {
      foreach my $unitid (keys %{$holdersof->{$deputyid}->{$roleid}}) {
        foreach my $holderid (@{$holdersof->{$deputyid}->{$roleid}->{$unitid}}) {
          push (@{$holders->{$deputyid}->{$roleid}->{$unitid}}, $holderid);
          $self->fillHoldersTree ($holders, $holderid);
        }
      }
    }
  }
}

sub fillDeputiesPersValues {
  my ($self, $values, $persid, $holders, $args) = @_;  
  my @roleids = $args->{roleid} ? ($args->{roleid}) : keys %{$holders->{$persid}};
  foreach my $roleid (@roleids) {
    foreach my $unitid (keys %{$holders->{$persid}->{$roleid}}) {
      next if $values->{$roleid}->{$unitid}->{$persid};
      my ($value, $reason) = $self->fillDeputiesPersValues_rec (
        $persid, $values, $holders,
        {
          unitid => $unitid,
          roleid => $roleid,
        }
      );
      if ($value) {
        $values->{$roleid}->{$unitid}->{$persid} = "$value:D:$unitid:$reason";
      }
    }
  }
}

sub fillDeputiesPersValues_rec {
  my ($self, $deputyid, $values, $holders, $args) = @_;
  my $roleid = $args->{roleid};
  my $unitid = $args->{unitid};
  return unless ($roleid && $unitid);
  
  foreach my $holderid (@{$holders->{$deputyid}->{$roleid}->{$unitid}}) {
    my $value = $values->{$roleid}->{$unitid}->{$holderid};
    return ($value, "S:$holderid:D:$unitid") if $value;
    my ($value, $reason) = $self->fillDeputiesPersValues_rec (
      $holderid, $values, $holders, $args,
    );
    return ($value, "S:$holderid:$reason") if $value;
  }
}

sub fillDeputiesValues {
  my ($self, $values, $deputies, $args) = @_;
  foreach my $roleid (sort keys %$values) {
    foreach my $unitid (keys %{$values->{$roleid}}) {
      foreach my $persid (keys %{$values->{$roleid}->{$unitid}}) {
        my $value = $values->{$roleid}->{$unitid}->{$persid};
        next unless $value;
        $value = "$value:D:$unitid";
        foreach my $deputyid (@{$deputies->{$persid}->{$roleid}->{$unitid}}) {
          $values->{$roleid}->{$unitid}->{$deputyid} = $value . ":S:$persid";
          if ($deputies->{$deputyid}->{$roleid}->{$unitid}) {
            $self->fillDeputiesValues_rec ($deputyid, $values, $value, $deputies, $args);
          }
        }
      }
    }
  }
}

sub fillDeputiesValues_rec {
  my ($self, $holderid, $values, $value, $deputies, $args) = @_;
  foreach my $roleid (keys %{$deputies->{$holderid}}) {
    foreach my $unitid (keys %{$deputies->{$holderid}->{$roleid}}) {
      foreach my $deputyid (@{$deputies->{$holderid}->{$roleid}->{$unitid}}) {
        $values->{$roleid}->{$unitid}->{$deputyid} = $value . ":S:$holderid";
        if ($deputies->{$deputyid}->{$roleid}->{$unitid}) {
          $self->fillDeputiesValues_rec ($deputyid, $values, $value, $deputies, $args);
        }
      }
    }
  }
}

sub printdeputies {
  my $deputies = shift;
  foreach my $persid (keys %$deputies) {
    foreach my $roleid (keys %{$deputies->{$persid}}) {
      foreach my $unitid (keys %{$deputies->{$persid}->{$roleid}}) {
        warn "printdeputies:deputy:$persid:$roleid:$unitid:".
             "@{$deputies->{$persid}->{$roleid}->{$unitid}}\n";
      }
    }
  }
}

sub printholders {
  my $holders = shift;
  foreach my $persid (keys %$holders) {
    foreach my $roleid (keys %{$holders->{$persid}}) {
      foreach my $unitid (keys %{$holders->{$persid}->{$roleid}}) {
        warn "printholders:holders:$persid:$roleid:$unitid:".
             "@{$holders->{$persid}->{$roleid}->{$unitid}}\n";
      }
    }
  }
}

sub checkDeputiesLoops {
  my ($self, $persid, $roleid, $unitid, $deputyid) = @_;
  return 1 if ($deputyid == $persid);
  return $self->checkDeputiesLoops_rec ($persid, $persid, $roleid, $unitid, $deputyid);
}

sub checkDeputiesLoops_rec {
  my ($self, $rootid, $persid, $roleid, $unitid, $deputyid) = @_;
  my $deputations = $self->getDeputations ($persid, $roleid, $unitid);
  foreach my $deputation (@{$deputations->{$persid}}) {
    my  $depid = $deputation->{deputid};
    return 1 if ($depid == $rootid);
    return $self->checkDeputiesLoops_rec ($rootid, $depid, $roleid, $unitid, $deputyid);
  }
}

sub getDeputations {
  my ($self, $persid, $roleid, $unitid) = @_;
  importmodules ($self, 'AccredDB');
  my $where = {};
  $where->{persid} = $persid if $persid;
  $where->{roleid} = $roleid if $roleid;
  $where->{unitid} = $unitid if $unitid;
  my @results = $self->{accreddb}->dbselect (
    table => 'deputations',
     what => [ '*' ],
    where => $where,
  );
  my $deputations;
  foreach my $result (@results) {
    my $persid = $result->{persid};
    push (@{$deputations->{$persid}}, $result);
  }
  return $deputations;
}

sub getTreeDeputations {
  my ($self, $persid, $roleid, $unitid) = @_;
  importmodules ($self, 'AccredDB', 'Units');
  my $where = {};
  $where->{persid} = $persid if $persid;
  $where->{roleid} = $roleid if $roleid;
  if ($unitid) {
    my @descendantids = $self->{units}->listDescendantsIds ($unitid);
    $where->{unitid} = [ $unitid, @descendantids ];
  }
  my @results = $self->{accreddb}->dbselect (
    table => 'deputations',
     what => [ '*' ],
    where => $where,
  );
  my $deputations;
  foreach my $result (@results) {
    my $persid = $result->{persid};
    push (@{$deputations->{$persid}}, $result);
  }
  return $deputations;
}

sub getHolders {
  my ($self, $deputid, $roleid, $unitid) = @_;
  my $where = {};
  $where->{deputid} = $deputid if $deputid;
  $where->{roleid}  = $roleid  if $roleid;
  $where->{unitid}  = $unitid  if $unitid;
  my @results = $self->{accreddb}->dbselect (
    table => 'deputations',
     what => [ '*' ],
    where => $where,
  );
  my $deputations;
  foreach my $result (@results) {
    my $deputid = $result->{deputid};
    push (@{$deputations->{$deputid}}, $result);
  }
  return $deputations;
}

sub getDeputation {
  my ($self, $id) = @_;
  return unless $id;
  my @results = $self->{accreddb}->dbselect (
    table => 'deputations',
     what => [ '*' ],
    where => {
      id => $id,
    },
  );
  return unless @results;
  my $deputation = shift @results;
  return $deputation;
}

sub addDeputation {
  my ($self, $deputation, $author) = @_;
  return unless ($deputation &&
                 $deputation->{persid} && $deputation->{deputid} &&
                 $deputation->{unitid} && $deputation->{roleid});

  importmodules ($self, 'Accreds');
  my @accreds = $self->{accreds}->getAccredsOfPerson ($deputation->{deputid});
  unless (@accreds) {
    $self->{errmsg} = "addDeputation: $deputation->{deputid} has no accreditation";
    return;
  }
  my $hasloop = $self->checkDeputiesLoops (
    $deputation->{persid},
    $deputation->{roleid},
    $deputation->{unitid},
    $deputation->{deputid},
  );
  if ($hasloop) {
    $self->{errmsg} = "addDeputation: Loop detected, I cannot do that";
    return;
  }
  
  my $status = $self->{accreddb}->dbinsert (
    table => 'deputations',
      set => {
             id => 'UUID_SHORT',
         persid => $deputation->{persid},
         roleid => $deputation->{roleid},
         unitid => $deputation->{unitid},
        deputid => $deputation->{deputid},
           cond => $deputation->{cond},
        datedeb => $deputation->{datedeb},
        datefin => $deputation->{datefin},
      },
  );
  unless ($status) {
    $self->{errmsg} = "addDeputation: DB error : $self->{accreddb}->{errmsg}";
    return;
  }
  importmodules ($self, 'Logs', 'Notifications');
  $self->{logs}->log ($author, 'adddeputation',
    $deputation->{persid},
    $deputation->{unitid},
    $deputation->{roleid},
    $deputation->{deputid},
    $deputation->{cond},
    $deputation->{datedeb},
    $deputation->{datefin},
  );
  $self->{notifications}->notify (
      action => 'adddeputation',
      unitid => $deputation->{unitid},
      object => $deputation->{roleid},
      persid => $deputation->{persid},
    holderid => $deputation->{persid},
     deputid => $deputation->{deputid},
      author => $author,
  );
  return 1;
}

sub modDeputation {
  my ($self, $deputid, $values, $author) = @_;
  return unless ($deputid && $values && keys %$values);
  importmodules ($self, 'Logs');
  my $olddeputation = $self->getDeputation ($deputid);
  unless ($olddeputation) {
    $self->{errmsg} = "modDeputation: unknown deputation : $deputid";
    return;
  }
  my @validargs = qw{cond datedeb datefin};
  my @logargs;
  my $sets;
  foreach my $arg (@validargs) {
    if (exists $values->{$arg} && $values->{$arg} ne $olddeputation->{$arg}) {
      $sets->{$arg} = $values->{$arg};
      push (@logargs, $arg, $olddeputation->{$arg}, $values->{$arg});
    }
  }
  return unless ($sets && keys %$sets);
  if ($sets->{cond} && ($sets->{cond} ne 'd')) {
    $sets->{datedeb} = 'null';
    $sets->{datefin} = 'null';
  }
  my $status = $self->{accreddb}->dbupdate (
    table => 'deputations',
      set => $sets,
    where => {
      id => $deputid,
    }
  );
  unless ($status) {
    $self->{errmsg} = "moddDeputation: DB error : $self->{accreddb}->{errmsg}";
    return;
  }
  $self->{logs}->log ($author, "moddeputation",
    $olddeputation->{persid},
    $olddeputation->{roleid},
    $olddeputation->{unitid},
    @logargs,
  );
  return 1;
}

sub remDeputation {
  my ($self, $id, $author) = @_;
  return unless ($id && $author);
  importmodules ($self, 'Logs', 'Notifications');

  my $deputation = $self->getDeputation ($id);
  unless ($deputation) {
    $self->{errmsg} = "modDeputation: unknown deputation : $id";
    return;
  }
  my $status = $self->{accreddb}->dbdelete (
    table => 'deputations',
    where => {
      id => $id,
    },
  );
  unless ($status) {
    $self->{errmsg} = "remDeputation: DB error : $self->{accreddb}->{errmsg}";
    return;
  }
  $self->{logs}->log ($author, "remdeputation",
    $deputation->{id},
    $deputation->{persid},
    $deputation->{unitid},
    $deputation->{roleid},
    $deputation->{deputid},
    $deputation->{cond},
    $deputation->{datedeb},
    $deputation->{datefin},
  );
  $self->{notifications}->notify (
      action => 'remdeputation',
      unitid => $deputation->{unitid},
      object => $deputation->{roleid},
      persid => $deputation->{persid},
    holderid => $deputation->{persid},
     deputid => $deputation->{deputid},
      author => $author,
  );
  return 1;
}

sub getAbsences {
  my ($self, $persid) = @_;
  return {} if $self->{nojson};

  return $self->{allabsents} if $self->{allabsents};
  
  #warn scalar localtime, " INFO:getAbsences:Loading cache.\n";
  my $absurl = 'https://websrv.epfl.ch/cgi-bin/rwsabsences?app=Accred&caller=105640';
  my $lwp = new LWP::UserAgent;
  unless ($lwp) {
    $self->{errmsg} = "unable to initialize LWP client.";
    warn "Roles:getAbsences:Error: $self->{errmsg}\n";
    return;
  }
  my $url = $absurl;
  if ($persid) {
    $persid = [ $persid ] unless (ref $persid eq 'ARRAY');
    $url = $absurl . '&sciper=' . join (',', @$persid)
  }
  my $httpreq = new HTTP::Request ('GET', $url);
  my $res = $lwp->request ($httpreq);
  if ($res->code != 200) {
    $self->{errmsg} = "Bad answer from Absences : ", $res->status_line;
    warn "Roles:getAbsences:Error: $self->{errmsg}\n";
    return;
  }
  my $content = $res->decoded_content;
  my $data;
  eval {
    my $json = JSON->new ();
    #$json->relaxed (1);
    $data = $json->decode ($content);
  } || do {
    $self->{errmsg} = "Bad JSON response from Absences : $content : $@";
    warn "Roles:getAbsences:Error: $self->{errmsg}\n";
    return;
  };
  if ($data->{Status}) {
    if ($data->{Error} && $data->{Error}->{text}) {
      $self->{errmsg} = "Error: Absences says : $data->{Error}->{text}";
    } else {
      $self->{errmsg} = "Error: Absences says nothing about it, status = $data->{Status}";
    }
    warn "Roles:getAbsences:Error: $self->{errmsg}\n";
    return;
  }
  $self->{allabsents} = { map { $_ => 1 } @{$data->{result}} };
  #warn scalar localtime, " INFO:getAbsences:Cache loaded.\n";
  return $self->{allabsents};
}

sub setCache {
  *getAbsences = Accred::Utils::cache (\&getAbsences, 3600);
}

my $deputations = qq{
  create table deputations (
         id bigint unsigned,
     persid char(8),
    deputid char(8),
     unitid char(12),
     roleid int,
       cond char(1),
    datedeb date,
    datefin date,
     debval datetime,
     finval datetime,
      index (id, persid, deputid, unitid, roleid)
  );
};



1;

