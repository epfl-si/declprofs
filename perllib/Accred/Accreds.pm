#
##############################################################################
#
# File Name:    Accreds.pm
# Description:  
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Fri Nov 12 13:05:45 CET 2004
# Revision:    
#
##############################################################################
#
#
package Accred::Accreds;

use strict;
use utf8;
use Carp;

use Accred::Utils;

our $errmsg;

my $revtime = '1m';
my $durees = {
  '1j' =>    86400, # 1 day.
  '1s' =>   604800, # 1 week.
  '2s' =>  1209600, # 2 weeks.
  '3s' =>  1814400, # 3 weeks.
  '1m' =>  2678400, # 1 month.
  '3m' =>  7948800, # 3 months.
  '6m' => 15811200, # 6 months.
  '1a' => 31536000, # 1 year.
};

my $persstatusid = 1;
my $hotestatusid = 2;
my $horsstatusid = 3;

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
  $self->{lang}    = $req->{lang} || 'en';
  $self->{dateref} = $req->{dateref};
  Accred::Utils::import ();
  importmodules ($self, 'AccredDB');
  return $self;
}

#
# Accreditations
#

sub getAccred {
  my ($self, $persid, $unitid, @optargs) = @_;
  my @accreds = $self->{accreddb}->dbselect (
    table => 'accreds',
     what => [ '*' ],
    where => {
      persid => $persid,
      unitid => $unitid,
    },
    @optargs,
  );
  return unless @accreds;
  my $accred = $accreds [0];
  $accred->{datefin} = undef if ($accred->{datefin} =~ /^0000/);
  return $accred;
}

sub getAccredsOfUnit {
  my ($self, $unitid, @optargs) = @_;  
  importmodules ($self, 'Persons');
  my @accreds = $self->{accreddb}->dbselect (
    table => 'accreds',
     what => [ '*' ],
    where => { unitid => $unitid },
    @optargs,
  );
  my @persids = ();
  foreach my $accred (@accreds) {
    push (@persids, $accred->{persid});
  }
  my $persons = $self->{persons}->getPersons (\@persids);
  foreach my $accred (@accreds) {
    my $person = $persons->{$accred->{persid}};
    $accred->{persname} = ($person && $person->{rname})
      ? $person->{rname}
      : $accred->{persid};
  }
  return @accreds;
}

sub listAccredsUnderUnit {
  my ($self, $unitid, @optargs) = @_;  
  importmodules ($self, 'Units');
  $unitid ||= 10000; # EPFL
  my @unitids = $self->{units}->listDescendantsIds ($unitid);
  push (@unitids, $unitid);
  return unless @unitids;
  
  my @accreds = $self->{accreddb}->dbselect (
    table => 'accreds',
     what => [ '*' ],
    where => { unitid => \@unitids },
    @optargs,
  );
  return @accreds;
}

sub getAccredsOfPerson {
  my ($self, $persid, @optargs) = @_;
  importmodules ($self, 'AccredDB');
  my @accreds = $self->{accreddb}->dbselect (
    table => 'accreds',
     what => [ '*' ],
    where => { persid => $persid },
    order => 'ordre',
    @optargs,
  );
  return @accreds;
}

sub setAccredsOrder {
  my ($self, $author, $persid, @units) = @_;
  importmodules ($self, 'Logs', 'Notifier');

  my @modargs;
  my $ordre = 1;
  foreach my $unit (@units) {
    my $oldaccred = $self->getAccred ($persid, $unit);
    if ($oldaccred->{ordre} ne $ordre) {
      push (@modargs, $unit, $oldaccred->{ordre}, $ordre);
    }

    $self->{accreddb}->dbupdate (
      table => 'accreds',
        set => {  ordre => $ordre },
      where => {
        persid => $persid,
        unitid => $unit,
      },
    updonly => 1,
    );
    $ordre++;
  }
  $self->{logs}->log ($author, 'setaccredsorder', $persid, @units);
  $self->{notifier}->changeAccredsOrder ($persid, $author, @modargs)
    if $self->{notifier};
}

sub setAccredsOrderInternal {
  my ($self, $persid) = @_;
  my @accreds = $self->getAccredsOfPerson ($persid);
  return unless @accreds;
  my $personnel =  1;
  my $doctorant = 12;
  my @newaccreds;
  if ($accreds [0]->{classid} == $doctorant) {
    push (@newaccreds, shift @accreds);
    my $shifted;
    foreach my $accred (@accreds) {
      if (!$shifted && $accred->{statusid} == $personnel) {
        unshift (@newaccreds, $accred);
        $shifted = 1;
      } else {
        push (@newaccreds, $accred);
      }
    }
  } else {
    @newaccreds = @accreds;
  }
  my $order = 1;
  foreach my $accred (@newaccreds) {
    $self->{accreddb}->dbupdate (
      table => 'accreds',
        set => { ordre => $order },
      where => { 
        persid => $accred->{persid},
        unitid => $accred->{unitid},
      },
      nohist => 1,
    );
    $order++;
  }
}

sub isPersonnel {
  my ($self, $persid) = @_;
  my @accreds = $self->getAccredsOfPerson ($persid);
  my $ispers;
  foreach my $accred (@accreds) {
    if ($accred->{statusid} == $persstatusid) {
      $ispers = 1;
      last;
    }
  }
  return $ispers;
}

#
# Status
#

