#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Persons.pm
# Description:  Accès à la base de données CADI des personnes
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Wed Nov 12 12:07:13 CET 2014
# Revision:     
#
##############################################################################
#
package Accred::Local::Persons;
#
use strict;
use utf8;
use Unicode::Normalize;

use lib qw(/opt/dinfo/lib/perl);
use Accred::Local::LocalDB;

our $errmsg;

sub new {
  my ($class, $args) = @_;
  my  $self = {
            utf8 => 1,
          errmsg => undef,
            fake => 0,
           debug => 0,
         verbose => 0,
           trace => 1,
  };
  foreach my $arg (keys %$args) {
    $self->{$arg} = $args->{$arg};
  }
  
  unless ($self->{dinfodb}) {
    $self->{dinfodb} = new Accred::Local::LocalDB (
      dbname => 'dinfo',
       trace => $self->{trace},
        utf8 => $self->{utf8},
    );
    unless ($self->{dinfodb}) {
      $errmsg = "Unable to connect to dinfo database : $Accred::Local::LocalDB::errmsg";
      return;
    }
  }

  unless (eval "use Cadi::Sciper; 1;") {
    $self->{nosciper} = 1;
  }
  unless ($self->{sciperdb} || $self->{nosciper}) {
    $self->{sciperdb} = new Cadi::Sciper ({
      dbname => 'dbi:Oracle:SCIPER',
      dbuser => 'accred/acc080702',
    });
    unless ($self->{sciperdb}) {
      $errmsg = "Unable to connect to SCIPER database : $Cadi::Sciper::errmsg";
      return;
    }
  }
  warn scalar localtime, " new Accred::Local::Persons ().\n" if $self->{verbose};

  $self->{packname} = 'Persons';
  bless $self, $class;
}

sub getPersons {
  my ($self, $persid) = @_;
  return unless $persid;
  
  my @persids = (ref $persid eq 'ARRAY') ? @$persid : ( $persid );
  my      $in = join (', ', map { '?' } @persids);
  my     $sql = qq{
    select dinfo.sciper.sciper as id,
                    nom as ucsurname,
                 prenom as ucfirstname,
                nom_acc as surname,
             prenom_acc as firstname,
             date_naiss as birthdate,
                   sexe as gender,
              nom_usuel as usualsurname,
           prenom_usuel as usualfirstname,
                addrlog as email
      from dinfo.sciper
      left outer join dinfo.emails on dinfo.emails.sciper = dinfo.sciper.sciper
     where dinfo.sciper.sciper in ($in)
  };
  my $sth = $self->dbsafequery ($sql, @persids) || return;
  my $persons;
  while (my $pers = $sth->fetchrow_hashref) {
    my $persid = $pers->{id};
    $pers->{scipfirstname} = $pers->{firstname};
    $pers->{scipsurname}   = $pers->{surname};
    $pers->{firstname}     = $pers->{usualfirstname} if $pers->{usualfirstname};
    $pers->{surname}       = $pers->{usualsurname}   if $pers->{usualsurname};
    $pers->{name}          = $pers->{firstname} . ' ' . $pers->{surname};
    $pers->{rname}         = $pers->{surname}   . ' ' . $pers->{firstname};
    $persons->{$persid}    = $pers;
  }
  $sth->finish;

  my @notfound = grep (!$persons->{$_}, @persids);
  if (@notfound && !$self->{nosciper}) {
    my $morepers = $self->{sciperdb}->getManyPersons (@notfound);
    map { $persons->{$_} = $morepers->{$_} } keys %$morepers;
    if ($morepers && %$morepers) {
      foreach my $persid (keys %$morepers) {
        my $pers = $morepers->{$persid};
        $pers->{birthdate} =~ s/-/./g;
        eval {
          $self->addDinfoPerson ($pers);
        } || warn scalar localtime,
             " Accred::Local::Person: Unable to add $pers->{persid} in cache.\n";
      }
    }
  }
  return (ref $persid eq 'ARRAY') ? $persons : $persons->{$persid};
}
*getPerson = \&getPersons;

