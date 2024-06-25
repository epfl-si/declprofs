#!/usr/bin/perl
#
use strict;
use utf8;
use Encode;

use lib qw(/opt/dinfo/lib/perl);
use Tequila::Client;
use Cadi::CadiDB;

package Cadi::WebRequest;

my ($errmsg, $messages);
my $defaultuser = {
  username => 'lecom',
    sciper => 105640,
      name => 'Lecommandeur',
 firstname => 'Claude',
};
my $defaultlang = 'en';


sub new { # Exported
  my $class = shift;
  my  $args = (@_ == 1) ? shift : { @_ } ;
  my $self = {
      errmsg => undef,
        lang => 'fr',
        fake => 0,
     verbose => 0,
  };
  foreach my $arg (keys %$args) {
    $self->{$arg} = $args->{$arg};
  }
  $self->{verbose} = 1 if $self->{fake};
  bless $self, $class;
  $self->initmessages   ();
  $self->loadfromenv    ();
  $self->setlanguage    ();
  $self->checkcsrftoken () if $self->{needscsrfshield}->{$self->{command}};
  return $self;
}
#
# Authentication.
#
sub inittequila {
  my ($self, $teqargs) = @_;
  my $tequila;
  if ($self->{remaddr}) {
    $tequila = new Tequila::Client (
      urlaccess => $teqargs->{urlaccess} || undef,
        service => $teqargs->{service}   || 'Unknown service',
         allows => $teqargs->{allows},
        request => $teqargs->{request}   ||
          [ 'uniqueid', 'name', 'firstname', 'email', 'categorie' ],
    );
    $tequila->init ();
  }
  $self->{tequila} = $tequila;
}

sub authenticate {
  my $self = shift;
  unless ($self->{remaddr}) {
    $self->{user} = $defaultuser;
    return;
  }
  my $tequila = $self->{tequila};
  $tequila->authenticate ();

  my      $name = $tequila->{attrs}->{name};
  my $firstname = $tequila->{attrs}->{firstname};
  $name         =~ s/(,.*)$//;
  $firstname    =~ s/(,.*)$//;
  my $categorie = $tequila->{attrs}->{categorie};
  $categorie = 'epfl' if ($categorie =~ /^(ehe|entreprises|technique)$/i);
  
  $self->{user} = {
      sciper => $tequila->{attrs}->{uniqueid},
    username => $tequila->{user},
        name => $name,
   firstname => $firstname,
   categorie => $categorie,
  };
  $self->{isroot} = $self->{roots}->{$self->{user}->{sciper}};
}

sub checkauth {
  my $self = shift;
  unless ($self->{remaddr}) {
    $self->{user} = $defaultuser;
    return;
  }
  my $tequila = $self->{tequila};
  return unless $tequila->authenticated ();
  
  my $categorie = $tequila->{attrs}{categorie};
  my      $name = $tequila->{attrs}->{name};
  my $firstname = $tequila->{attrs}->{firstname};
  $name         =~ s/(,.*)$//;
  $firstname    =~ s/(,.*)$//;
  $categorie = 'epfl' if ($categorie =~ /^(ehe|entreprises|technique)$/i);
  $self->{user} = {
      sciper => $tequila->{attrs}->{uniqueid},
    username => $tequila->{user},
        name => $name,
   firstname => $firstname,
   categorie => $categorie,
  };
  return 1;
}

sub logout {
  my $self = shift;
  my $tequila = $self->{tequila};
  $tequila->logout () if $tequila;
}

sub setRoots {
  my ($self, $roots) = @_;
  $self->{roots} = $roots;
}

sub setlanguage {
  my $self = shift;
  my $cookies = $ENV {HTTP_COOKIE};
  my $appname = $self->{appname} || 'default';
  if ($cookies) {
    my $lang;
    foreach my $cookie (split (/; /, $cookies)) {
      if ($cookie =~ /^${appname}_lang=(.*)$/) {
        $lang = $1;
        last;
      }
    }
    if ($lang) {
      $lang = $defaultlang unless ($lang =~ /^(fr|en)$/);
      $self->{language} = $lang;
      return;
    }
  }
  my $preflang = $ENV {HTTP_ACCEPT_LANGUAGE};
  if ($preflang) {
    my $lang;
    foreach my $l (split (/,/, $preflang)) {
      $lang = 'fr', last if ($l =~ /^fr/);
      $lang = 'en', last if ($l =~ /^en/);
    }
    if ($lang) {
      $self->{language} = $lang;
      return;
    }
  }
  $self->{language} = $defaultlang;
}