sub getStatus {
  my ($self, $statusid) = @_;
  my $status = $self->{accreddb}->getObject (
    type => 'statuses',
      id => $statusid,
  );
  $status ||= {
             id => $statusid,
           name => '',
        labelfr => '',
        labelen => '',
    description => '',
       maillist => '',
  };
  $status->{labelen} ||= $status->{labelfr};
  $status->{label} = ($self->{lang} eq 'en')
    ? $status->{labelen}
    : $status->{labelfr}
    ;
  return $status;
}

sub listAllStatuses {
  my ($self) = @_;
  my @statuses = $self->{accreddb}->listAllObjects (
    'statuses',
  );
  foreach my $status (@statuses) {
    $status->{labelen} ||= $status->{labelfr};
    $status->{label} = ($self->{lang} eq 'en')
      ? $status->{labelen}
      : $status->{labelfr}
      ;
  }
  return @statuses;
}

sub getStatusAccreds {
  my ($self, $statusid) = @_;
  return unless $statusid;

  my @accreds = $self->{accreddb}->dbselect (
    table => 'accreds',
     what => [ '*' ],
    where => { statusid => $statusid }
  );

  return @accreds;
}

#
# Private email.
#

sub getPrivateEmail {
  my ($self, $persid, @optargs) = @_;
  my @emails = $self->{accreddb}->dbselect (
    table => 'privateemails',
     what => [ 'email' ],
    where => { persid => $persid },
    noval => 1,
  );
  return unless @emails;
  return $emails [0]->{email};
}

sub getNewPrivateEmail {
  my ($self, $persid, @optargs) = @_;
  my @emails = $self->{accreddb}->dbselect (
    table => 'privateemails',
     what => [ 'email' ],
    where => { persid => $persid, status => 0 },
    noval => 1,
  );
  return unless @emails;
  return $emails [0]->{email};
}

sub setPrivateEmail {
  my ($self, $persid, $unitid, $email, $userid) = @_;
  my $oldemail = $self->getPrivateEmail ($persid);
  if ($oldemail) {
    $self->{accreddb}->dbupdate (
       table => 'privateemails',
         set => {  email => $email, },
       where => { persid => $persid, },
      nohist => 1,
       noval => 1,
    );
  
  } else {
    $self->{accreddb}->dbinsert (
      table => 'privateemails',
          set => {
            persid => $persid,
             email => $email,
          },
       nohist => 1,
        noval => 1,
    );
  }
  $self->{logs}->log ($userid, "modaccr", $persid, $unitid, 'privmail', $oldemail, $email);
  return $email;
}

sub usePrivateEmail {
  my ($self, $persid, @optargs) = @_;
  $self->{accreddb}->dbupdate (
     table => 'privateemails',
       set => { status => 1, },
     where => { persid => $persid, },
    nohist => 1,
     noval => 1,
  );
  return 1;
}

#
#  Classes
#

sub getClass {
  my ($self, $classid) = @_;
  my $class = $self->{accreddb}->getObject (
    type => 'classes',
      id => $classid,
  );
  $class ||= {
             id => $classid,
           name => '',
        labelfr => '',
    description => '',
       maillist => '',
  };
  $class->{labelen} ||= $class->{labelfr};
  $class->{label} = ($self->{lang} eq 'en')
    ? $class->{labelen}
    : $class->{labelfr}
    ;
  return $class;
}

sub listAllClasses {
  my ($self, $statusid) = @_;
  my @classes;
  if ($statusid) {
     @classes = $self->{accreddb}->dbselect (
        table => 'classes',
         what => [ '*' ],
        where => { statusid => $statusid },
    );
  } else {
    @classes = $self->{accreddb}->listAllObjects (
      'classes',
    );
  }
  foreach my $class (@classes) {
    $class->{labelen} ||= $class->{labelfr};
    $class->{label} = ($self->{lang} eq 'en')
      ? $class->{labelen}
      : $class->{labelfr}
      ;
  }
  return @classes;
}

sub getClassAccreds {
  my ($self, $classid) = @_;
  return unless $classid;

  my @accreds = $self->{accreddb}->dbselect (
    table => 'accreds',
     what => [ '*' ],
    where => { classid => $classid }
  );

  return @accreds;
}

#
#
#

sub getActionUnits {
  my ($self, $persid, @optargs) = @_;
  importmodules ($self, 'Rights', 'Roles');
  return unless $persid;

  my $result;
  #
  # Roles.
  #
  my $rup = $self->{roles}->getRoles (
      persid => $persid,
    noexpand => 1,
  );
  foreach my $roleid (keys %$rup) {
    foreach my $unitid (keys %{$rup->{$roleid}}) {
      my $value = $rup->{$roleid}->{$unitid}->{$persid};
      $result->{$unitid} = 1 if ($value =~ /^y/);
    }
  }
  #
  # Accred right.
  #
  my $rup = $self->{rights}->getRights (
      persid => $persid,
     rightid => 1, # accreditation
    noexpand => 1,
  );
  foreach my $rightid (sort keys %$rup) {
    foreach my $unitid (sort keys %{$rup->{$rightid}}) {
      my $value = $rup->{$rightid}->{$unitid}->{$persid};
      $result->{$unitid} = 1 if ($value =~ /^y/);
    }
  }
  #
  # Roles managers.
  #
  my $isrolesmanager = $self->{roles}->isRolesManager (
      persid => $persid,
    noexpand => 1,
  );
  foreach my $roleid (keys %$isrolesmanager) {
    foreach my $unitid (keys %{$isrolesmanager->{$roleid}}) {
      $result->{$unitid} = $isrolesmanager->{$roleid}->{$unitid};
    }
  }
  return $result
}

