#!/usr/bin/perl
#
use strict;
use utf8;
use Encode;
use Cadi::CadiDB;

package Cadi::Persons;

my $messages;

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
  warn "new Cadi::Persons ()\n" if $self->{verbose};
  initmessages ($self);
  $self->{dinfodb} = new Cadi::CadiDB (
     dbname => 'dinfo',
      trace => $self->{trace},
    verbose => $self->{verbose},
       utf8 => $self->{utf8},
  );
  bless $self, $class;
}

sub getPersonInfos {
  return getPerson (@_);
}

sub getPerson {
  my ($self, $sciper) = @_;
  if ($sciper =~ /^(.*)@(.*)$/) { # Probably Shibboleth user.
    my ($id, $org) = ($1, $2);
    if ($org eq 'epfl.ch') { # Local.
      $sciper = $id;
    } else {
      return {
          id => $id,
        type => 'person',
         org => $org,
      };
    }
  }
  #
  # Name, Firstname, Username, Email, Org
  #
  my ($name, $firstname, $upname, $upfirstname, $nameus, $firstnameus,
      $sex, $username, $uid, $email, $physemail);
  my ($status, $display, $org);
  $org = 'epfl.ch';
  my $dinfodb = $self->{dinfodb};
  if ($sciper =~ /^\d\d\d\d\d\d$/) {
    my $sql = qq{
      select dinfo.sciper.nom_acc      as name,
             dinfo.sciper.prenom_acc   as firstname,
             dinfo.sciper.nom          as upname,
             dinfo.sciper.prenom       as upfirstname,
             dinfo.sciper.nom_usuel    as nameus,
             dinfo.sciper.prenom_usuel as firstnameus,
             dinfo.sciper.sexe         as sex,
             dinfo.accounts.user       as username,
             dinfo.accounts.uid        as uid,
             dinfo.emails.addrlog      as email,
             dinfo.emails.addrphy      as physemail
        from dinfo.sciper
         left outer join dinfo.accounts
                      on dinfo.sciper.sciper = dinfo.accounts.sciper
         left outer join dinfo.emails
                      on dinfo.sciper.sciper = dinfo.emails.sciper
        where dinfo.sciper.sciper = ?
    };
    my $sth = $dinfodb->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "getPerson : $dinfodb->{errmsg}";
      return;
    }
    my $rv = $dinfodb->execute ($sth,  $sciper);
    unless ($rv) {
      $self->{errmsg} = "getPerson : $dinfodb->{errmsg}";
      return;
    }
    ($name, $firstname, $upname, $upfirstname, $nameus, $firstnameus,
     $sex, $username, $uid, $email, $physemail) = $sth->fetchrow;
    return unless $name;
    $display = "$name $firstname";
    $sth->finish;
    #
    # Accred Statut
    #
    my $sql = qq{
      select accred.statuses.labelfr
        from accred.accreds,
             accred.statuses
       where accred.accreds.persid = ?
         and accred.accreds.debval < now()
         and accred.accreds.finval is null
         and accred.accreds.ordre = 1
         and accred.accreds.statusid = statuses.id
    };
    my $sth = $dinfodb->prepare ($sql);
    if ($sth) {
      my $rv = $dinfodb->execute ($sth,  $sciper);
      if ($rv) {
        my ($statut) = $sth->fetchrow;
        $status = $statut if $statut;
        $sth->finish;
      }
    }
    #
    # Olds
    #
    unless ($status) {
      my $sql = qq{
        select dinfo.epflold.lastunits
          from dinfo.epflold
         where dinfo.epflold.sciper = ?
      };
      my $sth = $dinfodb->prepare ($sql);
      if ($sth) {
        my $rv = $dinfodb->execute ($sth,  $sciper);
        if ($rv) {
          my ($lastunits) = $sth->fetchrow;
          $status = 'Old' if $lastunits;
          $sth->finish;
        }
      }
    }
  }
  elsif ($sciper =~ /^G\d\d\d\d\d$/) {
    my $sql = qq{
      select accred.guests.name      as name,
             accred.guests.firstname as firstname,
             accred.guests.email     as username,
             accred.guests.email     as email
        from accred.guests
       where accred.guests.status = 1
         and accred.guests.sciper = ?
    };
    my $sth = $dinfodb->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "Persons::getPerson : $dinfodb->{errmsg}";
     return;
    }
    my $rv = $dinfodb->execute ($sth, $sciper);
    unless ($rv) {
      $self->{errmsg} = "Persons::getPerson : $dinfodb->{errmsg}";
      return;
    }
    ($name, $firstname, $username, $email) = $sth->fetchrow;
    $sth->finish;
    return unless $name;
    $upname = uc $name; $upfirstname = uc $firstname;
    $status = 'Guest';
    $display = "Guest: $name $firstname";
  }
  elsif ($sciper =~ /^Z\d\d\d\d\d$/) {
    my $sql = qq{
      select dinfo.SwitchAAIUsers.name,
             dinfo.SwitchAAIUsers.firstname,
             dinfo.SwitchAAIUsers.username,
             dinfo.SwitchAAIUsers.email,
             dinfo.SwitchAAIUsers.org
        from dinfo.SwitchAAIUsers
       where dinfo.SwitchAAIUsers.sciper = ?
    };
    my $sth = $dinfodb->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "Persons::getPerson : $dinfodb->{errmsg}";
     return;
    }
    my $rv = $dinfodb->execute ($sth, $sciper);
    unless ($rv) {
      $self->{errmsg} = "Persons::getPerson : $dinfodb->{errmsg}";
      return;
    }
    ($name, $firstname, $username, $email, $org) = $sth->fetchrow;
    $sth->finish;
    return unless $name;
    $upname  = uc $name; $upfirstname = uc $firstname;
    $status  = 'SwitchAAI';
    $display = "AAI:$org: $name $firstname";
    $org     = 'SwitchAAI:' . $org;
  } else {
    return;
  }
  $status ||= 'none';
  if ($self->{utf8}) {
    Encode::_utf8_on ($display) unless Encode::is_utf8 ($display);
  }
  my $person = {
              id => $sciper,
            type => 'person',
          sciper => $sciper,
         display => $display,
       firstname => $firstname,
            name => $name,
     upfirstname => $upfirstname,
          upname => $upname,
     firstnameus => $firstnameus,
          nameus => $nameus,
        username => $username,
             uid => $uid,
             sex => $sex,
           email => $email,
       physemail => $physemail,
          status => $status,
             org => $org,
  };
  #
  # Accréditations
  #
  my $sql = qq{
    select accred.accreds.unitid    as unitid,
           accred.statuses.labelfr  as status,
           accred.classes.labelfr   as class,
           accred.positions.labelfr as fonction,
           dinfo.unites.sigle       as unit
      from accred.accreds
           join dinfo.unites     on dinfo.unites.id_unite = accred.accreds.unitid
           join accred.statuses  on    accred.statuses.id = accred.accreds.statusid
           join accred.classes   on     accred.classes.id = accred.accreds.classid
           join accred.positions on   accred.positions.id = accred.accreds.posid
     where accred.accreds.persid = ?
       and accred.accreds.debval < now()
       and (accred.accreds.finval is null or accred.accreds.finval > now())
  };
  my $sth = $dinfodb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Persons::getPerson : $dinfodb->{errmsg}";
   return;
  }
  my $rv = $dinfodb->execute ($sth, $sciper);
  unless ($rv) {
    $self->{errmsg} = "Persons::getPerson : $dinfodb->{errmsg}";
    return;
  }
  my @accreds;
  while (my ($unitid, $status, $class, $fonction, $unit) = $sth->fetchrow) {
    my $display = $unit . '.' . $name . ' ' . $firstname;
    push (@accreds,
      {
        accred => {
               id => "$unitid:$sciper",
          display => $display,
         fonction => $fonction,
           status => $status,
            class => $class,
        },
      },
    );
  }
  $sth->finish;
  $person->{accreds} = \@accreds;
  #
  # isaetu
  #
  my $sql = qq{
    select sciper,
           branche1,
           branche3,
           nivetude,
           matricule,
           uniteaccred
      from isa_etu
     where sciper = ?
  };
  my $sth = $dinfodb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Persons::getPerson : $dinfodb->{errmsg}";
    return;
  }
  my $rv = $dinfodb->execute ($sth, $sciper);
  unless ($rv) {
    $self->{errmsg} = "Persons::getPerson : $dinfodb->{errmsg}";
    return;
  }
  my @studies;
  while (my $study = $sth->fetchrow_hashref) {
    push (@studies, $study);
  }
  $sth->finish;
  $person->{studies} = \@studies;
  #
  # Rôles
  #
  my $sql = qq{
    select accred.roles_persons.roleid as roleid,
           accred.roles_persons.unitid as unitid,
           accred.roles_persons.value  as value,
           accred.roles.labelfr        as rolename,
           dinfo.unites.sigle          as unitacro
      from accred.roles,
           accred.roles_persons,
           dinfo.unites
     where accred.roles_persons.persid = ?
       and accred.roles_persons.unitid = dinfo.unites.id_unite
       and accred.roles_persons.roleid = accred.roles.id
  };
  my $sth = $dinfodb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Persons::getPerson : $dinfodb->{errmsg}";
   return;
  }
  my $rv = $dinfodb->execute ($sth, $sciper);
  unless ($rv) {
    $self->{errmsg} = "Persons::getPerson : $dinfodb->{errmsg}";
    return;
  }
  my @roles;
  while (my $role = $sth->fetchrow_hashref) {
    push (@roles, {
        role => $role->{rolename},
        unit => {
               id => $role->{unitid},
          display => $role->{unitacro}
        },
        value => $role->{value},
      }
    );
  }
  $sth->finish;
  $person->{roles} = \@roles;
  #
  # Droits
  #
  my $sql = qq{
    select accred.rights_persons.rightid as rightid,
           accred.rights_persons.unitid  as unitid,
           accred.rights_persons.value   as value,
           accred.rights.labelfr         as rightname,
           dinfo.unites.sigle            as unitacro
      from accred.rights,
           accred.rights_persons,
           dinfo.unites
     where accred.rights_persons.persid  = ?
       and accred.rights_persons.unitid  = dinfo.unites.id_unite
       and accred.rights_persons.rightid = accred.rights.id
  };
  my $sth = $dinfodb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Persons::getPerson : $dinfodb->{errmsg}";
   return;
  }
  my $rv = $dinfodb->execute ($sth, $sciper);
  unless ($rv) {
    $self->{errmsg} = "Persons::getPerson : $dinfodb->{errmsg}";
    return;
  }
  my @rights;
  while (my $right = $sth->fetchrow_hashref) {
    push (@rights, {
        right => $right->{rightname},
        unit => {
               id => $right->{unitid},
          display => $right->{unitacro}
        },
        value => $right->{value},
      }
    );
  }
  $sth->finish;
  $person->{rights} = \@rights;
  #
  return $person;
}

