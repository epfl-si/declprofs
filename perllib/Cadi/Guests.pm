#!/usr/bin/perl
#

use strict;
use utf8;
use lib qw(/opt/dinfo/lib/perl);
use Cadi::CadiDB;
use Cadi::Notifier;

package Cadi::Guests;

my $messages;
my $cryptpwds = 1;

sub new { # Exported
  my $class = shift;
  my $args = (@_ == 1) ? shift : { @_ } ;
  my  $self = {
      caller => undef,
        root => undef,
          db => undef,
      errmsg => undef,
     errcode => undef,
        utf8 => 0,
    language => 'en',
       debug => 0,
     verbose => 0,
       trace => 0,
  };
  foreach my $arg (keys %$args) {
    $self->{$arg} = $args->{$arg};
  }
  $self->{accreddb} = new Cadi::CadiDB (
    dbname => 'accred',
     trace => $self->{trace},
      utf8 => $self->{utf8},
  );
  initmessages ($self);
  bless $self, $class;
}

sub getGuest {
  return getGuestInfos (@_);
}

sub getGuestInfos {
  my ($self, $sciperoremail, $status) = @_;
  my $caller = $self->{caller};
  my  $guest = $self->dbgetguest ($sciperoremail, $status);
  if (!$guest) {
    $self->{errmsg} = "Guests::getGuest : Unknown guests : $sciperoremail";
    return;
  }
  if ($self->{root}) {
    $guest->{password} = uncryptpasswd ($guest->{password}) if $cryptpwds;
  } else {
    delete $guest->{password};
  }
  return $guest;
}

sub addGuest {
  my ($self, $guest) = @_;
  my       $caller = $self->{caller};
  my        $email = $guest->{email};
  my     $password = $guest->{password};
  my         $name = $guest->{name};
  my    $firstname = $guest->{firstname};
  my $authprovider = $guest->{authprovider};
  my          $org = $guest->{org};
  my      $creator = $guest->{creator} || $caller;

  unless     ($email) {
    $self->{errmsg} = "Guests::addGuest : No email.";
    return;
  }
  unless      ($name) {
    $self->{errmsg} = "Guests::addGuest : No name.";
    return;
  }
  unless ($firstname) {
    $self->{errmsg} = "Guests::addGuest : No firstname.";
    return;
  }
  unless ($org) {
    $self->{errmsg} = "Guests::addGuest : No org.";
    return;
  }
  unless ($password || $authprovider) {
    $self->{errmsg} = "Guests::addGuest : Neither password nor ".
                      "authentication provider.";
    return;
  }
  unless ($self->{root} || ($creator eq $caller)) {
    $self->{errmsg} = "Guests::addGuest : Access denied, you can ".
                      "only add guests of your own.";
    warn "Guests::addGuest: $self->{errmsg}\n";
    return;
  }
  my $oldguest = $self->dbgetguest ($email);
  if ($oldguest) {
    $self->{errmsg} = "Guests::addGuest : Duplicate email address : $email";
    return;
  }
  $password = cryptpasswd ($password) if $cryptpwds;
  my  $accreddb = $self->{accreddb};
  my $sql = qq{
    insert into guests
       set password = ?,
               name = ?,
          firstname = ?,
              email = ?,
       organization = ?,
            creator = ?,
           creation = now(),
             status = '1',
             actkey = 'EPFLGUEST'
  };
  my $sth = $accreddb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Guests::addGuest : $accreddb->{errmsg}";
    return;
  }
  my $rv = $accreddb->execute ($sth, $password, $name, $firstname, $email, $org, $creator);
  unless ($rv) {
    $self->{errmsg} = "Guests::addGuest : $accreddb->{errmsg}";
    return;
  }
  my $code = $sth->{mysql_insertid};
  $sth->finish;

  my $sciper = sprintf ("G%05d", $code);
  my $sql = qq{
    update guests
       set sciper = ?
     where   code = ?
  };
  my $sth = $accreddb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Guests::addGuest : $accreddb->{errmsg}";
    return;
  }
  my $rv = $accreddb->execute ($sth, $sciper, $code);
  unless ($rv) {
    $self->{errmsg} = "Guests::addGuest : $accreddb->{errmsg}";
    return;
  }
  $sth->finish;
  Notifier::notify (
     event => 'addguest',
    author => $caller,
    sciper => $sciper,
  );
  return {
          sciper => $sciper,
            name => $name,
       firstname => $firstname,
           email => $email,
    organization => $org,
         creator => $creator,
  };
}