sub loadSuperRights {
  my $self = shift;
  my @rows = $self->{accreddb}->dbselect (
    table => 'superrights',
     what => [ '*' ],
  );
  my $supers;
  foreach my $row (@rows) {
    my   $name = $row->{name};
    my    $env = $row->{env};
    my $persid = $row->{persid};
    $supers->{$name}->{$env}->{$persid} = 1;
  }
  foreach my $name (keys %$supers) { # prod => test
    foreach my $persid (keys %{$supers->{$name}->{prod}}) {
      $supers->{$name}->{test}->{$persid} = $supers->{$name}->{prod}->{$persid};
    }
  }
  return $supers;
}

sub isAccreditor {
  my ($self, $persid) = @_;
  importmodules ($self, 'Rights', 'RightsAdmin');
  
  my $right = $self->{rightsadmin}->getRight ('accreditation');
  return unless $right;
  my $rightid = $right->{id};
  my $rup = $self->{rights}->getRights (
    rightid => $right->{id},
     persid => $persid,
  );
  return unless ($rup && $rup->{$rightid});
  my @unitids;
  foreach my $unitid (keys %{$rup->{$rightid}}) {
    push (@unitids, $unitid) if ($rup->{$rightid}->{$unitid}->{$persid} =~ /^y/);
  }
  return @unitids;
}

sub addAccred {
  my ($self, $accred, $author) = @_;
  importmodules ($self, 'Persons', 'Logs', 'Notifier', 'Notifications');
  $self->{accreddb}->dbinsert (
    table => 'accreds',
      set => {
           persid => $accred->{persid},
           unitid => $accred->{unitid},
         statusid => $accred->{statusid},
          classid => $accred->{classid},
            posid => $accred->{posid},
          datedeb => $accred->{datedeb},
          datefin => $accred->{datefin}  || 'null',
          origine => $accred->{origine}  || 'm',
          comment => $accred->{comment}  || '',
         revalman => $accred->{revalman} || 'y',
           author => $author,
          creator => $author,
        datecreat => 'now',
            ordre => 1000,
      },
  ) || do {
    $errmsg = $self->{accreddb}->{errmsg};
    return;
  };
  $self->setAccredsOrderInternal ($accred->{persid});
  $self->{persons}->usePerson    ($accred->{persid});

  $self->{logs}->log ($author, 'addaccr',
    $accred->{persid},
    $accred->{unitid},
    $accred->{statusid},
    $accred->{classid},
    $accred->{posid},
    $accred->{datedeb},
    $accred->{datefin},
  );

  $self->{notifier}->addAccred (
    $accred->{persid},
    $accred->{unitid},
    $author,
  ) if $self->{notifier};

  $self->{notifications}->notify (
    action => 'addaccred',
    unitid => $accred->{unitid},
    object => undef,
    persid => $accred->{persid},
    author => $author,
  );
  return 1;
}

sub modAccred {
  my ($self, $accred, $author) = @_;
  importmodules ($self, 'Logs', 'Notifier');
  my $persid = $accred->{persid};
  my $unitid = $accred->{unitid};
  
  my $oldaccred = $self->getAccred ($persid, $unitid);
  $oldaccred->{datedeb} =~ s/ .*$//;
  $oldaccred->{datefin} =~ s/ .*$//;

  my $set;
  if (exists $accred->{datefin} && $accred->{datefin} ne $oldaccred->{datefin}) {
    $set->{revalman}  = ($author eq '000000') ? 'n' : 'y';
    $set->{datereval} = 'now';
  }
  my @logargs;
  foreach my $key ('statusid', 'classid', 'posid', 'datedeb', 'datefin',
                   'comment', 'revalman', 'origine') {
    if (exists $accred->{$key} && $accred->{$key} ne $oldaccred->{$key}) {
      $set->{$key} = $accred->{$key};
      push (@logargs, $key, $oldaccred->{$key}, $accred->{$key});
    }
  }
  return -1 unless ($set && keys %$set);
  $set->{author} = $author;

  $self->{accreddb}->dbupdate (
    table => 'accreds',
      set => $set,
    where => {
      unitid => $unitid,
      persid => $persid,
    }
  );
  #
  # Logs
  #
  $self->{logs}->log ($author, "modaccr", $persid, $unitid, @logargs);
  $self->{notifier}->modAccred ($persid, $unitid, $author, @logargs)
    if $self->{notifier};

  return 1;
}

