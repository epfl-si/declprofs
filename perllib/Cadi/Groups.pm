#!/usr/bin/perl
#
use strict;
use lib qw(/opt/dinfo/lib/perl);
#use Time::HiRes qw( time );
use Encode;
use Cadi::CadiDB;
use Cadi::Lists;
use Cadi::Notifier;

use utf8;

package Cadi::Groups;

use bytes;

#
# \d : Personnes.
#  G : Guests.
#  S : Groupes.
#  U : Unités.
#  L : Autolistes.
#  M : Services.
#  Q : Query.
#  Z : Switch AAI.
#

my        $groupstable = 'groupes.newgroups';
my       $memberstable = 'groupes.newmembers';
my        $adminstable = 'groupes.newadmins';
my      $excludedtable = 'groupes.excluded';
my       $queriestable = 'groupes.newqueries';

my $doautolists = 0;
my $messages;
our @seen;

sub new { # Exported
  my $class = shift;
  my $args = (@_ == 1) ? shift : { @_ } ;
  my  $self = {
      caller => undef,
        root => undef,
    groupsdb => undef,
      logger => undef,
    readonly => 0,
      notify => 1,
        utf8 => 0,
      errmsg => undef,
     errcode => undef,
    language => 'fr',
        fake => 0,
       debug => 0,
     verbose => 0,
       trace => 0,
    tracesql => 0,
  };
  foreach my $arg (keys %$args) {
    $self->{$arg} = $args->{$arg};
  }
  warn "new Cadi::Groups ()\n" if $self->{verbose};

  initmessages ($self);
  $self->{groupsdb} ||= new Cadi::CadiDB (
    dbname => $self->{dbname} || 'groupes',
     trace => $self->{tracesql},
      utf8 => $self->{utf8},
  );
  eval {
    require Cadi::Logs; import Cadi::Logs;
    $self->{logger} = new Cadi::Logs (caller => 'Groups');
  };
  bless $self, $class;
  
  unless ($self->{caller}) {
    $self->{errmsg} = "Groups : No caller.";
    warn "$self->{errmsg}\n";
    return $self;
  }
  if ($self->{caller} eq 'root') {
    $self->{root} = 1;
  }
  if ($self->{caller} ne 'root') {
    my $callerinfo = getObjectInfos ($self, $self->{caller});
    unless ($callerinfo) {
      #warn "Groups : Bad caller : $self->{caller}.";
      #warn "$self->{errmsg}\n";
    }
  }
  return $self;
}

sub getGroup {
  my ($self, $gnameorid) = @_;
  my $caller = $self->{caller};
  warn "Groups::getGroup ($caller, $gnameorid)\n" if $self->{trace};
  unless ($gnameorid) {
    $self->{errmsg} = "getGroup : No group name.";
    warn "$self->{errmsg}\n";
    return;
  }
  my $groupid = $self->dbfindgroup ($gnameorid);
  unless ($groupid) {
    $self->error ('getGroup', 'unknowngroup', $gnameorid);
    return;
  }
  my $group = $self->dbloadgroup ($groupid);
  unless ($self->canseemembers ($group)) {
    delete $group->{persons};
    delete $group->{members};
  }
  return $group;
}

sub getGroupFull {
  return getGroup (@_);
}

sub getGroupMetaData {
  my ($self, $gnameorid) = @_;
  my $caller = $self->{caller};
  warn "Groups::getGroupMetaData: ($caller, $gnameorid)\n" if $self->{trace};
  unless ($gnameorid) {
    $self->{errmsg} = "getGroupMetaData : No group name.";
    warn "$self->{errmsg}\n";
    return;
  }
  my $groupid = $self->dbfindgroup ($gnameorid);
  unless ($groupid) {
    $self->error ('getGroupMetaData', 'unknowngroup', $gnameorid);
    return;
  }
  my $group = $self->dbloadgroup ($groupid);
  #unless ($self->canseegroup ($group)) {
  #  $self->error ('getGroup', 'unknowngroup', $gnameorid);
  #  return;
  #}
  delete $group->{persons};
  delete $group->{members};
  return $group;
}

sub getObjectInfos {
  my ($self, $objectid) = @_;
  my $caller = $self->{caller};
  warn "Groups::getObjectInfos ($caller, $objectid)\n" if $self->{trace};
  unless ($objectid) {
    $self->{errmsg} = "getObjectInfos : No objectid.";
    warn "$self->{errmsg}\n";
    return;
  }
  if ($objectid =~ /^[GAZ\d]\d\d\d\d\d$/) {
    return $self->dbgetpersoninfos ($objectid);
  }
  elsif ($objectid =~ /^M\d\d\d\d\d$/) {
    return $self->dbgetserviceinfos ($objectid);
  }
  elsif ($objectid =~ /^S\d\d\d\d\d$/) {
    return $self->dbloadgroupdata ($objectid);
  }
  elsif ($objectid =~ /^U\d\d\d\d\d$/) {
    return $self->dbgetunitinfos ($objectid);
  }
  elsif ($objectid =~ /^L\d\d\d\d\d$/) {
    return $self->dbloadautogroup ($objectid);
  }
  elsif ($objectid =~ /^Q\d\d\d\d\d$/) {
    return $self->dbgetquery ($objectid);
  } else {
    return;
    #return {
    #         id => sprintf ("X%05s", $objectid),
    #       type => 'special',
    #     sciper => sprintf ("X%05s", $objectid),
    #       name => $objectid,
    #    display => $objectid,
    #};
  }
}

sub listMembers {
  my ($self, $gnameorid) = @_;
  my $caller = $self->{caller};
  my     $db = $self->{groupsdb};
  warn "Groups::getGroup ($caller, $gnameorid)\n" if $self->{trace};
  unless ($gnameorid) {
    $self->{errmsg} = "getGroup : No group name.";
    warn "$self->{errmsg}\n";
    return;
  }
  my $groupid = $self->dbfindgroup ($gnameorid);
  unless ($groupid) {
    $self->error ('getGroup', 'unknowngroup', $gnameorid);
    return;
  }
  my @members = $self->dblistmembers ($groupid);
  return sort { $a->{id} <=> $b->{id} } @members;
}

sub listAdmins {
  my ($self, $gnameorid) = @_;
  my $caller = $self->{caller};
  warn "Groups::listAdmins ($caller, $gnameorid)\n" if $self->{trace};
  unless ($gnameorid) {
    $self->{errmsg} = "listAdmins : No group name.";
    warn "$self->{errmsg}\n";
    return;
  }
  my $groupid = $self->dbfindgroup ($gnameorid);
  unless ($groupid) {
    $self->error ('listAdmins', 'unknowngroup', $gnameorid);
    return;
  }
  my ($admins, $persadmins) = $self->dblistadmins ($groupid);
  return sort { $a->{id} <=> $b->{id} } @$admins;
}

