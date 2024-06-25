#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Services.pm
# Description:  
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Fri Sep  4 15:37:18 CEST 2009
# Revision:     
#
##############################################################################
#
#
use strict;
use lib qw(/opt/dinfo/lib/perl);
use Time::Local;
use MIME::Base64;
use Crypt::RC4;
use Cadi::CadiDB;
use Cadi::Accounts;
use Cadi::Notifier;
use Cadi::Groups;
use Cadi::Accreds;
use LWP::UserAgent;

package Cadi::Services;

my $MINUID = 900000;

use vars qw($errcode $errmsg);
my $bools = {
  tequila => 1,
     ldap => 1,
       ad => 1,
   radius => 1,
      sco => 1,
};
my $strict;

my $root = {
  105640 => 1,
    root => 1,
};

sub new { # Exported
  my $class = shift;
  my  $args = (@_ == 1) ? shift : { @_ } ;
  my $self = {
            caller => undef,
                db => undef,
              utf8 => undef,
            notify => 1,
            errmsg => undef,
           errcode => undef,
          language => 'fr',
             debug => 0,
           verbose => 0,
             trace => 0,
          tracesql => 0,
  };
  foreach my $arg (keys %$args) {
    $self->{$arg} = $args->{$arg};
  }
  bless $self, $class;
  warn "new Cadi::Services ()\n" if $self->{verbose};
  $self->{db} = new Cadi::CadiDB (
     dbname => 'services',
       utf8 => $self->{utf8},
      trace => $self->{trace},
    verbose => $self->{verbose},
  );
  return unless $self->{db};
  return $self;
}

sub getService {
  return getServiceInfos (@_);
}

sub getServiceInfos {
  my ($self, $nameorid, $getall) = @_;
  return $self->error ('noid') unless $nameorid;
  my $caller = $self->{caller};
  warn "$caller->getService ($nameorid)\n" if $self->{trace};
  
  my $service = $self->dbfindServices (
    nameorid => $nameorid,
      getall => $getall,
  );
  return unless $service;
  return $self->error ($self->('noaccess'))
    if ($strict && $caller ne $service->{owner} && !$root->{$caller});
  if ($root->{$caller}) {
    $service->{password} = uncryptpasswd ($service->{password});
  } else {
    delete $service->{password};
  }
  return $service;
}

sub listServicesOf {
  my ($self, $sciper) = @_;
  my $caller = $self->{caller};
  warn "$caller->listServicesOf ($sciper)\n" if $self->{trace};
  return $self->error ('noaccess')
    if ($strict && $caller ne $sciper && !$root->{$caller});
  my @services = $self->dbfindServices (owner => $sciper);
  return $self->error ('dberror', $self->{db}->{errmsg}) unless @services;
  foreach my $service (@services) {
    if ($root->{$caller}) {
      $service->{password} = uncryptpasswd ($service->{password});
    } else {
      delete $service->{password};
    }
  }
  return @services;
}

sub listServicesManagedBy {
  my ($self, $sciper) = @_;
  my $caller = $self->{caller};
  warn "$caller->listServicesInUnits ($sciper)\n" if $self->{trace};
  return $self->error ('noaccess') if ($strict && !$root->{$caller});

  my $Accreds = new Cadi::Accreds (
    caller => 'root',
  );
  my    @units = $Accreds->getUnitsWhereHasRole ($sciper, 'respinfo');
  return unless @units;
  my  @unitids = map { $_->{id} } @units;
  my @services = $self->dbfindServices (unit => \@unitids);
  return $self->error ('dberror', $self->{db}->{errmsg}) unless @services;
  foreach my $service (@services) {
    if ($root->{$caller}) {
      $service->{password} = uncryptpasswd ($service->{password});
    } else {
      delete $service->{password};
    }
  }
  return @services;
}

sub serviceIsManagedBy {
  my ($self, $service, $sciper) = @_;
  if (not ref $service) {
    my $srvname = $service;
    $service = $self->dbfindServices (nameorid => $srvname);
    unless ($service) {
      error ("serviceIsManagedBy: unknown service : $srvname.");
      return;
    }
  }
  return $self->error ('badcall') unless ($service && $service->{id});
  my $caller = $self->{caller};
  warn "$caller->serviceIsManagedBy ($service->{name}. $sciper)\n" if $self->{trace};
  return $self->error ('noaccess') if ($strict && !$root->{$caller});

  my  $Accreds = new Cadi::Accreds (
    caller => 'root',
  );
  my    @units = $Accreds->getUnitsWhereHasRole ($sciper, 'respinfo');
  my  %unitids = map { $_->{id_unite}, 1 } @units;
  return $unitids {$service->{unit}};
}

