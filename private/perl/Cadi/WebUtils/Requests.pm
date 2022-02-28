#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Request.pm
# Description:  
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Wed May 25 15:45:03 CEST 2016
# Revision:     
#
##############################################################################
#
#
package Cadi::WebUtils::Requests;
#
use strict;
use utf8;

use Encode;
use Tequila::Client;
use Cadi::WebUtils::Utils;

my $defaultlang = 'fr';

my $superadmins = {
  105640 => 1, # Moi.
};

sub new { # Exported
  my ($class, $args) = @_;
  my  $self = {
                 me => undef,
                 us => undef,
                 qs => undef,
                 pi => undef,
               args => undef,
             cgidir => undef,
            version => '3.0',
            tequila => undef,
       authentified => undef,
               test => undef,
               warn => undef,
              title => undef,
             userid => undef,
            verbose => undef,
  };

  foreach my $arg (keys %$args) {
    $self->{$arg} = $args->{$arg};
  }
  bless $self, $class;
  warn scalar localtime, " new Cadi::Request.\n" if $self->{verbose};
  $self->init ();
  return $self;
}

sub init {
  my $self = shift;
  $self->setlanguage ();
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

  my ($tequila, $args);
  if ($ENV {SERVER_NAME}) {
    $tequila = new Tequila::Client (
      sessionmax => 86400,
         service => $self->{service} || 'Some service',
      cookiename => $self->{cookiename} || 'SomeCookieName',
         request => [ 'name', 'firstname', 'uniqueid', ],
       urlaccess => "https://$us/$me",
       #logouturl => "http://$us/$cgidir/accreds.pl/loggedout",
    );
    $tequila->init ();
    $args = $tequila->{appargs};
    #foreach my $arg (keys %$args) {
    #  $args->{$arg} = decode ('utf-8', $args->{$arg}) unless ref $args->{$arg};
    #}
    $self->{tequila} = $tequila;
  }
  
  my $cookies = $ENV {HTTP_COOKIE};
  if ($cookies) {
    foreach my $cookie (split (/; /, $cookies)) {
      if ($cookie =~ /^$self->{appname}::([^=]*)=(.*)$/) {
        $args->{$1} = $2;
      }
    }
  }
  $self->{test} = 1
    if ($ENV {SCRIPT_URL} =~ /test/
     || !$ENV {SERVER_NAME}
    );
    
  $self->{noserver}  = !$ENV {SERVER_NAME};
  my     $prod = -f '/opt/dinfo/etc/MASTER';
  my  $scratch = -f '/opt/dinfo/etc/SCRATCH';

  my $userid;
  if ($pi =~ /^logout/) {
    $tequila->globallogout () if $tequila;
    $userid = '';
    return 1;
  }

  if ($self->authenticated ()) {
    $userid = $self->{tequila}->{attrs}->{uniqueid};
  }
  else  {
    $userid = $self->authenticate ();
    error ($self, msg('BadUser', $tequila->{user})) unless $userid;
  }
  my $realuserid = $self->{realuserid} = $userid;
  if ($userid && $superadmins->{$userid} && $args->{spoofid}) {
    $userid = $args->{spoofid};
  }
  $self->{userid} = $userid;
  $self->{args}   = $args;
  $self->{su}     = $superadmins->{$userid};
  
  return 1;
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
    Cadi::WebUtils::Utils::init ($self);
    Cadi::WebUtils::Utils::head ($self);
    my $loginurl = $self->{me};
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
  return $self->{tequila}->{attrs}->{uniqueid};
}

sub authenticated {
  my $self = shift;
  return unless ($self && $self->{tequila});
  my $authenticated = $self->{tequila}->authenticated ();
  return $authenticated;
}

1;
