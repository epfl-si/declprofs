#!/usr/bin/perl
#
##############################################################################
#
# File Name:    RightsAdmin.pm
# Description:  
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Thu Feb  6 14:07:19 CET 2003
# Revision:     
#
##############################################################################
#
#
package Accred::RightsAdmin;

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

sub listAllRights { return listRights (@_); }
sub listRights {
  my ($self, $utype) = @_;
  my @rights;
  my @allrights = $self->{accreddb}->listAllObjects ('rights');
  foreach my $right (@allrights) {
    next if ($utype && ($right->{unittype} ne $utype));
    $right->{labelen} ||= $right->{labelfr};
    $right->{label} = ($self->{lang} eq 'en')
      ? $right->{labelen}
      : $right->{labelfr}
      ;
    $right->{type}    = 'Right';
    #$right->{nodeleg} = 1 if ($right->{name} eq 'fundadminroles'); # Should be in DB.
    push (@rights, $right)
  }
  my $utypes;
  foreach my $right (@rights) {
    push (@{$utypes->{$right->{unittype}}}, $right);
  }
  my     $ordre = 1;
  my    $config = new Accred::Config ();
  my $allutypes = $config->{unittypes};
  foreach my $utype (
        sort {
          $allutypes->{$a}->{order} <=> $allutypes->{$b}->{order}
        } keys %$utypes) {
    if ($utype eq 'Funds') {
      my @rlist = sort {
        if ($a->{name} =~ /^sig(\d+)$/) {
          my $av = $1;
          if ($b->{name} =~ /^sig(\d+)$/) {
            my $bv = $1;
            return int $av <=> int $bv;
          } else {
            return -1;
          }
        }
        elsif ($b->{name} =~ /^sig(\d+)$/) {
          return 1;
        } else {
          return $a->{name} cmp $b->{name};
        }
      } @{$utypes->{$utype}};
      map { $_->{ordre} = $ordre++ } @rlist;
    }
  }
  return @rights;
}

sub getRight {
  my ($self, $rightid) = @_;
  my $field = ($rightid =~ /^\d.*$/) ? 'id' : 'name';
  my $right = $self->{accreddb}->getObject (
      type => 'rights',
    $field => $rightid,
  );
  return unless $right;
  $right->{labelen} ||= $right->{labelfr};
  $right->{label} = ($self->{lang} eq 'en')
    ? $right->{labelen}
    : $right->{labelfr}
    ;
  $right->{type}    = 'Right';
  $right->{nodeleg} = 1 if ($right->{name} eq 'fundadminroles'); # Should be in DB.
  return $right;
}

sub getOldRight {
  my ($self, $rightid) = @_;
  my $field = ($rightid =~ /^\d.*$/) ? 'id' : 'name';
  my $right = $self->{accreddb}->getObject (
      type => 'olddroits',
    $field => $rightid,
  );
  $right->{labelen} ||= $right->{labelfr};
  $right->{label} = ($self->{lang} eq 'en')
    ? $right->{labelen}
    : $right->{labelfr}
    ;
  return $right;
}

sub addRight {
  my ($self, $right, $author) = @_;
  importmodules ($self, 'Logs', 'Notifier');
  my $rightid = $self->{accreddb}->dbinsert (
    table => 'rights',
      set => $right,
  );
  unless ($rightid) {
    $self->{errmsg} = "DB error : $self->{accreddb}->{errmsg}";
    return;
  }
    $self->{logs}->log ($author, "addright",
    $right->{name},
    $right->{unittype},
    $right->{labelfr},
    $right->{description},
  );
  $self->{notifier}->createAccredRight ($rightid, $author)
    if $self->{notifier};
  return 1;
}

sub modRight {
  my ($self, $right, $author) = @_;
  importmodules ($self, 'Notifier', 'Logs');
  my $rightid = $right->{id};

  my $oldright = $self->getRight ($rightid);
  return unless $oldright;

  my $status = $self->{accreddb}->dbrealupdate (
    table => 'rights',
      set => $right,
    where => {
      id => $rightid,
    },
  );
  unless ($status) {
    $self->{errmsg} = "DB error : $self->{accreddb}->{errmsg}";
    return;
  }
  
  my $newright = $self->getRight ($rightid);
  return unless $newright;

  my @logargs = ();
  foreach my $attr ('name', 'labelfr', 'labelxx', 'labelen', 'description') {
    push (@logargs, $attr, $oldright->{$attr}, $newright->{$attr})
      if ($newright->{$attr} ne $oldright->{$attr});
  }
  $self->{logs}->log ($author, 'modifyright', $rightid, @logargs) if @logargs;
  $self->{notifier}->changeRight ($rightid) if $self->{notifier};
  return 1;
}