sub listAllServices {
  my ($self) = @_;
  my $caller = $self->{caller};
  warn "$caller->listAllServices\n" if $self->{trace};
  return $self->error ('noaccess')  if ($strict && !$root->{$caller});
  my @services = $self->dbfindServices ();
  return $self->error ('dberror', $self->{db}->{errmsg}) unless @services;
  foreach my $service (@services) {
    if ($root->{$caller}) {
      $service->{password} = uncryptpasswd ($service->{password});
    } else {
      delete $service->{password};
    }
  }
  return @services;
}

sub listOldServices {
  my ($self) = @_;
  my $caller = $self->{caller};
  warn "$caller->listOldServices\n" if $self->{trace};
  return $self->error ('noaccess')  if ($strict && !$root->{$caller});
  my @services = $self->dbfindServices (getold => 1);
  return $self->error ('dberror', $self->{db}->{errmsg}) unless @services;
  foreach my $service (@services) {
    if ($root->{$caller}) {
      $service->{password} = uncryptpasswd ($service->{password});
    } else {
      delete $service->{password};
    }
  }
  return @services;
}

sub findServices {
  my ($self, $name) = @_;
  my $caller = $self->{caller};
  warn "$caller->findServices ($name)\n" if $self->{trace};
  return $self->error ('noname') unless $name;
  my @allservices = $self->dbfindServices (name => $name);
  return $self->error ('dberror', $self->{db}->{errmsg}) unless @allservices;
  foreach my $service (@allservices) {
    if ($root->{$caller}) {
      $service->{password} = uncryptpasswd ($service->{password});
    } else {
      delete $service->{password};
    }
  }
  return @allservices if (!$strict || $root->{$caller});
  my @services;
  foreach my $service (@allservices) {
    push (@services, $service)
      if (!$strict || ($service->{owner} eq $caller && !$root->{$caller}));
  }
  return @services;
}

sub addService {
  my ($self, $service) = @_;
  my $caller = $self->{caller};
  return $self->error ('allfields')
    unless ($service->{name} && $service->{label} && $service->{description});
  warn "$caller->addService ($service->{name})\n" if $self->{trace};
  
  return $self->error ('badname', $service->{name})
    unless ($service->{name} =~ /^[a-z][a-z0-9-_\.]*$/i);
    
  return $self->error ('badname', $service->{name})
    if ($service->{name} =~ /^x-/i);
    
  return $self->error ('accountexists', $service->{name})
    if getAccount ($service->{name});

  if ($service->{email} && ($service->{email} ne 'Exchange')) {
    return $self->error ('bademail', $service->{email})
      unless ($service->{email} =~ /^[a-z0-9_.+=-]+\@([a-z0-9][a-z0-9_-]*\.)+[a-z]+/i);
  }
  return $self->error ('emailexists', $service->{name})
    unless $self->checkemail ($service);

  my $uinfo = new Cadi::Units ()->getUnitInfos ($service->{unit});
  return $self->error ('unknownunit') unless $uinfo;

  my @services = $self->dbfindServices (name => $service->{name});
  return $self->error ('srvalreadyexists', $service->{name}) if @services;
  
  unless ($self->checkpassword ($service)) {
     return $self->error ('badpassword', $service->{errmsg});
  }
  $service->{password} = cryptpasswd ($service->{password});

  $service->{ad} = 1;
  my $camiprorfid = '';
  if ($service->{camipro}) {
    if (!$service->{camiprorfid}) {
      $service->{camiprorfid} = $self->addincamipro ($service);
    }
    $camiprorfid = $service->{camiprorfid};
    if (length $camiprorfid == 16) {
      # Already in hexa, nothing to do.
    }
    elsif (length $camiprorfid == 20) {
      # Decimal ID..
      $camiprorfid = camiprodectohex ($camiprorfid);
    } else {
      return $self->error ('badrfid', $camiprorfid);
    }
  }
  return $self->error ('camrfidinuse', $service->{name})
    if ($camiprorfid && $self->camiproInUse ($service, $camiprorfid));

  my $sql = qq{insert into services set
           name = ?,
          label = ?,
       password = ?,
          owner = '$caller',
           unit = ?,
    description = ?,
        tequila = ?,
           ldap = ?,
             ad = ?,
         radius = ?,
            sco = ?,
            uid = ?,
            gid = ?,
          email = ?,
      camiproid = ?,
    camiprorfid = ?,
       lifetime = ?,
       creation = now(),
        removal = null
  };
  my  $db = $self->{db};
  return $self->error ('dberror', $Cadi::CadiDB::errmsg) unless $db;
  my $sth = $db->prepare ($sql);
  return $self->error ('dberror', $self->{db}->{errmsg}) unless $sth;
  my $rv = $db->execute (
    $sth,
    $service->{name},
    $service->{label},
    $service->{password},
    $service->{unit},
    $service->{description},
    $service->{tequila} ? 'y' : 'n',
    $service->{ldap}    ? 'y' : 'n',
    $service->{ad}      ? 'y' : 'n',
    $service->{radius}  ? 'y' : 'n',
    $service->{sco}     ? 'y' : 'n',
    -1,
    $service->{gid} || $uinfo->{gid} || -1,
    $service->{email},
    $service->{camiproid},
    $camiprorfid,
    $service->{lifetime},
  );
  return $self->error ('dberror', $self->{db}->{errmsg}) unless $rv;
  my $srvid = $sth->{mysql_insertid};
  
  my  $uid = $MINUID + $srvid; # $self->allocuid ();
  my $sql2 = qq{update services set uid = ? where id = $srvid};
  my $sth2 = $db->prepare ($sql2);
  my  $rv2 = $db->execute ($sth2, $uid);
  
  $self->logevent ('addservice', $srvid, $service->{name});
  my $service = $self->dbfindServices (id => $srvid);
  Notifier::notify (
     event => 'addservice',
    author => $caller,
        id => $srvid,
  ) if $self->{notify};
  $self->addingaspar ($service);
  $self->createemail ($service) if $service->{email};
  return $service;
}

