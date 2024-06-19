#!/usr/bin/perl
#
use strict;
use lib qw(/opt/dinfo/lib/perl);
use Net::LDAP;
use Net::LDAPS;
use Time::Local;
use Cadi::CadiDB;
use Cadi::Persons;
use Cadi::Groups;
use Cadi::Units;
use Cadi::Accounts;
use Cadi::Accreds;
use Cadi::Guests;
use Cadi::Services;

package Cadi::SCO;

my $domemberuid = 1; 
my $accredldapattrs = {
  fonction => [ 'title', 'description', ],
    statut => [ 'organizationalStatus', ],
    classe => [ 'userClass', ],
};

sub new { # Exported
  my $class = shift;
  my  %args = @_;
  my $self = {
       caller => undef,
           db => undef,
       errmsg => undef,
      errcode => undef,
     language => 'fr',
       server => undef,
         base => undef,
        debug => 0,
      verbose => 0,
        trace => 0,
     tracesql => 0,
  };
  foreach my $arg (keys %args) {
    $self->{$arg} = $args {$arg};
  }
  $self->{verbose} = 1 if $self->{fake};
  my %modargs = (
     caller => 'root',
       root => 1,
       utf8 => 1,
    verbose => $self->{verbose},
       fake => $self->{fake},
  );
  $self->{Persons}  = new Cadi::Persons  (%modargs);
  $self->{Groups}   = new Cadi::Groups   (%modargs);
  $self->{Units}    = new Cadi::Units    (%modargs);
  $self->{Accounts} = new Cadi::Accounts (%modargs);
  $self->{Accreds}  = new Cadi::Accreds  (%modargs);
  $self->{Guests}   = new Cadi::Guests   (%modargs);
  $self->{Services} = new Cadi::Services (%modargs);
  $self->{ldap}     = ldapbind ($self);
  unless ($self->{ldap}) {
    error ("Cadi::SCO: Unable to bind to $self->{server}:$self->{base}");
    return;
  }
  bless $self, $class;
}

sub setserver {
  my ($self, $scoserver) = @_;
  $self->{scoserver} = $scoserver;
}

#
#
#  Accreds
#
#

sub addAccred {
  my ($self, $sciper, $unite) = @_;
  msg ("addAccred ($sciper, $unite)") if $self->{trace};
  unless ($sciper && $unite) {
    error ("addAccred: Bad call : $sciper = $sciper, unite = $unite");
    return;
  }
  my $person = $self->{Persons}->getPerson ($sciper);
  unless ($person && $person->{name}) {
    error ("addAccred: Unknown sciper : $sciper : .$self->{Persons}->{errmsg}");
    return;
  }
  my $unit = $self->{Units}->getUnit ($unite);
  unless ($unit) {
    error ("addAccred: Unknown unit : $unite");
    return;
  }
  my $accred = $self->{Accreds}->getAccred ($sciper, $unite);
  unless ($accred && $accred->{datedeb}) {
    error ("addAccred: Accred not found : ($sciper, $unite)");
    return;
  }
  my $account = $self->{Accounts}->getAccount ($sciper);
  unless ($account) {
    error ("addAccred: No account for $sciper");
    return;
  }
  #
  # Check start date.
  #
  my $datedeb = $accred->{datedeb};
  unless ($datedeb =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/) {
    error ("addAccred: Bad start date for ($sciper, $unite) : $datedeb");
    return;
  }
  my ($y, $m, $d) = ($1, $2, $3);
  my $timedeb;
  eval {
    $timedeb = Time::Local::timelocal (0, 0, 0, $d, $m - 1, $y);
  } || do {
    error ("addAccred: Bad start date for : ($sciper, $unite) : $@");
  };
  return 1 if ($timedeb > time);
  #
  # Try to find the password.
  #
  my $gaspardb = new Cadi::CadiDB (dbname => 'gaspar');
  if ($gaspardb) {
    my $sql = qq{
      select pwdsha
        from clients
       where sciper = ?
    };
    my $sth = $gaspardb->prepare ($sql);
    if ($sth) {
      my $rv = $gaspardb->execute ($sth, $sciper);
      if ($rv) {
        my ($pwdsha) = $sth->fetchrow;
        $accred->{password} = $pwdsha if $pwdsha;
      }
    }
    $sth->finish;
  }
  #
  #
  #
  my      $statut = $accred->{statut};
  my      $classe = $accred->{classe};
  my    $fonction = $accred->{fonction};
  my      $upname = ucfirst lc $person->{upname};
  my $upfirstname = ucfirst lc $person->{upfirstname};
  my        $name = $person->{name};
  my   $firstname = $person->{firstname};
  my       $email = $person->{email};
          $statut = $statut;
          $classe = $classe;
        $fonction = $fonction;
  my    $unitacro = $unit->{sigle};
  my    $unitname = $unit->{label};
  my       $gecos = $account->{gecos},
     
  my $uid;
  if ($accred->{ordre} == 1) {
    $uid = [ $account->{user}, $account->{user} . '@' . lc $unitacro ];
  } else {
    $uid = $account->{user} . '@' . lc $unitacro;
  }

  my @cn = ("$firstname $name");
  push (@cn, "$upfirstname $upname")
    if (("\U$name" ne "\U$upname") || ("\U$firstname" ne "\U$upfirstname"));
  push (@cn, $name);
  push (@cn, $upname) if ("\U$name" ne "\U$upname");
  my @sn = ($name);
  push (@sn, $upname) if ("\U$name" ne "\U$upname");
  my @gn = ($firstname);
  push (@gn, $upfirstname) if ("\U$firstname"  ne "\U$upfirstname");

  my @attrs = (
    cn => \@cn,
    sn => \@sn,
    gn => \@gn,
  );
  my $password = $accred->{password} || '{CRYPT}*';
  push (@attrs, (
            uniqueIdentifier => $sciper,
                userPassword => $password,
                         uid => $account->{user},
                   uidnumber => $account->{uid},
                   gidnumber => $account->{gid},
                       gecos => $gecos,
               homedirectory => $account->{home},
                  loginshell => $account->{shell},
                 objectclass => [
                   'posixAccount',
                   'person',
                   'organizationalPerson',
                   'EPFLorganizationalPerson',
                   'inetOrgPerson',
                 ])
  );

  my  $userdn = "uid=$account->{user},ou=users,o=epfl,c=ch";
  my @parents = $self->{Units}->getHierarchy ($unite);
  my $result = $self->{ldap}->search (
      base => $userdn,
     scope => 'base',
    filter => '(objectclass=*)',
     attrs => ['memberOf', ]
  );
  my %moflist;
  if ($result->code) { # Not yet here
    msg ("AddAccred: adding accred ($sciper, $unite)") if $self->{verbose};
    unless ($self->{fake}) {
      my $status = $self->{ldap}->add ($userdn, attrs => [@attrs]);
      if ($status->code) {
        error ("addAccred: Unable to add $userdn : ", $status->error)
          unless ($status->error =~ /already exists/i);
        return;
      }
    }
    %moflist = ();
  } else {
    my @memberOf = $result->entries;
    if (!@memberOf) {
      error ("addAccred: Unable to get memberOf for ".
              "$userdn : ", $result->error);
      return;
    }
    my  $moflist = $memberOf [0];
    my  @moflist = $moflist->get_value ('memberOf');
    %moflist = map { $_, 1 } @moflist;
  }
  my @memberof;
  push (@memberof, 'S00000') unless $moflist {'S00000'};
  foreach my $parent (@parents) {
    my $id = sprintf ("U%05d", $parent->{id});
    last if $moflist {$id}; # Already memberof
    msg ("addAccred: add memberOf $id to $userdn") if $self->{verbose};
    push (@memberof, $id);
  }
  unless ($self->{fake}) {
    my $status = $self->{ldap}->modify ($userdn, add => { memberOf => \@memberof });
    if ($status->code) {
      error ("addAccred: Unable to add memberOf's to $userdn : ",
             $status->error) unless ($status->error =~ /already exists/i);
    }
  }
  #
  # Groups
  #
  my @groups = $self->{Groups}->listGroupsUserBelongsTo ($sciper);
  foreach my $group (@groups) {
    $self->updateMembers ($group->{name});
  }
  return 1;
}