sub remAccred {
  my ($self, $accred, $author, $flags) = @_;
  return unless ($accred && $accred->{persid} && $accred->{unitid});
  importmodules ($self, 'Logs', 'Notifier', 'Notifications');
  my $persid = $accred->{persid};
  my $unitid = $accred->{unitid};

  $self->{accreddb}->dbdelete (
    table => 'accreds',
    where => {
      persid => $persid,
      unitid => $unitid,
    },
    author => $author
  );
  $self->{accreddb}->dbdelete (
    table => 'accreds_properties',
    where => {
      persid => $persid,
      unitid => $unitid,
    },
  );
  $self->setAccredsOrderInternal ($persid);
  $self->purgePersonUnit ($unitid, $persid, $author);

  $self->{logs}->log ($author, "remaccr", $persid, $unitid);
  $self->{notifier}->remAccred ($persid, $unitid, $author)
    if $self->{notifier};
  $self->{notifications}->notify (
    action => 'remaccred',
    unitid => $unitid,
    object => undef,
    persid => $persid,
    author => $author,
  );
  
  my @accreds = $self->getAccredsOfPerson ($persid);
  my $topurge = 1;
  foreach my $accred (@accreds) { # Keep only first class statuses.
    if (1 || ($accred->{statusid} >= 1 && $accred->{statusid} <= 5)) { # Not sure what to do.
      $topurge = 0;
      last;
    }
  }
  if ($topurge) { # C'est la dernière bonne accreditation pour cette personne,
                  # il faut nettoyer.
    $self->purgePerson ($persid, $author);
    $self->{notifier}->removeLastAccred ($persid, $unitid, $author)
      if $self->{notifier};
  }
  my $unitstoignore = {
    12030 => 1,
  };
  $self->warnRolesandRights ($accred) unless $unitstoignore->{$unitid};
  return 1;
}

sub setStatus {
  my ($self, $accred, $statusid, $author) = @_;
  importmodules ($self, 'Logs', 'Notifier');
  my $persid = $accred->{persid};
  my $unitid = $accred->{unitid};
  
  my $oldaccred = $self->getAccred ($persid, $unitid);
  unless ($oldaccred) {
    warn "Accreds::setStatus: Unknown accred ($persid, $unitid)\n";
    return;
  }
  $self->{accreddb}->dbupdate (
     table => 'accreds',
       set => {
         statusid => $statusid,
       },
     where => {
       persid => $persid,
       unitid => $unitid,
     },
    auteur => $author,
  );
  $self->{logs}->log ($author, "modaccr", $persid, $unitid,
                      'statusid', $oldaccred->{statusid}, $statusid);
  $self->{notifier}->modAccred ($persid, $unitid, $author)
    if $self->{notifier};
  return 1;
}

sub setPosition {
  my ($self, $accred, $posid, $author) = @_;
  importmodules ($self, 'Logs', 'Notifier');
  my $persid = $accred->{persid};
  my $unitid = $accred->{unitid};
  
  my $oldaccred = $self->getAccred ($persid, $unitid);
  unless ($oldaccred) {
    warn "Accreds::setPosition: Unknown accred ($persid, $unitid)\n";
    return;
  }
  $self->{accreddb}->dbupdate (
     table => 'accreds',
       set => {
         posid => $posid,
       },
     where => {
       persid => $persid,
       unitid => $unitid,
     },
    auteur => $author,
  );
  $self->{logs}->log ($author, "modaccr", $persid, $unitid,
                      'posid', $oldaccred->{posid}, $posid);
  $self->{notifier}->modAccred ($persid, $unitid, $author)
    if $self->{notifier};
  return 1;
}

sub accredDistance {
  my ($self, $persid, $unitid) = @_;
  importmodules ($self, 'Units');
  my  @accreds = $self->getAccredsOfPerson ($persid);
  my $distance = 5;
  my  $unit = $self->{units}->getUnit ($unitid);
  return $distance unless $unit;
  my $unitpath = $unit->{upath};
  my @unitpath = split (/\s+/, $unitpath);
  
  foreach my $accred (@accreds) {
    my $d = $distance;
    my $unitid = $accred->{unitid};
    my $accunitinfo = $self->{units}->getUnit   ($unitid);
    next unless $accunitinfo;
    my $accunitpath = $accunitinfo->{upath};
    next unless $accunitpath;
    my @accunitpath = split (/\s+/, $accunitpath);
    if ($accunitpath [0] eq $unitpath [0]) {
      $d = 4;
      if ($accunitpath [1] eq $unitpath [1] || !$unitpath [1]) {
        $d = 3;
        if ($accunitpath [2] eq $unitpath [2] || !$unitpath [2]) {
          $d = 2;
          if (!$unitpath [3]) {
            $d = 1;
          }
          elsif ($accunitpath [3] eq $unitpath [3]) {
            $d = 0;
          }
        }
      }
    }
    $distance = $d if ($d < $distance);
  }
  return $distance;
}

#
# Warns admins.
#