sub storeAAIUser {
  my ($self, $user) = @_;
  unless ($user->{username} && $user->{name} && $user->{firstname} && $user->{email}) {
    $self->{errmsg} =
      "Persons::storeAAIUser : Bad call : ".
      "$user->{username}:$user->{name}:$user->{firstname}:$user->{email}";
    return;
  }
  my $dinfodb = $self->{dinfodb};
  unless ($dinfodb) {
    $self->{errmsg} = "Persons::storeAAIUser : $DBI::errstr";
    return;
  }
  my $sql = qq{
    select id, sciper, username, name, firstname, email
     from SwitchAAIUsers
    where username = ?
  };
  my $sth = $dinfodb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Persons::storeAAIUser : $dinfodb->{errmsg}";
    return;
  }
  my $rv = $sth->execute ($user->{username});
  unless ($rv) {
    $self->{errmsg} = "Persons::storeAAIUser : $dinfodb->{errmsg}";
    return;
  }
  my $account = $sth->fetchrow;
  return $account->{sciper} if $account;

  my ($uid, $org) = split (/@/, $user->{username});
  my $sql = qq{
    insert into SwitchAAIUsers set
      username => ?,
          name => ?,
     firstname => ?,
         email => ?,
           org => ?
  };
  my $sth = $dinfodb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Persons::storeAAIUser : $dinfodb->{errmsg}";
    return;
  }
  my $rv = $sth->execute (
    $user->{username},
    $user->{name},
    $user->{firstname},
    $user->{email},
    $org,
  );
  unless ($rv) {
    warn "OAuth2IdP:error: $dinfodb->{errmsg}.\n";
    return;
  }
  my $id = $sth->{mysql_insertid};
  unless ($id) {
    $self->{errmsg} = "Persons::storeAAIUser : $dinfodb->{errmsg}";
    return;
  }
  my $sciper = sprintf ("Z%05d", $id);
  my $sql = qq{
    update SwitchAAIUsers
       set sciper = ?
     where     id = ?,
  };
  my $sth = $dinfodb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Persons::storeAAIUser : $dinfodb->{errmsg}";
    return;
  }
  my $rv = $sth->execute ($sciper, $id);
  unless ($rv) {
    $self->{errmsg} = "Persons::storeAAIUser : $dinfodb->{errmsg}";
    return;
  }
  $user->{id}     = $id;
  $user->{sciper} = $sciper;
  return $user;
}