sub deleteAccred {
  my ($self, $sciper, $unite) = @_;
  msg ("deleteAccred ($sciper, $unite)") if $self->{trace};
  unless ($sciper && $unite) {
    error ("deleteAccred: Bad call : $sciper = $sciper, unite = $unite");
    return;
  }
  my $account = $self->{Accounts}->getAccount  ($sciper);
  unless ($account) {
    error ("deleteAccred: No account for $sciper");
    return;
  }
  my  @units = $self->{Accreds}->getUnitsOfAccreds ($sciper);
  my $userdn = "uid=$account->{user},ou=users,o=epfl,c=ch";

  my $keep;
  foreach my $unit (@units) {
    next if ($unit eq $unite);
    my (@parents) = $self->{Units}->getHierarchy ($unit);
    foreach my $parent (@parents) {
      $keep->{$parent->{id}} = $parent;
    }
  }
  my $remove;
  my (@parents) = $self->{Units}->getHierarchy ($unite);
  foreach my $parent (@parents) {
    $remove->{$parent->{id}} = $parent unless $keep->{$parent->{id}};
  }

  foreach my $unitid (keys %$remove) {
    my $sigle = $remove->{$unitid}->{sigle};
    my    $id = sprintf ("U%05d", $unitid);
    $self->removeMember ({ id => $id, name =>  "$sigle-unit" }, $sciper);
  }
  return 1;
}

#
# Emails.
#

sub addEmailAddress {
  my ($self, $sciper, $email) = @_;
  $self->scosetemail ('add', $sciper, $email);
  return 1;
}

sub removeEmailAddress {
  my ($self, $sciper, $email) = @_;
  $self->scosetemail ('delete', $sciper, $email);
  return 1;
}

sub changeEmailAddress {
  my ($self, $sciper, $email) = @_;
  $self->scosetemail ('replace', $sciper, $email);
  return 1;
}

sub scosetemail {
  my ($self, $action, $sciper, $email) = @_;
  my $filter = "(& (uniqueIdentifier=$sciper) (objectclass=person))";
  my $status = $self->{ldap}->search (
      base => $self->{base},
     scope => 'sub',
    filter => $filter,
  );
  if ($status->code) {
    error ("setEmailAddress: Unable to find entry for $sciper : ", $status->error);
    return;
  }
  my @results = $status->entries;
  foreach my $result (@results) {
    my $userdn = $result->dn;
    msg ("setEmailAddress: setting email address to $userdn") if $self->{verbose};
    unless ($self->{fake}) {
      my $status = $self->{ldap}->modify ($userdn, $action => { mail => $email });
      if ($status->code) {
        error ("setEmailAddress: Unable to set email address for $userdn : ", $status->error)
          unless ($status->error =~ /already exists/i);
      }
    }
  }
  return 1;
}

#
#
# Groups.
#
#

