#!/usr/bin/perl
#
use strict;
use utf8;
use Encode;
use Cadi::CadiDB;

package Cadi::OAuth2;

my $errmsg;

sub new { # Exported
  my $class = shift;
  my $args = (@_ == 1) ? shift : { @_ } ;
  my $self = {
      caller => undef,
     dinfodb => undef,
      errmsg => undef,
     errcode => undef,
        utf8 => 0,
    language => 'fr',
       debug => 0,
     verbose => 0,
       trace => 0,
    tracesql => 0,
  };
  foreach my $arg (keys %$args) {
    $self->{$arg} = $args->{$arg};
  }
  warn "new Cadi::OAuth2 ()\n" if $self->{verbose};
  $self->{teqdb} = new Cadi::CadiDB (
     dbname => 'tequila',
      trace => $self->{trace},
    verbose => $self->{verbose},
       utf8 => $self->{utf8},
  );
  unless ($self->{teqdb}) {
    $errmsg = "Unable to connect database : $Cadi::CadiDB::errmsg";
    return;
  }
  bless $self, $class;
}
#
# Clients
#
# id             | int(11)
# name           | varchar(64)
# owner          | char(6)
# client_id      | varchar(32)
# client_secret  | varchar(32)
# redirect_uri   | varchar(250)
# limited_access | tinyint(1)
# status         | enum('development','pending','approved','rejected')
# auto_approve   | tinyint(4)
# username       | varchar(32)
# password       | varchar(32)
# suspended      | tinyint(1)
# notes          | tinytext
# codelifespan   | int(11)
# trusted        | tinyint(4)
#
sub listClients {
  my $self = shift;
  my $sql = qq{select * from oauth_clients};
  my $sth = $self->{teqdb}->prepare ($sql);
  return $self->error ("listClients : $self->{teqdb}->{errmsg}") unless $sth;
  my  $rv = $self->{teqdb}->execute ($sth);
  return $self->error ("listClients : $self->{teqdb}->{errmsg}") unless $rv;
  my @clients;
  while (my $client = $sth->fetchrow_hashref) {
    push (@clients, $client);
  }
  return @clients;
}

sub getClient {
  my ($self, $client_id) = @_;
  return $self->error ('getClient : no client_id') unless $client_id;
  my $sql = qq{
    select *
      from oauth_clients
     where client_id = ?
  };
  my $sth = $self->{teqdb}->prepare ($sql);
  return $self->error ("getClient : $self->{teqdb}->{errmsg}") unless $sth;
  my  $rv = $self->{teqdb}->execute ($sth,  $client_id);
  return $self->error ("getClient : $self->{teqdb}->{errmsg}") unless $rv;
  my $client = $sth->fetchrow_hashref;
  return $client;
}

