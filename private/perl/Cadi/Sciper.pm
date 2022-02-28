#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Sciper2.pm
# Description:  Module de communication avec la base SCIPER.
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Tue Jul 16 09:43:03 CEST 2002
# Revision:     
#
##############################################################################
#
package Cadi::Sciper;
#
use strict;
use utf8;
use Encode;
use Unicode::Normalize;

sub setoraenv {
      $ENV {ORACLE_HOME} = '/usr/lib/oracle/11.2/client64';
  $ENV {LD_LIBRARY_PATH} = '/usr/lib/oracle/11.2/client64/lib';
             $ENV {LANG} = 'en_US';
         $ENV {NLS_LANG} = 'AMERICAN_AMERICA.AL32UTF8';
        $ENV {NLS_NCHAR} = 'AL32UTF8';
  $ENV {NLS_DATE_FORMAT} = 'DD.MM.YYYY';
}

BEGIN {
  setoraenv ();
};

use DBI;
use DBD::Oracle;

my      $kErrBDSciper = -1;
my           $kErrAcs = -2;

my           $kPasErr =  0;
my   $kErrAcsInvalide = -3;
my $kErrAcsPropExiste = -4;

my      $kAssocActive =  1;
my    $kAssocReActive =  2;
my    $kAssocInactive =  3;

my $messages;

use vars qw( $errmsg );

sub new {
  my $class = shift;
  my $args = (@_ == 1) ? shift : { @_ } ;
  my $def = {
        fake => 0,
       debug => 0,
     verbose => 0,
       trace => 1,
  };
  my  $self = {
      dbname => undef,
      dbuser => undef,
          db => undef,
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
  $self->{verbose} = $def->{verbose} unless defined $self->{verbose};
  $self->{trace}   = $def->{trace}   unless defined $self->{trace};

  $self->{dbname} ||= 'dbi:Oracle:SCIPER';
  $self->{dbuser} ||= 'accred/acc080702';
  warn scalar localtime, " new Cadi::Sciper ($self->{dbname}).\n"
    if $self->{verbose};
  dbconnect ($self);
  unless ($self->{db}) {
    $errmsg = "Cadi::Sciper::Unable to connect do $self->{dbname}";
    return;
  }
  bless $self;
}

sub dbconnect {
  my   $self = shift;
  my $dbname = $self->{dbname};
  my $dbuser = $self->{dbuser};
  my ($user, $pwd) = split (/\//, $self->{dbuser});
  $self->{db} = DBI->connect ($self->{dbname}, $user, $pwd, {
             ora_envhp => 0,
           ora_charset => 'AL32UTF8',
          ora_ncharset => 'AL32UTF8',
      #ora_taf_function => $self->{usetaf} ? \&taf_event : undef,
    },
  );
  return unless $self->{db};

  my $sql = qq{alter session set NLS_DATE_FORMAT = 'DD.MM.YYYY'};
  my $sth = $self->{db}->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Cadi::Sciper::dbconnect : Cannot prepare to set ".
                      "NLS_DATE_FORMAT : $DBI::errstr.";
    warn scalar localtime, " $self->{errmsg}\n";
    return;
  }
  my $rv = $sth->execute;
  unless ($rv) {
    $self->{errmsg} = "Cadi::Sciper::dbconnect : Cannot execute set ".
                      "NLS_DATE_FORMAT : $DBI::errstr.";
    warn scalar localtime, " $self->{errmsg}\n";
    return;
  }
}

sub getPersonInfos {
  my ($self, $persid) = @_;
  return $self->getPerson ($persid);
}

sub getPerson {
  my ($self, $persid) = @_;
  unless ($persid =~ /^\d\d\d\d\d\d$/) {
    $self->{errmsg} = "Bad sciper : $persid.";
    warn scalar localtime, " Cadi::Sciper::getPerson: $self->{errmsg}\n";
    return;
  }
  my $sql = qq{select * from v_pe_personne where i_personne = '$persid'};
  my $sth = $self->{db}->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "SCIPER database connection error : $DBI::errstr.";
    warn scalar localtime, " Cadi::Sciper::getPerson: $self->{errmsg}\n";
    return;
  }
  my $ret = $sth->execute;
  unless ($ret) {
    $self->{errmsg} = "SCIPER database connection error : $DBI::errstr.";
    warn scalar localtime, " Cadi::Sciper::getPerson: $self->{errmsg}\n";
    return;
  }
  my @fields = $sth->fetchrow ();
  $sth->finish;
  unless ($fields [0]) {
    $self->{errmsg} = "No result for persid $persid";
    warn scalar localtime, " Cadi::Sciper::getPerson: $self->{errmsg}\n";
    return;
  }
  #
  # Sometimes the utf8 flag is not set by DBI or DBD::Oracle. !!!!
  #
  Encode::_utf8_on ($fields [4]);
  Encode::_utf8_on ($fields [5]);
  Encode::_utf8_on ($fields [10]);
  Encode::_utf8_on ($fields [11]);
  #
  (my $birthdate = $fields [6]) =~ s/\./-/g;
  return {
             id => $fields [0],
           name => $fields [5] . ' ' . $fields [4],
          rname => $fields [4] . ' ' . $fields [5],
        surname => $fields [4],
      firstname => $fields [5],
      ucsurname => $fields [1],
    ucfirstname => $fields [2],
      birthdate => $fields [6],
         gender => $fields [7],
       creation => $fields [8],
            acs => $fields [3],
          nomus => $fields [10],
       prenomus => $fields [11],
  };
}