sub listGroups {
  my ($self, $letter) = @_;
  my $caller = $self->{caller};
  warn "Groups::listGroups ($caller, $letter)\n" if $self->{trace};
  my @groups = $self->dbsearchgroup ("^$letter.*");
  @groups = $self->filtergroups (@groups);
  return @groups;
}
#
# List all groups with persons. Only scipers. Used by LDAP builder.
#
sub listAllGroupsFull {
  my $self = shift;
  my $caller = $self->{caller};
  my     $db = $self->{groupsdb};
  warn "Groups::listAllGroupsFull ($caller)\n" if $self->{trace};
  #
  # Groups
  #
  my $sql = qq{select * from $groupstable};
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "listAllGroupsFull : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth);
  unless ($rv) {
    $self->{errmsg} = "listAllGroupsFull : $db->{errmsg}";
    return;
  }
  my @groups;
  while (my $group = $sth->fetchrow_hashref) {
    push (@groups, $group);
  }
  $sth->finish;

  @groups = $self->filtergroups (@groups);
  $self->fixgroups (@groups);
  #
  # Members
  #
  my $sql = qq{
    select * from $memberstable
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "listAllGroupsFull : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth);
  unless ($rv) {
    $self->{errmsg} = "listAllGroupsFull : $db->{errmsg}";
    return;
  }
  my ($Persons, $Children, $Units, $Services, $Switch, $Unitcache);
  while (my ($member, $groupid) = $sth->fetchrow) {
    if ($member =~ /^S/) {
      $Children->{$groupid}->{$member}  = 1;
      next;
    }
    if ($member =~ /^U/) {
      my $persons = $Unitcache->{$member} || $self->dbgetunitpersons ($member);
      map { $Persons->{$groupid}->{$_->{id}} = 1; } @$persons;
      $Unitcache->{$member} = $persons;
      next;
    }
    if ($member =~ /^[GMZ\d]/) {
      $Persons->{$groupid}->{$member} = 1;
      next;
    }
    warn "Invalid member in $groupid : $member\n";
  }
  my $ok = 0;
  while (!$ok) {
    $ok = 1;
    foreach my $parentid (keys %$Children) {
      my @children = keys %{$Children->{$parentid}};
      my $newchildren;
      foreach my $childid (@children) {
        if ($Children->{$childid}) {
          $newchildren->{$childid} = 1;
          $ok = 0;
          next;
        }
        foreach my $person (keys %{$Persons->{$childid}}) {
          $Persons->{$parentid}->{$person} = 1;
        }
      }
      $Children->{$parentid} = $newchildren;
    }
  }
  foreach my $group (@groups) {
    $group->{persons} = [ keys %{$Persons->{$group->{id}}} ];
  }
  return @groups;
}

sub listAllGroups {
  my $self = shift;
  my $caller = $self->{caller};
  my     $db = $self->{groupsdb};
  warn "Groups::listAllGroups ($caller)\n" if $self->{trace};

  my $sql = qq{select * from $groupstable};
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "listAllGroups : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth);
  unless ($rv) {
    $self->{errmsg} = "listAllGroups : $db->{errmsg}";
    return;
  }
  my @groups;
  while (my $group = $sth->fetchrow_hashref) {
    push (@groups, $group);
  }
  $sth->finish;
  @groups = $self->filtergroups (@groups);
  $self->fixgroups (@groups);
  return @groups;
}

sub searchGroup {
  my ($self, $pattern) = @_;
  my $caller = $self->{caller};
  warn "Groups::searchGroup ($caller, $pattern)\n" if $self->{trace};
  unless (eval { /$pattern/; 1 }) {
    $self->{errmsg} = "searchGroup : invalid pattern : $pattern";
    return;
  }
  my @groups = $self->dbsearchgroup ($pattern);
  @groups = $self->filtergroups (@groups);
  return @groups;
}

sub matchGroup {
  my ($self, $patterns) = @_;
  my $caller = $self->{caller};
  warn "Groups::matchGroup ($caller)\n" if $self->{trace};
  my $ok;
  my @fields = $self->dblistfields ($groupstable);
  my $fields = { map { $_, 1 } @fields };
  foreach my $attr (keys %$patterns) {
    next unless $fields->{$attr};
    my $pattern = $patterns->{$attr};
    unless (eval { /$pattern/; 1 }) {
      $self->{errmsg} = "matchGroup : invalid pattern : $pattern";
      return;
    }
    $ok = 1;
  }
  unless ($ok) {
    $self->{errmsg} = "matchGroup : No pattern given.";
    return;
  }
  my @groups = $self->dbmatchgroup ($patterns);
  @groups = $self->filtergroups (@groups);
  return @groups;
}

sub listGroupsOwnedBy {
  my ($self, $sciper) = @_;
  my $caller = $self->{caller};
  my     $db = $self->{groupsdb};
  warn "Groups::listGroupsOwnedBy ($caller, $sciper)\n" if $self->{trace};
  unless ($sciper) { $self->{errmsg} = "listGroupsOwnedBy : No sciper."; return; }
  my $sql = qq{
    select *
      from $groupstable
     where owner = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "listGroupsOwnedBy : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $sciper);
  unless ($rv) {
    $self->{errmsg} = "listGroupsOwnedBy : $db->{errmsg}";
    return;
  }
  my @groups;
  while (my $group = $sth->fetchrow_hashref) {
    $self->fixgroup ($group);
    push (@groups, $group);
  }
  $sth->finish;
  @groups = $self->filtergroups (@groups);
  return @groups;
}

sub listGroupsUserBelongsTo {
  my ($self, $sciper) = @_;
  my $caller = $self->{caller};
  unless ($sciper) {
    $self->{errmsg} = "listGroupsUserBelongsTo : No sciper.";
    return;
  }
  my @groups = $self->dblistgroupsuserbelongsto ($sciper);
  @groups = $self->filtergroups (@groups);
  return @groups;
}

sub listGroupsUserBelongsToFull {
  my ($self, $sciper) = @_;
  my @groups = $self->listGroupsUserBelongsTo ($sciper);
  @groups = $self->filtergroups (@groups);
  foreach my $group (@groups) {
    my $group = $self->dbloadgroup ($group->{id});
    unless ($self->canseemembers ($group)) {
      delete $group->{persons};
      delete $group->{members};
    }
  }
  return @groups;
}

sub listGroupsUserIsAdmin {
  my ($self, $sciper) = @_;
  my $caller = $self->{caller};
  unless ($sciper) {
    $self->{errmsg} = "listGroupsUserIsAdmin : No sciper.";
    return;
  }
  my @groups = $self->dblistgroupsuserisadmin ($sciper);
  @groups = $self->filtergroups (@groups);
  return @groups;
}

sub filtergroups {
  my ($self, @groups) = @_;
  my $caller = $self->{caller};
  if ($self->{root}) {
    return sort { $a->{name} cmp $b->{name} } @groups;
  }
  elsif ($caller) {
    my   @callergroups = $self->dblistgroupsuserbelongsto ($caller);
    my $callerismember = { map { $_->{id}, 1 } @callergroups };
    my    @admingroups = $self->dblistgroupsuserisadmin ($caller);
    my  $callerisadmin = { map { $_->{id}, 1 } @admingroups };
    my @retgroups;
    foreach my $group (@groups) {
      push (@retgroups, $group)
      if ($group->{visible}               ||
        $callerismember->{$group->{id}} ||
        $callerisadmin->{$group->{id}} ||
        $group->{owner} eq $caller);
    }
    return sort { $a->{name} cmp $b->{name} } @retgroups;
  } else {
    my @retgroups;
    foreach my $group (@groups) {
      push (@retgroups, $group) if $group->{visible};
    }
    return sort { $a->{name} cmp $b->{name} } @retgroups;
  }
  return;
}

sub addGroup {
  my ($self, $group) = @_;
  my $db = $self->{groupsdb};
  if ($self->{readonly}) {
    $self->{errmsg} = "addGroup : database is readonly.";
    warn "Groups::addGroup: $self->{errmsg}\n";
    return;
  }
  my $caller = $self->{caller};
  warn "Groups::addGroup ($caller, $group->{name})\n" if $self->{trace};
  unless ($caller) {
    $self->{errmsg} = "addGroup : No caller.";
    return;
  }
  $group->{access}       ||= 'o';
  $group->{registration} ||= 'f';
  $group->{owner}        ||= $caller;
  unless ($group->{name}) {
    $self->{errmsg} = "addGroup : No group name.";
    warn "Groups::addGroup: $self->{errmsg}\n";
    return;
  }
  unless ($group->{name} =~ /^[a-z][a-z0-9\-\._]*$/i) {
    $self->{errmsg} = "addGroup : Invalid group name : $group->{name}.";
    warn "Groups::addGroup: $self->{errmsg}\n";
    return;
  }
  my $badnames = $self->dbloadbadnames ();
  if ($badnames->{$group->{name}}) {
    $self->{errmsg} = "addGroup : Forbidden group name : $group->{name}.";
    warn "Groups::addGroup: $self->{errmsg}\n";
    return;
  }
  unless ($group->{owner} =~ /^[\w\d]*$/) {
    $self->{errmsg} = "addGroup : Invalid group owner : $group->{owner}.";
    warn "Groups::addGroup: $self->{errmsg}\n";
    return;
  }
  unless ($self->{root} || ($caller eq $group->{owner})) {
    $self->{errmsg} = "addGroup : Access denied, you can only add a group you own.";
    warn "Groups::addGroup: $self->{errmsg}\n";
    return;
  }
  unless ($group->{access} =~ /^[orf]$/) {
    $self->{errmsg} =  "addGroup : Invalid access string : $group->{access}.";
    warn "Groups::addGroup: $self->{errmsg}\n";
    return;
  }
  unless ($group->{registration} =~ /^[owf]$/) {
    $self->{errmsg} = "addGroup : Invalid registration string : $group->{registration}.";
    warn "Groups::addGroup: $self->{errmsg}\n";
    return;
  }
  unless ($group->{owner} =~ /^[M\d]\d\d\d\d\d$/) {
    $self->{errmsg} = "addGroup : Owner must be EPFL member or service.";
    warn "Groups::addGroup: $self->{errmsg}\n";
    return;
  }
  my $groupid = $self->dbfindgroup ($group->{name});
  if ($groupid) {
    $self->error ('addGroup', 'groupalreadyexists', $group->{name});
    warn "Groups::addGroup: $self->{errmsg}\n";
    return;
  }
  $group->{gid} = $self->allocGID ();
  #
  # Add groups table entry.
  #
  my $sql = qq{insert into $groupstable set
                         name = ?,
                        owner = ?,
                  description = ?,
                          url = ?,
                       access = ?,
                 registration = ?,
                      visible = ?,
                     maillist = ?,
                     visilist = ?,
                      listext = ?,
                       public = ?,
                         ldap = ?,
                          gid = ?,
                     creation = now()
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "addGroup : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth,
    $group->{name},
    $group->{owner},
    $group->{description},
    $group->{url},
    $group->{access},
    $group->{registration},
    $group->{visible}  ? 'y' : 'n',
    $group->{maillist} ? 'y' : 'n',
    $group->{visilist} ? 'y' : 'n',
    $group->{listext}  ? 'y' : 'n',
    $group->{public}   ? 'y' : 'n',
    $group->{ldap}     ? 'y' : 'n',
    $group->{gid}
  );
  unless ($rv) {
    $self->{errmsg} = "addGroup : $db->{errmsg}";
    warn "$self->{errmsg}\n";
    return;
  }
  my $numid = $sth->{mysql_insertid};
  $sth->finish;
  #
  # Set id field.
  #
  $group->{id} = sprintf ('S%05d', $numid);
  my $sql = qq{
    update $groupstable
       set    id = ?
     where numid = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Groups::addGroup : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $group->{id}, $numid);
  unless ($rv) {
    $self->{errmsg} = "Groups::addGroup : $db->{errmsg}";
    return;
  }
  #
  # Add members if any, otherwise add owner.
  #
  $group->{members} = [ $group->{owner} ]
    unless ($group->{members} && @{$group->{members}});

  my $sql = qq{insert into $memberstable set member = ?, groupid = ?};
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "addGroup : $db->{errmsg}";
    warn "$self->{errmsg}\n";
    return;
  }
  foreach my $member (@{$group->{members}}) {
    my $rv = $db->execute ($sth, $member, $group->{id});
    unless ($rv) {
      $self->{errmsg} = "addGroup : $db->{errmsg}";
      warn "$self->{errmsg}\n";
      next;
    }
  }
  $sth->finish;
  #
  # Update members
  #
  $group = $self->dbloadgroup ($group->{id});
  Notifier::notify (
     event => 'creategroup',
    author => $caller,
        id => $group->{id},
  ) if $self->{notify};
  $self->updatemembers ($group);
  #
  # Log action.
  #
  $self->log ('creategroup', $group->{id}, $group) if $self->{logger};
  Lists::addGroup ($group) if $group->{maillist};
  return $group;
}

sub deleteGroup {
  my ($self, $gnameorid) = @_;
  my $db = $self->{groupsdb};
  if ($self->{readonly}) {
    $self->{errmsg} = "Groups::deleteGroup : database is readonly.";
    warn "$self->{errmsg}\n";
    return;
  }
  my $caller = $self->{caller};
  warn "Groups::deleteGroup ($caller, $gnameorid)\n" if $self->{trace};
  unless ($caller) {
    $self->{errmsg} = "Groups::deleteGroup : No caller.";
    warn "$self->{errmsg}\n";
    return;
  }
  unless ($gnameorid) {
    $self->{errmsg} = "Groups::deleteGroup : No group name or id.";
    warn "$self->{errmsg}\n";
    return;
  }
  my $groupid = $self->dbfindgroup ($gnameorid);
  warn "Groups::deleteGroup::groupid = $groupid\n" if $self->{trace};
  unless ($groupid) {
    $self->{errmsg} = "Groups::deleteGroup : unknown group : $gnameorid.";
    warn "$self->{errmsg}\n";
    return;
  }
  my $group = $self->dbloadgroup ($groupid);
  unless ($self->{root} || isowner ($group, $caller)) {
    $self->{errmsg} = "Groups::deleteGroup : Access denied, only the owner can remove a group.";
    warn "$self->{errmsg}\n";
    return;
  }
  #
  # Check if the group to delete is member of another group.
  #
  my $sql = qq{
    select name
      from $groupstable, $memberstable
     where      $groupstable.id = $memberstable.groupid
       and $memberstable.member = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Groups::deleteGroup : $db->{errmsg}";
    warn "$self->{errmsg}\n";
    return;
  }
  my $rv = $db->execute ($sth, $group->{id});
  unless ($rv) {
    $self->{errmsg} = "Groups::deleteGroup : $db->{errmsg}";
    warn "$self->{errmsg}\n";
    return;
  }
  my $numrows = $sth->rows;
  if ($numrows) {
    my $groupnames = $sth->fetchall_arrayref ([0]);
    my @groupnames = map { $_->[0] } @$groupnames;
    $self->{errmsg} = "Groups::deleteGroup : Group $group->{name} is subgroup of @groupnames";
    warn "$self->{errmsg}\n";
    return;
  }
  $sth->finish;
  #
  # Check if the group to delete is excluded from another group.
  #
  my $sql = qq{
    select name
      from $groupstable, $excludedtable
     where       $groupstable.id = $excludedtable.groupid
       and $excludedtable.member = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Groups::deleteGroup : $db->{errmsg}";
    warn "$self->{errmsg}\n";
    return;
  }
  my $rv = $db->execute ($sth, $group->{id});
  unless ($rv) {
    $self->{errmsg} = "Groups::deleteGroup : $db->{errmsg}";
    warn "$self->{errmsg}\n";
    return;
  }
  my $numrows = $sth->rows;
  if ($numrows) {
    my $groupnames = $sth->fetchall_arrayref ([0]);
    my @groupnames = map { $_->[0] } @$groupnames;
    $self->{errmsg} = "Groups::deleteGroup : Group $group->{name} is excluded from @groupnames";
    $sth->finish;
    return;
  }
  $sth->finish;
  #
  # We can remove safely.
  #
  my $sql = qq{
    delete from $groupstable
     where id = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Groups::deleteGroup : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $group->{id});
  unless ($rv) {
    $self->{errmsg} = "Groups::deleteGroup : $db->{errmsg}";
    return;
  }
  $sth->finish;

  my $sql = qq{
    delete from $memberstable
     where groupid = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Groups::deleteGroup : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $group->{id});
  unless ($rv) {
    $self->{errmsg} = "Groups::deleteGroup : $db->{errmsg}";
    return;
  }
  $sth->finish;

  my $sql = qq{
    delete from $adminstable
     where groupid = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Groups::deleteGroup : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $group->{id});
  unless ($rv) {
    $self->{errmsg} = "Groups::deleteGroup : $db->{errmsg}";
    return;
  }
  $sth->finish;

  Notifier::notify (
     event => 'removegroup',
      name => $group->{name},
        id => $group->{id},
      ldap => $group->{ldap},
    author => $caller,
  ) if $self->{notify};
  Lists::deleteGroup ($group) if $group->{maillist};
  $self->log ('removegroup', $group->{id}) if $self->{logger};
  return 1;
}

sub renameGroup {
  my ($self, $gnameorid, $newname) = @_;
  my $db = $self->{groupsdb};
  if ($self->{readonly}) {
    $self->{errmsg} = "renameGroup : database is readonly.";
    warn "Groups::renameGroup: $self->{errmsg}\n";
    return;
  }
  my $caller = $self->{caller};
  warn "Groups::renameGroup ($caller, $gnameorid, $newname)\n" if $self->{trace};
  unless ($caller) {
    $self->{errmsg} = "renameGroup : No caller.";
    return;
  }
  unless ($gnameorid) {
    $self->{errmsg} = "renameGroup : No group name or id.";
    return;
  }
  unless ($newname) {
    $self->{errmsg} = "renameGroup : No newname.";
    return;
  }
  unless ($newname =~ /^[a-z][a-z0-9\-\._]*$/i) {
    $self->{errmsg} = "renameGroup : Invalid new group name : $newname.";
    return;
  }
  my $badnames = $self->dbloadbadnames ();
  if ($badnames->{$newname}) {
    $self->{errmsg} = "renameGroup : Forbidden new group name : $newname.";
    return;
  }
  my $groupid = $self->dbfindgroup ($newname);
  if ($groupid) {
    $self->{errmsg} = "renameGroup : Group $newname already exists.";
    return;
  }
  my $groupid = $self->dbfindgroup ($gnameorid);
  unless ($groupid) {
    $self->{errmsg} = "renameGroup : Group $gnameorid doesn't exist.";
    return;
  }
  my   $group = $self->dbloadgroup ($groupid);
  my $oldname = $group->{name};
  unless ($self->{root} || isowner ($group, $caller)) {
    $self->{errmsg} = "renameGroup : Access denied, only the owner can rename a group.";
    return;
  }
  my $sql = qq{
    update $groupstable
       set name = ?
     where   id = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "renameGroup : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $newname, $groupid);
  unless ($rv) {
    $self->{errmsg} = "deleteGroup : $db->{errmsg}";
    return;
  }
  $sth->finish;

  Notifier::notify (
      event => 'renamegroup',
     author => $caller,
         id => $group->{id},
    oldname => $oldname,
    newname => $newname,
  ) if $self->{notify};
  if ($group->{maillist}) {
    Lists::deleteGroup ($group);
    $group->{name} = $newname;
    Lists::updateGroup ($group);
  }
  $self->log ('modifygroup', $group->{id},
    { name => $newname },
    { name => $oldname }
  ) if $self->{logger};
  return 1;
}

sub modifyGroup {
  my ($self, $gnameorid, %modifs) = @_;
  my $db = $self->{groupsdb};
  if ($self->{readonly}) {
    $self->{errmsg} = "modifyGroup : database is readonly.";
    warn "Groups::modifyGroup: $self->{errmsg}\n";
    return;
  }
  my $caller = $self->{caller};
  warn "Groups::modifyGroup ($caller, $gnameorid)\n" if $self->{trace};
  unless ($caller) {
    $self->{errmsg} = "modifyGroup : No caller.";
    warn "$self->{errmsg}\n";
    return;
  }
  unless ($gnameorid) {
    $self->{errmsg} = "modifyGroup : No group name or id.";
    warn "$self->{errmsg}\n";
    return;
  }
  my $groupid = $self->dbfindgroup ($gnameorid);
  unless ($groupid) {
    $self->error ('modifyGroup', 'unknowngroup', $gnameorid);
    warn "$self->{errmsg}\n";
    return;
  }
  my $modifs = \%modifs;
  if (exists $modifs->{owner} && $modifs->{owner} !~ /^[\w\d]*$/) {
    $self->{errmsg} = "modifyGroup : Invalid group owner : $modifs->{owner}.";
    return;
  }
  if (exists $modifs->{access} && $modifs->{access} !~ /^[orf]$/) {
    $self->{errmsg} =  "modifyGroup : Invalid access string : $modifs->{access}.";
    return;
  }
  if (exists $modifs->{registration} && $modifs->{registration} !~ /^[owf]$/) {
    $self->{errmsg} = "modifyGroup : Invalid registration string : ".
                      "$modifs->{registration}.";
    return;
  }
  my $group = $self->dbloadgroup ($groupid);
  unless ($self->{root} || isowner ($group, $caller)) {
    $self->{errmsg} = "modifyGroup : Access denied, only the owner can modify a group.";
    return;
  }
  my @allfields =qw{owner description url access registration visible visilist
                    listext maillist ldap public};
  my $bools = {
      visible => 1,
     maillist => 1,
     visilist => 1,
      listext => 1,
       public => 1,
         ldap => 1,
       public => 1,
  };
  my (@fields, @values);
  foreach my $field (@allfields) {
    next unless exists $modifs->{$field};
    next if ($group->{$field} eq $modifs->{$field});
    my $value = $modifs->{$field};
    if ($bools->{$field}) {
      $value            = $modifs->{$field} ? 'y' : 'n';
      $modifs->{$field} = $modifs->{$field} ? '1' : '0';
    }
    push (@fields, $field);
    push (@values, $value);
  }
  unless (@fields) {
    $self->{errmsg} = "modifyGroup : No modification";
    return;
  }
  my $set = join (', ', map { "$_ = ?" } @fields);
  my $sql = qq{
    update $groupstable set $set where id = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "modifyGroup : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, @values, $group->{id});
  unless ($rv) {
    $self->{errmsg} = "modifyGroup : $db->{errmsg}";
    return;
  }
  $sth->finish;

  Notifier::notify (
     event => 'modifygroup',
    author => $caller,
        id => $group->{id},
  ) if $self->{notify};

  if (exists $modifs->{maillist}) {
    my $oldmail = $group->{maillist};
    my $newmail = $modifs->{maillist};
    Lists::updateGroup ($group) if ($newmail && !$oldmail);
    Lists::deleteGroup ($group) if ($oldmail && !$newmail);
  }

  if (exists $modifs->{listext}) {
    if ($modifs->{listext} != $group->{listext}) {
      $group->{listext} = $modifs->{listext};
      Lists::updateStatus ($group);
    }
  }
  $self->log ('modifygroup', $group->{id}, $modifs, $group) if $self->{logger};
  return 1;
}

sub addMember {
  my ($self, $gnameorid, $member) = @_;
  my $db = $self->{groupsdb};
  warn "Groups::addMember::($gnameorid, $member)\n" if $self->{trace};
  if ($self->{readonly}) {
    $self->{errmsg} = "addMember : database is readonly.";
    warn "Groups::addMember: $self->{errmsg}\n";
    return;
  }
  my $caller = $self->{caller};
  warn "Groups::addMember ($caller, $gnameorid, $member)\n" if $self->{trace};
  unless ($caller) {
    $self->{errmsg} = "addMember : No caller.";
    warn "$self->{errmsg}\n";
    return;
  }
  unless ($gnameorid) {
    $self->{errmsg} = "addMember : No group name or id.";
    warn "$self->{errmsg}\n";
    return;
  }
  my $groupid = $self->dbfindgroup ($gnameorid);
  unless ($groupid) {
    $self->error ('addMember', 'unknowngroup', $gnameorid);
    warn "$self->{errmsg}\n";
    return;
  }
  my $group = $self->dbloadgroup ($groupid);
  unless ($self->{root} ||
          isowner ($group, $caller) ||
          isadmin ($group, $caller) ||
          (($group->{registration} =~ /^(o|w)$/) && ($member eq $caller))) {
    $self->{errmsg} = "addMember : Access denied, only the owner and ".
      "admins can add members to a group.";
    return;
  }
  my $ismember = ismember ($group, $member);
  if ($ismember) {
    $self->{errmsg} = "addMember : $member is already member of $group->{name}";
    return;
  }
  
  my $memberinfo = $self->getObjectInfos ($member);
  unless ($memberinfo) {
    $self->error ('addMember', 'unknownobject', $member);
    warn "$self->{errmsg}\n";
    return;
  }
  
  if ($member =~ /^S\d\d\d\d\d$/) { # Check for loops.
    my $subgroup = $self->dbloadgroup ($member);
    unless (checkloop ($group, $subgroup)) {
      $self->{errmsg} = "addMember : $subgroup->{name} is an ancestor of $group->{name}";
      return;
    }
    if (($subgroup->{owner} ne $caller) && !$subgroup->{public}) {
      $self->{errmsg} = "addMember : You don't own group $subgroup->{name} ".
                        "and it is not public";
      return;
    }
  }

  my $sql = qq{
    insert into $memberstable
       set  member = ?,
           groupid = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "addMember : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $member, $group->{id});
  unless ($rv) {
    $self->{errmsg} = "deleteGroup : $db->{errmsg}";
    return;
  }
  $sth->finish;
  push (@{$group->{members}}, $member);
  $group = $self->dbloadgroup ($groupid);
  $self->updatemembers ($group);
  $self->log ('addgroupmembers', $group->{id}, { member => $member }) if $self->{logger};
  return 1;
}

sub removeMember {
  my ($self, $gnameorid, $member) = @_;
  my $db = $self->{groupsdb};
  if ($self->{readonly}) {
    $self->{errmsg} = "removeMember : database is readonly.";
    warn "Groups::removeMember: $self->{errmsg}\n";
    return;
  }
  my $caller = $self->{caller};
  warn "Groups::removeMember ($caller, $gnameorid, $member)\n" if $self->{trace};
  unless ($caller) {
    $self->{errmsg} = "removeMember : No caller.";
    warn "$self->{errmsg}\n";
    return;
  }
  unless ($gnameorid) {
    $self->{errmsg} = "removeMember : No group name or id.";
    warn "$self->{errmsg}\n";
    return;
  }
  my $groupid = $self->dbfindgroup ($gnameorid);
  warn "Groups::removeMember::groupid = $groupid\n" if $self->{trace};
  unless ($groupid) {
    $self->error ('removeMember', 'unknowngroup', $gnameorid);
    warn "$self->{errmsg}\n";
    return;
  }
  my $group = $self->dbloadgroup ($groupid);
  unless ($self->{root} ||
          isowner ($group, $caller) ||
          isadmin ($group, $caller) ||
          (($group->{registration} =~ /^(o|w)$/) && ($member eq $caller))) {
    $self->{errmsg} = "removeMember : Access denied, only the owner and admins ".
      "can remove members from a group.";
    warn "$self->{errmsg}\n";
    return;
  }
  my $ismember = ismember ($group, $member);
  if (!$ismember) {
    $self->{errmsg} = "removeMember : $member is not member of group $group->{name}";
    warn "$self->{errmsg}\n";
    return;
  }
  if (@{$group->{members}} == 1) {
    $self->{errmsg} = "removeMember : $member is the last member of group $group->{name}";
    warn "$self->{errmsg}\n";
    return;
  }
  #
  # Actual delete
  #
  my $sql = qq{
    delete from $memberstable
     where  member = ?
       and groupid = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "removeMember : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $member, $group->{id});
  unless ($rv) {
    $self->{errmsg} = "deleteGroup : $db->{errmsg}";
    return;
  }
  $sth->finish;
  #
  # If group is empty undo delete member.
  #
  my $group = $self->dbloadgroup ($groupid);
  unless (@{$group->{persons}}) {
    my $sql = qq{
      insert into $memberstable set
         member = ?,
        groupid = ?
    };
    my $sth = $db->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "removeMember : $db->{errmsg}";
      return;
    }
    my $rv = $db->execute ($sth, $member, $group->{id});
    unless ($rv) {
      $self->{errmsg} = "deleteGroup : $db->{errmsg}";
      return;
    }
    $sth->finish;
    $self->{errmsg} = "removeMember : $group->{name} would be empty after this";
    return;
  }
  $group = $self->dbloadgroup ($groupid);
  $self->updatemembers ($group);
  $self->log (
    'removegroupmembers',
    $group->{id},
      {
        member => $member,
      },
  ) if $self->{logger};
  return 1;
}

sub excludeMember {
  my ($self, $gnameorid, $member) = @_;
  my $db = $self->{groupsdb};
  if ($self->{readonly}) {
    $self->{errmsg} = "excludeMember : database is readonly.";
    warn "Groups::excludeMember: $self->{errmsg}\n";
    return;
  }
  my $caller = $self->{caller};
  warn "Groups::excludeMember ($caller, $gnameorid, $member)\n" if $self->{trace};
  unless ($caller) {
    $self->{errmsg} = "excludeMember : No caller.";
    warn "$self->{errmsg}\n";
    return;
  }
  unless ($gnameorid) {
    $self->{errmsg} = "excludeMember : No group name or id.";
    warn "$self->{errmsg}\n";
    return;
  }
  my $groupid = $self->dbfindgroup ($gnameorid);
  unless ($groupid) {
    $self->error ('excludeMember', 'unknowngroup', $gnameorid);
    warn "$self->{errmsg}\n";
    return;
  }
  my $group = $self->dbloadgroup ($groupid);
  my @excludedids = map { $_->{id} } @{$group->{excluded}};
  if (grep /^$member$/, @excludedids) {
    $self->{errmsg} = "excludeMember : this member is already excluded ".
      "from group $group->{name}.";
    return;
  }
  unless ($self->{root} || isowner ($group, $caller)
                        || isadmin ($group, $caller)) {
    $self->{errmsg} = "excludeMember : Access denied, only the owner and admins ".
      "can exclude a person from a group.";
    return;
  }
  my @persons = @{$group->{persons}};
  if ($member =~ /^[GMZ\d]\d\d\d\d\d$/) {
    my $userbelongsto = belongsto ($group, $member);
    if (!$userbelongsto) {
      $self->{errmsg} = "excludeMember : $member is not member of group $group->{name}";
      return;
    }
  }
  if ($member =~ /^S\d\d\d\d\d$/) {
    my $excludegroup = $self->dbloadgroup ($member);
    unless (checkloop ($group, $excludegroup)) {
      $self->{errmsg} = "excludeMember : $excludegroup->{name} is an ".
                        "ancestor of $group->{name}";
      return;
    }
    if (($excludegroup->{owner} ne $group->{owner}) && !$excludegroup->{public}) {
      $self->{errmsg} = "addMember : You don't own group $excludegroup->{name} ".
                        "and it is not public";
      return;
    }
  }
  my $userismember = ismember ($group, $member);
  if ($userismember) {
    $self->{errmsg} = "excludeMember : $member direct member of group $group->{name}";
    return;
  }
  
  
  my $sql = qq{
    insert into $excludedtable set
       member = ?,
      groupid = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "excludeMember : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $member, $group->{id});
  unless ($rv) {
    $self->{errmsg} = "deleteGroup : $db->{errmsg}";
    return;
  }
  $sth->finish;

  my $group = $self->dbloadgroup ($groupid);
  unless (@{$group->{persons}}) {
    my $sql = qq{delete from $excludedtable
                  where  member = ?
                    and groupid = ?
    };
    my $sth = $db->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "excludeMember : $db->{errmsg}";
      return;
    }
    my $rv = $db->execute ($sth, $member, $group->{id});
    unless ($rv) {
      $self->{errmsg} = "deleteGroup : $db->{errmsg}";
      return;
    }
    $sth->finish;
    $self->{errmsg} = "removeMember : $group->{name} would be empty after this";
    return;
  }
  $group = $self->dbloadgroup ($groupid);
  $self->updatemembers ($group);
  $self->log (
    'excludegroupmember',
    $group->{id},
    {
      member => $member,
    },
  ) if $self->{logger};
  return 1;
}

sub unExcludeMember {
  my ($self, $gnameorid, $member) = @_;
  my $db = $self->{groupsdb};
  if ($self->{readonly}) {
    $self->{errmsg} = "unExcludeMember : database is readonly.";
    warn "Groups::unExcludeMember: $self->{errmsg}\n";
    return;
  }
  my $caller = $self->{caller};
  warn "unExcludeMember ($caller, $gnameorid, $member)\n" if $self->{trace};
  unless ($caller) {
    $self->{errmsg} = "unExcludeMember : No caller.";
    warn "$self->{errmsg}\n";
    return;
  }
  unless ($gnameorid) {
    $self->{errmsg} = "unExcludeMember : No group name or id.";
    warn "$self->{errmsg}\n";
    return;
  }
  my $groupid = $self->dbfindgroup ($gnameorid);
  unless ($groupid) {
    $self->error ('unExcludeMember', 'unknowngroup', $gnameorid);
    warn "$self->{errmsg}\n";
    return;
  }
  my $group = $self->dbloadgroup ($groupid);
  my @excludedids = map { $_->{id} } @{$group->{excluded}};
  if (!grep /^$member$/, @excludedids) {
    $self->{errmsg} = "unExcludeMember : this member is not excluded ".
      "from group $group->{name}.";
    return;
  }
  unless ($self->{root} || isowner ($group, $caller)
                        || isadmin ($group, $caller)) {
    $self->{errmsg} = "unExcludeMember : Access denied, only the owner and admins ".
      "can reintegrate a person in a group.";
    return;
  }
  my $sql = qq{
    delete from $excludedtable
     where  member = ?
       and groupid = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "unExcludeMember : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $member, $group->{id});
  unless ($rv) {
    $self->{errmsg} = "unExcludeMember : $db->{errmsg}";
    return;
  }
  $sth->finish;
  $group = $self->dbloadgroup ($groupid);
  $self->updatemembers ($group);
  $self->log (
    'unexcludegroupmember',
    $group->{id},
    {
      member => $member,
    },
  ) if $self->{logger};
  return 1;
}

sub changeOwner {
  my ($self, $gnameorid, $sciper) = @_;
  my $db = $self->{groupsdb};
  if ($self->{readonly}) {
    $self->{errmsg} = "changeOwner : database is readonly.";
    warn "Groups::changeOwner: $self->{errmsg}\n";
    return;
  }
  my $caller = $self->{caller};
  warn "Groups::changeOwner ($caller, $gnameorid, $sciper)\n" if $self->{trace};
  unless ($caller) {
    $self->{errmsg} = "changeOwner : No caller.";
    warn "$self->{errmsg}\n";
    return;
  }
  unless ($sciper =~ /^[M\d]\d\d\d\d\d$/) {
    $self->{errmsg} = "changeOwner : Bad new owner.";
    warn "$self->{errmsg}\n";
    return;
  }
  unless ($gnameorid) {
    $self->{errmsg} = "changeOwner : No group name or id.";
    warn "$self->{errmsg}\n";
    return;
  }
  my $groupid = $self->dbfindgroup ($gnameorid);
  unless ($groupid) {
    $self->error ('changeOwner', 'unknowngroup', $gnameorid);
    warn "$self->{errmsg}\n";
    return;
  }
  unless ($sciper =~ /^[\w\d]*$/) {
    $self->{errmsg} = "changeOwner : Invalid sciper : $sciper.";
    return;
  }
  my $group = $self->dbloadgroup ($groupid);
  unless ($self->{root} || isowner ($group, $caller)) {
    $self->{errmsg} = "changeOwner : Access denied, only the owner ".
      "can change the owner of a group.";
    return;
  }
  my $sql = qq{
    update $groupstable
       set owner = ?
     where    id = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "excludePerson : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $sciper, $group->{id});
  unless ($rv) {
    $self->{errmsg} = "excludePerson : $db->{errmsg}";
    return;
  }
  Notifier::notify (
     event => 'changegroupowner',
    author => $caller,
        id => $group->{id},
  ) if $self->{notify};
  $self->log (
    'modifygroup',
    $group->{id},
    {
      owner => $sciper,
    },
    {
      owner => $group->{owner},
    }
  ) if $self->{logger};
  return 1;
}

sub addAdmin {
  my ($self, $gnameorid, $adminid) = @_;
  my $db = $self->{groupsdb};
  if ($self->{readonly}) {
    $self->{errmsg} = "addAdmin : database is readonly.";
    warn "Groups::addAdmin: $self->{errmsg}\n";
    return;
  }
  my $caller = $self->{caller};
  warn "Groups::addAdmin ($caller, $gnameorid, $adminid)\n" if $self->{trace};
  unless ($caller) {
    $self->{errmsg} = "addAdmin : No caller.";
    warn "$self->{errmsg}\n";
    return;
  }
  unless ($gnameorid) {
    $self->{errmsg} = "addAdmin : No group name or id.";
    warn "$self->{errmsg}\n";
    return;
  }
  my $groupid = $self->dbfindgroup ($gnameorid);
  unless ($groupid) {
    $self->error ('addAdmin', 'unknowngroup', $gnameorid);
    warn "$self->{errmsg}\n";
    return;
  }
  unless ($adminid =~ /^[\w\d]\d\d\d\d\d$/) {
    $self->{errmsg} = "addAdmin : Invalid Id : $adminid.";
    return;
  }
  
  my $group = $self->dbloadgroup ($groupid);
  unless ($self->{root} || isowner ($group, $caller)) {
    $self->{errmsg} = "addAdmin : Access denied, only the owner can add admins to a group.";
    return;
  }
  my $sql = qq{select admin, groupid from $adminstable
                where groupid = ?
                  and   admin = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "addAdmin : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $group->{id}, $adminid);
  unless ($rv) {
    $self->{errmsg} = "addAdmin : $db->{errmsg}";
    return;
  }
  my ($admin, $groupid) = $sth->fetchrow;
  $sth->finish;
  if ($groupid) {
    $self->{errmsg} = "addAdmin : $adminid is already admin of group $gnameorid";
    return;
  }
  
  if ($adminid =~ /^S/) {
    my $admingroup = $self->dbloadgroup ($adminid);
    unless ($admingroup) {
      $self->{errmsg} = "addAdmin : Unknown group $adminid";
      return;
    }
    unless (checkloop ($group, $admingroup)) {
      $self->{errmsg} = "addAdmin : $admingroup->{name} is an ancestor of $group->{name}";
      return;
    }
  }

  my $sql = qq{
    insert into $adminstable
       set   admin = ?,
           groupid = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "addAdmin : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $adminid, $group->{id});
  unless ($rv) {
    $self->{errmsg} = "deleteGroup : $db->{errmsg}";
    return;
  }
  $self->log (
    'addgroupadmin',
    $group->{id},
    {
      admin => $adminid,
    },
  ) if $self->{logger};
  return 1;
}

sub removeAdmin {
  my ($self, $gnameorid, $adminid) = @_;
  my $db = $self->{groupsdb};
  if ($self->{readonly}) {
    $self->{errmsg} = "removeAdmin : database is readonly.";
    warn "Groups::removeAdmin: $self->{errmsg}\n";
    return;
  }
  my $caller = $self->{caller};
  warn "Groups::removeAdmin ($caller, $gnameorid $adminid)\n" if $self->{trace};
  unless ($caller) {
    $self->{errmsg} = "removeAdmin : No caller.";
    warn "$self->{errmsg}\n";
    return;
  }
  unless ($gnameorid) {
    $self->{errmsg} = "removeAdmin : No group name or id.";
    warn "$self->{errmsg}\n";
    return;
  }
  my $groupid = $self->dbfindgroup ($gnameorid);
  unless ($groupid) {
    $self->error ('removeAdmin', 'unknowngroup', $gnameorid);
    warn "$self->{errmsg}\n";
    return;
  }
  unless ($adminid =~ /^[\w\d]\d\d\d\d\d$/) {
    $self->{errmsg} = "removeAdmin : Invalid Id : $adminid.";
    return;
  }
  my $group = $self->dbloadgroup ($groupid);
  unless ($self->{root} || isowner ($group, $caller)) {
    $self->{errmsg} = "removeAdmin : Access denied, only the owner can ".
                      "add admins to a group.";
    return;
  }
  my $sql = qq{select admin, groupid from $adminstable
                where groupid = ?
                  and   admin = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "removeAdmin : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $group->{id}, $adminid);
  unless ($rv) {
    $self->{errmsg} = "removeAdmin : $db->{errmsg}";
    return;
  }
  my ($admin, $groupid) = $sth->fetchrow;
  $sth->finish;
  if (!$groupid) {
    $self->{errmsg} = "removeAdmin : $adminid is not admin of group $gnameorid";
    return;
  }
  my $sql = qq{
    delete from $adminstable
     where   admin = ?
       and groupid = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "removeAdmin : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $adminid, $group->{id});
  unless ($rv) {
    $self->{errmsg} = "removeAdmin : $db->{errmsg}";
    return;
  }
  $self->log (
    'removegroupadmin',
    $group->{id},
    {
      admin => $adminid,
    },
  ) if $self->{logger};
  return 1;
}

sub listQueries {
  my ($self, $sciper) = @_;
  my  $caller = $self->{caller};
  my @queries = $self->dblistqueries ($sciper);
  if ($self->{root} || $caller eq $sciper) {
    return @queries;
  } else {
    my @retqueries;
    foreach my $query (@queries) {
      push (@retqueries, $query)
        if ($caller eq $query->{owner} || $query->access eq 'p');
    }
    return @retqueries;
  }
  return;
}

sub getQuery {
  my ($self, $queryid) = @_;
  my $caller = $self->{caller};
  my  $query = $self->dbgetquery ($queryid);
  unless ($caller eq $query->{owner} || $query->access eq 'p') {
    $self->{errmsg} = "getQuery : Access denied, you are not ".
                      "allowed to read this query.";
    return;
  }
  return $query;
}

sub addToGroup {
  addMember (@_);
}

sub removeFromGroup {
  removeMember (@_);
}

sub dbfindgroup {
  my ($self, $gnameorid) = @_;
  my $db = $self->{groupsdb};
  my ($sql, $field);
  if ($gnameorid =~ /^S0*(\d+)$/) {
    $field = 'id';
  } else {
    #unless ($gnameorid =~ /^[a-z][a-z0-9\-\._]*$/i) {
    unless ($gnameorid =~ /^[a-z0-9\-\._]+$/i) {
      $self->{errmsg} = "dbfindgroup: Invalid group name : $gnameorid";
      return;
    }
    $field = 'name';
  }
  my $sql = qq{
    select id
      from $groupstable
     where $field = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dbfindgroup : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $gnameorid);
  unless ($rv) {
    $self->{errmsg} = "dbfindgroup : $db->{errmsg}";
    return;
  }
  my ($groupid) = $sth->fetchrow;
  $sth->finish;
  return $groupid if $groupid;
  return unless $doautolists;

  my ($field, $value);
  if ($gnameorid =~ /^L0*(\d+)$/) {
    $field = 'id';
    $value = $1;
  } else {
    $field = 'concat(subtype,'.',unite)';
    $value = $gnameorid;
  }
  my $sql = qq{
    select id
      from dinfo.autolistes
     where $field = ?
     order by type, subtype, unite
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dbfindgroup : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $value);
  unless ($rv) {
    $self->{errmsg} = "dbfindgroup : $db->{errmsg}";
    return;
  }
  my ($listid) = $sth->fetchrow;
  $sth->finish;
  return unless $listid;
  return sprintf ('L%05d', $listid);
}

sub dbsearchgroup {
  my ($self, $pattern) = @_;
  my $db = $self->{groupsdb};
  my $sql = qq{
    select *
      from $groupstable
     where name rlike ?
     order by name
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dbsearchgroup : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $pattern);
  unless ($rv) {
    $self->{errmsg} = "dbfindgroup : $db->{errmsg}";
    return;
  }
  my @groups;
  while (my $group = $sth->fetchrow_hashref) {
    push (@groups, $group);
  }
  $sth->finish;
  $self->fixgroups (@groups);
  return @groups unless $doautolists;

  my $sql = qq{
    select id, type, subtype, unite
      from dinfo.autolistes
     where concat(subtype,'.',unite) rlike ?
     order by type, subtype, unite
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dbsearchgroup : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $pattern);
  unless ($rv) {
    $self->{errmsg} = "dbsearchgroup : $db->{errmsg}";
    return;
  }
  my @autogroups;
  while (my ($id, $type, $subtype, $unite) = $sth->fetchrow) {
    my $description = getautogroupdescription ($type, $subtype, $unite);
    $id = sprintf ('L%05d', $id);
    push (@autogroups, {
               id => $id,
             type => "autogroup",
             name => "$subtype.$unite",
          display => "$subtype.$unite",
      description => $description,
          visible => 1,
           access => 'o',
    });
  }
  $sth->finish;
  return (@groups, @autogroups);
}

sub dbmatchgroup {
  my ($self, $patterns) = @_;
  my $db = $self->{groupsdb};
  my @fields = $self->dblistfields ($groupstable);
  my $fields = { map { $_, 1 } @fields };
  my (@rlikes, @values);
  foreach my $attr (keys %$patterns) {
    next unless $fields->{$attr};
    my $pattern = $patterns->{$attr};
    push (@rlikes, "$attr rlike ?");
    push (@values, $pattern);
  }
  my $rlikes = join (' and ', @rlikes);
  unless ($rlikes) {
    $self->{errmsg} = "dbmatchgroup : No pattern given.";
    return;
  }
  my $sql = qq{
    select *
      from $groupstable
     where $rlikes
     order by name
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dbmatchgroup : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, @values);
  unless ($rv) {
    $self->{errmsg} = "dbfindgroup : $db->{errmsg}";
    return;
  }
  my @groups;
  while (my $group = $sth->fetchrow_hashref) {
    $self->fixgroup ($group);
    push (@groups, $group);
  }
  $sth->finish;
  return @groups;
}

sub fixgroup {
  my ($self, $group) = @_;
  return unless $group;
  $group->{display}  = $group->{name};
  $group->{type}     = 'group';
  $group->{visible}  = $group->{visible}  eq 'n' ? 0 : 1;
  $group->{maillist} = $group->{maillist} eq 'n' ? 0 : 1;
  $group->{visilist} = $group->{visilist} eq 'n' ? 0 : 1;
  $group->{listext}  = $group->{listext}  eq 'n' ? 0 : 1;
  $group->{ldap}     = $group->{ldap}     eq 'n' ? 0 : 1;
  $group->{public}   = $group->{public}   eq 'n' ? 0 : 1;
}

sub fixgroups {
  my ($self, @groups) = @_;
  return unless @groups;
  foreach my $group (@groups) {
    $group->{display}  = $group->{name};
    $group->{type}     = 'group';
    $group->{visible}  = $group->{visible}  eq 'n' ? 0 : 1;
    $group->{maillist} = $group->{maillist} eq 'n' ? 0 : 1;
    $group->{visilist} = $group->{visilist} eq 'n' ? 0 : 1;
    $group->{listext}  = $group->{listext}  eq 'n' ? 0 : 1;
    $group->{ldap}     = $group->{ldap}     eq 'n' ? 0 : 1;
    $group->{public}   = $group->{public}   eq 'n' ? 0 : 1;
  }
}

sub dbloadgroup {
  my ($self, $groupid) = @_;
  if ($groupid =~ /^L\d*$/) {
    return $self->dbloadautogroup ($groupid);
  }
  local @seen = ();
  my $group = $self->dbloadgrouprec ($groupid);
  return $group;
}

sub dbloadgrouprec {
  my ($self, $groupid) = @_;
  if (grep (/$groupid/, @seen)) { # Avoid looping.
    warn "Groups:dbloadgrouprec:loop detected : stack = @seen\n";
    return;
  }
  push (@seen, $groupid);

  my $group = $self->dbloadgroupdata ($groupid);
  return unless $group;
  my $status = $self->dbloadgroupmembers ($group);
  return unless $status;
  my $status = $self->dbloadgroupadmins ($group);
  return unless $status;
  warn "Groups:dbloadgrouprec:bad stack\n" unless ($seen[-1] eq $groupid);
  pop @seen;
  return $group;
}

sub dbloadgroupdata {
  my ($self, $groupid) = @_;
  return unless ($groupid =~ /^S\d*$/);
  my $db = $self->{groupsdb};
  my $sql = qq{
    select *
      from $groupstable
     where id = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dbloadgroupdata : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $groupid);
  unless ($rv) {
    $self->{errmsg} = "dbloadgroupdata : $db->{errmsg}";
    return;
  }
  my $group = $sth->fetchrow_hashref;
  $sth->finish;
  return unless $group;
  
  $group->{ownerinfo} = $self->dbgetpersoninfos ($group->{owner});
  $self->fixgroup ($group);
  return $group;
}

sub dbloadgroupmembers {
  my ($self, $group) = @_;
  my  $db = $self->{groupsdb};
  my $sql = qq{
    select member
      from $memberstable
     where groupid = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dbloadgroup : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $group->{id});
  unless ($rv) {
    $self->{errmsg} = "dbloadgroup : $db->{errmsg}";
    return;
  }
  my $memberids = $sth->fetchall_arrayref ([0]);
  my @memberids = map { $_->[0] } @$memberids;
  my (@members, @scipers, @persons, $persons);
  $sth->finish;
  foreach my $member (@memberids) {
    if ($member =~ /^[GAZM\d]\d\d\d\d\d$/) {
      push (@members, $member);
      push (@scipers, $member);
    }
    elsif ($member =~ /^S\d\d\d\d\d$/) {
      my $subgroup = $self->dbloadgrouprec ($member);
      unless ($subgroup) {
        warn "dbloadgroup : Unknown subgroup : $member\n";
        next;
      }
      foreach my $person (@{$subgroup->{persons}}) {
        $persons->{$person->{sciper}} = $person;
      }
      push (@members, $subgroup);
    }
    elsif ($member =~ /^U\d\d\d\d\d$/) {
      my $unit = $self->dbgetunitinfos ($member);
      unless ($unit) {
        warn "dbloadgroup : Unknown unit : $member\n";
        next;
      }
      $unit->{persons} = $self->dbgetunitpersons ($member);
      foreach my $person (@{$unit->{persons}}) {
        $persons->{$person->{sciper}} = $person;
      }
      push (@members, $unit);
    }
    elsif ($member =~ /^L\d\d\d\d\d$/) {
      my $list = $self->dbloadautogroup ($member);
      unless ($list) {
        warn "dbloadgroup : Unknown group : $member\n";
        next;
      }
      foreach my $person (@{$list->{persons}}) {
        $persons->{$person->{sciper}} = $person;
      }
      push (@members, $list);
    }
    elsif ($member =~ /^Q\d\d\d\d\d$/) {
      my $query = $self->dbgetquery ($member);
      unless ($query) {
        warn "dbloadgroup : Unknown query : $member\n";
        next;
      }
      my $result = $self->dbexecutequery ($query);
      foreach my $person (@{$result->{persons}}) { # Only people yet...
        $persons->{$person->{sciper}} = $person;
      }
      push (@members, $result);
    }
  }

  my $personinfos = $self->dbgetpersonsinfos (@scipers);
  my @newmembers;
  foreach my $member (@members) {
    if ($member !~ /^[GMZ\d]\d\d\d\d\d$/) {
      push (@newmembers, $member);
      next;
    }
    next unless $personinfos->{$member};
    $persons->{$member} = $personinfos->{$member};
    push (@newmembers, $persons->{$member});
  }
  @members = @newmembers;

  my $sql = qq{
    select member
      from $excludedtable
     where groupid = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dbloadgroup : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $group->{id});
  unless ($rv) {
    $self->{errmsg} = "dbloadgroup : $db->{errmsg}";
    return;
  }
  my $excludeids = $sth->fetchall_arrayref ([0]);
  my @excludeids = map { $_->[0] } @$excludeids;
  $sth->finish;
  my (@excluded, $excluded);
  if (@excludeids) {
    foreach my $exclude (@excludeids) {
      if ($exclude =~ /^[GAZM\d]\d\d\d\d\d$/) {
        my $person = $self->dbgetpersoninfos ($exclude);
        unless ($person) {
          warn "dbloadgroup : Unknown excluded sciper : $exclude\n";
          next;
        }
        $excluded->{$exclude} = $person;
        delete $persons->{$exclude};
      }
      elsif ($exclude =~ /^S\d\d\d\d\d$/) {
        my $excludegroup = $self->dbloadgrouprec ($exclude);
        unless ($excludegroup) {
          warn "dbloadgroup : Unknown group : $exclude\n";
          next;
        }
        $excluded->{$exclude} = $excludegroup;
        foreach my $person (@{$excludegroup->{persons}}) {
          delete $persons->{$person->{id}};
        }
      }
    }
    foreach my $sciper (
      sort {
        $excluded->{$a}->{display} cmp $excluded->{$b}->{display}
      } keys %$excluded) {
      push (@excluded, $excluded->{$sciper});
    }
    my $excludedid = $group->{id};
    $excludedid =~ s/^S/E/;
    my $excludedgroup = {
           id => $excludedid,
         type => 'excluded',
      display => 'Personnes exclues',
      members => \@excluded,
      persons => \@excluded,
    };
    push (@members, $excludedgroup);
  }
  foreach my $sciper (
    sort {
      $persons->{$a}->{display} cmp $persons->{$b}->{display}
    } keys %$persons) {
    next if $excluded->{$sciper};
    push (@persons, $persons->{$sciper});
  }
  $group->{members}    = \@members;
  $group->{persons}    = \@persons;
  $group->{excluded}   = \@excluded if @excluded;
  return 1;
}

sub dbloadgroupadmins {
  my ($self, $group) = @_;
  my ($admins, $persadmins) = $self->dblistadmins ($group->{id});
  $group->{admins}     = $admins;
  $group->{persadmins} = $persadmins;
}

sub dbloadautogroup {
  my ($self, $groupid) = @_;
  return unless ($groupid =~ /^L0*(\d*)$/);
  my $group = $self->dbloadautogroupdata ($groupid);
  return unless $group;
  my $status = $self->dbloadautogroupmembers ($group);
  return unless $status;
  return $group;
}

sub dbloadautogroupdata {
  my ($self, $groupid) = @_;
  return unless ($groupid =~ /^L0*(\d*)$/);
  my $listid = $1;
  my  $db = $self->{groupsdb};
  my $sql = qq{
    select id, type, subtype, unite
      from dinfo.autolistes
     where id = ?
  };
  my     $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dbloadautogroup : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $listid);
  unless ($rv) {
    $self->{errmsg} = "dbloadautogroup : $db->{errmsg}";
    return;
  }
  my ($id, $type, $subtype, $unite) = $sth->fetchrow;
  my $description = getautogroupdescription ($type, $subtype, $unite);
  my $group = {
             id => $groupid,
           type => "autogroup",
           name => "$subtype.$unite",
        display => $description,
    description => $description,
        visible => 1,
         access => 'o',
   registration => 'f',
    mailinglist => 1,
           ldap => 1,
           gid  => -1,
       creation => 0,
  };
  return $group;
}

sub dbloadautogroupmembers {
  my ($self, $group) = @_;
  return unless ($group->{id} =~ /^L0*(\d*)$/);
  my $listid = $1;
  my  $db = $self->{groupsdb};
  my $sql = qq{
    select sciper
      from dinfo.autolistesmembres
     where id = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dbloadautogroup : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $listid);
  unless ($rv) {
    $self->{errmsg} = "dbloadautogroup : $db->{errmsg}";
    return;
  }
  my $scipers = $sth->fetchall_arrayref ([0]);
  my @scipers = map { $_->[0] } @$scipers;
  my $members = $self->dbgetpersonsinfos (@scipers);
  my @members;
  foreach my $sciper (
    sort {
      $members->{a}->{display} cmp $members->{b}->{display}
    } keys %$members) {
    push (@members, $members->{$sciper});
  }
  $group->{members} = \@members;
  $group->{persons} = \@members;
  return 1;
}

sub dblistmembers {
  my ($self, $groupid) = @_;
  my  $db = $self->{groupsdb};
  my $sql = qq{
    select member
      from $memberstable
     where groupid = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dblistmembers : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $groupid);
  unless ($rv) {
    $self->{errmsg} = "dblistmembers : $db->{errmsg}";
    return;
  }
  my $memberids = $sth->fetchall_arrayref ([0]);
  my @memberids = map { $_->[0] } @$memberids;
  my (@persons, @groups, @units, @queries, @lists);
  $sth->finish;
  foreach my $member (@memberids) {
    if ($member =~ /^[GAZM\d]\d\d\d\d\d$/) {
      push (@persons, $member);
    }
    elsif ($member =~ /^S\d\d\d\d\d$/) {
      push (@groups, $member);
    }
    elsif ($member =~ /^U\d\d\d\d\d$/) {
      push (@units, $member);
    }
    elsif ($member =~ /^L\d\d\d\d\d$/) {
      push (@lists, $member);
    }
    elsif ($member =~ /^Q\d\d\d\d\d$/) {
      push (@queries, $member);
    }
  }

  my @members;
  my $persinfos = $self->dbgetpersonsinfos (@persons);
  foreach my $id (keys %$persinfos) {
    my $person = $persinfos->{$id};
    next unless $person;
    push (@members, {
         type => $person->{type},
           id => $person->{id},
      display => $person->{display},
        email => $person->{email},
    });
  }
  foreach my $id (@groups) {
    my $group = $self->dbloadgroupdata ($id);
    next unless $group;
    push (@members, {
              type => $group->{type},
                id => $group->{id},
           display => $group->{display},
      memberscount => $group->{memberscount},
      personscount => $group->{personscount},
    });
  }
  foreach my $id (@units) {
    my $unit = $self->dbgetunitinfos ($id);
    next unless $unit;
    push (@members, {
         type => $unit->{type},
           id => $unit->{id},
      display => $unit->{display},
    });
  }
  foreach my $id (@lists) {
    my $list = $self->dbloadautogroup ($id);
    next unless $list;
    push (@members, {
         type => $list->{type},
           id => $list->{id},
      display => $list->{display},
    });
  }
  foreach my $id (@queries) {
    my $query = $self->dbgetquery ($id);
    next unless $query;
    push (@members, {
         type => $query->{type},
           id => $query->{id},
      display => $query->{display},
    });
  }
  return @members;
}

sub dblistadmins {
  my ($self, $groupid) = @_;
  my  $db = $self->{groupsdb};
  my $sql = qq{
    select admin
      from $adminstable
     where groupid = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dblistadmins : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $groupid);
  unless ($rv) {
    $self->{errmsg} = "dblistadmins : $db->{errmsg}";
    return;
  }
  my $adminsid = $sth->fetchall_arrayref ([0]);
  my @adminsid = map { $_->[0] } @$adminsid;
  $sth->finish;
  my ($admins, $persadmins);
  foreach my $adminid (@adminsid) {
    if ($adminid =~ /^[GAZM\d]\d\d\d\d\d$/) {
      my $admin = $self->dbgetpersoninfos ($adminid);
      unless ($admin) {
        warn "dblistadmins : Unknown admin sciper : $adminid\n";
        next;
      }
      $admins->{$adminid} = {
           type => $admin->{type},
             id => $admin->{id},
        display => $admin->{display},
      };
      $persadmins->{$adminid} = $admin;
    }
    if ($adminid =~ /^S\d\d\d\d\d$/) {
      my $admin = $self->dbloadgroup ($adminid);
      unless ($admin) {
        warn "dblistadmins : Unknown group Id : $adminid\n";
        next;
      }
      $admins->{$adminid} = {
           type => $admin->{type},
             id => $admin->{id},
        display => $admin->{display},
      };
      my %persids = map { $_->{id}, $_ } @{$admin->{persons}};
      foreach my $id (keys %persids) {
        $persadmins->{$id} = $persids {$id};
      }
    }
  }
  my (@admins, @persadmins);
  foreach my $id (
    sort {
      $admins->{$a}->{display} cmp $admins->{$b}->{display}
    } keys %$admins) {
    push (@admins, $admins->{$id});
  }
  foreach my $id (
    sort {
      $persadmins->{$a}->{display} cmp $persadmins->{$b}->{display}
    } keys %$persadmins) {
    push (@persadmins, $persadmins->{$id});
  }
  return (\@admins, \@persadmins);
}

sub isadmin {
  my ($group, $id) = @_;
  return unless $id;
  return unless $group->{admins};
  my %persadminsids = map { $_->{id}, 1 } @{$group->{persadmins}};
  return $persadminsids {$id};
}

sub isowner {
  my ($group, $sciper) = @_;
  return unless $sciper;
  return ($group->{owner} eq $sciper);
}

sub ismember {
  my ($group, $sciper) = @_;
  return unless $sciper;
  return unless $group->{members};
  my @memberids = map { $_->{id} } @{$group->{members}};
  my $ret = grep (/^$sciper$/, @memberids);
  return $ret;
}

sub belongsto {
  my ($group, $sciper) = @_;
  return unless $sciper;
  return unless $group->{persons};
  my @persons = @{$group->{persons}};
  foreach my $person (@persons) {
    return 1 if ($sciper eq $person->{sciper});
  }
  return;
}

sub canseegroup {
  my ($self, $group) = @_;
  my $canseegroup = (
    $group->{visible}                  ||
    $self->{root}                      ||
    $self->{caller} eq $group->{owner} ||
    ismember ($group, $self->{caller}) ||
    isadmin  ($group, $self->{caller})
  );
  return $canseegroup;
}

sub canseemembers {
  my ($self, $group) = @_;
  my $access = $group->{access};
  return 1 if $self->{root};
  if ($access eq 'o') {
    return 1;
  }
  if ($access eq 'r') {
    return 1 if (
      isowner  ($group, $self->{caller}) ||
      isadmin  ($group, $self->{caller}) ||
      ismember ($group, $self->{caller})
    );
  }
  if ($access eq 'f') {
    return 1 if (
      isowner  ($group, $self->{caller}) ||
      isadmin  ($group, $self->{caller})
    );
  }
  return 0;
}

sub isdynamic {
  my $group = shift;
  return unless $group;
  my $dynamic;
  foreach my $member (@{$group->{members}}) {
    my $type = $member->{type};
    next if ($type eq 'person');
    next if ($type eq 'autogroup');
    if ($type eq 'group') {
      $dynamic = isdynamic ($member);
      last if $dynamic;
    }
    elsif ($type eq 'unit' || $type eq 'query') {
      $dynamic = 1;
      last;
    }
  }
  return $dynamic;
}

sub checkloop {
  my ($group, $subgroup) = @_;
  return 1 if ($group->{type} eq 'autogroup');
  return if ($group->{id} eq $subgroup->{id});
  my @members = @{$subgroup->{members}};
  foreach my $member (@members) {
    if ($member->{id} =~ /^S(\d\d\d\d\d)$/) {
      return unless checkloop ($group, $member);
    }
  }
  return 1;
}

sub updatemembers {
  my ($self, $group) = @_;
  return unless $group;
  my $groupid = $group->{id};
  return if ($groupid =~ /^L/);
  my  $db = $self->{groupsdb};

  #
  # Update external data.
  #
  Notifier::notify (
      event => 'setgroupmembers',
     author => $self->{caller},
         id => $groupid
  ) if $self->{notify};
  Lists::updateGroup ($group) if $group->{maillist};

  #
  # Update parents;
  #
  my $sql = qq{
    select groupid
      from $memberstable
     where member = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "updatemembers : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $group->{id});
  unless ($rv) {
    $self->{errmsg} = "updatemembers : $db->{errmsg}";
    next;
  }
  my $parentids = $sth->fetchall_arrayref ([0]);
  my @parentids = map { $_->[0] } @$parentids;
  foreach my $parentid (@parentids) {
    my $parent = $self->dbloadgroup ($parentid);
    $self->updatemembers ($parent);
  }
}

sub dblistgroupsuserbelongsto {
  my ($self, $who) = @_;
  my @groups = $self->dblistgroupsuserbelongstoactual ($who);
  return @groups unless $doautolists;

  my  $db = $self->{groupsdb};
  my $sql = qq{
    select dinfo.autolistes.id, type, subtype, unite
      from dinfo.autolistes, dinfo.autolistesmembres
     where dinfo.autolistesmembres.id = dinfo.autolistes.id
       and dinfo.autolistesmembres.sciper = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dblistgroupsuserbelongsto : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $who);
  unless ($rv) {
    $self->{errmsg} = "dblistgroupsuserbelongsto : $db->{errmsg}";
    next;
  }
  my @autogroups;
  while (my ($listid, $type, $subtype, $unite) = $sth->fetchrow) {
    my $description = getautogroupdescription ($type, $subtype, $unite);
    my     $groupid = sprintf ('L%05d', $listid);
    push (@autogroups,
      {
                 id => $groupid,
               type => 'autogroup',
               name => "$subtype.$unite",
            display => "$subtype.$unite",
        description => $description,
      }
    );
  }
  $sth->finish;
  @autogroups = sort { $a->{display} cmp $b->{display} } @autogroups;
  return (@groups, @autogroups);
}

sub dblistgroupsuserbelongstoactual {
  my ($self, $who) = @_;
  my  $db = $self->{groupsdb};
  my $sql = qq{
    select $groupstable.id
      from $groupstable, $memberstable
     where $groupstable.id = $memberstable.groupid
       and $memberstable.member = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dblistgroupsuserbelongstoactual : $db->{errmsg}";
    warn $self->{errmsg};
    return;
  }
  my $rv = $db->execute ($sth, $who);
  unless ($rv) {
    $self->{errmsg} = "dblistgroupsuserbelongstoactual : $db->{errmsg}";
    warn $self->{errmsg};
    return;
  }
  my @groups;
  while (my ($groupid) = $sth->fetchrow) {
    push (@groups, $groupid);
  }
  $sth->finish;
  
  my @units = $self->dblistunitssuserbelongsto ($who);
  my $ismember;
  foreach my $groupid (@groups, @units) {
    my @parentids = $self->listGroupParents ($groupid);
    map { $ismember->{$_} = 1; } @parentids;
  }
  my @ismember = grep (/^S/, keys %$ismember);

  my $in = join ("','", @ismember);
  my $sql = qq{
    select $groupstable.*
      from $groupstable
     where $groupstable.id in ('$in')
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dblistgroupsuserbelongstoactual : $db->{errmsg}";
    warn $self->{errmsg};
    return;
  }
  my $rv = $db->execute ($sth);
  unless ($rv) {
    $self->{errmsg} = "dblistgroupsuserbelongstoactual : $db->{errmsg}";
    warn $self->{errmsg};
    return;
  }
  my @groups;
  while (my $group = $sth->fetchrow_hashref) {
    push (@groups, $group);
  }
  $sth->finish;

  $self->fixgroups (@groups);
  return @groups;
}


sub listGroupParents {
  my ($self, $groupid) = @_;
  my $ancestors = $self->listGroupParents_rec ($groupid);
  $ancestors->{$groupid} = 1;
  return keys %$ancestors;
}

sub listGroupParents_rec {
  my ($self, $groupid) = @_;
  my  $db = $self->{groupsdb};
  my $sql = qq{
    select $memberstable.groupid
      from $memberstable
     where $memberstable.member = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) { $self->{errmsg} = "listGroupParents : $db->{errmsg}"; return; }
  my $rv = $db->execute ($sth, $groupid);
  unless  ($rv) { $self->{errmsg} = "listGroupParents : $db->{errmsg}"; return; }

  my $ancestors;
  while (my ($id) = $sth->fetchrow) {
    $ancestors->{$id} = 1;
    my $ancs = $self->listGroupParents_rec ($id);
    map {  $ancestors->{$_} = 1; } keys %$ancs;
  }
  $sth->finish;
  return $ancestors;
}

sub dblistunitssuserbelongsto {
  my ($self, $who) = @_;
  my  $db = $self->{groupsdb};
  my $sql = qq{
    select dinfo.allunits.level1,
           dinfo.allunits.level2,
           dinfo.allunits.level3,
           dinfo.allunits.level4
      from accred.accreds
      join dinfo.allunits on dinfo.allunits.id_unite = accreds.unitid
     where accreds.persid = ?
       and accreds.debval < now()
       and (accreds.finval is null or accreds.finval > now())
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dblistunitssuserbelongsto : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $who);
  unless ($rv) {
    $self->{errmsg} = "dblistunitssuserbelongsto : $db->{errmsg}";
    return;
  }
  my $allunits;
  while (my @units = $sth->fetchrow) {
    map { $allunits->{"U$_"} = 1 } @units;
  }
  $sth->finish;
  return keys %$allunits;
}

sub dblistgroupsuserisadmin {
  my ($self, $sciper) = @_;
  my $db = $self->{groupsdb};

  my    @groupsofuser = $self->dblistgroupsuserbelongsto ($sciper);
  my @groupsofuserids = map { $_->{id} } @groupsofuser;
  my   @questionmarks = map { '?' } @groupsofuser;
  my $in = join (',', '?', @questionmarks);
  my $sql = qq{
    select $groupstable.*
      from $groupstable, $adminstable
     where $groupstable.id = $adminstable.groupid
       and $adminstable.admin in ($in)
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dblistgroupsuserisadmin : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $sciper, @groupsofuserids);
  unless ($rv) {
    $self->{errmsg} = "dblistgroupsuserisadmin : $db->{errmsg}";
    next;
  }
  my @groups;
  while (my $group = $sth->fetchrow_hashref) {
    push (@groups, $group);
  }
  $sth->finish;
  $self->fixgroups (@groups);
  return @groups;
}


sub dbgetpersoninfos {
  my ($self, $sciper) = @_;
  my ($name, $firstname, $username, $type, $email, $org, $display);
  my $db = $self->{groupsdb};
  if ($sciper =~ /^\d\d\d\d\d\d$/) {
    my $sql = qq{
                 select dinfo.sciper.nom_acc      as nameacc,
                        dinfo.sciper.prenom_acc   as firstnameacc,
                        dinfo.sciper.nom_usuel    as name,
                        dinfo.sciper.prenom_usuel as firstname,
                        dinfo.accounts.user       as username,
                        dinfo.emails.addrlog      as email
                   from dinfo.sciper
        left outer join dinfo.accounts
                     on dinfo.sciper.sciper = dinfo.accounts.sciper
        left outer join dinfo.emails
                     on dinfo.sciper.sciper = dinfo.emails.sciper
                  where dinfo.sciper.sciper = ?
    };
    my $sth = $db->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "dbgetpersoninfos : $db->{errmsg}";
     return;
    }
    my $rv = $db->execute ($sth, $sciper);
    unless ($rv) {
      $self->{errmsg} = "dbgetpersoninfos : $db->{errmsg}";
      next;
    }
    my ($nameacc, $firstnameacc);
    ($nameacc, $firstnameacc, $name, $firstname, $username, $email) = $sth->fetchrow;
    return unless $nameacc;
    $name      ||= $nameacc;
    $firstname ||= $firstnameacc;
    $type    = 'person';
    $display = "$name $firstname";
    $sth->finish;
  }
  elsif ($sciper =~ /^G\d\d\d\d\d$/) {
    my $sql = qq{select accred.guests.name      as name,
                        accred.guests.firstname as firstname,
                        accred.guests.email     as username
                   from accred.guests
                  where accred.guests.sciper = ?
    };
    my $sth = $db->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "dbgetpersoninfos : $db->{errmsg}";
     return;
    }
    my $rv = $db->execute ($sth, $sciper);
    unless ($rv) {
      $self->{errmsg} = "dbgetpersoninfos : $db->{errmsg}";
      return;
    }
    ($name, $firstname, $username) = $sth->fetchrow;
    return unless $name;
    $type    = 'person';
    $email   = $username;
    $display = "Guest: $name $firstname";
    $sth->finish;
  }
  elsif ($sciper =~ /^Z\d\d\d\d\d$/) {
    my $sql = qq{
      select dinfo.SwitchAAIUsers.name,
             dinfo.SwitchAAIUsers.firstname,
             dinfo.SwitchAAIUsers.username,
             dinfo.SwitchAAIUsers.email,
             dinfo.SwitchAAIUsers.org
        from dinfo.SwitchAAIUsers
        where dinfo.SwitchAAIUsers.sciper = ?
    };
    my $sth = $db->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "dbgetpersoninfos : $db->{errmsg}";
     return;
    }
    my $rv = $db->execute ($sth, $sciper);
    unless ($rv) {
      $self->{errmsg} = "dbgetpersoninfos : $db->{errmsg}";
      return;
    }
    ($name, $firstname, $username, $email, $org) = $sth->fetchrow;
    return unless $name;
    $type    = 'person';
    $display = "AAI:$org: $name $firstname";
    $sth->finish;
  }
  elsif ($sciper =~ /^M\d\d\d\d\d$/) {
    (my $id = $sciper) =~ s/^M0*//;
    my $sql = qq{
      select dinfo.services.id,
             dinfo.services.name
        from dinfo.services
       where dinfo.services.id = ?
    };
    my $sth = $db->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "dbgetpersoninfos : $db->{errmsg}";
      return;
    }
    my $rv = $db->execute ($sth, $id);
    unless ($rv) {
      $self->{errmsg} = "dbgetpersoninfos : $db->{errmsg}";
      return;
    }
    my ($id, $name) = $sth->fetchrow;
    return unless $name;
    $type     = 'service';
    $email    = "$name\@epfl.ch";
    $display  = "Service:$name";
    $username = $name;
    $sth->finish;
  }
  Encode::_utf8_on ($display);
  my $person = {
           id => $sciper,
         type => $type,
       sciper => $sciper,
         name => $name,
    firstname => $firstname,
      display => $display,
     username => $username,
        email => $email,
  };
  return $person;
}

sub dbgetpersonsinfos {
  my ($self, @scipers) = @_;
  my     @epfl = grep (/^\d\d\d\d\d\d/, @scipers);
  my   @guests = grep ( /^G\d\d\d\d\d/, @scipers);
  my     @aais = grep ( /^Z\d\d\d\d\d/, @scipers);
  my @services = grep ( /^M\d\d\d\d\d/, @scipers);
  my $persons;

  my $db = $self->{groupsdb};
  if (@epfl) {
    my $in = join (', ', map { '?' } @epfl);
    my $sql = qq{select dinfo.sciper.sciper,
                        dinfo.sciper.nom_acc      as nameacc,
                        dinfo.sciper.prenom_acc   as firstnameacc,
                        dinfo.sciper.nom_usuel    as name,
                        dinfo.sciper.prenom_usuel as firstname,
                        dinfo.accounts.user       as username,
                        dinfo.emails.addrlog      as email
                   from dinfo.sciper
        left outer join dinfo.accounts
                     on dinfo.sciper.sciper = dinfo.accounts.sciper
        left outer join dinfo.emails
                     on dinfo.sciper.sciper = dinfo.emails.sciper
                  where dinfo.sciper.sciper in ($in)
    };
    my $sth = $db->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "dbgetpersonsinfos : $db->{errmsg}";
      return;
    }
    my $rv = $db->execute ($sth, @epfl);
    unless ($rv) {
      $self->{errmsg} = "dbgetpersoninfos : $db->{errmsg}";
      return;
    }
    while (my ($sciper, $nameacc, $firstnameacc,
               $name, $firstname, $username, $email) = $sth->fetchrow) {
      next unless $nameacc;
      $name      ||= $nameacc;
      $firstname ||= $firstnameacc;
      my $display = "$name $firstname";
      Encode::_utf8_on ($display);
      my $person = {
              id => $sciper,
            type => 'person',
          sciper => $sciper,
         display => $display,
        username => $username,
           email => $email,
      };
      $persons->{$sciper} = $person;
    }
    $sth->finish;
  }
  if (@guests) {
    my $in = join (', ', map { '?' } @guests);
    my $sql = qq{
      select accred.guests.sciper    as sciper,
             accred.guests.name      as name,
             accred.guests.firstname as firstname,
             accred.guests.email     as username
        from accred.guests
       where accred.guests.sciper in ($in)
    };
    my $sth = $db->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "dbgetpersonsinfos : $db->{errmsg}";
      return;
    }
    my $rv = $db->execute ($sth, @guests);
    unless ($rv) {
      $self->{errmsg} = "dbgetpersoninfos : $db->{errmsg}";
      return;
    }
    while (my ($sciper, $name, $firstname, $username) = $sth->fetchrow) {
      next unless $name;
      my $display = "Guest: $name $firstname";
      Encode::_utf8_on ($display);
      my $person = {
              id => $sciper,
            type => 'person',
          sciper => $sciper,
         display => $display,
        username => $username,
           email => $username,
      };
      $persons->{$sciper} = $person;
    }
    $sth->finish;
  }
  if (@aais) {
    my $in = join (', ', map { '?' } @aais);
    my $sql = qq{
      select dinfo.SwitchAAIUsers.sciper,
             dinfo.SwitchAAIUsers.name,
             dinfo.SwitchAAIUsers.firstname,
             dinfo.SwitchAAIUsers.username,
             dinfo.SwitchAAIUsers.email,
             dinfo.SwitchAAIUsers.org
        from dinfo.SwitchAAIUsers
       where dinfo.SwitchAAIUsers.sciper in ($in)
    };
    my $sth = $db->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "dbgetpersonsinfos : $db->{errmsg}";
      return;
    }
    my $rv = $db->execute ($sth, @aais);
    unless ($rv) {
      $self->{errmsg} = "dbgetpersoninfos : $db->{errmsg}";
      return;
    }
    while (my ($sciper, $name, $firstname, $username, $email, $org) = $sth->fetchrow) {
      next unless $name;
      my $person = {
              id => $sciper,
            type => 'person',
          sciper => $sciper,
         display => "AAI:$org: $name $firstname",
        username => $username,
           email => $email,
      };
      $persons->{$sciper} = $person;
    }
    $sth->finish;
  }
  if (@services) {
    map { s/^M0*//; } @services;
    my $in = join (', ', map { '?' } @services);
    my $sql = qq{
      select dinfo.services.id,
             dinfo.services.name
        from dinfo.services
       where dinfo.services.id in ($in)
    };
    my $sth = $db->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "dbgetpersonsinfos : $db->{errmsg}";
      return;
    }
    my $rv = $db->execute ($sth, @services);
    unless ($rv) {
      $self->{errmsg} = "dbgetpersoninfos : $db->{errmsg}";
      return;
    }
    while (my ($id, $name) = $sth->fetchrow) {
      next unless $name;
      my $sciper = sprintf ('M%05d', $id);
      my $person = {
              id => $sciper,
            type => 'service',
          sciper => $sciper,
         display => "Service:$name",
        username => $name,
           email => "$name\@epfl.ch",
      };
      $persons->{$sciper} = $person;
    }
    $sth->finish;
  }
  return $persons;
}

sub dbgetserviceinfos {
  my ($self, $id) = @_;
  return unless ($id =~ /^M\d\d\d\d\d$/);
  (my $numid = $id) =~ s/^M0*//;
  my  $db = $self->{groupsdb};
  my $sql = qq{
    select dinfo.services.*
      from dinfo.services
     where dinfo.services.id = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dbgetserviceinfos : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $numid);
  unless ($rv) {
    $self->{errmsg} = "dbgetserviceinfos : $db->{errmsg}";
    return;
  }
  my $service = $sth->fetchrow_hashref;
  return unless $service->{name};
  $sth->finish;
  return {
            id => $id,
          type => 'service',
       display => "Service: $service->{name}",
      username => $service->{name},
         email => $service->{email},
  };
}

sub dbexecutequery {
  my ($self, $query) = @_;
  my  $db = $self->{groupsdb};
  my $sql = $query->{query};
  my $sth = $db->query ($sql);
  unless ($sth) {
    $self->{errmsg} = "dbexecutequery : $db->{errmsg}";
    return;
  }
  my @persons;
  my $scipers = $sth->fetchall_arrayref ([0]);
  my @scipers = map { $_->[0] } @$scipers;
  my $persons = $self->dbgetpersonsinfos (@scipers);
  foreach my $sciper (
    sort {
      $persons->{$a}->{display} cmp $persons->{$b}->{display}
    } @scipers) {
    push (@persons, $persons->{$sciper});
  }
  $sth->finish;
  my $result = {
         id => $query->{id},
       type => 'query',
    display => $query->{label},
    persons => \@persons,
  };
  return $result;
}

sub dbgetquery {
  my ($self, $queryid) = @_;
  my  $db = $self->{groupsdb};
  my $sql = qq{
    select *
      from $queriestable
     where id = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dbgetquery : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $queryid);
  unless ($rv) {
    $self->{errmsg} = "dbgetquery : $db->{errmsg}";
    return;
  }
  my $query = $sth->fetchrow_hashref;
  $sth->finish;
  return $query;
}

sub dblistqueries {
  my ($self, $sciper) = @_;
  my  $db = $self->{groupsdb};
  my $sql = qq{
    select *
      from $queriestable
     where owner = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dblistqueries : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $sciper);
  unless ($rv) {
    $self->{errmsg} = "dblistqueries : $db->{errmsg}";
    return;
  }
  my @queries;
  while (my $query = $sth->fetchrow_hashref) {
    $query->{display} = $query->{label};
    push (@queries, $query);
  }
  $sth->finish;
  return @queries;
}

sub dbgetservice {
  my ($self, $servid) = @_;
  my $idserv = $servid;
  $idserv =~ s/^M0*//;
  my  $db = $self->{groupsdb};
  my $sql = qq{
    select *
      from dinfo.services
     where id = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dbgetservice : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $idserv);
  unless ($rv) {
    $self->{errmsg} = "dbgetservice : $db->{errmsg}";
    return;
  }
  my $service = $sth->fetchrow_hashref;
  return unless $service;
  $service->{type}    = 'service';
  $service->{id}      = $servid;
  $service->{display} = $service->{name};
  return $service;
}

sub dbgetunitinfos {
  my ($self, $unitid) = @_;
  my $idunite = $unitid;
  $idunite =~ s/^U0*//;
  my  $db = $self->{groupsdb};
  my $sql = qq{
    select *
      from dinfo.allunits
     where id_unite = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dbgetunitinfos : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $idunite);
  unless ($rv) {
    $self->{errmsg} = "dbgetunitinfos : $db->{errmsg}";
    return;
  }
  my $unit = $sth->fetchrow_hashref;
  return unless $unit;
  $unit->{type}    = 'unit';
  $unit->{id}      = $unitid;
  $unit->{display} = $unit->{sigle};
  return $unit;
}

sub dbgetunitpersons {
  my ($self, $unitid) = @_;
  (my $idunite = $unitid) =~ s/^U0*//;
  my  $db = $self->{groupsdb};
  my $sql = qq{
    select id_unite
      from dinfo.allunits
     where level1 = ?
        or level2 = ?
        or level3 = ?
        or level4 = ?
  };
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dbgetunitpersons : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth, $idunite, $idunite, $idunite, $idunite);
  unless ($rv) {
    $self->{errmsg} = "dbgetunitpersons : $db->{errmsg}";
    return;
  }
  my @unitids;
  while (my ($unitid) = $sth->fetchrow) {
    push (@unitids, $unitid);
  }
  return unless @unitids;
  my $in = join (',', @unitids);
  
  my $sql = qq{
    select accred.accreds.persid  as sciper,
           dinfo.sciper.nom_acc    as name,
           dinfo.sciper.prenom_acc as firstname,
           dinfo.accounts.user     as username,
           dinfo.emails.addrlog    as email
      from accred.accreds,
           dinfo.allunits,
           dinfo.sciper
       left outer join dinfo.accounts on dinfo.accounts.sciper = dinfo.sciper.sciper
       left outer join dinfo.emails   on   dinfo.emails.sciper = dinfo.sciper.sciper
      where  accred.accreds.unitid = dinfo.allunits.id_unite
        and  accred.accreds.persid = dinfo.sciper.sciper
        and dinfo.allunits.id_unite in ($in)
        and (accred.accreds.debval is null or accred.accreds.debval <= now())
        and (accred.accreds.finval is null or accred.accreds.finval  > now())
  };
  #$sql =~ s/[\t\n ]+/ /g; warn "dbgetunitpersons:sql = $sql\n";
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "dbgetunitpersons : $db->{errmsg}";
    return;
  }
  my $rv = $db->execute ($sth);
  unless ($rv) {
    $self->{errmsg} = "dbgetunitpersons : $db->{errmsg}";
    return;
  }
  my @persons;
  while (my ($sciper, $name, $firstname, $username, $email) = $sth->fetchrow) {
    my $display = "$name $firstname";
    Encode::_utf8_on ($display);
    push (@persons, {
           id => $sciper,
         type => 'person',
       sciper => $sciper,
      display => $display,
     username => $username,
        email => $email,
    });
  }
  return \@persons;
}

sub dbloadbadnames {
  my $self = shift;
  my  $db = $self->{groupsdb};
  my $sql = qq{select * from badnames};
  my $sth = $db->prepare ($sql);
  $sth->execute;
  unless ($sth) {
    $self->{errmsg} = "Groups::dbloadbadnames : $db->{errmsg}";
    return;
  }
  my $badnames;
  while (my $name = $sth->fetchrow) {
    $badnames->{$name} = 1;
  }
  return $badnames;
}

sub dblistfields {
  my ($self, $table) = @_;
  $table =~ s/^(.*)\.//;
  my  $db = $self->{groupsdb};
  my $sql = qq{listfields $table};
  my $sth = $db->prepare ($sql);
  $sth->execute;
  unless ($sth) {
    $self->{errmsg} = "Groups::dblistfields : $db->{errmsg}";
    return;
  }
  my $fields = $sth->{NAME};
  return @$fields;
}

sub allocGID {
  my $self = shift;
  my $MINGID = 60000;
  my  $db = $self->{groupsdb};
  my $sql = qq{select gid from $groupstable};
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "allocGID : $db->{errmsg}";
    return -1;
  }
  my $rv = $db->execute ($sth);
  unless ($rv) {
    $self->{errmsg} = "allocGID : $db->{errmsg}";
    return -1;
  }
  my $usedgids = $sth->fetchall_arrayref ([0]);
  my @usedgids = map { $_->[0] } @$usedgids;
  $sth->finish;
  my %usedgids = map { $_, 1 } @usedgids;

  for (my $gid = $MINGID;; $gid++) {
    return $gid unless $usedgids {$gid};
  }
}