sub warnRolesandRights {
  my ($self, $accred) = @_;
  my $persid = $accred->{persid};
  importmodules ($self, 'Units', 'Rights', 'Roles', 'RightsAdmin', 'RolesAdmin');
  my $rup = $self->{rights}->getExplicitRights (
    persid => $persid,
  );
  my ($rightsinfos, $rightuinfos);
  my $mails;
  foreach my $rightid (keys %$rup) {
    foreach my $unitid (keys %{$rup->{$rightid}}) {
      my $value = $rup->{$rightid}->{$unitid};
      next unless ($value eq 'y');
      $rightsinfos->{$rightid} ||= $self->{rightsadmin}->getRight ($rightid);
      my $unit = $self->{units}->getUnit ($unitid);
      $rightuinfos->{$unitid}  ||= $unit;
      my @admins = $self->{rights}->ListFirstRightAdmins ($rightid, $unitid);
      warn "No admins found for right $rightsinfos->{$rightid}->{name} ",
           "in $rightuinfos->{$unitid}->{name}\n" unless @admins;
      foreach my $admin (@admins) {
        my $adminscip = $admin->{persid};
        my $adminunit = $admin->{unitid};
        my $adminrole = $admin->{roleid};
        next if ($adminscip == $persid);
        push (@{$mails->{$adminscip}}, {
              type => 'right',
          unitinfo => $rightuinfos->{$unitid},
              info => $rightsinfos->{$rightid},
        });
      }
    }
  }
  my $rup = $self->{roles}->getRoles (
    persid => $persid,
  );
  return unless $rup;
  my ($rolesinfos, $roleuinfos);
  foreach my $roleid (keys %$rup) {
    foreach my $unitid (keys %{$rup->{$roleid}}) {
      my $value = $rup->{$roleid}->{$unitid};
      next unless ($value eq 'y');
      $rolesinfos->{$roleid}  ||= $self->{rolesadmin}->getRole ($roleid);
      my $unit = $self->{units}->getUnit ($unitid);
      $roleuinfos->{$unitid} ||= $unit;
      my @admins = $self->{roles}->ListFirstRolesAdmins ($roleid, $unitid);
      warn "No admins found for role $rolesinfos->{$roleid}->{name} ",
           "in $roleuinfos->{$unitid}->{name}\n" unless @admins;
      foreach my $admin (@admins) {
        my $adminscip = $admin->{persid};
        my $adminunit = $admin->{unitid};
        my $adminrole = $admin->{roleid};
        next if ($adminscip == $persid);
        push (@{$mails->{$adminscip}}, {
              type => 'role',
          unitinfo => $roleuinfos->{$unitid},
              info => $rolesinfos->{$roleid},
        });
      }
    }
  }
  
  $self->sendrightadminssummary ($accred, $mails) if $mails;
  #$self->sendmailtorightadmins  ($accred, $mails) if $mails;
}

#
# History
#

sub getHistory {
  my ($self, $persid, $unitid) = @_;
  return unless ($persid || $unitid);
  my $where;
  $where->{persid} = $persid if $persid;
  $where->{unitid} = $unitid if $unitid;
  my @accreds = $self->{accreddb}->dbselect (
      table => 'accreds',
       what => [ '*' ],
      where => $where,
    listold => 1,
  );
  @accreds = reverse @accreds;
  my @histrecs = $self->{accreddb}->dbselect (
      table => 'history',
       what => [ '*' ],
      where => $where,
      order => 'dateoper',
    listold => 1,
  );
  my ($statusids, $classids);
  my @statuses = $self->listAllStatuses (listold => 1);
  foreach my $status (@statuses) {
    $statusids->{$status->{name}} = $status->{id};
  }
  my @classes = $self->listAllClasses (listold => 1);
  foreach my $class (@classes) {
    $classids->{$class->{name}} = $class->{id};
  }
  foreach my $histrec (reverse @histrecs) {
    my $accred;
    $accred->{persid}    = $histrec->{persid};
    $accred->{unitid}    = $histrec->{unitid};
    $accred->{statusid}  = $statusids->{$histrec->{statusid}};
    $accred->{classid}   = $classids->{$histrec->{classid}};
    $accred->{posid}     = $histrec->{posid};
    $accred->{datedeb}   = $histrec->{datedeb};
    $accred->{datefin}   = $histrec->{datefin};
    $accred->{creator}   = $histrec->{creator};
    $accred->{datecreat} = $histrec->{datecreat};
    $accred->{author}    = $histrec->{respons};
    $accred->{debval}    = $histrec->{debval};
    $accred->{finval}    = $histrec->{finval};
    push (@accreds, $accred);
  }
  return @accreds;
}

#
# Revalidation
#
sub needRevalidation {
  my ($self, $unitid) = @_;
  my     $now = time;
  my @accreds = $self->{accreddb}->dbselect (
    table => 'accreds',
     what => [ '*' ],
    where => { unitid => $unitid }
  );
  use Time::Local;
  foreach my $accred (@accreds) {
    my $datefin = $accred->{datefin};
    return 0 unless $datefin;
    my  $origine = $accred->{origine};
    my $revalman = $accred->{revalman};
    next if ($revalman ne 'y' && $origine =~ /^[pse]$/);
    my ($afin, $mfin, $jfin) = ($datefin =~ /^(\d*)-(\d*)-(\d*) /);
    my $timefin = timelocal (59, 59, 23, $jfin, $mfin - 1, $afin);
    return 1 if ($timefin < $now + $durees->{$revtime});
  }
  return 0;
}

sub neededRevalidation {
  my ($self, $unitid) = @_;
  my $now = time;
  my @accreds = $self->{accreddb}->dbselect (
    table => 'accreds',
     what => [ '*' ],
    where => { unitid => $unitid }
  );

  use Time::Local;
  my @allmonths = ('Jan', 'Fev', 'Mar', 'Avr', 'Mai', 'Jun',
                   'Jul', 'Aou', 'Sep', 'Oct', 'Nov', 'Dec');
  my @needreval;
  foreach my $accred (@accreds) {
    my $datefin = $accred->{datefin};
    $datefin = 0 if ($datefin && $datefin =~ /^0000/);
    next unless $datefin;
    my  $origine = $accred->{origine};
    my $revalman = $accred->{revalman};
    next if ($revalman eq 'q');
    next if ($revalman ne 'y' && $origine =~ /^[pse]$/);
    my ($afin, $mfin, $jfin) = ($datefin =~ /^(\d*)-(\d*)-(\d*) /);
    my $timefin = timelocal (59, 59, 23, $jfin, $mfin - 1, $afin);
    push (@needreval, $accred) if ($timefin < $now + $durees->{$revtime});
  }
  return @needreval;
}