sub checkPerson {
  my ($self, $firstname, $surname, $birthdate, $gender) = @_;
  my ($personne, $status);

  my $sth = $self->{db}->prepare (q{
    BEGIN
      :status := Sciper_G_Personne.controlePersonneLong
                 (:iNomLong, :iPrenomLong, :iDateNaiss, :iSexe, :oPersonnes);
    END;
  });
  unless ($sth) {
    $self->{errmsg} = "SCIPER database connection error : $DBI::errstr.";
    warn scalar localtime, " Cadi::Sciper::checkPerson: $self->{errmsg}\n";
    return;
  }
  $sth->bind_param (":iNomLong",    $surname);
  $sth->bind_param (":iPrenomLong", $firstname);
  $sth->bind_param (":iDateNaiss",  $birthdate);
  $sth->bind_param (":iSexe",       $gender);
  $sth->bind_param_inout (":oPersonnes", \$personne, 128);
  $sth->bind_param_inout (":status",     \$status,     4);
  $sth->execute;
  return ($status, $personne);
}

sub addPerson {
  my ($self, $firstname, $surname, $birthdate, $gender, $datefin, $author) = @_;
  warn scalar localtime, " addPerson: ($firstname, $surname, $birthdate, $gender, $datefin)"
    if $self->{verbose};
  
  $author ||= 'accred';
  $birthdate =~ s/\./-/g; # dd-mm-yyyy

  my ($persid, $status);
  my $sth = $self->{db}->prepare (q{
    BEGIN
      :status := Sciper_G_Interne.put_acs (:px_ACS);
      :sciper := Sciper_G_Personne.creationPersonneLong
                   (:iUserID, :iNomMin, :iPrenomMin, :iDateNaiss, :iSexe);
    END;
  });
  unless ($sth) {
    $self->{errmsg} = "SCIPER database connection error : $DBI::errstr.";
    warn scalar localtime, "Cadi::Sciper::addPerson: $self->{errmsg}\n";
    return;
  }
  $sth->bind_param (":px_ACS", "accred");
  $sth->bind_param_inout (":status", \$status, 4);
  $sth->bind_param (":iUserID",    $author);
  $sth->bind_param (":iNomMin",    $surname);
  $sth->bind_param (":iPrenomMin", $firstname);
  $sth->bind_param (":iDateNaiss", $birthdate);
  $sth->bind_param (":iSexe",      $gender);
  $sth->bind_param_inout (":sciper", \$persid, 8);
  $sth->execute;
  
  if (!$persid || ($persid <= 0)) {
    if ($persid == -6) {
      $self->{errmsg} = "Cadi::Sciper: Bad Birth Date : $birthdate";
    }
    elsif ($persid == -7) {
      $self->{errmsg} = "Cadi::Sciper: Names are not uppercase";
    } else {
      $self->{errmsg} = "Cadi::Sciper: Unknown return status : $persid";
    }
  }
  
  return $persid;
}

#  1 SAC    SAC    SERVICE ACADEMIQUE                   1     
#  2 GESPER GESPER GESTION DU PERSONNEL                 1     
#  3 GDI    GDI    GESTION ET DIFFUSION INFORMATIQUE SA 1     
#  5 SIC    SIC    SERVICE INFORMATIQUE CENTRAL         1  03-MAR-00   
#  4 SID    SID    SERVEUR IDENTIFICATION CAMIPRO       1     
#  6 PER    PER    PERSONNEL EPFL                       1  13-DEC-00 SCIPER  
#  7 ACCRED ACCRED BUREAU D'ACCREDITATION               1   
  
