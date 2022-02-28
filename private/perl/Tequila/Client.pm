#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Tequila/Client.pm
# Description:  Encapsule l'authentification Tequila pour les CGI en perl
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Thu Oct 31 09:16:06 CET 2002
#
# 2.0.1 -> 2.0.2
#   - Remove all remnant of opaque ans urlauth.
#   - Fix localorg image access. Now, it is logo.gif.
#
# 2.0.2 -> 2.0.3
#   - In loadargs : protect from multiple 'key' values.
#   - Remove all remnant of 'fromserver'.
#   - Fetch images from server.
#
# 2.0.2 -> 2.0.3
#   - Fix for ever the key business. Now there is a separate key for the request
#     and session.
#   - No longer use the key= attribute in the urlaccess, always use cookies.
#
##############################################################################
#
package Tequila::Client;
#
use strict;
use utf8;
use Socket;
use IO::Socket::SSL;
use IO::Socket::INET;

BEGIN {
  if (eval { require Apache2::ServerRec }) {
#    import Apache2::ServerRec qw(warn);
  }
}

use vars qw(@ISA $VERSION $XS_VERSION $CONFIG $DEBUG);

$VERSION = '2.0.3';

sub new { # Exported
  my $class = shift;
  my  %args = @_;

  my $config = configure ();
  my  $self = {
           partner => undef,
          resource => undef,
          urlacces => undef,
         urlaccess => undef,
            usessl => 1,
           service => undef,
           request => undef,
              wish => undef,
           require => undef,
         wantright => undef,
          wantrole => undef,
          language => 'english',
        identities => undef,
       localserver => $config->{server},
         serverurl => $config->{serverurl},
       sessionsdir => $config->{sessionsdir},
        serverfile => "/tequila",
       usesessions => 1,
   sessionsmanager => 'files',
        sessionmax => 24 * 3600,
            dbname => undef,
           dbtable => undef,
            dbuser => undef,
            dbpass => undef,
 checkcertificates => 0,
            cafile => undef,
        clientargs => {},
            allows => undef,
      authstrength => 0,
         hascookie => 0,
        usecookies => 1,
        cookiename => undef,
      cookiepolicy => 'session',
     servercookies => 1,
      allsensitive => undef,
          username => undef,
           contact => undef,
           testing => undef,
             debug => undef,
         logouturl => undef,
           charset => 'utf-8',

           verbose => 0,
     authenticated => undef,
       initialized => undef,
       querystring => undef,
          pathinfo => undef,
        scriptname => undef,
        servername => undef,
        serverport => undef,
             https => undef,
        sessionkey => undef,
        requestkey => undef,
               org => undef,
              user => undef,
              host => undef,
              vars => undef,
             attrs => undef,
         noappargs => 0,
           appargs => undef,
  };
  foreach my $arg (keys %args) {
    if (ref ($args {$arg}) eq 'ARRAY') {
      $self->{$arg} = join ('+', @{$args {$arg}});
      next;
    }
    $self->{$arg} = $args {$arg};
  }
  if ($self->{charset} =~ /^utf/i) {
    foreach my $arg (keys %args) {
      my $value = $self->{$arg};
      Encode::_utf8_on ($self->{$arg});
      my $wellformedutf8 = Encode::is_utf8 ($self->{$arg}, 1) ? 1 : 0;
      $self->{$arg} = Encode::decode ('iso-8859-1', $value) unless $wellformedutf8;
    }
  }
  $self->{urlaccess} ||= $self->{urlacces};
  
  if ($self->{profile}) {
    $self->{profile} = 0 unless eval "use Time::HiRes; 1;";
  }
  bless $self, $class;
  $self->init ();
  return $self;
}

sub init {
  my $self = shift;
  return if $self->{initialized};
  my $appargs = loadargs () unless $self->{noappargs};
  $self->configserverurl ();

  $self->{querystring} = $ENV {QUERY_STRING};
  $self->{pathinfo}    = $ENV {PATH_INFO};
  $self->{scriptname}  = $ENV {SCRIPT_NAME};
  $self->{servername}  = $ENV {SERVER_NAME};
  $self->{serverport}  = $ENV {SERVER_PORT};
  $self->{https}       = $ENV {HTTPS};
  $self->{appargs}     = $appargs;

  $self->{sessioncookiename} ||= $self->{cookiename};
  unless ($self->{sessioncookiename}) {
    my $scriptname = $self->{scriptname};
    if ($scriptname =~ /^.*\/(\S+)$/) {
      $self->{sessioncookiename} = "Tequila_$1";
    } else {
      $self->{sessioncookiename} = 'teqsession_key';
    }
  }
  unless ($self->{requestcookiename}) {
    my $scriptname = $self->{scriptname};
    if ($scriptname =~ /^.*\/(\S+)$/) {
      $self->{requestcookiename} = "Tequila_req_$1";
    } else {
      $self->{requestcookiename} = 'teqrequest_key';
    }
  }
  my $sessioncookiename = $self->{sessioncookiename};
  my $requestcookiename = $self->{requestcookiename};
  #
  # Look for key is in cookies
  #
  if ($self->{usecookies}) {
    my $allcookies = $ENV {HTTP_COOKIE};
    foreach my $cookie (split (/; /, $allcookies)) {
      if ($cookie =~ /^\Q$sessioncookiename\E=(.*)$/) {
        $self->{sessionkey} = $1;
        last;
      }
      if ($cookie =~ /^\Q$requestcookiename\E=(.*)$/) {
        $self->{requestkey} = $1;
      }
    }
  }
  #
  # Not found in cookies, look in parameters.
  #
  unless ($self->{sessionkey}) {
    $self->{sessionkey} = $appargs->{teqsession_key};
    delete $appargs->{teqsession_key};
  }
  unless ($self->{requestkey}) {
    $self->{requestkey} = $appargs->{teqrequest_key} ||
                          $appargs->{requestkey}     ||
                          $appargs->{key};
    delete $appargs->{teqrequest_key};
    delete $appargs->{requestkey};
    delete $appargs->{key};
  }
  #
  # Check the result.
  #
  if ($self->{usesessions} && $self->{sessionkey}) {
    my $status = $self->loadsession ();
    $self->{authenticated} = 1 if ($status == 1);
  }
  elsif ($self->{requestkey}) {
    if ($self->fetchattributes ()) {
      $self->setsessioncookie () if ($self->{usecookies} && !$self->{nph});
      $self->{authenticated} = 1;
    }
  }
  $self->{initialized} = 1;
}