sub getPersonFromName {
  my ($self, $name) = @_;
  my $sql = qq{
    select sciper
      from sciper
     where nom = ?
  };
  my $sth = $self->dbsafequery ($sql, $name) || return;
  my @persids;
  while (my ($persid) = $sth->fetchrow_array) {
    push (@persids, $persid);
  }
  $sth->finish;
  return @persids;
}

sub getPersonFromNameLike {
  my ($self, $name) = @_;
  my ($sql, $sth);
  if ($name !~ /^[\w\s\.-]*$/) {
    $name =~ s/\*/.*/g;
    $name = "^$name\$";
     $sql = qq{
       select sciper
         from sciper
        where     nom rlike ?
           or nom_acc rlike ?
     };
     $sth = $self->dbsafequery ($sql, $name, $name) || return;
  } else {
     $sql = qq{
       select sciper from sciper
        where     nom rlike ?
           or     nom rlike ?
           or nom_acc rlike ?
           or nom_acc rlike ?
    };
    $sth = $self->dbsafequery ($sql,
      "^$name", ".*[- ]$name",
      "^$name", ".*[- ]$name",
    ) || return;
  }
  my @persids;
  while (my ($persid) = $sth->fetchrow_array) {
    push (@persids, $persid);
  }
  $sth->finish;
  return @persids;
}

sub getPersonFromNameAndFirstname {
  my ($self, $firstname, $surname) = @_;
  my $sql = qq{
    select sciper
      from sciper
     where prenom = ?
       and    nom = ?
  };
  my $sth = $self->dbsafequery ($sql, $firstname, $surname) || return;
  my @persids;
  while (my ($persid) = $sth->fetchrow_array) {
    push (@persids, $persid);
  }
  $sth->finish;
  return @persids;
}

sub AlreadyExists {
  my ($self, $firstname, $surname, $birthdate, $gender) = @_;
  return if $self->{nosciper};
  return $self->{sciperdb}->AlreadyExists (
    $firstname, $surname, $birthdate, $gender,
  );
}

sub addPerson {
  my ($self, $pers, $author) = @_;
  return if $self->{nosciper};
  unless ($pers->{birthdate} =~ /^(\d\d)-(\d\d)-(\d\d\d\d)$/) {
    $self->{errmsg} = "Bad birth date : $pers->{birthdate}";
    return;
  }
  my $persid = $self->{sciperdb}->addPerson (
    $pers->{firstname}, $pers->{surname},
    $pers->{birthdate}, $pers->{gender}, undef, $author,
  );
  if ($persid <= 0) {
    $self->{errmsg} = $self->{sciperdb}->{errmsg};
    return;
  }
  $pers->{id} = $persid;
  eval {
    $self->addDinfoPerson ($pers);
  } || warn scalar localtime, " Accred::Local::Person: Unable to add $pers->{persid} in cache.\n";

  $self->{notifier}->addPerson ($persid, $author) if $self->{notifier};
  return $persid;
}

sub addDinfoPerson {
  my ($self, $pers) = @_;
  unless ($pers->{ucsurname}) {
    $pers->{ucsurname} = $pers->{surname};
    toUpper ($pers->{ucsurname});
  }
  unless ($pers->{ucfirstname}) {
    $pers->{ucfirstname} = $pers->{firstname};
    toUpper ($pers->{ucfirstname});
  }
  (my $birthdate = $pers->{birthdate}) =~ s/-/./g;

  my $sql = qq{
    replace into sciper set
          sciper = ?,
             nom = ?,
          prenom = ?,
            type = ?,
         nom_acc = ?,
      prenom_acc = ?,
      date_naiss = ?,
            sexe = ?
  };
  my $sth = $self->dbsafequery ($sql,
    $pers->{id},
    $pers->{ucsurname},
    $pers->{ucfirstname},
    7,
    $pers->{surname},
    $pers->{firstname},
    $birthdate,
    $pers->{gender}  
  ) or return;
  $sth->finish;
  return 1;
}