sub modPerson {
  my ($self, $persid, $firstname, $surname, $birthdate, $gender, $datefin, $author) = @_;
  my ($status1, $status2);
  warn scalar localtime, " ModifyPersonne: ($persid, $firstname, $surname, $birthdate, ",
    "$gender, $datefin).\n" if $self->{verbose};
  $self->ReprisePersonne ($persid); # On essaye de reprendre la personne si elle est libre.
  
  my $pe_acs = $self->getACS ();
  my $person = $self->getPerson ($persid);
  return -1 unless $person;
  my  $i_acs = $person->{acs};
  my $px_acs = $pe_acs->{$i_acs};
  if ($px_acs !~ /^accred$/i) {
    $self->{errmsg} = "Ce numéro Sciper n'appartient pas à Accred, il appartient ".
      "à l'application '$px_acs' ($i_acs), vous ne pouvez donc pas le modifier.";
    return -1;
  }
  $author ||= 'accred';
  my $sth = $self->{db}->prepare (q{
    BEGIN
      :status1 := Sciper_G_Interne.put_acs (:px_ACS);
      :status2 := Sciper_G_Personne.mutationPersonneLong
                         (:iUserID, :iNLU, :iNomMin, :iPrenomMin, :iDateNaiss, :iSexe);
    END;
  });
  unless ($sth) {
    $self->{errmsg} = "SCIPER database connection error : $DBI::errstr.";
    return;
  }
  $sth->bind_param (":px_ACS", $px_acs);
  $sth->bind_param_inout (":status1", \$status1, 4);
  $sth->bind_param (":iUserID",    $author);
  $sth->bind_param (":iNLU",       $persid);
  $sth->bind_param (":iNomMin",    $surname);
  $sth->bind_param (":iPrenomMin", $firstname);
  $sth->bind_param (":iDateNaiss", $birthdate);
  $sth->bind_param (":iSexe",      $gender);
  $sth->bind_param_inout (":status2", \$status2, 4);
  $sth->execute;
  if ($status2 < 0) {
    $self->{errmsg} = "Error with SCIPER database : status = $status2";
    return $status2;
  }
  return 1;
}

sub getManyPersonsInfos {
  return getManyPersons (@_);
}

sub getManyPersons {
  my ($self, @persids) = @_;
  return unless @persids;
  my @goodpersids;
  foreach my $persid (@persids) {
    push (@goodpersids, $persid) if ($persid =~ /^\d\d\d\d\d\d$/);
  }
  return unless @goodpersids;
  my $constraint = join (' or i_personne = ', @goodpersids);
  my $sql = qq{
    select *
      from v_pe_personne
     where i_personne = $constraint
  };
  my $sth = $self->{db}->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "SCIPER database connection error : $DBI::errstr.";
    warn "Cadi::Sciper::getManyPersonsInfos: $self->{errmsg}\n";
    return;
  }
  $sth->execute;
  my $persons;
  while (my ($persid, $ucsurname, $ucfirstname, $acs,
             $nomacc, $pnomacc, $ne, $gender) = $sth->fetchrow) {
    $persons->{$persid} = {
               id => $persid,
             name => $pnomacc . ' ' . $nomacc,
            rname => $nomacc . ' ' . $pnomacc,
          surname => $nomacc,
        firstname => $pnomacc,
        ucsurname => $ucsurname,
      ucfirstname => $ucfirstname,
        birthdate => $ne,
           gender => $gender,
              acs => $acs,
    };
  }
  $sth->finish;
  return $persons;
}

sub useSciper { # Exported
  my ($self, $sciper) = @_;
  my $db = $self->{db};
  unless ($db) {
    $self->{errmsg} = "Cadi::Sciper::useSciper : uninitialized db.";
    return;
  }
  my ($status1, $status2);
  my $csr = $db->prepare (q{
    BEGIN
      :status1 := Sciper_G_Interne.put_acs (:px_ACS);
      :status2 := Sciper_G_Personne.utilisePersonne (:iUserID, :iNLU, NULL, NULL);
    END;
  });
  $csr->bind_param (":px_ACS", $self->{acs});
  $csr->bind_param_inout (":status1", \$status1, 4);

  $csr->bind_param (":iUserID", $self->{acs});
  $csr->bind_param (":iNLU",    $sciper);
  $csr->bind_param_inout (":status2", \$status2, 4);
  $csr->execute;
  return $status2;
}