sub deleteRight {
  my ($self, $rightid, $author) = @_;
  importmodules ($self, 'Logs', 'Notifier');
  my @tables = (
    'rights_classes',
    'rights_persons',
    'rights_roles',
    'rights_statuses',
    'rights_units',
  );
  foreach my $table (@tables) {
    my $status = $self->{accreddb}->dbdelete (
      table => $table,
      where => {
        rightid => $rightid,
      },
    );
    return unless $status;
  }
  my $status = $self->{accreddb}->dbdelete (
    table => 'rights',
    where => {
      id => $rightid,
    },
  );
  unless ($status) {
    $self->{errmsg} = "DB error : $self->{accreddb}->{errmsg}";
    return;
  }
  $self->{logs}->log ($author, "deleteright", $rightid);
  $self->{notifier}->removeAccredRight ($rightid, $author)
    if $self->{notifier};

  return 1;
}

sub getRightPolicy {
  my ($self, $rightid) = @_;
  my @statuses = $self->{accreddb}->dbselect (
    table => 'rights_statuses',
     what => 'statusid',
    where => {
      rightid => $rightid,
    },
  );
  my $policy;
  foreach my $statusid (@statuses) {
    push (@{$policy->{statuses}}, $statusid);
  }

  my @classes = $self->{accreddb}->dbselect (
    table => 'rights_classes',
     what => 'classid',
    where => {
      rightid => $rightid,
    },
  );
  foreach my $classe (@classes) {
    push (@{$policy->{classes}}, $classe);
  }

  my @roles = $self->{accreddb}->dbselect (
    table => 'rights_roles',
     what => 'roleid',
    where => {
      rightid => $rightid,
    },
  );
  foreach my $roleid (@roles) {
    push (@{$policy->{roles}}, $roleid);
  }

  my @unitvals = $self->{accreddb}->dbselect (
    table => 'rights_units',
     what => [ 'unitid', 'value' ],
    where => {
      rightid => $rightid,
    },
  );
  foreach my $unitval (@unitvals) {
    push (@{$policy->{units}}, [$unitval->{unitid}, $unitval->{value}]);
  }
  return $policy;
}

sub setRightPolicy {
  my ($self, $rightid, $newpolicy) = @_;
  my  $oldpolicy = $self->getRightPolicy ($rightid);
  #
  # Statuses
  #
  my %newstatuses = map { $_, 1 } @{$newpolicy->{statuses}};
  my %oldstatuses = map { $_, 1 } @{$oldpolicy->{statuses}};
  foreach my $oldstatus (keys %oldstatuses) {
    next if $newstatuses {$oldstatus};
    $self->{accreddb}->dbdelete (
      table => 'rights_statuses',
      where => {
         rightid => $rightid,  
        statusid => $oldstatus,
      },
    );
  }
  foreach my $newstatus (keys %newstatuses) {
    next if $oldstatuses {$newstatus};
    $self->{accreddb}->dbinsert (
      table => 'rights_statuses',
        set => {
           rightid => $rightid,
          statusid => $newstatus,
        },
    );
  }
  #
  # Classes
  #
  my %newclasses = map { $_, 1 } @{$newpolicy->{classes}};
  my %oldclasses = map { $_, 1 } @{$oldpolicy->{classes}};
  foreach my $classid (keys %oldclasses) {
    next if $newclasses {$classid};
    $self->{accreddb}->dbdelete (
      table => 'rights_classes',
      where => {
        rightid => $rightid,
         classe => $classid,
      },
    );
  }
  foreach my $classid (keys %newclasses) {
    next if $oldclasses {$classid};
    $self->{accreddb}->dbinsert (
      table => 'rights_classes',
        set => {
          rightid => $rightid,
          classid => $classid,
        },
    );
  }
  #
  # Roles
  #
  my %newroles = map { $_, 1 } @{$newpolicy->{roles}};
  my %oldroles = map { $_, 1 } @{$oldpolicy->{roles}};
  foreach my $oldrole (keys %oldroles) {
    next if $newroles {$oldrole};
    $self->{accreddb}->dbdelete (
      table => 'rights_roles',
      where => {
        rightid => $rightid,
         roleid => $oldrole,
      },
    );
  }
  foreach my $newrole (keys %newroles) {
    next if $oldroles {$newrole};
    $self->{accreddb}->dbinsert (
      table => 'rights_roles',
        set => {
          rightid => $rightid,
           roleid => $newrole,
        },
    );
  }
  return 1;
}

