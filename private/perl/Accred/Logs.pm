#!/usr/bin/perl
#
##############################################################################
#
# File Name:    logs.pm
# Description:  
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Tue Jul  9 14:20:42 CEST 2002
# Revision:     
#
##############################################################################
#
#
package Accred::Logs;

use strict;
use utf8;
use Carp qw(cluck);

use Accred::Utils;
use Accred::Messages;

my $origines = {
  A => {
    fr => "Autorisé",
    en => "Allowed",
  },
  I => {
    fr => "Interdit",
    en => "Forbidden",
  },
  H => {
    fr => "Hérité",
    en => "Inherited",
  },
};

our @frmonthnames = (
  "Jan",     "Février", "Mars",      "Avril",   "Mai",      "Juin",
  "Juillet", "Août",    "Septembre", "Octobre", "Novembre", "Décembre",
);
our @enmonthnames = (
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
);

our $loglabels = initlabels  ();
my $logopcodes = initopcodes ();
my  $logstable = 'logs';

our $maxlogcode = 59;

sub new {
  my ($class, $req) = @_;
  my  $self = {
         req => $req || {},
          db => undef,
        utf8 => 1,
      errmsg => undef,
        fake => 0,
       debug => 0,
     verbose => 0,
       trace => 0,
  };
  bless $self;
  $self->{lang} = $req->{lang} || 'en';
  Accred::Utils::import ();
  importmodules ($self, 'AccredDB');
  return $self;
}

sub log {
  my ($self, $persid, $oper, @args) = @_;
  my $opcode = ($oper =~ /^\d*$/) ? $oper : $logopcodes->{$oper};
  my ($sec, $min, $hour, $day, $month, $year) = (localtime ())[0..5];
  $month++; $year += 1900;
  my $date = sprintf (
    "%d-%02d-%02d %02d:%02d:%02d",
    $year, $month, $day, $hour, $min, $sec);
  
  my $text = $self->maketext ($opcode, @args);
  cluck ('error: log with no persid') if ($text =~ /:P:/);
  my  $sql = qq{
    insert into $logstable set
              date = ?,
            opcode = ?,
            persid = ?,
              text = ?
  };
  my $sth = $self->{accreddb}->dbsafequery ($sql,
    $date, $opcode, $persid, $text,
  ) or return;
  $sth->finish;
}

sub getLogs {
  my ($self, $author, $when, $what) = @_;
  my    $now = time;
  my $from;
  if    (!$when)                  { $from = 10000;    }
  elsif ($when =~   /^(\d+)day$/) { $from = $1;       }
  elsif ($when =~  /^(\d+)week$/) { $from = $1 *   7; }
  elsif ($when =~ /^(\d+)month$/) { $from = $1 *  31; }
  elsif ($when =~   /^(\d+)year/) { $from = $1 * 365; }
  else                            { $from = 10000; }

  my $sql = qq{
    select date, opcode, persid, text
      from $logstable
     where persid = '$author'
       and to_days(date) > to_days(now()) - $from
  };
  my @values = ();
  if ($what) {
    $sql .= qq{ and opcode = ?};
    push (@values, $what);
  }
  $sql .= qq{ order by date desc};
  my $sth = $self->{accreddb}->dbsafequery ($sql, @values) or return;

  my @logs;
  while (my $log = $sth->fetchrow_hashref) {
    $log->{args} = [ $self->parsetext ($log->{text}) ];
    push (@logs, $log);
  }
  $sth->finish;
  return @logs;
}

sub selectLogs {
  my ($self, %conds) = @_;
  my $conds = \%conds;
  my (@wheres, @values);
  foreach my $field (keys %$conds) {
    if ($field eq 'lessthan') {
      push (@wheres, "to_days(date) > to_days(now()) - $conds->{$field}");
      next;
    }
    if ($field eq 'opcode') {
      next if ($conds->{$field} =~ /^all$/i);
      my $opcode = $logopcodes->{$conds->{$field}};
      next unless $opcode;
      push (@wheres, "opcode = ?");
      push (@values, $opcode);
      next;
    }
    if ($field eq 'unit') {
      my $values = (ref $conds->{$field} eq 'ARRAY')
        ? $conds->{$field}
        : [ $conds->{$field} ]
        ;
      my @questions = map { 'text like ?' } @$values;
      my  @orvalues = map { "%:U$_:%" } @$values;
      push (@wheres, '(' . join (' or ', @questions) . ')');
      push (@values, @orvalues);
      next;
    }
    if ($field eq 'pers') {
      my $values = (ref $conds->{$field} eq 'ARRAY')
        ? $conds->{$field}
        : [ $conds->{$field} ]
        ;
      my @questions = map { 'text like ?' } @$values;
      my  @orvalues = map { "%:P$_:%" } @$values;
      push (@wheres, '(' . join (' or ', @questions) . ')');
      push (@values, @orvalues);
      next;
    }
    push (@wheres, "$field = ?");
    push (@values, $conds->{$field});
  }
  my $where = join (' and ', @wheres);
  my $sql = qq{
    select date,
           opcode,
           persid,
           text
      from $logstable
     where $where
      order by date desc
  };
  my $sth = $self->{accreddb}->dbsafequery ($sql, @values) or return;

  my @logs;
  while (my $log = $sth->fetchrow_hashref) {
    $log->{args} = [ $self->parsetext ($log->{text}) ];
    push (@logs, $log);
  }
  $sth->finish;
  return @logs;
}

