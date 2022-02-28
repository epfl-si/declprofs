#!/usr/bin/perl
#
##############################################################################
#
# File Name:    roles.pl
# Description:  
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Wed Sep 25 15:36:33 CEST 2002
# Revision:     
#
##############################################################################
#
#
package Accred::RolesAdmin;

use strict;
use utf8;

use Accred::Config;
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

sub listAllRoles { return listRoles (@_); }
sub listRoles {
  my ($self, $unitType) = @_;
  importmodules ($self, 'AccredDB');
  my $utype = $unitType;
  if ($utype && ref $utype) {
    $utype = ref $unitType;
    $utype =~ s/Accred::(.*)$/$1/;
  }
  my @roles;
  my @allroles = $self->{accreddb}->listAllObjects ('roles');
  foreach my $role (@allroles) {
    next if ($utype && ($role->{unittype} ne $utype));
    $role->{hasrights} = ($role->{hasrights} eq 'y') ? 1 : 0;
    $role->{delegate}  = ($role->{delegate}  eq 'y') ? 1 : 0;
    $role->{protected} = ($role->{protected} eq 'y') ? 1 : 0;
    $role->{labelen} ||= $role->{labelfr};
    $role->{label} = ($self->{lang} eq 'en')
      ? $role->{labelen}
      : $role->{labelfr}
      ;
    $role->{type} = 'Role';
    push (@roles, $role)
  }
  my $utypes;
  foreach my $role (@roles) {
    push (@{$utypes->{$role->{unittype}}}, $role);
  }
  my     $ordre = 1;
  my    $config = new Accred::Config ();
  my $allutypes = $config->{unittypes};
  foreach my $utype (
        sort {
          $allutypes->{$a}->{order} <=> $allutypes->{$b}->{order}
        } keys %$utypes) {
    my @roles = @{$utypes->{$utype}};
    if ($utype eq 'Funds') {
      my @orders = qw(
        respcf1 membresgec respcf2 adjointsvp respcf3
        regsigadmin respfinance respcf4 respcf5 gestcf
      );
      my $forder = 1;
      my $orders = { map { $_, $forder++ } @orders };
      my  @rlist = sort { $orders->{$a->{name}} <=> $orders->{$b->{name}} } @roles;
      map { $_->{ordre} = $ordre++ } @rlist;
    }
    if ($utype eq 'Orgs') {
      my @rlist = sort {
        return $a->{name} cmp $b->{name};
      } @roles;
      map { $_->{ordre} = $ordre++ } @rlist;
    }
  }
  return @roles;
}

sub getRole {
  my ($self, $roleid) = @_;
  my $field = ($roleid =~ /^\d.*$/) ? 'id' : 'name';
  my  $role = $self->{accreddb}->getObject (
      type => 'roles',
    $field => $roleid,
  );
  $role->{hasrights} = ($role->{hasrights} eq 'y') ? 1 : 0;
  $role->{delegate}  = ($role->{delegate}  eq 'y') ? 1 : 0;
  $role->{protected} = ($role->{protected} eq 'y') ? 1 : 0;
  $role->{labelen} ||= $role->{labelfr};
  $role->{label} = ($self->{lang} eq 'en')
    ? $role->{labelen}
    : $role->{labelfr}
    ;
  $role->{type} = 'Role';
  return $role;
}

sub addRole {
  my ($self, $role, $author) = @_;
  importmodules ($self, 'Logs', 'Notifier');
  my $roleid = $self->{accreddb}->dbinsert (
    table => 'roles',
      set => $role,
  );
  unless ($roleid) {
    $self->{errmsg} = "DB error : $self->{accreddb}->{errmsg}";
    return;
  }
  $self->{logs}->log ($author, "addrole",
    $role->{name},
    $role->{unittype},
    $role->{labelfr},
    $role->{description},
  );
  $self->{notifier}->createAccredRole ($roleid, $author) if $self->{notifier};
  return 1;
}

