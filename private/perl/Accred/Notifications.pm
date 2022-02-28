#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Notifications.pm
# Description:  Gestion des notifications aux évenèments.
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Tue Mar 22 15:06:37 CET 2016
# Version:      1.0
# Revision:     
#
##############################################################################
#
#
package Accred::Notifications;

use strict;
use utf8;

use Accred::Utils;
use Accred::Messages;

sub new {
  my ($class, $req) = @_;
  my  $self = {
         req => $req || {},
          db => undef,
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

sub notify {
  my ($self, %args) = @_;
  my $args = \%args;
  my $action = $args->{action};
  my $unitid = $args->{unitid};
  return unless ($action && $unitid);
  
  importmodules ($self, 'Persons', 'Roles', 'Rights', 'RolesAdmin', 'RightsAdmin');

  my $listenings = $self->loadlistenings ();
  $listenings = $listenings->{$action};
  my ($rights, $roles);
  foreach my $listener (keys %$listenings) {
    my $objects = $listenings->{$listener};
    foreach my $object (keys %$objects) {
      my $details = $objects->{$object};
      next if ($object ne 'all' && $object ne $args->{object});
      my  $reason = $details->{reason};
    
      if ($reason =~ /^role\s+(.*)$/) {
        my $rolename = $1;
        my     $role = $self->{rolesadmin}->getRole ($rolename);
        next unless $role; # Bogus role.
        my $roleid = $role->{id};
        push (@{$roles->{$roleid}}, {
          listener => $listener,
              role => $role,
            reason => $reason,
        });
      }
      elsif ($reason =~ /^right\s+(.*)$/) {
        my $rightname = $1;
        my     $right = $self->{rightsadmin}->getRight ($rightname);
        next unless $right; # Bogus right.
        my $rightid = $right->{id};
        push (@{$rights->{$rightid}}, {
          listener => $listener,
             right => $right,
            reason => $reason,
        });
      } else { next; } # Bogus listening.
    }
  }
  
  my $tonotify;
  foreach my $roleid (keys %$roles) {
    my $rup = $self->{roles}->getRoles (
      roleid => $roleid,
      unitid => $unitid,
    );
    next unless ($rup && $rup->{$roleid} && $rup->{$roleid}->{$unitid});
    my @persids = keys %{$rup->{$roleid}->{$unitid}};
    next unless @persids;
    foreach my $persid (@persids) {
      foreach my $details (@{$roles->{$roleid}}) {
        $tonotify->{$persid} = $details
          if ($details->{listener} eq 'all' || $details->{listener} eq $persid);
      }
    }
  }
  foreach my $rightid (keys %$rights) {
    my $rup = $self->{rights}->getRights (
      rightid => $rightid,
       unitid => $unitid,
    );
    next unless ($rup && $rup->{$rightid} && $rup->{$rightid}->{$unitid});
    my @persids = keys %{$rup->{$rightid}->{$unitid}};
    next unless @persids;
    foreach my $persid (@persids) {
      foreach my $details (@{$rights->{$rightid}}) {
        $tonotify->{$persid} = $details
          if ($details->{listener} eq 'all' || $details->{listener} eq $persid);
      }
    }
  }

  my @tonotify = keys %$tonotify ;
  my $dests = $self->{persons}->getPerson (\@tonotify);
  foreach my $destid (keys %$dests) {
    my $dest = $dests->{$destid};
    next unless ($dest && $dest->{email});
    my $details = $tonotify->{$destid};
    $self->sendnotification (
            to => $dest->{email},
        action => $args->{action},
        unitid => $args->{unitid},
        object => $args->{object},
        persid => $args->{persid},
      holderid => $args->{holderid},
       deputid => $args->{deputid},
        reason => $details->{reason},
        author => $args->{author},
    );
  }
}
sub sendnotification {
  my ($self, %args) = @_;
  my $args = \%args;  
  importmodules ($self, 'Roles', 'Units', 'Persons', 'RolesAdmin', 'RightsAdmin');

  return unless (
    $args->{to}     && $args->{action} && $args->{unitid} &&
    $args->{object} && $args->{persid} && $args->{reason} &&
    $args->{author}
  );

  my $test = 0;
  my $to = $args->{to};
  if ($test) {
    my $dest = $self->{persons}->getPerson ($args->{author});
    $to = $dest->{email};
  }
  my $unit = $self->{units}->getUnit ($args->{unitid});
  return unless $unit;

  my $person = $self->{persons}->getPerson ($args->{persid});
  return unless $person;
  
  my $action = $args->{action};
  my ($holderen, $holderfr);
  my $object;
  if ($action =~ /role$/) {
    $object = $self->{rolesadmin}->getRole ($args->{object});
  }
  elsif ($action =~ /right$/) {
    $object = $self->{rightsadmin}->getRight ($args->{object});
  }
  elsif ($action =~ /deputation$/) {
    return unless ($args->{holderid} && $args->{deputid});
    $object = $self->{rolesadmin}->getRole ($args->{object});
    if ($args->{holderid} ne $args->{author}) {
      my $holder = $self->{persons}->getPerson ($args->{holderid});
      $holderfr = "de $holder->{name} ";
      $holderen = "of $holder->{name} ";
    }
    $person = $self->{persons}->getPerson ($args->{deputid});
    return unless $person;
  }
  my $author = $self->{persons}->getPerson ($args->{author});
  return unless $author;
  #
  my $subjects = {
        grantrole => "Attribution d'un rôle / Role granting",
       revokerole => "Revocation d'un rôle / Role revocation",
       grantright => "Attribution d'un droit / Right granting",
      revokeright => "Revocation d'un droit / Right revocation",
        addaccred => "Ajout d'une accréditation / Accreditation added",
        remaccred => "Suppression d'une accréditation / Accreditation removed",
    adddeputation => "Nomination d'un remplaçant / Nomination of a deputy",
    remdeputation => "Suppression d'un remplaçant / Revocation of a deputy",
  };
  return unless $subjects->{$action};
  my $hasdone = {
    grantrole => {
      fr => "$author->{name} a attribué le rôle '$object->{name}' ".
            "à $person->{name} dans l'unité $unit->{name}",
      en => "$author->{name} has granted role '$object->{name}' ".
            "to $person->{name} in unit $unit->{name}",
    },
    revokerole => {
      fr => "$author->{name} a supprimé le rôle '$object->{name}' ".
            "à $person->{name} dans l'unité $unit->{name}",
      en => "$author->{name} has revoked role '$object->{name}' ".
            "to $person->{name} in unit $unit->{name}",
    },
    grantright => {
      fr => "$author->{name} a attribué le droit '$object->{name}' ".
            "à $person->{name} dans l'unité $unit->{name}",
      en => "$author->{name} has granted right '$object->{name}' ".
            "to $person->{name} in unit $unit->{name}",
    },
    revokeright => {
      fr => "$author->{name} a retiré le droit '$object->{name}' ".
            "à $person->{name} dans l'unité $unit->{name}",
      en => "$author->{name} has revoked right '$object->{name}' ".
            "to $person->{name} in unit $unit->{name}",
    },
    addaccred => {
      fr => "$author->{name} a ajouté une accréditation dans l'unité ".
            "$unit->{name} pour $person->{name}",
      en => "$author->{name} has added an accreditation in unit ".
            "$unit->{name} for $person->{name}",
    },
    remaccred => {
      fr => "$author->{name} a supprimé une accréditation dans l'unité ".
            "$unit->{name} pour $person->{name}",
      en => "$author->{name} has removed an accreditation in unit ".
            "$unit->{name} for $person->{name}",
    },
    adddeputation => {
      fr => "$author->{name} a nommé $person->{name} comme remplaçant $holderfr".
            "pour le rôle '$object->{labelfr}' ".
            "dans l'unité $unit->{name} ",
      en => "$author->{name} has named $person->{name} as deputy $holderfr".
            "for the role '$object->{labelen}' ".
            "in unit $unit->{name}",
    },
    remdeputation => {
      fr => "$author->{name} a supprimé $person->{name} comme remplaçant $holderfr".
            "pour le rôle '$object->{labelfr}' ".
            "dans l'unité $unit->{name} ",
      en => "$author->{name} has revoked $person->{name} as deputy $holderfr".
            "for the role '$object->{labelen}' ".
            "in unit $unit->{name}",
    },
  };
  
  my $reason = $args->{reason};
  my $reasonlabel;
  if ($reason =~ /^role\s+(.*)$/) {
    my $rolename = $1;
    my     $role = $self->{rolesadmin}->getRole ($rolename);
    return unless $role; # Bogus role.
    $reasonlabel = {
      fr => "vous êtes titulaire du rôle '$role->{labelfr}' ".
            "pour l'unite $unit->{name}",
      en => "you have role '$role->{labelen}' in $unit->{name}",
    };
  }
  elsif ($reason =~ /^right\s+(.*)$/) {
    my $rightname = $1;
    my     $right = $self->{rightsadmin}->getRight ($rightname);
    return unless $right; # Bogus right.
    $reasonlabel = {
      fr => "vous êtes titulaire du droit '$right->{labelfr}' ".
            "dans l'unite $unit->{name}",
      en => "you have right '$right->{labelen}' in $unit->{name}",
    };
  } else { # Bogus listening.
    return;
  }
  my $subject = $subjects->{$action};
  my    $body =
    "<br>\n".
    "----------------- English below --------------------<br>\n".
    "<br>\n".
    "  Bonjour,<br>\n".
    "<br>\n".
    "  Vous recevez cet email car $reasonlabel->{fr}.<br>\n".
    "<br>\n".
    "$hasdone->{$action}->{fr}".
    "<br>\n".
    "<br>\n".
    "    Merci.<br>\n".
    "<br>\n".
    "----------------------------------------------------<br>\n".
    "<br>\n".
    "  Hello,<br>\n".
    "<br>\n".
    "  You are receiving this email because $reasonlabel->{en}.<br>\n".
    "<br>\n".
    "$hasdone->{$action}->{en}".
    "<br>\n".
    "<br>\n".
    "    Thanks.<br>\n".
    "<br>\n";
  my $execmode = $self->{req}->{execmode};
  sendmail ($to, $subject, $body) if ($execmode eq 'prod');
}

sub addListening {
  my ($self, $action, $object, $persid, $reason) = @_;
  my $actions = $self->loadactions ();
  return error ($self, msg('BadAction', $action)) unless $actions->{$action};
  if ($object eq 'all') { # remove first all identical actions.
    my $status =  $self->{accreddb}->dbdelete (
      table => 'notifications_listenings',
      where => {
        action => $action,
        persid => $persid,
      },
    );
    
  }
  my $status =  $self->{accreddb}->dbinsert (
    table => 'notifications_listenings',
      set => {
        action => $action,
        object => $object,
        persid => $persid,
        reason => $reason,
      },
  );
  unless ($status) {
    $self->{errmsg} = "DB error : $self->{accreddb}->{errmsg}";
    return;
  }
  return 1,
}

sub delListening {
  my ($self, $action, $object, $persid) = @_;
  my $actions = $self->loadactions ();
  return error ($self, msg('BadAction', $action)) unless $actions->{$action};
  my $status =  $self->{accreddb}->dbdelete (
    table => 'notifications_listenings',
    where => {
      action => $action,
      object => $object,
      persid => $persid,
    },
  );
  unless ($status) {
    $self->{errmsg} = "DB error : $self->{accreddb}->{errmsg}";
    return;
  }
  return 1,
}

sub listlistenings {
  my ($self, $persid) = @_;
  my $results;
  my $listenings = $self->loadlistenings ();
  foreach my $action (keys %$listenings) {
    next unless $listenings->{$action}->{$persid};
    $results->{$action} = $listenings->{$action}->{$persid};
  }
  return $results;
}

sub listactions {
  my $self = shift;
  my $actions = $self->loadactions ();
  foreach my $actionname (keys %$actions) {
    $actions->{$actionname}->{label} = ($self->{lang} eq 'en')
      ? $actions->{$actionname}->{labelen}
      : $actions->{$actionname}->{labelfr}
      ;
  }
  return $actions;
}

sub loadlistenings {
  my $self = shift;
  my @results =  $self->{accreddb}->dbselect (
    table => 'notifications_listenings',
     what => [ '*', ],
  );
  my $listenings;
  foreach my $result (@results) {
    my $action = $result->{action};
    my $object = $result->{object};
    my $persid = $result->{persid};
    next unless ($action && $object && $persid);
    $listenings->{$action}->{$persid}->{$object} = $result;
  }
  return $listenings;
}

sub loadactions {
  my $self = shift;
  my @actions =  $self->{accreddb}->dbselect (
    table => 'notifications_actions',
     what => [ '*', ],
  );
  my $actions = { map { $_->{name}, $_ } @actions };
  return $actions;
}



sub notify_old {
  my ($self, %args) = @_;
  my $args = \%args;
  my $action = $args->{action};
  return unless $action;
  
  $self->notifyrolesadmin (
    $action, $args->{unitid}, $args->{objid}, $args->{persid}, $args->{author}
  );
  if ($action =~ /deputation$/) {
    $self->notifyrespfinance (%args);
  }
}

#
# Too specific, should be made mode generic.
#
sub notifyrolesadmin {
  my ($self, %args) = @_;
  my $args = \%args;
  
  importmodules ($self, 'Persons', 'Roles');

  my $action = $args->{action};
  my $unitid = $args->{unitid};
  return unless $unitid;
  my  $listenings = $self->loadlistenings ();
  my @adminsunits = $self->{roles}->ListRolesAdmins ($unitid);
  my $tonotify;
  foreach my $adminunit (@adminsunits) {
    my $adminid = $adminunit->{persid};
    my  $unitid = $adminunit->{unitid};
    next unless ($unitid =~ /^\d+$/); # Only Orgs.
    $tonotify->{$adminid} = 1 if $listenings->{$action}->{$adminid};
  }
  return unless ($tonotify && keys %$tonotify);
  
  my @tonotify = [ keys %$tonotify ];
  my $dests = $self->{persons}->getPerson (\@tonotify);
  foreach my $destid (keys %$dests) {
    my $dest = $dests->{$destid};
    next unless ($dest && $dest->{email});
    $self->sendnotification (
          to => $dest->{email},
      action => $args->{action},
      unitid => $args->{unitid},
      object => $args->{object},
      persid => $args->{persid},
      reason => 'right adminroles',
      author => $args->{author},
    );
  }
}
#
# Too specific, should be made mode generic.
#
sub notifyrespfinance {
  my ($self, %args) = @_;
  my $args = \%args;
  return unless ($args->{action} && ($args->{action} eq 'adddeputation'));
  
  importmodules ($self, 'Persons', 'Roles');

  my    $unitid = $args->{unitid};
  my $rolerffid = 13; # hoouuu.
  my $rup = $self->{roles}->getRoles (
    roleid => $rolerffid,
    unitid => $unitid,
  );
  return unless ($rup && $rup->{$rolerffid} && $rup->{$rolerffid}->{$unitid});
  my @rffids = keys %{$rup->{$rolerffid}->{$unitid}};
  return unless @rffids;

  my $dests = $self->{persons}->getPerson (\@rffids);
  foreach my $destid (keys %$dests) {
    my $dest = $dests->{$destid};
    next unless ($dest && $dest->{email});
    $self->sendnotification (
            to => $dest->{email},
        action => $args->{action},
        unitid => $args->{unitid},
        object => $args->{object},
        persid => $args->{deputid},
      holderid => $args->{persid},
        reason => 'role respfinance',
        author => $args->{author},
    );
  }
}

1;


