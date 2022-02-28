#!/usr/bin/perl
#
use strict;
use utf8;
use Cadi::CadiDB;
use Tequila::SAML2::Entities;

package Cadi::MyTequila;

my $errmsg;

my @clientsFields = qw(
  name type icon oauth2id saml2id owner service urlaccess request
  required allows allowedorgs identities charset authstrength
  forcelogin nologinform issuermatch subjectmatch allowedhosts
  trustedauth contact creation
);
my $clientsFields = { map { $_, 1 } @clientsFields };

my @oauth2Fields = qw(
  id name owner client_id client_secret redirect_uri limited_access
  status auto_approve username password notes codelifespan trusted
);
my $oauth2Fields = { map { $_, 1 } @oauth2Fields };

my $title = 'MyTequila';
my @attributes = initattributes ();
my $attributes = { map { $_->{name}, $_ } @attributes };

sub new { # Exported
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
     verbose => 1,
       trace => 1,
  };
  foreach my $arg (keys %$args) {
    $self->{$arg} = $args->{$arg};
  }
  warn "new Cadi::MyTequila ($self->{dbname})\n" if $self->{verbose};
  $self->{db} = new Cadi::CadiDB (%$self);
  unless ($self->{db}) {
    $errmsg = $Cadi::CadiDB::errmsg;
    warn "MyTequila:new: $errmsg\n";
    return;
  }
  bless $self, $class;
}