sub updateService {
  my ($self, $service) = @_;
  return $self->error ('badcall') unless ($service && $service->{id});
  my $caller = $self->{caller};
  my @oldserv = $self->dbfindServices (id => $service->{id});
  return $self->error ('unknownsrv', $service->{id})
    unless (@oldserv && $oldserv [0]);
  my $oldserv = shift @oldserv;

  if ($service->{lifetime} < $oldserv->{lifetime}) {
    my $newlife = $service->{lifetime};
    my $renewed = $oldserv->{renewed} || $oldserv->{creation};
    $renewed =~ /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/;
    my ($yn, $mn, $dn, $hn, $Mn, $sn) = ($1, $2, $3, $4, $5, $6);
    my $renewtime = Time::Local::timelocal ($sn, $Mn, $hn, $dn, $mn - 1, $yn);

    my ($ye, $me, $de, $he, $Me, $se) = ($yn, $mn, $dn, $hn, $Mn, $sn);
    if    ($newlife ==   1) { $me += 1; if ($me > 12) { $me -= 12; $ye++; }}
    elsif ($newlife ==   2) { $me += 2; if ($me > 12) { $me -= 12; $ye++; }}
    elsif ($newlife ==   3) { $me += 3; if ($me > 12) { $me -= 12; $ye++; }}
    elsif ($newlife ==   6) { $me += 6; if ($me > 12) { $me -= 12; $ye++; }}
    elsif ($newlife ==  12) { $ye +=  1; }
    else { return $self->error ('badlifetime') }
    my $endtime = Time::Local::timelocal ($se, $Me, $he, $de, $me - 1, $ye);
    return $self->error ('badlifetime') if ($endtime < time);
  }
  if ($service->{camipro}) {
    if (!$oldserv->{camipro} && !$service->{camiprorfid}) {
      $service->{camiprorfid} = $self->addincamipro ($service);
    }
    my $camiprorfid = $service->{camiprorfid};
    if (length $camiprorfid == 16) {
      # Already in hexa, nothing to do.
    }
    elsif (length $camiprorfid == 20) {
      # Decimal ID..
      $camiprorfid = camiprodectohex ($camiprorfid);
    } else {
      return $self->error ('badrfid', $camiprorfid);
    }
    $service->{camiprorfid} = $camiprorfid;
  } else {
    $service->{camiprorfid} = '';
  }
  delete $service->{camipro};
  delete $oldserv->{camipro};
  my (@names, @values, $mods);
  foreach my $field (keys %$oldserv) {
    next if ($field =~ /^(id|owner|uid|creation|removal|renewed|reminded)$/);
    if ($field eq 'password') {
      next unless $service->{password};
      unless ($self->checkpassword ($service)) {
        return $self->error ('badpassword', $service->{errmsg});
      }
      $service->{password} = cryptpasswd ($service->{password});
      $self->addingaspar ($service);
    }
    if ($field eq 'gid') {
      if ($service->{gid}) {
        next if ($service->{gid} == $oldserv->{gid});
        my $Groups = new Cadi::Groups (caller => 'root');
        my @groups = $Groups->listGroupsOwnedBy ($caller);
        my $ok = 0;
        foreach my $group (@groups) {
          if ($group->{gid} == $service->{gid}) {
            $ok = 1;
            last;
          }
        }
        return $self->error ('notgroupowner', $service->{gid}) unless $ok;
      } else {
        my $uinfo = new Cadi::Units ()->getUnitInfos ($service->{unit});
        $service->{gid} = $uinfo ? ($uinfo->{gid} || -1) : -1;
      }
    }
    if ($field eq 'camiprorfid') {
      my $camiprorfid = $service->{camiprorfid};
      return $self->error ('camrfidinuse', $oldserv->{name})
        if ($camiprorfid && $self->camiproInUse ($oldserv, $camiprorfid));
    }
    if ($service->{$field} ne $oldserv->{$field}) {
      if ($field eq 'unit' && !$service->{gid}) {
        push (@names, 'gid');
        my $uinfo = new Cadi::Units ()->getUnitInfos ($service->{unit});
        my $value = $uinfo ? ($uinfo->{gid} || -1) : -1;
        push (@values, $value);
      }
      push (@names,  $field);
      my $value = $service->{$field};
      $value = $value ? 'y' : 'n' if $bools->{$field};
      push (@values, $value);
      $mods = 1;
    }
  }
  return $self->error ('nochange') unless $mods;

  my $set = join (', ', map { "$_ = ?" } @names);
  my $sql = qq{update services set $set where id = ?};
  my  $db = $self->{db};
  return $self->error ('dberror', $CadiDB::errmsg) unless $db;
  my $sth = $db->prepare ($sql);
  return $self->error ('dberror', $self->{db}->{errmsg}) unless $sth;
  my $rv = $db->execute ($sth, @values, $service->{id});
  return $self->error ('dberror', $self->{db}->{errmsg}) unless $rv;

  my $logstr = join (':', map { "$_:$oldserv->{$_}->$service->{$_}" } @names);
  $self->logevent ('modservice', $service->{id}, $logstr);
  Notifier::notify (
     event => 'updateservice',
    author => $caller,
        id => $service->{id},
  ) if $self->{notify};
  if ($service->{email} ne $oldserv->{email}) {
    if (!$oldserv->{email}) {
      $self->createemail ($service);
    }
    elsif (!$service->{email}) {
      $self->deleteemail ($service);
    } else {
      $self->changeemail ($service);
    }
  }
  return 1;
}

