#!/usr/bin/perl
#
use strict;
use lib qw(/opt/dinfo/lib/perl);
use Net::LDAP;
use Net::LDAPS;
use Time::Local;
use Digest::SHA1;
use MIME::Base64;

use Cadi::CadiDB;
use Cadi::Persons;
use Cadi::Groups;
use Cadi::Units;
use Cadi::Accounts;
use Cadi::Accreds;
use Cadi::Guests;
use Cadi::Services;

package Cadi::LDAP;

my $domemberuniqueid = 0;

my $accredldapattrs = {
  fonction => [ 'title', 'description', ],
    statut => [ 'organizationalStatus', ],
    classe => [ 'userClass', ],
};

sub new { # Exported
  my $class = shift;
  my  %args = @_;
  my $self = {
      errmsg => undef,
     errcode => undef,
    language => 'fr',
      server => undef,
        base => undef,
       debug => 0,
     verbose => 1,
       trace => 0,
  };
  foreach my $arg (keys %args) {
    $self->{$arg} = $args {$arg};
  }
  $self->{verbose} = 1 if $self->{fake};
  $self->{verbose} = 1;
  my %modargs = (
     caller => 'root',
       root => 1,
       utf8 => 1,
    verbose => 0,
       fake => 0
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
  unless ($accred) {
    error ("addAccred: Accred not found : ($sciper, $unite)");
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
  if ($timedeb > time) {
    info ("addAccred: ignoring future accred ($sciper, $unite)");
    return 1;
  }
  #
  # Try to find the password.
  #
  my $gaspardb = new Cadi::CadiDB (
    dbname => 'gaspar',
      utf8 => 1,
  );
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
  my   $statusid = $accred->{statusid};
  my    $classid = $accred->{classid};
  my      $posid = $accred->{posid};
  
  my     $status = $self->{Accreds}->getStatus   ($statusid);
  my      $class = $self->{Accreds}->getClass    ($classid);
  my   $position = $self->{Accreds}->getPosition ($posid);
  
  my $fonctionxy = $position->{labelfr};
  my $fonctionxx = $position->{labelxx};
  my $fonctionen = $position->{labelen};
  my   $fonction = ($person->{sex} eq 'F') ? $fonctionxx : $fonctionxy;
  my  $perstitle = ($person->{sex} eq 'F') ? 'Madame' : 'Monsieur';

  my       $upname = fixcase ($person->{upname});
  my  $upfirstname = fixcase ($person->{upfirstname});
  my         $name = $person->{name};
  my    $firstname = $person->{firstname};
  my  $displayname = "$firstname $name";
  my        $email = $person->{email};
  my     $unitacro = $unit->{sigle};
  my     $unitname = $unit->{label};
  my $employeeType = 'Ignore';
  my   $botwebprop = 1;

  my $visible = $self->{Accreds}->getAccredProperty ($accred, $botwebprop);
  if ($visible) {
    my $employeetypes = {
      'p' => 'Personnel',
      'e' => 'Enseignant',
      's' => 'Etudiant',
      'm' => 'Manuelle',
    };
    my $orig = $accred->{origine};
    $employeeType = $orig ? $employeetypes->{$orig} : 'Autre';
  }

  my $unitdn = dnofunit ($unit);
  my $dn = "cn=$upfirstname $upname,$unitdn";

  my @cn = ("$firstname $name");
  push (@cn, "$upfirstname $upname")
    if (("\U$name" ne "\U$upname") || ("\U$firstname" ne "\U$upfirstname"));
  push (@cn, $name);
  push (@cn, $upname) if ("\U$name" ne "\U$upname");
  my @sn = ($name);
  push (@sn, $upname) if ("\U$name" ne "\U$upname");
  my @gn = ($firstname);
  push (@gn, $upfirstname) if ("\U$firstname"  ne "\U$upfirstname");

  my $org = 'epfl';
  if ($dn =~ /o=([^\s,]*)/) {
    $org = $1;
  }
  my @attrs = (
             cn => \@cn,
             sn => \@sn,
             gn => \@gn,
    displayName => $displayname,
             ou => $unitacro,
              l => 'Lausanne',
              o => $org,
  );
  push (@attrs, (ou => $unitname))  unless (uc $unitname eq uc $unitacro);
  push (@attrs, (
              'title' => $fonction,
        'description' => $fonction,
      'personalTitle' => $perstitle,
    )
  ) if $fonction;
  push (@attrs, (
            'title;lang-en' => $fonctionen,
      'description;lang-en' => $fonctionen,
    )
  ) if $fonctionen;
  
  push (@attrs, ('userClass' => $class->{labelfr})) if $class;
  push (@attrs, (     'mail' =>  $email)) if $email;
  my $password = $accred->{password} || '{CRYPT}*';
  push (@attrs, (
    'organizationalStatus' => $status->{labelfr},
            'employeeType' => $employeeType,
        'uniqueIdentifier' => $sciper,
            'userPassword' => $password,
    ),
  );
  my @objectclasses = (
    'person',
    'organizationalPerson',
    'EPFLorganizationalPerson',
    'inetOrgPerson',
  );

  my $account = $self->{Accounts}->getAccount ($sciper);
  if ($account) {
    my @uids = ($accred->{ordre} == 1)
      ? ($account->{user}, $account->{user} . '@' . lc $unitacro)
      : ($account->{user} . '@' . lc $unitacro)
      ;
    push (@attrs, (
                  'uid' => \@uids,
            'uidnumber' => $account->{uid},
            'gidnumber' => $unit->{gid},
                'gecos' => $account->{gecos},
        'homedirectory' => $account->{home},
           'loginshell' => $account->{shell},
      )
    );
    push (@objectclasses, 'posixAccount', 'shadowAccount');
  }
  
  my $shibb = 1;
  if ($shibb) {
    my $eduPersonAffiliations = {
      'p' => 'staff',
      'm' => 'staff',
      'e' => 'staff',
      's' => 'student',
    };
    my      $origine = $accred->{origine};
    my $edupersaffil = $eduPersonAffiliations->{$origine} if $origine;
    push (@attrs, ('swissEduPersonUniqueID' => "$sciper\@epfl.ch"));
    push (@attrs, (  'eduPersonAffiliation' => $edupersaffil)) if $edupersaffil;
    push (@objectclasses, 'swissEduPerson');
  }
  push (@attrs, ('objectclass' => \@objectclasses));
  #
  # Finish.
  #
  msg ("addAccred: adding accred ($sciper, $unite)") if $self->{verbose};
  unless ($self->{fake}) {
    my $status = $self->{ldap}->add ($dn, attrs => [ @attrs ]);
    if ($status->code) {
      error ("addAccred: unable to add $dn on $self->{server} : ", $status->error)
        unless ($status->error =~ /already exists/i);
    }
    $self->addAutomap ($account);
  }
  $self->fixAccredsOrder ($sciper);
  $self->removeOld ($sciper); # Remove from epfl-old id exists.
  #
  # Groups
  #
  my @groups = $self->{Groups}->listGroupsUserBelongsTo ($sciper);
  foreach my $group (@groups) {
    $self->addMember ($group->{name}, $sciper);
  }
  return 1;
}

sub dnofunit {
  my $unit = shift;
  my @path = split (/\s+/, lc $unit->{path});
  my $o = shift @path;
  @path = reverse @path;
  my $dn = join (',', map { "ou=$_" } @path);
  $dn .= ",o=$o,c=ch";
  return $dn;
}

sub deleteAccred {
  my ($self, $sciper, $unite) = @_;
  msg ("deleteAccred ($sciper, $unite)") if $self->{trace};
  unless ($sciper && $unite) {
    error ("deleteAccred: Bad call : $sciper = $sciper, unite = $unite");
    return;
  }
  my $person = $self->{Persons}->getPerson ($sciper);
  unless ($person && $person->{name}) {
    error ("deleteAccred: Unknown sciper : $sciper");
    return;
  }
  my      $upname = fixcase ($person->{upname});
  my $upfirstname = fixcase ($person->{upfirstname});

  my $unit = $self->{Units}->getUnit ($unite);
  unless ($unit) {
    error ("deleteAccred: Unknown unit : $unite");
    return;
  }
  my $unitdn = dnofunit ($unit);
  my $dn = "cn=$upfirstname $upname,$unitdn";

  msg ("deleteAccred: removing accred ($sciper, $unite)") if $self->{verbose};
  unless ($self->{fake}) {
    my $status = $self->{ldap}->delete ($dn);
    if ($status->code && $self->{verbose}) {
      error ("deleteAccred: unable to remove $dn from $self->{server} : ", $status->error);
    }
  }
  $self->fixAccredsOrder ($sciper);
  return 1;
}

sub updateAccred {
  my ($self, $sciper, $unite) = @_;
  msg ("updateAccred ($sciper, $unite)") if $self->{trace};
  unless ($sciper && $unite) {
    error ("updateAccred: Bad call : $sciper = $sciper, unite = $unite");
    return;
  }
  my $person = $self->{Persons}->getPerson ($sciper);
  unless ($person && $person->{name}) {
    error ("updateAccred: Unknown sciper : $sciper");
    return;
  }
  my $accred = $self->{Accreds}->getAccred ($sciper, $unite);
  unless ($accred) {
    error ("updateAccred: Accred not found : ($sciper, $unite)");
    return;
  }
  my      $upname = fixcase ($person->{upname});
  my $upfirstname = fixcase ($person->{upfirstname});

  my $unit = $self->{Units}->getUnit ($unite);
  unless ($unit) {
    error ("deleteAccred: Unknown unit : $unite");
    return;
  }
  my $unitdn = dnofunit ($unit);
  my     $dn = "cn=$upfirstname $upname,$unitdn";

  my $changes;
  if ($accred->{posid}) {
    my     $posid = $accred->{posid};
    my  $position = $self->{Accreds}->getPosition ($posid);
    if ($position) {
      my $posfr = ($person->{sex} eq 'F')
        ? $position->{labelxx}
        : $position->{labelfr}
        ;
      my $posen = $position->{labelen};
      if ($posfr) {
        push (@$changes, 'replace', [       title => $posfr ]);
        push (@$changes, 'replace', [ description => $posfr ]);
      }
      if ($posen) {
        push (@$changes, 'replace', [       'title;lang-en' => $posen ]);
        push (@$changes, 'replace', [ 'description;lang-en' => $posen ]);
      }
    }
  }
  
  if ($accred->{statusid}) {
    my $statusid = $accred->{statusid};
    my   $status = $self->{Accreds}->getStatus ($statusid);
    if ($status) {
      push (@$changes, 'replace', [ 'organizationalStatus' => $status->{labelfr} ]);    
    }
  }
  
  if ($accred->{classid}) {
    my $classid = $accred->{classid};
    my   $class = $self->{Accreds}->getClass ($classid);
    if ($class) {
      push (@$changes, 'replace', [ 'userClass' => $class->{labelfr} ]);    
    }
  }
  if ($changes && @$changes) {
    msg ("updateAccred: updating accred ($sciper, $unite)") if $self->{verbose};
    unless ($self->{fake}) {
      my $status = $self->{ldap}->modify ($dn, changes => $changes);
      if ($status->code) {
        error ("updateAccred: unable to update of $dn on $self->{server} : ", $status->error)
          unless ($status->error =~ /already exists/i);
      }
    }
  }
  return 1;
}

sub changeAccredsOrder {
  my ($self, $sciper) = @_;
  msg ("changeAccredsOrder ($sciper)") if $self->{trace};
  $self->fixAccredsOrder ($sciper);
  #
  # Change member field of groups if the main accred gets changed. TODO.
  #
  return 1;
}

sub setAccredVisible {
  my ($self, $sciper, $unite) = @_;
  msg ("setAccredVisible ($sciper, $unite)") if $self->{trace};
  unless ($sciper && $unite) {
    error ("setAccredVisible: Bad call : $sciper = $sciper, unite = $unite");
    return;
  }
  my $employeetypes = {
    'p' => 'Personnel',
    'e' => 'Enseignant',
    's' => 'Etudiant',
    'm' => 'Manuelle',
  };
  my $person = $self->{Persons}->getPerson ($sciper);
  unless ($person && $person->{name}) {
    error ("setvisivle: Unknown sciper : $sciper");
    return;
  }
  my $accred = $self->{Accreds}->getAccred ($sciper, $unite);
  unless ($accred) {
    error ("setvisivle: Accred not found : ($sciper, $unite)");
    return;
  }
  my       $upname = fixcase ($person->{upname});
  my  $upfirstname = fixcase ($person->{upfirstname});
  my         $orig = $accred->{origine};
  my $employeeType = $orig ? $employeetypes->{$orig} : 'Autre';
  my       $unitdn = $self->getUnitDN ($unite);
  unless ($unitdn) {
    error ("setvisivle: unable to find unit dn for $unite");
    return;
  }
  my $dn = "cn=$upfirstname $upname,$unitdn";
  msg ("setAccredVisible: accred = ($sciper, $unite)") if $self->{verbose};
  unless ($self->{fake}) {
    my $status = $self->{ldap}->modify ($dn, replace => { 'employeeType' => $employeeType });
    if ($status->code) {
      error ("setvisible: unable to modify employeeType for $dn : ", $status->error)
        unless ($status->error =~ /already exists/i);
    }
  }
  return 1;
}

sub setAccredNotVisible {
  my ($self, $sciper, $unite) = @_;
  msg ("setAccredNotVisible ($sciper, $unite)") if $self->{trace};
  unless ($sciper && $unite) {
    error ("setAccredNotVisible: Bad call : $sciper = $sciper, unite = $unite");
    return;
  }
  my $person = $self->{Persons}->getPerson ($sciper);
  unless ($person && $person->{name}) {
    error ("setnotvisivle: Unknown sciper : $sciper");
    return;
  }
  my $accred = $self->{Accreds}->getAccred ($sciper, $unite);
  unless ($accred) {
    error ("setnotvisivle: Accred not found : ($sciper, $unite)");
    return;
  }
  my      $upname = fixcase ($person->{upname});
  my $upfirstname = fixcase ($person->{upfirstname});
  my      $unitdn = $self->getUnitDN ($unite);
  unless ($unitdn) {
    error ("setnotvisivle: unable to find unit dn for $unite");
    return;
  }
  my $dn = "cn=$upfirstname $upname,$unitdn";
  msg ("setAccredNotVisible: accred = ($sciper, $unite)") if $self->{verbose};
  unless ($self->{fake}) {
    my $status = $self->{ldap}->modify ($dn, replace => { 'employeeType' => 'Ignore' });
    if ($status->code) {
      error ("setnotvisible: unable to modify employeeType for $dn : ", $status->error)
        unless ($status->error =~ /already exists/i);
    }
  }
  return 1;
}

sub addEmailAddress {
  my ($self, $sciper, $email) = @_;
  $self->ldapsetemail ('add', $sciper, $email);
  return 1;
}

sub removeEmailAddress {
  my ($self, $sciper, $email) = @_;
  $self->ldapsetemail ('delete', $sciper, $email);
  $self->removeOld ($sciper); # Remove from epfl-old id exists.
  return 1;
}

sub changeEmailAddress {
  my ($self, $sciper, $email) = @_;
  $self->ldapsetemail ('replace', $sciper, $email);
  return 1;
}

sub ldapsetemail {
  my ($self, $action, $sciper, $email) = @_;
  my $filter = "(& (uniqueIdentifier=$sciper) (objectclass=person))";
  my $status = $self->{ldap}->search (
      base => 'c=ch',
     scope => 'sub',
    filter => $filter,
  );
  if ($status->code) {
    error ("setEmailAddress: unable to find entry for $sciper on $self->{server} : ",
           $status->error);
    return;
  }
  my @results = $status->entries;
  foreach my $result (@results) {
    my $userdn = $result->dn;
    msg ("changeEmailAddress: accred = ($sciper, $email, $action)") if $self->{verbose};
    unless ($self->{fake}) {
      my $status = $self->{ldap}->modify ($userdn, $action => { mail => $email });
      if ($status->code) {
        error ("setEmailAddress: unable to set email address for $userdn on $self->{server} : ",
          $status->error) unless ($status->error =~ /(already exists|no such attribute)/i);
      }
    }
  }
  return 1;
}

sub removeOld {
  my ($self, $sciper) = @_;
  my $status = $self->{ldap}->search (
      base => 'o=epfl-old,c=ch',
     scope => 'sub',
    filter => "(& (uniqueIdentifier=$sciper) (objectclass=person))",
  );
  return if $status->code; # Not there, ignore.
  my @results = $status->entries;
  foreach my $result (@results) {
    my $dn = $result->dn;
    msg ("removeOld: pers = ($sciper, $dn)") if $self->{verbose};
    unless ($self->{fake}) {
      my $status = $self->{ldap}->delete ($dn);
      if ($status->code) {
        error ("removeOld: unable to remove for $dn on $self->{server} : ", $status->error);
        return;
      }
    }
  }
  return 1;
}

sub addOld { # unfinished.
  my ($self, $sciper) = @_;
  #
  # Pers infos
  #
  my $person = $self->{Persons}->getPerson ($sciper);
  unless ($person && $person->{name}) {
    error ("addOld: Unknown sciper : $sciper : .$self->{Persons}->{errmsg}");
    return;
  }
  my        $name = fixcase ($person->{upname});
  my   $firstname = fixcase ($person->{upfirstname});
  my          $cn = "$firstname $name";
  my          $dn = "cn=$cn,o=epfl-old,c=ch";
  my          $sn = $name;
  my          $gn = $firstname;
  my $displayName = $cn;
  my           $o = 'epfl-old';
  my         @ous = ('epfl-old');
  my       $email = $person->{email};
  #
  # Gaspar
  #
  my $userPassword = gasparPwd ($sciper) || '{CRYPT}*';
  #
  # Last units
  #
  my @lastunits = readdepart ($sciper);
  if (@lastunits) {
    foreach my $unit (@lastunits) {
      my $unit = $self->{Units}->getUnit ($unit);
      next unless $unit;
      my $sigle = $unit->{sigle};
      push (@ous, $sigle) if $sigle;
    }
  }
  #
  # Account
  #
  my $account = $self->{Accounts}->getAccount ($sciper);
  return unless $account;
  my          $user = $account->{user};
  my     $uidNumber = $account->{uid} || -1;
  my     $gidNumber = $account->{gid} || -1;
  my $homeDirectory = $account->{home};
  my    $loginShell = $account->{shell} || '/bin/bash';
  my         $gecos = $account->{gecos};
  #
  # objectClass
  #
  my @objectClass = (
    'person',
    'organizationalPerson',
    'EPFLorganizationalPerson',
    'swissEduPerson',
    'inetOrgPerson',
    'posixAccount',
  );
  my @attrs = (
                        cn => $cn,
                        sn => $sn,
                        gn => $gn,
               displayName => $displayName,
                        ou => \@ous,
                         l => 'Lausanne',
                         o => $o,
      organizationalStatus => 'Externe',
          uniqueIdentifier => $sciper,
                      mail => $email,
                       uid => $user,
                 uidNumber => $uidNumber,
                 gidNumber => $gidNumber,
                loginShell => $loginShell,
                     gecos => $gecos,
             homeDirectory => $homeDirectory,
              userPassword => $userPassword,
    swissEduPersonUniqueID => "$sciper\@epfl.ch",
                 #memberOf => @groups ? \@groups : undef,
               objectClass => \@objectClass,
  );
  unless ($self->{fake}) {
    my $status = $self->{ldap}->add ($dn, attrs => [@attrs]);
    if ($status->code) {
      error ("addOld: unable to add $dn on $self->{server} : ", $status->error)
        unless ($status->error =~ /already exists/i);
      return;
    }
  }
}

sub gasparPwd {
  my ($self, $sciper) = @_;
  my $gaspardb = new Cadi::CadiDB (
    dbname => 'gaspar',
      utf8 => 1,
  );
  return unless $gaspardb;

  my $sql = qq{select pwdsha from clients where sciper = ?};
  my $sth = $gaspardb->prepare ($sql);
  return unless $sth;
  my $rv = $gaspardb->execute ($sth, $sciper);
  return unless $rv;
  my ($pwdsha) = $sth->fetchrow;
  $sth->finish;
  return $pwdsha;
}

sub readdepart {
  my ($self, $sciper) = @_;
  my $dinfodb = new Cadi::CadiDB (
    dbname => 'dinfo',
      utf8 => 1,
  );
  return unless $dinfodb;

  my $sql = qq{
    select date_depart,
           lastunits
      from dinfo.departs
     where sciper = ?
  };
  my $sth = $dinfodb->query ($sql);
  return unless $sth;

  my ($datedepart, $lastunits) = $sth->fetchrow;
  return unless $datedepart;
  
  my @lastunits = split (/,/, $lastunits);
  $sth->finish;
  return @lastunits;
}

sub fixAccredsOrder {
  my ($self, $sciper) = @_;
  msg ("fixAccredsOrder ($sciper)") if $self->{trace};
  my   @accreds = $self->{Accreds}->getAccreds ($sciper);
  return unless @accreds;

  my $person = $self->{Persons}->getPerson ($sciper);
  return unless ($person && $person->{upname});
  my      $upname = fixcase ($person->{upname});
  my $upfirstname = fixcase ($person->{upfirstname});
  my   $account = $self->{Accounts}->getAccount  ($sciper);
  return unless $account;

  foreach my $accred (@accreds) {
    my $unitid = $accred->{unitid};
    my   $unit = $self->{Units}->getUnit ($unitid);
    unless ($unit) {
      error ("fixAccredsOrder: Unknown unit : $unitid for $sciper");
      return;
    }
    my $unitdn = dnofunit ($unit);
    $accred->{userdn} = "cn=$upfirstname $upname,$unitdn";
    $accred->{unit}   = $unit;
  }
  foreach my $accred (@accreds) {
    my $userdn = $accred->{userdn};
    msg ("fixAccredsOrder: fixing uids for $userdn") if $self->{verbose};
    my $unitacro = lc $accred->{unit}->{sigle};
    my     @uids = ($accred->{ordre} == 1)
      ? ($account->{user}, $account->{user} . '@' . $unitacro)
      : ($account->{user} . '@' . $unitacro);
    msg ("fixAccredsOrder: new uids = @uids") if $self->{verbose};

    unless ($self->{fake}) {
      my  $firstuid = shift @uids;
      my $changes = [
        replace => [             uid => $firstuid ],
        replace => [ EPFLAccredOrder => $accred->{ordre} ],
      ];
      my  $status = $self->{ldap}->modify ($userdn, changes => $changes);
      if ($status->code) {
        error ("fixAccredsOrder: unable to set uid for $userdn on $self->{server} : ", 
                $status->error);
      }
      my $seconduid = shift @uids;
      if ($seconduid) {
        my $changes = [ add => [ uid => $seconduid ] ];
        my  $status = $self->{ldap}->modify ($userdn, changes => $changes);
        if ($status->code) {
          error ("fixAccredsOrder: unable to add uid for $userdn on $self->{server} : ", 
                  $status->error);
        }
      }
    }
  }
  return 1;
}

#
# Accounts
#

sub setPosixAccount {
  my ($self, $sciper, $unite) = @_;
  msg ("setPosixAccount ($sciper, $unite)") if $self->{trace};
  my $account = $self->{Accounts}->getAccount  ($sciper);
  return unless $account;
  my      $uid = $account->{uid};
  my      $gid = $account->{gid};
  my    $shell = $account->{shell};
  my     $home = $account->{home};
  my    $gecos = $account->{gecos};
  unless ($uid && $gid && $shell && $home && $gecos) {
    error ("setPosixAccount: bad account : ($uid, $gid, $shell, $home, $gecos)");
    return;
  }

  my $unit = $self->{Units}->getUnit ($unite);
  unless ($unit) {
    error ("setPosixAccount: Unknown unit : $unite");
    return;
  }
  my  $uacro = $unit->{sigle};
  my $status = $self->{ldap}->search (
      base => 'c=ch',
     scope => 'sub',
    filter => "(&(objectClass=person)(uniqueIdentifier=$sciper)(ou=$uacro)",
  );
  if ($status->code) {
    error ("setPosixAccount: unable to find entry for $sciper, $uacro on $self->{server} : ",
            $status->error);
    return;
  }
  my @results = $status->entries;
  my  $result = shift @results;
  if (@results) {
    error ("setPosixAccount: more than one entry for $sciper, $uacro on $self->{server}");
    return;
  }
  my $userdn = $result->dn;
  my $changes;
  push (@$changes, 'add', [     'uidNumber' => $uid   ]);
  push (@$changes, 'add', [     'gidNumber' => $gid   ]);
  push (@$changes, 'add', [    'loginShell' => $shell ]);
  push (@$changes, 'add', [ 'homeDirectory' => $home  ]);
  push (@$changes, 'add', [         'gecos' => $gecos ]);
  push (@$changes, 'add', [   'objectClass' => 'posixAccount'  ]);
  push (@$changes, 'add', [   'objectClass' => 'shadowAccount' ]);
  msg ("setPosixAccount: of $sciper in $uacro") if $self->{verbose};
  unless ($self->{fake}) {
    my $status = $self->{ldap}->modify ($userdn, changes => $changes);
    if ($status->code) {
      error ("setPosixAccount: unable to change account for $userdn on $self->{server} : ",
              $status->error);
    }
  }
  return 1;
}

sub unsetPosixAccount {
  my ($self, $sciper, $unite) = @_;
  msg ("unsetPosixAccount ($sciper, $unite)") if $self->{trace};
  my $unit = $self->{Units}->getUnit ($unite);
  unless ($unit) {
    error ("unsetPosixAccount: Unknown unit : $unite");
    return;
  }
  my  $uacro = $unit->{sigle};
  my $status = $self->{ldap}->search (
      base => 'c=ch',
     scope => 'sub',
    filter => "(&(objectClass=person)(uniqueIdentifier=$sciper)(ou=$uacro)",
  );
  if ($status->code) {
    error ("unsetPosixAccount: unable to find entry for $sciper, $uacro on $self->{server} : ",
            $status->error);
    return;
  }
  my @results = $status->entries;
  my  $result = shift @results;
  if (@results) {
    error ("unsetPosixAccount: more than one entry for $sciper, $uacro on $self->{server}");
    return;
    }
  my $userdn = $result->dn;
  my $changes;
  push (@$changes, 'delete',      'uidNumber');
  push (@$changes, 'delete',      'gidNumber');
  push (@$changes, 'delete',     'loginShell');
  push (@$changes, 'delete',  'homeDirectory');
  push (@$changes, 'delete',          'gecos');
  push (@$changes, 'delete', [   'objectClass' => 'posixAccount'  ]);
  push (@$changes, 'delete', [   'objectClass' => 'shadowAccount' ]);

  msg ("unsetPosixAccount: of $sciper in $uacro") if $self->{verbose};
  unless ($self->{fake}) {
    my $status = $self->{ldap}->modify ($userdn, changes => $changes);
    if ($status->code) {
      error ("unsetPosixAccount: unable to change account for $userdn on $self->{server} : ",
              $status->error);
    }
  }
  return 1;
}

sub changeAccount {
  my ($self, $sciper) = @_;
  my $account = $self->{Accounts}->getAccount ($sciper);
  unless ($account) {
    error ("changeAccount: No account found for $sciper");
    return;
  }
  my  $user = $account->{user};
  my  $uids = $account->{uid} || -1;
  my  $gids = $account->{gid} || -1;
  my  $home = $account->{home};
  my $shell = $account->{shell} || '/bin/bash';
  my $gecos = $account->{gecos};

  my $person = $self->{Persons}->getPerson ($sciper);
  unless ($person && $person->{name}) {
    error ("changeAccount: Unknown sciper : $sciper");
    return;
  }
  my $filter = "(& (uniqueIdentifier=$sciper) (objectclass=person))";
  my $status = $self->{ldap}->search (
      base => 'c=ch',
     scope => 'sub',
    filter => $filter,
  );
  if ($status->code) {
    error ("changeAccount: unable to find entry for $sciper on $self->{server} : ",
      $status->error);
    return;
  }
  my @results = $status->entries;
  foreach my $result (@results) {
    my $userdn = $result->dn;
    my $changes;
    push (@$changes, 'replace', [    'loginShell' => $shell ]) if $shell;
    push (@$changes, 'replace', [ 'homeDirectory' => $home  ]) if $home;
    msg ("changeAccount: of $sciper") if $self->{verbose};
    unless ($self->{fake}) {
      my $status = $self->{ldap}->modify ($userdn, changes => $changes);
      if ($status->code) {
        error ("changeAccount: unable to change account for $userdn on $self->{server} : ",
                $status->error) unless ($status->error =~ /already exists/i);
      }
  }
  }
  $self->changeAutomap ($account);
  return 1;
}

sub lockAccount {
  my ($self, $sciper) = @_;
  $self->changeAccountLock ($sciper, 1);
}

sub unlockAccount {
  my ($self, $sciper) = @_;
  $self->changeAccountLock ($sciper, 0);
}

sub changeAccountLock {
  my ($self, $sciper, $lock) = @_;
  my $actionname = $lock ? 'lockAccount' : 'unlockAccount';
  my @ldapaction = $lock
    ? ( replace => { pwdMustChange => 'TRUE' } )
    : (  delete => 'pwdMustChange' )
    ;
  my $status = $self->{ldap}->search (
      base => 'c=ch',
     scope => 'sub',
    filter => "uniqueIdentifier=$sciper",
  );
  if ($status->code) {
    error ("$actionname: unable to find entry for $sciper on $self->{server} : ",
           $status->error);
    return;
  }
  my @results = $status->entries;
  foreach my $result (@results) {
    my $userdn = $result->dn;
    unless ($self->{fake}) {
      my $status = $self->{ldap}->modify ($userdn, @ldapaction);
      if ($status->code) {
        error ("$actionname: unable to change pwdMustChange for $userdn on $self->{server} : ",
          $status->error) unless ($status->error =~ /(already exists|no such attribute)/i);
      }
    }
  }
  return 1;
}

#
# Automaps.
#

sub addAutomap {
  my ($self, $account) = @_;
  my $automap = $account->{automap} || $account->{defaultmap};
  return unless ($automap && $account->{user});
  my $protocol = $automap->{protocol};
  my   $server = $automap->{server};
  my     $path = $automap->{path};
  my $security = $automap->{security} || 'none';
  my     $user = $account->{user};
  my     $base = 'ou=auto.home,ou=automaps,o=epfl,c=ch';
  return unless ($user && $protocol && $server && $path);

  my $status = $self->{ldap}->search (
      base => $base,
     scope => 'sub',
    filter => "cn=$user",
  );
  if ($status->code) {
    error ("addAutomap: unable to find automap entry for $user on $self->{server} : ",
           $status->error);
    return;
  }
  my @results = $status->entries;
  return if (@results && $results [0]); # Automap already exists
  my $autoinfo = "-fstype=$protocol,proto=tcp,port=2049,sec=$security $server:$path";
  my    $mapdn = "cn=$user,ou=auto.home,ou=automaps,o=epfl,c=ch";

  unless ($self->{fake}) {
    my @attrs = (
                        cn => $user,
      automountInformation => $autoinfo,
               objectClass => 'automount',
    );
    my $status = $self->{ldap}->add ($mapdn, attrs => \@attrs);
    if ($status->code) {
      error ("addAutomap: unable to add $mapdn on $self->{server} : ", $status->error)
        unless ($status->error =~ /already exists/i);
    }
  }
}

sub changeAutomap {
  my ($self, $account) = @_;
  my $automap = $account->{automap} || $account->{defaultmap};
  return unless ($automap && $account->{user});
  my $protocol = $automap->{protocol};
  my   $server = $automap->{server};
  my     $path = $automap->{path};
  my $security = $automap->{security} || 'none';
  my     $user = $account->{user};
  my     $base = 'ou=auto.home,ou=automaps,o=epfl,c=ch';
  return unless ($user && $protocol && $server && $path);

  my $status = $self->{ldap}->search (
      base => $base,
     scope => 'sub',
    filter => "cn=$user",
  );
  if ($status->code) {
    error ("changeAutomap: unable to find automap entry for $user on $self->{server} : ",
           $status->error);
    return;
  }
  my @results = $status->entries;
  return unless @results;
  my  $result = $results [0];
  return unless $result;
  my $autoinfo = "-fstype=$protocol,proto=tcp,port=2049,sec=$security $server:$path";
  my    $mapdn = $result->dn;
  my $changes = ['replace', [ 'automountInformation' => $autoinfo  ], ];
  unless ($self->{fake}) {
    my $status = $self->{ldap}->modify ($mapdn, changes => $changes);
    if ($status->code) {
      error ("changeAutomap: unable to change man for $mapdn on $self->{server} : ",
             $status->error) unless ($status->error =~ /already exists/i);
    }
  }
}

#
#
# Groups.
#
#

sub addGroup {
  my ($self, $group) = @_;
  if (not ref $group) {
    my $grpname = $group;
    $group = $self->{Groups}->getGroup ($grpname);
    unless ($group) {
      error ("addGroup: unknown group : $grpname");
      return;
    }
  }
  return 1 unless $group->{ldap};
  my       $gname = $group->{name};
  my     $groupdn = "cn=$gname,ou=groups,o=epfl,c=ch";
  my     $groupid = $group->{id};
  my $description = $group->{description} || $group->{name};
  error ("addGroup: bad group : $groupid") unless ($groupid && $gname);
  my $cattrs = [
                    cn => $group->{name},
      uniqueIdentifier => $groupid,
             gidnumber => $group->{gid},
           description => $description,
           objectclass => 'groupOfNames',
           objectclass => 'EPFLGroupOfPersons',
  ];
  my @members = @{$group->{members}};
  error ("addGroup: No members in $gname"), return 1 unless @members;
  my @scipers = map { $_->{id} } @members;

  my $accounts;
  foreach my $sciper (@scipers) {
    next unless ($sciper =~ /^\d\d\d\d\d\d$/);
    $accounts->{$sciper} = $self->{Accounts}->getAccount ($sciper);
  }
  my $ownerdn = $self->getUserDN ($group->{owner});
  unless ($ownerdn) {
    error ("addGroup: unable to find owner dn for ($gname, $group->{owner})");
    return;
  }
  my ($attrs, $dns);
  push (@$attrs, @$cattrs);
  push (@$attrs, 'owner', $ownerdn);
  foreach my $sciper (@scipers) {
    unless ($dns->{$sciper}) {
      my @sciperdns = $self->getUserDNs ($sciper);
      unless (@sciperdns) {
        error ("addGroup: unable to find dn for sciper $sciper");
        next;
      }
      $dns->{$sciper} = \@sciperdns;
    }
    push (@$attrs, 'member', $dns->{$sciper}->[0])
      if ($dns->{$sciper} && @{$dns->{$sciper}});
    push (@$attrs, 'memberUid', $accounts->{$sciper}->{user})
      if ($accounts->{$sciper} && $accounts->{$sciper}->{user});
  }
  unless (keys %$dns) {
    error ("addGroup: unable to find dn any member");
    return;
  }
  msg ("addGroup: add $gname") if $self->{verbose};
  unless ($self->{fake}) {
    my $status = $self->{ldap}->add ($groupdn, attrs => $attrs);
    if ($status->code) {
      error ("addGroup: unable to add $groupdn on $self->{server} : ", $status->error)
        unless ($status->error =~ /already exists/i);
      return;
    }
  }
  foreach my $sciper (@scipers) {
    next unless $dns->{$sciper};
    my @sciperdns = @{$dns->{$sciper}};
    next unless @sciperdns;
    foreach my $sciperdn (@sciperdns) {
      msg ("addGroup: add memberOf $gname to $sciper") if $self->{verbose};
      unless ($self->{fake}) {
        my $status = $self->{ldap}->modify ($sciperdn, add => { memberOf => $gname });
        if ($status->code) {
          error ("addGroup: unable to add $sciper in $groupdn on $self->{server} : ",
                 $status->error)
            unless ($status->error =~ /already exists/i);
        }
      }
    }
  }
  return 1;
}

sub deleteGroup {
  my ($self, $nameorid) = @_;
  error ("deleteGroup: bad call") unless $nameorid;
  my $ldgroup = $self->getGroupDN ($nameorid);
  unless ($ldgroup) { # Not there... OK.
    error ("deleteGroup: group not found in LDAP");
    return;
  }
  my $groupdn = $ldgroup->{dn};
  my   $gname = $ldgroup->{name};
  msg ("deleteGroup: Removing group $nameorid on $self->{server}") if $self->{verbose};
  unless ($self->{fake}) {
    my  $status = $self->{ldap}->delete ($groupdn);
    if ($status->code && $self->{verbose}) {
      error ("deleteGroup: unable to remove LDAP entry $groupdn sur le".
              " server LDAP $self->{server} : ", $status->error);
      return;
    }
  }
  my $status = $self->{ldap}->search (
      base => "$self->{ldapserver}->{base}",
     scope => 'sub',
    filter => "(& (memberOf=$gname) (objectclass=person))",
  );
  if ($status->code) {
    error ("deleteGroup: unable to find members of $groupdn on".
            " server LDAP $self->{server} : ", $status->error);
    return;
  }
  my @results = $status->entries;
  foreach my $result (@results) {
    my $userdn = $result->dn;
    msg ("deleteGroup: delete memberof $gname of $userdn") if $self->{verbose};
    unless ($self->{fake}) {
      my $status = $self->{ldap}->modify ($userdn, delete => { memberOf => $gname });
      if ($status->code) {
        error ("deleteGroup: unable to remove member $userdn from group $groupdn on $self->{server} :",
          $status->error) unless ($status->error =~ /already exists/i);
      }
    }
  }
  return 1;
}

sub renameGroup {
  my ($self, $group) = @_;
  if (not ref $group) {
    my $grpname = $group;
    $group = $self->{Groups}->getGroup ($grpname);
    unless ($group) {
      error ("renameGroup: unknown group : $grpname");
      return;
    }
  }
  return 1 unless $group->{ldap};
  my   $gname = $group->{name};
  my $groupid = $group->{id};
  my $ldgroup = $self->getGroupDN ($groupid);
  unless ($ldgroup) {
    error ("renameGroup: unable to find group $gname on $self->{server}");
    return;
  }
  my   $olddn = $ldgroup->{dn};
  my $oldname = $ldgroup->{name};
  msg ("renameGroup: moddn of group $oldname to $gname") if $self->{verbose};
  unless ($self->{fake}) {
    my  $status = $self->{ldap}->moddn ($olddn, newrdn => "cn=$gname", deleteoldrdn => 1);
    if ($status->code) {
      error ("renameGroup: unable to rename $oldname to $gname on $self->{server} : ",
              $status->error) unless ($status->error =~ /already exists/i);
      return;
    }
  }
  my $status = $self->{ldap}->search (
      base => 'c=ch',
     scope => 'sub',
    filter => "(& (memberOf=$oldname) (objectclass=person))",
  );
  if ($status->code) {
    error ("renameGroup: unable to find members of $oldname on $self->{server} : ", $status->error);
    return;
  }
  my @results = $status->entries;
  foreach my $result (@results) {
    my $userdn = $result->dn;
    msg ("renameGroup: rename group $oldname to $gname") if $self->{verbose};
    unless ($self->{fake}) {
      my $status = $self->{ldap}->modify ($userdn,
        delete => { memberOf => $oldname },
           add => { memberOf => $gname },
      );
      if ($status->code) {
        error ("RenameGroup: unable to modify ($oldname => $gname) for $userdn on $self->{server} :",
                $status->error) unless ($status->error =~ /already exists/i);
      }
    }
  }
  return 1;
}

sub updateGroup {
  my ($self, $group) = @_;
  if (not ref $group) {
    my $grpname = $group;
    $group = $self->{Groups}->getGroup ($grpname);
    unless ($group) {
      error ("addGroup: unknown group : $grpname");
      return;
    }
  }
  return 1 unless $group->{ldap};
  my   $gname = $group->{name};
  my $groupdn = "cn=$gname,ou=groups,o=epfl,c=ch";
  my $groupid = $group->{id};
  my $cattrs = [
                  cn => $group->{name},
    uniqueIdentifier => $groupid,
           gidnumber => $group->{gid},
         objectclass => 'groupOfNames',
         objectclass => 'EPFLGroupOfPersons',
  ];
  my $ownerdn = $self->getUserDN ($group->{owner});
  unless ($ownerdn) {
    error ("updateGroup: unable to find owner dn for ($gname, $group->{owner})");
    return;
  }
  my ($attrs, $dns);
  push (@$attrs, @$cattrs);
  push (@$attrs, 'owner', $ownerdn);
  return 1;
}

sub updateMembers {
  my  ($self, $group) = @_;
  if (not ref $group) {
    my $grpname = $group;
    $group = $self->{Groups}->getGroup ($grpname);
    unless ($group) {
      error ("updateGroup: unknown group : $grpname");
      return;
    }
  }
  return 1 unless $group->{ldap};
  msg ("updateMembers of $group->{name}") if $self->{verbose};
  my     $gname = $group->{name};
  my   $groupid = $group->{id};
  my   $groupdn = "cn=$gname,ou=groups,o=epfl,c=ch";
  my   @members = $group->{persons} ? @{$group->{persons}} : ();
  my   @scipers = map { $_->{id} } @members;
  my ($ismember, $memberuids, $maindns, $alldns, $uid2sciper, $dn2sciper);
  foreach my $sciper (@scipers) {
    $ismember->{$sciper} = 1;
  }
  my     @epfl = grep (/^\d/, @scipers);
  my   @guests = grep (/^G/,  @scipers);
  my @services = grep (/^M/,  @scipers);
  
  my @accounts = $self->{Accounts}->getManyAccounts (@epfl);
  foreach my $account (@accounts) {
    my $sciper = $account->{sciper};
    my    $uid = $account->{user};
    $memberuids->{$sciper} = $uid;
    $uid2sciper->{$uid}    = $sciper;
  }
  
  foreach my $sciper (@scipers) {
    if ($sciper =~ /^G\d\d\d\d\d/) { # Guest
      my $guest = $self->{Guests}->getGuest ($sciper);
      next unless $guest;
      my $uid = $guest->{email};
      $memberuids->{$sciper} = $uid;
      $uid2sciper->{$uid}    = $sciper;
    }
    elsif ($sciper =~ /^M\d\d\d\d\d$/) { # Service
      my $service = $self->{Services}->getService ($sciper);
      next unless $service;
      my $uid = $service->{name};
      $memberuids->{$sciper} = $uid;
      $uid2sciper->{$uid}    = $sciper;
    }
    my @memberdns = $self->getUserDNs ($sciper);
    if (@memberdns) {
      $maindns->{$sciper} = $memberdns [0];
      $alldns->{$sciper}  = \@memberdns;
      foreach my $dn (@memberdns) {
        $dn2sciper->{$dn} = $sciper;
      }
    }
  }
  my $ldgroup = $self->getLDAPGroup ($groupid);
  unless ($ldgroup) {
    error ("updateMembers: unable to find group $groupid on $self->{server}");
    return;
  }
  my     $groupdn = $ldgroup->{dn};
  my   $ldmembers = $ldgroup->{member};
  my $lduniqueids = $ldgroup->{lduniqueids};
  my      $lduids = $ldgroup->{lduids};
  my    $memberof = $self->getMemberOfs ($gname);
  #
  # add
  #
  foreach my $sciper (@scipers) {
    my    $maindn = $maindns->{$sciper};
    my $memberuid = $memberuids->{$sciper};
    if ($maindn) {
      unless ($ldmembers->{$maindn}) {
        msg ("updateMembers: add member=$maindn to $gname") if $self->{verbose};
        unless ($self->{fake}) {
          my $status = $self->{ldap}->modify ($groupdn, add => { member => $maindn });
          if ($status->code) {
            error ("updateMembers: unable to add  attribute member $maindn ".
                   "in $gname on $self->{server} : ", $status->error)
              unless ($status->error =~ /already exists/i);
          }
        }
      }
    }
    if ($domemberuniqueid) {
      unless ($lduniqueids->{$sciper}) {
        msg ("updateMembers: add memberUniqueId=$sciper to $gname") if $self->{verbose};
        unless ($self->{fake}) {
          my $status = $self->{ldap}->modify ($groupdn, add => { memberUniqueId => $sciper });
          if ($status->code) {
            error ("updateMembers: unable to add attribute memberUniqueId $sciper ".
                   "in $gname on $self->{server} : ", $status->error)
            unless ($status->error =~ /already exists/i);
          }
        }
      }
    }
    if ($memberuid && !$lduids->{$memberuid}) {
      msg ("updateMembers: add memberUid=$memberuid to $gname for sciper $sciper")
        if $self->{verbose};
      unless ($self->{fake}) {
        my $status = $self->{ldap}->modify ($groupdn, add => { memberUid => $memberuid });
        if ($status->code) {
          error ("updateMembers: unable to add attribute memberUid $memberuid ".
                 "in $gname on $self->{server} : ", $status->error)
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
          error ("updateMembers: unable to delete attribute member $dn ".
                 "in $gname on $self->{server} : ", $status->error)
            unless ($status->error =~ /already exists/i);
        }
      }
    }
  }
  if ($domemberuniqueid) {
    foreach my $sciper (keys %$lduniqueids) {
      unless ($ismember->{$sciper}) {
        msg ("updateMembers: delete memberUniqueId=$sciper from $gname") if $self->{verbose};
        unless ($self->{fake}) {
          my $status = $self->{ldap}->modify ($groupdn, delete => { memberUniqueId => $sciper });
          if ($status->code) {
            error ("updateMembers: unable to delete attribute memberUniqueId $sciper ".
                   "in $gname on $self->{server} : ", $status->error)
              unless ($status->error =~ /already exists/i);
          }
        }
      }
    }
  }
  foreach my $uid (keys %$lduids) {
    my $sciper = $uid2sciper->{$uid};
    unless ($sciper) {
      msg ("updateMembers: delete memberUid=$uid from $gname") if $self->{verbose};
      unless ($self->{fake}) {
        my $status = $self->{ldap}->modify ($groupdn, delete => { memberUid => $uid });
        if ($status->code) {
          error ("updateMembers: unable to delete attribute memberUid $uid ".
                  "in $gname on $self->{server} : ", $status->error)
            unless ($status->error =~ /already exists/i);
        }
      }
    }
  }
  #
  # memberOf
  #
  foreach my $sciper (@scipers) {
    next unless ($sciper =~ /^[GM\d]\d\d\d\d\d$/);
    next unless $alldns->{$sciper};
    my @alldns = @{$alldns->{$sciper}};
    foreach my $dn (@alldns) {
      unless ($memberof->{$sciper}->{$dn}) {
        msg ("updateMembers: add memberof=$gname to $dn") if $self->{verbose};
        unless ($self->{fake}) {
          my $status = $self->{ldap}->modify ($dn, add => { memberOf => $gname });
          if ($status->code) {
            error ("updateMembers: unable to add memberOf=$gname to $dn on $self->{server} : ",
                   $status->error) unless ($status->error =~ /already exists/i);
          }
        }
      }
    }
  }
  foreach my $sciper (keys %$memberof) {
    next unless ($sciper =~ /^[GM\d]\d\d\d\d\d$/);
    next unless $memberof->{$sciper};
    foreach my $dn (keys %{$memberof->{$sciper}}) {
      unless ($dn2sciper->{$dn}) {
        msg ("updateMembers: delete memberof=$gname from $dn") if $self->{verbose};
        unless ($self->{fake}) {
          my $status = $self->{ldap}->modify ($dn, delete => { memberOf => $gname });
          if ($status->code) {
            error ("updateMembers: unable to delete memberOf=$gname from $dn on $self->{server} : ",
                   $status->error) unless ($status->error =~ /already exists/i);
            return;
          }
        }
      }
    }
  }
  return 1;
}

sub addMember {
  my ($self, $group, $sciper) = @_;
  error ("addMember: bad sciper : $sciper")
    unless ($sciper =~ /^\w\d\d\d\d\d$/);
  if (not ref $group) {
    my $grpname = $group;
    $group = $self->{Groups}->getGroup ($grpname);
    unless ($group) {
      error ("addMember: unknown group : $grpname");
      return;
    }
  }
  return 1 unless $group->{ldap};
  my   $gname = $group->{name};
  my $groupid = $group->{id};
  my $account = $self->{Accounts}->getAccount ($sciper);
  my $ldgroup = $self->getGroupDN ($groupid);
  unless ($ldgroup) {
    error ("addMember: unable to find group $gname on $self->{server}");
    return;
  }
  my $groupdn = $ldgroup->{dn};
  my   $gname = $ldgroup->{name};
  my @userdns = $self->getUserDNs ($sciper);
  unless (@userdns) {
    error ("addMember: unable to get dn for sciper $sciper on $self->{server}");
    return;
  }
  my $userdn = $userdns [0];
  my $add = { member => $userdn};
    
  if ($sciper =~ /^G/) { # Guest
    my $guest = $self->{Guests}->getGuest ($sciper);
    unless ($guest) {
      error ("removeMember: unknown guest : $sciper");
      return;
    }
    $add->{memberUid} = $guest->{email};
  }
  elsif ($sciper =~ /^M/) { # Service
    my $service = $self->{Services}->getService ($sciper);
    unless ($service) {
      error ("removeMember: unknown service : $sciper");
      return;
    }
    $add->{memberUid} = $service->{name};
  }
  elsif ($account && $account->{user}) {
    $add->{memberUid} = $account->{user};
  }
  msg ("addMember: add member=$add->{member}, memberUid = $add->{memberUid} ".
       "for $sciper to $gname") if $self->{verbose};
  unless ($self->{fake}) {
    my $status = $self->{ldap}->modify ($groupdn, add => $add);
    if ($status->code) {
      unless ($status->error =~ /already exists/i) {
        error ("AddMember: unable to add $userdn in $gname on ".
               "$self->{server} : ", $status->error);
      }
    }
  }
  foreach my $userdn (@userdns) {
    msg ("addMember: add memberof=$gname to $userdn for$sciper") if $self->{verbose};
    unless ($self->{fake}) {
      my $status = $self->{ldap}->modify ($userdn, add => { memberOf => $gname });
      if ($status->code) {
        unless ($status->error =~ /already exists/i) {
          error ("AddMember: unable to add $groupdn to $userdn on",
                 "$self->{server} : ", $status->error) ;
        }
      }
    }
  }
  return 1;
}

sub removeMember {
  my ($self, $group, $sciper) = @_;
  error ("removeMember: bad sciper : $sciper") unless ($sciper =~ /^\w\d\d\d\d\d$/);
  if (not ref $group) {
    my $grpname = $group;
    $group = $self->{Groups}->getGroup ($grpname);
    unless ($group) {
      error ("removeMember: unknown group : $grpname");
      return;
    }
  }
  return 1 unless $group->{ldap};
  my   $gname = $group->{name};
  my $groupid = $group->{id};
  my $account = $self->{Accounts}->getAccount ($sciper);
  my $ldgroup = $self->getGroupDN ($groupid);
  unless ($ldgroup) { # Not there, no problem.
    error ("removeMember: unable to find group $gname on $self->{server}");
    return;
  }
  my $groupdn = $ldgroup->{dn};
  my   $gname = $ldgroup->{name};
  my @userdns = $self->getUserDNs ($sciper);
  unless (@userdns) {
    error ("removeMember: unable to get dn for sciper $sciper on $self->{server}");
    return;
  }
  my $userdn = $userdns [0];
  my $delete = { member => $userdn };
  if ($sciper =~ /^G/) { # Guest
    my $guest = $self->{Guests}->getGuest ($sciper);
    unless ($guest) {
      error ("removeMember: unknown guest : $sciper");
      return;
    }
    $delete->{memberUid} = $guest->{email};
  }
  elsif ($sciper =~ /^M/) { # Service
    my $service = $self->{Services}->getService ($sciper);
    unless ($service) {
      error ("removeMember: unknown service : $sciper");
      return;
    }
    $delete->{memberUid} = $service->{name};
  }
  elsif ($account && $account->{user}) {
    $delete->{memberUid} = $account->{user};
  }
  msg ("removeMember: remove memberdn of $sciper from $gname") if $self->{verbose};
  unless ($self->{fake}) {
    my $status = $self->{ldap}->modify ($groupdn, delete => $delete);
    if ($status->code) {
      error ("DeleteMember: unable to remove $userdn from $gname on $self->{server} : ",
             $status->error) unless ($status->error =~ /already exists/i);
    }
  }
  foreach my $userdn (@userdns) {
    msg ("removeMember: remove memberof $gname from $userdn") if $self->{verbose};
    unless ($self->{fake}) {
      my $status = $self->{ldap}->modify ($userdn, delete => { memberOf => $gname });
      if ($self->{debug} && $status->code) {
        error ("removeMember: unable to remove $groupdn from $userdn on $self->{server} : ",
               $status->error) unless ($status->error =~ /already exists/i);
      return;
      }
    }
  }
  return 1;
}

sub changeOwner {
  my ($self, $group) = @_;
  if (not ref $group) {
    my $grpname = $group;
    $group = $self->{Groups}->getGroup ($grpname);
    unless ($group) {
      error ("changeOwner: unknown group : $grpname");
      return;
    }
  }
  return 1 unless $group->{ldap};
  my   $gname = $group->{name};
  my   $owner = $group->{owner};
  my $groupid = $group->{id};
  my $ldgroup = $self->getGroupDN ($groupid);
  unless ($ldgroup) {
    error ("changeOwner: unable to find group $gname on $self->{server}");
    return;
  }
  my $groupdn = $ldgroup->{dn};
  my  $ldname = $ldgroup->{name};
  my $ownerdn = $self->getUserDN ($owner);
  unless ($ownerdn) {
    error ("ChangeOwner: unable to find owner for ($group->{name}, $owner)");
    return;
  }
  msg ("changeOwner: change owner of $gname to $owner") if $self->{verbose};
  unless ($self->{fake}) {
    my $status = $self->{ldap}->modify ($groupdn, replace => { owner => $ownerdn });
    if ($status->code) {
      error ("unable to modify owner of $gname on server $self->{server} : ",
             $status->error) unless ($status->error =~ /already exists/i);
      return;
    }
  }
  return 1;
}

sub groupExists {
  my ($self, $group) = @_;
  my $ldgroup = $self->getGroupDN ($group->{id});
  return $ldgroup;
}

#
# Guests
#

sub addGuest {
  my ($self, $guest) = @_;
  if (not ref $guest) {
    my $gstname = $guest;
    $guest = $self->{Guests}->getGuest ($gstname);
    unless ($guest) {
      error ("addGuest: unknown guest : $gstname");
      return;
    }
  }
  error ("addGuest: bad guest : password is missing")  unless $guest->{password};
  error ("addGuest: bad guest : email is missing")     unless $guest->{email};
  error ("addGuest: bad guest : id is missing")        unless $guest->{id};
  error ("addGuest: bad guest : firstname is missing") unless $guest->{firstname};
  error ("addGuest: bad guest : name is missing")      unless $guest->{name};
  error ("addGuest: bad guest : org is missing")       unless $guest->{org};

  my     $email = $guest->{email};
  my    $pwdsha = makesha ($guest->{password});
  my        $id = $guest->{id};
  my $uidnumber = 500000 + $guest->{code};
  my $gidnumber = 500000;
  my     $email = $guest->{email};
  my    $sciper = $guest->{sciper} || sprintf ("S%05d", $id);
  my      $name = fixcase ($guest->{name});
  my $firstname = fixcase ($guest->{firstname});
  my       $org = $guest->{organization};
  my   $guestdn = "cn=$guest->{sciper},o=epfl-guests,c=ch";
  
  my $attrs = [
                      cn => $sciper,
                      cn => "$firstname $name",
                      sn => $name,
                      gn => $firstname,
                       o => 'epfl-guests',
                      ou => [ 'epfl-guests', 'EPFL Guests' ],
    organizationalStatus => "Externe",
        uniqueIdentifier => $sciper,
                    mail => $email,
                     uid => [ $email, $sciper ],
               uidnumber => $uidnumber,
               gidnumber => $gidnumber,
              loginshell => "/bin/bash",
                   gecos => "Guest $email",
           homedirectory => "/home/$sciper",
            userPassword => $pwdsha,
             objectclass => [
                'person',
                'organizationalPerson',
                'EPFLorganizationalPerson',
                'inetOrgPerson',
                'posixAccount',
                'shadowAccount',
              ],
  ];
  msg ("addGuest: add guest $email") if $self->{verbose};
  unless ($self->{fake}) {
    my $status = $self->{ldap}->add ($guestdn, attrs => $attrs);
    if ($status->code) {
      error ("addGuest: unable to add $guestdn on server $self->{server} : ",
             $status->error) unless ($status->error =~ /already exists/i);
      return;
    }
  }
  return 1;
}

sub removeGuest {
  deleteGuest (@_);
}

sub deleteGuest {
  my ($self, $guest) = @_;
  if (not ref $guest) {
    my $gstname = $guest;
    $guest = $self->{Guests}->getGuest ($gstname, 2);
    unless ($guest) {
      error ("addGuest: unknown guest : $gstname");
      return;
    }
  }
  my $dn = "cn=$guest->{sciper},o=epfl-guests,c=ch";
  msg ("deleteGuest: remove guest $guest->{email}") if $self->{verbose};
  unless ($self->{fake}) {
    my $status = $self->{ldap}->delete ($dn);
    if ($status->code && $self->{verbose}) {
      error ("deleteGuest: unable to remove $dn on server $self->{server} : ",
             $status->error);
      return;
    }
  }
  return 1;
}

sub updateGuest {
  my ($self, $guest) = @_;
  if (not ref $guest) {
    my $gstname = $guest;
    $guest = $self->{Guests}->getGuest ($gstname);
    unless ($guest) {
      error ("updateGuest: unknown guest : $gstname");
      return;
    }
  }
  my    $sciper = $guest->{sciper};
  my      $name = fixcase ($guest->{name});
  my $firstname = fixcase ($guest->{firstname});
  my       $org = $guest->{organization};
  my     $email = $guest->{email};
  my    $pwdsha = makesha ($guest->{password});
  my        $dn = "cn=$guest->{sciper},o=epfl-guests,c=ch";
  my   $changes = [
    replace => [           cn => $sciper            ],
        add => [           cn => "$firstname $name" ],
    replace => [           sn => $name              ],
    replace => [           gn => $firstname         ],
    replace => [          uid => $email             ],
    replace => [         mail => $email             ],
    replace => [ userPassword => $pwdsha            ],
  ];
  msg ("updateGuest: update guest $email") if $self->{verbose};
  unless ($self->{fake}) {
    my $status = $self->{ldap}->modify ($dn, changes => $changes);
    if ($status->code) {
      error ("updateGuest: unable to modify $dn on $self->{server} : ",
             $status->error) unless ($status->error =~ /already exists/i);
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
  my   $name = lc $service->{name};
  my     $dn = "cn=$name,ou=services,o=epfl,c=ch";
  my $uniqid = sprintf ('M%05d', $service->{id});
  my  $attrs = [
                        ou => 'services',
                        cn => $name,
                        sn => $name,
                       uid => $name,
          uniqueIdentifier => $uniqid,
               description => $name,
                 uidNumber => $service->{uid} || -1,
                 gidNumber => $service->{gid} || -1,
             homeDirectory => "/home/$name",
              userpassword => $pwdsha,
    swissEduPersonUniqueID => $uniqid . '@epfl.ch',
               objectclass => [
                 'swissEduPerson',
                 'posixAccount',
                 'shadowAccount',
                 'EPFLObject'
               ],
  ];
  msg ("addService: add service $name") if $self->{verbose};
  unless ($self->{fake}) {
    my $ldn = $self->getServiceDN ($name);
    if ($ldn) {
      error ("addService: service $name already in $self->{server}");
      return;
    }
    my $status = $self->{ldap}->add ($dn, attrs => $attrs);
    if ($status->code) {
      error ("addService: unable to add $dn on server $self->{server} : ",
              $status->error) unless ($status->error =~ /already exists/i);
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
    replace => [           sn => $name   ],
    replace => [          uid => $name   ],
    replace => [  description => $name   ],
    replace => [    uidNumber => $uid    ],
    replace => [ userPassword => $pwdsha ],
  ];
  msg ("updateService: update service $name") if $self->{verbose};
  unless ($self->{fake}) {
    my $ldn = $self->getServiceDN ($name);
    if    ($ldn && !$service->{ldap}) {
      my $status = $self->{ldap}->delete ($ldn);
      if ($status->code && $self->{verbose}) {
        error ("updateService: unable to remove $dn on server $self->{server} : ",
               $status->error);
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
               objectclass => [
                 'swissEduPerson',
                 'posixAccount',
                 'shadowAccount',
                 'EPFLObject',
               ],
      ];
      my $status = $self->{ldap}->add ($dn, attrs => $attrs);
      if ($status->code) {
        error ("updateService: unable to add $dn on server $self->{server} : ",
               $status->error) unless ($status->error =~ /already exists/i);
      }
    } else {
      my $status = $self->{ldap}->modify ($dn, changes => $changes);
      if ($status->code) {
        error ("updateService: unable to modify $dn on $self->{server} : ",
               $status->error) unless ($status->error =~ /already exists/i);
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
    if ($dn) {
      my $status = $self->{ldap}->delete ($dn);
      if ($status->code && $self->{verbose}) {
        error ("removeService: unable to remove $dn on server $self->{server} : ",
               $status->error);
        return;
      }
    }
  }
  return 1;
}

sub fixServices {
  my $self = shift;
  my @services = $self->{Services}->listAllServices ();
  unless (@services) {
    error ("fixService: Unable to get services list");
    return;
  }
  foreach my $service (@services) {
    my  $name = $service->{name};
    my $srvid = sprintf ('M%05d', $service->{id});
    my    $dn = "cn=$name,ou=services,o=epfl,c=ch";
    my   $changes = [
      add => [      objectClass => 'EPFLObject' ],
      add => [ uniqueIdentifier => $srvid   ],
    ];
    msg ("fixServices: update service $name") if $self->{verbose};
    unless ($self->{fake}) {
      my $ldn = $self->getServiceDN ($name);
      my $status = $self->{ldap}->modify ($dn, changes => $changes);
      if ($status->code) {
        error ("fixServices: unable to modify $dn on $self->{server} : ",
               $status->error) unless ($status->error =~ /already exists/i);
        return;
      }
    }
  }
  return 1;
}

#
# Utils
#

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

  my $ldap = new Net::LDAPS ($host, port => $port);
  unless ($ldap) {
    error ("unable to contact LDAP server $host:$port");
    return;
  }
  my $status = $ldap->bind (dn => $upddn, password => $updpw, version => 3);
  if ($status->code) {
    error ("unable to bind to LDAP server $host:$port : ", $status->error);
    return;
  }
  return $ldap;
}

sub getGroupDN {
  my ($self, $nameorid) = @_;
  my ($field, $value);
  if ($nameorid =~ /^\d+$/) {
    $field = 'uniqueIdentifier';
    $value = sprintf ("S%05d", $nameorid);
  }
  elsif ($nameorid =~ /^S\d+$/) {
    $field = 'uniqueIdentifier';
    $value = $nameorid;
  } else {
    $field = 'cn';
    $value = $nameorid;
  }
  my $status = $self->{ldap}->search (
      base => 'ou=groups,o=epfl,c=ch',
     scope => 'sub',
    filter => "($field=$value)",
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
      base => 'c=ch',
     scope => 'sub',
    filter => "(& (uniqueIdentifier=$sciper) (objectclass=person))",
  );
  return if $status->code;
  my @results = $status->entries;
  return unless @results;
  return $results [0]->dn;
}

sub getUserDNs {
  my ($self, $sciper) = @_;
  my @dns;
  my $status = $self->{ldap}->search (
      base => "c=ch",
     scope => 'sub',
    filter => "(& (uniqueIdentifier=$sciper) (objectclass=person))",
     attrs => [ 'uniqueIdentifier' ],
  );
  return if $status->code;
  if ($status->code) {
    error ("Unable to search dn for $sciper : ", $status->error);
    return;
  }
  my @results = $status->entries;
  return unless @results;
  foreach my $result (@results) {
    push (@dns, $result->dn);
  }
  return @dns;
}

sub getMemberOfs {
  my ($self, $gname) = @_;
  my $status = $self->{ldap}->search (
      base => "c=ch",
     scope => 'sub',
    filter => "(& (memberof=$gname) (objectclass=person))",
     attrs => [ 'uniqueIdentifier' ],
  );
  if ($status->code) {
    error ("Unable to search memberof for group $gname : ", $status->error);
    return;
  }
  my @results = $status->entries;
  return unless @results;
  my $memberof;
  foreach my $result (@results) {
    my $sciper = $result->get_value ('uniqueidentifier');
    $memberof->{$sciper}->{$result->dn} = 1;
  }
  return $memberof;
}

sub getLDAPGroup {
  my ($self, $groupid) = @_;
  my $status = $self->{ldap}->search (
      base => "c=ch",
     scope => 'sub',
    filter => "(& (uniqueIdentifier=$groupid) (objectclass=groupOfNames))",
  );
  if ($status->code) {
    error ("Unable to search group $groupid : ", $status->error);
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
  $ldgroup->{owner} = $result->get_value ('owner');
  $ldgroup->{gid}   = $result->get_value ('gidNumber');
  return $ldgroup;
}

sub getUnitDN {
  my ($self, $unite) = @_;
  my $status = $self->{ldap}->search (
      base => "c=ch",
     scope => 'sub',
    filter => "(& (uniqueIdentifier=$unite) (objectclass=organizationalUnit))",
     attrs => ['description'],
  );
  if ($status->code) {
    error ("Unable to search unit $unite : ", $status->error);
    return;
  }
  my @results = $status->entries;
  return unless @results;
  return $results [0]->dn;
}

sub getServiceDN {
  my ($self, $name) = @_;
  my $status = $self->{ldap}->search (
      base => "ou=services,o=epfl,c=ch",
     scope => 'sub',
    filter => "(cn=$name)",
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

sub fixcase {
  my $string = shift;
  $string =~ tr/A-Z/a-z/;
  if ($string =~ /^(.*)([- ,\/]+)(.*)$/) {
    #my ($a, $b, $c) = ($1, $2, $3);
    $string = fixcase1 ($1) . $2 . fixcase1 ($3);
  } else {
    substr ($string, 0, 1) =~ tr/a-z/A-Z/;
  }
  return $string;
}

sub fixcase1 {
  my $string = shift;
  $string =~ tr/A-Z/a-z/;
  if ($string =~ /^(.*)([- ,\/]+)(.*)$/) {
    my ($a, $b, $c) = ($1, $2, $3);
    $string = fixcase1 ($a) . $b . fixcase1 ($c);
  } else {
    substr ($string, 0, 1) =~ tr/a-z/A-Z/
      unless ($string =~ /^(a|au|des|der|de|du|en|et|zur|le|la|les|sur|von|van|la)$/);
  }
  return $string;
}

sub error {
  my $msg = join (' ', @_);
  my $now = scalar localtime;
  warn "[$now] [LDAP] $msg.\n";
}

sub msg {
  my $msg = join (' ', @_);
  my $now = scalar localtime;
  warn "[$now] [LDAP] $msg.\n";
}

1;