sub authenticate {
  my $self = shift;
  $self->init () unless $self->{initialized};
  return if ($self->{authenticated} &&
            ($self->{attrs}->{authstrength} >= $self->{authstrength}));
  $self->createserverrequest ();
  $self->redirecttoserver    ();
}

sub authenticated {
  my $self = shift;
  return $self->{authenticated};
}

sub logout {
  my $self = shift;
  my $starttime = Time::HiRes::time () if $self->{profile};
  $self->killsession () if $self->{usesessions};
  $self->{authenticated} = 0;
  $self->removecookie ($self->{sessioncookiename});
  checkpoint ('Client.pm:logout', $starttime) if $self->{profile};
}

sub globallogout {
  my $self = shift;
  $self->logout ();
  my        $pi = $self->{pathinfo};
  my        $me = $self->{scriptname};
  my        $us = $self->{servername};
  my $serverurl = $self->{serverurl};
  my $logouturl = $self->{logouturl} || $self->{urlaccess} || "http://$us$me$pi";
  $logouturl    = escapeurl ($logouturl);
  nphheaders ('302 Moved Temporarily') if $self->{nph};
  print qq{Location: $serverurl/logout?urlaccess=$logouturl\r\n\r\n};
}

sub redirecttoserver {
  my $self = shift;
  my $requestkey = $self->{requestkey};
  $self->error ("Internal error in redirecttoserver : requestkey undefined.")
    unless $requestkey;
  nphheaders ('302 Moved Temporarily') if $self->{nph};
  print qq{WWW-Authenticate: Tequila serverurl="$self->{serverurl}" requestkey="$requestkey"\r\n};
  print qq{Location: $self->{serverurl}/auth?requestkey=$requestkey\r\n};
  print qq{\r\n};
  exit;
}

sub setrequestcookie {
  my $self = shift;
  warn  qq{Tequila:Client:setrequestcookie.\n} if $self->{verbose};
  $self->removecookie  ($self->{sessioncookiename});
  $self->depositcookie ($self->{requestcookiename}, $self->{requestkey});
}

sub setsessioncookie {
  my $self = shift;
  warn  qq{Tequila:Client:setsessioncookie.\n} if $self->{verbose};
  $self->removecookie  ($self->{requestcookiename});
  $self->depositcookie ($self->{sessioncookiename}, $self->{sessionkey});
}

sub depositcookie {
  my ($self, $cook, $value) = @_;
  return unless $cook;
  my $date = gmtime (time + $self->{sessionmax});
  my ($day, $month, $daynum, $hms, $year) = split (/\s+/, $date);
  my $expires = sprintf ("%s %02d-%s-%s %s GMT", $day, $daynum, $month, $year, $hms);
  if ($self->{cookiepolicy} eq 'session') {
    print qq{Set-Cookie: $cook=$value; path=/; httponly\r\n};
  } else {
    print qq{Set-Cookie: $cook=$value; path=/; expires=$expires;\r\n};
  }
}

sub removecookie {
  my ($self, $cook) = @_;
  my $date = gmtime (time - 3600);
  my ($day, $month, $daynum, $hms, $year) = split (/\s+/, $date);
  my $expires = sprintf ("%s %02d-%s-%s %s GMT", $day, $daynum, $month, $year, $hms);
  print qq{Set-Cookie: $cook=removed; path=/; expires=$expires;\r\n};
}

sub nphheaders {
  my $statutline = shift;
  print qq{HTTP/1.1 $statutline\r\n},
        qq{Date: }, scalar time, "\r\n"
  ;
}

sub nphcookies {
  my $self = shift;
  return unless ($self->{nph} && $self->{usecookies});
  $self->removecookie  ($self->{requestcookiename}) if $self->{requestkey};
  $self->depositcookie ($self->{sessioncookiename}, $self->{sessionkey})
}