sub searchClients {
  my ($self, $filter) = @_;
  my  $where = join (', ', map { "$_ = ?" } keys %$filter);
  my @values; 
  foreach my $key (keys %$filter) {
    push (@values, $filter->{$key});
  }
  my $sql = qq{select * from oauth_clients where $where};
  my $sth = $self->{teqdb}->prepare ($sql);
  return $self->error ("searchClients : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{teqdb}->execute ($sth, @values);
  return $self->error ("searchClients : $self->{db}->{errmsg}") unless $rv;
  my @clients;
  while (my $client = $sth->fetchrow_hashref) {
    push (@clients, $client);
  }
  return @clients;
}



#
# Codes
#
# client_id    | varchar(32)
# redirect_uri | varchar(250)
# username     | varchar(64)
# uniqueid     | char(6)
# scopes       | varchar(128)
# value        | varchar(64)
# device       | varchar(128)
# created      | datetime
# lastused     | datetime
#
sub listCodes {
  my $self = shift;
  my $sql = qq{select * from oauth_codes};
  my $sth = $self->{teqdb}->prepare ($sql);
  return $self->error ("listCodes : $self->{teqdb}->{errmsg}") unless $sth;
  my  $rv = $self->{teqdb}->execute ($sth);
  return $self->error ("listCodes : $self->{teqdb}->{errmsg}") unless $rv;
  my @codes;
  while (my $code = $sth->fetchrow_hashref) {
    push (@codes, $code);
  }
  return @codes;
}

sub getCode {
  my ($self, $value) = @_;
  return $self->error ('getCode : no value') unless $value;
  my $sql = qq{
    select *
      from oauth_codes
     where value = ?
  };
  my $sth = $self->{teqdb}->prepare ($sql);
  return $self->error ("getCode : $self->{teqdb}->{errmsg}") unless $sth;
  my  $rv = $self->{teqdb}->execute ($sth,  $value);
  return $self->error ("getCode : $self->{teqdb}->{errmsg}") unless $rv;
  my $client = $sth->fetchrow_hashref;
  return $client;
}

sub searchCodes {
  my ($self, $filter) = @_;
  my  $where = join (', ', map { "$_ = ?" } keys %$filter);
  my @values; 
  foreach my $key (keys %$filter) {
    push (@values, $filter->{$key});
  }
  my $sql = qq{select * from oauth_codes where $where};
  warn "COUCOU:searchCodes:sql = $sql, values = @values\n";
  my $sth = $self->{teqdb}->prepare ($sql);
  return $self->error ("searchCodes : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{teqdb}->execute ($sth, @values);
  return $self->error ("searchCodes : $self->{db}->{errmsg}") unless $rv;
  my @codes;
  while (my $code = $sth->fetchrow_hashref) {
    push (@codes, $code);
  }
  return @codes;
}

sub addCode {
  my ($self, $client_id, $redirect_uri, $username, $uniqueid, $scopes, $device) = @_;
  $self->message ("createCode ($client_id, $username, $uniqueid, $scopes)")
    if $self->{trace};
  my $teqdb = $self->{teqdb};
  return $self->error ('createCode1') unless $teqdb;
  
  $scopes =~ s/[\s,]+/ /g;
  my $code = md5_hex (time . uniqueid ());
  my $sql = qq{
    insert into oauth_codes set
         client_id = ?,
      redirect_uri = ?,
          username = ?,
          uniqueid = ?,
            scopes = ?,
             value = ?,
            device = ?,
           created = now(),
         lastused  = now()
  };
  my $sth = $teqdb->prepare ($sql);
  return $self->error ('createCode2') unless $sth;
  my $rv = $sth->execute (
    $client_id,
    $redirect_uri,
    $username,
    $uniqueid,
    $scopes,
    $code,
    $device
  );
  return $self->error ('createCode3') unless $rv;
  return $code;
}

sub deleteCode {
  my ($self, $code) = @_;
  return unless $code;
  my $teqdb = $self->{teqdb};
  return $self->error ('deleteCode1') unless $teqdb;

  my $sql = qq{
    delete from oauth_codes
     where value = ?
  };
  my $sth = $teqdb->prepare ($sql);
  return $self->error ('deleteCode2') unless $sth;
  my $rv = $sth->execute ($code);
  return $self->error ('deleteCode3') unless $rv;
  $self->deleteCodeTokens ($code);
  return 1;
}

sub deleteUserCodes {
  my ($self, $username, $device, $client_id) = @_;
  return unless $username;
  my $teqdb = $self->{teqdb};

  return $self->error ('deleteUserCodes1') unless $teqdb;

  my $field = ($username =~ /^[a-z]*$/) ? 'username' : 'uniqueid';
  my $sql = qq{select * from oauth_codes where $field = ?};
  my @values = ($username);
  if ($device) {
    $sql .= qq{ and device = ?};
    push (@values, $device);
  }
  if ($client_id) {
    $sql .= qq{ and client_id = ?};
    push (@values, $client_id);
  }
  my $sth = $teqdb->prepare ($sql);
  return $self->error ('deleteUserCodes2') unless $sth;
  my $rv = $sth->execute (@values);
  return $self->error ('deleteUserCodes3') unless $rv;

  while (my $code = $sth->fetchrow_hashref) {
    $self->deleteCode ($code->{value});
    $self->deleteCodeTokens ($code);
  }
  return 1;
}

#
# Tokens
#
# client_id | varchar(32)  | NO   |     | NULL    |       |
# code      | varchar(64)  | NO   | MUL | NULL    |       |
# username  | varchar(64)  | YES  |     | NULL    |       |
# uniqueid  | char(6)      | YES  |     | NULL    |       |
# resource  | varchar(64)  | YES  |     | NULL    |       |
# scopes    | varchar(128) | YES  |     | NULL    |       |
# value     | varchar(64)  | NO   | PRI | NULL    |       |
# created   | datetime     | YES  |     | NULL    |       |
# lastused  | datetime     | YES  |     | NULL    |       |
#
sub listTokens {
  my $self = shift;
  my $sql = qq{select * from oauth_tokens};
  my $sth = $self->{teqdb}->prepare ($sql);
  return $self->error ("listTokens : $self->{teqdb}->{errmsg}") unless $sth;
  my  $rv = $self->{teqdb}->execute ($sth);
  return $self->error ("listTokens : $self->{teqdb}->{errmsg}") unless $rv;
  my $token = $sth->fetchrow_hashref;
  return $token;
}

sub getToken {
  my ($self, $value) = @_;
  return $self->error ('getToken : no value') unless $value;
  my $sql = qq{
    select *
      from oauth_tokens
     where value = ?
  };
  my $sth = $self->{teqdb}->prepare ($sql);
  return $self->error ("getToken : $self->{teqdb}->{errmsg}") unless $sth;
  my  $rv = $self->{teqdb}->execute ($sth,  $value);
  return $self->error ("getToken : $self->{teqdb}->{errmsg}") unless $rv;
  my @tokens;
  while (my $token = $sth->fetchrow_hashref) {
    push (@tokens, $token);
  }
  return @tokens;
}

sub searchTokens {
  my ($self, $filter) = @_;
  my  $where = join (', ', map { "$_ = ?" } keys %$filter);
  my @values; 
  foreach my $key (keys %$filter) {
    push (@values, $filter->{$key});
  }
  my $sql = qq{select * from oauth_tokens where $where};
  my $sth = $self->{teqdb}->prepare ($sql);
  return $self->error ("searchTokens : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{teqdb}->execute ($sth, @values);
  return $self->error ("searchTokens : $self->{db}->{errmsg}") unless $rv;
  my @tokens;
  while (my $token = $sth->fetchrow_hashref) {
    push (@tokens, $token);
  }
  return @tokens;
}

sub addToken {
  my ($self, $client_id, $code, $username, $uniqueid, $resource, $scopes) = @_;
  my @scopes = split (/[\s,]+/, $scopes);
  map { s/^$resource->{name}\.//; } @scopes;
  $scopes = join (' ', @scopes);

  my $tokenvalue = 'Bearer ' . sha1_hex (time . uniqueid ());
  my $sql = qq{
    insert into oauth_tokens set
      client_id = ?,
           code = ?,
       username = ?,
       uniqueid = ?,
       resource = ?,
         scopes = ?,
          value = ?,
        created = now(),
       lastused = now()
  };
  my $sth = $self->{teqdb}->prepare ($sql);
  return $self->error ('createDBToken2') unless $sth;
  my $rv = $sth->execute (
    $client_id,
    $code,
    $username,
    $uniqueid,
    $resource,
    $scopes,
    $tokenvalue,
  );
  return $self->error ('createDBToken3') unless $rv;
  my ($sec, $min, $hour, $day, $month, $year) = (localtime ())[0..5];
  my $now = sprintf ('%4d-%02d-%02d %02d:%02d:%02d',
    $year + 1900, $month + 1, $day, $hour, $min, $sec);
  return {
    client_id => $client_id,
         code => $code,
     username => $username,
     uniqueid => $uniqueid,
     resource => $resource,
       scopes => $scopes,
        value => $tokenvalue,
         type => 'Bearer',
      created => $now,
     lastused => $now,
  };
}

sub deleteCodeTokens {
  my ($self, $code) = @_;
  return unless $code;
  my $teqdb = $self->{teqdb};
  return $self->error ('deleteTokens1') unless $teqdb;

  my $sql = qq{delete from oauth_tokens where code = ?};
  my $sth = $teqdb->prepare ($sql);
  return $self->error ('deleteTokens2') unless $sth;
  my $rv = $sth->execute ($code);
  return $self->error ('deleteTokens3') unless $rv;
  return 1;
}

sub deleteUserTokens {
  my ($self, $username) = @_;
  return unless $username;
  my $teqdb = $self->{teqdb};
  return $self->error ('deleteUserTokens1') unless $teqdb;

  my $field = ($username =~ /^[a-z]*$/) ? 'username' : 'uniqueid';
  my $sql = qq{delete from oauth_tokens where $field = ?};
  my $sth = $teqdb->prepare ($sql);
  return $self->error ('deleteUserTokens2') unless $sth;
  my $rv = $sth->execute ($username);
  return $self->error ('deleteUserTokens3') unless $rv;
  return 1;
}

#
# Utils.
#

sub errmsg {
  my $self = shift;
  return $self->{errmsg};
}

sub error {
  my ($self, @msgs) = @_;
  my $msg = join ('', @msgs);
  $self->{errmsg} = "Cadi::OAuth2: $msg";
  return;
}

1;