sub log {
  my ($self, $opcode, $groupid, $new, $old) = @_;
  return unless $self->{logger};
  my $strings = {
           name => 1,
    description => 1,
  };
  my ($lognew, $logold);
  if ($old) {
    foreach my $key (keys %$old) {
      next unless exists $new->{$key};
      $logold->{$key} = $old->{$key};
      $logold->{$key} = Encode::decode ('iso-8859-1', $logold->{$key})
        if ($strings->{$key} && !$self->{utf8});
    }
  }
  foreach my $key (keys %$new) {
    next if ($old && !exists $old->{$key});
    $lognew->{$key} = $new->{$key};
    $lognew->{$key} = Encode::decode ('iso-8859-1', $lognew->{$key})
      if ($strings->{$key} && !$self->{utf8});
  }
  $self->{logger}->log ($self->{caller}, $opcode, $groupid, $lognew, $logold);
}

sub errmsg {
  my $self = shift;
  return $self->{errmsg};
}

sub initmessages {
  my $self = shift;
  $messages = {
    nosciper => {
      fr => "No sciper",
      en => "Pas de sciper",
    },
    invalidsciper => {
      fr => "Invalid sciper : %s",
      en => "Numéro sciper invalide : %s",
    },
    nocaller => {
      fr => "Pas d'appelant",
      en => "No caller",
    },
    nogroupname => {
      fr => "Pas de nom de groupe",
      en => "No group name",
    },
    invalidgroupname => {
      fr => "Nom de groupe invalide : %s",
      en => "Invalid group name : %s",
    },
    nogroupowner => {
      fr => "Pas de propriétaire de groupe",
      en => "No group owner",
    },
    invalidgroupowner => {
      fr => "Propriétaire de groupe invalide : %s",
      en => "Invalid group owner : %s",
    },
    unknowngroup => {
      fr => "Le groupe %s n'existe pas",
      en => "Group %s doesn't exist",
    },
    unknownobject => {
      fr => "L'objet %s n'existe pas",
      en => "Object %s doesn't exist",
    },
    groupalreadyexists => {
      fr => "Le groupe %s existe déjà",
      en => "Group %s already exists",
    },
    adddontown => {
      fr => "Accès interdit, vous pouvez seulement ajouter un groupe à votre nom",
      en => "Access denied, you can only add a group you own",
    },
    invalidaccess => {
      fr => "Chaîne d'accès invalide : %s",
      en => "Invalid access string : %s",
    },
    invalidregistration => {
      fr => "Chaîne d'enregistrement invalide : %s",
      en => "Invalid registration string : %s",
    },
    cannotremove => {
      fr => "Accès interdit, seul le propriétaire peut supprimer un groupe",
      en => "Access denied, only the owner can remove a group",
    },
    nooldgroupname => {
      fr => "Pas de nom de groupe à renommer",
      en => "No old group name",
    },
    nonewgroupname => {
      fr => "Pas de nouveau nom de groupe",
      en => "No new group name",
    },
    cannotrename => {
      fr => "Accès interdit, seul le propriétaire peut renommer un groupe",
      en => "Access denied, only the owner can rename a group",
    },
    cannotmodify => {
      fr => "Accès interdit, seul le propriétaire peut modifier un groupe",
      en => "Access denied, only the owner can modify a group",
    },
    nomidification => {
      fr => "Pas de modification",
      en => "No modification",
    },
    invalidmember => {
      fr => "Membre invalide : %s",
      en => "Invalid member : %s",
    },
    cannotaddmembers => {
      fr => "Accès interdit, seul le propriétaire et les administrateurs ".
            "peuvent ajouter des membres à un groupe",
      en => "Access denied, only the owner and admins can add members to a group",
    },
    alreadymember => {
      fr => "%s est déjà membre du groupe %s",
      en => "%s is already member of group %s",
    },
    notmember => {
      fr => "%s n'est pas membre du groupe %s",
      en => "%s is not member of group %s",
    },
    directmember => {
      fr => "%s est membre direct du groupe %s",
      en => "%s is direct member of group %s",
    },
    isancestor => {
      fr => "%s est un ancêtre du groupe %s",
      en => "%s is an ancestor of %s",
    },
    cannotremovemember => {
      fr => "Accès interdit, seul le propriétaire et les administrateurs ".
            "peuvent enlever un membre d'un un groupe",
      en => "Access denied, only the owner and admins can remove members from a group",
    },
    alreadyexcluded => {
      fr => "Ce membre est déjà exclu du groupe %s",
      en => "This member is already excluded from group %s",
    },
    cannotremovemember => {
      fr => "Accès interdit, seul le propriétaire et les administrateurs ".
            "peuvent exclure un membre d'un un groupe",
      en => "Access denied, only the owner and admins can exclude members from a group",
    },
    cannotchangeowner => {
      fr => "Accès interdit, seul le propriétaire peut changer le propriétaire d'un groupe",
      en => "Access denied, only the owner and admins can change the owner of a group",
    },
    cannotaddadmins => {
      fr => "Accès interdit, seul le propriétaire peut ajouter un administrateur ".
            "à un groupe",
      en => "Access denied, only the owner can add admins to a group",
    },
    cannotremoveadmins => {
      fr => "Accès interdit, seul le propriétaire peut supprimer un administrateur ".
            "d'un groupe",
      en => "Access denied, only the owner can remove admins to a group",
    },
    notadmin => {
      fr => "%s n'est pas administrateur du groupe %s",
      en => "%s is not admin of group %s",
    },
    alreadyadmin => {
      fr => "%s est déjà administrateur du groupe %s",
      en => "%s is already admin of group %s",
    },
    cannotreadquery => {
      fr => "Accès interdit, vous n'êtes pas autorisé à lire cette requête",
      en => "Access denied, you are not allowed to read this query",
    },
  };
}

