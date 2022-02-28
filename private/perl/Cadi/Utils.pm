#!/usr/bin/perl
#
package Cadi::Utils;

use strict;
use lib qw(/opt/dinfo/lib/perl);

use Cadi::CadiDB;
use Accred::Properties;

my $verbose = 0;
my $cadidb;

sub init {
  $cadidb = new Cadi::CadiDB (
    dbname => 'cadi',
  );
  unless ($cadidb) {
    die "Cadi::Utils::init : Unable to connect to CADI database : $CadiDB::errmsg\n";
  }
}

sub getPersonneInfos {
  my $sciper = shift;
  my $sql = qq{
    select nom_acc       as nom,
           prenom_acc    as prenom,
           nom           as nommaj,
           prenom        as prenommaj,
           nom_usuel,
           prenom_usuel,
           user          as username,
           uid           as uid,
           addrlog       as email,
           addrphy       as physemail
      from dinfo.sciper
      left outer join dinfo.emails
                   on emails.sciper = sciper.sciper
      left outer join dinfo.accounts
                   on dinfo.accounts.sciper = sciper.sciper
                where sciper.sciper = ?
  };
  #main::logmsg (1, "getPersonneInfos:sql = $sql");
  my  $db = new Cadi::CadiDB (dbname => 'cadi');
  my $sth = $db->prepare ($sql) || return;
  my  $rv = $db->execute ($sth, $sciper) || return;
  
  my ($nom, $prenom, $nommaj, $prenommaj, $nom_usuel, $prenom_usuel,
      $username, $uid, $email) = $sth->fetchrow;
  return {
          sciper => $sciper,
             nom => $nom,
          prenom => $prenom,
          nommaj => $nommaj,
       prenommaj => $prenommaj,
       nom_usuel => $nom_usuel,
    prenom_usuel => $prenom_usuel,
        username => $username,
             uid => $uid,
           email => $email,
            type => 'A',
  } if $nom;

  my $sql = qq{
    select name,
           firstname,
           email
      from accred.guests
     where sciper = ?
  };
  my  $db = new Cadi::CadiDB (dbname => 'cadi');
  my $sth = $db->prepare ($sql) || return;
  my  $rv = $db->execute ($sth, $sciper) || return;

  my ($name, $firstname, $email) = $sth->fetchrow;
  return unless $name;
  $sth->finish;
  return {
        sciper => $sciper,
           nom => $name,
        prenom => $firstname,
      username => $email,
           uid => -1,
         email => $email,
          type => 'G',
    };
}

sub getGasparInfos {
  my $sciper = shift;
  my $sql = qq{
    select *
      from accred.guests
     where sciper = ?
  };
  my  $db = new Cadi::CadiDB (dbname => 'cadi');
  my $sth = $db->prepare ($sql) || return;
  my  $rv = $db->execute ($sth, $sciper) || return;
  my $guest = $sth->fetchrow_hashref;
  $sth->finish;
  return $guest;
}

sub getGuestInfos {
  my $sciper = shift;
  my $sql = qq{
    select *
      from accred.guests
     where sciper = ?
  };
  my  $db = new Cadi::CadiDB (dbname => 'cadi');
  my $sth = $db->prepare ($sql) || return;
  my  $rv = $db->execute ($sth, $sciper) || return;
  my $guest = $sth->fetchrow_hashref;
  $sth->finish;
  return $guest;
}

sub getUnitInfos {
  my  $unit = shift;
  my $sql = qq{
    select sigle,
           dinfo.allunits.libelle as libelle,
           hierarchie,
           date_debut,
           date_fin,
           gid
      from dinfo.allunits,
           dinfo.groups
     where dinfo.allunits.id_unite = ?
       and         dinfo.groups.id = ?
  };
  my  $db = new Cadi::CadiDB (dbname => 'cadi');
  my $sth = $db->prepare ($sql) || return;
  my  $rv = $db->execute ($sth, $unit, $unit) || return;

  my $result = $sth->fetchrow_hashref;
  $sth->finish;
  return $result;
}