sub revalidate {
  my ($self, $accred, $resp, $add) = @_;
  importmodules ($self, 'Logs');
  my  $persid = $accred->{persid};
  my  $unitid = $accred->{unitid};
  my $datefin = $accred->{datefin};
  return 0 unless $datefin;

  unless ($add) { # On ne veut rien rajouter et ne plus voir cette accred
                  # dans l'ecran de revalidation.
    $self->{accreddb}->dbupdate (
      table => 'accreds',
        set => {
           creator => $resp,
          revalman => 'q',
        },
      where => { persid => $persid, unitid => $unitid }
    );
    return 1;
  }
  $add = 13 if ($add > 13);
  my @monthslen = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
  my ($afin, $mfin, $jfin) = ($datefin =~ /^(\d*)-(\d*)-(\d*) /);
  $mfin--; $mfin += $add;
  if ($mfin >= 12) { $mfin -= 12; $afin++; }
  if ($mfin >= 12) { $mfin -= 12; $afin++; }
  $jfin = $monthslen [$mfin] if ($jfin > $monthslen [$mfin]);
  my $timefin = timelocal (0, 0, 12, $jfin, $mfin, $afin);
  return 0 if ($timefin > time + 34214400);
  my $newdatefin = sprintf ("%d-%02d-%02d 00:00:00", $afin, $mfin + 1, $jfin);

  $self->{accreddb}->dbupdate (
    table => 'accreds',
      set => {
         datefin => $newdatefin,
         creator => $resp,
        revalman => 'y',
      },
    where => { persid => $persid, unitid => $unitid }
  );
  $self->{logs}->log ($resp, "revalidate", $persid, $unitid);
  return 1;
}

#
# Accrediteurs
#

sub getAccreditorRight {
  my $self = shift;
  return $self->{accreddb}->getObject (
    type => 'rights',
    name => 'accreditation',
  );
}

sub isAccred {
  my ($self, $persid, $unitid) = @_;
  importmodules ($self, 'Rights');
  my $accredright = $self->getAccreditorRight ();
  my $rightid = $accredright->{id};
  my $rup = $self->{rights}->getRights (
    rightid => $rightid,
     unitid => $unitid,
  );
  return ($rup->{$rightid}->{$unitid}->{$persid} =~ /^y/);
}

sub purgePerson { # lors de la disparition de la dernière accreditation d'une persons.
  my ($self, $persid, $author) = @_;
  return unless $persid;
  importmodules ($self, 'Roles', 'Rights');
  #
  # Purge rights.
  #
  my $rup = $self->{rights}->getExplicitRights (
    persid => $persid,
  );
  if ($rup) {
    foreach my $rightid (keys %$rup) {
      foreach my $unitid (keys %{$rup->{$rightid}}) {
        $self->{rights}->setPersonRight ($persid, $unitid, $rightid, 'd', $author);
      }
    }
  }
  #$self->{accreddb}->dbdelete (
  #  table => 'rights_persons',
  #  where => {
  #    persid => $persid,
  #  },
  #);
  #
  # Purge roles.
  #
  my $rup = $self->{roles}->getExplicitRoles (
    persid => $persid,
  );
  if ($rup) {
    foreach my $roleid (keys %$rup) {
      foreach my $unitid (keys %{$rup->{$roleid}}) {
        $self->{roles}->setPersonRole ($roleid, $persid, $unitid, 'd', $author);
      }  
    }
  }
  #$self->{accreddb}->dbdelete (
  #  table => 'roles_persons',
  #  where => {
  #    persid => $persid,
  #  },
  #);
  #
  # Purge all deputations where $persid is holder / deputy.
  #
  my $deputations = $self->{roles}->getHolders ($persid);
  if ($deputations) {
    foreach my $deputation (@{$deputations->{$persid}}) {
      $self->{roles}->remDeputation ($deputation->{id}, $author);
    }
  }
  my $deputations = $self->{roles}->getDeputations ($persid);
  if ($deputations) {
    foreach my $deputation (@{$deputations->{$persid}}) {
      $self->{roles}->remDeputation ($deputation->{id}, $author);
    }
  }
  #
  # Purge properties.
  #
  $self->{accreddb}->dbdelete (
    table => 'accreds_properties',
    where => { persid => $persid },
  );
}

sub purgePersonUnit {
  my ($self, $unitid, $persid, $author) = @_;
  return unless ($persid && $unitid);
  importmodules ($self, 'Roles', 'Rights');
  #
  # Purge rights.
  #
  my $rup = $self->{rights}->getExplicitRights (
    unitid => $unitid,
    persid => $persid,
  );
  if ($rup) {
    foreach my $rightid (keys %$rup) {
      $self->{rights}->setPersonRight ($persid, $unitid, $rightid, 'd', $author);
    }
  }
  #$self->{accreddb}->dbdelete (
  #  table => 'rights_persons',
  #  where => {
  #    persid => $persid,
  #    unitid => $unitid,
  #  },
  #);
  #
  # Purge roles.
  #
  my $rup = $self->{roles}->getExplicitRoles (
    unitid => $unitid,
    persid => $persid,
  );
  if ($rup) {
    foreach my $roleid (keys %$rup) {
      $self->{roles}->setPersonRole ($roleid, $persid, $unitid, 'd', $author);
    }
  }
  #$self->{accreddb}->dbdelete (
  #  table => 'roles_persons',
  #  where => {
  #    persid => $persid,
  #    unitid => $unitid,
  #  },
  #);
  #
  # Purge all deputations in unitid where $persid is holder / deputy.
  #
  my $deputations = $self->{roles}->getHolders ($persid, undef, $unitid);
  if ($deputations) {
    foreach my $deputation (@{$deputations->{$persid}}) {
      $self->{roles}->remDeputation ($deputation->{id}, $author);
    }
  }
  my $deputations = $self->{roles}->getDeputations ($persid, undef, $unitid);
  if ($deputations) {
    foreach my $deputation (@{$deputations->{$persid}}) {
      $self->{roles}->remDeputation ($deputation->{id}, $author);
    }
  }
  #
  # Purge properties.
  #
  $self->{accreddb}->dbdelete (
    table => 'accreds_properties',
    where => {
      persid => $persid,
      unitid => $unitid,
    },
  );
  return 1;
}