sub loadsessionsmanager {
  my $self = shift;
  my $sessionsmanager = $self->{sessionsmanager};
  my $SM = 'Tequila::' . $sessionsmanager;
  eval "use $SM; 1;" || do {
    warn "loadsessionsmanager ($sessionsmanager) failed1.\n" if $self->{verbose};
    $self->error ("loadsessionsmanager : Unable to load session manager $SM : $@");
  };
  
  my $sm;
  if ($self->{sessionsmanager} eq 'DSM') {
    eval "\$sm = new Tequila::DSM (
      dsmhost => 'localhost',
      dsmport => 2345,
      charset => \'$self->{charset}\',
    );" || do {
      warn "loadsessionsmanager ($sessionsmanager) failed2.\n" if $self->{verbose};
      $self->error ("loadsessionsmanager : Unable to initialized session manager $SM : $@");
    };
  }
  elsif ($self->{sessionsmanager} eq 'SQLSM') {
    $self->error ("loadsessionsmanager : Unable to initialized session manager $SM : no db table")
      unless $self->{dbtable};
    my ($dbhost, $dbname, $dbuser, $dbpass);
    if ($self->{dbhost} &&  $self->{dbname} && $self->{dbuser} && $self->{dbpass}) {
      $dbhost = $self->{dbhost};
      $dbname = $self->{dbname};
      $dbuser = $self->{dbuser};
      $dbpass = $self->{dbpass};
    }
    elsif ($self->{dbname}) {
      if (eval 'use Cadi::CadiDB; 1;') {
        my $cadidb = Cadi::CadiDB->new (dbname => $self->{dbname});
        $self->error ("loadsessionsmanager : Unable to initialized session manager1 $SM : ".
                      "$Cadi::CadiDB::errmsg") unless $cadidb;
        $dbhost = $cadidb->{db}->{host};
        $dbname = $cadidb->{db}->{name};
        $dbuser = $cadidb->{db}->{user};
        $dbpass = $cadidb->{db}->{pass};
      } else {
        $self->error ("loadsessionsmanager : Unable to initialized session manager $SM : ".
                      "Cadi::CadiDB not present")
      }
    } else {
      $self->error ("loadsessionsmanager : Unable to initialized session manager $SM : ".
                    "not enough information")
    }
    eval '
      $sm = new Tequila::SQLSM (
        dbhost => $dbhost,
        dbname => $dbname,
        dbuser => $dbuser,
        dbpass => $dbpass,
       dbtable => $self->{dbtable},
      );
    ' || do {
        warn "loadsessionsmanager ($sessionsmanager) failed2.\n" if $self->{verbose};
        $self->error ("loadsessionsmanager : Unable to initialized session manager $SM : $@");
      };
  }
  $self->{sm} = $sm;
  warn "loadsessionsmanager ($sessionsmanager) OK.\n" if $self->{verbose};
}

sub createsession {
  my $self = shift;
  warn "createsession ($self->{sessionsdir}:$self->{sessionkey}:$self->{org}".
       ":$self->{user}:$self->{host}).\n" if $self->{verbose};
  
  return $self->createfilesession () if ($self->{sessionsmanager} eq 'files');
  
  $self->loadsessionsmanager () unless $self->{sm};
  return unless $self->{sm};
  my $sm = $self->{sm};
  return unless $sm;
  my $session = {
        org => $self->{org},
       user => $self->{user},
       host => $self->{host},
    timeout => $self->{sessionmax}
  };
  foreach my $attr (keys %{$self->{attrs}}) {
    my $value = $self->{attrs}->{$attr};
    $value =~ s/\n/\\n/g;
    $value =~ s/\r]//g;
    $session->{$attr} = $value;
  }
  my $status = $sm->createsession ("Application:$self->{sessionkey}", $session);
  unless ($status) {
    $self->error ("createsession : Unable to create session Application:$self->{sessionkey}");
  }
  warn "createsession : session $self->{sessionkey} created\n" if $self->{verbose};
  return 1;
}

#
# loadsession
#
# returns : 1 : OK.
#           2 : pas de session.
#           3 : session echue.
#           4 : pas la bonne machine au bout
#
sub loadsession {
  my $self = shift;
  return $self->loadfilesession () if ($self->{sessionsmanager} eq 'files');
  
  $self->loadsessionsmanager () unless $self->{sm};
  return unless $self->{sm};
  my $sm = $self->{sm};
  return unless $sm;
  warn "loadsession ($self->{sessionkey} OK\n" if $self->{verbose};
  my $session = $sm->readsession ("Application:$self->{sessionkey}");
  return 2 unless $session;
  foreach my $attr (keys %$session) {
    if ($attr =~ /^(org|user|host)$/) {
      $self->{$attr} = $session->{$attr};
      next;
    }
    $self->{attrs}->{$attr} = $session->{$attr};
  }
  return 1;
}

sub purgesessions {
  my $self = shift;
  return if ($self->{sessionsmanager} ne 'files');
  my $sesmax = $self->{sessionmax};
  opendir (SESSIONS, $self->{sessionsdir}) || return;
  my @sessions = readdir (SESSIONS);
  closedir (SESSIONS);
  @sessions = grep (!/^\.\.?$/, @sessions);
  foreach my $session (@sessions) {
    my $sessionfile = "$self->{sessionsdir}/$session";
    next if -d $sessionfile;
    my $lastaccess = (stat ($sessionfile))[8];
    my        $now = time;
    unlink ($sessionfile) if ($lastaccess < ($now - $sesmax));
  }
}

sub killsession {
  my $self = shift;
  return $self->killfilesession () if ($self->{sessionsmanager} eq 'files');
  $self->loadsessionsmanager () unless $self->{sm};
  return unless $self->{sm};
  my $sm = $self->{sm};
  return unless $sm;
  $sm->deletesession ("Application:$self->{sessionkey}");
}
#
# File sessions management.
#
sub createfilesession {
  my $self = shift;
  warn "createfilesession ($self->{sessionsdir}:$self->{sessionkey}:$self->{org}".
       ":$self->{user}:$self->{host})" if $self->{verbose};
  
  my $sesdir = $self->{sessionsdir};
  unless (-d $sesdir && -w $sesdir) {
    $self->error ("Tequila:createfilesession: Session directory $sesdir doesn't ".
                  "exist or not writable.");
  }
  unless (open (SESSION, ">$sesdir/$self->{sessionkey}")) {
    $self->error ("Tequila:createfilesession: Unable to open session file ".
                  "($sesdir/$self->{sessionkey}) : $!");
  }
  binmode SESSION, ":utf8" if ($self->{charset} =~ /^utf/);
  print SESSION "org=$self->{org}\n",
                "user=$self->{user}\n",
                "host=$self->{host}\n";
  foreach my $attr (keys %{$self->{attrs}}) {
    my $value = $self->{attrs}->{$attr};
    $value = "\\\n" . $value . "\n" if ($value =~ /[\n\r]/);
    print SESSION "$attr=$value\n";
  }
  close (SESSION);
  return 1;
}

