#!/usr/bin/perl
#
##############################################################################
#
# File Name:    MyCADI
# Description:  
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Tue Jul  9 14:20:42 CEST 2002
# Revision:     
#
##############################################################################
#
#
use strict;
use utf8;
use Data::Dumper;
use Cadi::CadiDB;

package Cadi::MyCadi;

my $errmsg;

sub new {
  my $class = shift;
  my $args = (@_ == 1) ? shift : { @_ } ;
  my $self = {
      caller => undef,
      dbname => undef,
      errmsg => undef,
     errcode => undef,
          db => undef,
        utf8 => 1,
    language => 'fr',
       debug => 0,
     verbose => 0,
       trace => 1,
  };
  foreach my $arg (keys %$args) {
    $self->{$arg} = $args->{$arg};
  }
  warn "new Cadi::MyCadi ()\n" if $self->{verbose};
  $self->{db} = new Cadi::CadiDB (%$self);
  unless ($self->{db}) {
    $errmsg = $Cadi::CadiDB::errmsg;
    warn "MyCadi:new: $errmsg\n";
    return;
  }
  bless $self, $class;
}

#
# Web services
#
sub listWS {
  my $self = shift;
  
  my $sql = qq{select * from WSServices where removed is null};
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("listWS1 : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth);
  return $self->error ("listWS2 : $self->{db}->{errmsg}") unless $rv;
  my @wssrvs;
  while (my $ws = $sth->fetchrow_hashref) {
    push (@wssrvs, $ws);
  }
  return @wssrvs;
}

sub loadWS {
  my ($self, $name) = @_;
  return $self->error ("loadWS : no name") unless $name;
  
  my $sql = qq{select * from WSServices where name = ? and removed is null};
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("loadWS1 : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, $name);
  return $self->error ("loadWS2 : $self->{db}->{errmsg}") unless $rv;
  my $ws = $sth->fetchrow_hashref;
  return unless $ws;
  #
  # Callers
  #
  my $sql = qq{select * from WSAppsCallers where ws = ? and removed is null};
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("loadWS3 : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, $name);
  return $self->error ("loadWS4 : $self->{db}->{errmsg}") unless $rv;
  
  my $clients;
  my $calleracls;
  while (my $acl = $sth->fetchrow_hashref) {
    my $app = $acl->{app};
    push (@{$calleracls->{$app}}, $acl);
    $clients->{$app} = 1;
  }
  $sth->finish;  
  #
  # Hosts
  #
  my $sql = qq{select * from WSAppsHosts where ws = ? and removed is null};
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("loadWS5 : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, $name);
  return $self->error ("loadWS6 : $self->{db}->{errmsg}") unless $rv;
  my $hostacls;
  while (my $acl = $sth->fetchrow_hashref) {
    my $app = $acl->{app};
    push (@{$hostacls->{$app}}, $acl);
    $clients->{$app} = 1;
  }
  $sth->finish;
  
  my $appacl;
  foreach my $app (keys %$clients) {
    if ($calleracls->{$app}) {
      foreach my $acl (@{$calleracls->{$app}}) {
        push (@{$appacl->{$app}->{callers}}, $acl);
      }
    }
    if ($hostacls->{$app}) {
      foreach my $acl (@{$hostacls->{$app}}) {
        push (@{$appacl->{$app}->{hosts}}, $acl);
      }
    }
  }
  return {
        name => $ws->{name},
    creation => $ws->{creation},
        acls => $appacl,
  };
}

sub addWS {
  my ($self, $name, $caller) = @_;
  my $ws = $self->loadWS ($name);
  return $self->error ("addWS : WS $name already exists") if $ws;
  my $sql = qq{
    insert into WSServices
    values(?, now(), null)
  };
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("addWS : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, $name);
  return $self->error ("addWS : $self->{db}->{errmsg}") unless $rv;
  return $self->loadWS ($name);
}

#
# ACL's
#

sub addWSCallerACL {
  my ($self, $wsname, $clname, $caller) = @_;
  my $sql = qq{
    insert into WSAppsCallers
    values(?, ?, ?, null, ?, now(), null)
  };
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("addWSCallerACL : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, $wsname, $clname, $caller, $caller);
  return $self->error ("addWSCallerACL : $self->{db}->{errmsg}") unless $rv;
  return 1;
}

sub delWSCallerACL {
  my ($self, $wsname, $clname, $caller) = @_;
  my $sql = qq{
    update WSAppsCallers
       set removed = now()
    where     ws = ?
      and    app = ?
      and sciper = ?
  };
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("delWSCallerACL : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, $wsname, $clname, $caller);
  return $self->error ("delWSCallerACL : $self->{db}->{errmsg}") unless $rv;
  return 1;
}

sub addWSHostACL {
  my ($self, $wsname, $clname, $host, $caller) = @_;
  my $sql = qq{
    insert into WSAppsHosts
    values(?, ?, ?, ?, now(), null)
  };
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("addWSHostACL : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, $wsname, $clname, $host, $caller);
  return $self->error ("addWSHostACL : $self->{db}->{errmsg}") unless $rv;
  return 1;
}

sub delWSHostACL {
  my ($self, $wsname, $clname, $host, $caller) = @_;
  my $sql = qq{
    update WSAppsHosts
       set removed = now()
    where   ws = ?
      and  app = ?
      and addr = ?
  };
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("delWSHostACL : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, $wsname, $clname, $host);
  return $self->error ("delWSHostACL : $self->{db}->{errmsg}") unless $rv;
  return 1;
}

sub listWSClients {
  my $self = shift;
  my $sql = qq{select * from WSClients};
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("listWSClients1 : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth);
  return $self->error ("listWSClients2 : $self->{db}->{errmsg}") unless $rv;
  my @clients;
  while (my $client = $sth->fetchrow_hashref) {
    push (@clients, $client);
  }
  return @clients;
}

sub addWSClient {
  my ($self, $name, $owner, $contact) = @_;
  my $sql = qq{select * from WSClients where name = ?};
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("addWSClient1 : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, $name);
  return $self->error ("addWSClient2 : $self->{db}->{errmsg}") unless $rv;
  my $client = $sth->fetchrow_hashref;
  return $self->error ("addWSClient : Client $name already exists") if $client;

  my $sql = qq{
    insert into WSClients set
          name = ?,
         owner = ?,
       contact = ?,
      creation = now()
  };
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("addWSClient3 : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, $name, $owner, $contact);
  return $self->error ("addWSClient4 : $self->{db}->{errmsg}") unless $rv;
  return $self->loadWSClient ($name);
}

sub loadWSClient {
  my ($self, $name) = @_;
  my $sql = qq{select * from WSClients where name = ?};
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("listWSClients1 : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, $name);
  return $self->error ("listWSClients2 : $self->{db}->{errmsg}") unless $rv;
  my $client = $sth->fetchrow_hashref;
  return unless $client;
  #
  # Callers
  #
  my $sql = qq{select * from WSAppsCallers where app = ? and removed is null};
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("loadWSClient : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, $name);
  return $self->error ("loadWSClient : $self->{db}->{errmsg}") unless $rv;
  
  my $services;
  my $calleracls;
  while (my $acl = $sth->fetchrow_hashref) {
    my $ws = $acl->{ws};
    push (@{$calleracls->{$ws}}, $acl);
    $services->{$ws} = 1;
  }
  $sth->finish;  
  #
  # Hosts
  #
  my $sql = qq{select * from WSAppsHosts where app = ? and removed is null};
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("loadWSClient : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, $name);
  return $self->error ("loadWSClient : $self->{db}->{errmsg}") unless $rv;
  my $hostacls;
  while (my $acl = $sth->fetchrow_hashref) {
    my $ws = $acl->{ws};
    push (@{$hostacls->{$ws}}, $acl);
    $services->{$ws} = 1;
  }
  $sth->finish;  
  
  my $wsacl;
  foreach my $ws (keys %$services) {
    if ($calleracls->{$ws}) {
      foreach my $acl (@{$calleracls->{$ws}}) {
        push (@{$wsacl->{$ws}->{callers}}, $acl);
      }
    }
    if ($hostacls->{$ws}) {
      foreach my $acl (@{$hostacls->{$ws}}) {
        push (@{$wsacl->{$ws}->{hosts}}, $acl);
      }
    }
  }
  $client->{acls} = $wsacl;
  return $client;
}

sub deleteWSClient {
  my ($self, $name) = @_;
  my $client = $self->loadWSClient ($name);
  return unless $client;
  
  my $sql = qq{delete from WSClients where name = ?};
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("deleteWSClient1 : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, $name);
  return $self->error ("deleteWSClient2 : $self->{db}->{errmsg}") unless $rv;
  my $client = $sth->fetchrow_hashref;
  return unless $client;
  #
  # Callers
  #
  my $sql = qq{
    update WSAppsCallers
       set removed = now()
     where app = ?
  };
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("deleteWSClient3 : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, $name);
  return $self->error ("deleteWSClient4 : $self->{db}->{errmsg}") unless $rv;
  #
  # Hosts
  #
  my $sql = qq{
    update WSAppsHosts
       set removed = now()
     where app = ?
  };
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("deleteWSClient5 : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, $name);
  return $self->error ("deleteWSClient6 : $self->{db}->{errmsg}") unless $rv;

  return 1;
}

#
# Databases
#

sub listDBClients {
  my $self = shift;
  my $sql = qq{select * from DBClients};
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("listDBClients1 : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth);
  return $self->error ("listDBClients2 : $self->{db}->{errmsg}") unless $rv;
  my @clients;
  while (my $client = $sth->fetchrow_hashref) {
    push (@clients, $client);
  }
  return @clients;
}

sub listDBTables {
  my ($self, $name) = @_;
  my $db = new Cadi::CadiDB (
    dbname => 'cadi',
      utf8 => 1,
     trace => 1,
  );
  $db->pingdb ();
  return $self->error ("Unable to access CADI database, retry later") unless $db;
  my $tables = $db->{db}->{dbh}->selectcol_arrayref ("show tables from CADI_$name");
  return $self->error ("listDBTables : $self->{db}->{errmsg}") unless $tables;
  my @tables = grep (!/_old$/, @$tables);
  return @tables;
}

sub getDBTable {
  my ($self, $dbname, $tbname) = @_;
  my $db = new Cadi::CadiDB (
    dbname => 'cadi',
      utf8 => 1,
     trace => 1,
  );
  $db->pingdb ();
  return $self->error ("Unable to access CADI database, retry later") unless $db;

  my     $sth = $db->{db}->{dbh}->table_info (undef, "CADI_$dbname", $tbname, undef);
  my $table = $sth->fetchall_arrayref ({});
  #print STDERR Data::Dumper->Dump ($table);

  my     $sth = $db->{db}->{dbh}->column_info (undef, "CADI_$dbname", $tbname, undef);
  my $columns = $sth->fetchall_arrayref ({});
  my @columns;
  foreach my $column (@$columns) {
    push (@columns, {
      name => $column->{COLUMN_NAME},
      type => $column->{mysql_type_name},
    })
  }
  my $type = @$table [0]->{TABLE_TYPE};
  return {
       name => $tbname,
         db => $dbname,
       type => $type,
    columns => \@columns,
  };
}

sub error {
  my ($self, @msgs) = @_;
  $self->{errmsg} = 'MyCADI error: ' . join (' ', @msgs);
  warn scalar localtime, " $self->{errmsg}\n";
  return;
}

my $createtable = qq{
  create table WSClients (
           name varchar(32) not null,
          owner char(6),
        contact varchar(64),
       creation datetime,
            key (name),
          index (owner)
  );
  create table WSServices (
           name varchar(32) not null,
       creation datetime,
        removed datetime default null,
            key (name)
  );
  create table DBClients (
           name varchar(32) not null,
          owner char(6),
        contact varchar(64),
       creation datetime,
            key (name),
          index (owner)
  );
};

