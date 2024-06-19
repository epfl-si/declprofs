#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Oracle.pm
# Description:  Module de communication avec la base Oracle.
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Tue Apr  7 17:21:04 CEST 2015
# Revision:     
#
##############################################################################
#
package Cadi::Oracle;
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


use vars qw($errmsg);

my  $dbuser = 'accred/acc080702';

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
    sciperdbname => undef,
      scipertest => 0,
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
  $self->{sciperdbname} ||= $self->{scipertest} ? 'SCIPERTEST' : 'SCIPER';
  $self->{dbname} = "dbi:Oracle:$self->{sciperdbname}";
  
  $self->{verbose}  = $def->{verbose} unless defined $self->{verbose};
  $self->{trace}    = $def->{trace}   unless defined $self->{trace};
  $self->{dbuser} ||= $dbuser;

  warn scalar localtime, " new Cadi::Oracle ($self->{dbname}).\n"
    if $self->{verbose};

  dbconnect ($self);
  unless ($self->{db}) {
    $errmsg = "Cadi::Oracle: Unable to connect do $self->{dbname}";
    return;
  }
  bless $self;
}

sub prepare {
  my ($self, $sql) = @_;
  return $self->{db}->prepare ($sql);
}

sub execute {
  my ($self, $sth, @values) = @_;
  return $sth->execute (@values);
}

sub begin_work {
  my $self = shift;
  return $self->{db}->begin_work
}

sub commit {
  my $self = shift;
  return $self->{db}->commit;
}

sub rollback {
  my $self = shift;
  return $self->{db}->rollback;
}

sub errstr {
  my $self = shift;
  return $self->{db}->errstr;
}

sub dbconnect {
  my $self = shift;
  my $dbname = $self->{dbname};
  my $dbuser = $self->{dbuser};
  my ($user, $pwd) = split (/\//, $dbuser);
  $self->{db} = DBI->connect ($dbname, $user, $pwd, {
             ora_envhp => 0,
           ora_charset => 'AL32UTF8',
          ora_ncharset => 'AL32UTF8',
      ora_taf_function => \&taf_event,
    },
  );
  return unless $self->{db};

  my $sql = qq{alter session set NLS_DATE_FORMAT = 'DD.MM.YYYY'};
  my $sth = $self->{db}->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Cadi::Oracle::connect : Cannot prepare to set ".
                      "NLS_DATE_FORMAT : $DBI::errstr.";
    warn "$self->{errmsg}\n";
    return;
  }
  my $rv = $sth->execute;
  unless ($rv) {
    $self->{errmsg} = "Cadi::Oracle::connect : Cannot execute set ".
                      "NLS_DATE_FORMAT : $DBI::errstr.";
    warn "$self->{errmsg}\n";
    return;
  }
}

sub error {
  my ($self, @args) = @_;
  $self->{errmsg} = sprintf ("Cadi::Oracle: ", @args);
  warn scalar localtime, ' ', $self->{errmsg};
  return;
}

sub taf_event {
  my ($event, $type, $dbh) = @_;
  warn "Cadi::Oracle::taf_event event=$event, type=$type\n";
  return;
}


1;
