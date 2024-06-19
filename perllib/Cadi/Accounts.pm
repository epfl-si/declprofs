#!/usr/bin/perl
#
use strict;
use Cadi::CadiDB;
use Cadi::Notifier;
use Cadi::Units;
use Cadi::Persons;
use Cadi::Accreds;
use Cadi::OAuth2;

package Cadi::Accounts;

my $messages;

my     $MINUID =  1025;
my     $MAXUID = 65532;
my $MINEPFLGID = 20000;
my $MINEXTEGID = 25000;
my $MINSECTGID = 30000;
my $MAXSECTGID = 40000;
my   $MAXYEARS = 100;

sub new { # Exported
  my $class = shift;
  my  $args = (@_ == 1) ? shift : { @_ } ;
  my $self = {
      caller => undef,
          db => undef,
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
  $self->{verbose} = 1 if $self->{fake};
  my %modargs = (
     caller => 'root',
       root => 1,
       utf8 => 1,
    verbose => 0,
       fake => 0
  );
  $self->{Units}   = new Cadi::Units   (%modargs);
  $self->{Persons} = new Cadi::Persons (%modargs);
  $self->{Accreds} = new Cadi::Accreds (%modargs);
  initmessages ($self);
  $self->{db} = new Cadi::CadiDB (
    dbname => 'dinfo',
     trace => $self->{trace},
  );
  bless $self, $class;
}

sub getAccount {
  getAccountInfos (@_);
}

sub getAccountInfos {
  my ($self, $sciperoruser) = @_;
  my $field = ($sciperoruser =~ /^[a-z]*$/) ? 'user' : 'sciper';
  my $sql = qq{
    select *
      from dinfo.accounts
     where $field = ?
  };
  my $sth = $self->{db}->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "getAccount : $self->{db}->{errmsg}";
    return;
  }
  my $rv = $self->{db}->execute ($sth, $sciperoruser);
  unless ($rv) {
    $self->{errmsg} = "getAccount : $self->{db}->{errmsg}";
    return;
  }
  my $account = $sth->fetchrow_hashref;
  $sth->finish;
  return unless $account;
  
  my $sciper = $account->{sciper};
  my $sql = qq{
    select *
      from dinfo.automaps
     where sciper = ?
  };
  my $sth = $self->{db}->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "getAccount : $self->{db}->{errmsg}";
    return;
  }
  my $rv = $self->{db}->execute ($sth, $sciper);
  unless ($rv) {
    $self->{errmsg} = "getAccount : $self->{db}->{errmsg}";
    return;
  }
  $account->{automap} = $sth->fetchrow_hashref;
  $sth->finish;

  $account->{defaultmap} = defaultMap ($account);
  return $account;
}

sub getGroup {
  my ($self, $unitid) = @_;
  my $sql = qq{select * from dinfo.groups where id = ?};
  my $sth = $self->{db}->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "getGroup : $self->{db}->{errmsg}";
    return;
  }
  my $rv = $self->{db}->execute ($sth, $unitid);
  unless ($rv) {
    $self->{errmsg} = "getGroup : $self->{db}->{errmsg}";
    return;
  }
  my $group = $sth->fetchrow_hashref;
  return $group;
}

sub getManyAccounts {
  getManyAccountsInfos (@_);
}

sub getManyAccountsInfos { # Beware : no automaps.
  my ($self, @scipersorusers) = @_;
  return unless @scipersorusers;
  my $first = $scipersorusers [0];
  my $field = ($first =~ /^[a-z]*$/) ? 'user' : 'sciper';
  my  $in = join (', ', map { '?' } @scipersorusers);
  
  my $sql = qq{
    select *
      from dinfo.accounts
     where $field in ($in)
  };
  my $sth = $self->{db}->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "getManyAccountsInfos : $self->{db}->{errmsg}";
    return;
  }
  my $rv = $self->{db}->execute ($sth, @scipersorusers);
  unless ($rv) {
    $self->{errmsg} = "getManyAccountsInfos : $self->{db}->{errmsg}";
    return;
  }
  my @accounts;
  while (my $account = $sth->fetchrow_hashref) {
    push (@accounts, $account);
  }
  $sth->finish;
  return @accounts;
}