sub modRole {
  my ($self, $role, $author) = @_;
  importmodules ($self, 'Logs', 'Notifier');
  my $roleid = $role->{id};

  my $oldrole = $self->getRole ($roleid);
  return unless $oldrole;

  my $status = $self->{accreddb}->dbrealupdate (
    table => 'roles',
      set => $role,
    where => {
      id => $roleid,
    },
  );
  unless ($status) {
    $self->{errmsg} = "DB error : $self->{accreddb}->{errmsg}";
    return;
  }
  
  my $newrole = $self->getRole ($roleid);
  return unless $newrole;

  my $notifyRoleRights = $oldrole->{hasrights} != $newrole->{hasrights};
  if ($notifyRoleRights) {
    # changeRoleRights sends notifications for each person that has the role
    $self->{notifier}->changeRoleRights ($roleid) if $self->{notifier};
  }

  my @logargs = ();
  foreach my $attr ('name', 'labelfr', 'labelxx', 'labelen', 'description') {
    push (@logargs, $attr, $oldrole->{$attr}, $newrole->{$attr})
      if ($newrole->{$attr} ne $oldrole->{$attr});
  }
  $self->{logs}->log ($author, 'modifyrole', $roleid, @logargs) if @logargs;
  # avoid doubling the notifications if changeRoleRights was already called
  $self->{notifier}->changeRole ($roleid) if $self->{notifier} && !$notifyRoleRights;
  return 1;
}

sub delRole {
  my ($self, $roleid, $author) = @_;
  importmodules ($self, 'Logs', 'Notifier');
  my @tables = (
    'roles_persons',
    'roles_rights',
  );
  foreach my $table (@tables) {
    my $status = $self->{accreddb}->dbdelete (
      table => $table,
      where => {
        roleid => $roleid,
      },
    );
    return unless $status;
  }
  my $status = $self->{accreddb}->dbdelete (
    table => 'roles',
    where => {
      id => $roleid,
    },
  );
  unless ($status) {
    $self->{errmsg} = "DB error : $self->{accreddb}->{errmsg}";
    return;
  }
  $self->{logs}->log ($author, "deleterole", $roleid);
  $self->{notifier}->removeAccredRole ($roleid, $author) if $self->{notifier};
  return 1;
}

sub getRightAdminByRole {
  my ($self, $roleid) = @_;
  my @rightids = $self->{accreddb}->dbselect (
    table => 'rights_roles',
     what => 'rightid',
    where => {
      roleid => $roleid,
    },
    order => 'rightid',
  );
  return @rightids;
}

sub getAdminRoles {
  my ($self, $rightid) = @_;
  my @roles = $self->{accreddb}->dbselect (
    table => 'rights_roles',
     what => 'roleid',
    where => {
      rightid => $rightid,
    },
    order => 'rightid'
  );
  return @roles;
}

sub getRoleManagingRights {
  my ($self, $roleid) = @_;
  my @rightids = $self->{accreddb}->dbselect (
    table => 'roles_rights',
     what => 'rightid',
    where => {
      roleid => $roleid,
    },
    order => 'rightid',
  );
  return @rightids;
}

sub getAllManagingRights {
  my $self = shift;
  my @results = $self->{accreddb}->dbselect (
       table => 'roles_rights',
        what => [ 'roleid', 'rightid' ],
    distinct => 1,
  );
  my $results;
  foreach my $result (@results) {
    push (@{$results->{$result->{roleid}}}, $result->{rightid});
  }
  return $results;
}

sub addManagingRight {
  my ($self, $roleid, $rightid) = @_;
  my @rights = $self->{accreddb}->dbselect (
    table => 'roles_rights',
     what => 'rightid',
    where => {
      roleid => $roleid,
    },
  );
  return if grep (/^$rightid$/, @rights);
  $self->{accreddb}->dbinsert (
    table => 'roles_rights',
      set => {
         roleid => $roleid,
        rightid => $rightid,
      },
  );
  return 1;
}

sub delManagingRight {
  my ($self, $roleid, $rightid) = @_;
  $self->{accreddb}->dbdelete (
    table => 'roles_rights',
    where => {
       roleid => $roleid,
      rightid => $rightid,
    },
  );
  return 1;
}


my $create = qq{
  create table roles_rights (
     roleid smallint,
    rightid smallint,
     debval datetime,
     finval datetime,
     index (roleid, rightid, debval, finval)
  );
};


1;