sub sendrightadminssummary {
  my ($self, $accred, $admins) = @_;
  importmodules ($self, 'Persons', 'Units');
  return if $self->{fake};
  return unless ($self->{req}->{execmode} eq 'prod');
  
  my $summail = 'claude.lecommandeur@epfl.ch';
  my  $unitid = $accred->{unitid};
  my    $unit = $self->{units}->getUnit ($accred->{unitid});
  my   $uname = $unit->{name};
  my    $pers = $self->{persons}->getPerson ($accred->{persid});
  my   $pname = $pers->{name};

  my @allaccreds = $self->getAccredsOfPerson ($accred->{persid});
  my @otherunits;
  foreach my $acc (@allaccreds) {
    next if ($acc->{unitid} == $accred->{unitid});
    my $unitid = $acc->{unitid};
    my   $unit = $self->{units}->getUnit ($unitid);
    next unless $unit;
    push (@otherunits, $unit->{name});
  }
  my $theunits;
  my $lastunit = pop @otherunits;
  if (@otherunits) {
    my $firstsunits = join (', ', @otherunits);
    $theunits = 'les unités ' . $firstsunits . ' et ' . $lastunit;
  } else {
    $theunits = "l'unité $lastunit";
  }
  unless ($summail =~ /^[\w\._\-]+@[\w\._\-]+\.[\w]{2,}$/) {
    warn "Accreds:sendmailtorightadmins: Bas email address : $summail\n";
    return;
  }
  open  (SUM, qq{| /usr/lib/sendmail -F"Accreditation" -f"Accreditation" $summail}) || do {
    warn "Accreds:sendrightadminssummary: Unable to send summary : $!\n";
    return;
  };
  #open (SUM, ">&STDOUT");
  binmode (SUM, ':utf8');

  print SUM
    "From: noreply\@epfl.ch\n".
    "Subject: Accreditation de $pname dans $uname supprimée.\n",
    "MIME-Version: 1.0\n",
    "Content-Type: text/plain; charset=utf-8\n",
    "\n",
    "\n";

  foreach my $persid (keys %$admins) {
    my $admin = $self->{persons}->getPerson ($persid);
    print SUM
      "To: $admin->{email}\n",
      "Reply-to: trash\@epfl.ch\n",
      "Subject: Accréditation de $pname dans $uname de supprimée.\n",
      "MIME-Version: 1.0\n",
      "Content-Type: text/plain; charset=utf-8\n",
      "\n",
      "  Bonjour,\n",
      "\n",
      "  L'accréditation de $pname dans l'unité $uname vient d'être ",
      "supprimée.\n",
      "\n",
      "  Or, cette personne possède les droits et rôles suivants dans une ou ",
      "plusieurs unités dont vous êtes responsables :\n",
      "\n",
      ;
    
    my $done;
    foreach my $record (@{$admins->{$persid}}) {
      my  $type = $record->{type};
      my $uname = $record->{unitinfo}->{name};
      my  $name = $record->{info}->{name};
      next if $done->{"$uname:$type:$name"};
      printf SUM ("%15s : %s %-10s\n", $uname, $type, $name);
      $done->{"$uname:$type:$name"} = 1;
    }

    print SUM
      "\n",
      "  Si vous pensez que ces droits ou rôles doivent être conservés, vous n'avez ",
      "aucune action à effectuer. Dans le cas contraire, nous vous conseillons de ",
      "les supprimer.\n",
      "\n",
      "  Notez, malgré tout que cette personne est toujours accréditée dans $theunits ",
      "\n",
      "\n",
      "    Merci.\n",
      "\n",
      "      Le fidèle système d'accréditation.\n",
      "\n",
      ;
  }
  close (SUM);
}