sub maketext {
  my ($self, $opcode, @args) = @_;

  grep { s/:/\|/g }      @args;
  grep { s/[\r\n]/\*/g } @args;
  #
  #  1 : Ajout d'une accréditation
  #  3 : Suppression d'une accréditation
  # 33 : Modification d'une accréditation (ancienne version)
  #
  my $text;
  if (($opcode ==  1) || ($opcode ==  3) || ($opcode ==  33)) {
    my ($persid, $unitid, @left) = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', "P$persid", "U$unitid", @left);
  }
  #
  # 2 : Modification d'une accréditation (nouvelle version)
  #
  elsif ($opcode ==  2) {
    my ($persid, $unitid, @left) = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', "P$persid", "U$unitid", @left);
  }
  #
  # 4 : Ajout d'une personne
  #
  elsif ($opcode ==  4) {
    my   @left = @args;
    my $persid = pop @left;
    map { $_ = "X$_" } @left;
    $text = join (':', @left, "P$persid");
  }
  #
  # 5 : Modification d'une personne
  #
  elsif ($opcode ==  5) {
    my   @left = @args;
    my $persid = shift @left;
    map { $_ = "X$_" } @left;
    $text = join (':', "P$persid", @left);
  }
  #
  # 6 : Modification des droits aux prestations d'une unité
  #
  elsif ($opcode ==  6) {
    my ($unitid, @left) = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', "U$unitid", @left);
  }
  #
  # 7 : Modification d'une prestation
  #
  elsif ($opcode ==  7) {
    my @left = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', @left);
  }
  #
  # 8, 23 : Création de l'account
  #
  elsif ($opcode ==  8 || $opcode == 23) {
    my ($persid, @left) = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', "P$persid", @left);
  }
  #
  # 9 : Modification de l'ordre des accreds d'une personne
  #
  elsif ($opcode == 9) {
    my ($persid, @unitids) = @args;
    map { $_ = "U$_" } @unitids;
    $text = join (':', "P$persid", @unitids);
  }
  #
  # 10 : Modification de fonctions EHE
  #
  elsif ($opcode == 10) {
    my ($unitid, @left) = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', "U$unitid", @left);
  }
  #
  # 11 : Création d'une fonction EHE
  # 12 : Suppression d'une fonction EHE
  #
  elsif ($opcode == 11 || $opcode == 12) {
    my @left = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', @left);
  }
  #
  # 38 : Modification d'une fonction EHE
  #
  elsif ($opcode == 38) {
    my @left = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', @left);
  }
  #
  # 13 : Revalidation d'une accréditation
  #
  elsif ($opcode == 13) {
    my ($persid, $unitid, @left) = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', "P$persid", "U$unitid", @left);
  }
  #
  # 14 : Ajout d'un rôle
  # 15 : Modification d'un rôle
  #
  elsif ($opcode == 14 || $opcode == 15) {
    my @left = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', @left);
  }
  #
  # 16 : Suppression d'un rôle
  #
  elsif ($opcode == 16) {
    my @left = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', @left);
  }
  #
  # 17 : Ajout d'un nouveau droit
  # 18 : Modification d'un droit
  #
  elsif ($opcode == 17 || $opcode == 18) {
    my @left = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', @left);
  }
  #
  # 19 : Suppression d'un droit
  #
  elsif ($opcode == 19) {
    my @left = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', @left);
  }
  #
  # 20 : Obsolète
  # 21 : Pas implémenté.
  # 22 : Pas implémenté.
  #
  #
  # 24 : Modification des rôles d'une personne.
  #
  elsif ($opcode == 24) {
    my ($roleid, $persid, $unitid, $newval) = @args;
    $text = join (':', "R$roleid", "P$persid", "U$unitid", "X$newval");
  }
  #
  # 25 : Suppression d'un rôle à une personne.
  #
  elsif ($opcode == 25) {
    my ($roleid, $persid, $unitid) = @args;
    $text = join (':', "R$roleid", "P$persid", "U$unitid");
  }
  #
  # 26 : Modification des droits d'une personne.
  #
  elsif ($opcode == 26) {
    my ($rightid, $persid, $unitid, $newval) = @args;
    $text = join (':', "D$rightid", "P$persid", "U$unitid", "X$newval");
  }
  #
  # 27 : Suppression d'un droit à une personne.
  #
  elsif ($opcode == 27) {
    my ($rightid, $persid, $unitid) = @args;
    $text = join (':', "D$rightid", "P$persid", "U$unitid");
  }
  #
  # 28 : Modification des droits d'une unité
  #
  elsif ($opcode == 28) {
    my ($rightid, $unitid, $newval) = @args;
    $text = join (':', "D$rightid", "U$unitid", "X$newval");
  }
  #
  # 29 : Suppression d'un droit à une unité.
  #
  elsif ($opcode == 29) {
    my ($rightid, $unitid) = @args;
    $text = join (':', "D$rightid", "U$unitid");
  }
  #
  # 30 : Création de fonctions EPFL
  #
  elsif ($opcode == 30) {
    my @left = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', @left);
  }
  #
  # 31 : Modification d'une fonction EPFL
  #
  elsif ($opcode == 31) {
    my @left = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', @left);
  }
  #
  # 32 : Suppression d'une fonction EPFL
  #
  elsif ($opcode == 32) {
    my @left = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', @left);
  }
  #
  # 34 : Ajout d'un privilège droit à un accréditeur
  # 35 : Suppression d'un privilège droit à un accréditeur
  #
  elsif ($opcode == 34 || $opcode == 35) {
    my ($persid, $unitid, $rightid) = @args;
    $text = join (':', "D$rightid", "P$persid", "U$unitid");
  }
  #
  # 36 : Ajout d'un privilège rôle à un accréditeur
  # 37 : Suppression d'un privilège rôle à un accréditeur
  #
  elsif ($opcode == 36 || $opcode == 37) {
    my ($persid, $unitid, $roleid) = @args;
    $text = join (':', "P$persid", "U$unitid", "R$roleid");
  }
  #
  # 43 : Modification d'une propriété d'une accréditation
  #
  elsif ($opcode == 43) { # setaccprop
    my ($persid, $unitid, @left) = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', "P$persid", "U$unitid", @left);
  }
  #
  # 44 : Modification d'une propriété d'une unité
  #
  elsif ($opcode == 44) { # setunitprop
    my ($unitid, $propid, $aut, $def) = @args;
    $text = join (':', "U$unitid", "O$propid", "X$aut", "X$def");
  }
  #
  # 46 : Création d'une fonction
  #
  elsif ($opcode == 46) {
    my @left = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', @left);
  }
  #
  # 47 : Modification d'une fonction.
  #
  elsif ($opcode == 47) {
    my @left = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', @left);
  }
  #
  # 48 : Suppression d'une fonction EPFL
  #
  elsif ($opcode == 48) {
    my @left = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', @left);
  }
  #
  # 49 : Demande d'approbation d'une action
  # 50 : Approbation d'une action
  # 51 : Refus d'une action
  # 52 : Action approuvée
  # 53 : Action refusée
  #
  elsif (($opcode >= 49) && ($opcode <= 53)) {
    my ($wobjtype, $wobjid, $unitid, $recipid) = @args;
    $wobjid = ($wobjtype eq 'Right') ? "D$wobjid" : "R$wobjid";
    $text = join (':', "X$wobjtype", $wobjid, "U$unitid", "P$recipid");
  }
  #
  # 51 : Approbation d'obtention de droit
  # 52 : Approbation de revocation de droit
  #
  elsif (($opcode == 51) || ($opcode == 52)) {
    my ($decision, $rightid, $recipid, $unitid) = @args;
    $text = join (':', "X$decision", "D$rightid", "P$recipid", "U$unitid");
  }
  #
  # Deputations
  #
  elsif ($opcode == 57) { # adddeputation
    my ($persid, $unitid, $roleid, $deputid, $cond, $datedeb, $datefin) = @args;
    $text = join (':',
      "P$persid", "U$unitid", "R$roleid", "P$deputid",
      "X$cond", "X$datedeb", "X$datefin");
  }
  elsif ($opcode == 58) { # moddeputation
    my ($persid, $roleid, $unitid, $deputid, @left) = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', "P$persid", "R$roleid", "U$unitid", "P$deputid", @left);
  }
  elsif ($opcode == 59) { # remdeputation
    my ($id, $persid, $unitid, $roleid, $deputid, $cond, $datedeb, $datefin, @left) = @args;
    $text = join (':',
      "X$id", "P$persid", "U$unitid", "R$roleid", "P$deputid",
      "X$cond", "X$datedeb", "X$datefin");
  }
  #
  # Autres.
  #
  else {
    my @left = @args;
    map { $_ = "X$_" } @left;
    $text = join (':', @left);
  }
  return ":$text:";
}