sub loadfilesession {
  my       $self = shift;
  my $sessionkey = $self->{sessionkey};
  my     $sesdir = $self->{sessionsdir};
  my     $sesmax = $self->{sessionmax};
  my    $keyfile = "$sesdir/$sessionkey";
  warn "loadfilesession ($keyfile) failed : $!.\n" unless (-r $keyfile);
  return 2 unless (-r $keyfile);
  my $lastaccess = (stat ($keyfile))[8];
  my        $now = time;
  if ($lastaccess < ($now - $sesmax)) {
    unlink ($keyfile);
    return 3;
  }
  open (SESSION, $keyfile) || return 2;
  binmode SESSION, ":utf8" if ($self->{charset} =~ /^utf/);
  while (<SESSION>) {
    chomp;
    my ($attr, $value) = split (/=/, $_, 2);
    if ($attr =~ /^(org|user|host)$/) {
      $self->{$attr} = $value;
      next;
    }
    if ($value =~ /^\\/) {
      $value = "\\\n";
      while (<SESSION>) {
        last if /^[\r\n]*$/;
        $value .= $_;
      }
    }
    $self->{attrs}->{$attr} = $value;
  }
  close (SESSION);
  utime ($now, $now, "$sesdir/$sessionkey");
  killsession ($self) unless $self->{usesessions};
  return 1;
}

sub killfilesession {
  my $self = shift;
  my $sessionfile = "$self->{sessionsdir}/$self->{sessionkey}";
  unlink ($sessionfile) || "killsession: Unable to kill session $self->{sessionkey} : $!";
}

sub checkuserprofile {
  my      $self = shift;
  my     $abort = shift;
  my   $require = $self->{require};
  my  $resource = $self->{resource};
  my $wantright = $self->{wantright};
  my  $wantrole = $self->{wantrole};

  return 1 if ($self->{attrs}->{status} eq 'fail'); # Don't check failed login.
  if ($resource && ($resource ne $self->{attrs}->{resource})) {
    return 0 if !$abort;
    $self->error (
      "Tequila:checkuserprofile: request found on the server, doesnt match the".
      " requested resource :".
      "<br>server says resource = $self->{attrs}->{resource},".
      "<br>client says resource = $resource"
    );
  }
  if ($require && ($require ne $self->{attrs}->{require})) {
    return 0 if !$abort;
    $self->error (
      "Tequila:checkuserprofile: request found on the server, doesnt fit the".
      " required filter :".
      "<br>server says require = $self->{attrs}->{require},".
      "<br>client says require = $require"
    );
  }
  if ($wantright) {
    my @rights = split (/,/, $wantright);
    foreach my $right (@rights) {
      unless ($self->{attrs}->{$right}) {
        return 0 if !$abort;
        $self->error (
          "Tequila:checkuserprofile: request found on the server, doesn't".
          " fit the required filter : right $right is missing");
      }
    }
  }
  if ($wantrole) {
    my @roles = split (/,/, $wantrole);
    foreach my $role (@roles) {
      unless ($self->{attrs}->{$role}) {
        return 0 if !$abort;
        $self->error (
          "Tequila:checkuserprofile: request found on the server, doesnt".
          " fit the required filter : role $role is missing");
      }
    }
  }
  return 1;
}

sub request {
  my $self = shift;
  $self->{request} = join ('+', @_);
}

sub wish {
  my $self = shift;
  $self->{wish} = join ('+', @_);
}

sub require {
  my   $self = shift;
  my $newreq = shift;
  if ($self->{require}) {
    $self->{require} = "($self->{require})&($newreq)";
  } else {
    $self->{require} = $newreq;
  }
}

sub authstrength {
  my $self = shift;
  $self->{authstrength} = shift;
}

sub checkcerts {
  my $self = shift;
  $self->{checkcertificates} = shift;
}

sub cafile {
  my $self = shift;
  $self->{cafile} = shift;
}

sub wantright {
  my $self = shift;
  $self->{wantright} = shift;
}

sub wantrole {
  my $self = shift;
  $self->{wantrole} = shift;
}

sub setresource {
  my $self = shift;
  $self->{resource} = shift;
}

sub setpartner {
  my $self = shift;
  $self->{partner} = shift;
}

sub setlang {
  my $self = shift;
  $self->{language} = shift;
}

sub setidentities {
  my $self = shift;
  $self->{identities} = shift;
}

sub allsensitive {
  my $self = shift;
  my $value = shift;
  $self->{allsensitive} = $value ? 1 : 0;
}

sub usecookies {
  my $self = shift;
  my $value = shift;
  $self->{usecookies} = $value ? 1 : 0;
}

sub setcookiename {
  my $self = shift;
  #$self->{cookiename} = $self->{sessioncookiename} = shift;
}

sub setcookiepolicy {
  my $self = shift;
  $self->{cookiepolicy} = shift;
}