sub searchPersons {
  my ($self, $key, $value) = @_;
  my $fieldnames = {
           id => 'dinfo.sciper.sciper',
       sciper => 'dinfo.sciper.sciper',
         name => 'dinfo.sciper.nom_acc',
    firstname => 'dinfo.sciper.prenom_acc',
     username => 'dinfo.accounts.user',
        email => 'dinfo.emails.addrlog',
  };
  my $tables;
  foreach my $field (keys %$fieldnames) {
    my $table = $fieldnames->{$field};
    $table =~ s/\.[^\.]*$//;
    $tables->{$table} = 1;
  }
  my $select = join (', ', map { "$fieldnames->{$_} as $_" } keys %$fieldnames);
  my $dinfodb = $self->{dinfodb};
  my $sql = qq{
    select $select
      from dinfo.sciper
      left outer join dinfo.accounts
        on dinfo.sciper.sciper = dinfo.accounts.sciper
      left outer join dinfo.emails
        on dinfo.sciper.sciper = dinfo.emails.sciper
     where $fieldnames->{$key} = ?
  };
  #$sql =~ s/\s+/ /g; warn "sql = $sql\n";
  my $sth = $dinfodb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Persons::searchPersons : $dinfodb->{errmsg}";
    return;
  }
  my $rv = $dinfodb->execute ($sth, $value);
  unless ($rv) {
    $self->{errmsg} = "Persons::searchPersons : $dinfodb->{errmsg}";
    return;
  }
  my $persons;
  while (my $person = $sth->fetchrow_hashref) {
    $person->{type}     = 'person';
    $person->{display}  = "$person->{name} $person->{firstname}";
    $persons->{$person->{sciper}} = $person;
  }
  $sth->finish;
  my @persons = values %$persons;
  return @persons;
}