sub addGroup {
  my ($self, $group) = @_;
  if (not ref $group) {
    my $gnameorid = $group;
    $group = $self->{Groups}->getGroup ($group);
    unless ($group) {
      error ("addGroup: unknown group : $gnameorid");
      return;
    }
  }
  my       $gname = $group->{name};
  my          $cn = lc $gname;
  my     $groupdn = "cn=$cn,ou=groups,o=epfl,c=ch";
  my     $groupid = $group->{id};
  my $description = $group->{description} || $group->{name};
  my          $cn = lc $gname;
  error ("addGroup: bad group : $groupid") unless ($groupid && $gname);
  my $cattrs = [
                  cn => $cn,
         displayName => $gname,
    uniqueIdentifier => $groupid,
      memberUniqueId => $group->{owner},
         description => $description,
           gidnumber => $group->{gid},
         objectclass => 'groupOfNames',
         objectclass => 'EPFLGroupOfPersons',
  ];
  my @members = @{$group->{members}};
  unless (@members) {
    error ("addGroup: No members in $gname");
    return 1;
  }
  my @scipers = map { $_->{id} } @members;
  my $accounts;
  foreach my $sciper (@scipers) {
    next unless ($sciper =~ /^\d\d\d\d\d\d$/);
    $accounts->{$sciper} = $self->{Accounts}->getAccount ($sciper);
  }
  my $ownerdn = $self->getUserDN ($group->{owner});
  unless ($ownerdn) {
    error ("addGroup: Unable to find owner dn for ($group->{name}, $group->{owner})");
    return;
  }
  my ($attrs, $dns);
  push (@$attrs, @$cattrs);
  push (@$attrs, owner => $ownerdn);
  foreach my $sciper (@scipers) {
    unless ($dns->{$sciper}) {
      my @sciperdns = $self->getUserDNs ($sciper);
      unless (@sciperdns) {
        error ("addGroup: Unable to find dn for sciper $sciper");
        next;
      }
      $dns->{$sciper} = \@sciperdns;
    }
    push (@$attrs, 'member',    $dns->{$sciper}->[0])
      if ($dns->{$sciper} && @{$dns->{$sciper}});
    push (@$attrs, 'memberUid', $accounts->{$sciper}->{user})
      if ($domemberuid && $accounts->{$sciper} && $accounts->{$sciper}->{user});
  }
  unless (keys %$dns) {
    error ("addGroup: Unable to find dn any member");
    return;
  }
  msg ("addGroup: add $groupdn on $self->{server}") if $self->{verbose};
  unless ($self->{fake}) {
    my $status = $self->{ldap}->add ($groupdn, attrs => $attrs);
    if ($status->code) {
      error ("addGroup: Unable to add $groupdn : ", $status->error)
        unless ($status->error =~ /already exists/i);
      return;
    }
  }
  foreach my $sciper (@scipers) {
    next unless $dns->{$sciper};
    my @sciperdns = @{$dns->{$sciper}};
    foreach my $sciperdn (@sciperdns) {
      msg ("addGroup: add memberOf $gname to $sciper") if $self->{verbose};
      unless ($self->{fake}) {
        my $status = $self->{ldap}->modify ($sciperdn, add => { memberOf => $groupid });
        if ($status->code) {
          error ("addGroup: Unable to add $sciper in $groupdn : ", $status->error)
            unless ($status->error =~ /already exists/i);
        }
      }
    }
  }
  return 1;
}

sub deleteGroup {
  my ($self, $groupid) = @_;
  error ("deleteGroup: bad call") unless ($groupid && ($groupid =~ /^S\d+$/));
  my $gname;
  my $ldgroup = $self->getGroupDN ($groupid);
  unless ($ldgroup) {
    error ("deleteGroup: Unable to find group $groupid");
    return;
  }
  my $groupdn = $ldgroup->{dn};
  $gname = $ldgroup->{name};
  msg ("Removing group $groupid") if $self->{verbose};
  unless ($self->{fake}) {
    my $status = $self->{ldap}->delete ($groupdn);
    if ($status->code && $self->{verbose}) {
      error ("deleteGroup: Unable to remove group $groupid : ", $status->error);
      return;
    }
  }
  my $status = $self->{ldap}->search (
      base => $self->{base},
     scope => 'sub',
    filter => "(& (memberOf=$groupid) (objectclass=person))"
  );
  if ($status->code) {
    error ("deleteGroup: Unable to find members of $groupid) : ", $status->error);
    next;
  }
  my @results = $status->entries;
  foreach my $result (@results) {
    my $userdn = $result->dn;
    msg ("Removing memberOf $groupid to $userdn") if $self->{verbose};
    unless ($self->{fake}) {
      my $status = $self->{ldap}->modify ($userdn, delete => { memberOf => $groupid });
      if ($status->code) {
        error ("deleteGroup: Unable to remove memberOf $groupid to $userdn : ", $status->error)
          unless ($status->error =~ /already exists/i);
      }
    }
  }
  return 1;
}

sub renameGroup {
  my ($self, $group) = @_;
  if (not ref $group) {
    my $gnameorid = $group;
    $group = $self->{Groups}->getGroup ($gnameorid);
    unless ($group) {
      error ("renameGroup: unknown group : $gnameorid");
      return;
    }
  }
  my   $gname = $group->{name};
  my      $cn = lc $gname;
  my $groupid = $group->{id};
  error ("renameGroup: bad group : $groupid") unless ($groupid && $gname);
  my $oldname;
  my $ldgroup = $self->getGroupDN ($groupid);
  unless ($ldgroup) {
    error ("renameGroup: Unable to find group $groupid");
    return;
  }
  my $olddn = $ldgroup->{dn};
  $oldname  = $ldgroup->{name};
  msg ("renameGroup: Renaming $oldname to $gname") if $self->{verbose};
  unless ($self->{fake}) {
    my  $status = $self->{ldap}->moddn ($olddn, newrdn => "cn=$cn", deleteoldrdn => 1);
    if ($status->code) {
      error ("renameGroup: Unable to rename $oldname to $gname : ", $status->error)
        unless ($status->error =~ /already exists/i);
      return;
    }
  }
  my $newdn = "cn=$cn,ou=groups,o=epfl,c=ch";
  warn"renameGroup: setting displayName for $gname :" if $self->{verbose};
  unless ($self->{fake}) {
    my $status = $self->{ldap}->modify ($newdn,
      replace => {
                 cn => $cn,
        displayName => $gname,
    });
    if ($status->code) {
      error ("renameGroup: Unable to set displayName for $gname :", $status->error)
        unless ($status->error =~ /already exists/i);
      return;
    }
  }
  return 1;
}