sub useloginwindow {
  # nothing.
}

sub servercookies {
  my $self = shift;
  $self->{servercookies} = shift;
}

sub setopaque {
  # nothing
}

sub setserver {
  my   $self = shift;
  my $server = shift;
  $self->{localserver} = $server;

  if ($server !~ /^tequila\./) {
    my $binaddr = gethostbyname ($server);
    my $srvaddr = join ('.', unpack ('C4', $binaddr));
    $self->{sessionsdir} = $self->{sessionsdir} . '/' . $srvaddr;
  }
  $self->{serverurl}   = "https://$self->{localserver}/tequila";
}

sub setserverurl {
  my      $self = shift;
  my $serverurl = shift;
  $self->{serverurl} = $serverurl;
  $self->configserverurl ();
}

sub configserverurl {
  my $self = shift;
  my $serverurl = $self->{serverurl};

  if ($serverurl =~ m!^(http|https)://([^/]*)(.*)$!) {
    my ($host, $file) = ($2, $3);
    $host = $1 if $host =~ /^([^:]*):(.*)$/;
    $self->{localserver} = $host;
    $self->{serverfile}  = $file;
  }
  if ($self->{localserver} !~ /^tequila\./) {
    my $binaddr = gethostbyname ($self->{localserver});
    my $srvaddr = join ('.', unpack ('C4', $binaddr));
    $self->{sessionsdir} = $self->{sessionsdir} . '/' . $srvaddr;
  }
}

sub getserverurl {
  my $self = shift;
  return $self->{serverurl};
}

sub setlogouturl {
  my $self = shift;
  $self->{logouturl} = shift;
}

sub usessl {
  my $self = shift;
  $self->{usessl} = shift;
}

sub allows {
  my ($self, $allow) = @_;
  $self->{allows} .= '|' if $self->{allows};
  $self->{allows} .= $allow;
}

sub setusername {
  my $self = shift;
  $self->{username} = shift;
}

sub setorg {
  my $self = shift;
  $self->{org} = shift;
}

sub setservice {
  my $self = shift;
  $self->{service} = shift;
}

sub setclientarg {
  my ($self, $key, $value) = @_;
  $self->{clientargs}->{$key} = $value;
}

sub getclientarg {
  my ($self, $key) = @_;
  return $self->{clientargs}->{$key};
}

sub usesessions {
  my $self = shift;
  $self->{usesessions} = shift;
}

sub setsessionsdir {
  my $self = shift;
  $self->{sessionsdir} = shift;
}

sub getsessionsdir {
  my $self = shift;
  return $self->{sessionsdir};
}

sub setsessionsduration {
  my $self = shift;
  $self->{sessionmax} = shift;
}

sub getsessionsduration {
  my $self = shift;
  return $self->{sessionmax};
}

sub loadargs {
  my  $clen = $ENV {CONTENT_LENGTH};
  my  $meth = $ENV {REQUEST_METHOD};
  my   $get = $ENV {QUERY_STRING};

  my $args;
  my $post = '';
  if ($meth eq 'POST') {
    read STDIN, $post, $clen;
    my $ctype = $ENV {CONTENT_TYPE};
    if ($ctype =~ /^multipart\/form-data;\s+boundary=(.*)$/) {
      my $boundary = $1;
      my @parts = split (/$boundary/, $post);
      shift @parts; pop @parts;

      my $pat1 = qq{\r\nContent-Disposition: form-data; name="(.*?)"};
      my $pat2 = qq{\r\nContent-Type: (.*?)\r\n\r\n(.*)};
      foreach my $part (@parts) {
        if($part =~ /^$pat1\r\n\r\n(.*)\r\n/is) {
          my  $name = $1;
          my $value = $2;
          $args->{$name} = $value;
          next;
        }
        if ($part =~ /^$pat1; filename="(.*?)"$pat2\r\n/is) {
          my     $name = $1;
          my $filename = $2; $filename =~ s/.*\\//; $filename =~ s/.*\///;
          my    $ctype = $3;
          my  $content = $4; $content =~ s/!$//;
          $args->{$name} = {
               filename => $filename,
            contenttype => $ctype,
                content => $content,
          };
          next;
        }
        if ($part =~ /^$pat1; filename="(.*?)"\r\n(.*)\r\n/is) {
          my     $name = $1;
          my $filename = $2; $filename =~ s/.*\\//; $filename =~ s/.*\///;
          my  $content = $3; $content =~ s/!$//;
          $args->{$name} = {
               filename => $filename,
            contenttype => "unknown",
                content => $content,
          };
          next;
        }
      }
      $post = '';
    }
  }
  my $all = $get . '&' . $post;
  my @fields = split (/&/, $all);
  foreach (@fields) {
    s/\+/ /g;
    s/%([0-9a-f]{2,2})/pack ("C", hex ($1))/gie;
  }
  foreach my $field (@fields) {
    next unless ($field =~ /=/);
    my ($key, $value) = split(/=/, $field, 2);
    #next unless $value;
    if ($key eq 'key') {
      $args->{$key} = $value;
    } else {
      my $oldval = $args->{$key};
      $args->{$key} = $oldval ? "$oldval,$value" : $value;
    }
  }
  return $args;
}

sub parseargs {
  my $qstr = shift;
  return unless $qstr;

  my $args;
  my @fields = split (/&/, $qstr);
  foreach (@fields) {
    s/\+/ /g;
    s/%([0-9a-f]{2,2})/pack ("C", hex ($1))/gie;
  }
  foreach my $field (@fields) {
    next unless ($field =~ /=/);
    my ($key, $value) = split (/=/, $field, 2);
    my $oldval = $args->{$key};
    $args->{$key} = $oldval ? "$oldval,$value" : $value;
  }
  return $args;
}