sub matchPerson {
  my ($self, $patterns) = @_;
  my $caller = $self->{caller};
  warn "Persons::matchPerson ($caller)\n" if $self->{trace};
  my $ok;
  my $fields = $self->dblistfields ();
  foreach my $attr (keys %$patterns) {
    next unless $fields->{$attr};
    my $pattern = $patterns->{$attr};
    unless (eval { /$pattern/; 1 }) {
      $self->{errmsg} = "Persons::matchPerson : invalid pattern : $pattern";
      return;
    }
    $ok = 1;
  }
  unless ($ok) {
    $self->{errmsg} = "Persons::matchPerson : No pattern given.";
    return;
  }
  my @persons = $self->dbmatchperson ($patterns);
  return @persons;
}

sub getPersonFromNameLike {
  my ($self, $name) = @_;
  my $sql = qq{
    select sciper,
           match(nom_acc, prenom_acc) against(? in boolean mode) as score
      from sciper
    having score > 0
     order by score desc, nom_acc, prenom_acc
     limit 20
  };
  my @names = split (/[\s\.-]/, $name);
  $names [0] = '>' . $names [0];
  my $value = join (' ', @names);
  my $sth = $self->dbsafequery ($sql, $value) || return;
  my @results;
  while (my ($persid, $score) = $sth->fetchrow_array) {
    push (@results, {
      persid => $persid,
       score => $score,
    });
  }
  $sth->finish;
  return @results;
}

sub dbsafequery {
  my ($self, $sql, @values) = @_;
  warn "dbsafequery:sql = $sql, values = @values\n" if ($self->{verbose} >= 3);
  
  unless ($self->{dinfodb}) {
    warn scalar localtime, " $self->{packname}::Connecting to dinfo.\n"
      if ($self->{verbose} >= 3);
    $self->{dinfodb} = new Accred::Local::LocalDB (
      dbname => 'dinfo',
       trace => 1,
        utf8 => 1,
    );
  }
  return unless $self->{dinfodb};
  my  $db = $self->{dinfodb};
  my $sth = $db->prepare ($sql);
  unless ($sth) {
    warn scalar localtime, " $self->{packname}::Trying to reconnect..., sql = $sql";
    $sth = $db->prepare ($sql);
    warn scalar localtime, "$self->{packname}::Reconnection failed." unless $sth;
  }
  my $rv = $sth->execute (@values);
  unless ($rv) {
    warn scalar localtime, " $self->{packname}::Trying to reconnect..., sql = $sql";
    $rv = $sth->execute (@values);
    warn scalar localtime, " $self->{packname}::Reconnection failed." unless $rv;
  }
  return $sth;
}

sub findPersons {
  my ($self, $string) = @_;
  my  $dinfodb = $self->{dinfodb};
  unless ($dinfodb) {
    $self->{errmsg} = "Persons::findPersons : $Cadi::CadiDB::errmsg";
    return;
  }
  if ($string =~ /\s/) {
    my ($p, $n) = split (/\s+/, $string, 2);
    my $sql = qq{
      select distinct sciper.sciper
        from sciper,
             accred.accreds
       where ((nom     like ? and prenom     like ?)
          or  (nom_acc like ? and prenom_acc like ?)
          or  (nom     like ? and prenom     like ?)
          or  (nom_acc like ? and prenom_acc like ?))
         and accred.accreds.persid = sciper.sciper
         and (accred.accreds.debval is NULL or accred.accreds.debval <= now())
         and (accred.accreds.finval is NULL or accred.accreds.finval  > now())
    };
    #$sql =~ s/\s+/ /g; warn "sql = $sql\n";
    my $sth = $dinfodb->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "Persons::findPersons : $dinfodb->{errmsg}";
      return;
    }
    my $rv = $dinfodb->execute ($sth,
      "%$n%", "%$p%",
      "%$n%", "%$p%",
      "%$p%", "%$n%",
      "%$p%", "%$n%",
    );
    unless ($rv) {
      $self->{errmsg} = "Persons::findPersons : $dinfodb->{errmsg}";
      return;
    }
    my $scipers = $sth->fetchall_arrayref ([0]); # fetchcol
    my @scipers = map { $_->[0] } @$scipers;

    my $sql = qq{
      select distinct sciper
        from accred.guests
       where status = 1
         and ((name like ? and firstname like ?)
          or  (name like ? and firstname like ?))
    };
    my $sth = $dinfodb->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "Persons::findPersons : $dinfodb->{errmsg}";
      return;
    }
    my $rv = $dinfodb->execute ($sth, "%$n%", "%$p%", "%$p%", "%$n%");
    unless ($rv) {
      $self->{errmsg} = "Persons::findPersons : $dinfodb->{errmsg}";
      return;
    }
    my $guests = $sth->fetchall_arrayref ([0]);
    my @guests = map { $_->[0] } @$guests;

    my $sql = qq{
      select distinct sciper
        from dinfo.SwitchAAIUsers
       where (name like ? and firstname like ?)
          or (name like ? and firstname like ?)
    };
    my $sth = $dinfodb->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "Persons::findPersons : $dinfodb->{errmsg}";
      return;
    }
    my $rv = $dinfodb->execute ($sth, "%$n%", "%$p%", "%$p%", "%$n%");
    unless ($rv) {
      $self->{errmsg} = "Persons::findPersons : $dinfodb->{errmsg}";
      return;
    }
    my $aais = $sth->fetchall_arrayref ([0]);
    my @aais = map { $_->[0] } @$aais;

    return (@scipers, @guests, @aais);
  } else {
    my $sql = qq{
      select distinct sciper.sciper
        from sciper, accred.accreds
       where nom like ?
         and accred.accreds.persid = sciper.sciper
         and (accred.accreds.debval is NULL or accred.accreds.debval <= now())
         and (accred.accreds.finval is NULL or accred.accreds.finval  > now())
    };
    #$sql =~ s/\s+/ /g; warn "sql = $sql\n";
    my $sth = $dinfodb->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "Persons::findPersons : $dinfodb->{errmsg}";
      return;
    }
    my $rv = $dinfodb->execute ($sth, "%$string%");
    unless ($rv) {
      $self->{errmsg} = "Persons::findPersons : $dinfodb->{errmsg}";
      return;
    }
    my $scipers = $sth->fetchall_arrayref ([0]);
    my @scipers = map { $_->[0] } @$scipers;
    
    my $sql = qq{
      select distinct sciper
        from accred.guests
       where status = 1
         and name like ?
    };
    my $sth = $dinfodb->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "Persons::findPersons : $dinfodb->{errmsg}";
      return;
    }
    my $rv = $dinfodb->execute ($sth, "%$string%");
    unless ($rv) {
      $self->{errmsg} = "Persons::findPersons : $dinfodb->{errmsg}";
      return;
    }
    my $guests = $sth->fetchall_arrayref ([0]);
    my @guests = map { $_->[0] } @$guests;
    
    my $sql = qq{select distinct sciper
                   from dinfo.SwitchAAIUsers
                  where name like ?
    };
    my $sth = $dinfodb->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "Persons::findPersons : $dinfodb->{errmsg}";
      return;
    }
    my $rv = $dinfodb->execute ($sth, "%$string%");
    unless ($rv) {
      $self->{errmsg} = "Persons::findPersons : $dinfodb->{errmsg}";
      return;
    }
    my $aais = $sth->fetchall_arrayref ([0]);
    my @aais = map { $_->[0] } @$aais;
    
    return (@scipers, @guests, @aais);
  }
}

