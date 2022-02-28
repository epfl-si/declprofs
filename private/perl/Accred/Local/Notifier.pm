#!/usr/bin/perl
#
package Accred::Local::Notifier;

use strict;
use utf8;

use LWP::UserAgent;
use URI;
use URI::QueryParam;

use lib qq(/opt/dinfo/lib/perl);
use Accred::Utils;

my $configs = {
  prod => {
    wsserver => 'http://notifier.epfl.ch/cgi-bin/',
     verbose => 0,
    },
  test => {
    wsserver => 'http://test-notifier.epfl.ch/cgi-bin/',
     verbose => 1,
  },
  dev => {
    wsserver => 'http://dev-notifier/cgi-bin/',
     verbose => 1,
  },
};

my $package = 'Accred::Local::Notifier';

sub new {
  my ($class, $args) = @_;
  my  $self = {
        utf8 => 1,
      errmsg => undef,
        fake => 0,
       debug => 0,
     verbose => 0,
       trace => 0,
  };
  foreach my $arg (keys %$args) {
    $self->{$arg} = $args->{$arg};
  }

  my $config = $configs->{$args->{execmode}};
  return unless $config;
  $self->{wsserver} = $config->{wsserver};
  $self->{verbose}  = $config->{verbose};

  warn scalar localtime, " new Accred::Local::Notifier ($self->{wsserver}).\n"
    if ($self->{verbose} > 1);

  Accred::Utils::import ();
  bless $self;
}

sub addPerson {
  my ($self, $persid, $author) = @_;
  my $url = "notify?event=addsciper&sciper=$persid&author=$author";
  warn "${package}::addPerson ($persid, $author).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub modPerson {
  my ($self, $persid, $author) = @_;
  my $url = "notify?event=modifysciper&sciper=$persid&author=$author";
  warn "${package}::modifyPerson ($persid, $author).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub addAccred {
  my ($self, $persid, $unitid, $author) = @_;
  my $url = "notify?event=addaccred&sciper=$persid&unite=$unitid&author=$author";
  warn "${package}::addAccred ($persid, $unitid, $author).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub modAccred {
  my ($self, $persid, $unitid, $author) = @_;
  my $url = "notify?event=modifyaccred&sciper=$persid&unite=$unitid&author=$author";
  warn "${package}::modifyAccred ($persid, $unitid, $author).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub remAccred {
  my ($self, $persid, $unitid, $author) = @_;
  my $url = "notify?event=removeaccred&sciper=$persid&unite=$unitid&author=$author";
  warn "${package}::removeAccred ($persid, $unitid, $author).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub removeLastAccred {
  my ($self, $persid, $unitid, $author) = @_;
  my $url = "notify?event=removelastaccred&sciper=$persid&unite=$unitid&author=$author";
  warn "${package}::removeLastAccred ($persid, $unitid, $author).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
}

sub changeAccredsOrder {
  my ($self, $persid, $author, @modargs) = @_;

  warn "${package}::changeAccredsOrder ($persid, $author).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};

  my $url = "notify?event=changeaccredsorder&sciper=$persid&author=$author";
  $self->callURL ($url);

  while (@modargs) {
    my ($unitid, $old, $new) = (shift @modargs, shift @modargs, shift @modargs);
    # useful for Notifier::FUSE
    $self->modAccred ($persid, $unitid, $author);
  }
}