sub getClient {
  my ($self, $id) = @_;
  my $sql = qq{
    select *
      from resources
     where id = ?
  };
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("dbloadclient : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, $id);
  return $self->error ("dbloadclient : $self->{db}->{errmsg}") unless $rv;

  my $client = $sth->fetchrow_hashref;
  $client->{request}     = [ split (/\s+/,  $client->{request}) ];
  $client->{allows}      = [ split (/\|/,   $client->{allows}) ];
  $client->{allowedorgs} = [ split (/\s+/,  $client->{allowedorgs}) ];
  $client->{oauth2}      = $self->getOAuth2Client ($client->{oauth2id})
    if ($client->{type} eq 'oauth2');
  $client->{saml2} = $self->getSAML2Client ($client->{saml2id})
    if ($client->{type} eq 'saml2');
  return $client;
}

sub listClients {
  my ($self, $owner) = @_;
  my @values;
  my $sql = qq{select * from resources};
  if ($owner) {
    $sql .= qq{ where owner = ?};
    @values = ($owner);
  }
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("dblistclients : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, @values);
  return $self->error ("dblistclients : $self->{db}->{errmsg}") unless $rv;
  my @clients;
  while (my $client = $sth->fetchrow_hashref) {
    push (@clients, $client);
  }
  $sth->finish;
  return @clients;
}

sub searchClients {
  my ($self, $filter) = @_;
  my  $where = join (',', map { "$_ = ?" } keys %$filter);
  my @values; 
  foreach my $key (keys %$filter) {
    push (@values, $filter->{$key});
  }
  my $sql = qq{select * from resources where $where};
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("searchClients : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, @values);
  return $self->error ("searchClients : $self->{db}->{errmsg}") unless $rv;
  my @clients;
  while (my $client = $sth->fetchrow_hashref) {
    $client->{request}     = [ split (/\s+/,  $client->{request}) ];
    $client->{allows}      = [ split (/\|/,   $client->{allows}) ];
    $client->{allowedorgs} = [ split (/\s+/,  $client->{allowedorgs}) ];
    $client->{oauth2}      = $self->getOAuth2Client ($client->{oauth2id})
      if ($client->{type} eq 'oauth2');
    $client->{saml2} = $self->getSAML2Client ($client->{saml2id})
      if ($client->{type} eq 'saml2');
    push (@clients, $client);
  }
  return @clients;
}

sub addClient {
  my ($self, $values) = @_;

  return unless $self->checkClient ($values);
  my @samename = searchClients ($self, { name => $values->{name} });
  return $self->error ("addClient : Client name already used : $values->{name}")
    if @samename;

  if ($values->{type} eq 'oauth2') {
    $values->{oauth2id} = $self->addOAuth2Client ($values);
    return unless $values->{oauth2id};
  }
  if ($values->{type} eq 'saml2') {
    my $client = $self->addSAML2Client ($values);
    return unless $client;
    $values->{saml2id} = $client->{id};
  }

  my (@fields, @values);
  foreach my $field (keys %$values) {
    next unless $clientsFields->{$field};
    push (@fields, "$field = ?");
    push (@values, $values->{$field});
  }
  my $set = join (', ', @fields);
  my $sql = qq{insert into resources set $set};
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("addClient : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, @values);
  return $self->error ("addClient : $self->{db}->{errmsg}") unless $rv;
  my $clientid = $sth->{mysql_insertid};
  return $clientid;
}

sub modifyClient {
  my ($self, $id, $values) = @_;
  
  return $self->error ("modifyClient : No client ID") unless $id;
  my $client = $self->getClient ($id);
  return $self->error ("modifyClient : Unknown client ID : $id") unless $client;

  my @samename = searchClients ($self, { name => $values->{name} });
  if (@samename) {
    my $first = shift @samename;
    return $self->error ("modifyClient : Client name already used : $values->{name}")
      if ($first->{id} != $id);
  }
  
  if ($values->{type} eq 'oauth2') {
    my $oauth2id = $values->{oauth2id};
    return $self->error ("modifyClient : No oauth2id") unless $oauth2id;
    my $status = $self->modOAuth2Client ($oauth2id, $values);
    return unless $status;
  }
  
  if ($values->{type} eq 'saml2') {
    my $saml2id = $values->{saml2id};
    return $self->error ("modifyClient : No saml2id") unless $saml2id;
  }
  
  my (@fields, @values, @allows);
  foreach my $field (keys %$values) {
    if ($field =~ /^allows:(.*)$/) {
      push (@allows, $1);
      next;
    }
    next unless $clientsFields->{$field};
    if (ref $client->{$field} eq 'ARRAY') {
      my $clival = join (' ', sort @{$client->{$field}});
      my $newval = join (' ', sort (split (' ', $values->{$field})));
      next if ($newval eq $clival);
    } else {
      next if ($values->{$field} eq $client->{$field});
    }
    push (@fields, "$field = ?");
    push (@values, $values->{$field});
  }
  if (@allows) {
    my $cliallows = join ('|', sort @{$client->{allows}});
    my $allows = join ('|', sort @allows);
    if ($allows ne $cliallows) {
      push (@fields, "allows = ?");
      push (@values, $allows);
    }
  }
  return 1 if !@values;
  my $set = join (', ', @fields);
  my $sql = qq{update resources set $set where id = $client->{id}};
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("dbmodclient : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, @values);
  return $self->error ("dbmodclient : $self->{db}->{errmsg}") unless $rv;
  return 1;
}

sub deleteClient {
  my ($self, $id) = @_;
  return $self->error ("deleteClient : No client ID") unless $id;
  my $client = $self->getClient ($id);
  return $self->error ("deleteClient : Unknown client ID : $id") unless $client;

  my $sql = qq{delete from resources where id = ?};
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("deleteClient : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, $id);
  return $self->error ("deleteClient : $self->{db}->{errmsg}") unless $rv;
}

sub checkClient {
  my ($self, $client) = @_;
  return $self->error ("checkClient : no client name")
    unless $client->{name};
  return $self->error ("checkClient : no client contact address")
    unless $client->{contact};
  return 1;
}

#
# OAUTH2
#

sub getOAuth2Client {
  my ($self, $idorname) = @_;
  my $field = ($idorname =~ /^\d+$/) ? 'id' : 'name';
  my $sql = qq{select * from oauth_clients where $field = ?};
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("dbloadoauth2client1 : $self->{db}->{errmsg}") unless $sth;
  my $rv = $sth->execute ($idorname);
  return $self->error ("dbloadoauth2client2 : $self->{db}->{errmsg}") unless $rv;
  my $client = $sth->fetchrow_hashref;
  return unless $client;
  
  my $sql = qq{select scope from oauth_allowedscopes where client = ?};
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("dbloadoauth2client3 : $self->{db}->{errmsg}") unless $sth;
  my $rv = $sth->execute ($client->{name});
  return $self->error ("dbloadoauth2client4 : $self->{db}->{errmsg}") unless $rv;
  my @scopes;
  while (my ($scope) = $sth->fetchrow) {
    push (@scopes, $scope);
  }
  $client->{scopes} = \@scopes;
  return $client;
}

sub addOAuth2Client {
  my ($self, $values) = @_;
  my  $redirect_uri = $values->{redirect_uri};
  my        $caller = $self->{caller};
  my     $client_id = genoauth2clientid     ();
  my $client_secret = genoauth2clientsecret ();
  return $self->error ("addOAuth2Client1 : missing value : redirect_uri")
      unless $values->{redirect_uri};

  $values->{owner} ||= $caller;
  return $self->error ("addOAuth2Client2 : bad owner : $values->{owner}")
    unless ($self->{isroot} || ($values->{owner} eq $caller));

  my $sql = qq{
    insert into oauth_clients set
             name = ?,
            owner = ?,
        client_id = ?,
    client_secret = ?,
     redirect_uri = ?,
   limited_access = ?,
           status = ?,
     auto_approve = ?,
         username = ?,
         password = ?,
        suspended = ?,
            notes = ?,
     codelifespan = ?
  };
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("addOAuth2Client3 : $self->{db}->{errmsg}") unless $sth;
  
  my $rv = $self->{db}->execute ($sth,
    $values->{name}, $values->{owner}, $client_id, $client_secret, $redirect_uri,
    0, 'development', 0, undef, undef, 0, undef, 0);
  return $self->error ("addOAuth2Client4 : $self->{db}->{errmsg}") unless $rv;
  my $id = $sth->{mysql_insertid};
  #
  # Allowed scopes.
  #
  my $sql = qq{insert into oauth_allowedscopes values(?, ?)};
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("addOAuth2Client5 : $self->{db}->{errmsg}") unless $sth;
  my $allowedscopes = $values->{allowedscopes} || [ 'Tequila.profile' ];
  foreach my $scope (@$allowedscopes) {
    my $rv = $self->{db}->execute ($sth, $values->{name}, $scope);
    return $self->error ("addOAuth2Client6 : $self->{db}->{errmsg}") unless $rv;
  }
  return $id;
}

sub modOAuth2Client {
  my ($self, $idorname, $values) = @_;
  return $self->error ("modOAuth2Client : no client ID") unless $idorname;

  my $oauth2 = $self->getOAuth2Client ($idorname);
  return $self->error ("modOAuth2Client : unknown oauth2 client : $idorname")
    unless $oauth2;

  $values->{owner} ||= $oauth2->{owner};
  return $self->error ("modOAuth2Client : you do not own client $idorname")
    unless ($self->{isroot} || ($values->{owner} eq $oauth2->{owner}));
  return $self->error ("modOAuth2Client : bad owner : $values->{owner}")
    unless ($self->{isroot} || ($oauth2->{owner} eq $values->{owner}));

  my (@fields, @values);
  foreach my $field (@oauth2Fields) {
    next unless $values->{$field};
    next if ($field eq 'id');
    next if ($values->{$field} eq $oauth2->{$field});
    push (@fields, "$field = ?");
    push (@values, $values->{$field});
  }
  return 1 if !@values;
  my $set = join (', ', @fields);
  my $sql = qq{
    update oauth_clients
       set $set
     where id = $oauth2->{id}
  };
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("modOAuth2Client : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, @values);
  return $self->error ("modOAuth2Client : $self->{db}->{errmsg}") unless $rv;
  $sth->finish;
  return 1;
}

sub checkOAuth2Client {
  my ($self, $client) = @_;
  return $self->error ("checkOAuth2Client : no client name")
    unless $client->{name};
  return $self->error ("checkOAuth2Client : no client client_secret")
    unless $client->{client_secret};
  return $self->error ("checkOAuth2Client : no client redirect_uri")
    unless $client->{redirect_uri};
  return 1;
}

sub listOAuth2Scopes {
  my $self = shift;
  my $sql = qq{select * from oauth_scopes};
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("listOAuth2Scopes : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth);
  return $self->error ("listOAuth2Scopes : $self->{db}->{errmsg}") unless $rv;
  my @scopes;
  while (my $scope = $sth->fetchrow_hashref) {
    push (@scopes, $scope);
  }
  return @scopes;
}
#
# SAML2
#

sub getSAML2Client {
  my ($self, $id) = @_;
  my $sql = qq{
    select *
      from SAML2Entities
     where id = ?
  };
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("getSAML2Client1 : $self->{db}->{errmsg}") unless $sth;
  my $rv = $sth->execute ($id);
  return $self->error ("getSAML2Client2 : $sth->{errmsg}") unless $rv;
  my $entity = $sth->fetchrow_hashref;
  return unless $entity;
  $entity->{posturl}       =~ s/^\d+://;
  $entity->{redirecturl}   =~ s/^\d+://;
  $entity->{simplesignurl} =~ s/^\d+://;
  return $entity;
}

sub addSAML2Client {
  my ($self, $values) = @_;
  my $owner = $self->{caller};
  $owner    = $values->{owner} if ($self->{isroot} && $values->{owner});

  if ($values->{saml2metadata}) {
    my $dbhost = ($self->{dbname} =~ /^test/) ? 'test-cadidb.epfl.ch' : 'cadidb.epfl.ch';
    my $Entities = new Tequila::SAML2::Entities (
       dbhost => $dbhost,
      verbose => 1,
    );
    my   $entity = $Entities->parseEntityData ($values->{saml2metadata});
    return $self->error ("addSAML2Client : error in metadata file : $Entities->{errmsg}")
      unless $entity;
    return $self->error ("addSAML2Client : bad entity type in metadata file : $entity->{type}")
      if ($entity->{type} ne 'SP');

    my $old = $self->getSAML2Client ($entity->{id});
    if ($old) {
      my @clients = $self->searchClients ($self, { saml2id => $entity->{id}, });
      if (@clients) {
        my $client = shift @clients;
        return $self->error (
          "modSAML2Client : SAML2 entity '$entity->{id}' is already ".
          "existing and belongs to client '$client->{name}'"
        );
      } else {
        return $self->error (
          "modSAML2Client : SAML2 entity '$entity->{id}' is already ".
          "existing, though it belongs to no client"
        );
      }
    }
    $entity->{owner} = $owner;
    return $Entities->addEntity ($entity);
  } else {
    my ($sql, @fields, @values);
    $values->{owner} = $owner;
    $values->{type}  = 'SP';
    my @saml2Fields = qw{id posturl owner};
    foreach my $field (@saml2Fields) {
      return $self->error ("addSAML2Client : missing value : $field")
        unless $values->{$field};
      push (@fields, "$field = ?");
      push (@values, $values->{$field});
    }
    my $set = join (', ', @fields);
    my $old = $self->getSAML2Client ($values->{id});
    return $self->error ("addSAML2Client : entity already exists : $values->{id}") if $old;
    $sql = qq{insert into SAML2Entities set $set};
    my $sth = $self->{db}->prepare ($sql);
    return $self->error ("addSAML2Client : $self->{db}->{errmsg}") unless $sth;
    my $rv = $self->{db}->execute ($sth, @values);
    return $self->error ("addSAML2Client : $self->{db}->{errmsg}") unless $rv;
    $sth->finish;
    return $values;
  }
}

sub modSAML2Client {
  my ($self, $id, $values) = @_;
  my $caller = $self->{caller};

  return $self->error ("modSAML2Client : no SAML2 ID to modify") unless $id;
  my $saml2 = $self->getSAML2Client ($id);
  return $self->error ("modSAML2Client : unknown SAML2 id : $id") unless $saml2;
  $values->{owner} ||= $saml2->{owner};
  return $self->error ("modSAML2Client : you do not own entity $id")
    unless ($self->{isroot} || ($saml2->{owner} eq $self->{caller}));
  return $self->error ("modSAML2Client : bad owner : $values->{owner}")
    unless ($self->{isroot} || ($saml2->{owner} eq $values->{owner}));

  if ($values->{saml2metadata}) {
    my $Entities = new Tequila::SAML2::Entities ();
    my   $entity = $Entities->parseEntityData ($values->{saml2metadata});
    return $self->error ("modSAML2Client : error in metadata file : $Entities->{errmsg}")
      unless $entity;
    return $self->error ("modSAML2Client : bad entity type in metadata file : $entity->{type}")
      if ($entity->{type} ne 'SP');

    if ($entity->{id} ne $id) {
      my $old = $self->getSAML2Client ($entity->{id});
      if ($old) {
        my @clients = $self->searchClients ($self, { saml2id => $entity->{id}, });
        if (@clients) {
          my $client = shift @clients;
          return $self->error ("modSAML2Client : SAML2 entity '$entity->{id}' is already ".
                        "existing and belongs to client '$client->{name}'");
        } else {
          return $self->error ("modSAML2Client : SAML2 entity '$entity->{id}' is already ".
                         "existing, though it belongs to no client");
        }
      }
    }
    $values = $entity;
  }
  
  my ($sql, @fields, @values);
  my @saml2Fields = qw{id posturl owner};
  foreach my $field (@saml2Fields) {
    next if ($field =~ /^(id|owner)$/i);
    push (@fields, "$field = ?");
    push (@values, $values->{$field});
  }
  my $set = join (', ', @fields);
  my $sql = qq{update SAML2Entities set $set where id = ?};
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("modSAML2Client : $self->{db}->{errmsg}") unless $sth;
  my $rv = $self->{db}->execute ($sth, @values, $id);
  return $self->error ("modSAML2Client : $self->{db}->{errmsg}") unless $rv;
  return 1;
}

sub addSAML2Certificate {
  my ($self, $type, $saml2id, $pemcert) = @_;
  
  return $self->error ("addSAML2Certificate : no SAML2 ID to modify") unless $saml2id;
  my $saml2 = $self->getSAML2Client ($saml2id);
  return $self->error ("addSAML2Certificate : unknown SAML2 id : $saml2id") unless $saml2;
  return $self->error ("addSAML2Certificate : you do not own entity $saml2id")
    unless ($self->{isroot} || ($saml2->{owner} eq $self->{caller}));

  my @sslcerts = split (/\n\n/s, $saml2->{sslcerts});
  my $newcerts = join ("\n\n", @sslcerts, "$type:$pemcert");
  my $sql = qq{
    update SAML2Entities
       set sslcerts = ?
     where id = ?
  };
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("dbsaml2addcertificate3: $self->{db}->{errmsg}")
    unless $sth;
  my $rv = $sth->execute ($newcerts, $saml2id);
  return $self->error ("dbsaml2addcertificate4: $sth->{errmsg}")
    unless $rv;
  return 1;
}

sub delSAML2Certificate {
  my ($self, $saml2id, $pemcert) = @_;
  
  return $self->error ("delSAML2Certificate : no SAML2 ID to modify") unless $saml2id;
  my $saml2 = $self->getSAML2Client ($saml2id);
  return $self->error ("delSAML2Certificate : unknown SAML2 id : $saml2id") unless $saml2;
  return $self->error ("delSAML2Certificate : you do not own entity $saml2id")
    unless ($self->{isroot} || ($saml2->{owner} eq $self->{caller}));

  my @sslcerts = split (/\n\n/s, $saml2->{sslcerts});
  my @newcerts;
  foreach my $sslcert (@sslcerts) {
    (my $sslc = $sslcert) =~ s/^.*://;
    next if ($sslc eq $pemcert);
    push (@newcerts, $sslcert);
  }
  my $newcerts = join ("\n\n", @newcerts);
  my $sql = qq{
    update SAML2Entities
       set sslcerts = ?
     where id = ?
  };
  my $sth = $self->{db}->prepare ($sql);
  return $self->error ("dbsaml2removecertificate3: $self->{db}->{errmsg}")
    unless $sth;
  my $rv = $sth->execute ($newcerts, $saml2id);
  return $self->error ("dbsaml2removecertificate4: $sth->{errmsg}")
    unless $rv;
  return 1;
}

sub genoauth2clientid { # 942707787870@epfl.ch
  return genrandomkey (12) . '@epfl.ch';
}

sub genoauth2clientsecret { # 55D5AD99D6D40003
  return genrandomkey (16);
}

sub genrandomkey {
  my $len = shift || 16;
  my $rand;
  open (RND, "/dev/urandom") || die "Unable to init random engine : $!";
  if (sysread (RND, $rand, $len) != $len) { die "Unable to read random bytes : $!"; }
  close (RND);
  my $key = unpack 'H*', $rand;
  return $key;

}

sub error {
  my ($self, $msg) = @_;
  $self->{errmsg} = $msg;
  warn "MyTequila:error: $msg\n";
  return;
}

sub initattributes {
  my $attributes = {
    uniqueid => {
             name => 'uniqueid',
            label => 'Sciper number',
      description => 'uniqueid',
            order => 1,
    },
    name => {
             name => 'name',
            label => 'Name',
      description => 'name',
            order => 2,
    },
    firstname => {
             name => 'firstname',
            label => 'First name',
      description => 'firstname',
            order => 3,
   },
   username => {
             name => 'username',
            label => 'Username',
      description => 'username',
            order => 4,
    },
    title => {
             name => 'title',
            label => 'Title',
      description => 'title',
            order => 5,
    },
    email => {
             name => 'email',
            label => 'Email',
      description => 'email',
            order => 6,
    },
    statut => {
             name => 'statut',
            label => 'Statut',
      description => 'statut',
            order => 7,
    },
    classe => {
             name => 'classe',
            label => 'Classe',
      description => 'classe',
            order => 8,
    },
    org => {
             name => 'org',
            label => 'Organization',
      description => 'org',
            order => 9,
    },
    affiliation => {
             name => 'affiliation',
            label => 'Affiliation',
      description => 'affiliation',
            order => 10,
    },
    unit => {
             name => 'unit',
            label => 'Unit',
      description => 'unit',
            order => 11,
    },
    unitdn => {
             name => 'unitdn',
            label => 'Unit LDAP dn',
      description => 'unitdn',
            order => 12,
    },
    unitid => {
             name => 'unitid',
            label => 'Unit Id',
      description => 'unitid',
            order => 13,
    },
    where => {
             name => 'where',
            label => 'Where',
      description => 'where',
            order => 14,
    },
    wheres => {
             name => 'wheres',
            label => 'Wheres',
      description => 'wheres',
            order => 15,
    },
    allcfs => {
             name => 'allcfs',
            label => "All CFs",
      description => 'allcfs',
            order => 16,
    },
    allunits => {
             name => 'allunits',
            label => 'All Units',
      description => 'allunits',
            order => 17,
    },
    phone => {
             name => 'phone',
            label => 'Phone',
      description => 'phone',
            order => 18,
    },
    postaladdress => {
             name => 'postaladdress',
            label => 'Postal Address',
      description => 'postaladdress',
            order => 19,
    },
    categorie => {
             name => 'categorie',
            label => 'Categorie',
      description => 'categorie',
            order => 20,
    },
    cf => {
             name => 'cf',
            label => 'CF',
      description => 'cf',
            order => 21,
    },
    groupid => {
             name => 'groupid',
            label => "Group id",
      description => 'groupid',
            order => 22,
    },
    matriculationnumber => {
             name => 'matriculationnumber',
            label => 'Matriculation Number',
      description => 'matriculationnumber',
            order => 23,
    },
    office => {
             name => 'office',
            label => 'Office',
      description => 'office',
            order => 24,
    },
    studybranch1 => {
             name => 'studybranch1',
            label => 'Study Branch 1',
      description => 'studybranch1',
            order => 25,
    },
    studybranch2 => {
             name => 'studybranch2',
            label => 'Study Branch 2',
      description => 'studybranch2',
            order => 26,
    },
    studybranch3 => {
             name => 'studybranch3',
            label => 'Study Branch 3',
      description => 'studybranch3',
            order => 27,
    },
    studylevel => {
             name => 'studylevel',
            label => 'Study Level',
      description => 'studylevel',
            order => 28,
    },
    unixid => {
             name => 'unixid',
            label => 'Unix ID',
      description => 'unixid',
            order => 29,
    },
    camiprocardid => {
             name => 'camiprocardid',
            label => 'Camipro Card ID',
      description => 'camiprocardid',
            order => 30,
    },
    group => {
             name => 'group',
            label => 'Groups',
      description => 'group',
            order => 31,
    },
    unitresp => {
             name => 'unitresp',
            label => 'Unit Resp.',
      description => 'unitresp',
            order => 32,
    },
  };
  
  my $rights = {
    accreditation => {
             name => 'droit-accreditation',
            label => 'droit-accreditation',
      description => 'droit-accreditation',
            order => 1,
    },
    adminad => {
             name => 'droit-adminad',
            label => 'Droit administrateur AD',
      description => 'droit-adminad',
            order => 2,
    },
    admindiode => {
             name => 'droit-admindiode',
            label => 'droit-admindiode',
      description => 'droit-admindiode',
            order => 3,
    },
    admingaspar => {
             name => 'droit-admingaspar',
            label => 'droit-admingaspar',
      description => 'droit-admingaspar',
            order => 4,
    },
    adminroles => {
             name => 'droit-adminroles',
            label => 'droit-adminroles',
      description => 'droit-adminroles',
            order => 5,
    },
    cartevisite => {
             name => 'droit-cartevisite',
            label => 'droit-cartevisite',
      description => 'droit-cartevisite',
            order => 6,
    },
    confirmdistrilog => {
             name => 'droit-confirmdistrilog',
            label => 'droit-confirmdistrilog',
      description => 'droit-confirmdistrilog',
            order => 7,
    },
    controlesf => {
             name => 'droit-controlesf',
            label => 'droit-controlesf',
      description => 'droit-controlesf',
            order => 8,
    },
    demdetrav => {
             name => 'droit-demdetrav',
            label => 'droit-demdetrav',
      description => 'droit-demdetrav',
            order => 9,
    },
    demvm => {
             name => 'droit-demvm',
            label => 'droit-demvm',
      description => 'droit-demvm',
            order => 10,
    },
    distrilog => {
             name => 'droit-distrilog',
            label => 'droit-distrilog',
      description => 'droit-distrilog',
            order => 11,
    },
    ficheporte => {
             name => 'droit-ficheporte',
            label => 'droit-ficheporte',
      description => 'droit-ficheporte',
            order => 12,
    },
    gestionprofils => {
             name => 'droit-gestionprofils',
            label => 'droit-gestionprofils',
      description => 'droit-gestionprofils',
            order => 13,
    },
    impression => {
             name => 'droit-impression',
            label => 'droit-impression',
      description => 'droit-impression',
            order => 14,
    },
    intranet => {
             name => 'droit-intranet',
            label => 'droit-intranet',
      description => 'droit-intranet',
            order => 15,
    },
    inventaire => {
             name => 'droit-inventaire',
            label => 'droit-inventaire',
      description => 'droit-inventaire',
            order => 16,
    },
    payonline => {
             name => 'droit-payonline',
            label => 'droit-payonline',
      description => 'droit-payonline',
            order => 17,
    },
    railticket => {
             name => 'droit-railticket',
            label => 'droit-railticket',
      description => 'droit-railticket',
            order => 18,
    },
    shopepfl => {
             name => 'droit-shopepfl',
            label => 'droit-shopepfl',
      description => 'droit-shopepfl',
            order => 19,
    },
    smssmtp => {
             name => 'droit-smssmtp',
            label => 'droit-smssmtp',
      description => 'droit-smssmtp',
            order => 20,
    },
    smsweb => {
             name => 'droit-smsweb',
            label => 'droit-smsweb',
      description => 'droit-smsweb',
            order => 21,
    },
    sre => {
             name => 'droit-sre',
            label => 'droit-sre',
      description => 'droit-sre',
            order => 22,
    },
    substitutiondistrilog => {
             name => 'droit-substitutiondistrilog',
            label => 'droit-substitutiondistrilog',
      description => 'droit-substitutiondistrilog',
            order => 23,
    },
    vpnguest => {
             name => 'droit-vpnguest',
            label => 'droit-vpnguest',
      description => 'droit-vpnguest',
            order => 24,
    },
  };
  
  my $roles = {
    respaccred => {
             name => 'role-respaccred',
            label => 'Role responsable accreditation',
      description => 'role-respaccred',
            order => 1,
    },
    respadmin => {
             name => 'role-respadmin',
            label => 'role-respadmin',
      description => 'role-respadmin',
            order => 2,
    },
    respcomm => {
             name => 'role-respcomm',
            label => 'role-respcomm',
      description => 'role-respcomm',
            order => 3,
    },
    respinfo => {
             name => 'role-respinfo',
            label => 'Role responsable informatique',
      description => 'role-respinfo',
            order => 4,
    },
    respinfra => {
             name => 'role-respinfra',
            label => 'role-respinfra',
      description => 'role-respinfra',
            order => 5,
    },
    respsecu => {
             name => 'role-respsecu',
            label => 'role-respsecu',
      description => 'role-respsecu',
            order => 6,
    },
  };
  my  @attrs = map { $attributes->{$_} } sort {
    $attributes->{$a}->{order} <=> $attributes->{$b}->{order}
  } keys %$attributes;
  
  my  @rights = map { $rights->{$_}     } sort {
    $rights->{$a}->{order} <=> $rights->{$b}->{order}
  } keys %$rights;
  
  my  @roles = map { $roles->{$_}      } sort {
    $roles->{$a}->{order} <=> $roles->{$b}->{order}
  } keys %$roles;
  
  my @attributes = (@attrs, @rights, @roles);
  #my @attributes = (map { $rights->{$_}      } @rights);
  return @attributes
}

my $createtable = qq{
  create table clients (
             id mediumint not null auto_increment,
           name varchar(32),
           icon blob,
           type varchar(6),
       oauth2id int,
        saml2id varchar(128),
          owner char(6),
        service varchar(64),
      urlaccess varchar(128),
        request varchar(128),
       required varchar(64),
         allows varchar(64),
    allowedorgs varchar(64),
     identities varchar(3)  default 'any',
        charset varchar(16) default 'utf8',
    clienttrust varchar(10) default 'strong',
   subjectmatch varchar(128),
    issuermatch varchar(128),
   allowedhosts varchar(256),
   authstrength tinyint default 0,
     forcelogin tinyint default 0,
    nologinform tinyint default 0,
        contact varchar(128),
       creation datetime,
            key (id)
  );
};