sub getManyPersonsInfos {
  my ($self, @scipers) = @_;

  my    @epfl = grep (/^\d/, @scipers);
  my  @guests = grep (/^G/,  @scipers);
  my    @aais = grep (/^A/,  @scipers);
  
  my  $dinfodb = $self->{dinfodb};
  my $persons;

  if (@epfl) {
    my  $in = join (', ', map { '?' } @epfl);
    my $sql = qq{
      select dinfo.sciper.sciper,
             dinfo.sciper.nom_acc      as name,
             dinfo.sciper.prenom_acc   as firstname,
             dinfo.sciper.nom_usuel    as nameus,
             dinfo.sciper.prenom_usuel as firstnameus,
             dinfo.sciper.sexe         as genre,
             dinfo.accounts.user       as username,
             dinfo.emails.addrlog      as email
        from dinfo.sciper
        left outer join dinfo.accounts
          on dinfo.sciper.sciper = dinfo.accounts.sciper
        left outer join dinfo.emails
          on dinfo.sciper.sciper = dinfo.emails.sciper
       where dinfo.sciper.sciper in ($in)
    };
    my $sth = $dinfodb->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "Persons::getManyPersonsInfos : $dinfodb->{errmsg}";
      return;
    }
    my $rv = $dinfodb->execute ($sth, @epfl);
    unless ($rv) {
      $self->{errmsg} = "Persons::getManyPersonsInfos : $dinfodb->{errmsg}";
      return;
    }
    while (my ($sciper, $name, $firstname, $nameus, $firstnameus,
               $genre, $username, $email) = $sth->fetchrow) {
      next unless $name;
      my $person = {
                 id => $sciper,
               type => 'person',
             sciper => $sciper,
            display => "$name $firstname",
               name => $name,
          firstname => $firstname,
             nameus => $nameus,
        firstnameus => $firstnameus,
              genre => $genre,
           username => $username,
              email => $email,
      };
      $persons->{$sciper} = $person;
    }
    $sth->finish;
  }
  if (@guests) {
    my  $in = join (', ', map { '?' } @guests);
    my $sql = qq{
      select accred.guests.sciper    as sciper,
             accred.guests.name      as name,
             accred.guests.firstname as firstname,
             accred.guests.email     as usernamee,
             accred.guests.email     as email
        from accred.guests
       where accred.guests.status = 1
         and accred.guests.sciper in ($in)
    };
    my $sth = $dinfodb->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "Persons::getManyPersonsInfos : $dinfodb->{errmsg}";
      return;
    }
    my $rv = $dinfodb->execute ($sth, @guests);
    unless ($rv) {
      $self->{errmsg} = "Persons::getManyPersonsInfos : $dinfodb->{errmsg}";
      return;
    }
    while (my ($sciper, $name, $firstname, $username, $email) = $sth->fetchrow) {
      next unless $name;
      my $person = {
              id => $sciper,
            type => 'person',
          sciper => $sciper,
         display => "$name $firstname",
       firstname => $firstname,
            name => $name,
        username => $username,
           email => $email,
      };
      $persons->{$sciper} = $person;
    }
    $sth->finish;
  }
  if (@aais) {
    my  $in = join (', ', map { '?' } @aais);
    my $sql = qq{
      select dinfo.SwitchAAIUsers.sciper,
             dinfo.SwitchAAIUsers.name,
             dinfo.SwitchAAIUsers.firstname,
             dinfo.SwitchAAIUsers.username,
             dinfo.SwitchAAIUsers.email
        from dinfo.SwitchAAIUsers
       where dinfo.SwitchAAIUsers.sciper in ($in)
    };
    my $sth = $dinfodb->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "Persons::getManyPersonsInfos : $dinfodb->{errmsg}";
      return;
    }
    my $rv = $dinfodb->execute ($sth, @aais);
    unless ($rv) {
      $self->{errmsg} = "Persons::getManyPersonsInfos : $dinfodb->{errmsg}";
      return;
    }
    while (my ($sciper, $name, $firstname, $username, $email) = $sth->fetchrow) {
      next unless $name;
      my $person = {
              id => $sciper,
            type => 'person',
          sciper => $sciper,
         display => "$name $firstname",
       firstname => $firstname,
            name => $name,
        username => $username,
           email => $email,
      };
      $persons->{$sciper} = $person;
    }
    $sth->finish;
  }
  return $persons;
}

