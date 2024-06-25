#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Request.pm
# Description:  
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Tue Jul  9 14:20:42 CEST 2002
# Revision:     
#
##############################################################################
#
#
package Accred::Requests;
#
use strict;
use utf8;

use Encode;
use Tequila::Client;

use Accred::Config;
use Accred::AccredDB;
use Accred::Utils;
use Accred::Messages;
use Accred::Units;
use Accred::Positions;
use Accred::Rights;
use Accred::RightsAdmin;
use Accred::Roles;
use Accred::RolesAdmin;
use Accred::Properties;
use Accred::Logs;
use Accred::Local::Notifier;

my $defaultlang = 'fr';
my $maintenance = 0;
my $noauthcommands = {
          help => 1,
      userinfo => 1,
      unitinfo => 1,
     loggedout => 1,
  adminsofunit => 1,
};
my $needscsrfshield;


sub new { # Exported
  my ($class, $args) = @_;
  my  $self = {
                 me => undef,
                 us => undef,
                 qs => undef,
                 pi => undef,
               args => undef,
             cgidir => undef,
            version => '3.2',
            tequila => undef,
       authentified => undef,
            dateref => undef,
               test => undef,
               warn => undef,
             unitid => undef,
             userid => undef,
         realuserid => undef,
              devel => undef,
          unitnames => undef,
            verbose => undef,
          otheroots => undef,
          unitroots => undef,
         superadmin => undef,
          admanager => undef,
             client => undef,
           redirect => undef,
  };
  bless $self, $class;
  warn scalar localtime, " new Request.\n" if $self->{verbose};
  Accred::Utils::import ();
  initcsrf ();
  $self->init ();
  return $self;
}