sub removeGuest {
  my ($self, $sciperoremail) = @_;
  my $caller = $self->{caller};
  my  $guest = $self->dbgetguest ($sciperoremail);
  if (!$guest) {
    $self->{errmsg} = "Guests::removeGuest : Unknown guests : $sciperoremail";
    return;
  }
  unless ($self->{root} || ($caller eq $guest->{creator})) {
    $self->{errmsg} = "Guests::removeGuest : Access denied, only the creator ".
                      "can remove a guest.";
    warn "Guests::removeGuest: $self->{errmsg}\n";
    return;
  }
  my  $accreddb = $self->{accreddb};
  my $sql = qq{
    update guests
       set  status = '2',
           remover = ?,
           removal = now()
    where code = ?
  };
  my $sth = $accreddb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Guests::removeGuest : $accreddb->{errmsg}";
    return;
  }
  my $rv = $accreddb->execute ($sth, $caller, $guest->{code});
  unless ($rv) {
    $self->{errmsg} = "Guests::removeGuest : $accreddb->{errmsg}";
    return;
  }
  $sth->finish;
  Notifier::notify (
     event => 'removeguest',
    author => $caller,
    sciper => $guest->{sciper},
  );
  return 1;
}

sub modifyGuest {
  my  $self  = shift;
  my $caller = $self->{caller};
  my   $spec = shift;
  my %modifs = @_;
  my $modifs = \%modifs;
  warn "modifyGuest ($caller, $spec, ", keys %modifs, ")\n" if $self->{trace};

  unless ($caller) {
    $self->{errmsg} = "Guests::modifyGuest : No caller.";
    return;
  }
  unless ($spec) {
    $self->{errmsg} = "Guests::modifyGuest : No guest specification.";
    return;
  }
  my  $guest = $self->dbgetguest ($spec);
  if (!$guest) {
    $self->{errmsg} = "Guests::modifyGuest : Guest $spec doesn't exist.";
    return;
  }
  unless ($self->{root} || ($caller eq $guest->{creator})) {
    $self->{errmsg} = "Guests::modifyGuest : Access denied, only the creator ".
                      "can modify a guest.";
    return;
  }
  my (@fields, @values);
  if (defined $modifs->{password}) {
    $modifs->{password} = cryptpasswd ($modifs->{password}) if $cryptpwds;
    $guest->{password}  = $modifs->{password};
    push (@fields, 'password = ?');
    push (@values, $modifs->{password});
  }
  if (defined $modifs->{name}) {
    $guest->{name} = $modifs->{name};
    push (@fields, 'name = ?');
    push (@values, $modifs->{name});
  }
  if (defined $modifs->{firstname}) {
    $guest->{firstname} = $modifs->{firstname};
    push (@fields, 'firstname = ?');
    push (@values, $modifs->{firstname});
  }
  if (defined $modifs->{org}) {
    $guest->{org} = $modifs->{org};
    push (@fields, 'organization = ?');
    push (@values, $modifs->{org});
  }
  if (defined $modifs->{creator} && $self->{root}) {
    $guest->{creator} = $modifs->{creator};
    push (@fields, 'creator = ?');
    push (@values, $modifs->{creator});
  }
  unless (@fields) {
    $self->{errmsg} = "Guests::modifyGuest : No modification";
    return;
  }
  my $set = join (', ', @fields);
  my  $accreddb = $self->{accreddb};
  my $sql = qq{
    update guests
       set $set
     where sciper = ?
  };
  my $sth = $accreddb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Guests::modifyGuest : $accreddb->{errmsg}";
    return;
  }
  my $rv = $accreddb->execute ($sth, @values, $guest->{sciper});
  unless ($rv) {
    $self->{errmsg} = "Guests::modifyGuest : $accreddb->{errmsg}";
    return;
  }
  $sth->finish;
  Notifier::notify (
     event => 'modifyguest',
    author => $caller,
    sciper => $guest->{sciper},
  );
  return 1;
}