sub createAccount {
  my ($self, $sciper) = @_;

  my $account = $self->getAccount ($sciper);
  return 1 if $account;
  
  my $person = $self->{Persons}->getPerson ($sciper);
  return unless $person;

  my @accreds = $self->{Accreds}->getAccreds ($sciper);
  return unless @accreds;
  my $accred = shift @accreds;
  my $unitid = $accred->{unitid};

  my $unit = $self->{Units}->getUnit ($unitid);
  return unless $unit;

  my $group = $self->getGroup ($unitid);

  my   $gid = $group ? $group->{gid} : -1;
  my  $user = $self->allocuser ($person);
  my   $uid = $self->allocuid  ($sciper);
  my    $up = fixcase ($person->{upfirstname});
  my    $un = fixcase ($person->{upname});
  my $gecos = "$up $un";

  my  $home = "/home/$user";
  my $shell = '/bin/bash';

  my $sql = qq{
    insert into accounts
       set user = ?,
         sciper = ?,
            uid = ?,
            gid = ?,
          gecos = ?,
           home = ?,
          shell = ?
  };
  my $sth = $self->{db}->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "createAccount : $self->{db}->{errmsg}";
    return;
  }
  my $rv = $self->{db}->execute (
    $sth,
    $user,
    $sciper,
    $uid,
    $gid,
    $gecos,
    $home,
    $shell,
  );
  unless ($rv) {
    $self->{errmsg} = "createAccount : $self->{db}->{errmsg}";
    return;
  }

  Notifier::notify (
     event => 'addaccount',
    sciper => $sciper,
  );
  return 1;
}

sub addAccount {
  my ($self, $account) = @_;
  my $sql = qq{
    insert into accounts
       set user = ?,
         sciper = ?,
            uid = ?,
            gid = ?,
          gecos = ?,
           home = ?,
          shell = ?
  };
  my $sth = $self->{db}->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "addAccount : $self->{db}->{errmsg}";
    return;
  }
  my   $gid = $account->{gid}   || -1;
  my $gecos = $account->{gecos} || $account->{user};
  my  $home = $account->{home}  || "/home/$account->{user}";
  my $shell = $account->{shell} || "/bin/tcsh";;
  my $rv = $self->{db}->execute (
    $sth,
    $account->{user},
    $account->{sciper},
    $account->{uid},
    $gid,
    $gecos,
    $home,
    $shell,
  );
  unless ($rv) {
    $self->{errmsg} = "addAccount : $self->{db}->{errmsg}";
    return;
  }
  $sth->finish;
  
  if ($account->{automap} && !hasDefaultMap ($account)) {
    my $automap = $account->{automap};
    unless ($automap->{protocol} &&
            $automap->{server}   &&
            $automap->{path}     &&
            $automap->{security}) {
      warn "Invalid automap : protocol = $automap->{protocol}, ".
           "server = $automap->{server}, path = $automap->{path}, ".
           "security = $automap->{security}.\n";
      goto nomap;
    }
    my $sql = qq{
      insert into dinfo.automaps
         set sciper = ?,
           protocol = ?,
             server = ?,
               path = ?,
           security = ?
    };
    my $sth = $self->{db}->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "addAccount : $self->{db}->{errmsg}";
      goto nomap;
    }
    my $rv = $self->{db}->execute (
      $sth,
      $automap->{sciper},
      $automap->{protocol},
      $automap->{server},
      $automap->{path},
      $automap->{security},
    );
    unless ($rv) {
      $self->{errmsg} = "addAccount : $self->{db}->{errmsg}";
      goto nomap;
    }
    $sth->finish;
  }
 nomap:
  Notifier::notify (
     event => 'addaccount',
    sciper => $account->{sciper},
  );
  return 1;
}