sub setAccredVisible {
  my ($self, $persid, $unitid, $author) = @_;
  my $url = "notify?event=setaccredvisible&sciper=$persid&unite=$unitid&author=$author";
  warn "${package}::setAccredVisible ($persid, $unitid, $author).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub setAccredNotVisible {
  my ($self, $persid, $unitid, $author) = @_;
  my $url = "notify?event=setaccrednotvisible".
            "&sciper=$persid&unite=$unitid&author=$author";
  warn "${package}::setAccredNotVisible ($persid, $unitid, $author).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub setAccredProperty {
  my ($self, $persid, $unitid, $propid, $author) = @_;
  my $url = "notify?event=setaccredproperty".
            "&sciper=$persid&unite=$unitid&property=$propid&author=$author";
  warn "${package}::setAccredProperty ($persid, $unitid, $propid, $author).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub createAccredRight {
  my ($self, $rightid, $author) = @_;
  my $url = "notify?event=createaccredright&right=$rightid&author=$author";
  warn "${package}::createAccredRight ($rightid, $author).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub removeAccredRight {
  my ($self, $rightid, $author) = @_;
  my $url = "notify?event=removeaccredright&right=$rightid&author=$author";
  warn "${package}::removeAccredRight ($rightid, $author).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub addRightToPerson {
  my ($self, $persid, $unitid, $rightid, $author) = @_;
  my $url = "notify?event=addrighttoperson".
            "&right=$rightid&sciper=$persid&unite=$unitid&author=$author";
  warn "${package}::addRightToPerson ($rightid, $persid, $unitid, $author).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub delRightOfPerson {
  my ($self, $persid, $unitid, $rightid, $author) = @_;
  my $url = "notify?event=delrightofperson".
            "&right=$rightid&sciper=$persid&unite=$unitid&author=$author";
  warn "${package}::delRightOfPerson ($persid, $rightid, $unitid, $author).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub changeRightPolicy {
  my ($self, $rightid, $author) = @_;
  my $url = "notify?event=changeRightPolicy&right=$rightid&author=$author";
  warn "${package}::changerightpolicy ($rightid, $author).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub createAccredRole {
  my ($self, $rightid, $author) = @_;
  my $url = "notify?event=createaccredrole&right=$rightid&author=$author";
  warn "${package}::createAccredRole ($rightid, $author).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub removeAccredRole {
  my ($self, $roleid, $author) = @_;
  my $url = "notify?event=removeaccredrole&role=$roleid&author=$author";
  warn "${package}::removeAccredRole ($roleid, $author).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub addRoleToPerson {
  my ($self, $persid, $unitid, $roleid, $author) = @_;
  my $url = "notify?event=addroletoperson".
            "&role=$roleid&sciper=$persid&unite=$unitid&author=$author";
  warn "${package}::addRoleToPerson ($roleid, $persid, $unitid, $author).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub delRoleOfPerson {
  my ($self, $persid, $unitid, $roleid, $author) = @_;
  my $url = "notify?event=delroleofperson".
            "&role=$roleid&sciper=$persid&unite=$unitid&author=$author";
  warn "${package}::delRoleToPerson ($roleid, $persid, $unitid, $author).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub changeRolePolicy {
  my ($self, $roleid, $author) = @_;
  my $url = "notify?event=changerolepolicy&role=$roleid&author=$author";
  warn "${package}::changeRolePolicy ($roleid, $author).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub changeRoleRights {
  my ($self, $roleid, $author) = @_;
  my $url = "notify?event=changerolerights&role=$roleid";
  warn "${package}::changeRoleRights ($roleid, $author).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub changeStatusRights {
  my ($self, $statusid) = @_;
  my $url = "notify?event=changestatusrights&status=$statusid";
  warn "${package}::changeStatusRights ($statusid).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub changeClassRights {
  my ($self, $classid) = @_;
  my $url = "notify?event=changeclassrights&class=$classid";
  warn "${package}::changeClassRights ($classid).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub changeRight {
  my ($self, $rightid) = @_;
  my $url = "notify?event=changeright&right=$rightid";
  warn "${package}::changeRight ($rightid).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub changeRole {
  my ($self, $roleid) = @_;
  my $url = "notify?event=changerole&role=$roleid";
  warn "${package}::changeRole ($roleid).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub changeUnitRights {
  my ($self, $unitid) = @_;
  my $url = "notify?event=changeunitrights&unit=$unitid";
  warn "${package}::changeUnitRights ($unitid).\n"
    if ($self->{fake} || $self->{verbose});
  return if $self->{fake};
  $self->callURL ($url);
}

sub callURL {
  my ($self, $url) = @_;

  if (!$url || !$self->{wsserver}) {
    warn("Accreds::Notifier::callURL url is incomplete, abort");
    return;
  }

  my $url = URI->new_abs ($url, $self->{wsserver});

  if ($self->{notifiers}) {
    my $notifiers = join(',', @{$self->{notifiers}});
    $url->query_param(notifiers => $notifiers);
  }

  my $ua = LWP::UserAgent->new ();
  $ua->timeout(3);

  my $req = HTTP::Request->new ('GET', $url->as_string);
  warn (scalar localtime, " ".ref($self)."::call info : ".$req->as_string) if $self->{verbose};

  my $response = $ua->request($req);
  if ($response->is_error) {
    $self->{errmsg} = $response->status_line;
    warn (scalar localtime, " ".ref($self)."::call error : ($url, $self->{errmsg})");
  }
}


1;