sub updateMembers {
  my  ($self, $group) = @_;
  if (not ref $group) {
    my $gnameorid = $group;
    $group = $self->{Groups}->getGroup ($gnameorid);
    unless ($group) {
      error ("updateMembers: unknown group : $gnameorid");
      return;
    }
  }
  my   $gname = $group->{name};
  my $groupid = $group->{id};
  error ("updateMembers: bad group : $groupid") unless ($groupid && $gname);
  my @members = $group->{persons} ? @{$group->{persons}} : ();
  unless (@members) {
    error ("updateMembers: No members in $gname");
    return 1;
  }
  my @scipers = map { $_->{id} } @members;
  my ($ismember, $memberuids, $maindns, $alldns, $uid2sciper, $dn2sciper);
  foreach my $sciper (@scipers) {
    $ismember->{$sciper} = 1;
    my $uid;
    if ($sciper =~ /^G\d\d\d\d\d/) { # Guest
      my $guest = $self->{Guests}->getGuest ($sciper);
      $uid = $guest->{email} if $guest;
    }
    elsif ($sciper =~ /^M\d\d\d\d\d$/) { # Service
      my $service = $self->{Services}->getService ($sciper);
      $uid = $service->{name} if $service;
    }
    elsif ($sciper =~ /^\d\d\d\d\d\d$/) {
      my $account = $self->{Accounts}->getAccount ($sciper);
      $uid = $account->{user} if $account;
    }
    $memberuids->{$sciper} = $uid;
    $uid2sciper->{$uid} = $sciper;

    my @memberdns = $self->getUserDNs ($sciper);
    if (@memberdns) {
      $maindns->{$sciper} = $memberdns [0];
      $alldns->{$sciper}  = \@memberdns;
      foreach my $dn (@memberdns) {
        $dn2sciper->{$dn} = $sciper;
      }
    }
  }

  my $ldgroup = $self->getGroupMembers ($groupid);
  unless ($ldgroup) {
    error ("updateMembers: Unable to find group $groupid");
    return;
  }
  my    $groupdn = $ldgroup->{dn};
  my  $ldmembers = $ldgroup->{member};
  my $ldgroupids = $ldgroup->{lduniqueids};
  my     $lduids = $ldgroup->{lduids};
  #
  # add
  #
  foreach my $sciper (@scipers) {
    my    $maindn = $maindns->{$sciper};
    my $memberuid = $memberuids->{$sciper};
    if ($maindn) {
      unless ($ldmembers->{$maindn}) {
        msg ("updateMembers: add member=$maindn to $gname")if $self->{verbose};
        unless ($self->{fake}) {
          my $status = $self->{ldap}->modify ($groupdn, add => { member => $maindn });
          if ($status->code) {
            error ("updateMembers: Unable to add  attribute member $maindn ",
                   "in $gname (dn = $groupdn) : ", $status->error)
              unless ($status->error =~ /already exists/i);
          }
        }
      }
    }
    unless ($ldgroupids->{$sciper}) {
      msg ("updateMembers: add memberUniqueId=$sciper to $gname") if $self->{verbose};
      unless ($self->{fake}) {
        my $status = $self->{ldap}->modify ($groupdn, add => { memberUniqueId => $sciper });
        if ($status->code) {
          error ("updateMembers: Unable to add attribute memberUniqueId $sciper ",
                 "in $gname (dn = $groupdn) :", $status->error)
            unless ($status->error =~ /already exists/i);
        }
      }
    }
    if ($domemberuid && !$lduids->{$memberuid}) {
      msg ("updateMembers: add memberUid=$memberuid to $gname") if $self->{verbose};
      unless ($self->{fake}) {
        my $status = $self->{ldap}->modify ($groupdn, add => { memberUid => $memberuid });
        if ($status->code) {
          error ("updateMembers: Unable to add attribute memberUid $memberuid",
                 "in $gname (dn = $groupdn) : ", $status->error)
            unless ($status->error =~ /already exists/i);
        }
      }
    }
  }
  #
  # delete
  #
  foreach my $dn (keys %$ldmembers) {
    my $sciper = $dn2sciper->{$dn};
    unless ($sciper) {
      msg ("updateMembers: delete member=$dn from $gname") if $self->{verbose};
      unless ($self->{fake}) {
        my $status = $self->{ldap}->modify ($groupdn, delete => { member => $dn });
        if ($status->code) {
          error ("updateMembers: Unable to delete attribute member $dn ",
                 "in $gname : ", $status->error)
            unless ($status->error =~ /already exists/i);
        }
      }
    }
  }
  foreach my $sciper (keys %$ldgroupids) {
    unless ($ismember->{$sciper}) {
      msg ("updateMembers: delete memberUniqueId=$sciper from $gname") if $self->{verbose};
      unless ($self->{fake}) {
        my $status = $self->{ldap}->modify ($groupdn, delete => { memberUniqueId => $sciper });
        if ($status->code) {
          error ("updateMembers: Unable to delete attribute memberUniqueId $sciper ",
                 "in $gname : ", $status->error)
            unless ($status->error =~ /already exists/i);
        }
      }
    }
  }
  if ($domemberuid) { 
    foreach my $uid (keys %$lduids) {
      my $sciper = $uid2sciper->{$uid};
      unless ($sciper) {
        msg ("updateMembers: delete memberUid=$uid from $gname") if $self->{verbose};
        unless ($self->{fake}) {
          my $status = $self->{ldap}->modify ($groupdn, delete => { memberUid => $uid });
          if ($status->code) {
            error ("updateMembers: Unable to delete attribute memberUid $uid ".
                   "in $gname : ", $status->error)
              unless ($status->error =~ /already exists/i);
          }
        }
      }
    }
  }
  #
  # memberOf
  #
  my $dns = $self->getMemberOfs ($groupid);
  foreach my $sciper (@scipers) {
    next unless $alldns->{$sciper};
    my @alldns = @{$alldns->{$sciper}};
    foreach my $dn (@alldns) {
      unless ($dns->{$sciper}->{$dn}) {
        msg ("updateMembers: add memberof=$groupid to $dn") if $self->{verbose};
        unless ($self->{fake}) {
          my $status = $self->{ldap}->modify ($dn, add => { memberOf => $groupid });
          if ($status->code) {
            error ("updateMembers: Unable to add memberOf=$groupid to $dn  : ",
                   $status->error)
              unless ($status->error =~ /already exists/i);
          }
        }
      }
    }
  }
  foreach my $sciper (keys %$dns) {
    next unless $dns->{$sciper};
    foreach my $dn (keys %{$dns->{$sciper}}) {
      unless ($dn2sciper->{$dn}) {
        msg ("updateMembers: delete memberof=$groupid from $dn") if $self->{verbose};
        unless ($self->{fake}) {
          my $status = $self->{ldap}->modify ($dn, delete => { memberOf => $groupid });
          if ($status->code) {
            error ("updateMembers: Unable to delete memberOf=$groupid from $dn : ",
                   $status->error)
              unless ($status->error =~ /already exists/i);
          }
        }
      }
    }
  }
  return 1;
}