sub error {
  my ($self, $msgkey, @args) = @_;
  my $lang = $self->{language};
  $self->{errmsg}  = $messages->{$msgkey}->{$lang} || $msgkey;
  $self->{errmsg} .= '(' . join (' ', @args) . ')' if @args;
  warn "$self->{errmsg}\n";
  return;
}

sub escape {
  my $self = shift;
  $_[0] =~ s/&/&amp;/g;
  $_[0] =~ s/</&lt;/g;
  $_[0] =~ s/>/&gt;/g;
  $_[0] =~ s/"/&quot;/g;
}

#
# CSRF.
#
sub initcsrf {
  my ($self, $subslist) = @_;
  $self->{needscsrfshield} = $subslist;
}

sub loadcsrfkey {
  my    $self = shift;
  my $docroot = $ENV {DOCUMENT_ROOT};
  return $self->error ('initerror', 'loadcsrfkey') unless $docroot;
  $docroot =~ s/(htdocs|html)$/private/;
  open (CSRFKEY, "$docroot/csrfkey") || return $self->error ('nocsrfkeyfile');
  my $hexcsrfkey = <CSRFKEY>; chomp $hexcsrfkey;
  close (CSRFKEY);
  $self->{csrfkey} = pack ('H*', $hexcsrfkey);
}

sub loadfromenv {
  my $self = shift;
  return if ($ENV {REQUEST_METHOD} eq 'OPTIONS');
  my  $get = $ENV {QUERY_STRING};
  my $post = '';
  if ($ENV {REQUEST_METHOD} && $ENV {REQUEST_METHOD} eq 'POST') {
    read (STDIN, $post, $ENV {CONTENT_LENGTH});
  }
  my    $all = $get . '&' . $post;
  my @fields = split (/&/, $all);
  foreach (@fields) {
    s/\+/ /g;
    s/%([0-9a-f]{2,2})/pack ("C", hex ($1))/gie;
  }
  my $args;
  foreach my $field (@fields) {
    next unless ($field =~ /=/);
    my ($name, $value) = split(/=/, $field, 2);
    $value =~ s/\s*$//; $value =~ s/^\s*//;
    $value = Encode::decode ('UTF-8', $value);
    #$self->escape ($value);
    $args->{$name} = $args->{$name} ? $args->{$name} . '|' . $value : $value;
  }
  $self->{args}    = $args;
  $self->{me}      = $ENV {SCRIPT_URL};
  my           $pi = $ENV {PATH_INFO};
  $self->{me}      =~ s/$pi$//;
  $pi              =~ s/^(\/*)//;
  my ($command, @modifiers) = split (/\//, $pi);
  $self->{command}   = $command;
  $self->{modifiers} = { map { $_, 1 } @modifiers };
  $self->{us}      = $ENV {SERVER_NAME};
  $self->{remaddr} = $ENV {REMOTE_ADDR};
}

sub getSSLUser {
  my $self = shift;
  return unless ($ENV {SSL_CLIENT_VERIFY} eq 'SUCCESS');
  my  $cn = $ENV {SSL_CLIENT_S_DN_CN};
  my $org = $ENV {SSL_CLIENT_S_DN_O};
  unless ($cn =~ /^[^\(]*\(CAMIPRO=(\d\d\d\d\d\d)\)$/) {
    my $appname = $self->{appname} || 'default';
    warn "$appname:getSSLUser: Invalid cn : $cn\n";
    return;
  }
  my $sciper = $1;
  return $sciper;
}

#
# Errors.
#

sub errmsg {
  my $self = shift;
  return $self->{errmsg};
}

sub initmessages {
  my $self = shift;
  $messages = {
    initerror => {
      fr => "Erreur d'initialisation.",
      en => "Initialization error.",
    },

    nocsrfkeyfile => {
      fr => "Erreur interne : pas de fichier de clé CSRD.",
      en => "Internal error : no CSRF key file.",
    },

    nocsrftoken => {
      fr => "Clé CSRF manquante.",
      en => "No CSRF token.",
    },

    badcsrftoken => {
      fr => "Clé CSRF invalide.",
      en => "Bad CSRF token.",
    },

    expiredcsrftoken => {
      fr => "Clé CSRF trop vielle. Rechargez la page pour corriger.",
      en => "Too old CSRF token. Reload the page to fix it",
    },

    nocryptomodule => {
      fr => "Erreur de chargement du module de crypto",
      en => "Unable to load crypto module",
    },
  };
}


1;