sub listGuestsCreatedBy {
  my ($self, $sciper) = @_;
  my $caller = $self->{caller};
  my  $accreddb = $self->{accreddb};
  my $sql = qq{
    select *
      from guests
     where creator = ?
       and  status = '1'
  };
  my $sth = $accreddb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Guests::listGuestsCreatedBy : $accreddb->{errmsg}";
    return;
  }
  my $rv = $accreddb->execute ($sth, $sciper);
  unless ($rv) {
    $self->{errmsg} = "Guests::listGuestsCreatedBy : $accreddb->{errmsg}";
    return;
  }
  my @guests;
  while (my $guest = $sth->fetchrow_hashref) {
    delete $guest->{password};
    push (@guests, $guest);
  }
  $sth->finish;
  return @guests;
}

sub findGuests {
  my ($self, $string) = @_;
  my $caller = $self->{caller};
  my  $accreddb = $self->{accreddb};
  my $sql = qq{select * from guests
                where      name like ?
                   or firstname like ?
                   or     email like ?
  };
  my $sth = $accreddb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Guests::findGuests : $accreddb->{errmsg}";
    return;
  }
  my $rv = $accreddb->execute ($sth, "%$string%", "%$string%", "%$string%");
  unless ($rv) {
    $self->{errmsg} = "Guests::findGuests : $accreddb->{errmsg}";
    return;
  }
  my @guests;
  while (my $guest = $sth->fetchrow_hashref) {
    delete $guest->{password};
    push (@guests, $guest);
  }
  $sth->finish;
  return @guests;
}

sub dbgetguest {
  my ($self, $spec, $status) = @_;
  my $field = ($spec =~ /@/) ? 'email' : 'sciper';
  $status ||= 1;
  my  $accreddb = $self->{accreddb};
  my $sql = qq{
    select *
      from guests
     where $field = ?
       and status = ?
  };
  my $sth = $accreddb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Guests::dbgetguest : $accreddb->{errmsg}";
    return;
  }
  my $rv = $accreddb->execute ($sth, $spec, $status);
  unless ($rv) {
    $self->{errmsg} = "Guests::dbgetguest : $accreddb->{errmsg}";
    return;
  }
  my $guest = $sth->fetchrow_hashref;
  $sth->finish;
  return unless $guest;
  $guest->{org} = $guest->{organization};
  $guest->{id}  = $guest->{code};
  return $guest;
}

sub errmsg {
  my $self = shift;
  return $self->{errmsg};
}


sub fixallaccents {
  my $self = shift;
  my  $accreddb = $self->{accreddb};
  my $sql = qq{select * from guests};
  my $sth = $accreddb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Guests::fixallaccents : $accreddb->{errmsg}";
    return;
  }
  my $rv = $accreddb->execute ($sth);
  unless ($rv) {
    $self->{errmsg} = "Guests::fixallaccents : $accreddb->{errmsg}";
    return;
  }
  
  my $sqlmod = qq{
    update guests
       set      name = ?,
           firstname = ?
     where sciper = ?
  };
  my $sthmod = $accreddb->prepare ($sqlmod);
  unless ($sthmod) {
    $self->{errmsg} = "Guests::fixallaccents : $accreddb->{errmsg}";
    return;
  }
  while (my $guest = $sth->fetchrow_hashref) {
    my $sciper = $guest->{sciper};
    my $firstname = $guest->{firstname};
    my      $name = $guest->{name};
    #next unless ($sciper eq 'G18164');
    
    $firstname =~ s/ÃÂ©/é/g; $name =~ s/ÃÂ©/é/g;
    $firstname =~ s/Ã©/é/g; $name =~ s/Ã©/é/g;
    $firstname =~ s/Ã¨/è/g; $name =~ s/Ã¨/è/g;
    $firstname =~ s/Ã¤/ä/g; $name =~ s/Ã¤/ä/g;
    $firstname =~ s/Ã¼/ü/g; $name =~ s/Ã¼/ü/g;
    
    my $rvmod = $accreddb->execute ($sthmod, $name, $firstname, $sciper);
    unless ($rvmod) {
      $self->{errmsg} = "Guests::fixallaccents : $accreddb->{errmsg}";
      return;
    }
  }
  $sth->finish;

}