sub parsetext {
  my ($self, $text) = @_;
  $text =~ s/^:(.*):$/$1/;
  my @args = split (':', $text);
  map { s/^.// } @args;
  return @args;
}

sub getActions {
  my ($self, $action, $unitid, $persid) = @_;
  my $sep = 'where';
  my $sql = qq{
    select date,
           opcode,
           persid,
           text
      from $logstable
  };
  my @values;
  if ($action) {
    $sql .= qq{ $sep opcode = ?};
    push (@values, $action);
    $sep  = 'and';
  }
  if ($persid) {
    $sql .= qq{
      $sep (text like ?
         or text like ?
         or text like ?)
    };
    push (@values, "$persid:%", "%:$persid:%", "%:$persid");
    $sep  = 'and';
  }
  if ($unitid) {
    $sql .= qq{
      $sep (text like ?
         or text like ?
         or text like ?)
    };
    push (@values, "$unitid:%", "%:$unitid:%", "%:$unitid");
    $sep  = 'and';
  }
  $sql .= qq{ order by date desc};
  my $sth = $self->{accreddb}->dbsafequery ($sql, @values) or return;

  my @logs;
  while (my $log = $sth->fetchrow_hashref) {
    push (@logs, $log);
  }
  $sth->finish;
  return @logs;
}

sub getActionsInUnit {
  my ($self, $unitid, $ndays) = @_;
  importmodules ($self, 'Units');
  my ($actions, $counts);
  my @descendants = $self->{units}->listDescendantsIds ($unitid);
  foreach my $uid ($unitid, @descendants) {
    my $sql = qq{
      select date,
           opcode,
           persid,
           text
        from $logstable
       where text like ?
         and to_days(date) > to_days(now()) - $ndays
       order by date desc
    };
    my $sth = $self->{accreddb}->dbsafequery ($sql, "%:$uid:%");
    next unless $sth;;
    while (my $action = $sth->fetchrow_hashref) {
      next if ($action->{opcode} == 33);
      my $author = $action->{persid};
      $counts->{$author}++;
      push (@{$actions->{$author}}, {
          opcode => $action->{opcode},
            unit => $unitid,
      });
    }
    $sth->finish;
  }
  return ($actions, $counts);
}

sub getPersActionsUnUnits {
  my ($self, $persid, $unitids, $ndays) = @_;
  my @actions;
  foreach my $unitid (@$unitids) {
    my $sql = qq{
      select date,
             opcode,
             persid,
             text
        from $logstable
       where persid  = ?
         and text like ?
         and to_days(date) > to_days(now()) - $ndays
       order by date desc
    };
    my $sth = $self->{accreddb}->dbsafequery ($sql, $persid, "%:$unitid:%") or next;
    while (my $action = $sth->fetchrow_hashref) {
      next if ($action->{opcode} == 33);
      push (@actions, { opcode => $action->{opcode}, unit => $unitid });
    }
    $sth->finish;
  }
  return @actions;
}

sub viewlogentry {
  my ($self, $logentry) = @_;
  importmodules ($self,
    'Accreds', 'Persons', 'Units', 'Positions', 'RightsAdmin', 'RolesAdmin',
    'PropsAdmin', 'Workflows'
  );
  my $options = { @_ };
  my    $date = $logentry->{date};
  my  $opcode = $logentry->{opcode};
  my    @args = @{$logentry->{args}};
  my  $persid = $logentry->{persid};
  my    $lang = $self->{lang} || 'en';
  my $oplabel = $self->getop ($opcode)->{$lang};
  my $author;
  
  if ($options->{author}) {
    if ($persid eq '000000') {
      $author = 'Auto';
    } else {
      my $pers = $self->{persons}->getPerson ($persid);
      $author = $pers->{name};
    }
  }
  my ($year, $month, $day, $hour, $min, $sec) =
      ($date =~ /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/);

  use Time::Local;
  my $bindate = timelocal ($sec, $min, $hour, $day, $month - 1, $year);
  my $strdate = ($lang eq 'fr')
    ? sprintf ("%d %s %d %02d:%02d", $day, $frmonthnames [$month - 1], $year, $hour, $min)
    : sprintf ("%s %d %d %02d:%02d", $enmonthnames [$month - 1], $day, $year, $hour, $min)
    ;
  my $viewaction = "$self->{me}/viewaction".
    "?date=$date".
    "&opcode=$opcode".
    "&persid=$persid".
    "&text=$logentry->{text}"
    ;
  print qq{
    <tr>
      <td style="text-align: right;">
        $author
      </td>
  } if $author;
  print qq{
      <td style="width: 150px; text-align: right;">
        $strdate
      </td>
  };
  print qq{
      <td>
        $oplabel
      </td>
    } unless $options->{noop};
  
  my $tdclasses = {
     1 => 'subtable',
     2 => 'modiftable',
     3 => 'subtable',
     4 => 'subtable',
     5 => 'subtable',
     6 => 'subtable',
     7 => 'subtable',
     8 => 'subtable',
     9 => 'subtable',
    10 => 'subtable',
    11 => 'subtable',
    12 => 'subtable',
    13 => 'subtable',
    14 => 'subtable',
    15 => 'subtable',
    16 => 'subtable',
    17 => 'subtable',
    18 => 'subtable',
    19 => 'subtable',
    23 => 'subtable',
    24 => 'subtable',
    25 => 'subtable',
    26 => 'subtable',
    27 => 'subtable',
    28 => 'subtable',
    29 => 'subtable',
    30 => 'subtable',
    31 => 'modiftable',
    32 => 'subtable',
    33 => 'subtable',
    34 => 'subtable',
    35 => 'subtable',
    36 => 'subtable',
    37 => 'subtable',
    38 => 'modiftable',
    43 => 'modiftable',
    44 => 'modiftable',
    46 => 'subtable',
    47 => 'modiftable',
    48 => 'subtable',
    49 => 'subtable',
    50 => 'subtable',
    51 => 'subtable',
    52 => 'subtable',
    53 => 'subtable',
    57 => 'subtable',
    58 => 'modiftable',
    59 => 'subtable',
  };
  print qq{
    <td id="$tdclasses->{$opcode}">
  };
  $self->viewlogdetails ($logentry, $options);
  print qq{
    </td>
  };
  print qq{
    </tr>
  };
}

sub viewlogdetails {
  my ($self, $logentry, $options) = @_;
  importmodules ($self,
    'Accreds', 'Persons', 'Units', 'Positions', 'RightsAdmin', 'RolesAdmin',
    'PropsAdmin', 'Workflows'
  );
  my    $lang = $self->{lang} || 'en';
  my    $date = $logentry->{date};
  my  $opcode = $logentry->{opcode};
  my    @args = @{$logentry->{args}};
  my  $persid = $logentry->{persid};
  my $oplabel = $self->getop ($opcode)->{$lang};
  
  my ($year, $month, $day, $hour, $min, $sec) =
      ($date =~ /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/);
  use Time::Local;
  my $bindate = timelocal ($sec, $min, $hour, $day, $month - 1, $year);

  my $viewaction = "$self->{me}/viewaction".
    "?date=$date".
    "&opcode=$opcode".
    "&persid=$persid".
    "&text=$logentry->{text}"
    ;
  #
  #  1 : Ajout d'une accréditation
  # 33 : Modification d'une accréditation (ancienne version)
  #  3 : Suppression d'une accréditation
  #
  if (($opcode ==  1) || ($opcode ==  33) || ($opcode ==  3)) {
    my ($persid, $unitid) = @args;
    my $unit = $self->{units}->getUnit ($unitid);
    my $pers = ($persid eq '000000')
      ? { name => 'Auto', }
      : $self->{persons}->getPerson ($persid);
    if ($options->{short}) {
      print qq{
        <a onclick="loadcontent ('$viewaction');">
          $unit->{name}, $pers->{name}
        </a>
      };
    } else {
      print qq{
        <table>
          <tr>
            <th> }.msg('Unit').qq{ </th>
            <td> $unit->{name} </td>
          </tr>
          <tr>
            <th align="right"> }.msg('PersonId').qq{ </th>
            <td> $pers->{name} ($persid) </td>
          </tr>
        </table>
      };
    }
  }
  #
  # 2 : Modification d'une accréditation (nouvelle version)
  #
  elsif ($opcode ==  2) {
    my ($persid, $unitid, @modifs) = @args;
    my   $unit = $self->{units}->getUnit ($unitid);
    my   $pers = ($persid eq '000000')
      ? { name => 'Auto', }
      : $self->{persons}->getPerson ($persid);
    my $pname = $pers->{name};
    my $uname = $unit->{name};
    if ($options->{short}) {
      print qq{
        <a onclick="loadcontent ('$viewaction');">
          $unit->{name}, $pers->{name}
        </a>
      };
    } else {
      print qq{
        }.msg('For').qq{ <b>$pname ($persid)</b>
        }.msg('In') .qq{ <b>$uname</b>
        <p>
        <table class="view" border>
          <tr align="center">
            <th> }.msg('ModifiedField').qq{  </th>
            <th style="text-align: center;"> }.msg('OldValue').qq{ </th>
            <th style="text-align: center;"> }.msg('NewValue').qq{ </th>
          </tr>
      };
      for (my $i = 0; $i < $#modifs; $i += 3) {
        my  $field = $modifs [$i];
        my $oldval = $self->getlabel ($field, $lang, $modifs [$i + 1], $unitid) || msg('Nothing');
        my $newval = $self->getlabel ($field, $lang, $modifs [$i + 2], $unitid) || msg('Nothing');
        next if ($oldval eq $newval);
        print qq{
          <tr align="center">
            <th style="text-align: right"> $field  </th>
            <td> $oldval </td>
            <td> $newval </td>
          </tr>
        };
      }
      print qq{
        </table>
      };
    }
  }
  #
  # 4 : Ajout d'une personne
  # 5 : Modification d'une personne
  #
  elsif (($opcode ==  4) || ($opcode ==  5)){
    my ($firstname, $surname, $birthdate, $gender,
        $firstnameus, $surnameus, $persid);
    if ($opcode ==  4) {
      ($firstname, $surname, $birthdate, $gender, $firstnameus,
       $surnameus, $persid) = @args;
    } else {
      ($persid, $firstname, $surname, $birthdate, $gender,
        $firstnameus, $surnameus) = @args;
    }
    $gender = ($gender eq 'M') ? "Homme" : "Femme";
    print qq{
      <table>
        <tr>
          <th align="right" width="120"> }.msg('Name').qq{ </th>
          <td> $surname </td>
        </tr>
        <tr>
          <th align="right"> }.msg('Firstname').qq{ </th>
          <td> $firstname </td>
        </tr>
        <tr>
          <th align="right"> }.msg('BirthDate').qq{ </th>
          <td> $birthdate </td>
        </tr>
        <tr>
          <th align="right"> }.msg('Gender').qq{ </th>
          <td> $gender </td>
        </tr>
        <tr>
          <th align="right"> }.msg('PersonId').qq{ </th>
          <td> $persid </td>
        </tr>
      </table>
    };
  }
  #
  # 6 : Modification des droits aux prestations d'une unité
  #
  elsif ($opcode ==  6) {
    my ($unitid, $rights) = @args;
    my  $unit = $self->{units}->getUnit ($unitid);
    print qq{
      }.msg('Unit').qq{ <b>$unit->{name}</b><br>
      <table class="view" border>
        <tr>
          <th> }.msg('Prestation')     .qq{ </th>
          <th> }.msg('Allowed')        .qq{ </th>
          <th> }.msg('GivenByDefault') .qq{ </th>
        </tr>
    };
    $rights =~ s/^\[(.*)\]$/$1/;
    my @rights = split (/\]\[/, $rights);
    foreach (@rights) {
      my ($prest, $right, $defaut) = m/^(.*), (.*), (.*)$/;
      $right  = $right  == 0 ? msg('No') : $right == 1 ? msg('Yes') : msg('Inherited');
      $defaut = $defaut == 0 ? msg('No') : $right == 1 ? msg('Yes') : msg('Inherited');
      print qq{
        <tr>
          <td align="center"> $prest  </td>
          <td align="center"> $right  </td>
          <td align="center"> $defaut </td>
        </tr>
      };
    }
    print qq{
      </table>
    };
  }
  #
  # 7 : Modification d'une prestation
  #
  elsif ($opcode ==  7) {
    my ($prest, $namep, $type, $desc, $email, $respid, $active) = @args;
    my $respname = 'Unknown';
    if ($respid) {
      my $resp = ($respid eq '000000')
        ? { name => 'Auto', }
        : $self->{persons}->getPerson ($respid);
      $respname = $resp->{name} if $resp;
    }
    my $status = $active ? msg('Yes') : msg('No');
    my  %types = (M => 'Mail', S=> 'Special');
    my  $stype = $types {$type};

    print qq{
      <table>
        <tr>
          <th align="right" width="120"> }.msg('Name').qq{ </th>
          <td> $prest </td>
        </tr>
        <tr>
          <th align="right"> }.msg('Label').qq{ </th>
          <td> $namep </td>
        </tr>
        <tr>
          <th align="right"> Type </th>
          <td> $stype </td>
        </tr>
        <tr>
          <th align="right"> }.msg('Description').qq{ </th>
          <td> $desc </td>
        </tr>
        <tr>
          <th align="right"> Email </th>
          <td> $email </td>
        </tr>
        <tr>
          <th align="right"> }.msg('Manager').qq{ </th>
          <td> $respname </td>
        </tr>
        <tr>
          <th align="right"> Active </th>
          <td> $status </td>
        </tr>
      </table>
    };
  }
  #
  # 8, 23 : Création de l'account
  #
  elsif ($opcode ==  8 || $opcode == 23) {
    my ($persid, $password, $imap, $mailbox, $prestid) = @args;
    my $pers = ($persid eq '000000')
      ? { name => 'Auto', }
      : $self->{persons}->getPerson ($persid);
    $password = '******';

    print qq{
      <table>
        <tr>
          <th> }.msg('PersonId').qq{ </th>
          <td> $persid ($pers->{name}) </td>
        </tr>
        <tr>
          <th> }.msg('Password').qq{ </th>
          <td> $password </td>
        </tr>
        <tr>
          <th> }.msg('IMAPAccount').qq{ </th>
          <td> $imap       </td>
        </tr>
        <tr>
          <th> }.msg('MailBox').qq{ </th>
          <td> $mailbox </td>
        </tr>
      </table>
    };
  }
  #
  # 9 : Modification de l'ordre des accreds d'une personne
  #
  elsif ($opcode == 9) {
    my ($persid, @unitids) = @args;
    my  $pers = ($persid eq '000000')
      ? { name => 'Auto', }
      : $self->{persons}->getPerson  ($persid);
    my     $units = $self->{units}->getUnits (\@unitids);
    my @unitnames = map { $units->{$_}->{name} } @unitids;
    my $unitslist = join (', ', @unitnames);
    if ($options->{short}) {
      print qq{
        <a onclick="loadcontent ('$viewaction');">
          $pers->{name}
        </a>
      };
    } else {
      print qq{
        <table>
          <tr>
            <th> }.msg('PersonId').qq{ </th>
            <td> $persid ($pers->{name}) </td>
          </tr>
          <tr>
            <th> New order </th>
            <td> $unitslist </td>
          </tr>
        </table>
      };
    }
  }
  #
  # 10 : Modification de fonctions EHE
  #
  elsif ($opcode == 10) {
    my ($unitid, $rights) = @args;
    my  $unit = $self->{units}->getUnit ($unitid);
    $rights =~ s/^\[//;
    $rights =~ s/\][^\]]*$//;
    my @rights = split (/\]\[/, $rights);
    print qq{
      }.msg('Unit').qq{ <b>$unit->{name}</b>
      <br>
      <table>
        <tr>
          <th>
            }.msg('Position').qq{
          </th>
          <th>
            }.msg('Access').qq{
          </th>
        </tr>
    };
    foreach (@rights) {
      my ($posid, $rightid) = m/^(.*) (.)$/;
      my $position = $self->{positions}->getPosition ($posid);
      my   $poslib = $position ? $position->{labelfr} : $posid;
      my   $origin = $origines->{$rightid}->{$lang};
      print qq{
        <tr>
          <td> $poslib </td>
          <td> $origin </td>
        </tr>
      };
    }
    print qq{
      </table>
    };
  }
  #
  # 11 : Création d'une fonction EHE
  # 12 : Suppression d'une fonction EHE
  #
  elsif ($opcode == 11 || $opcode == 12) {
    my $position = shift @args;
    print qq{
      <table>
        <tr>
          <th>
            }.msg('Position').qq{
          </th>
          <td>
            $position
          </td>
        </tr>
      </table>
    };
  }
  #
  # 13 : Revalidation d'une accréditation
  #
  elsif ($opcode == 13) {
    my ($persid, $unitid) = @args;
    my  $unit = $self->{units}->getUnit ($unitid);
    my  $pers = ($persid eq '000000')
      ? { name => 'Auto', }
      : $self->{persons}->getPerson ($persid);
    if ($options->{short}) {
      print qq{
        <a onclick="loadcontent ('$viewaction');">
          $unit->{name}, $pers->{name}
        </a>
      };
    } else {
      print qq{
        <table>
          <tr>
            <th align="right" width="120">
              }.msg('PersonId').qq{
            </th>
            <td>
              $persid ($pers->{name})
            </td>
          </tr>
          <tr>
            <th align="right"> }.msg('Unit').qq{ </th>
            <td> $unit->{name} </td>
          </tr>
        </table>
      };
    }
  }
  #
  # 14 : Ajout d'un rôle
  # 15 : Modification d'un rôle
  #
  elsif ($opcode == 14 || $opcode == 15) {
    my ($name, $lib, $desc, $list) = @args;
    print qq{
        <table>
          <tr>
            <th width="120"> }.msg('Name').qq{ </th>
            <td> $name </td>
          </tr>
          <tr>
            <th> }.msg('Label').qq{ </th>
            <td> $lib </td>
          </tr>
          <tr>
            <th> }.msg('Description').qq{ </th>
            <td> $desc </td>
          </tr>
          <tr>
            <th> }.msg('List').qq{ </th>
            <td> $list </td>
          </tr>
        </table>
    };
  }
  #
  # 16 : Suppression d'un rôle
  #
  elsif ($opcode == 16) {
    my ($name) = @args;
    print qq{
      <table>
        <tr>
          <th align="right" width="120">
            }.msg('Name').qq{
          </th>
          <td> $name </td>
        </tr>
      </table>
    };
  }
  #
  # 17 : Ajout d'un nouveau droit
  # 18 : Modification d'un droit
  #
  elsif ($opcode == 17 || $opcode == 18) {
    my ($name, $lib, $desc) = @args;
    print qq{
      <table>
        <tr>
          <th width="120"> }.msg('Name').qq{ </th>
          <td> $name </td>
        </tr>
        <tr>
          <th> }.msg('Label').qq{ </th>
          <td> $lib   </td>
        </tr>
        <tr>
          <th> }.msg('Description').qq{ </th>
          <td> $desc       </td>
        </tr>
      </table>
    };
  }
  #
  # 19 : Suppression d'un droit
  #
  elsif ($opcode == 19) {
    my ($name) = @args;
    print qq{
      <table>
        <tr>
          <th width="120"> }.msg('Name').qq{ </th>
          <td> $name </td>
        </tr>
      </table>
    };
  }
  #
  # 20 : Obsolète
  # 21 : Pas implémenté.
  # 22 : Pas implémenté.
  #
  #
  # 24 : Modification des rôles d'une personne.
  #
  elsif ($opcode == 24) {
    my ($roleid, $persid, $unitid, $newval) = @args;
    my    $unit = $self->{units}->getUnit     ($unitid);
    my    $pers = ($persid eq '000000')
      ? { name => 'Auto', }
      : $self->{persons}->getPerson ($persid);
    my    $role = $self->{rolesadmin}->getRole ($roleid, $bindate);
    my $rolelib = $role ? $role->{labelfr} : msg('Unknown');
    my $val = ($newval eq 'y') ? msg('Yes') : msg('No');
    if ($options->{short}) {
      print qq{
        <a onclick="loadcontent ('$viewaction');">
          $rolelib, $unit->{name}, $pers->{name}
        </a>
      };
    } else {
      print qq{
        <table>
          <tr>
            <th align="right" width="120"> }.msg('Role').qq{ </th>
            <td> $rolelib </td>
          </tr>
          <tr>
            <th align="right"> }.msg('PersonId').qq{ </th>
            <td> $persid ($pers->{name})</td>
          </tr>
          <tr>
            <th align="right"> }.msg('Unit').qq{ </th>
            <td> $unit->{name} </td>
          </tr>
          <tr>
            <th align="right"> }.msg('Value').qq{ </th>
            <td> $val </td>
          </tr>
        </table>
      };
    }
  }
  #
  # 25 : Suppression d'un rôle à une personne.
  #
  elsif ($opcode == 25) {
    my ($roleid, $persid, $unitid) = @args;
    my    $unit = $self->{units}->getUnit     ($unitid);
    my    $pers = ($persid eq '000000')
      ? { name => 'Auto', }
      : $self->{persons}->getPerson ($persid);
    my    $role = $self->{rolesadmin}->getRole ($roleid, $bindate);
    my $rolelib = $role ? $role->{labelfr} : 'Inconnu';
    if ($options->{short}) {
      print qq{
        <a onclick="loadcontent ('$viewaction');">
          $rolelib, $unit->{name}, $pers->{name}
        </a>
      };
    } else {
      print qq{
        <table>
          <tr>
            <th width="120"> }.msg('Role').qq{ </th>
            <td> $rolelib </td>
          </tr>
          <tr>
            <th> }.msg('PersonId').qq{ </th>
            <td> $persid ($pers->{name}) </td>
          </tr>
          <tr>
            <th> }.msg('Unit').qq{   </th>
            <td> $unit->{name} </td>
          </tr>
        </table>
      };
    }
  }
  #
  # 26 : Modification des droits d'une personne.
  #
  elsif ($opcode == 26) {
    my ($rightid, $persid, $unitid, $newval) = @args;
    my     $unit = $self->{units}->getUnit     ($unitid);
    my     $pers = ($persid eq '000000')
      ? { name => 'Auto', }
      : $self->{persons}->getPerson ($persid);
    my    $right = $self->{rightsadmin}->getRight ($rightid, $bindate);
    my $rightlib = $right ? $right->{labelfr} : msg('Unknown');
    my      $val = ($newval eq 'y') ? msg('Yes') : msg('No');
    if ($options->{short}) {
      print qq{
        <a onclick="loadcontent ('$viewaction');">
          $rightlib, $unit->{name}, $pers->{name}
        </a>
      };
    } else {
      print qq{
        <table>
          <tr>
            <th> }.msg('Right').qq{ </th>
            <td> $rightlib </td>
          </tr>
          <tr>
            <th> }.msg('PersonId').qq{ </th>
            <td> $persid ($pers->{name}) </td>
          </tr>
          <tr>
            <th> }.msg('Unit').qq{   </th>
            <td> $unit->{name} </td>
          </tr>
          <tr>
            <th> }.msg('Value').qq{ </th>
            <td> $val   </td>
          </tr>
        </table>
      };
    }
  }
  #
  # 27 : Suppression d'un droit à une personne.
  #
  elsif ($opcode == 27) {
    my ($rightid, $persid, $unitid) = @args;
    my     $unit = $self->{units}->getUnit     ($unitid);
    my     $pers = ($persid eq '000000')
      ? { name => 'Auto', }
      : $self->{persons}->getPerson ($persid);
    my    $right = $self->{rightsadmin}->getRight ($rightid, $bindate);
    my $rightlib = $right ? $right->{labelfr} : msg('Unknown');
    if ($options->{short}) {
      print qq{
        <a onclick="loadcontent ('$viewaction');">
          $rightlib, $unit->{name}, $pers->{name}
        </a>
      };
    } else {
      print qq{
        <table>
          <tr>
            <th> }.msg('Right').qq{ </th>
            <td> $rightlib </td>
          </tr>
          <tr>
            <th> }.msg('PersonId').qq{ </th>
            <td> $persid </td>
          </tr>
          <tr>
            <th> }.msg('Name').qq{ </th>
            <td> $pers->{name} </td>
          </tr>
          <tr>
            <th>  }.msg('Unit').qq{  </th>
            <td> $unit->{name} </td>
          </tr>
        </table>
      };
    }
  }
  #
  # 28 : Modification des droits d'une unité
  #
  elsif ($opcode == 28) {
    my ($rightid, $unitid, $newval) = @args;
    my     $unit = $self->{units}->getUnit ($unitid);
    my    $right = $self->{rightsadmin}->getRight ($rightid, $bindate);
    my $rightlib = $right ? $right->{labelfr} : msg('Unknown');
    my      $val = ($newval eq 'y') ? msg('Yes') : msg('No');
    print qq{
      <table>
        <tr>
          <th> }.msg('Right').qq{   </th>
          <td> $rightlib </td>
        </tr>
        <tr>
          <th> }.msg('Unit').qq{   </th>
          <td> $unit->{name} </td>
        </tr>
        <tr>
          <th> }.msg('Value').qq{ </th>
          <td> $val   </td>
        </tr>
      </table>
    };
  }
  #
  # 29 : Suppression d'un droit à une unité.
  #
  elsif ($opcode == 29) {
    my ($rightid, $unitid) = @args;
    my     $unit = $self->{units}->getUnit ($unitid);
    my    $right = $self->{rightsadmin}->getRight ($rightid, $bindate);
    my $rightlib = $right ? $right->{labelfr} : 'Inconnu';
    print qq{
      <table>
        <tr>
          <th> }.msg('Right').qq{   </th>
          <td> $rightlib </td>
        </tr>
        <tr>
          <th> }.msg('Unit').qq{ </th>
          <td> $unit->{name} </td>
        </tr>
      </table>
    };
  }
  #
  # 30 : Création de fonctions EPFL
  #
  elsif ($opcode == 30) {
    my ($labelfr, $labelxx, $labelen, $policy) = @args;
    print qq{
      <table>
        <tr>
          <th> }.msg('Label').qq{ </th>
          <td> $labelfr </td>
        </tr>
        <tr>
          <th> }.msg('FeminineLabel').qq{ </th>
          <td> $labelxx </td>
        </tr>
        <tr>
          <th> }.msg('EnglishLabel').qq{ </th>
          <td> $labelen </td>
        </tr>
        <tr>
          <th> }.msg('Policy').qq{  </th>
          <td> $policy </td>
        </tr>
      </table>
    };
  }
  #
  # 31 : Modification d'une fonction EPFL
  #
  elsif ($opcode == 31) {
    my ($posid, @modifs) = @args;
    my $position = $self->{positions}->getPosition ($posid);
    my   $poslib = $position ? $position->{labelfr} : $posid;
    print qq{
      Fonction : <b> $poslib </b> <br>
      <table>
        <tr>
          <th>
            }.msg('ModifiedField').qq{
          </th>
          <th>
            }.msg('OldValue').qq{
          </th>
          <th>
            }.msg('NewValue').qq{
          </th>
        </tr>
    };
    for (my $i = 0; $i < $#modifs; $i += 3) {
      my  $field = $modifs [$i];
      my $oldval = $self->getlabel ($field, $lang, $modifs [$i + 1]);
      my $newval = $self->getlabel ($field, $lang, $modifs [$i + 2]);
      print qq{
        <tr>
          <td> $field  </td>
          <td> $oldval </td>
          <td> $newval </td>
        </tr>
      };
    }
    print qq{
      </table>
    };
  }
  #
  # 32 : Suppression d'une fonction EPFL
  #
  elsif ($opcode == 32) {
    my ($position) = @args;
    print qq{
      <table>
        <tr>
          <th>
            }.msg('Position').qq{
          </th>
          <td>
            $position
          </td>
        </tr>
      </table>
    };
  }
  #
  # 34 : Ajout d'un privilège droit à un accréditeur
  # 35 : Suppression d'un privilège droit à un accréditeur
  #
  elsif ($opcode == 34 || $opcode == 35) {
    my ($persid, $unitid, $rightid) = @args;
    my     $unit = $self->{units}->getUnit     ($unitid);
    my     $pers = ($persid eq '000000')
      ? { name => 'Auto', }
      : $self->{persons}->getPerson ($persid);
    my    $right = $self->{rightsadmin}->getRight ($rightid, $bindate);
    my $rightlib = $right ? $right->{labelfr} : msg('Unknown');
    print qq{
      <table>
        <tr>
          <th> }.msg('People').qq{ </th>
          <td> $pers->{name} </td>
        </tr>
        <tr>
          <th> }.msg('Right').qq{ </th>
          <td> $rightlib </td>
        </tr>
        <tr>
          <th> }.msg('Unit').qq{ </th>
          <td> $unit->{name} </td>
        </tr>
      </table>
    };
  }
  #
  # 36 : Ajout d'un privilège rôle à un accréditeur
  # 37 : Suppression d'un privilège rôle à un accréditeur
  #
  elsif ($opcode == 36 || $opcode == 37) {
    my ($persid, $unitid, $roleid) = @args;
    my    $unit = $self->{units}->getUnit     ($unitid);
    my    $pers = ($persid eq '000000')
      ? { name => 'Auto', }
      : $self->{persons}->getPerson ($persid);
    my    $role = $self->{rolesadmin}->getRole ($roleid, $bindate);
    my $rolelib = $role ? $role->{labelfr} : 'Inconnu';
    print qq{
      <table>
        <tr>
          <th>
            }.msg('People').qq{
          </th>
          <td>
            $pers->{name}
          </td>
        </tr>
        <tr>
          <th>
            }.msg('Role').qq{
          </th>
          <td>
            $rolelib
          </td>
        </tr>
        <tr>
          <th>
            }.msg('Unit').qq{
          </th>
          <td>
            $unit->{name}
          </td>
        </tr>
      </table>
    };
  }
  #
  # 38 : Modification d'une fonction EHE
  #
  elsif ($opcode == 38) {
    my ($id, $oldlib, $newlib);
    if (@args == 3) {
      ($id, $oldlib, $newlib) = @args;
    } else {
      ($id, $oldlib, $newlib) = (msg('Unknown'), msg('Unknowne'), shift @args);
    }
    print qq{
      <table>
        <tr>
          <th> Id </th>
          <th> }.msg('OldValue').qq{ </th>
          <th> }.msg('NewValue').qq{ </th>
        </tr>
        <tr>
          <td> $id     </td>
          <td> $oldlib </td>
          <td> $newlib </td>
        </tr>
      </table>
    };
  }
  #
  # 43 : Modification d'une propriété d'une accréditation
  #
  elsif ($opcode == 43) { # setaccprop
    my ($persid, $unitid, @modifs) = @args;
    my   $pers = ($persid eq '000000')
      ? { name => 'Auto', }
      : $self->{persons}->getPerson ($persid);
    my   $unit = $self->{units}->getUnit     ($unitid);
    my $labels = {
      'y' => msg('Yes'),
        d => msg('Default'),
        n => msg('No'),
    };
    print qq{
      }.msg('Unit').qq{ : $unit->{name},
      }.msg('Person').qq{ : $pers->{name}
      <table>
        <tr>
          <th> }.msg('Property').qq{ </th>
          <th> }.msg('OldValue').qq{ </th>
          <th> }.msg('NewValue').qq{ </th>
        </tr>
      };
      for (my $i = 0; $i < $#modifs; $i += 3) {
        my   $propid = $modifs [$i];
        my   $oldval = $modifs [$i + 1];
        my   $newval = $modifs [$i + 2];
        my $property = $self->{propsadmin}->getProperty ($propid);
        print qq{
          <tr>
            <th> $property->{labelfr} </th>
            <td> $labels->{$oldval}   </td>
            <td> $labels->{$newval}   </td>
          </tr>
       };
      }
    print qq{
      </table>
    };
  }
  #
  # 44 : Modification d'une propriété d'une unité
  #
  elsif ($opcode == 44) { # setunitprop
    my ($unitid, $propid, $aut, $def) = @args;
    my  $unit = $self->{units}->getUnit ($unitid);
    my $uname = $unit->{name} || 'Unknown';
    my $property = $self->{propsadmin}->getProperty ($propid);
    my $labels = {
      'y' => msg('Yes'),
        d => msg('Default'),
        n => msg('No'),
    };
    print qq{
      }.msg('Unit').qq{ : $unit->{name}
      <table>
        <tr>
          <th>
            }.msg('Unit').qq{
          </th>
          <th>
            }.msg('Property').qq{
          </th>
          <th>
            }.msg('Authorized').qq{
          </th>
          <th>
            }.msg('SetByDefault').qq{
          </th>
        </tr>
        <tr>
          <th> $uname               </th>
          <td> $property->{labelfr} </td>
          <td> $labels->{$aut}      </td>
          <td> $labels->{$def}      </td>
        </tr>
      </table>
    };
  }
  #
  # 46 : Création d'une fonction
  #
  elsif ($opcode == 46) {
    my ($labelfr, $labelxx, $labelen, $policy) = @args;
    print qq{
      <table>
        <tr>
          <th> }.msg('Label').qq{ </th>
          <td> $labelfr </td>
        </tr>
        <tr>
          <th> }.msg('FeminineLabel').qq{ </th>
          <td> $labelxx </td>
        </tr>
        <tr>
          <th> }.msg('EnglishLabel').qq{ </th>
          <td> $labelen </td>
        </tr>
        <tr>
          <th> }.msg('Policy').qq{  </th>
          <td> $policy </td>
        </tr>
      </table>
    };
  }
  #
  # 47 : Modification d'une fonction.
  #
  elsif ($opcode == 47) {
    my ($posid, @modifs) = @args;
    my $position = $self->{positions}->getPosition ($posid);
    my   $poslib = $position ? $position->{labelfr} : $posid;
    print qq{
      Fonction : <b> $poslib </b> <br>
      <table>
        <tr>
          <th>
            }.msg('ModifiedField').qq{
          </th>
          <th>
            }.msg('OldValue').qq{
          </th>
          <th>
            }.msg('NewValue').qq{
          </th>
        </tr>
    };
    for (my $i = 0; $i < $#modifs; $i += 3) {
      my  $field = $modifs [$i];
      my $oldval = $self->getlabel ($field, $lang, $modifs [$i + 1]);
      my $newval = $self->getlabel ($field, $lang, $modifs [$i + 2]);
      print qq{
        <tr>
          <td> $field  </td>
          <td> $oldval </td>
          <td> $newval </td>
        </tr>
      };
    }
    print qq{
      </table>
    };
  }
  #
  # 48 : Suppression d'une fonction EPFL
  #
  elsif ($opcode == 48) {
    my ($position) = @args;
    print qq{
      <table>
        <tr>
          <th>
            }.msg('Position').qq{
          </th>
          <td>
            $position
          </td>
        </tr>
      </table>
    };
  }
  #
  # 49 : Demande d'approbation d'une action
  # 50 : Approbation d'une action
  # 51 : Refus d'une action
  # 52 : Action approuvée
  # 53 : Action refusée
  #
  elsif (($opcode >= 49) && ($opcode <= 53)) {
    my ($wobjtype, $wobjid, $unitid, $recipid) = @args;
    my $object = $self->{workflows}->getObject ($wobjtype, $wobjid);
    my  $recip = ($recipid eq '000000')
      ? { name => 'Auto', }
      : $self->{persons}->getPerson ($recipid);
    my  $rname = $recip->{name} || $recipid;
    my   $unit = $self->{units}->getUnit ($unitid);
    my  $uname = $unit->{name} || $unitid;

    print qq{
      <table>
        <tr>
          <th> }.msg('Object').qq{ </th>
          <td> $object->{label} </td>
        </tr>
        <tr>
          <th> }.msg('PersonId').qq{ </th>
          <td> $recipid </td>
        </tr>
        <tr>
          <th> }.msg('Person').qq{ </th>
          <td> $rname </td>
        </tr>
        <tr>
          <th> }.msg('Unit').qq{  </th>
          <td> $uname </td>
        </tr>
      </table>
    };
  }
  #
  # 51 : Approbation d'obtention de droit
  # 52 : Approbation de revocation de droit
  #
  elsif (($opcode == 51) || ($opcode == 52)) {
    my ($decision, $rightid, $recipid, $unitid) = @args;
    my    $right = $self->{rightsadmin}->getRight ($rightid);
    my    $recip = ($recipid eq '000000')
      ? { name => 'Auto', }
      : $self->{persons}->getPerson ($recipid);
    my    $rname = $recip->{name} || $recipid;
    my     $unit = $self->{units}->getUnit ($unitid);
    my    $uname = $unit->{name} || $unitid;
    my $declabel = ($decision == 1) ? msg('ApprovedDecision') : msg('DeniedDecision');

    print qq{
      <table>
        <tr>
          <th> }.msg('Right').qq{ </th>
          <td> $right->{label} </td>
        </tr>
        <tr>
          <th> }.msg('PersonId').qq{ </th>
          <td> $recipid </td>
        </tr>
        <tr>
          <th> }.msg('Person').qq{ </th>
          <td> $rname </td>
        </tr>
        <tr>
          <th> }.msg('Unit').qq{  </th>
          <td> $uname </td>
        </tr>
        <tr>
          <th> }.msg('Decision').qq{ </th>
          <td> $declabel </td>
        </tr>
      </table>
    };
  }
  #
  # Deputations.
  #
  elsif ($opcode == 57) { # adddeputation
    my ($persid, $unitid, $roleid, $deputid, $cond, $datedeb, $datefin) = @args;
    my  $person = $self->{persons}->getPerson ($persid);
    my   $pname = $person->{name} || $persid;
    my    $role = $self->{rolesadmin}->getRole ($roleid);
    my   $rname = $role->{label} || "Role $roleid";
    my    $unit = $self->{units}->getUnit ($unitid);
    my   $uname = $unit->{name} || $unitid;
    my   $deput = $self->{persons}->getPerson ($deputid);
    my   $dname = $deput->{name} || $deputid;
    my $condlab = {
      w => 'When absent',
      d => 'Date range',
      p => 'Permanent',
    }->{$cond};
    
    print qq{
      <table>
        <tr>
          <th> }.msg('Person').qq{ </th>
          <td> $pname </td>
        </tr>
        <tr>
          <th> }.msg('Unit').qq{ </th>
          <td> $uname </td>
        </tr>
        <tr>
          <th> }.msg('Role').qq{ </th>
          <td> $rname </td>
        </tr>
        <tr>
          <th> }.msg('Deputy').qq{ </th>
          <td> $dname </td>
        </tr>
        <tr>
          <th> Condition  </th>
          <td> $condlab </td>
        </tr>
    };
    if ($cond eq 'd') {
      print qq{
        <tr>
          <th> }.msg('Datedeb').qq{ </th>
          <td> $datedeb </td>
        </tr>
        <tr>
          <th> }.msg('Datefin').qq{ </th>
          <td> $datefin </td>
        </tr>
      };
    }
    print qq{
      </table>
    };
  }
  elsif ($opcode == 58) { # moddeputation
    my ($persid, $roleid, $unitid, @modifs) = @args;
    my  $person = $self->{persons}->getPerson ($persid);
    my   $pname = $person->{name} || $persid;
    my    $role = $self->{rolesadmin}->getRole ($roleid);
    my   $rname = $role->{label} || "Role $roleid";
    my    $unit = $self->{units}->getUnit ($unitid);
    my   $uname = $unit->{name} || $unitid;
    my $condlabs = {
      w => 'When absent',
      d => 'Date range',
      p => 'Permanent',
    };
    my $fieldlabs = {
         cond => 'Condition',
      datedeb => msg('Datedeb'),
      datefin => msg('Datefin'),
    };
    
    print qq{
      }.msg('For')  .qq{ <b> $pname ($persid), </b>
      }.msg('Role') .qq{ <b> $rname </b>
      }.msg('In')   .qq{ <b> $uname </b>
      <p>
      <table class="view" border>
        <tr align="center">
          <th> }.msg('ModifiedField').qq{  </th>
          <th style="text-align: center;"> }.msg('OldValue').qq{ </th>
          <th style="text-align: center;"> }.msg('NewValue').qq{ </th>
        </tr>
    };
    for (my $i = 0; $i < $#modifs; $i += 3) {
      my $field = $modifs [$i];
      my $fieldlab = $fieldlabs->{$field} || 'Unknown';
      my   $old = $modifs [$i + 1] || msg('Nothing');
      my   $new = $modifs [$i + 2] || msg('Nothing');
      if ($field eq 'cond') {
        $old = $condlabs->{$old};
        $new = $condlabs->{$new};
      }
      print qq{
        <tr align="center">
          <th style="text-align: right;"> $fieldlab </th>
          <td> $old </td>
          <td> $new </td>
        </tr>
      };
    }
    print qq{
      </table>
    };
  }
  elsif ($opcode == 59) {
    my ($deputationid, $persid, $unitid, $roleid, $deputid, $cond, $datedeb, $datefin) = @args;
    my  $person = $self->{persons}->getPerson ($persid);
    my   $pname = $person->{name} || $persid;
    my    $role = $self->{rolesadmin}->getRole ($roleid);
    my   $rname = $role->{label} || "Role $roleid";
    my    $unit = $self->{units}->getUnit ($unitid);
    my   $uname = $unit->{name} || $unitid;
    my   $deput = $self->{persons}->getPerson ($deputid);
    my   $dname = $deput->{name} || $deputid;
    my $condlab = { w => 'When absent', d => 'Date range', p => 'Permanent' }->{$cond};

    print qq{
      <table>
        <tr>
          <th> }.msg('Person').qq{ </th>
          <td> $pname </td>
        </tr>
        <tr>
          <th> }.msg('Unit').qq{ </th>
          <td> $uname </td>
        </tr>
        <tr>
          <th> }.msg('Role').qq{ </th>
          <td> $rname </td>
        </tr>
        <tr>
          <th> }.msg('Deputy').qq{ </th>
          <td> $dname </td>
        </tr>
        <tr>
          <th> Condition  </th>
          <td> $condlab </td>
        </tr>
    };
    if ($cond eq 'd') {
      print qq{
        <tr>
          <th> }.msg('Datedeb').qq{ </th>
          <td> $datedeb </td>
        </tr>
        <tr>
          <th> }.msg('Datefin').qq{ </th>
          <td> $datefin </td>
        </tr>
      };
    }
    print qq{
      </table>
    };
  }
  #
  # Autres.
  #
  else {
    my $text = join (':', @args);
    print qq{$text\n};
  }
}