sub updateAccount {
  my ($self, $account) = @_;
  unless ($account) {
    $self->{errmsg} = "updateAccount : Argument missing.";
    return;
  }
  my $sciper = $account->{sciper};
  unless ($sciper && ($sciper =~ /^\d\d\d\d\d\d$/)) {
    $self->{errmsg} = "updateAccount : sciper missing or bad.";
    return;
  }
  my $sql = qq{
    update accounts
       set  user = ?,
             uid = ?,
             gid = ?,
           gecos = ?,
            home = ?,
           shell = ?
     where sciper = ?
  };
  my $sth = $self->{db}->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "updateAccount : $self->{db}->{errmsg}";
    return;
  }
  my $oldaccount = $self->getAccountInfos ($sciper);
  unless ($oldaccount) {
    $self->{errmsg} = "updateAccount : no account for $sciper.";
    return;
  }
  $account->{user}  ||= $oldaccount->{user};
  $account->{uid}   ||= $oldaccount->{uid};
  $account->{gid}   ||= $oldaccount->{gid};
  $account->{gecos} ||= $oldaccount->{gecos};
  $account->{home}  ||= $oldaccount->{home};
  $account->{shell} ||= $oldaccount->{shell};
  
  my $rv = $self->{db}->execute (
    $sth,
    $account->{user},
    $account->{uid},
    $account->{gid},
    $account->{gecos},
    $account->{home},
    $account->{shell},
    $account->{sciper},
  );
  unless ($rv) {
    $self->{errmsg} = "updateAccount : $self->{db}->{errmsg}";
    return;
  }
  $sth->finish;
  $self->updateMap ($oldaccount, $account->{automap});
  Notifier::notify (event => 'changeaccount', sciper => $sciper);
  return 1;
}
  
sub updateAutomap {
  my ($self, $sciperoruser, $automap) = @_;
  my $account = $self->getAccountInfos ($sciperoruser);
  unless ($account) {
    $self->{errmsg} = "updateAutomap : unknown account for $sciperoruser.";
    return;
  }
  return $self->updateMap ($account, $automap);
}

sub updateMap {
  my ($self, $account, $automap) = @_;
  my $sciper = $account->{sciper};
  my $defmap = $account->{defmap};
  my $oldmap = $account->{automap};
  my $newmap = $automap unless hasDefaultMap ($account, $automap);
  
  my ($sql, @args);
  if ($newmap) {
    if ($oldmap) {
      $newmap->{protocol} ||= $oldmap->{protocol};
      $newmap->{server}   ||= $oldmap->{server};
      $newmap->{path}     ||= $oldmap->{path};
      $newmap->{security} ||= $oldmap->{security};
      $account->{automap} = $newmap;
      $sql = qq{
        update dinfo.automaps
           set protocol = ?,
                 server = ?,
                   path = ?,
               security = ?
         where sciper = ?
      };
      @args = (
        $newmap->{protocol},
        $newmap->{server},
        $newmap->{path},
        $newmap->{security},
        $sciper,
      );
    }
    else {
      $newmap->{protocol} ||= $defmap->{protocol};
      $newmap->{server}   ||= $defmap->{server};
      $newmap->{path}     ||= $defmap->{path};
      $newmap->{security} ||= $defmap->{security};
      $account->{automap} = $newmap;
      if (!hasDefaultMap ($account)) {
        $sql = qq{
          insert into dinfo.automaps
             set   sciper = ?,
                 protocol = ?,
                   server = ?,
                     path = ?,
                 security = ?
        };
        @args = (
          $sciper,
          $newmap->{protocol},
          $newmap->{server},
          $newmap->{path},
          $newmap->{security},
        );
      }
    }
  } else {
    if ($oldmap) {
      $sql = qq{delete from dinfo.automaps where sciper = ?};
      @args = ($sciper);
    }
  }
  if ($sql) {
    my $sth = $self->{db}->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "updateAccount : $self->{db}->{errmsg}";
      return;
    }
    my $rv = $self->{db}->execute ($sth, @args);
    unless ($rv) {
      $self->{errmsg} = "updateAccount : $self->{db}->{errmsg}";
      return;
    }
    $sth->finish;
  }
  return 1;
}