sub head {
  my ($self, $title) = @_;
  $title ||= 'Tequila';
  print qq{Content-Type: text/html;charset=$self->{charset}

      <html>
        <head>
          <title>$title</title>
        </head>
        <body>
  };
}

sub tail {
  my $self = shift;
  print qq{
        </body>
      </html>
  };
  exit;
}

sub error {
  my ($self, $msg1, $testing, $msg2) = @_;
  my $server = $self->{localserver};
  $self->head ('Tequila error');
  print qq{
      <table width="100%" height="100%"><tr><td valign="middle">
        <table width="600" border="1" cellspacing="0" align="center" cellpadding="5">
          <tr>
            <td bgcolor="#CCCCCC">
              <table width="100%">
                <tr>
                  <td>
                    <img src="http://$server/images/logo.gif" alt="Local logo">
                  </td>
                  <td bgcolor="#CCCCCC" align="right">
                    <font size="+2">Service <b>$self->{service}</b></font>
                  </td>
                </tr>
              </table>
            </td>
          </tr>  
          <tr>
            <td align="center"> 
              <table width="98%" cellspacing="0" bgcolor=white>
                <tr>
                  <td width="219">
                    <img src="http://$server/images/eye.gif" width="200" height="270">
                  </td>
                  <td align="center" valign="middle">
                    <font color="red" size="+1">
                      Tequila error : $msg1
                      <h3 align="center">Contact the manager of the application you
                          are trying to access.</h3>
                    </font>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </td></tr></table>
  };
  $self->tail ();
}

sub getaddrs {
  my $srv = shift;
  my ($name, $aliases, $addrtype, $length, @addresses) = gethostbyname ($srv);
  next unless @addresses;
  foreach (@addresses) {
    $_ = join ('.', unpack ('C4', $_));
  }
  return @addresses;
}

sub createserverrequest {
  my   $self = shift;
  my $starttime = Time::HiRes::time () if $self->{profile};
  $self->{urlaccess}  = $self->makeurlaccess () unless $self->{urlaccess};
  $self->{usecookies} = $self->{servercookies} ? 'on' : 'off';
  #
  #  We should use method POST, but we get trapped in the Apache infamous
  #  Method Not Allowed message.
  #
  my $method = 'GET';
  #my $method = 'POST';
  my $args;
  if ($self->{resource}) {
    $args->{resource} = $self->{resource};
    $args->{partner}  = $self->{partner} if $self->{partner};
  } else {
    foreach my $keyword (qw(partner resource origresource urlaccess service username
                allows allsensitive request wish require wantright forcelogin
                wantrole language identities usecookies authstrength debug allowedorgs
                nochecksrchost charset)) {
      next unless $self->{$keyword};
      my $value = $self->{$keyword};
      if (ref $value eq 'ARRAY') {
        $value = join ('+', @$value);
      }
      $args->{$keyword} = $value;
      $args->{$keyword} = escapeurl ($args->{$keyword}) if ($method eq 'GET');
    }
  }
  foreach my $key (keys %{$self->{clientargs}}) {
    next if $args->{$key};
    my $value = $self->{clientargs}->{$key};
    $value = escapeurl ($value) if ($method eq 'GET');
    $args->{$key} = $value;
  }
  $args->{dontappendkey} = 1 if $self->{usecookies};
  my    $server = $self->{localserver};
  my    $script = $self->{serverfile};
  my $serverurl = $self->{serverurl} || "http://$server$script";
  $serverurl    =~ s/\/tequila(\/|$)/\/tequilac$1/ if $self->{resource} || $self->{partner};
  $serverurl    =~ s/^http:/https:/ if $self->{checkcertificates} ||
                                       $self->{resource}          ||
                                       $self->{partner}           ||
                                       $self->{usessl};
  my ($status, $sock, $statusline) =
    $self->httpsocket ("$serverurl/createrequest", $method, $args);

  $self->error ("Bad connection to Tequila server ($serverurl), server says : $statusline")
    if ($status != 200);

  my $requestkey;
  my $nempty = 0;
  while (<$sock>) { # body
    last unless $_;
    s/^[\r\n]*$//;
    if (/^$/) {
      last if (++$nempty > 5);
    } else { $nempty = 0; }
    $requestkey = $1 if /^key=(.*)$/;
  }
  close ($sock);
  $self->error ("Bad response from local Tequila server ($server)") if !$requestkey;
  $self->{requestkey} = $requestkey;
  $self->setrequestcookie ();
  checkpoint ('Client.pm:createserverrequest', $starttime) if $self->{profile};
}