sub getop {
  my ($self, $opcode) = @_;
  return $loglabels->[$opcode] if ($opcode > 0 && $opcode <= $maxlogcode);
  return $loglabels->[0];
}

my $statuses;
sub getstatus {
  my ($self, $statusid) = @_;
  if ($statuses->{$statusid}) {
    return $statuses->{$statusid};
  } else {
    my $status = $self->{accreds}->getStatus ($statusid);
    $statuses->{$statusid} = $status;
    return $status;
  }
}

my $classes;
sub getclass {
  my ($self, $classid) = @_;
  if ($classes->{$classid}) {
    return $classes->{$classid};
  } else {
    my $class = $self->{accreds}->getClass ($classid);
    $classes->{$classid} = $class;
    return $class;
  }
}

my $positions;
sub getposition {
  my ($self, $posid) = @_;
  if ($positions->{$posid}) {
    return $positions->{$posid};
  } else {
    my $position = $self->{positions}->getPosition ($posid);
    $positions->{$posid} = $position;
    return $position
  }
}

my $roles;
sub getrole {
  my ($self, $roleid, $date) = @_;
  if ($roles->{$roleid}) {
    return $roles->{$roleid};
  } else {
    my $role = $self->{rolesadmin}->getRole ($roleid, $date);
    $roles->{$roleid} = $role;
    return $role;
  }
}