sub cryptallpasswords {
  my $self = shift;
  my  $accreddb = $self->{accreddb};
  my $sql = qq{select * from guests};
  my $sth = $accreddb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Guests::cryptallpasswords : $accreddb->{errmsg}";
    return;
  }
  my $rv = $accreddb->execute ($sth);
  unless ($rv) {
    $self->{errmsg} = "Guests::cryptallpasswords : $accreddb->{errmsg}";
    return;
  }
  
  my $sqlmod = qq{update guests set password = ? where sciper = ?};
  my $sthmod = $accreddb->prepare ($sqlmod);
  unless ($sthmod) {
    $self->{errmsg} = "Guests::cryptallpasswords : $accreddb->{errmsg}";
    return;
  }
  while (my $guest = $sth->fetchrow_hashref) {
    #next unless ($guest->{sciper} eq 'G16399');
    my $password = $guest->{password};
    if ($password =~ /^[0-9a-f]{32}$/i) {
      warn "Skipping $guest->{email} : pwd = $password\n";
      next;
    }
    $password = cryptpasswd ($password);
    my $rvmod = $accreddb->execute ($sthmod, $password, $guest->{sciper});
    unless ($rvmod) {
      $self->{errmsg} = "Guests::cryptallpasswords : $accreddb->{errmsg}";
      return;
    }
    
  }
  $sth->finish;

}

sub uncryptallpasswords {
  my $self = shift;
  my  $accreddb = $self->{accreddb};
  my $sql = qq{select * from guests};
  my $sth = $accreddb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Guests::cryptallpasswords : $accreddb->{errmsg}";
    return;
  }
  my $rv = $accreddb->execute ($sth);
  unless ($rv) {
    $self->{errmsg} = "Guests::cryptallpasswords : $accreddb->{errmsg}";
    return;
  }
  
  my $sqlmod = qq{update guests set password = ? where sciper = ?};
  my $sthmod = $accreddb->prepare ($sqlmod);
  unless ($sthmod) {
    $self->{errmsg} = "Guests::cryptallpasswords : $accreddb->{errmsg}";
    return;
  }
  while (my $guest = $sth->fetchrow_hashref) {
    my $password = $guest->{password};
    if ($password !~ /^[0-9a-f]$/i) {
      warn "Skipping $guest->{email} : pwd = $password\n";
      next;
    }
    $password = uncryptpasswd ($password);
    my $rvmod = $accreddb->execute ($sthmod, $password, $guest->{sciper});
    unless ($rvmod) {
      $self->{errmsg} = "Guests::cryptallpasswords : $accreddb->{errmsg}";
      return;
    }
    
  }
  $sth->finish;
}

sub initmessages {
  my $self = shift;
  $messages = {
    noemail => {
      fr => "Pas d'adresse email",
      en => "No email",
    },
    nopassword => {
      fr => "Pas de mot de passe",
      en => "No password",
    },
    noname => {
      fr => "Pas de nom",
      en => "No name",
    },
    nofirstname => {
      fr => "Pas de prénom",
      en => "No firstname",
    },
    noorg => {
      fr => "Pa d'organisation",
      en => "No org",
    },
    duplicateemail => {
      fr => "Adresse email déjà existente : %s",
      en => "Duplicate email address : %s",
    },
    unknownguest => {
      fr => "Huest inconnu : %s",
      en => "Unknown guests : %s",
    },
    cannotremoveguest => {
      fr => "Accès interdit, seul le propriétaire peut supprimer un guest",
      en => "Access denied, only the creator can remove a guest",
    },
  };
}

sub error {
  my ($self, $sub, $msgcode, @args) = @_;
  my  $msghash = $messages->{$msgcode};
  my $language = $self->{language} || 'en';
  my  $message = $msghash->{$language};
  $self->{errmsg} = sprintf ("$sub : $message", @args);
}



1;