sub init {
  my $self = shift;
  $self->setlanguage ();
  $self->{epflroots} = 10000;
  $self->{otheroots} = [10582, 3199, 11390, ];
  $self->{unitroots} = [10000, 10582, 3199, 11390, ];
  $self->loadargssyntaxes ();
  
  my    $uri = $ENV {REQUEST_URI};
  my     $us = $ENV {SERVER_NAME};
  my     $pi = $ENV {PATH_INFO};
  my     $qs = $ENV {QUERY_STRING};
  my $client = $ENV {REMOTE_ADDR};
  my     $me = $ENV {SCRIPT_URL}; $me =~ s/$pi$//;

  my @me = split (/\//, $me);
  my @cgidir;
  shift @me;
  while (my $rep = shift @me) {
    last if ($rep =~ /\.pl$/);
    push (@cgidir, $rep);
  }
  my $cgidir = join ('/', @cgidir);
  $cgidir = '/' . $cgidir if $cgidir;

  $pi =~ s/^\///;
  my ($command, @pis) = split (/\//, $pi);
  
  foreach my $p (@pis) {
    if ($p =~ /^([^=]*)=(.*)$/) {
      $self->{modifiers}->{$1} = $2;
    } else {
      $self->{modifiers}->{$p} = 1;
    }
  }
  $self->{command} = $command;
  $self->{pi}      = $pi;
  $self->{uri}     = $uri;
  $self->{me}      = $me;
  $self->{us}      = $us;
  $self->{qs}      = $qs;
  $self->{client}  = $client;
  $self->{cgidir}  = $cgidir;
  $self->{remaddr} = $ENV {REMOTE_ADDR};

  my ($tequila, $args);
  if ($ENV {SERVER_NAME}) {
    $tequila = new Tequila::Client (
      sessionmax => 86400,
         service => 'accred',
      cookiename => 'Accred_Session',
         request => [ 'name', 'firstname', 'uniqueid', ],
       urlaccess => "https://$us/",
       logouturl => "http://$us/accreds.pl/loggedout",
    );
    $tequila->init ();
    $args = $tequila->{appargs};
    foreach my $arg (keys %$args) {
      $args->{$arg} = decode ('utf-8', $args->{$arg});
    }
    $self->{tequila} = $tequila;
  }
  
  my $cookies = $ENV {HTTP_COOKIE};
  if ($cookies) {
    foreach my $cookie (split (/; /, $cookies)) {
      if ($cookie =~ /^accred::([^=]*)=(.*)$/) {
        $args->{$1} = $2;
      }
    }
  }
  checkargs  ($self, $args);
  loadaccredconf ($self);
  my $execmode = $self->{accredconf}->{execmode} || 'none';
  $self->{execmode} = $execmode;
  $self->{notifier} = new Accred::Local::Notifier ($self);

  my $dateref = $args->{dateref};
  $dateref = undef if ($dateref eq 'now');
  $dateref = undef unless checkdateref ($dateref);
  $self->{dateref} = $dateref;

  my @modules = (
    'Config', 'AccredDB', 'Accreds', 'Persons', 'Units',
    'Roles', 'RolesAdmin', 'Rights', 'RightsAdmin', 'Logs',
    'Positions', 'Properties', 'PropsAdmin', 'UnitsAdmin',
    'Summary', 'Workflows', 'InternalWorkflow', 'Notifications',
  );
  foreach my $module (@modules) {
    my $lcmodule = lc $module;
    $self->{$lcmodule} = "Accred::$module"->new ($self);
    unless ($self->{$lcmodule}) {
      my $errmsg = $self->{$lcmodule . 'err'};
      error ($self, "Unable to initialize module $module : $errmsg");
    }
  }

  my $userid;
  if ($pi =~ /^logout/) {
    $tequila->globallogout () if $tequila;
    $userid = '';
    return 1;
  }
  $self->{noauth} = $noauthcommands->{$command};

  if ($self->isauthenticated ()) {
    $userid = $self->{tequila}->{attrs}{uniqueid};
  }
  elsif (!$self->{noauth}) {
    $userid = $self->authenticate ();
    error ($self, msg('BadUser', $tequila->{user})) unless $userid;
  }
  my $realuserid = $self->{realuserid} = $userid;

  my $superrights = $self->{accreds}->loadSuperRights ();
  my  $superadmin = $userid && $superrights->{su}->{$execmode}->{$realuserid};

  if ($superadmin && $args->{userid}) {
    $userid = $args->{userid};
  }
  return 1 unless ($userid || $self->{noauth});
  $self->{authentified} = 1;
  $self->{userid}       = $userid;

  my         $su = $userid && $superrights->{su}      ->{$execmode}->{$userid};
  my  $admanager = $userid && $superrights->{ad}      ->{$execmode}->{$userid};
  my $timemaster = $userid && $superrights->{tm}      ->{$execmode}->{$userid};
  my    $auditor = $userid && $superrights->{audit}   ->{$execmode}->{$userid};

  my  $user = $self->{persons}->getPerson ($userid);
  my $uname = $user->{name};

  if ($args->{unitname}) {
    my $uname = $args->{unitname};
    my  $unit = $self->{units}->getUnitFromName ($uname);
    error ($self, msg('UnknownUnit', $uname)) unless $unit;
    $args->{unitid} = $unit->{id};
    $args->{unit}   = $unit;
  }
  elsif ($args->{unitid}) {
    my $unitid = $args->{unitid};
    my   $unit = $self->{units}->getUnit ($unitid);
    error ($self, msg('UnknownUnit', $unitid)) unless $unit;
    $args->{unitname} = $unit->{name};
    $args->{unitid}   = $unit->{id};
    $args->{unit}     = $unit;
  }

  my $pers;
  $args->{persid} ||= $args->{thescip};
  if ($args->{persid} && ($args->{persid} ne '000000')) {
    $pers = $self->{persons}->getPerson ($args->{persid});
  }
  
  $self->{userid}     = $userid;
  $self->{unitid}     = $args->{unitid};
  $self->{unit}       = $args->{unit};
  $self->{uname}      = $args->{unitname};
  $self->{persid}     = $args->{persid};
  $self->{pers}       = $pers;
  $self->{dateref}    = $dateref;
  $self->{superadmin} = $superadmin;
  $self->{su}         = $su;
  $self->{admanager}  = $admanager;
  $self->{timemaster} = $timemaster;
  $self->{auditor}    = $auditor;
  $self->{now}        = !$dateref;
  $self->{args}       = $args;

  $self->checkcsrftoken () if needscsrfshield ($command);
  return 1;
}

sub loadaccredconf {
  my $self = shift;
  my $accredconf;
  my $docroot = $ENV {DOCUMENT_ROOT};
  error ($self, msg('InternalError', 'No document root')) unless $docroot;
  $docroot =~ s/(htdocs|html)$/private/;
  open (ACCREDCONF, "$docroot/Accred.conf") || error ($self, msg('No config file.'));
  while (<ACCREDCONF>) {
    chomp; s/#.*$//; next if /^$/;
    if (/^ExecMode:\s*(.*)$/) {
      $accredconf->{execmode} = $1;
    }
    elsif (/^Workflow:\s*(.*)$/) {
      $accredconf->{workflow} = $1;
    }
    elsif (/^SAPWorkflowsUser:\s*(.*)$/) {
      $accredconf->{sapworkflowsuser} = $1;
    }
    elsif (/^SAPWorkflowsPass:\s*(.*)$/) {
      $accredconf->{sapworkflowspass} = $1;
    }
  }
  close (ACCREDCONF);
  $self->{accredconf} = $accredconf;
}

sub setlanguage {
  my $self = shift;
  my $cookies = $ENV {HTTP_COOKIE};
  if ($cookies) {
    my $lang;
    foreach my $cookie (split (/; /, $cookies)) {
      if ($cookie =~ /^accreds_lang=(.*)$/) {
        $lang = $1;
        last;
      }
    }
    if ($lang) {
      $lang = $defaultlang unless ($lang =~ /^(fr|en)$/);
      $self->{language} = $lang;
    }
  }
  unless ($self->{language}) {
    my $preflang = $ENV {HTTP_ACCEPT_LANGUAGE};
    if ($preflang) {
      my $lang;
      foreach my $l (split (/,/, $preflang)) {
        $lang = 'fr', last if ($l =~ /^fr/);
        $lang = 'en', last if ($l =~ /^en/);
      }
      if ($lang) {
        $self->{language} = $lang;
      }
    }
  }
  unless ($self->{language}) {
    $self->{language} = $defaultlang;
  }
  $self->{lang} = $self->{language};
  Accred::Messages::setlanguage ($self);
}

sub logout {
  my $self = shift;
  $self->{tequila}->killsession ($self->{key});
  print qq{
         <br>
         <h3> }.msg('LogoutMessage', $self->{me}).qq{</h3>
  };
}

sub authenticate {
  my $self = shift;
  if ($self->{modifiers}->{embedded}) {
    Accred::Utils::head ($self);
    my $loginurl = "$self->{cgidir}/main.pl";
    print qq{X-HTTP-Target: page\n\n};
    print qq{
      <input type="button"
               id="loginbutton"
            value="Session expired, click to login"
          onclick="document.location.href = '$loginurl';">
    };
    tail ($self);
  }
  $self->{tequila}->authenticate ();
  my $user = $self->{tequila}->{user};
  if ($user =~ /^(.*)@([^\.]*)$/) {
    $user = $1;
  }
  return $self->{tequila}->{attrs}{uniqueid};
}

sub isauthenticated {
  my $self = shift;
  return unless ($self && $self->{tequila});
  my $isauthenticated = $self->{tequila}->authenticated ();
  return $isauthenticated;
}

sub checkdateref {
  my $dateref = shift;
  return unless $dateref;
  my ($aref, $mref, $jref) = ($dateref =~ /^(\d*)-(\d*)-(\d*).*$/);
  return unless ($aref && $mref && $jref);
  use Time::Local;
  my $timeref = timelocal (0, 0, 12, $jref, $mref - 1, $aref);
  return if ($timeref > time);
  return if ($aref < 2005);
  return 1;
}

sub checkargs {
  my ($self, $args) = @_;

  foreach my $arg (keys %$args) {
    if ($arg =~ /^comment$/) {
      escape ($args->{$arg});
      next;
    }
    my $value = $args->{$arg}; next unless $value;
    my $msg = msg ('BadValueForType', $arg, $value);
    foreach my $syntaxname (keys %{$self->{argssyntaxes}}) {
      my $syntax = $self->{argssyntaxes}->{$syntaxname};
      if ($arg =~ $syntax->{name}) {
        my @valsyntaxes = (ref $syntax->{value} eq 'ARRAY')
          ? @{$syntax->{value}}
          : ($syntax->{value})
          ;
        my $ok;
        foreach my $valsyntax (@valsyntaxes) {
          if ($value =~ $valsyntax) {
            $ok = 1;
            last;
          }
        }
        error ($self, $msg) unless $ok;
        return;
      }
    }
    escape ($args->{$arg});
  }
}

sub loadargssyntaxes {
  my $self = shift;
  $self->{argssyntaxes} = {
    persname => {
       type => 'Person name',
       name => qr/^(pers|sur|first)name$/,
      value => qr/^[[:alpha:] \'\.-]+$/,
    },
    persid => {
       type => 'Sciper',
       name => qr/^persid$/,
      value => qr/^\d\d\d\d\d\d$/,
    },
    unitid => {
       type => 'Unit Id',
       name => qr/^unitid$/,
      value => qr/^(FC|FF)?\d+$/,
    },
    unitname => {
       type => 'Person name',
       name => qr/^unitname$/,
      value => qr/^[[:alnum:] \'\.-]+$/,
    },
    objectid => {
       type => 'Object Id',
       name => qr/^(role|right|status|class|pos|prop|deput)id$/,
      value => qr/^\d+$/,
    },
    dateaccred => {
       type => 'Date',
       name => qr/^date(deb|fin)$/,
      value => [
        qr/^\d\d\d\d-\d\d-\d\d( \d\d:\d\d:\d\d)?$/,
        qr/^\d\d\-\w+-\d\d\d\d( \d\d:\d\d:\d\d)?$/,
      ],
    },
    refdate => {
       type => 'Date',
       name => qr/^refdate$/, # 11-Oct-2016
      value => qr/^(\d\d?)-(\w+)-(\d\d\d\d)$/,
    },
    dateindex => {
       type => 'Day, Month or Year',
       name => qr/^(j|m|a)(deb|fin)$/,
      value => qr/^\d+$/,
    },
    dateindex2 => {
       type => 'Person name',
       name => qr/^(day|month|year)$/,
      value => qr/^\d+$/,
    },
    accreds => {
       type => 'Accreds',
       name => qr/^accreds$/,
      value => qr/^(\d+[:,]?)+$/,
    },
    order => {
       type => 'Order',
       name => qr/order$/,
     value => qr/^([[:alnum:] \'\.-]+[\s*,\s*]?)+$/,
    },
    confirm => {
       type => 'Confirmation',
       name => qr/^confirm.*$/,
      value => qr/^\d+$/,
    },
    rolerightid => {
       type => 'Role / Right Id',
       name => qr/^(role|right)select$/,
      value => qr/^\d+$/,
    },
    csrftoken => {
       type => 'CSRFToken',
       name => qr/^csrftoken$/,
      value => qr/^[[:xdigit:]]+$/,
    },
    email => {
       type => 'Email',
       name => qr/^privateemail$/,
      value => qr/^[\w\._\-]+@[\w\._\-]+\.[\w]{2,}$/,
    },
    propval => {
       type => 'YesNo',
       name => qr/^(botweb|listesemail|droitscamipro|comptead|stockindiv|gestprofil)$/,
      value => qr/^(y|n|d)$/,
    },
    classstatus => {
       type => 'Class / Status Id',
       name => qr/^(class|status)-\d+/,
      value => qr/^\d+$/,
    },
    whatsort => {
       type => 'Alpha',
       name => qr/^(what|sort)$/,
      value => qr/^[[:alpha:]]+$/,
    },
    depcond => {
       type => 'Condition',
       name => qr/^(deput)?cond$/,
      value => qr/^(w|d|p)$/,
    },
    propname => {
       type => 'Property name',
       name => qr/^propname.[[:alnum:]]+$/,
      value => qr/^[[:alpha:]]+$/,
    },
    unittype => {
       name => 'Unit type',
       name => qr/^utype$/, # Unit type, now 'Orgs' or 'Funds'.
      value => qr/^[[:alpha:]]+$/,
    },
  };
}
#
# CSRF.
#

sub loadcsrfkey {
  my    $self = shift;
  my $docroot = $ENV {DOCUMENT_ROOT};
  error ($self, msg('InternalError', 'No document root')) unless $docroot;
  $docroot =~ s/(htdocs|html)$/private/;
  open (CSRFKEY, "$docroot/csrfkey") || error ($self, msg('NoCSRFKeyFile'));
  my $hexcsrfkey = <CSRFKEY>; chomp $hexcsrfkey;
  close (CSRFKEY);
  $self->{csrfkey} = pack ('H*', $hexcsrfkey);
}

sub needscsrfshield {
  my $command = shift;
  #return 1;
  return $needscsrfshield->{$command};
}

1;