sub deleteAccount {
  my ($self, $sciperoruser) = @_;
  my $account = $self->getAccountInfos ($sciperoruser);
  unless ($account) {
    $self->{errmsg} = "deleteAccount : unknown account for $account->{sciper}.";
    return;
  }
  my $sql = qq{
    delete
      from accounts
     where sciper = ?
  };
  my $sth = $self->{db}->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "deleteAccount : $self->{db}->{errmsg}";
    return;
  }
  my $rv = $self->{db}->execute ($sth, $account->{sciper});
  unless ($rv) {
    $self->{errmsg} = "deleteAccount : $self->{db}->{errmsg}";
    return;
  }
  $sth->finish;
  #
  # Automaps. TODO: should use Cadi::Automaps.
  #
  my $sql = qq{delete from dinfo.automaps where sciper = ?};
  my $sth = $self->{db}->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "deleteAccount : $self->{db}->{errmsg}";
    goto endautomaps;
  }
  my $rv = $self->{db}->execute ($sth, $account->{sciper});
  unless ($rv) {
    $self->{errmsg} = "deleteAccount : $self->{db}->{errmsg}";
    goto endautomaps;
  }
  $sth->finish;
  endautomaps:
  #
  # OAUth2 tokens.
  #
  my $oauth2 = new Cadi::OAuth2 ();
  unless ($oauth2) {
    $self->{errmsg} = "deleteAccount : Unable to initialize OAuth2 module : $Cadi::OAuth2::errmsg\n";
    goto endoauth2;
  }
  $oauth2->deleteUserTokens ($account->{user});
  endoauth2:
  
  Notifier::notify (event => 'removeaccount', sciper => $account->{sciper});
  return 1;
}

sub defaultMap {
  my $account = shift;
  my  $sciper = $account->{sciper};
  return unless ($sciper =~ /^\d\d\d\d\d\d$/);
  my $srvnum = $sciper % 10;
  return {
    protocol => 'nfs4',
      server => "files$srvnum.epfl.ch",
        path => "/dit-files$srvnum-t1/data/$account->{user}",
    security => 'krb5',
  }
}

sub eqMap {
  my ($map1, $map2) = @_;
  return unless ($map1 && $map2);
  return (
    ($map1->{protocol} eq $map2->{protocol}) &&
    ($map1->{server}   eq $map2->{server})   &&
    ($map1->{path}     eq $map2->{path})     &&
    ($map1->{security} eq $map2->{security})
  );
}

sub hasDefaultMap {
  my $account = shift;
  my  $accmap = shift || $account->{automap};
  return unless $accmap;
  my $defmap = defaultMap ($account);
  return 1 unless (
    $accmap->{protocol} ||
    $accmap->{server}   ||
    $accmap->{path}     ||
    $accmap->{security}
  );
  return (
    ($accmap->{protocol} eq $defmap->{protocol}) &&
    ($accmap->{server}   eq $defmap->{server})   &&
    ($accmap->{path}     eq $defmap->{path})     &&
    ($accmap->{security} eq $defmap->{security})
  );
}