sub updateSciperCache {
  my ($self, $sciper) = @_;
  eval "use Cadi::Sciper; 1;";
  return if $@;
  my $Sciper = new Cadi::Sciper ();
  my $person = $Sciper->getPerson ($sciper);
  my $dinfodb = $self->{dinfodb};

  my $sql = qq{
    insert into dinfo.sciper set
              sciper => ?,
                 nom => ?,
              prenom => ?,
                type => ?,
             nom_acc => ?,
          prenom_acc => ?,
          date_naiss => ?,
                sexe => ?
  };
  my $sth = $dinfodb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Persons::updateSciperCache : $dinfodb->{errmsg}";
    return;
  }
  my $rv = $dinfodb->execute ($sth,
    $person->{id},          # sciper
    $person->{ucsurname},   # nom
    $person->{ucfirstname}, # prenom
    $person->{acs},         # type
    $person->{surname},     # nom_acc
    $person->{firstname},   # prenom_acc
    $person->{birthdate},   # date_naiss
    $person->{gender},      # sexe
  );
  unless ($rv) {
    $self->{errmsg} = "Persons::updateSciperCache : $dinfodb->{errmsg}";
    return;
  }
  return 1;
}

sub setPrivateEmail {
  my ($self, $persid, $email) = @_;
  my $accreddb = new Cadi::CadiDB (
     dbname => 'accred',
      trace => $self->{trace},
    verbose => $self->{verbose},
       utf8 => $self->{utf8},
  );
  my $sql = qq{insert into accred.privateemails values (?, ?, 0)};
  my $sth = $accreddb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Persons::setPrivateEmail : $accreddb->{errmsg}";
    return;
  }
  my $rv = $accreddb->execute ($sth,  $persid, $email);
  unless ($rv) {
    $self->{errmsg} = "Persons::setPrivateEmail : $accreddb->{errmsg}";
    return;
  }
  return 1;
}

sub getPrivateEmail {
  my ($self, $persid) = @_;
  my $accreddb = new Cadi::CadiDB (
     dbname => 'accred',
      trace => $self->{trace},
    verbose => $self->{verbose},
       utf8 => $self->{utf8},
  );
  my $sql = qq{
    select email
      from accred.privateemails
     where sciper = ?
  };
  my $sth = $accreddb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Persons::getPrivateEmail : $accreddb->{errmsg}";
    return;
  }
  my $rv = $accreddb->execute ($sth, $persid);
  unless ($rv) {
    $self->{errmsg} = "Persons::getPrivateEmail : $accreddb->{errmsg}";
    return;
  }
  my ($email) = $sth->fetchrow;
  return $email;
}

sub usePrivateEmail {
  my ($self, $persid) = @_;
  my $accreddb = new Cadi::CadiDB (
     dbname => 'accred',
      trace => $self->{trace},
    verbose => $self->{verbose},
       utf8 => $self->{utf8},
  );
  my $sql = qq{
    update accred.privateemails set
      status = 1
     where persid = ?
  };
  my $sth = $accreddb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Persons::usePrivateEmail : $accreddb->{errmsg}";
    return;
  }
  my $rv = $accreddb->execute ($sth,  $persid);
  unless ($rv) {
    $self->{errmsg} = "Persons::usePrivateEmail : $accreddb->{errmsg}";
    return;
  }
  return 1;
}
sub addEmailAddress {
  my ($self, $persid, $email) = @_;
  my $dinfodb = $self->{dinfodb};
  if ($persid =~ /^\d\d\d\d\d\d$/) { # EPFL
    my $sql = qq{insert into dinfo.emails set sciper = ?, addrlog = ?};
    my $sth = $dinfodb->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "Persons::addEmailAddress : $dinfodb->{errmsg}";
      return;
    }
    my $rv = $dinfodb->execute ($sth,  $persid, $email);
    unless ($rv) {
      $self->{errmsg} = "Persons::addEmailAddress : $dinfodb->{errmsg}";
      return;
    }
  }
  return 1;
}