sub getAdminRoles {
  my ($self, $rightid) = @_;
  my @roleids = $self->{accreddb}->dbselect (
    table => 'rights_roles',
     what => 'roleid',
    where => {
      rightid => $rightid,
    },
  );
  return @roleids;
}

sub getRolesManaged {
  my ($self, $rightid) = @_;
  my @roleids = $self->{accreddb}->dbselect (
    table => 'roles_rights',
     what => 'roleid',
    where => {
      rightid => $rightid,
    },
    order => 'roleid',
  );
  return @roleids;
}

sub addAdminRole {
  my ($self, $rightid, $roleid) = @_;
  importmodules ($self, 'Notifier', 'RolesAdmin');
  my @roles = $self->{accreddb}->dbselect (
    table => 'rights_roles',
     what => 'roleid',
    where => {
      rightid => $rightid,
    },
  );
  return if grep (/^$roleid$/, @roles);
  $self->{accreddb}->dbinsert (
    table => 'rights_roles',
      set => {
        rightid => $rightid,
         roleid => $roleid,
      },
  );
  my $role = $self->{rolesadmin}->getRole($roleid);
  $self->{notifier}->changeRoleRights ($roleid) if $self->{notifier} && $role->{hasrights};
  return 1;
}

sub delAdminRole {
  my ($self, $rightid, $roleid) = @_;
  importmodules ($self, 'Notifier', 'RolesAdmin');
  $self->{accreddb}->dbdelete (
    table => 'rights_roles',
    where => {
      rightid => $rightid,
       roleid => $roleid,
    },
  );
  my $role = $self->{rolesadmin}->getRole($roleid);
  $self->{notifier}->changeRoleRights ($roleid) if $self->{notifier} && $role->{hasrights};
  return 1;
}

sub addDefaultStatus {
  my ($self, $rightid, $statusid) = @_;
  importmodules ($self, 'Notifier');
  my @statuses = $self->{accreddb}->dbselect (
    table => 'rights_statuses',
     what => 'statusid',
    where => {
      rightid => $rightid,
    },
  );
  return if grep (/^$statusid$/, @statuses);
  $self->{accreddb}->dbinsert (
    table => 'rights_statuses',
      set => {
         rightid => $rightid,
        statusid => $statusid,
      },
  );
  $self->{notifier}->changeStatusRights ($statusid) if $self->{notifier};
  return 1;

}

sub delDefaultStatus {
  my ($self, $rightid, $statusid) = @_;
  importmodules ($self, 'Notifier');
  $self->{accreddb}->dbdelete (
    table => 'rights_statuses',
    where => {
       rightid => $rightid,
      statusid => $statusid,
    },
  );
  $self->{notifier}->changeStatusRights ($statusid) if $self->{notifier};
}

sub addDefaultClass {
  my ($self, $rightid, $classid) = @_;
  importmodules ($self, 'Notifier');
  my @classes = $self->{accreddb}->dbselect (
    table => 'rights_classes',
     what => 'classid',
    where => {
      rightid => $rightid,
    },
  );
  return if grep (/^$classid$/, @classes);
  $self->{accreddb}->dbinsert (
    table => 'rights_classes',
      set => {
        rightid => $rightid,
        classid => $classid,
      },
  );
  $self->{notifier}->changeClassRights ($classid) if $self->{notifier};
  return 1;
}

sub delDefaultClass {
  my ($self, $rightid, $classid) = @_;
  importmodules ($self, 'Notifier');
  $self->{accreddb}->dbdelete (
    table => 'rights_classes',
    where => {
      rightid => $rightid,
      classid => $classid,
    },
  );
  $self->{notifier}->changeClassRights ($classid) if $self->{notifier};
}

sub addUnitPolicy {
  my ($self, $rightid, $unitid, $value) = @_;
  importmodules ($self, 'Notifier');
  if ($value eq 'd') {
    $self->{accreddb}->dbdelete (
      table => 'rights_units',
      where => {
        rightid => $rightid,
         unitid => $unitid,
      },
    );
  } else {
    $self->{accreddb}->dbupdate (
      table => 'rights_units',
        set => {
          value => $value,
        },
      where => {
        rightid => $rightid,
         unitid => $unitid,
      },
    );
  }
  $self->{notifier}->changeUnitRights ($unitid) if $self->{notifier};
  return 1;
}

sub delUnitPolicy {
  my ($self, $rightid, $unitid) = @_;
  importmodules ($self, 'Notifier');
  $self->{accreddb}->dbdelete (
    table => 'rights_units',
    where => {
      rightid => $rightid,
       unitid => $unitid,
    },
  );
  $self->{notifier}->changeUnitRights ($unitid) if $self->{notifier};
  return 1;
}



1;


