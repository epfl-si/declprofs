#!/usr/bin/perl
#

use strict;
use Encode;
use DBI;
use DBD::mysql;

package Cadi::CadiDB;

use vars qw{$verbose $errmsg};
my $messages;

sub new { # Exported
  my $class = shift;
  my $args = (@_ == 1) ? shift : { @_ } ;
  my $self = {
         db => undef,
     noping => undef,
       utf8 => undef,
   language => 'en',
     errmsg => undef,
    errcode => undef,
    profile => undef,
      debug => 0,
    verbose => 0,
      trace => 0,
  };
  my $dbkey = $args->{dbname};
  warn "New CadiDB ($dbkey)\n" if $self->{verbose};
  unless ($dbkey) {
    $errmsg = "No db name.";
    warn "$errmsg\n";
    return;
  }
  foreach my $arg (keys %$args) {
    $self->{$arg} = $args->{$arg};
  }
  if ($self->{profile}) {
    $self->{profile} = 0 unless eval "use Time::HiRes; 1;";
  }
  my ($dbname, $dbhost, $dbuser, $dbpwd) = loaddb ($dbkey);
  unless ($dbname && $dbhost && $dbuser && $dbpwd) {
    $errmsg = "Database $dbkey not found in DB config file.";
    warn "$errmsg\n";
    return;
  }
  $self->{db} = {
    host => $dbhost,
    name => $dbname,
    user => $dbuser,
    pass => $dbpwd,
  };
  initmessages ($self);
  bless $self, $class;
}

sub query {
  my ($self, $sql, @args) = @_;
  warn "CadiDB:query:sql = $sql\n" if $self->{profile};
  warnsql ($sql) if $self->{tracesql};
  return unless $self->pingdb ();
  my $dbh = $self->{db}->{dbh};
  my $sth = $dbh->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Unable to query $self->{dbname} database : $dbh->errstr.";
    return;
  }
  my $rv = $sth->execute (@args);
  unless ($rv) {
    $sql = pack ('C*', unpack ('U*', $sql));
    $self->{errmsg} = "Unable to execute $sql : $dbh->errstr.";
    return;
  }
  return $sth;
}

sub prepare {
  my ($self, $sql) = @_;
  if ($self->{profile}) {
    $sql =~ s/\s+/ /g;
    warn "CadiDB:prepare:sql = $sql\n" if $self->{profile};
  }
  warnsql ($sql) if $self->{tracesql};
  return unless $self->pingdb ();
  my $dbh = $self->{db}->{dbh};
  my $sth = $dbh->prepare ($sql);
  unless ($sth) {
    $sql = pack ('C*', unpack ('U*', $sql));
    $self->{errmsg} = "Unable to prepare $sql : $dbh->errstr.";
    return;
  }
  return $sth;
}

sub execute {
  my ($self, $sth, @args) = @_;
  my $starttime = Time::HiRes::time () if $self->{profile};
  my  $rv = $sth->execute (@args);
  unless ($rv) {
    $self->{errmsg} = "Unable to execute : $sth->errstr.";
    return;
  }
  if ($self->{profile}) {
    my $elapsed = int ((Time::HiRes::time () - $starttime) * 1000);
    warn "CadiDB:execute took $elapsed milliseconds";
  }
  return $rv;
}

sub pingdb {
  my $self = shift;
  my   $db = $self->{db};
  unless ($db) {
    $self->{errmsg} = "No database selected.";
    return;
  }
  my $dbh = $db->{dbh};
  unless ($dbh) {
    warn "Cadi::CadiDB::Initializing connection.\n" if $self->{verbose};
    $dbh = $self->{db}->{dbh} = $self->dbconnect ();
    unless ($dbh) {
      $self->{errmsg} = "Unable to ping $self->{dbname} database.";
      return;
    }
  }
  return 1 if $self->{noping};
  my $sth = $dbh->do ('select 1') || $dbh->do ('select 1');
  #warn "Reusing connection.\n" if ($sth && $self->{verbose});
  return 1 if $sth;
  warn "Connection is bad.\n" if $self->{verbose};

  $dbh = $self->{db}->{dbh} = $self->dbconnect ();
  unless ($dbh) { warn "$errmsg\n"; return; }
  my $sth = $dbh->do ('select 1');
  unless ($sth) {
    $self->{errmsg} = "Unable to ping $self->{dbname} database.";
    return;
  }
  warn "New connection is OK.\n" if $self->{verbose};
  return 1;
}

sub dbconnect {
  my $self = shift;
  my   $db = $self->{db};
  if ($db->{name} eq 'oath') {
    $db->{name} = 'gaspar';
  }
  warn "Cadi::CadiDB::dbconnect ($db->{host}, $db->{name}, $db->{user}, ".
       "utf8 = $self->{utf8}).\n" if $self->{verbose};

  my $dsn = "DBI:mysql:database=$db->{name};host=$db->{host}";
  $dsn .= ";mysql_enable_utf8=1" if $self->{utf8};
  my $dbh = DBI->connect ($dsn, $db->{user}, $db->{pass},
    {
      PrintError => 1,
      AutoCommit => 1,
    }
  );
  return unless $dbh;
  $dbh->{mysql_auto_reconnect} = 1;
  $dbh->{mysql_enable_utf8}    = 1 if $self->{utf8};
  return $dbh;
}