my $rights;
sub getright {
  my ($self, $rightid, $date) = @_;
  if ($rights->{$rightid}) {
    return $rights->{$rightid};
  } else {
    my $right = $self->{rightsadmin}->getRight ($rightid, $date);
    $rights->{$rightid} = $right;
    return $right;
  }
}

sub getduree {
  my ($self, $duree) = @_;
  return { fr =>   '1 an', en =>   '1 year' } if ($duree eq '1a');
  return { fr => '6 mois', en => '6 months' } if ($duree eq '6m');
  return { fr => '3 mois', en => '3 months' } if ($duree eq '3m');
  return { fr => '1 mois', en =>  '1 month' } if ($duree eq '1m');
}

sub getpolicy {
  my ($self, $policy) = @_;
  ($policy eq 'n') && return {
    labelfr => 'Restreint',
    labelen => 'Restricted',
  };
  return {
    labelfr => 'Libre',
    labelen => 'Open',
  };
}

sub getorigin {
  my ($self, $origin) = @_;
  ($origin eq 'p') && return {
    labelfr => 'SAP',
    labelen => 'SAP',
  };
  ($origin eq 'm') && return {
    labelfr => 'Accréditeur',
    labelen => 'Accreditor',
  };
  ($origin eq 'e') && return {
    labelfr => 'SAC',
    labelen => 'SAC',
  };
  ($origin eq 's') && return {
    labelfr => 'SAC',
    labelen => 'SAC',
  };
  ($origin eq 'a') && return {
    labelfr => 'Alumni',
    labelen => 'Alumni',
  };
  ($origin eq 'l') && return {
    labelfr => 'CDL',
    labelen => 'CDL',
  };
  ($origin eq 'g') && return {
    labelfr => 'Agepoly',
    labelen => 'Agepoly',
  };
  ($origin eq 'z') && return {
    labelfr => 'Ex-SAP',
    labelen => 'Ex-SAP',
  };
}