sub removeEmailAddress {
  my ($self, $persid) = @_;
  my $dinfodb = $self->{dinfodb};
  if ($persid =~ /^\d\d\d\d\d\d$/) { # EPFL
    my $sql = qq{delete from dinfo.emails where sciper = ?};
    my $sth = $dinfodb->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "Persons::removeEmailAddress : $dinfodb->{errmsg}";
      return;
    }
    my $rv = $dinfodb->execute ($sth,  $persid);
    unless ($rv) {
      $self->{errmsg} = "Persons::removeEmailAddress : $dinfodb->{errmsg}";
      return;
    }
  }
  return 1;
}

sub changeEmailAddress {
  my ($self, $persid, $email) = @_;
  my $dinfodb = $self->{dinfodb};
  if ($persid =~ /^\d\d\d\d\d\d$/) { # EPFL
    my $sql = qq{update dinfo.emails set addrlog = ? where sciper = ?};
    my $sth = $dinfodb->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "Persons::changeEmailAddress : $dinfodb->{errmsg}";
      return;
    }
    my $rv = $dinfodb->execute ($sth,  $persid, $email);
    unless ($rv) {
      $self->{errmsg} = "Persons::changeEmailAddress : $dinfodb->{errmsg}";
      return;
    }
  }
  return 1;
}

sub getPersonByEmail {
  my ($self, $email) = @_;
  my $dinfodb = $self->{dinfodb};
  my $sql1 = qq{select sciper from dinfo.emails         where addrlog = ?};
  my $sql2 = qq{select sciper from accred.guests        where email = ?};
  my $sql3 = qq{select sciper from dinfo.SwitchAAIUsers where email = ?};

  foreach my $sql ($sql1, $sql2, $sql3) {
    my $sth = $dinfodb->prepare ($sql);
    unless ($sth) {
      $self->{errmsg} = "getPersonByEmail : $dinfodb->{errmsg}";
      next;
    }
    my $rv = $dinfodb->execute ($sth, $email);
    unless ($rv) {
      $self->{errmsg} = "getPersonByEmail : $dinfodb->{errmsg}";
      next;
    }
    my ($sciper) = $sth->fetchrow;
    return $sciper if $sciper;
  }
  return;
}