sub removeService {
  my ($self, $service) = @_;
  if (not ref $service) {
    my $srvname = $service;
    $service = $self->dbfindServices (nameorid => $srvname);
    unless ($service) {
      error ("removeService: unknown service : $srvname.");
      return;
    }
  }
  return $self->error ('badcall') unless ($service && $service->{id});
  my $caller = $self->{caller};
  my $sql = qq{update dinfo.services set removal = now() where id = ?};
  my  $db = $self->{db};
  return $self->error ('dberror', $CadiDB::errmsg) unless $db;
  my $sth = $db->prepare ($sql);
  return $self->error ('dberror', $self->{db}->{errmsg}) unless $sth;
  my $rv = $db->execute ($sth, $service->{id});
  return $self->error ('dberror', $self->{db}->{errmsg}) unless $rv;
  $self->logevent ("delservice", $service->{id});
  Notifier::notify (
     event => 'removeservice',
        id => $service->{id},
      name => $service->{name},
    author => $caller,
  ) if $self->{notify};
  $self->deleteemail ($service) if $service->{email};
  return 1;
}

sub revalService {
  my ($self, $service) = @_;
  if (not ref $service) {
    my $srvname = $service;
    $service = $self->dbfindServices (nameorid => $srvname);
    unless ($service) {
      error ("revalService: unknown service : $srvname.");
      return;
    }
  }
  return $self->error ('badcall') unless ($service && $service->{id});
  my $caller = $self->{caller};
  my $sql = qq{
    update services
       set renewed = now(),
           removal = null
     where id = ?
  };
  my  $db = $self->{db};
  return $self->error ('dberror', $CadiDB::errmsg) unless $db;
  my $sth = $db->prepare ($sql);
  return $self->error ('dberror', $self->{db}->{errmsg}) unless $sth;
  my $rv = $db->execute ($sth, $service->{id});
  return $self->error ('dberror', $self->{db}->{errmsg}) unless $rv;
  $self->logevent ("revalservice", $service->{id});
  Notifier::notify (
     event => 'updateservice',
    author => $caller,
        id => $service->{id},
  ) if $self->{notify};
  return 1;
}