sub modPerson {
  my ($self, $pers, $author) = @_;
  return if $self->{nosciper};
  unless ($pers->{id}) {
    $self->{errmsg} = "No person Id";
    return;
  }
  unless ($pers->{birthdate} =~ /^(\d\d)-(\d\d)-(\d\d\d\d)$/) {
    $self->{errmsg} = "Bad birth date : $pers->{birthdate}";
    return;
  }
  my $status = $self->{sciperdb}->modPerson ($pers->{id},
    $pers->{firstname}, $pers->{surname},
    $pers->{birthdate}, $pers->{gender}, undef, $author,
  );
  if ($status < 0) {
    $self->{errmsg} = $self->{sciperdb}->{errmsg};
    return;
  }
  eval {
    $self->modDinfoPerson ($pers);
  } || warn scalar localtime, " Accred::Local::Person: ",
                              "Unable to modify $pers->{persid} in cache.\n";
  $self->{notifier}->modPerson ($pers->{id}, $author) if $self->{notifier};
  return 1;
}

sub modDinfoPerson {
  my ($self, $pers) = @_;
  unless ($pers->{ucsurname}) {
    $pers->{ucsurname} = $pers->{surname};
    toUpper ($pers->{ucsurname});
  }
  unless ($pers->{ucfirstname}) {
    $pers->{ucfirstname} = $pers->{firstname};
    toUpper ($pers->{ucfirstname});
  }
  (my $birthdate = $pers->{birthdate}) =~ s/-/./g;

  my $sql = qq{
    update sciper set
             nom = ?,
          prenom = ?,
            type = 7,
         nom_acc = ?,
      prenom_acc = ?,
      date_naiss = ?,
            sexe = ?
    where sciper = ?
  };
  my $sth = $self->dbsafequery ($sql,
    $pers->{ucsurname},
    $pers->{ucfirstname},
    $pers->{surname},
    $pers->{firstname},
    $birthdate,
    $pers->{gender},
    $pers->{id},
  ) || return;
  $sth->finish;
  return 1;
}

sub usePerson {
  my ($self, $persid) = @_;
  return if $self->{nosciper};
  $self->{sciperdb}->useSciper ($persid);
  if ($self->{sciperdb}->{errmsg}) {
    $self->{errmsg} = $self->{sciperdb}->{errmsg};
    return;
  }
  return 1;
}

sub lookForDups {
  my ($self, $firstname, $surname, $birthdate) = @_;
  my (%possdups, @possdups);
  my $sql;

  my @firstname_accs = split (/\s/, $firstname);
  my   @surname_accs = split (/\s/, $surname);
  if (@surname_accs) {
    foreach my $na (@surname_accs) {
      my $n = $na; toUpper ($n);
      if (@firstname_accs) {
        foreach my $pa (@firstname_accs) {
          my $p = $pa; toUpper ($p);
          $sql = qq{
            select sciper from sciper
             where (nom_acc        = ? or
                    nom_acc    rlike ? or
                    nom_acc    rlike ? or
                    nom            = ? or
                    nom        rlike ? or
                    nom        rlike ?)
               and (prenom_acc     = ? or
                    prenom_acc rlike ? or
                    prenom_acc rlike ? or
                    prenom         = ? or
                    prenom     rlike ? or
                    prenom     rlike ?)
          };
          my @values = (
            "$na", "[- ]$na.*", "$na\[- ]", "$n", "[- ]$n.*", "$n\[- ]",
            "$pa", "[- ]$pa.*", "$pa\[- ]", "$p", "[- ]$p.*", "$p\[- ]",
          );
          push (@possdups, $self->trydup ($sql, @values));
          my @values = (
            "$pa", "[- ]$pa.*", "$pa\[- ]", "$p", "[- ]$p.*", "$p\[- ]",
            "$na", "[- ]$na.*", "$na\[- ]", "$n", "[- ]$n.*", "$n\[- ]",
          );
          push (@possdups, $self->trydup ($sql, @values));
        }
      }
      if ($birthdate) {
        $sql = qq{
          select sciper from sciper
           where (nom_acc     = ? or
                  nom_acc rlike ? or
                  nom_acc rlike ? or
                  nom         = ? or
                  nom     rlike ? or
                  nom     rlike ?)
             and date_naiss = ?
        };
        my @values = (
          "$na", "[- ]$na.*", "$na\[- ]", "$n", "[- ]$n.*", "$n\[- ]", "$birthdate",
        );
        push (@possdups, $self->trydup ($sql, @values));
      }
      if (!$birthdate && !@firstname_accs) {
        $sql = qq{
          select sciper from sciper
           where (nom_acc     = ? or
                  nom_acc rlike ? or
                  nom_acc rlike ? or
                  nom         = ? or
                  nom     rlike ? or
                  nom     rlike ?)
        };
        my @values = (
          "$na", "[- ]$na.*", "$na\[- ]", "$n", "[- ]$n.*", "$n\[- ]",
        );
        push (@possdups, $self->trydup ($sql, @values));
      }
    }
  }
  if (@firstname_accs && $birthdate) {
    foreach my $pa (@firstname_accs) {
      my $p = $pa; toUpper ($p);
      $sql = qq{
        select sciper from sciper
         where (prenom_acc     = ? or
                prenom_acc rlike ? or
                prenom_acc rlike ? or
                prenom         = ? or
                prenom     rlike ? or
                prenom     rlike ?)
           and date_naiss = ?
      };
      my @values = (
        "$pa", "[- ]$pa.*", "$pa\[- ]", "$p", "[- ]$p.*", "$p\[- ]", "$birthdate",
      );
      push (@possdups, $self->trydup ($sql, @values));
    }
  }
  return unless @possdups;
  my $persons = $self->getPersons (\@possdups);
  my @persons = ();
  foreach my $persid (@possdups) {
    push (@persons, $persons->{$persid});
  }
  return @persons;
}