sub dbmatchperson {
  my ($self, $patterns) = @_;
  my  $dinfodb = $self->{dinfodb};
  my $fields = $self->dblistfields ();
  #
  # EPFL
  #
  my (@rlikes, @patts);
  foreach my $attr (keys %$patterns) {
    next unless $fields->{$attr};
    my $pattern = $patterns->{$attr};
    if ($attr eq 'name') {
      push (@rlikes,
        '('.
          "nom           rlike ? or ".
          "nom_acc       rlike ? or ".
          "nom_usuel     rlike ? or ".
          "nom_usuel_maj rlike ?".
        ')'
      );
      push (@patts, $pattern, $pattern, $pattern, $pattern);
    }
    elsif ($attr eq 'firstname') {
      push (@rlikes,
        '('.
          "prenom           rlike ? or ".
          "prenom_acc       rlike ? or ".
          "prenom_usuel     rlike ? or ".
          "prenom_usuel_maj rlike ?".
        ')'
     );
      push (@patts, $pattern, $pattern, $pattern, $pattern);
    }
    elsif ($attr eq 'username') {
      push (@rlikes, "user rlike ?");
      push (@patts, $pattern);
    }
    elsif ($attr eq 'sciper') {
      push (@rlikes, "dinfo.validscipers.sciper rlike ?");
      push (@patts, $pattern);
    }
    elsif ($attr eq 'email') {
      push (@rlikes, "dinfo.emails.addrlog rlike ?");
      push (@patts, $pattern);
    } else {
      push (@rlikes, "$attr rlike ?");
      push (@patts,  $pattern);
    }
  }
  my $rlikes = join (' and ', @rlikes);
  unless ($rlikes) {
    $self->{errmsg} = "Persons::dbmatchperson : Invalid pattern.";
    return;
  }
  my @results;
  my $sql = qq{
    select dinfo.validscipers.sciper     as sciper,
           dinfo.validscipers.nom_acc    as name,
           dinfo.validscipers.prenom_acc as firstname,
           dinfo.accounts.user           as username,
           dinfo.emails.addrlog          as email
      from dinfo.validscipers
      left outer join dinfo.accounts
                   on dinfo.validscipers.sciper = dinfo.accounts.sciper
      left outer join dinfo.emails
                   on dinfo.validscipers.sciper = dinfo.emails.sciper
                where $rlikes
  };
  #$sql =~ s/\t+/ /g; warn "sql1 = $sql\n";
  my $sth = $dinfodb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Persons::dbmatchperson : $dinfodb->{errmsg}";
    return;
  }
  my $rv = $dinfodb->execute ($sth, @patts);
  unless ($rv) {
    $self->{errmsg} = "Persons::dbmatchperson : $dinfodb->{errmsg}";
    return;
  }
  while (my $person = $sth->fetchrow_hashref) {
    $person->{type} = 'person';
    $person->{display} = "$person->{name} $person->{firstname}";
    $person->{status}  = 'EPFL';
    if ($self->{utf8} && !Encode::is_utf8 ($person->{display})) {
      Encode::_utf8_on ($person->{display});
    }
    push (@results, $person);
  }
  $sth->finish;
  #
  # Guests
  #
  my (@rlikes, @patts);
  foreach my $attr (keys %$patterns) {
    next unless $fields->{$attr};
    my $pattern = $patterns->{$attr};
    if ($attr eq 'username') {
      push (@rlikes, "email rlike ?");
      push (@patts, $pattern);
    } else {
      push (@rlikes, "$attr rlike ?");
      push (@patts,  $pattern);
    }
  }
  my $rlikes = join (' and ', @rlikes);
  my $sql = qq{
    select accred.guests.sciper,
           accred.guests.name,
           accred.guests.firstname,
           accred.guests.email
      from accred.guests
     where accred.guests.status = 1
       and $rlikes
  };
  #$sql =~ s/\t+/ /g; warn "sql2 = $sql\n";
  my $sth = $dinfodb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Persons::dbmatchperson : $dinfodb->{errmsg}";
    warn "Error : $dinfodb->{errmsg}\n";
    return;
  }
  my $rv = $dinfodb->execute ($sth, @patts);
  unless ($rv) {
    $self->{errmsg} = "Persons::dbmatchperson : $dinfodb->{errmsg}";
    return;
  }
  while (my $person = $sth->fetchrow_hashref) {
    $person->{type} = 'person';
    $person->{display}  = "$person->{name} $person->{firstname}";
    $person->{status}   = 'Guest';
    $person->{username} = $person->{email};
    if ($self->{utf8} && !Encode::is_utf8 ($person->{display})) {
      Encode::_utf8_on ($person->{display});
    }
    push (@results, $person);
  }
  $sth->finish;
  #
  # AAI
  #
  my (@rlikes, @patts);
  foreach my $attr (keys %$patterns) {
    next unless $fields->{$attr};
    my $pattern = $patterns->{$attr};
    push (@rlikes, "$attr rlike ?");
    push (@patts,  $pattern);
  }
  my $rlikes = join (' and ', @rlikes);
  my $sql = qq{
    select dinfo.SwitchAAIUsers.sciper,
           dinfo.SwitchAAIUsers.name,
           dinfo.SwitchAAIUsers.firstname,
           dinfo.SwitchAAIUsers.username,
           dinfo.SwitchAAIUsers.email,
           dinfo.SwitchAAIUsers.org
      from dinfo.SwitchAAIUsers
     where $rlikes
  };
  #$sql =~ s/\t+/ /g; warn "sql3 = $sql\n";
  my $sth = $dinfodb->prepare ($sql);
  unless ($sth) {
    $self->{errmsg} = "Persons::dbmatchperson : $dinfodb->{errmsg}";
   return;
  }
  my $rv = $dinfodb->execute ($sth, @patts);
  unless ($rv) {
    $self->{errmsg} = "Persons::dbmatchperson : $dinfodb->{errmsg}";
    return;
  }
  while (my $person = $sth->fetchrow_hashref) {
    $person->{type} = 'person';
    $person->{display} = "$person->{name} $person->{firstname}";
    $person->{status}  = "AAI:$person->{org}";
    if ($self->{utf8} && !Encode::is_utf8 ($person->{display})) {
      Encode::_utf8_on ($person->{display});
    }
    push (@results, $person);
  }
  $sth->finish;
  
  return @results;
}

sub dblistfields {
  my $self = shift;
  return {
       sciper => 1,
         name => 1,
    firstname => 1,
     username => 1,
        email => 1,
  };
}

sub errmsg {
  my $self = shift;
  return $self->{errmsg};
}

sub initmessages {
  my $self = shift;
  $messages = {
    nosciper => {
      fr => "No sciper",
      en => "Pas de sciper",
    },
    invalidsciper => {
      fr => "Invalid sciper : %s",
      en => "Numéro sciper invalide : %s",
    },
    nocaller => {
      fr => "Pas d'appelant",
      en => "No caller",
    },
    dberror => {
      fr => "Unable to access database : %s.",
      en => "Impossible d'accéder à la base de données : %s.",
    },
  };
}

sub error {
  my ($self, $sub, $msgcode, @args) = @_;
  my  $msghash = $messages->{$msgcode};
  my $language = $self->{language} || 'en';
  my  $message = $msghash->{$language};
  $self->{errmsg} = sprintf ("$sub : $message", @args);
  return;
}

1;