sub addMember {
  my ($self, $group, $sciper) = @_;
  if (not ref $group) {
    my $gnameorid = $group;
    $group = $self->{Groups}->getGroup ($gnameorid);
    unless ($group) {
      error ("addMember: unknown group : $gnameorid");
      return;
    }
  }
  my   $gname = $group->{name};
  my $groupid = $group->{id};
  error ("addMember: bad group : $groupid") unless ($groupid && $gname);
  my $account = $self->{Accounts}->getAccount ($sciper);

  my $memberuid;
  if ($sciper =~ /^G/) { # Guest
    my $guest = $self->{Guests}->getGuest ($sciper);
    unless ($guest) {
      error ("addMember: Unknown guest : $sciper");
      return;
    }
    $memberuid = $guest->{email};
  }
  elsif ($sciper =~ /^M/) { # Service
    my $service = $self->{Services}->getService ($sciper);
    unless ($service) {
      error ("addMember: Unknown service : $sciper");
      return;
    }
    $memberuid = $service->{name};
  }
  elsif ($account && $account->{user}) {
    $memberuid = $account->{user};
  }
  my $ldgroup = $self->getGroupDN ($groupid);
  unless ($ldgroup) {
    error ("addMember: Unable to find group $groupid");
    return;
  }
  my $groupdn = $ldgroup->{dn};
  my   $gname = $ldgroup->{name};
  my @userdns = $self->getUserDNs ($sciper);
  unless (@userdns) {
    error ("addMember: Unable to get dn for sciper $sciper");
    return;
  }
  my $userdn = $userdns [0];
  my $add = { member => $userdn, memberUniqueId => $sciper, };
  $add->{memberUid} = $memberuid if ($domemberuid && $memberuid);
  msg ("addMember: add member $sciper to $gname") if $self->{verbose};
  unless ($self->{fake}) {
    foreach my $attr (keys %$add) {
      next unless $add->{$attr};
      msg ("addMember: adding  attribute $attr in $gname") if $self->{verbose};
      my $status = $self->{ldap}->modify ($groupdn, add => { $attr => $add->{$attr} });
      if ($status->code) {
        error ("addMember: Unable to add  attribute $attr in $gname : ",
               $status->error) unless ($status->error =~ /already exists/i);
      }
    }
  }
  foreach my $userdn (@userdns) {
    msg ("addMember: add memberof $gname to $sciper") if $self->{verbose};
    unless ($self->{fake}) {
      my $status = $self->{ldap}->modify ($userdn, add => { memberOf => $groupid });
      if ($status->code) {
        error ("addMember: Unable to add memberOf $groupid to $userdn : ",
               $status->error) unless ($status->error =~ /already exists/i);
      }
    }
  }
  return 1;
}

sub removeMember {
  my ($self, $group, $sciper) = @_;
  if (not ref $group) {
    my $gnameorid = $group;
    $group = $self->{Groups}->getGroup ($gnameorid);
    unless ($group) {
      error ("removeMember: unknown group : $gnameorid");
      return;
    }
  }
  my   $gname = $group->{name};
  my $groupid = $group->{id};
  my  $account = $self->{Accounts}->getAccount ($sciper);
  error ("removeMember: bad group : $groupid") unless ($groupid && $gname);

  my $memberuid;
  if ($sciper =~ /^G/) { # Guest
    my $guest = $self->{Guests}->getGuest ($sciper);
    unless ($guest) {
      error ("removeMember: unknown guest : $sciper");
      return;
    }
    $memberuid = $guest->{email};
  }
  elsif ($sciper =~ /^M/) { # Service
    my $service = $self->{Services}->getService ($sciper);
    unless ($service) {
      error ("removeMember: unknown service : $sciper");
      return;
    }
    $memberuid = $service->{name};
  }
  elsif ($account && $account->{user}) {
    $memberuid = $account->{user};
  }
  my $ldgroup = $self->getGroupDN ($groupid);
  unless ($ldgroup) {
    error ("RemoveMember: Unable to find group $groupid");
    return;
  }
  my $groupdn = $ldgroup->{dn};
  my   $gname = $ldgroup->{name};
  my @userdns = $self->getUserDNs ($sciper);
  unless (@userdns) {
    error ("removeMember: Unable to get dn for sciper $sciper");
    return;
  }
  my $userdn = $userdns [0];
  my $delete = { member => $userdn, memberUniqueId => $sciper, };
  $delete->{memberUid} = $memberuid if ($domemberuid && $memberuid);
  msg ("removeMember: remove memberdn of $sciper from $gname") if $self->{verbose};
  unless ($self->{fake}) {
    foreach my $attr (keys %$delete) {
      next unless $delete->{$attr};
      msg ("removeMember: removing attribute $attr from $gname") if $self->{verbose};
      my $status = $self->{ldap}->modify ($groupdn, delete => { $attr => $delete->{$attr} });
      if ($status->code) {
        error ("removeMember: Unable to remove attribute $attr from $gname : ",
               $status->error) unless ($status->error =~ /already exists/i);
      }
    }
  }
  foreach my $userdn (@userdns) {
    msg ("removeMember: remove memberof $gname from $userdn") if $self->{verbose};
    unless ($self->{fake}) {
      my $status = $self->{ldap}->modify ($userdn, delete => { memberOf => $groupid });
      if ($status->code) {
        error ("removeMember: Unable to remove memberOf $groupid to $userdn : ",
               $status->error)
          unless ($status->error =~ /already exists/i);
      }
    }
  }
  return 1;
}