sub monthname {
  my ($self, $month) = @_;
  return ($self->{lang} eq 'en')
    ? $enmonthnames [$month]
    : $frmonthnames [$month]
    ;
}

sub getfieldlabel {
  my ($self, $field, $lang) = @_;
  my $label =
    ($field eq 'statusid') ? 'Status'   :
    ($field eq   'statut') ? 'Status'   :
    ($field eq  'classid') ? 'Class'    :
    ($field eq   'classe') ? 'Class'    :
    ($field eq    'posid') ? 'Position' :
    ($field eq 'fonction') ? 'Position' :
    ($field eq   'roleid') ? 'Role'     :
    ($field eq  'rightid') ? 'Right'    :
    ($field eq  'datedeb') ? 'Datedeb'  :
    ($field eq  'datefin') ? 'Datefin'  :
    ($field eq  'comment') ? 'Comment'  :
    ($field eq  'origine') ? 'Origine'  :
    ($field eq   'policy') ? 'Policy'   :
    undef;

  return $field unless $label;
  return msg($label);
}

sub getlabel {
  my ($self, $name, $lang, $id, @left) = @_;
  my $label =
    ($name =~ /^(statut|statusid)$/) ? $self->getstatus   ($id, @left) :
    ($name =~  /^(classe|classid)$/) ? $self->getclass    ($id, @left) :
    ($name =~  /^(fonction|posid)$/) ? $self->getposition ($id, @left) :
    ($name eq              'roleid') ? $self->getrole     ($id, @left) :
    ($name eq             'rightid') ? $self->getright    ($id, @left) :
    ($name eq               'duree') ? $self->getduree    ($id, @left) :
    ($name eq             'origine') ? $self->getorigin   ($id, @left) :
    ($name eq              'policy') ? $self->getpolicy   ($id, @left) :
    undef;

  return $id unless $label;
  return ($lang eq 'en')
    ? $label->{labelen}
    : $label->{labelfr}
    ;
}