sub error {
  my ($self, $sub, $msgcode, @args) = @_;
  my  $msghash = $messages->{$msgcode};
  my $language = $self->{language} || 'en';
  my  $message = $msghash->{$language};
  $self->{errmsg} = sprintf ("$sub : $message", @args);
  #warn "$self->{errmsg}\n";
}

sub getautogroupdescription {
  my ($type, $subtype, $unite) = @_;
  my $descriptions = {
       'batiments.batiment' => "Personnes dans le batiment %unite",
    'batiments.secretaires' => "Secrétaires dans le batiment %unite",
                  'classes' => "Personnes ayant la classe %subtype dans l'unité  %unite",
              'conseils.ae' => "Assemblée d'école",
          'conseils.ae-cat' => "Assemblée d'école corps administratif et technique",
         'conseils.ae-cens' => "Assemblée d'école corps enseignant",
         'conseils.ae-cint' => "Assemblée d'école corps intermédiaire",
          'conseils.ae-etu' => "Assemblée d'école corps étudiant",
     'conseils.conseil-cat' => "Conseil de faculté %unite corps administratif et technique",
    'conseils.conseil-cens' => "Conseil de faculté %unite corps enseignant",
    'conseils.conseil-cint' => "Conseil de faculté %unite corps intermédiaire",
     'conseils.conseil-etu' => "Conseil de faculté %unite corps étudiant",

 'corps.corps-administratif-technique' =>
   "Personnes du corps administratif et technique dans la faculté %unite",
              'corps.corps-enseignant' =>
   "Personnes du corps corps enseignant dans la faculté %unite",
           'corps.corps-intermediaire' =>
   "Personnes du corps intermédiaire dans la faculté %unite",
                'corps.corps-etudiant' =>
   "Personnes du corps étudiant dans la faculté %unite",

                           'droits' => "Personnes de l'unité %unite ayant le droit %subtype",
'enseignants.directeurs-these.epfl' => "Directeurs de thèse",
     'enseignants.directeurs-these' => "Directeurs de thèse dans l'unité %unite",
          'enseignants.enseignants' => "Enseignants dans l'unite %unite",

                       'doctorants' => "Doctorants %unite",
                        'etudiants' => "Etudiants section %unite",
                   'etudiants.epfl' => "Etudiants EPFL",
                    'etudiants-ba1' => "Etudiants bachelor 1er semestre section %unite",
                    'etudiants-ba2' => "Etudiants bachelor 2ème semestre section %unite",
                    'etudiants-ba3' => "Etudiants bachelor 3ème semestre section %unite",
                    'etudiants-ba4' => "Etudiants bachelor 4ème semestre section %unite",
                    'etudiants-ba5' => "Etudiants bachelor 5ème semestre section %unite",
                    'etudiants-ba6' => "Etudiants bachelor 6ème semestre section %unite",
 'etudiants-chimie-moleculaire-bio' => "Etudiants chimie moleculaire bio section %unite",
         'etudiants-cycle-bachelor' => "Etudiants cycle bachelor section %unite",
            'etudiants-echange-ete' => "Etudiants échange été section %unite",
          'etudiants-echange-hiver' => "Etudiants échange hiver section %unite",
    'etudiants-enseignement-chimie' => "Etudiants enseignement chimie",
  'etudiants-enseignement-physique' => "Etudiants enseignement physique",
                    'etudiants-ma1' => "Etudiants master 1er semestre section %unite",
                    'etudiants-ma2' => "Etudiants master 2ème semestre section %unite",
                    'etudiants-ma3' => "Etudiants master 3ème semestre section %unite",
                    'etudiants-ma4' => "Etudiants master 4ème semestre section %unite",
      'etudiants-projet-master-ete' => "Etudiants projet master été section %unite",
    'etudiants-projet-master-hiver' => "Etudiants projet master hiver section %unite",
              'etudiants-stage-ete' => "Etudiants stage été section %unite",
            'etudiants-stage-hiver' => "Etudiants stage hiver section %unite",
                       'postgrades' => "Etudiants section %unite",


                'corps-professoral' => "Corps professoral dans l'unité %unite",
                      'professeurs' => "Professeurs dans l'unité %unite",
 'professeurs-assistants-tenure-tr' => "Professeurs assistants tenure track dans l'unité %unite",
             'professeurs-associes' => "Professeurs associés dans l'unité %unite",
            'professeurs-boursiers' => "Professeurs boursiers FN dans l'unité %unite",
           'professeurs-ordinaires' => "Professeurs ordinaires dans l'unité %unite",
           'professeurs-titulaires' => "Professeurs titulaires dans l'unité %unite",

                     'responsables' => "Responsables de quelque chose.",
              'responsables-centre' => "Responsables de centre",
              'responsables-chaire' => "Responsables de chaire",
           'responsables-direction' => "Responsables de direction",
              'responsables-divers' => "Responsables de divers",
               'responsables-ecole' => "Responsables d'école",
 'responsables-entiteshotesdelepfl' => "Responsables d'EHE",
     'responsables-entitetechnique' => "Responsables d'entreprise technique",
  'responsables-entreprisessursite' => "Responsables d'entreprise sur site ",
             'responsables-faculte' => "Responsables de faculté",
           'responsables-fondation' => "Responsables de fondation",
              'responsables-groupe' => "Responsables de groupe",
            'responsables-institut' => "Responsables d'institut",
         'responsables-laboratoire' => "Responsables de laboratoire",
           'responsables-programme' => "Responsables de programme",
             'responsables-section' => "Responsables de section",
      'responsables-servicecentral' => "Responsables de service central",
      'responsables-servicegeneral' => "Responsables de service général",
  'responsables-visibiliteannuaire' => "responsables visibilité annuaire",
 'responsables-visibiliteorganigra' => "responsables visibilité organigramme",

                       'respaccred' => "Responsables accréditation dans l'unité %unite",
                        'respadmin' => "Responsables administratif dans l'unité %unite",
                         'respcomm' => "Responsables communication dans l'unité %unite",
                         'respinfo' => "Responsables informatique dans l'unité %unite",
                        'respinfra' => "Responsables infrastructure dans l'unité %unite",
                         'respsecu' => "Responsables sécurité dans l'unité %unite",

  };
  my $description =
      $descriptions->{$type} ||
      $descriptions->{$subtype} ||
      $descriptions->{"$type.$subtype"} ||
      $descriptions->{"$type.$subtype.$unite"};
  $unite   = uc $unite;
  $subtype = uc $subtype;
  if ($unite eq 'EPFL') {
    $description =~ s/ de l'unité.%unite/ de l'<b>EPFL<\/b>/;
    $description =~ s/ dans l'unité.*$//;
    $description =~ s/ dans le batiment.*$//;
    $description =~ s/ dans la section.*$//;
    $description =~ s/ dans la faculté.*$//;
  }
  $description =~ s/%subtype/<b>$subtype<\/b>/g;
  $description =~ s/%type/<b>$type<\/b>/g;
  $description =~ s/%unite/<b>$unite<\/b>/g;
  return $description;
}

my $freeid = qq{
  select n.id + 1
    from newgroups n left join newgroups n1 on n1.id = n.id + 1
   where n1.id is null
   limit 0, 1;
};


1;