sub getUnitHierarchy {
  my    $unit = shift;
  my @parents = ();
  while ($unit) {
    my $sql = qq{select sigle, id_parent
                   from dinfo.allunits
                  where dinfo.allunits.id_unite = ?
    };
    my  $db = new Cadi::CadiDB (dbname => 'cadi');
    my $sth = $db->prepare ($sql) || last;
    my  $rv = $db->execute ($sth, $unit) || last;
    my ($sigle, $parent) = $sth->fetchrow;
    $sth->finish;
    push (@parents, { id => $unit, sigle => $sigle, });
    $unit = $parent;
  }
  return @parents;
}

sub getUnitAncestors {
  my $unit = shift;
  my @ancestors;
  while ($unit) {
    my $sql = qq{
      select id_parent
        from dinfo.allunits
       where id_unite = ?
    };
    my  $db = new Cadi::CadiDB (dbname => 'cadi');
    my $sth = $db->prepare ($sql) || last;
    my  $rv = $db->execute ($sth, $unit) || last;
    my ($parent) = $sth->fetchrow ();
    push (@ancestors, $parent) if $parent;
    $unit = $parent;
  }
  return @ancestors;
}

sub getAccredInfos {
  my ($sciper, $unite) = @_;
  my $sql = qq{
    select *
      from accred.accreds
     where persid = ?
       and unitid = ?
       and (debval is NULL or debval <= now())
       and (finval is NULL or finval  > now())
  };
  my  $db = new Cadi::CadiDB (dbname => 'cadi');
  my $sth = $db->prepare ($sql) || last;
  my  $rv = $db->execute ($sth, $sciper, $unite) || return;

  my $result = $sth->fetchrow_hashref;
  $sth->finish;
  return $result;
}

sub getAccreds {
  my $sciper = shift;
  my $sql = qq{
    select unitid
     from accred.accreds
    where persid = ?
      and (debval is NULL or debval <= now())
      and (finval is NULL or finval  > now())
  };
  my  $db = new Cadi::CadiDB (dbname => 'cadi');
  my $sth = $db->prepare ($sql) || return;
  my  $rv = $db->execute ($sth, $sciper) || return;

  my $units = $sth->fetchall_arrayref ([0]);
  my @units = map { $_->[0] } @$units;
  $sth->finish;
  return @units;
}

sub getAccredProperty {
  my ($accred, $propid) = @_;
  my $properties = new Accred::Properties ();
  return $properties->getAccredProperty ($accred, $propid);
}