sub trydup {
  my ($self, $sql, @values) = @_;
  warn "trydup: sql = $sql, values = @values\n" if ($self->{verbose} > 5);
  my $sth = $self->dbsafequery ($sql, @values) or return;
  my @persids;
  while (my @row = $sth->fetchrow_array) {
    push (@persids, $row[0]);
  }
  $sth->finish;
  return @persids;
}

sub searchApprox {
  my ($self, $firstname, $surname, $birthdate, $gender) = @_;
  return () if $self->{nosciper};
  my ($status, $persids) = $self->{sciperdb}->checkPerson (
    $firstname, $surname, $birthdate, $gender
  );
  my @persons = ();
  if ($status > 0) {
    my @persids = split ('\s*,\s*', $persids);
    my $persons = $self->getPersons (\@persids);
    foreach my $persid (keys %$persons) {
      push (@persons, $persons->{$persid});
    }
  }
  return @persons;
}

#
# Camipro
#

sub hasCamiproCard {
  my ($self, $persid) = @_;
  my $sql = qq{
    select camipro
      from bottin
     where sciper = ?
  };
  my $sth = $self->dbsafequery ($sql, $persid) || return;
  my ($camipro) = $sth->fetchrow;
  $sth->finish;
  return $camipro;
}

sub dbsafequery {
  my ($self, $sql, @values) = @_;
  warn "dbsafequery:sql = $sql, values = @values\n" if ($self->{verbose} >= 3);
  
  unless ($self->{dinfodb}) {
    warn scalar localtime, " $self->{packname}::Connecting to dinfo.\n"
      if ($self->{verbose} >= 3);
    $self->{dinfodb} = new Accred::Local::LocalDB (
      dbname => 'dinfo',
       trace => 1,
        utf8 => 1,
    );
  }
  return unless $self->{dinfodb};
  my  $db = $self->{dinfodb};
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    warn scalar localtime, " $self->{packname}::Trying to reconnect..., sql = $sql";
    $sth = $db->prepare ($sql);
    warn scalar localtime, "$self->{packname}::Reconnection failed." unless $sth;
  }
  my $rv = $sth->execute (@values);
  unless ($rv) {
    warn scalar localtime, " $self->{packname}::Trying to reconnect..., sql = $sql";
    $rv = $sth->execute (@values);
    warn scalar localtime, " $self->{packname}::Reconnection failed." unless $rv;
  }
  return $sth;
}

sub errmsg {
  my $self = shift;
  return $self->{errmsg};
}

sub setverbose {
  my ($self, $verb) = @_;
  $self->{verbose} = $verb;
}

sub toUpper {
  $_[0] =~ s/ü/ue/g;
  $_[0] =~ s/ö/oe/g;
  $_[0] =~ s/ä/ae/g;
  $_[0] = Unicode::Normalize::NFKD ($_[0]);
  $_[0] =~ s/\p{NonspacingMark}//g;
  $_[0] = uc $_[0];
}


1;