sub undelService {
  my ($self, $service) = @_;
  if (not ref $service) {
    my $srvname = $service;
    $service = $self->dbfindServices (nameorid => $srvname);
    unless ($service) {
      error ("undelService: unknown service : $srvname.");
      return;
    }
  }
  return $self->error ('badcall') unless ($service && $service->{id});
  my $caller = $self->{caller};
  my $sql = qq{update services set removal = null, renewed = now() where id = ?};
  my  $db = $self->{db};
  return $self->error ('dberror', $CadiDB::errmsg) unless $db;
  my $sth = $db->prepare ($sql);
  return $self->error ('dberror', $self->{db}->{errmsg}) unless $sth;
  my $rv = $db->execute ($sth, $service->{id});
  return $self->error ('dberror', $self->{db}->{errmsg}) unless $rv;
  $self->logevent ("undelService", $service->{id});
  return 1;
}

sub dbfindServices {
  my ($self, %args) = @_;
  my (@fields, @values);
  foreach my $field (keys %args) {
    next if ($field =~ /^get(all|old)$/);
    my $value = $args {$field};
    next unless $value;
    if ($field eq 'nameorid') {
      if ($value =~ /^\d+$/) {
        $field = 'id';
      }
      elsif ($value =~ /^M\d+$/) {
        $field = 'id';
        $value =~ s/^M0*//;
      } else {
        $field = 'name';
      }
      push (@fields, "$field = ?");
      push (@values, $value);
    }
    elsif ($field eq 'unit') {
      my @units = (ref $value eq 'ARRAY') ? @$value : ($value);
      my   @ins = map { '?' } @units;
      my    $in = join (',', @ins);
      push (@fields, "unit in ($in)");
      push (@values, @units);
    } else {
      push (@fields, "$field = ?");
      push (@values, $value);
    }
  }
  my $sql =
    $args {getall} ? qq{select * from services where 1} :
    $args {getold} ? qq{select * from services where removal is not null} :
                     qq{select * from services where removal is null};
  $sql .= ' and ' . join (' and ', @fields) if @fields;
  $sql .= ' order by id';
  #warn "dbfindServices: sql = $sql\n";
  my  $db = $self->{db};         return unless $db;
  my $sth = $db->prepare ($sql); return unless $sth;
  my  $rv = $db->execute ($sth, @values);
  my @services;
  while (my $srv = $sth->fetchrow_hashref) {
    foreach (keys %$srv) {
      $srv->{$_} = $srv->{$_} eq 'y' if $bools->{$_};
    }
    $srv->{camipro} = $srv->{camiprorfid};
    push (@services, $srv);
  }
  return wantarray ? @services : $services [0];
}

sub addingaspar {
  my ($self, $service) = @_;
  warn "addingaspar ($service->{name})\n" if $self->{verbose};
  my $gaskey = 'BzIdpeUtw';
  my $gaspardb = new Cadi::CadiDB (
    dbname => 'gaspar',
      utf8 => $self->{utf8},
  );
  unless ($gaspardb) {
    $self->error ('nogaspar', $CadiDB::errmsg);
    return;
  }
  my $sql = qq{
    insert into new_accounts
       set     ts = now(),
           sciper = ?,
              msg = ?
    };
  my $sth = $gaspardb->prepare ($sql);
  unless ($sth) {
    $self->error ('nogaspar', $gaspardb->{errmsg});
    return;
  }
  my $pwd = uncryptpasswd ($service->{password});
  my $uid = sprintf ("M%05d", $service->{id});
  my $rc4 = new Crypt::RC4 ($gaskey);
  my $msg = MIME::Base64::encode_base64 ($rc4->RC4 ($pwd), '');
  my  $rv = $gaspardb->execute ($sth, $uid, $msg);
  unless ($rv) {
    $self->error ('nowritegaspar', $gaspardb->{errmsg});
    return;
  }
  return 1;
}