sub changeOwner {
  my ($self, $group) = @_;
  if (not ref $group) {
    my $gnameorid = $group;
    $group = $self->{Groups}->getGroup ($gnameorid);
    unless ($group) {
      error ("changeOwner: unknown group : $gnameorid");
      return;
    }
  }
  my    $gname = $group->{name};
  my    $owner = $group->{owner};
  my  $groupid = $group->{id};
  error ("changeOwner: bad group : $groupid") unless ($groupid && $gname);
  my $ldgroup = $self->getGroupDN ($groupid);
  unless ($ldgroup) {
    error ("ChangeOwner: Unable to find group $groupid");
    return;
  }
  my $groupdn = $ldgroup->{dn};
  my  $ldname = $ldgroup->{name};
  my $ownerdn = $self->getUserDN ($owner);
  unless ($ownerdn) {
    error ("ChangeOwner: Unable to find owner for ($group->{name}, $owner)");
    return;
  }
  msg ("changeOwner: change owner of $gname to $owner") if $self->{verbose};
  unless ($self->{fake}) {
    my $status = $self->{ldap}->modify ($groupdn, replace => { owner => $ownerdn });
    if ($status->code) {
      error ("ChangeOwner: Unable to modify owner of $gname : ", $status->error)
             unless ($status->error =~ /already exists/i);
      return;
    }
  } 
  return 1;
}

#
# Guests
#

sub addGuest {
  my ($self, $guest) = @_;
  if (not ref $guest) {
    my $gnameorid = $guest;
    $guest = $self->{Guests}->getGuest ($gnameorid);
    unless ($guest) {
      error ("addGuest: unknown guest : $gnameorid");
      return;
    }
  }
  error ("addGuest: bad guest : password is missing"),
    return unless $guest->{password};
  error ("addGuest: bad guest : email is missing"),
    return unless $guest->{email};
  error ("addGuest: bad guest : id is missing"),
    return unless $guest->{id};
  error ("addGuest: bad guest : firstname is missing"),
    return unless $guest->{firstname};
  error ("addGuest: bad guest : name is missing"),
    return unless $guest->{name};
  error ("addGuest: bad guest : org is missing"),
    return unless $guest->{org};
  
  my     $email = $guest->{email};
  my       $pwd = crypt ($guest->{password}, genkey ());
  my        $id = $guest->{id};
  my $uidnumber = 500000 + $guest->{id};
  my $gidnumber = 500000;
  my      $user = $guest->{email};
  my    $sciper = $guest->{sciper} || sprintf ("S%05d", $id);
  my        $dn = "uid=$guest->{email},ou=guests,o=epfl,c=ch";
  my      $name = ucfirst latin1toutf8 ($guest->{name});
  my $firstname = ucfirst latin1toutf8 ($guest->{firstname});
  my       $org = latin1toutf8 ($guest->{org});
  $user =~ tr/A-Z/a-z/;

  my $attrs = [
                        cn => "$firstname $name",
                        sn => $name,
                        gn => $firstname,
                         o => $org,
                        ou => [ 'epfl-guests', 'EPFL Guest' ],
      organizationalStatus => "Guest",
                 userClass => "Guest",
          uniqueIdentifier => $guest->{sciper},
                      mail => $guest->{email},
                       uid => $user,
                 uidnumber => -1,
                 gidnumber => -1,
                     gecos => "Guest $user",
             homedirectory => "/guests/$user",
                loginshell => "/bin/false",
              userPassword => "{CRYPT}$pwd",
               objectclass => ['person',
                 'organizationalPerson',
                 'EPFLorganizationalPerson',
                 'inetOrgPerson',
                 'posixAccount',
          ],
  ];
  msg ("addGuest: add guest $email") if $self->{verbose};
  unless ($self->{fake}) {
    my $status = $self->{ldap}->add ($dn, attrs => $attrs);
    if ($status->code) {
      error ("addGuest: Unable to add $dn : ", $status->error)
        unless ($status->error =~ /already exists/i);
      return;
    }
  }
  $self->addMember ({ id => 'S00000', name =>  'users' }, $sciper);
  $self->addMember ({ id => 'S00001', name => 'guests' }, $sciper);
  return 1;
}

sub deleteGuest {
  my ($self, $guest) = @_;

  if (not ref $guest) {
    my $gnameorid = $guest;
    $guest = $self->{Guests}->getGuest ($gnameorid, 2);
    unless ($guest) {
      error ("deleteGuest: unknown guest : $gnameorid");
      return;
    }
  }
  unless ($guest->{email}) {
    error ("deleteGuest: bad guest : email is missing");
    return;
  }
  unless ($guest->{sciper}) {
    error ("deleteGuest: bad guest : sciper is missing");
    return;
  }
  my  $email = $guest->{email};
  my $sciper = $guest->{sciper};
  $self->removeMember ({ id => 'S00000', name =>  'users' }, $sciper);
  $self->removeMember ({ id => 'S00001', name => 'guests' }, $sciper);

  my $scodn = "uid=$email,ou=guests,$self->{base}";
  msg ("deleteGuest: remove guest $guest->{email}") if $self->{verbose};
  unless ($self->{fake}) {
    my $status = $self->{ldap}->delete ($scodn);
    if ($status->code && $self->{verbose}) {
      error ("deleteGuest: Unable to remove $scodn : ", $status->error)
        unless ($status->error =~ /already exists/i);
      return;
    }
  }
  return 1;
}