sub fetchattributes {
  my       $self = shift;
  my $starttime = Time::HiRes::time () if $self->{profile};
  my $requestkey = $self->{requestkey};
  my     $server = $self->{localserver};
  my  $serverurl = $self->{serverurl} || "http://$server/tequila";
  $serverurl     =~ s/\/tequila(\/|$)/\/tequilac$1/
    if ($self->{resource} || $self->{partner});
  $serverurl     =~ s/^http:/https:/ if $self->{checkcertificates} ||
                                        $self->{resource}          ||
                                        $self->{partner}           ||
                                        $self->{usessl};

  my $args = { key => $requestkey, };
  checkpoint ('Client.pm:fetchattributes1', $starttime) if $self->{profile};
  my ($status, $sock, $statusline) =
    $self->httpsocket ("$serverurl/fetchattributes", 'GET', $args);
  checkpoint ('Client.pm:fetchattributes2', $starttime) if $self->{profile};

  return if ($status == 451); # Invalid key.
  $self->error ("Bad connection to Tequila server ($serverurl), server says : $statusline")
    if ($status != 200);

  binmode ($sock, ':utf8') if ($self->{charset} =~ /^utf/);
  my ($org, $user, $host, $key, $sver, $attrs);
  while (<$sock>) { # body
    last unless $_;
    chomp; next if /^$/;
    my $orig_ = $_;
    # we *should* have UTF-8 encoded bytes as input
    Encode::_utf8_on ($_); # if ($self->{charset} =~ /^utf/);
    my $wellformedutf8 = Encode::is_utf8($_, 1) ? 1 : 0;
    # but if we don't, it certainly means we received some old Latin1
    if (!$wellformedutf8) {
      my $hexstr_orig_ = unpack('H*', $orig_);
      $hexstr_orig_ =~ s/..\K(?=.)/ /sg; # insert 1 space every 2 char
      warn ("fetchattributes: read line from socket is NOT well-formed utf-8 ($hexstr_orig_), will decode Latin1");
      $_ = Encode::decode('iso-8859-1', $orig_);
    }
    if (/^([^=]+)=(.*)$/) {
      my ($name, $value) = ($1, $2);
      if    ($name eq     'org') { $org  = $value; }
      elsif ($name eq    'user') { $user = $value; }
      elsif ($name eq    'host') { $host = $value; }
      elsif ($name eq     'key') { $key  = $value; }
      elsif ($name eq 'version') { $sver = $value; }
      else {
        if ($value =~ /^\\/) {
          $value = '';
          while (<$sock>) {
            last if /^[\r\n]*$/;
            $value .= $_;
          }
        }
        $attrs->{$name} = $value;
      }
    }
  }
  close ($sock);
  
  $self->error ("Tequila:fetchattributes: Malformed server response : org undefined")  unless $org;
  $self->error ("Tequila:fetchattributes: Malformed server response : user undefined") unless $user;
  $self->error ("Tequila:fetchattributes: Malformed server response : host undefined") unless $host;
  $self->error ("Tequila:fetchattributes: Malformed server response : key undefined")  unless $key;

  $self->{org}     = $org;
  $self->{user}    = $user;
  $self->{host}    = $host;
  $self->{version} = $sver;
  $self->{attrs}   = $attrs;

  if ($self->{usesessions}) {
    $self->{sessionkey} = genkey ();
    $self->createsession ();
  }
  checkpoint ('Client.pm:fetchattributes5', $starttime) if $self->{profile};
  return 1;
}

sub makeurlaccess () {
  my  $self = shift;
  my    $qs = $self->{querystring};
  my    $pi = $self->{pathinfo};
  my    $me = $self->{scriptname};
  my    $us = $self->{servername};
  my $proto = ($self->{https} && ($self->{https} eq 'on')) ? "https" : "http";
  my $urlaccess = "$proto://$us$me$pi";
  $urlaccess .= "?$qs" if $qs;
  return $urlaccess;
}

sub staticinit {
  configure ();
}