sub loadAccounts {
  my $self = shift;
  my $sql = qq{select * from accounts};
  my $sth = $self->{db}->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "loadAccounts : $self->{db}->{errmsg}";
    return;
  }
  my $rv = $self->{db}->execute ($sth);
  unless ($rv) {
    $self->{errmsg} = "loadAccounts : $self->{db}->{errmsg}";
    return;
  }
  my ($AccountsByUser, $AccountsByUid);
  while (my $account = $sth->fetchrow_hashref) {
    $AccountsByUser->{$account->{user}} = $account;
    $AccountsByUid->{$account->{uid}}   = $account;
  }
  $self->{AccountsByUser} = $AccountsByUser;
  $self->{AccountsByUid}  = $AccountsByUid;
}

sub loadGroups {
  my $self = shift;
  my $sql = qq{select * from groups};
  my $sth = $self->{db}->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "loadGroups : $self->{db}->{errmsg}";
    return;
  }
  my $rv = $self->{db}->execute ($sth);
  unless ($rv) {
    $self->{errmsg} = "loadGroups : $self->{db}->{errmsg}";
    return;
  }
  my (@AllGroups, $GroupsByGid);
  while (my $group = $sth->fetchrow_hashref) {
    $GroupsByGid->{$group->{gid}} = $group;
    push (@AllGroups, $group);
  }
  $self->{AllGroups}   = \@AllGroups;
  $self->{GroupsByGid} = $GroupsByGid;
}

sub getAccountOfUid {
  my ($self, $uid) = @_;
  my $sql = qq{
    select *
      from accounts
     where uid = ?
  };
  my $sth = $self->{db}->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "getAccountOfUid : $self->{db}->{errmsg}";
    return;
  }
  my $rv = $self->{db}->execute ($sth, $uid);
  unless ($rv) {
    $self->{errmsg} = "getAccountOfUid : $self->{db}->{errmsg}";
    return;
  }
  my $account = $sth->fetchrow_hashref;
  return $account;
}

sub getGroupOfGid {
  my ($self, $gid) = @_;
  my $sql = qq{
    select *
      from groups
     where gid = ?
  };
  my $sth = $self->{db}->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "getGroupOfGid : $self->{db}->{errmsg}";
    return;
  }
  my $rv = $self->{db}->execute ($sth, $gid);
  unless ($rv) {
    $self->{errmsg} = "getGroupOfGid : $self->{db}->{errmsg}";
    return;
  }
  my $group = $sth->fetchrow_hashref;
  return $group;
}

sub allocuid {
  my ($self, $sciper) = @_;
  warn "Cadi::Accounts::allocuid ($sciper).\n" if $self->{trace};
  my $uid = $sciper - 99000;
  
  $self->loadAccounts () unless $self->{AccountsByUid};
  my $account = $self->{AccountsByUid}->{$uid};
  return $uid if (!$account || $account->{sciper} eq $sciper);
  
  my $minfreeuid =  1025;
  for (my $uid = $minfreeuid; $uid < $MAXUID; $uid++) {
    my $account = $self->{AccountsByUid}->{$uid};
    return $uid if (!$account || $account->{sciper} eq $sciper);
  }
}

sub allocgid {
  my ($self, $unit) = @_;
  warn "Cadi::Accounts::allocgid ($unit->{id}).\n" if $self->{trace};
  $self->loadGroups () unless $self->{GroupsByGid};
  my $cf = $unit->{cf};
  if ($cf) {
    if ($cf == -1) { # section / semestre
      for (my $gid = $MINSECTGID;; $gid++) {
        my $group = $self->{GroupsByGid}->{$gid};
        return $gid if !$group;
      }
    }
    elsif (($cf >= 0) && ($cf < 10000)) {
      my   $gid = $cf + 10000;
      my $group = $self->{GroupsByGid}->{$gid};
      return $gid if !$group;
    }
    for (my $gid = $MINEPFLGID;; $gid++) {
      my $group = $self->{GroupsByGid}->{$gid};
      return $gid if !$group;
    }
  }
  for (my $gid = $MINEXTEGID;; $gid++) {
    my $group = $self->{GroupsByGid}->{$gid};
    return $gid if !$group;
  }
}