sub sendmailtorightadmins {
  my ($self, $accred, $admins) = @_;
  importmodules ($self, 'Persons', 'Units');
  return if $self->{fake};
  return unless ($self->{req}->{execmode} eq 'prod');

  my $unitid = $accred->{unitid};
  my   $unit = $self->{units}->getUnit     ($unitid);
  my   $pers = $self->{persons}->getPerson ($accred->{persid});
  my  $pname = $pers->{name};
  my  $uname = $unit->{name};

  my  @allaccreds = $self->getAccredsOfPerson ($accred->{persid});
  my @otherunits;
  foreach my $acc (@allaccreds) {
    next if ($acc->{unitid} == $accred->{unitid});
    my $unitid = $acc->{unitid};
    my   $unit = $self->{units}->getUnit ($unitid);
    next unless $unit;
    push (@otherunits, $unit->{name});
  }
  my $theunits;
  my $lastunit = pop @otherunits;
  if (@otherunits) {
    my $firstsunits = join (', ', @otherunits);
    $theunits = 'les unités ' . $firstsunits . ' et ' . $lastunit;
  } else {
    $theunits = "l'unité $lastunit";
  }

  foreach my $persid (keys %$admins) {
    my $adminpinfo = $self->{persons}->getPerson ($persid);
    my $adminemail = $adminpinfo->{email};
    unless ($adminemail) {
      warn "Accreds:sendmailtorightadmins: no email for admin $adminpinfo->{persid}\n";
      next;
    }
    unless ($adminemail =~ /^[\w\._\-]+@[\w\._\-]+\.[\w]{2,}$/) {
      warn "Accreds:sendmailtorightadmins: Bas email address : $adminemail\n";
      next;
    }
    open  (ADMIN, qq{| /usr/lib/sendmail -F"Accreditation" -f"Accreditation" $adminemail}) || do {
      warn "Accreds:sendmailtorightadmins: Unable to send email to $adminemail\n";
      next;
    };
    #open (ADMIN, ">&STDOUT");
    binmode (ADMIN, ':utf8');
    
    print ADMIN
      "To: $adminemail\n",
      "From: noreply\@epfl.ch\n".
      "Subject: Accreditation de $pname dans $uname supprimée.\n",
      "MIME-Version: 1.0\n",
      "Content-Type: text/plain; charset=utf-8\n",
      "\n",
      "  Bonjour,\n",
      "\n",
      "  L'accréditation de $pname dans l'unité $uname vient d'être ",
      "supprimée.\n",
      "\n",
      "   Or, cette personne possède les droits suivants dans une ou ",
      "plusieurs unités dont vous êtes responsables :\n",
      "\n",
    ;

    my $done;
    foreach my $record (@{$admins->{$persid}}) {
      my  $type = $record->{type};
      my $uname = $record->{unitinfo}->{name};
      my  $name = $record->{info}->{name};
      next if $done->{"$uname:$type:$name"};
      printf ADMIN ("%15s : %s %-10s\n", $uname, $type, $name);
      $done->{"$uname:$type:$name"} = 1;
    }

    print ADMIN
      "\n",
      "  Si vous pensez que ces droits ou rôles doivent être conservés, vous n'avez ",
      "aucune action à effectuer. Dans le cas contraire, nous vous conseillons de ",
      "les supprimer.\n",
      "\n",
      "  Notez, malgré tout que cette personne est toujours accréditée dans $theunits ",
      "\n",
      "\n",
      "    Merci.\n",
      "\n",
      "      Le fidèle système d'accréditation.\n",
      "\n";
    close (ADMIN);
  }
}

sub selectdate {
  my ($self, $current, $which, $attrs) = @_;
  my @monthsf = ("Janvier", "Février", "Mars", "Avril", "Mai", "Juin", "Juillet",
                 "Août", "Septembre", "Octobre", "Novembre", "Décembre");
  my ($year, $month, $day);
  if ($attrs->{noindet} && (!$current || $current eq 'now')) {
    ($day, $month, $year) = (localtime ())[3..5];
    $month++; $year += 1900;
  } else {
    ($year, $month, $day) = ($current =~ /^(\d*)-(\d*)-(\d*).*$/);
  }
  my $jname = 'j' . $which;
  my $mname = 'm' . $which;
  my $aname = 'a' . $which;

  my $ret = qq{<select name="$jname" id="$jname">\n};
  my $selected = $day ? "" : "selected";
  $ret .= qq{  <option value="0" $selected>Indéterminé\n} unless $attrs->{noindet};
  for (my $d = 1; $d <= 31; $d++) {
    my $selected = ($d == $day) ? "selected" : "";
    $ret .= sprintf qq{  <option value="%02d" $selected>%02d\n}, $d, $d;
  }
  $ret .= qq{</select>\n};

  $ret .= qq{<select name="$mname" id="$mname">\n};
  $selected = $month ? "" : "selected";
  $ret .= qq{  <option value="0" $selected>Indéterminé\n} unless $attrs->{noindet};
  for (my $m = 1; $m <= 12; $m++) {
    my $selected = ($m == $month) ? "selected" : "";
    $ret .= sprintf qq{  <option value="%02d" $selected>%s\n}, $m, $monthsf[$m-1];
  }
  $ret .= qq{</select>\n};

  my $thisyear = (localtime ())[5] + 1900;
  $ret .= qq{<select name="$aname" id="$aname">\n};
  $selected = $year ? "" : "selected";
  $ret .=  qq{  <option value="0" $selected>Indéterminé\n} unless $attrs->{noindet};
  my $passe = defined $attrs->{passe} ? $attrs->{passe} : 1;
  my $futur = defined $attrs->{futur} ? $attrs->{futur} : 1;
  $passe = $thisyear - $year if ($year && $year < $thisyear - $passe);
  $futur = $year - $thisyear if ($year && $year > $thisyear + $futur);
  $futur++ if ($which eq 'fin');
  for (my $y = - $passe; $y <= $futur; $y++) {
    my $yy = $thisyear + $y;
    my $selected = ($yy == $year) ? "selected" : "";
    $ret .= sprintf qq{  <option value="%04d" $selected> %04d\n}, $yy, $yy;
  }
  $ret .=  qq{</select>\n};
  return $ret;
}

1;