sub addincamipro {
  my ($self, $service) = @_;
  warn "addincamipro ($service->{name})\n" if $self->{verbose};
  return 1;
}

sub camiproInUse {
  my ($self, $service, $camiprorfid) = @_;
  my $sql = qq{
    select name
      from services
     where camiprorfid = ?
       and removal is null
  };
  my  $db = $self->{db};         return unless $db;
  my $sth = $db->prepare ($sql); return unless $sth;
  my  $rv = $db->execute ($sth, $camiprorfid);
  my ($name) = $sth->fetchrow;
  return 1 if ($name && ($name ne $service->{name}));
  return 0;
}

use Math::BigInt;
sub camiprohextodec {
  my $hexid = shift;
  return $hexid unless (length ($hexid) == 16);
  my @pairs = ($hexid =~ /^(..)(..)(..)(..)(..)(..)(..)(..)$/);
  my $hexid = new Math::BigInt ('0x' . join ('', reverse @pairs));
  my $decid = sprintf ("%020s", $hexid->bstr);
  return $decid;
}

sub camiprodectohex {
  my $decid = shift;
  return $decid unless (length ($decid) == 20);
  $decid = new Math::BigInt ($decid);
  my $hexstr = $decid->as_hex;
  my  @pairs = ($hexstr =~ /^0x(..)(..)(..)(..)(..)(..)(..)(..)$/);
  my  $hexid = join ('', reverse @pairs);
  return uc $hexid;
}

sub checkpassword {
  my ($self, $service) = @_;
  warn "checkpassword ($service->{name})\n" if $self->{verbose};
  my $lwp = new LWP::UserAgent;
  my $gas = "https://gaspar.epfl.ch/cgi-bin/chkpwd";
  my $pwd = escapeurl ($service->{password});
  my $url = "$gas?user=$service->{name}&pwd=$pwd";
  my $req = new HTTP::Request ('GET', $url);
  my $res = $lwp->request ($req);
  return 1 if ($res->code == 200);
  $service->{errmsg} = $res->message;
  return;
}

sub checkemail {
  my ($self, $service) = @_;
  warn "checkemail ($service->{name})\n" if $self->{verbose};
  my $url = "http://mailwww.epfl.ch/adresseService.cgi?check=$service->{name}";
  my $lwp = new LWP::UserAgent;
  my $req = new HTTP::Request ('GET', $url);
  my $res = $lwp->request ($req);
  my $status = $res->status_line;
  $status =~ s/^(\d+) .*$/$1/;
  return ($status < 400);
}

sub createemail {
  my ($self, $service) = @_;
  warn "createemail ($service->{name})\n" if $self->{verbose};
  my $uid = sprintf ("M%05d", $service->{id});
  my $url = "http://mailwww.epfl.ch/adresseService.cgi?service=$service->{name}";
  $url   .= "&id=$uid";
  $url   .= "&warn=$service->{owner}";
  $url   .= "&adresse=$service->{email}" unless ($service->{email} eq 'Exchange');
  my $lwp = new LWP::UserAgent;
  my $req = new HTTP::Request ('GET', $url);
  my $res = $lwp->request ($req);
  my $status = $res->status_line;
  $status =~ s/^(\d+) .*$/$1/;
  return ($status < 300);
}

sub deleteemail {
  my ($self, $service) = @_;
  warn "deleteemail ($service->{name})\n" if $self->{verbose};
  my $uid = sprintf ("M%05d", $service->{id});
  my $url = "http://mailwww.epfl.ch/adresseService.cgi?id=$uid&delete=$service->{name}";
  my $lwp = new LWP::UserAgent;
  my $req = new HTTP::Request ('GET', $url);
  my $res = $lwp->request ($req);
  my $status = $res->status_line;
  $status =~ s/^(\d+) .*$/$1/;
  return ($status < 300);
}

sub changeemail {
  my ($self, $service) = @_;
  warn "changeemail ($service->{name})\n" if $self->{verbose};
  return $self->createemail ($service);
}