sub allocuser {
  my ($self, $person) = @_;
  return unless $person;

  $self->loadAccounts () unless $self->{AccountsByUser};

  my $sciper = $person->{persid};
  my $p = $person->{upfirstname};
  my $n = $person->{upname};
  warn "Cadi::Accounts::allocuser ($sciper, $p, $n).\n" if $self->{trace};

  $p =~ tr/A-Z/a-z/;
  $n =~ tr/A-Z/a-z/;
  $p =~ s/[^a-z0-9 '.-]//g;
  $n =~ s/[^a-z0-9 '.-]//g;

  my    @noms = split (/[ \.'-]+/,  $n);
  my @prenoms = split (/[ \.,'-]+/, $p);

  my $user = $noms [0];
  $user = $user . $noms [1] if ($noms [1] && length ($user) < 5);
  $user = $user . $noms [2] if ($noms [2] && length ($user) < 5);
  $user =~ s/(.{8}).*/$1/;
  
  return $user if $self->usernameAvailable ($user, $sciper);
  my $ouser = $user;
  
  my @prens = @prenoms;
  my $inits = '';
  while (@prens) {
    my $cpre = shift @prens;
    my $init = substr ($cpre, 0, 1);
    $inits   = $inits . $init;
    my $user = $inits . $ouser;
    $user =~ s/(.{8}).*/$1/;
    return $user if $self->usernameAvailable ($user, $sciper);
  }
  
  my $oprenom = shift (@prenoms);
  (my $init = $oprenom) =~ s/^(..).*$/$1/;
  $user = $init . join ('',map {m/^(.).*$/;$1} @prenoms) . $ouser;
  $user =~ s/(.{8}).*/$1/;
  return $user if $self->usernameAvailable ($user, $sciper);

  unshift (@prenoms, $oprenom);
  $user = join('',map {m/^(..).*$/;$1} @prenoms) . $ouser;
  $user =~ s/(.{8}).*/$1/;
  return $user if $self->usernameAvailable ($user, $sciper);

  $user = join('',map {m/^(...).*$/;$1} @prenoms) . $ouser;
  $user =~ s/(.{8}).*/$1/;
  return $user if $self->usernameAvailable ($user, $sciper);

  $user = join('',map {m/^(....).*$/;$1} @prenoms) . $ouser;
  $user =~ s/(.{8}).*/$1/;
  return $user if $self->usernameAvailable ($user, $sciper);

  for (my $i = 1; $i < 10 ; $i++ ) {
    $user = $ouser . $i;
    return $user if $self->usernameAvailable ($user, $sciper);
  }
  for (my $i = 1; $i < 10000 ; $i++ ) {
    $user = "uuniq" . $i;
    return $user if $self->usernameAvailable ($user, $sciper);
  }
  return $user;
}

sub usernameAvailable {
  my ($self, $user, $sciper) = @_;
  $self->loadAccounts () unless $self->{AccountsByUser};
  my $account = $self->{AccountsByUser}->{$user};
  return 1 if (!$account || $account->{sciper} eq $sciper);
  return 0;
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
  };
}

sub fixcase {
  my $string = shift;
  $string =~ tr/A-Z/a-z/;
  if ($string =~ /^(.*)([- ]+)(.*)$/) {
    my ($a, $b, $c) = ($1, $2, $3);
    $string = fixcase ($a) . $b . fixcase ($c);
  } else {
    $string = ucfirst $string
      unless ($string =~ /^(a|au|des|de|du|en|et|zur|le|la|les|sur|von|la)$/);
  }
  return $string;
}

sub error {
  my ($self, $sub, $msgcode, @args) = @_;
  my  $msghash = $messages->{$msgcode};
  my $language = $self->{language} || 'en';
  my  $message = $msghash->{$language};
  $self->{errmsg} = sprintf ("$sub : $message", @args);
}


1;