sub getOpCodes {
  my $self = shift;
  return $loglabels;
}

sub getActionLabel {
  my ($self, $action, $lang) = @_;
  $lang ||= 'en';
  return $loglabels->[$action]->{$lang};
}

sub initlabels {
  return [
    { #  0
      fr => "Opération inconnue",
      en => "Unknown operation",
    },
    { #  1
      fr => "Ajout d'une accréditation",
      en => "Accred creation",
    },
    { #  2
      fr => "Modification d'une accréditation",
      en => "Accred modification",
    },
    { #  3
      fr => "Suppression d'une accréditation",
      en => "Accred removal",
    },
    { #  4
      fr => "Ajout d'une personne",
      en => "Person creation",
    },
    { #  5
      fr => "Modification des données d'une personne",
      en => "Person data modification",
    },
    { #  6
      fr => "Modification des droits aux prestations d'une unité",
      en => "Unit prestations rights modification",
    },
    { #  7
      fr => "Modification d'une prestation",
      en => "Prestation modification",
    },
    { #  8
      fr => "Inscription à GASPAR",
      en => "Gaspar account creation",
    },
    { #  9
      fr => "Modification de l'ordre des accreds d'une personne",
      en => "Accreds order modification",
    },
    { # 10
      fr => "Modification de fonctions EHE",
      en => "EHE position modification",
    },
    { # 11
      fr => "Création d'une fonction EHE",
      en => "EHE position creation",
    },
    { # 12
      fr => "Suppression d'une fonction EHE",
      en => "EHE position removal",
    },
    { # 13
      fr => "Revalidation d'une accréditation",
      en => "Accred revalidation",
    },
    { # 14
      fr => "Ajout d'un nouveau rôle",
      en => "Role creation",
    },
    { # 15
      fr => "Modification d'un rôle",
      en => "Role modification",
    },
    { # 16
      fr => "Suppression d'un rôle",
      en => "Role removal",
    },
    { # 17
      fr => "Ajout d'un nouveau droit",
      en => "Right creation",
    },
    { # 18
      fr => "Modification d'un droit",
      en => "Right modification",
    },
    { # 19
      fr => "Suppression d'un droit",
      en => "Right removal",
    },
    { # 20
      fr => "Ajout d'une machine",
      en => "Host creation",
    },
    { # 21
      fr => "Modification d'une machine",
      en => "Host modification",
    },
    { # 22
      fr => "Suppression d'une machine",
      en => "Host removal",
    },
    { # 23
      fr => "Demande d'inscription Gaspar",
      en => "Gaspar account creation",
    },
    { # 24
      fr => "Modification des rôles d'une personne",
      en => "Person's role modification",
    },
    { # 25
      fr => "Suppression d'un rôle à une personne",
      en => "Person's role removal",
    },
    { # 26
      fr => "Modification des droits d'une personne",
      en => "Person's right modification",
    },
    { # 27
      fr => "Suppression d'un droit à une personne",
      en => "Person's right removal",
    },
    { # 28
      fr => "Modification des droits d'une unité",
      en => "Unit's right modification",
    },
    { # 29
      fr => "Suppression d'un droit à une unité",
      en => "Unit's right removal",
    },
    { # 30
      fr => "Création d'une fonction EPFL",
      en => "EPFL position creation",
    },
    { # 31
      fr => "Modification de fonctions EPFL",
      en => "EPFL position modification",
    },
    { # 32
      fr => "Suppression d'une fonction EPFL",
      en => "EPFL position removal",
    },
    { # 33
      fr => "Modification d'une accréditation",
      en => "Accred modification",
    },
    { # 34
      fr => "Ajout d'un privilège droit à un accréditeur",
      en => "Privilege added to accreditor",
    },
    { # 35
      fr => "Suppression d'un privilège droit à un accréditeur",
      en => "Privilege removed from accreditor",
    },
    { # 36
      fr => "Ajout d'un privilège rôle à un accréditeur",
      en => "Privilege role added to accreditor",
    },
    { # 37
      fr => "Suppression d'un privilège rôle à un accréditeur",
      en => "Privilege role removed from accreditor",
    },
    { # 38
      fr => "Modification d'une fonction EHE",
      en => "EHE position modification",
    },
    { # 39
      fr => "Restriction des privilège d'une accréditation",
      en => "Accred privilege restriction",
    },
    { # 40
      fr => "Ajout d'une propriété",
      en => "Property creation",
    },
    { # 41
      fr => "Modification d'une propriété",
      en => "Property modification",
    },
    { # 42
      fr => "Suppression d'une propriété",
      en => "Property removal",
    },
    { # 43
      fr => "Modification d'une propriété d'une accréditation",
      en => "Accred's property modification",
    },
    { # 44
      fr => "Modification d'une propriété d'une unité",
      en => "Unit's property modification",
    },
    { # 45
      fr => "Operation 45",
      en => "Operation 45",
    },
    #
    # Positions.
    #
    { # 46,
      fr => "Création d'une fonction",
      en => "Add new position",
    },
    { # 47,
      fr => "Modification d'une fonction",
      en => "Modif a position",
    },
    { # 48
      fr => "Suppression d'une fonction",
      en => "Remove a position",
    },
    #
    # Workflows approval.
    #
    { # 49
      fr => "Demande d'approbation d'une action",
      en => "Ask for action approval",
    },
    { # 50
      fr => "Approbation d'une action",
      en => "Action approval",
    },
    { # 51
      fr => "Refus d'une action",
      en => "Action approval",
    },
    { # 52
      fr => "Action approuvée",
      en => "Action approved",
    },
    { # 53
      fr => "Refus d'une action",
      en => "Action refused",
    },
    #
    # Workflows
    #
    { # 54
      fr => "Création d'un workflow",
      en => "Workflow creation",
    },
    { # 55
      fr => "Modification d'un workflow",
      en => "Workflow modification",
    },
    { # 56
      fr => "Suppression d'un workflow",
      en => "Workflow removal",
    },
    #
    # Députations
    #
    { # 57
      fr => "Création d'une députation",
      en => "Deputation creation",
    },
    { # 58
      fr => "Modification d'une députation",
      en => "Deputation modification",
    },
    { # 59
      fr => "Suppression d'une députation",
      en => "Deputation removal",
    },
  ];
}