sub updateGuest {
  my ($self, $guest) = @_;
  my $email = ref $guest ? $guest->{email} : $guest;
  $guest = $self->{Guests}->getGuest ($email);
  unless ($guest) {
    error ("updateGuest: unknown guest : $email");
    return;
  }
  my    $sciper = $guest->{sciper};
  my      $name = ucfirst latin1toutf8 ($guest->{name});
  my $firstname = ucfirst latin1toutf8 ($guest->{firstname});
  my       $org = latin1toutf8 ($guest->{organization});
  my     $email = $guest->{email};
  my       $pwd = crypt ($guest->{password}, genkey ());
  my     $scodn = "uid=$email,ou=guests,o=epfl,c=ch";
  my   $changes = [
                    replace => [           cn => $sciper            ],
                        add => [           cn => "$firstname $name" ],
                    replace => [           sn => $name              ],
                    replace => [           gn => $firstname         ],
                    replace => [          uid => $email             ],
                    replace => [         mail => $email             ],
                    replace => [            o => $org               ],
                    replace => [ userPassword => "{CRYPT}$pwd"      ],
                   ];

  msg ("updateGuest: update guest $email") if $self->{verbose};
  unless ($self->{fake}) {
    my $status = $self->{ldap}->modify ($scodn, changes => $changes);
    if ($status->code) {
      error ("updateGuest: Unable to modify $scodn : ", $status->error)
        unless ($status->error =~ /already exists/i);
      return;
    }
  }
  return 1;
}
#
# Services
#

sub addService {
  my ($self, $nameorid) = @_;
  my $service = $self->{Services}->getService ($nameorid);
  unless ($service) {
    error ("addService: unknown service : $nameorid");
    return;
  }
  return 1 unless $service->{ldap};
  my $pwdsha = makesha ($service->{password});
  my   $name = latin1toutf8 (lc $service->{name});
  my     $dn = "cn=$name,ou=services,o=epfl,c=ch";
  my $uniqid = sprintf ('M%05d', $service->{id});
  my  $attrs = [
                ou => 'services',
                cn => $name,
               uid => $name,
  uniqueIdentifier => $uniqid,
       description => $name,
         uidNumber => $service->{uid} || -1,
         gidNumber => $service->{gid} || -1,
     homeDirectory => "/home/$name",
      userpassword => $pwdsha,
       objectclass => [ 'organizationalRole',
                        'posixAccount',
                        'shadowAccount',
                        'EPFLObject'],
  ];
  msg ("addService: add service $name") if $self->{verbose};
  unless ($self->{fake}) {
    my $ldn = $self->getServiceDN ($name);
    if ($ldn) {
      error ("addService: service $name already LDAP");
      return;
    }
    my $status = $self->{ldap}->add ($dn, attrs => $attrs);
    if ($status->code) {
      error ("addService: unable to add $dn : ", $status->error)
        unless ($status->error =~ /already exists/);
      return;
    }
  }
  return 1;
}

sub updateService {
  my ($self, $nameorid) = @_;
  my $service = $self->{Services}->getService ($nameorid);
  unless ($service) {
    error ("updateService: unknown service : $nameorid");
    return;
  }
  my   $name = $service->{name};
  my    $uid = $service->{uid} || -1;
  my    $gid = $service->{gid} || -1;
  my $uniqid = sprintf ('M%05d', $service->{id});
  my     $dn = "cn=$name,ou=services,o=epfl,c=ch";
  my $pwdsha = makesha ($service->{password});
  my   $changes = [
    replace => [           cn => $name   ],
    replace => [          uid => $name   ],
    replace => [  description => $name   ],
    replace => [    uidNumber => $uid    ],
    replace => [ userPassword => $pwdsha ],
  ];

  msg ("updateService: update service $name") if $self->{verbose};
  unless ($self->{fake}) {
    my $ldn = $self->getServiceDN ($name);
    if ($ldn && !$service->{ldap}) {
      my $status = $self->{ldap}->delete ($ldn);
      if ($status->code && $self->{verbose}) {
        error ("updateService: unable to remove $dn : ", $status->error);
        return;
      }
    }
    elsif ($service->{ldap} && !$ldn) {
      my $pwdsha = makesha ($service->{password});
      my  $attrs = [
                      ou => 'services',
                      cn => $name,
                     uid => $name,
        uniqueIdentifier => $uniqid,
             description => $name,
               uidNumber => $uid,
               gidNumber => $gid,
           homeDirectory => "/home/$name",
            userpassword => $pwdsha,
             objectclass => [ 'organizationalRole',
                              'posixAccount',
                              'shadowAccount',
                              'EPFLObject' ],
      ];
      my $status = $self->{ldap}->add ($dn, attrs => $attrs);
      if ($status->code) {
        error ("updateService: unable to add $dn : ", $status->error)
          unless ($status->error =~ /already exists/);
        return;
      }
    } else {
      my $status = $self->{ldap}->modify ($dn, changes => $changes);
      if ($status->code) {
        error ("updateService: unable to modify $dn : ", $status->error)
          unless ($status->error =~ /already exists/);
        return;
      }
    }
  }
  return 1;
}

sub removeService {
  my ($self, $srvname) = @_;
  msg ("removeService: remove service $srvname") if $self->{verbose};
  unless ($self->{fake}) {
    my $dn = $self->getServiceDN ($srvname);
    unless ($dn) {
      error ("removeService: unable to get $dn for service $srvname");
      return;
    }
    my $status = $self->{ldap}->delete ($dn);
    if ($status->code && $self->{verbose}) {
      error ("removeService: unable to remove $dn for service $srvname : ",
              $status->error);
      return;
    }
  }
  return 1;
}