sub loaddb {
  my $dbkey = shift;
  my @dbconfdirs = (
    '/etc',
    '/usr/local/etc',
    '/opt/dinfo/etc',
    '/var/www/vhosts/tequila.epfl.ch/private/Tequila'
  );
  my $dbconfdir;
  if ($ENV {DBCONFDIR}) {
    $dbconfdir = $ENV {DBCONFDIR};
    open (DBCONF, "$dbconfdir/dbs.conf") || do {
      $errmsg = "Unable to read DB config file ($dbconfdir/dbs.conf) : $!";
      warn "$errmsg\n";
      return;
    };
  
  } else {
    foreach my $confdir (@dbconfdirs) {
      if (open (DBCONF, "$confdir/dbs.conf")) {
        $dbconfdir = $confdir;
        last;
      }
    }
    unless ($dbconfdir) {
      $errmsg = "Unable to read DB config file (tried @dbconfdirs) : $!";
      warn "$errmsg\n";
      return;
    
    }
  }
  my ($dbname, $dbhost, $dbuser, $dbpwd);
  while (<DBCONF>) {
    chomp; next if /^#/;
    my @fields = split (/\t+/);
    my $key = (@fields == 5)
      ? shift @fields
      : $fields [0]
      ;
    if ($key eq $dbkey) {
      ($dbname, $dbhost, $dbuser, $dbpwd) = @fields;
      last;
    }
  }
  close (DBCONF);
  return ($dbname, $dbhost, $dbuser, $dbpwd);
}

sub trace {
  my ($self, $trace) = @_;
  $self->{trace} = $trace;
}

sub warnsql {
  my $sql = shift;
  $sql =~ s/\s+/ /g;
  warn "sql = $sql\n";
}

sub initmessages {
  my $self = shift;
  $messages = {
    nodbname => {
      fr => "Pas de nom de base de donn�e",
      en => "No database name",
    },
    invaliddbname => {
      fr => "Nom de base de donn�e inconnu : %s",
      en => "Unknown database name : %s",
    },
    unabletoconnect => {
      fr => "Unable to connect to %s database : %s",
      en => "Unable to connect to %s database : %s",
    },
    unabletoping => {
      fr => "Unable to ping %s database",
      en => "Unable to ping %s database",
    },
    unabletoexecute => {
      fr => "Unable to execute %s : %s",
      en => "Unable to execute %s : %s",
    },
  };
  my    $language = $self->{language};
  my $defaultlang = $self->{defaultlang} || 'en';
  no strict 'refs';
  foreach my $key (keys %$messages) {
    my $msg = $messages->{$key}->{$language} || $messages->{$key}->{$defaultlang};
    ${$key} = Encode::decode ('iso-8859-1', $msg);
  }
}

sub error {
  my ($self, $sub, $msgcode, @args) = @_;
  my  $msghash = $messages->{$msgcode};
  my $language = $self->{language} || 'en';
  my  $message = $msghash->{$language};
  $self->{errmsg} = sprintf ("$sub : $message", @args);
}

sub getconfig {
  my $dbkey = shift;
  my ($dbname, $dbhost, $dbuser, $dbpwd) = loaddb ($dbkey);
  unless ($dbname && $dbhost && $dbuser && $dbpwd) {
    msg ("Database $dbkey not found in DB config file : $!");
    return;
  }
  return {
    host => $dbhost,
      db => $dbname,
    user => $dbuser,
     pwd => $dbpwd,
  };
}

sub msg {
  my $msg = join (' ', @_);
  my $command = $0; $command =~ s!^./!!;
  warn scalar localtime, " : $command : $msg\n";
}
#
# DBI static call
#
sub dbiconnect {
  my $dbkey = shift;
  my ($dbname, $dbhost, $dbuser, $dbpwd) = loaddb ($dbkey);
  unless ($dbname && $dbhost && $dbuser && $dbpwd) {
    msg ("Database $dbkey not found in DB config file : $!");
    return;
  }
  my $dsn = "DBI:mysql:database=$dbname;host=$dbhost";
  my $dbh = DBI->connect ($dsn, $dbuser, $dbpwd);
  unless ($dbh) {
    $errmsg = $DBI::errstr;
    msg ("Unable to connect do database $dbname : $errmsg");
  }
  $dbh->{mysql_auto_reconnect} = 1;
  return $dbh;
}

sub connect {
  dbiconnect (@_);
}

sub printstack {
  my $depth = 0;
  while (my ($package, $filename, $line) = caller ($depth++)) {
    warn "$filename : $package line $line.\n";
  }
}


1;