sub configure {
  my ($localserver, $serverurl, $sessionsdir);
  srand (time ^ ($$ + ($$ << 15)));
  if (open (CONF, "/etc/tequila.conf")) {
    while (<CONF>) {
      chomp;
      next if (/^#/ || /^$/);
      $localserver = $1 if /^TequilaServer:\s*(.*)$/i;
      $serverurl   = $1 if /^TequilaServerUrl:\s*(.*)$/i;
      $sessionsdir = $1 if /^SessionsDir:\s*(.*)$/i;
    }
    close (CONF);
  }
  unless ($sessionsdir) {
    if (eval "use Tequila::Config; 1;") {
      $localserver = $Tequila::Config::server;
      $serverurl   = $Tequila::Config::serverurl;
      $sessionsdir = $Tequila::Config::sessionsdir;
    }
  }
  unless ($sessionsdir) {
    my $scriptfile = $ENV {SCRIPT_FILENAME};
    $scriptfile =~ s/\/[^\/]*$//;
    if (-d "$scriptfile/config/Sessions" && -w "$scriptfile/config/Sessions") {
      $sessionsdir = "$scriptfile/config/Sessions";
    }
  }
  my $tries;
  unless ($sessionsdir) {
    $sessionsdir = '/var/www/tequila/Tequila/Sessions';
    $tries = $sessionsdir;
    unless ($sessionsdir && -d $sessionsdir && -w $sessionsdir) { 
      $sessionsdir = $ENV {DOCUMENT_ROOT};
      $sessionsdir =~ s!/[^/]*/*$!/Sessions!;  # One step over DOCUMENT_ROOT.
      $tries .= ', ' . $sessionsdir if $sessionsdir;
      unless (-d $sessionsdir && -w $sessionsdir) {
        $sessionsdir =~ s!/Sessions$!/Tequila/Sessions!;
        $tries .= ', ' . $sessionsdir if $sessionsdir;
      }
      unless (-d $sessionsdir && -w $sessionsdir) {
        $sessionsdir =~ s!/Tequila/Sessions$!/private/Tequila/Sessions!;
        $tries .= ', ' . $sessionsdir if $sessionsdir;
      }
    }
  }
  unless ($sessionsdir) {
    my $self = { org => 'Unknown yet', service => 'Unknown yet', };
    bless $self, 'Tequila::Client';
    $self->error ("Unable to find the Session directory, (tried $tries).");
  }
  unless ($localserver) {
    my $localdomain = `/bin/hostname -d`;
    chomp $localdomain;
    $localdomain ||= 'epfl.ch';
    $localserver  = "tequila.$localdomain";
  }
  unless ($serverurl) {
    $serverurl  = "https://$localserver/tequila";
  }
  return {
         server => $localserver,
    sessionsdir => $sessionsdir,
      serverurl => $serverurl,
  }
}

sub escapeurl {
  local ($_) = @_;
  s/([^\w\+\.\-])/sprintf("%%%X",ord($1))/ge;
  return $_;
}

sub genkey {
  my $key = "";
  for (my $i = 0; $i < 32; $i++) {
    my $car .= int rand (35);
    $key .= ('a'..'z', '0'..'9')[$car];
  }
  return $key;
}

sub httpsocket {
  my ($self, $url, $method, $args) = @_;
  my $starttime = Time::HiRes::time () if $self->{profile};
  my $sock;
  my $nredir = 0;
  while ($url) {
    $self->error ("Tequila:httpsocket: invalid URL : $url")
      if ($url !~ m!^(http|https)://([^/]*)(.*)$!);
    my ($prot, $host, $file, $port) = ($1, $2, $3, 0);
    ($host, $port) = split (/:/, $host) if ($host =~ /:/);
    unless ($port) {
      $port = ($prot eq 'https') ? 443 : 80;
    }
    checkpoint ('Client.pm:httpsocket1', $starttime) if $self->{profile};
    $sock = ($prot eq 'https')
      ? $self->sslsocket ($host, $port)
      : new IO::Socket::INET ("$host:$port");
    $self->error ("Tequila:httpsocket: unable to open $prot socket ".
                  "connection to $host (for $url)") unless $sock;
    checkpoint ('Client.pm:httpsocket2', $starttime) if $self->{profile};

    if ($method eq 'POST') {
      my $argstring = '';
      foreach my $arg (keys %$args) {
        $argstring .= "$arg=$args->{$arg}\n";
      }
      my $arglen = length ($argstring);
      print $sock "POST $file HTTP/1.0\r\n",
                  "Host: $host\r\n",
                  "Content-type: application/x-www-form-urlencoded\r\n",
                  "Content-length: $arglen\r\n",
                  "\r\n",
                  "$argstring" ||
        $self->error ("Tequila:httpsocket: unable to send data to $host:$port");
    } else {
      my $argstring = '';
      foreach my $arg (keys %$args) {
        $argstring .= "&$arg=$args->{$arg}";
      }
      $argstring =~ s/^&//;
      print $sock "GET $file?$argstring HTTP/1.0\r\n",
                  "Host: $host\r\n",
                  "\r\n" ||
        $self->error ("Tequila:httpsocket: unable to send data to $host:$port");
    }
    $url = 0;
    my $statusline = <$sock>;
    $statusline = <$sock> unless $statusline;
    $statusline =~ s/[\r\n]//g;
    return (452, $sock, "No answer from server") unless $statusline;
    my ($status) = ($statusline =~ / (\d*) /); # HTTP/1.x 200 OK
    while (<$sock>) { # headers
      last unless $_;
      s/^[\r\n]*$//;
      if (/^Location:\s*(.*)$/) {
        $url = $1;
      }
      last if /^$/;
    }
    if (($status != 200) && !$url) {
      return ($status, $sock, $statusline);
    }
    if ($url) {
      close ($sock);
      $nredir++;
      $self->error ("Tequila:httpsocket: maximun number of HTTP redirect : $nredir")
        if ($nredir > 20);
    }
  }
  checkpoint ('Client.pm:httpsocket', $starttime) if $self->{profile};
  return (200, $sock);
}

sub sslsocket {
  my ($self, $server, $port) = @_;
  $port = 'https' unless $port;
  my ($sock, %sslargs);
  $sslargs {PeerAddr} = "$server:$port";
  $sslargs {SSL_verify_mode} = 0x00;
  if ($self->{checkcertificates} && $self->{cafile}) {
    $sslargs {SSL_verify_mode} = 0x01;
    $sslargs {SSL_ca_file}     = $self->{cafile};
  }
  if ($self->{keyfile} && $self->{certfile}) {
    $sslargs {SSL_use_cert}  = 1;
    $sslargs {SSL_key_file}  = $self->{keyfile};
    $sslargs {SSL_cert_file} = $self->{certfile};
  }
  $sock = new IO::Socket::SSL (%sslargs);

  if ($self->{checkcertificates} && $self->{cafile}) {
    my $subject = $sock->peer_certificate ('subject');
    my @cns = split (/\/CN=/i, $subject);
    shift @cns;
    my $ok = 0;
    foreach my $cn (@cns) {
      if ($cn =~ /^\((.*)\)(.*)$/) {
        my $domain = $2;
        my @names = split (/\|/, $1);
        foreach my $name (@names) {
          my $fdqn = $name . $domain;
          if (uc $server eq uc $fdqn) { $ok = 1; last; }
        }
        last if $ok;
      } else {
        if (uc $server eq uc $cn) { $ok = 1; last; }
      }
      $self->error ("Tequila:sslsocket: invalid certificate for $server : $subject") unless $ok;
    }
  }
  return $sock;
}

sub checkpoint {
  my ($label, $starttime) = @_;
  my $elapsed = int ((Time::HiRes::time () - $starttime) * 1000);
  warn scalar localtime, " Tequila:$label: elapsed = $elapsed ms.\n"; 
}

1;