sub ldapbind {
  my $self = shift;
  my $host = $self->{server};
  my $port = 636;
  if ($host =~ /^(.*):(.*)$/) {
    $host = $1;
    $port = $2;
  }
  my $upddn = 'cn=manager,o=epfl,c=ch';
  my $updpw = 'gasparf0rever';

  my $ldap = new Net::LDAPS ($host, port => $port, async => 1);
  unless ($ldap) {
    error ("Unable to contact LDAP server $host:$port");
    return;
  }
  my $status = $ldap->bind (dn => $upddn, password => $updpw, version => 3);
  if ($status->code) {
    error ("Unable to bind to LDAP server $host:$port : ", $status->error);
    return;
  }
  $self->{ldap}  = $ldap;
  return $ldap;
}

sub getGroupDN {
  my ($self, $groupid) = @_;
  my $status = $self->{ldap}->search (
      base => "ou=groups,$self->{base}",
     scope => 'sub',
    filter => "(uniqueIdentifier=$groupid)",
     attrs => [ 'uniqueIdentifier' ],
  );
  return if $status->code;
  my @results = $status->entries;
  return unless @results;
  my $dn =  $results [0]->dn;
  return unless ($dn =~ /^cn=([^,]*)/);
  my $name = $1;
  return { dn => $dn, name => $name, };
}

sub getUserDN {
  my ($self, $sciper) = @_;
  my $status = $self->{ldap}->search (
      base => 'o=epfl,c=ch',
     scope => 'sub',
    filter => "(& (uniqueIdentifier=$sciper) (objectclass=person))",
     attrs => [ 'uniqueIdentifier' ],
  );
  return if $status->code;
  my @results = $status->entries;
  return unless @results;
  return $results [0]->dn;
}

sub getUserDNs {
  my ($self, $sciper) = @_;
  my $status = $self->{ldap}->search (
      base => $self->{base},
     scope => 'sub',
    filter => "(& (uniqueIdentifier=$sciper) (objectclass=person))",
     attrs => [ 'uniqueIdentifier' ],
  );
  return if $status->code;
  my @results = $status->entries;
  return unless @results;
  return map { $_->dn } @results;
}

sub getServiceDN {
my ($self, $name) = @_;
  my $status = $self->{ldap}->search (
      base => "ou=services,$self->{base}",
     scope => 'sub',
    filter => "(& (cn=$name) (objectclass=organizationalRole))",
     attrs => ['cn'],
  );
  if ($status->code) {
    error ("Unable to search service $name : ", $status->error);
    return;
  }
  my @results = $status->entries;
  return unless @results;
  return $results [0]->dn;
}

sub getMemberOfs {
  my ($self, $groupid) = @_;
  my $status = $self->{ldap}->search (
      base => $self->{base},
     scope => 'sub',
    filter => "(& (memberof=$groupid) (objectclass=person))",
     attrs => [ 'uniqueIdentifier' ],
  );
  return if $status->code;
  my @results = $status->entries;
  return unless @results;
  my $dns;
  foreach my $result (@results) {
    my $sciper = $result->get_value ('uniqueidentifier');
    $dns->{$sciper}->{$result->dn} = 1;
  }
  return $dns;
}

sub getGroupMembers {
  my ($self, $groupid) = @_;
  my $status = $self->{ldap}->search (
      base => $self->{base},
     scope => 'sub',
    filter => "(&(uniqueIdentifier=$groupid) (objectclass=groupOfNames))",
     attrs => [ 'member', 'memberUid', 'memberUniqueId' ],
  );
  if ($status->code) {
    error ("Unable to search memberof $groupid : ", $status->error);
    return;
  }
  my @results = $status->entries;
  return unless @results;
  my $ldgroup;
  my $result = $results [0];
  $ldgroup->{dn} = $result->dn;

  my @members = $result->get_value ('member');
  map { $ldgroup->{member}->{$_} = 1 } @members;

  my @lduniqueids = $result->get_value ('memberUniqueId');
  map { $ldgroup->{lduniqueids}->{$_} = 1 } @lduniqueids;

  my @lduids = $result->get_value ('memberUid');
  map { $ldgroup->{lduids}->{$_} = 1 } @lduids;

  return $ldgroup;
}
  
sub getUnitDn {
  my ($self, $unite) = @_;
  my $status = $self->{ldap}->search (
      base => $self->{base},
     scope => 'sub',
    filter => "(& (uniqueIdentifier=$unite) (objectclass=organizationalUnit))",
     attrs => ['description'],
  );
  return if $status->code;
  my @results = $status->entries;
  return unless @results;
  return $results [0]->dn;
}

sub makesha {
  my $passwd = shift;
  my $salt = '1q2w3e4r5t6y';
  my  $ctx = new Digest::SHA1 ();
  $ctx->add ($passwd);
  $ctx->add ($salt);
  my $pwdsha =  '{SSHA}' . MIME::Base64::encode_base64 ($ctx->digest . $salt , '');
  return $pwdsha;
}

sub genkey {
  srand (time ^ ($$ + ($$ << 15)));
  my $key = "";
  for (my $i = 0; $i < 16; $i++) {
    my $car .= int rand (35);
    $key .= ('a'..'z', '0'..'9')[$car];
  }
  return $key;
}

sub latin1toutf8 {
  my $string = shift;
  $string =~ s/([\x80-\xFF])/chr(0xC0|ord($1)>>6).chr(0x80|ord($1)&0x3F)/eg;
  return $string;
}

sub error {
  my $msg = join (' ', @_);
  my $now = scalar localtime;
  warn "[$now] [SCO] $msg.";
}

sub msg {
  my $msg = join (' ', @_);
  my $now = scalar localtime;
  warn "[$now] [SCO] $msg.";
}

1;