sub initopcodes {
  return {
                addaccr =>  1, # Ajout d'une accréditation
                modaccr =>  2, # Modification d'une accréditation
                remaccr =>  3, # Suppression d'une accréditation
                addscip =>  4, # Ajout d'une personne
                modscip =>  5, # Modification d'une personne
          modunitrights =>  6, # Modification des droits aux prestations d'une unité
          modprestation =>  7, # Modification d'une prestation
         gaspar_request =>  8, # Inscription à GASPAR
        setaccredsorder =>  9, # Modification de l'ordre des accreds d'une personne.

      modpositioninunit => 10, # Modification de fonctions EHE

         addfonctionehe => 11, # Création d'une fonction EHE
      modifyfonctionehe => 38, # Modification d'une fonction EHE
      deletefonctionehe => 12, # Suppression d'une fonction EHE

             revalidate => 13, # Revalidation d'une accréditation

                addrole => 14, # Ajout d'un nouveau rôle
             modifyrole => 15, # Modification d'un rôle
             deleterole => 16, # Suppression d'un rôle

               addright => 17, # Ajout d'un nouveau droit
            modifyright => 18, # Modification d'un droit
            deleteright => 19, # Suppression d'un droit

            setrolepers => 24, # Modification des rôles d'une personne
         deleterolepers => 25, # Suppression d'un rôle à une personne
           setrightpers => 26, # Modification des droits d'une personne
        deleterightpers => 27, # Suppression d'un droit à une personne
           setrightunit => 28, # Modification des droits d'une unité
        deleterightunit => 29, # Suppression d'un droit à une unité

        addfonctionepfl => 30, # Création d'une fonction EPFL
     modifyfonctionepfl => 31, # Modification de fonctions EPFL
     deletefonctionepfl => 32, # Suppression d'une fonction EPFL
  
             oldmodaccr => 33, # Ancienne modification d'une accréditation

        addaccredrights => 34, # Ajout d'un privilège droit à un accréditeur
     removeaccredrights => 35, # Suppression d'un privilège droit à un accréditeur
         addaccredroles => 36, # Ajout d'un privilège rôle à un accréditeur
      removeaccredroles => 37, # Suppression d'un privilège rôle à un accréditeur

         restrictaccred => 39, # Restriction des privilège d'une accréditation
            addproperty => 40, # Ajout d'une propriété
            modproperty => 41, # Modification d'une propriété
         deleteproperty => 42, # Suppression d'une propriété

             setaccprop => 43, # Modification d'une propriété d'une accréditation
             setdefprop => 44, # Modification d'une propriété d'une unité

            addposition => 46, # Création d'une fonction.
         modifyposition => 47, # Modification d'une fonction.
         deleteposition => 48, # Suppression d'une fonction.
  
   askforactionapproval => 49, # Demande d'approbation d'une action.
          approveaction => 50, # Approbation d'une action
           refuseaction => 51, # Refus d'une action
         actionapproved => 52, # Action approuvée
          actionrefused => 53, # Refus d'une action

            addworkflow => 54, # Création d'un workflow.
         modifyworkflow => 55, # Modification d'un workflow.
         deleteworkflow => 56, # Suppression d'un workflow.

          adddeputation => 57, # Création d'une députation.
          moddeputation => 58, # Modification d'une députation.
          remdeputation => 59, # Suppression d'une députation.
  };
}


1;