sub getUnitProperty {
  my ($unitid, $propid) = @_;
  my ($aut, $def);

  my @ancestors = getUnitAncestors ($unitid);
  my $root = $ancestors [$#ancestors];
  unshift (@ancestors, $unitid);
  my $root = $ancestors [$#ancestors];
  foreach my $ancestor (@ancestors) {
    my $sql = qq{
      select allowed, granted
       from accred.properties_units
      where unitid = ?
        and propid = ?
        and (debval is NULL or debval <= now())
        and (finval is NULL or finval  > now())
    };
    my  $db = new Cadi::CadiDB (dbname => 'cadi');
    my $sth = $db->prepare ($sql) || last;
    my  $rv = $db->execute ($sth, $ancestor, $propid) || last;

    my ($autorise, $defaut) = $sth->fetchrow;
    $aut = $autorise if !$aut && $autorise;
    $def = $defaut   if !$def && $defaut;
    last if ($aut && $def);
  }
  $aut ||= 'n'; $def ||= 'n';
  return ($aut, $def);
}

sub getBottinInfos {
  my ($sciper, $unite) = @_;
  my $sql = qq{
    select *
      from dinfo.bottin
     where sciper = ?
       and  unite = ?
  };
  my  $db = new Cadi::CadiDB (dbname => 'cadi');
  my $sth = $db->prepare ($sql) || last;
  my  $rv = $db->execute ($sth, $sciper, $unite) || return;

  my $result = $sth->fetchrow_hashref;
  $sth->finish;
  return $result;
}

sub geLocalInfos {
  my $id = shift;
  my $sql = qq{
    select *
      from dinfo.locaux
     where room_id = ?
  };
  my  $db = new Cadi::CadiDB (dbname => 'cadi');
  my $sth = $db->prepare ($sql) || return;
  my  $rv = $db->execute ($sth, $id) || return;

  my $result = $sth->fetchrow_hashref;
  $sth->finish;
  return $result;
}

sub getGroupInfos {
  my $groupid = shift;
  return unless $groupid;
  if ($groupid =~ /^\d+$/) {
    $groupid = sprintf ("S%05d", $groupid);
  }
  return unless ($groupid =~ /^S\d\d\d\d\d$/);
  my $sql = qq{
    select *
      from groupes.newgroups
     where id = ?
  };
  my  $db = new Cadi::CadiDB (dbname => 'cadi');
  my $sth = $db->prepare ($sql) || return;
  my  $rv = $db->execute ($sth, $groupid) || return;
  my $group = $sth->fetchrow_hashref;
  $sth->finish;
  return unless $group;
  
  my $sql = qq{select member
                 from groupes.newmembers
                where groupid = ?
  };
  my  $db = new Cadi::CadiDB (dbname => 'cadi');
  my $sth = $db->prepare ($sql) || return;
  my  $rv = $db->execute ($sth, $groupid) || return;
  my $members = $sth->fetchall_arrayref ([0]);
  my @members = map { $_->[0] } @$members;
  $sth->finish;
  $group->{members} = \@members;

  my $sql = qq{select sciper
                 from groupes.actualmembers
                where groupid = ?
  };
  my  $db = new Cadi::CadiDB (dbname => 'cadi');
  my $sth = $db->prepare ($sql) || return;
  my  $rv = $db->execute ($sth, $groupid) || return;
  my $persons = $sth->fetchall_arrayref ([0]);
  my @persons = map { $_->[0] } @$persons;
  $sth->finish;
  $group->{persons} = \@persons;

  return $group;
}

sub getAccountInfos {
  my $sciper = shift;
  my $sql = qq{
    select *
      from dinfo.accounts
     where sciper = ?
  };
  my  $db = new Cadi::CadiDB (dbname => 'cadi');
  my $sth = $db->prepare ($sql) || return;
  my  $rv = $db->execute ($sth, $sciper) || return;
  my $result = $sth->fetchrow_hashref;
  $sth->finish;
  return $result;
}

sub getManyAccountsInfos {
  my @scipers = @_;
  my $in = join (', ', map { '?' } @scipers);
  my $sql = qq{
    select *
      from dinfo.accounts
     where sciper in ($in)
  };
  my  $db = new Cadi::CadiDB (dbname => 'cadi');
  my $sth = $db->prepare ($sql) || return;
  my  $rv = $db->execute ($sth, @scipers) || return;
  my $results;
  while (my $result = $sth->fetchrow_hashref) {
    my $sciper = $result->{sciper};
    $results->{$sciper} = $result;
  }
  $sth->finish;
  return $results;
}

sub getAccredsOrders {
  my $sciper = shift;
  my $sql = qq{
    select unitid, ordre
      from accred.accreds
     where persid = ?
       and (debval is NULL or debval <= now())
       and (finval is NULL or finval  > now())
  };
  my  $db = new Cadi::CadiDB (dbname => 'cadi');
  my $sth = $db->prepare ($sql) || return;
  my  $rv = $db->execute ($sth, $sciper) || return;
  my $orders;
  while (my ($unite, $order) = $sth->fetchrow) {
    $orders->{$unite} = $order;
  }
  $sth->finish;
  return $orders;
}

sub getAdminRoles {
  my $rightid = shift;
  my $sql = qq{
    select accred.roles.*
      from accred.rights_roles,
           accred.roles
     where accred.rights_roles.rightid = ?
       and accred.rights_roles.finval is null
       and accred.rights_roles.roleid = roles.id
  };
  my  $db = new Cadi::CadiDB (dbname => 'cadi');
  my $sth = $db->prepare ($sql) || return;
  my  $rv = $db->execute ($sth, $rightid) || return;
  my @roles;
  while (my $role = $sth->fetchrow_hashref) {
    push (@roles, $role);
  }
  $sth->finish;
  return @roles;
}

sub getAdminRights {
  my $roleid = shift;
  my $sql = qq{
    select accred.droits.*
     from accred.rights_roles,
          accred.rights
    where accred.rights_roles.roleid = ?
      and accred.rights_roles.finval is null
      and accred.rights_roles.rightid = rights.id
  };
  my  $db = new Cadi::CadiDB (dbname => 'cadi');
  my $sth = $db->prepare ($sql) || return;
  my  $rv = $db->execute ($sth, $roleid) || return;
  my @droits;
  while (my $droit = $sth->fetchrow_hashref) {
    push (@droits, $droit);
  }
  $sth->finish;
  return @droits;
}

sub getDroitInfos {
  my $rightid = shift;
  my $sql = qq{
    select *
      from accred.rights
     where id = ?
  };
  my  $db = new Cadi::CadiDB (dbname => 'cadi');
  my $sth = $db->prepare ($sql) || return;
  my  $rv = $db->execute ($sth, $rightid) || return;
  my $result = $sth->fetchrow_hashref;
  $sth->finish;
  return $result;
}

sub getRightOfPersonInUnit {
  my ($sciper, $unite, $rightid) = @_;
  my $sql = qq{
    select value
      from accred.rights_persons
     where  persid = ?
       and  unitid = ?
       and rightid = ?
       and debval < now()
       and (finval > now() or finval is null)
  };
  my  $db = new Cadi::CadiDB (dbname => 'cadi');
  my $sth = $db->prepare ($sql) || return;
  my  $rv = $db->execute ($sth, $sciper, $unite, $rightid) || return;
  my ($result) = $sth->fetchrow ();
  $sth->finish;
  return $result;

}

sub getRoleInfos {
  my $roleid = shift;
  my $sql = qq{
    select *
      from accred.roles
     where id = ?
  };
  my  $db = new Cadi::CadiDB (dbname => 'cadi');
  my $sth = $db->prepare ($sql) || return;
  my  $rv = $db->execute ($sth, $roleid) || return;
  my $result = $sth->fetchrow_hashref;
  $sth->finish;
  return $result;
}

sub getAttrLabel {
  my ($type, $id) = @_;
  my $table;
  if ($type eq 'fonction') {
    $table = 'accred.positions';
  }
  elsif ($type eq 'statut') {
    $table = 'accred.statuses'
  }
  elsif ($type eq 'classe') {
    $table = 'accred.classes'
  } else {
    return;
  }
  my $sql = qq{
    select labelfr from $table
     where id = ?
       and (debval is NULL or debval <= now())
       and (finval is NULL or finval  > now())
  };
  my  $db = new Cadi::CadiDB (dbname => 'cadi');
  my $sth = $db->prepare ($sql) || return;
  my  $rv = $db->execute ($sth, $id) || return;
  my ($label) = $sth->fetchrow;
  $sth->finish;
  return $label;
}

sub latin1toutf8 {
  my $string = shift;
  $string =~ s/([\x80-\xFF])/chr(0xC0|ord($1)>>6).chr(0x80|ord($1)&0x3F)/eg;
  return $string;
}

sub fixcase {
  my $string = shift;
  $string =~ tr/A-Z/a-z/;
  if ($string =~ /^(.*)([- ]+)(.*)$/) {
    my ($a, $b, $c) = ($1, $2, $3);
    $string = fixcase ($a) . $b . fixcase ($c);
  } else {
    $string = ucfirst $string
      unless ($string =~ /^(a|au|des|de|du|en|et|zur|le|la|les|sur|von|la)$/);
  }
  return $string;
}

sub dbquery {
  my $sql = shift;
  unless ($cadidb) {
    $cadidb = new Cadi::CadiDB (dbname => 'cadi');
    unless ($cadidb) {
      warn "error in CadiDB : $CadiDB::errmsg\n";
      return;
    }
  }
  my $sth = $cadidb->query ('select 1');
  unless ($sth) {
    $cadidb = new Cadi::CadiDB (dbname => 'cadi');
    unless ($cadidb) {
      warn "error in CadiDB : $CadiDB::errmsg\n";
      return;
    }
  }
  my $sth = $cadidb->query ($sql);
  #main::logmsg (1, "DB error : $CadiDB::errmsg") unless $sth;
  return $sth;
}


1;