sub releaseSciper { # Exported
  my ($self, $sciper) = @_;
  my $db = $self->{db};
  unless ($db) {
    $self->{errmsg} = "Cadi::Sciper::releaseSciper : uninitialized db.";
    return;
  }
  my ($status1, $status2);
  my $csr = $db->prepare (q{
    BEGIN
      :status1 := Sciper_G_Interne.put_acs (:px_ACS);
      :status2 := Sciper_G_Personne.utilisePersonne (:iUserID, :iNLU, SYSDATE, NULL);
    END;
  });
  $csr->bind_param (":px_ACS", $self->{acs});
  $csr->bind_param_inout (":status1", \$status1, 4);

  $csr->bind_param (":iUserID",   $self->{acs});
  $csr->bind_param (":iNLU",      $sciper);
  $csr->bind_param_inout (":status2", \$status2, 4);
  $csr->execute;
  return $status2;
}

sub AlreadyExists {
  my ($self, $firstname, $surname, $birthdate, $gender) = @_;
  my $db = $self->{db};
  unless ($db) {
    $self->{errmsg} = "Cadi::Sciper::AlreadyExists : uninitialized db.";
    return;
  }
  my $status;
  my $csr = $db->prepare (q{
    BEGIN
      :status := Sciper_G_Personne.controleDoublonLong_Parfait
                   (:iNom, :iPrenom, :iDateNaiss, :iSexe);
    END;
  });
  $csr->bind_param (":iNom",       $surname);
  $csr->bind_param (":iPrenom",    $firstname);
  $csr->bind_param (":iDateNaiss", $birthdate);
  $csr->bind_param (":iSexe",      $gender);
  $csr->bind_param_inout (":status", \$status, 4);
  $csr->execute;
  return $status;
}

sub ReprisePersonne { # Exported
  my ($self, $persid) = @_;
  my ($status1, $status2);
  my $sth = $self->{db}->prepare (q{
    BEGIN
      :status1 := Sciper_G_Interne.put_acs (:px_ACS);
      :status2 := Sciper_G_Personne.ReprisePersonne (:iUserID, :iNLU);
    END;
  });
  unless ($sth) {
    $self->{errmsg} = "SCIPER database connection error : $DBI::errstr.";
    warn scalar localtime, ", Cadi::Sciper::ReprisePersonne: $self->{errmsg}\n";
    return;
  }
  $sth->bind_param (":px_ACS", "accred");
  $sth->bind_param_inout (":status1", \$status1, 4);
  $sth->bind_param (":iUserID", "accred");
  $sth->bind_param (":iNLU",    $persid);
  $sth->bind_param_inout (":status2", \$status2, 4);
  $sth->execute;
  return $status2;
}

sub toUpper {
  $_[0] =~ s/ü/ue/g;
  $_[0] =~ s/ö/oe/g;
  $_[0] =~ s/ä/ae/g;
  $_[0] = Unicode::Normalize::NFKD ($_[0]);
  $_[0] =~ s/\p{NonspacingMark}//g;
  $_[0] = uc $_[0];
}

sub getACS {
  my $self = shift;
  my $pe_acs;
  my $db = $self->{db};
  unless ($db) {
    $self->{errmsg} = "Cadi::Sciper::getACS : uninitialized db.";
    return;
  }
  my $sql = "select I_ACS,X_ACS_ABR from V_PE_ACS";
  my $sth = $db->prepare ($sql) || do {
    warn scalar localtime, " getACS:prepare : $DBI::errstr";
    return;
  };
  $sth->execute || do {
    warn scalar localtime, " getACS:execute : $DBI::errstr";
    return;
  };
  while (my ($i_acs, $x_acs_abr) = $sth->fetchrow) {
    $pe_acs->{$i_acs} = $x_acs_abr;
  }
  $sth->finish;
  return $pe_acs;
}

sub putAcs {
  my ($self, $acs) = @_;
  my $db = $self->{db};
  unless ($db) {
    $self->{errmsg} = "Cadi::Sciper::putAcs : uninitialized db.";
    return;
  }
  my $status;
  my $csr = $db->prepare (q{
       BEGIN
         :status := Sciper_G_Interne.put_acs (:px_ACS);
       END;
     });
  $csr->bind_param (":px_ACS", $acs);
  $csr->bind_param_inout (":status", \$status, 4);
  $csr->execute;
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
    dberror => {
      fr => "Unable to access database : %s.",
      en => "Impossible d'accéder à la base de données : %s.",
    },
  };
}

sub error {
  my ($self, $sub, $msgcode, @args) = @_;
  my  $msghash = $messages->{$msgcode};
  my $language = $self->{language} || 'en';
  my  $message = $msghash->{$language};
  $self->{errmsg} = sprintf ("$sub : $message", @args);
  return;
}

sub taf_event {
  my ($event, $type, $dbh) = @_;
  warn scalar localtime, " Cadi::Sciper::taf_event event=$event, type=$type\n";
  return;
}


1;