my $msgs = {
          noaccess => "You are not allowed to do this.",
              noid => "No service ID specified.",
           dberror => "Unable to access database : %s.",
            noserv => "Unable to get service.",
            noname => "No service name specified.",
         allfields => "All fields must be specofied.",
  srvalreadyexists => "Service %s already exists.",
           badname => "Incorrect service name: %s.",
          bademail => "Incorrect email address: %s.",
           badrfid => "Incorrect RFID number : %s.",
        unknownsrv => "Unknown service : %s.",
          nogaspar => "Gaspar non accessible : %s.",
     nowritegaspar => "Unable to write Gaspar database : %s.",
     accountexists => "An account with this name already exists.",
       emailexists => "The email address is already booked, change the service name.",
      camrfidinuse => "This camipro card RFID is already used.",
       badlifetime => "Bad lifetime.",
          nochange => "No changes.",
       badpassword => "Bad password : %s",
     notgroupowner => "You are not owner of group with gid %s",
};

sub getAccount {
  my $name = shift;
  $name =~ tr/[A-Z]/[a-z]/;
  my $account = new Cadi::Accounts ()->getAccountInfos ($name);
  return $account;
}

sub error {
  my ($self, $err, @args) = @_;
  my $msg = $msgs->{$err};
  foreach (@args) {
    $msg =~ s/%s/$_/;
  }
  warn scalar localtime, ' Services:', $msg, "\n";
  $self->{errcode} = $err;
  $self->{errmsg}  = $msg;
  return;
}

my $aeskey = '1AB3H56FF09AEF6E1AB3H56EF09AEF6E';

sub escapeurl {
  my $url = shift;
  $url =~ s/([^\w\+\.\-])/sprintf("%%%X",ord($1))/ge;
  return $url;
}

sub allocuid {
  my $self = shift;
  my  $db = $self->{db};
  return unless $db;
  my $sth = $db->query ('select max(uid) from services');
  return unless $sth;
  my ($maxuid) = $sth->fetchrow;
  $maxuid++;
  return ($maxuid > $MINUID) ? $maxuid : $MINUID;
}

sub logevent {
  my ($self, $action, $srvid, $text) = @_;
  my $eventtypes = {
      addservice => 1,
      modservice => 2,
      delservice => 3,
    revalservice => 4,
  };
  my $eventtype = $eventtypes->{$action};
  return unless $eventtype;
  my $sql = qq{insert into serviceslog set
             date = now(),
           author = ?,
           action = ?,
            srvid = ?,
             text = ?
  };
  my $db = $self->{db};
  return $self->error ('dberror', $CadiDB::errmsg) unless $db;
  my $sth = $db->prepare ($sql);
  return $self->error ('dberror', $self->{db}->{errmsg}) unless $sth;
  my $rv = $db->execute (
    $sth,
    $self->{caller},
    $eventtype,
    $srvid,
    $text || '',
  );
  return $self->error ('dberror', $self->{db}->{errmsg}) unless $rv;
}

sub fixGids {
  my $self = shift;
  my  $db = $self->{db};
  die "Unable to access dinfo db 1" unless $db;
  my $sth = $db->query ('select * from services');
  die "Unable to access dinfo db 2" unless $sth;
  my $Units = new Cadi::Units ();
  die "Unable to access Unit db 2" unless $Units;

  while (my $srv = $sth->fetchrow_hashref) {
    my $uinfo = $Units->getUnitInfos ($srv->{unit});
    next unless ($uinfo && $uinfo->{gid});
    my $sql = qq{
      update services
         set gid = ?
       where  id = ?
    };
    my $sth = $db->prepare ($sql);
    die $db->{errmsg} unless $sth;
    my $rv = $db->execute ($sth, $uinfo->{gid}, $srv->{id});
    die $db->{errmsg} unless $rv;
  }
}

my $create = qq{
  create table services (
             id mediumint not null auto_increment,
           name varchar(64),
          label varchar(64),
       password varchar(64),
          owner varchar(6),
           unit varchar(6),
    description varchar(256),
        tequila char(1),
           ldap char(1),
             ad char(1),
         radius char(1),
            sco char(1),
            uid int,
          email varchar(64),
      camiproid char(5),
    camiprorfid varchar(32),
       lifetime int,
       creation datetime,
        removal datetime,
        renewed datetime,
       reminded datetime,
            key (id)
  )
  
  create table serviceslog (
             id mediumint not null auto_increment,
           date datetime,
         author char(6),
         action tinyint,
          srvid mediumint,
           text text,
            key (id)
  )
};

1;
