# #!/usr/bin/perl
#
package Accred::Messages;

use strict;
use utf8;

use vars qw(@pubvars $messages $months $shortmonths $language $defaultlang);
@pubvars = qw(
  OK Cancel Yes No Return Default Nothing Name Firstname Label FrenchLabel EnglishLabel
  Unit Units Description AccessDenied Manager Allowed Status BirthDate Man Woman Creator
  People Date Status Class Nonem Nonef Forbidden Undefined Person FeminineLabel
  MasculineLabel Inherited Position Access Unknown Unknowne List Role Right Value
  NoName Property Properties Why);

$defaultlang = 'fr';
$language = 'en';

sub import {
  my $callpkg = caller (0);
  no strict 'refs';
  *{$callpkg."::msg"}    = \&msg;
  *{$callpkg."::months"} = \$months;
  use strict 'refs';
}

$messages = {
  #
  # General
  #
  Me => {
    fr => 'Moi',
    en => 'Me',
  },
  Yes => {
    fr => "Oui",
    en => "Yes",
  },
  No => {
    fr => "Non",
    en => "No",
  },
  OK => {
    fr => "OK",
    en => "OK",
  },
  And => {
    fr => "et",
    en => "and",
  },
  Or => {
    fr => "ou",
    en => "or",
  },
  Continue => {
    fr => "Continuer",
    en => "Continue",
  },
  Default => {
    fr => "Défaut",
    en => "Default",
  },
  Authorized => {
    fr => "Autorisé",
    en => "Authorized",
  },
  SetByDefault => {
    fr => "Mis par défaut",
    en => "Set by default",
  },
  Error => {
    fr => "Erreur",
    en => "Error",
  },
  Return => {
    fr => "Retour",
    en => "Return",
  },
  WhyMe => {
    fr => "Pourquoi moi ?",
    en => "Why me ?",
  },
  Access => {
    fr => "Accès",
    en => "Access",
  },
  Now => {
    fr => "Maintenant",
    en => 'Now',
  },
  Datefin => {
    fr => "Date fin",
    en => 'End date',
  },
  Datedeb => {
    fr => "Date début",
    en => 'Start date',
  },
  When => {
    fr => "Quand",
    en => 'When',
  },
  Nonem => {
    fr => "Aucun",
    en => "None",
  },
  Nonef => {
    fr => "Aucune",
    en => 'None',
  },
  NoSomething => {
    fr => "Aucune %thing",
    en => 'No %thing',
  },
  All => {
    fr => "Tout",
    en => 'All',
  },
  Allf => {
    fr => "Toutes",
    en => 'All',
  },
  Nothing => {
    fr => "Rien",
    en => "Nothing",
  },
  Others => {
    fr => "Autres",
    en => 'Others',
  },
  YourSelf => {
    fr => "Vous-même",
    en => "Yourself",
  },
  PersonId => {
    fr => "numéro Sciper",
    en => "Sciper number",
  },
  Name => {
    fr => "Nom",
    en => "Name",
  },
  UpperName => {
    fr => "Nom majuscule",
    en => "Name in uppercase",
  },
  Firstname => {
    fr => "Prénom",
    en => "Firstname",
  },
  UpperFirstname => {
    fr => "Prénom majuscule",
    en => "Firstname in uppercase",
  },
  CasualName => {
    fr => "Nom usuel",
    en => "Casual name",
  },
  CasualFirstname => {
    fr => "Prénom usuel",
    en => "Casual firstname",
  },
  BirthDate => {
    fr => "Date de naissance",
    en => "Birth date",
  },
  Gender => {
    fr => "Sexe",
    en => "Gender",
  },
  Man => {
    fr => "Homme",
    en => 'Man',
  },
  Woman => {
    fr => "Femme",
    en => 'Woman',
  },
  Label => {
    fr => "Libellé",
    en => "Label",
  },
  FrenchLabel => {
    fr => "Libellé en français",
    en => "French label",
  },
  EnglishLabel => {
    fr => "Libellé en anglais",
    en => "English label",
  },
  FeminineLabel => {
    fr => "Libellé féminin",
    en => "Feminine label",
  },
  MasculineLabel => {
    fr => "Libellé masculin",
    en => "Masculine label",
  },
  Feminine => {
    fr => "Féminin",
    en => "Feminine",
  },
  Masculine => {
    fr => "Masculin",
    en => "Masculine",
  },
  Description => {
    fr => "Description",
    en => "Description",
  },
  Manager => {
    fr => "Responsable",
    en => "Manager",
  },
  Unit => {
    fr => "Unité",
    en => "Unit",
  },
  Units => {
    fr => "Unités",
    en => "Units",
  },
  Unitpsp => {
    fr => "Unité(s)",
    en => "Unit(s)",
  },
  TheUnit => {
    fr => "l'unité",
    en => "unit",
  },
  SeeUnit => {
    fr => "Voir l'unité",
    en => "See unit",
  },
  ExternalUnits => {
    fr => "les unités externes",
    en => "external units",
  },
  AllExternalUnits => {
    fr => "Toutes les unités externes",
    en => "All external units",
  },
  Right => {
    fr => "Droit",
    en => "Right",
  },
  Status => {
    fr => "Statut",
    en => "Status",
  },
  Class => {
    fr => "Classe",
    en => "Class",
  },
  Operation => {
    fr => "Opération",
    en => "Operation",
  },
  Detail => {
    fr => "Détail",
    en => "Detail",
  },
  Date => {
    fr => "Date",
    en => "Date",
  },
  StartDate => {
    fr => "Date début",
    en => "Start date",
  },
  EndDate => {
    fr => "Date fin",
    en => "End date",
  },
  Creator => {
    fr => "Créateur",
    en => "Creator",
  },
  CreationDate => {
    fr => "Date création",
    en => "Creation date",
  },
  Comment => {
    fr => "Commentaire",
    en => "Comment",
  },
  Origine => {
    fr => "Origine",
    en => "Origin",
  },
  Order => {
    fr => "Ordre",
    en => "Order",
  },
  Delete => {
    fr => "Enlever",
    en => "Delete",
  },
  Author => {
    fr => "Auteur",
    en => "Author",
  },
  Accreditation => {
    fr => "Accréditation",
    en => "Accreditation",
  },
  Accreditations => {
    fr => "Accréditations",
    en => "Accreditations",
  },
  Accreditors => {
    fr => "Accréditeurs",
    en => "Accreditors",
  },
  Names => {
    fr => "Noms",
    en => "Names",
  },
  Value => {
    fr => "Valeur",
    en => "Value",
  },
  History => {
    fr => "Historique",
    en => "History",
  },
  Nobody => {
    fr => "Personne",
    en => "Nobody",
  },
  Unknown => {
    fr => "Inconnu",
    en => "Unknown",
  },
  Unknowne => {
    fr => "Inconnue",
    en => "Unknown",
  },
  Defined => {
    fr => "Défini",
    en => "Defined",
  },
  DefinedFor => {
    fr => "Défini pour unit %unit",
    en => "Defined for unit %unit",
  },
  DefinedForThisUnit => {
    fr => "Défini pour cette unité",
    en => "Defined for this unit",
  },
  For => {
    fr => "Pour",
    en => "For",
  },
  In => {
    fr => "dans",
    en => "in",
  },
  Why => {
    fr => "Pourquoi",
    en => "Why",
  },
  From => {
    fr => "Du",
    en => "From",
  },
  To => {
    fr => "Au",
    en => "To",
  },
  orName => {
    fr => "ou Nom",
    en => "or Name",
  },
  Search => {
    fr => "Chercher",
    en => "Search",
  },
  DoYouWant => {
    fr => "Voulez-vous ?",
    en => "Do you want to ?",
  },
  DoYouWantTo => {
    fr => "Voulez-vous ",
    en => "Do you want to ",
  },
  Cancel => {
    fr => "Annuler",
    en => "Cancel",
  },
  Choose => {
    fr => "Choisissez",
    en => "Choose",
  },
  ChooseOrg => {
    fr => "Choisissez l'unité",
    en => "Choose unit",
  },
  UnitOrCF => {
    fr => "Unité / CF",
    en => "Unit / CF",
  },
  ChooseFund => {
    fr => "Choisissez le CF/fonds",
    en => "Choose CF/fund",
  },
  EnterOrgAcronym => {
    fr => "Entrer le sigle de l'unité",
    en => "Enter unit acronym",
  },
  OrEnterOrgAcronym => {
    fr => "Ou entrer le sigle ",
    en => "Or enter acronym",
  },
  EnterFundName => {
    fr => "Entrer le nom du CF/fonds",
    en => "Enter CF/fund name",
  },
  OrEnterFundName => {
    fr => "Ou entrer le nom",
    en => "Or enter name",
  },
  DoNothing => {
    fr => "Ne rien faire",
    en => "Do nothing",
  },
  StillDoIt => {
    fr => "Le faire quand même",
    en => "Still do it",
  },
  Illimited => {
    fr => "Illimité",
    en => "Unlimited",
  },
  Password => {
    fr => "Mot de passe",
    en => "Password",
  },
  IMAPAccount => {
    fr => "Compte IMAP",
    en => "IMAP account",
  },
  MailBox => {
    fr => "Boîte email",
    en => "MailBox",
  },  
  Automatic => {
    fr => "Automatique",
    en => "Automatic",
  },
  NoLabel => {
    fr => "Vous devez spécifier le libellé",
    en => "You must specify the label",
  },
  SortedBy => {
    fr => "Triés par",
    en => "Sorted by",
  },
  Revalidations => {
    fr => "Revalidations",
    en => "Revalidations",
  },
  Today => {
    fr => "Aujourd'hui",
    en => "Today",
  },
  month => {
    fr => "mois",
    en => "month",
  },
  year => {
    fr => "an",
    en => "year",
  },
  dans => {
    fr => "dans",
    en => "in",
  },
  pour => {
    fr => "pour",
    en => "for",
  },
  de => {
    fr => "de",
    en => "of",
  },
  Root => {
    fr => "Racine",
    en => "Root",
  },
  Allowed => {
    fr => "Autorisé",
    en => "Allowed",
  },
  Alloweds => {
    fr => "Autorisés",
    en => "Allowed",
  },
  Allowedf => {
    fr => "Autorisée",
    en => "Allowed",
  },
  Allowedfs => {
    fr => "Autorisées",
    en => "Allowed",
  },
  Forbidden => {
    fr => "Interdit",
    en => "Forbidden",
  },
  Inherited => {
    fr => "Hérité",
    en => "Inherited",
  },
  InheritedFrom => {
    fr => "Hérité de",
    en => "Inherited from",
  },
  Undefined => {
    fr => "Indéfini",
    en => "Undefined",
  },
  Management => {
    fr => "Gestion",
    en => "Management",
  },
  Summary => {
    fr => "Résumé",
    en => "Summary",
  },
  Dashboard => {
    fr => "Tableau de bord",
    en => "Dashboard",
  },
  UnknownCommand => {
    fr => "Commande inconnue",
    en => "Unknown command",
  },
  Person => {
    fr => "Personne",
    en => "Person",
  },
  People => {
    fr => "Personnes",
    en => "People",
  },
  Services => {
    fr => "Services",
    en => "Services",
  },
  Revalidations => {
    fr => "Revalidations",
    en => "Revalidations",
  },
  List => {
    fr => "Liste",
    en => "List",
  },
  Logs => {
    fr => "Logs",
    en => "Logs",
  },
  Activities => {
    fr => "Activités",
    en => "Activities",
  },
  ActivitiesOf => {
    fr => "Activités de %pers",
    en => "Activities of %pers",
  },
  SeeMore => {
    fr => "Voir plus",
    en => "See more",
  },
  Rights => {
    fr => "Droits",
    en => "Rights",
  },
  Prestation => {
    fr => "Prestation",
    en => "Service",
  },
  Prestations => {
    fr => "Prestations",
    en => "Basic services",
  },
  Documentation => {
    fr => "Documentation",
    en => "Documentation",
  },
  Logout => {
    fr => "Logout",
    en => "Logout",
  },
  invalid => {
    fr => " invalide",
    en => " invalid",
  },
  granting => {
    fr => "Attribution",
    en => "Attribution",
  },
  revocation => {
    fr => "Révocation",
    en => "Revocation",
  },
  grant => {
    fr => "donner",
    en => "grant",
  },
  revoke => {
    fr => "ôter",
    en => "revoke",
  },
  regrant => {
    fr => "remettre",
    en => "regrant",
  },
  inthepast => {
    fr => " dans le passé",
    en => " in the past",
  },
  CreateThisPerson => {
    fr => "créer cette personne",
    en => "add this person",
  },
  ViewThisPerson => {
    fr => "Détails de cette personne",
    en => "Details on this person",
  },
  PersonName => {
    fr => "Nom de la personne",
    en => "Person name",
  },
  UnknownName => {
    fr => "Aucune personne de ce nom trouvée.",
    en => "No person found with this name.",
  },
  SeveralResults => {
    fr => "Il y a plusieurs résultats",
    en => "There are several results",
  },
  EmailsListName => {
    fr => "Nom de la liste d'email",
    en => "Emails list’s name",
  },
  InvalidEmailsListName => {
    fr => "Nom de la liste d'email invalide",
    en => "Invalid emails list’s name",
  },
  InternalError => {
    fr => "Erreur interne : %errmsg.",
    en => "Internal error : %errmsg.",
  },
  DatabaseError => {
    fr => "Problème de connexion avec la base de données, essayez plus tard.",
    en => "Database access error, try again later.",
  },
  Success => {
    fr => "Opération effectuée avec succès.",
    en => "Operation successful.",
  },
  BecomeMyselfAgain => {
    fr => "Redevenir moi-même",
    en => "Become myself again",
  },
  SaveAsCSV => {
    fr => "Sauver en format CSV",
    en => "Save as CSV",
  },
  About => {
    fr => "A propos",
    en => "About",
  },
  AboutAccred => {
    fr => "A propos d'Accred",
    en => "About Accred",
  },
  YouAreUsing => {
    fr => "Vous utilisez la version 3.2 d'Accred",
    en => "You are using Accred version 3.2",
  },
  Optional => {
    fr => "Optionnel",
    en => "Optional",
  },
  NoWhere => {
    fr => "Nulle part",
    en => "No where",
  },
  BadValueForType => {
    fr => "Valeur invalide pour le type %type : %value",
    en => "Invalid value for type %type : %value",
  },

  #
  # Accreds
  #
  
  AccredAddedIn => {
    fr => "Accréditation ajoutée avec succès dans %unit",
    en => "Accreditation successfully added to %unit",
  },
  AccredOfPersInUnit => {
    fr => "Accréditation de %pers (%persid) pour l'unité %unit",
    en => "Accreditation of %pers (%persid) to unit %unit",
  },
  AccredPersonSomewhere => {
    fr => "Accréditer %pers quelque part",
    en => "Accredit %pers somewhere",
  },
  AccredThisPersonInUnit => {
    fr => "Accréditer cette personne dans l'unité %unit",
    en => "Accredit this person in unit %unit",
  },
  AddAnAccredIn => {
    fr => "Ajout d'une accréditation dans l'unité %unit",
    en => "Add an accreditation to unit %unit",
  },
  AddAnAccred => {
    fr => "Ajouter une accréditation",
    en => "Add an accreditation",
  },
  AddAnAccredTo => {
    fr => "Ajouter une accréditation à %pers",
    en => "Add an accreditation to %pers",
  },
  Impersonate => {
    fr => "Utiliser le compte de %pers",
    en => "Use the account of %pers",
  },
  NoModification => {
    fr => "Aucune modification.",
    en => "No change.",
  },
  SuccessfulModification => {
    fr => "Modification effectués avec succès.",
    en => "Modification processed successfully.",
  },
  NoMatchingPers => {
    fr => "Aucune personne ne correspond",
    en => "No matching person",
  },
  NoRevalidation => {
    fr => "Aucune revalidation effectuée.",
    en => "No revalidation done.",
  },
  RevalidationDone => {
    fr => "Revalidations effectuées.",
    en => "Revalidations done.",
  },
  NoEndDate => {
    fr => "Cette accréditation n'a pas de date de fin",
    en => "This accreditation has no end date",
  },
  AccredExists => {
    fr => "Cette personne est déjà accréditée dans cette unité",
    en => "This person is already accredited in this unit",
  },
  OnlyOneAccred => {
    fr => "Cette personne n'a qu'une seule accréditation",
    en => "This person has only one accreditation",
  },
  PersonHasNoAccred => {
    fr => "Cette personne n'a pas d'accréditation",
    en => "This person has no accreditation",
  },
  ChangeAccredsOrder => {
    fr => "Changement de l'ordre relatif des accréditations",
    en => "Change accreditations' order",
  },
  LookForPers => {
    fr => "Chercher une personne",
    en => "Search for a person",
  },
  LookForUnit => {
    fr => "Chercher une unité",
    en => "Search for a unit",
  },
  ClassForbidden => {
    fr => "Classe interdite",
    en => "Forbidden class",
  },
  ClassForbidForStat => {
    fr => "Classe interdite pour ce statut",
    en => "Forbidden class for this status",
  },
  PossibleComment => {
    fr => "Commentaire éventuel",
    en => "Comment",
  },
  inunit => {
    fr => " dans l'unité <b>%unit</b>",
    en => " in unit <b>%unit</b>",
  },
  InUnit => {
    fr => "Dans l'unité <b>%unit</b>",
    en => "In unit <b>%unit</b>",
  },
  NewOrder => {
    fr => "Nouvel ordre",
    en => "New order",
  },
  forperson => {
    fr => " pour %pers",
    en => " for %pers",
  },
  WhichUnitForAccred => {
    fr => "Dans quelle unité voulez-vous accréditer %pers",
    en => "In which unit do you want to accredit %pers",
  },
  AccredStartDate => {
    fr => "Date de début de l'accréditation",
    en => "Start date of accreditation",
  },
  AccredEndDate => {
    fr => "Date de fin de l'accréditation",
    en => "End date of accreditation",
  },
  RefDate => {
    fr => "Date de référence",
    en => "Reference date",
  },
  InvalideDate => {
    fr => "Date %date invalide.",
    en => "Invalid date : %date.",
  },
  InvalidRefDate => {
    fr => "Date de référence invalide : %date.",
    en => "Invalid reference date : %date.",
  },
  RefDateInFutur => {
    fr => "Date de référence invalide, %date est dans le fufur.",
    en => "Invalid reference date, %date is in the future.",
  },
  TooOldRefDate => {
    fr => "Date de référence invalide, trop ancienne.",
    en => "Invalid reference date, too old.",
  },
  EndbeforeStart => {
    fr => "Date fin antérieure à la date début.",
    en => "End date before start date.",
  },
  StartDateInThePast => {
    fr => "Date début invalide, elle est dans le passé.",
    en => "Invalid start date, it is in the past.",
  },
  EndDateInThePast => {
    fr => "Date fin invalide, elle est dans le passé.",
    en => "Invalid end date, it is in the past.",
  },
  ModifInPast => {
    fr => "Vous ne pouvez pas modifier dans le passé",
    en => "You cannot modify in the past",
  },
  AccredTooLong => {
    fr => "Date fin invalide, la durée de l'accréditation ne doit ".
          "pas excéder 1 an à partir de maintenant",
    en => "Invalid end date, accreditation duration must not exceed 1 year from now",
  },
  StartValidity => {
    fr => "Début validité",
    en => "Start of validity",
  },
  EndValidity => {
    fr => "Fin validité",
    en => "End of validity",
  },
  DataAboutPers => {
    fr => "Données concernant %pers",
    en => "Data concerning %pers",
  },
  YourData => {
    fr => "Données vous concernant",
    en => "Your data",
  },
  CannotDestroyAccred => {
    fr => "Vous ne pouvez pas détruire cette accréditation.",
    en => "You cannot destroy this accreditation.",
  },
  ConfirmRemAccred => {
    fr => "Êtes-vous sûr de vouloir détruire l'accréditation de %pers ".
          "dans l'unité %unit ?",
    en => "Do you really want to remove accreditation of %pers in unit %unit ?",
  },
  InvalidEmail => {
    fr => "Adresse email invalide",
    en => "Invalid email address",
  },
  AccredsHistory => {
    fr => "Historique des accréditations",
    en => "Accreditations' history",
  },
  AccredsOfPersInUnit => {
    fr => "Accréditation de %pers dans l'unité %unit",
    en => "Accreditation of %pers in unit %unit",
  },
  InParentUnit => {
    fr => " dans l'unité parente %unit",
    en => " in parent unit %unit",
  },
  BadLevel => {
    fr => "Il n'est pas possible de mettre des accréditation dans ".
          "des unités de niveau inférieur à 4",
    en => "It is not allowed to define accreditations in units below level 4",
  },
  NoAccred => {
    fr => "Il n'y a pas d'accréditation pour %pers dans l'unité %unit",
    en => "%pers has no accreditation in unit %unit",
  },
  NothingInHistory => {
    fr => "Il n'y a rien dans l'historique",
    en => "There is no history",
  },
  SeveralResults => {
    fr => "Il y a plusieurs résultats",
    en => "There are several results",
  },
  IDecideLater => {
    fr => "Je déciderai plus tard",
    en => "I'll decide later",
  },
  DestroyIt => {
    fr => "La détruire",
    en => "Destroy it",
  },
  DestroyItm => {
    fr => "Le détruire",
    en => "Destroy it",
  },
  ExtendIt => {
    fr => "La prolonger",
    en => "Extend it",
  },
  UnitsWhereAction => {
    fr => "Liste des unités où vous pouvez exercer une action",
    en => "Units in which you are active",
  },
  ViewAllAccredsOf => {
    fr => "Voir toutes les accréditations de cette personne",
    en => "View all accreditations of this person",
  },
  ModifyThisAccred => {
    fr => "Modifier cette accréditation",
    en => "Modify this accreditation",
  },
  ModifyAccredsOrder => {
    fr => "Modifier l'ordre de ces accréditations",
    en => "Change these accreditations order",
  },
  NewEndDateFor => {
    fr => "Nouvelle date de fin pour <b>%pers</b> dans <b>%unit</b> : %date",
    en => "New end date for <b>%pers</b> in <b>%unit</b> : %date",
  },
  NewRefDate => {
    fr => "Nouvelle date de référence",
    en => "New reference date",
  },
  EndDateIfAny => {
    fr => "Date fin (si limité)",
    en => "End date (if any)",
  },
  Persons => {
    fr => "Sciper",
    en => "Sciper",
  },
  FindAPerson => {
    fr => "Rechercher un Sciper",
    en => "Search for a Sciper",
  },
  UnknownPersonId => {
    fr => "Numéro sciper inconnu : %persid",
    en => "Unknown sciper number : %persid",
  },
  InvalidPersonId => {
    fr => "Numéro Sciper invalide : %persid",
    en => "Invalid sciper number : %persid",
  },
  PersonData => {
    fr => "Données Sciper pour %persid",
    en => "Sciper data for %persid",
  },
  ReEdit => {
    fr => "Ré-éditer",
    en => "Reedit",
  },
  OrEnterUnit => {
    fr => "Ou entrez un sigle d'unité",
    en => "Or enter unit acronym",
  },
  PeriodTooLong => {
    fr => "Période trop longue (maximum 12 mois)",
    en => "Period too long (12 months max)",
  },
  Period => {
    fr => "Période",
    en => "Period",
  },
  PersonsToRevalid => {
    fr => "Personnes à revalider",
    en => "Persons to revalidate",
  },
  NobodyToRevalid => {
    fr => "Il n'y a personne à revalider rapidement",
    en => "There is nobody to revalidate",
  },
  UnknownPerson => {
    fr => "Personne inconnue : %pers",
    en => "Unknown person : %pers",
  },
  NoAccredForPerson => {
    fr => "%pers n'a aucune accréditation",
    en => "%pers has no accreditation",
  },
  PersNotInUnit => {
    fr => "%pers n'est pas accrédité dans l'unité %unit",
    en => "%pers is not accredited in unit %unit",
  },
  forThisUnit => {
    fr => "pour cette unité",
    en => "for this unit",
  },
  GiveTheClass => {
    fr => "Précisez la classe",
    en => "Specify the class",
  },
  UnknownClass => {
    fr => "Classe inconnue : %class",
    en => "Unknown class : %class",
  },
  GiveTheStatus => {
    fr => "Précisez le statut",
    en => "Specify the status",
  },
  UnknownStatus => {
    fr => "Status inconnue : %status",
    en => "Unknown status : %status",
  },
  ReturnToUnit => {
    fr => "Retour à l'unité %unit",
    en => "Return to unit %unit",
  },
  AccredEndsAt => {
    fr => "<b>%pers</b> (%scip) échéance le %date",
    en => "<b>%pers</b> (%scip) end date %date",
  },
  AddTimeToAccred => {
    fr => "Ajouter",
    en => "Add",
  },
  RevalAccred => {
    fr => "Revalidation de %pers dans l'unité %unit",
    en => "Revalidation of %pers in unit %unit",
  },
  NeedsReval => {
    fr => "Échéance le %date, rajouter &nbsp;",
    en => "Ends on %date, add &nbsp;",
  },
  RevalsDone => {
    fr => "Revalidation%s effectuée%s avec succès.",
    en => "Revalidation%s successful.",
  },
  UnauthorizedStatus => {
    fr => "Statut non autorisé",
    en => "Unauthorized status",
  },
  AllTheRights => {
    fr => "Tous les droits",
    en => "All the rights",
  },
  AllYourRights => {
    fr => "Tous vos droits",
    en => "All your rights",
  },
  AccredsUnits => {
    fr => "Unité(s)",
    en => "Unit(s)",
  },
  UnknownUnit => {
    fr => "Unité inconnue : %unit",
    en => "Unknown unit : %unit",
  },
  PersonHistory => {
    fr => "Voir tout ce qui est arrivé à cette personne",
    en => "History of this Person",
  },
  AddAccredConfirm => {
    fr => "Voulez-vous vraiment ajouter l'accréditation suivante ?",
    en => "Do you really want to add this accreditation ?",
  },
  NoAccredGiven => {
    fr => "Vous devez spécifier au moins une accréditation",
    en => "You must specify an accreditation",
  },
  NoStatus => {
    fr => "Vous devez spécifier le statut",
    en => "You must specify the status",
  },
  NoClass => {
    fr => "Vous devez spécifier la classe",
    en => "You must specify the class",
  },
  NoEndDate => {
    fr => "Vous devez spécifier la date de fin",
    en => "You must specify the end date",
  },
  NoPersonId => {
    fr => "Vous devez spécifier le numéro Sciper",
    en => "You must give the sciper number",
  },
  NoUnit => {
    fr => "Vous devez spécifier l'unité",
    en => "You must specify the unit",
  },
  NoPersonOrUnit => {
    fr => "Vous devez spécifier soit le numéro Sciper, soit l'unité",
    en => "You must specify the either Sciper or unit",
  },
  NoValue => {
    fr => "Vous devez spécifier la valeur",
    en => "You must specify the value",
  },
  NoDay => {
    fr => "Vous devez spécifier le jour ",
    en => "You must specify the day",
  },
  NoStartDate => {
    fr => "Vous devez spécifier la date de début",
    en => "You must specify the start date",
  },
  BadStartDate => {
    fr => "Date de début invalide : %date",
    en => "Bad start date : %date",
  },
  BadEndDate => {
    fr => "Date de fin invalide : %date",
    en => "Bad end date : %date",
  },
  NoStartDay => {
    fr => "Vous devez spécifier le jour de début",
    en => "You must specify the start day",
  },
  NoEndDay => {
    fr => "Vous devez spécifier le jour de fin",
    en => "You must specify the end day",
  },
  NoMonth => {
    fr => "Vous devez spécifier le mois",
    en => "You must specify the month",
  },
  NoStartMonth => {
    fr => "Vous devez spécifier le mois de début",
    en => "You must give the start month",
  },
  NoEndMonth => {
    fr => "Vous devez spécifier le mois de fin",
    en => "You must give the end month",
  },
  NoYear => {
    fr => "Vous devez spécifier l'année ",
    en => "You must specify the year",
  },
  NoStartYear => {
    fr => "Vous devez spécifier l'année de début",
    en => "You must specify the start year",
  },
  NoEndYear => {
    fr => "Vous devez spécifier l'année de fin",
    en => "You must specify the end year",
  },
  YouMustGiveAllFields => {
    fr => "Vous devez spécifier tous les champs",
    en => "You must fill in all fields",
  },
  YouMustGive => {
    fr => "Vous devez spécifier ",
    en => "You must specify ",
  },
  UnknownPersonId => {
    fr => "Numéro sciper inconnu : %persid",
    en => "Unknown sciper number : %persid",
  },
  NoManagedUnit => {
    fr => "Vous ne gérez aucune unité",
    en => "You dont manage any units",
  },
  ForbiddenStatus => {
    fr => "Statut 'Personnel' invalide, la personne n'est pas connue des RH.",
    en => "Status 'Personnel' unauthorized.",
  },
  ChangeClassForbidden => {
    fr => "Vous ne pouvez pas changer la classe",
    en => "You cannot change the class",
  },
  ChangePositionForbidden => {
    fr => "Vous ne pouvez pas changer la fonction (protégée)",
    en => "You cannot change this position (protected)",
  },
  PositionForbidden => {
    fr => "Cette fonction est interdite pour cette unité",
    en => "This position is forbidden for this unit",
  },
  PositionRestricted => {
    fr => "Vous ne pouvez pas mettre cette fonction (protégée)",
    en => "You cannot set this position (protected)",
  },
  AddAccredForbidden => {
    fr => "Vous ne pouvez pas rajouter d'accréditation dans cette unité (%unit)",
    en => "You cannot add accreditations to this unit (%unit)",
  },
  NotAccreditor => {
    fr => "Vous n'êtes pas accréditeur",
    en => "You are not an accreditor",
  },
  AccessDenied => {
    fr => "Vous n'êtes pas autorisé à faire cette opération",
    en => "Operation not allowed",
  },
  YourAccreds => {
    fr => "Vos accréditations",
    en => "Your accreditations",
  },
  YourAccreditors => {
    fr => "Vos accréditeurs",
    en => "Your accreditors",
  },
  AccredsOrderHelp => {
    fr => "L'ordre relatif des accréditations est celui qui sera utilisé dans ".
          "l'annuaire Web, ainsi que par certaines applications informatiques. ".
          "Mettez l'accréditation principale en tête, puis, par ordre décroissant ".
          "de priorité.",
    en => "The accreditations' order is used in the Web directory and by several ".
          "IT applications. Put the main accreditation first, then ".
          "put any others in decreasing order of priority.",
  },
  OrderChangeHelp => {
    fr => "Pour changer l'ordre, cliquez sur une entrée dans la liste à gauche et ".
          "cliquez sur &lt;Up&gt; ou &lt;Down&gt; pour la monter ou la descendre ".
          "dans la liste.",
    en => "To change the order, click on an entry in the left list, then click on ".
          "&lt;Up&gt; or &lt;Down&gt; to push it up or down.",
  },
  AccredsOfPersonsInUnit => {
    fr => "Accréditations des personnes de l'unité %unit, %number personnes",
    en => "Accreditations in unit %unit, %number persons",
  },

  PrivateEmail => {
    fr => "Adresse email privée",
    en => "Private email address",
  },

  InternalEmail => {
    fr => "Adresse email invalide (adresse interne)",
    en => "Internal emails not authorized",
  },

  PrivateEmailHelp => {
    fr =>
      "<h3> Adresse email privée </h3>\n".
      "Si vous connaissez l'adresse email privée de la personne que vous accréditez, ".
      "vous pouvez l'indiquer dans ce champ.\n".
      "<br>\n".
      "Cette adresse sera utilisée pour la création automatique du compte Gaspar ".
      "et de la boîte email EPFL de cette personne. Une URL spéciale va être envoyée ".
      "à cette adresse lui permettant d'initialiser son mot de passe Gaspar.\n".
      "<br>\n".
      "Attention à ne pas faire d'erreur de transcription, il ne sera pas possible de ".
      "changer la valeur que vous allez donner. Si vous commettez une telle erreur, ".
      "la personne ne recevra pas l'email et seul son responsable Gaspar pourra ".
      "procéder à l'initialisation du compte.\n",
    en =>
      "<h3> Private email address </h3>\n".
      "If you know the private email address of the person you are accrediting, ".
      "you can enter it in this field.<\n>".
      "<br>\n".
      "This address will be used for automatic creation of the Gaspar account ".
      "and the EPFL email address. A specific URL will be sent ".
      "to this address allowing the initialization of the Gaspar password.\n".
      "<br>\n".
      "Be careful not to do transcriptions errors, since you will not be able to change ".
      "this address. In case of error, the user will not receive an email and only ".
      "the Gaspar manager will be able to initialize the account.\n",
  },

  Checkidentity => {
    fr => "Attention, vérifiez bien que vous avez affaire au bon ".
          "%pers, sexe %sexe, date de naissance : %date",
    en => "Be careful, double check the data is correct : %pers, gender %sexe, ".
          "birthdate %date",
  },

  Bye => {
    fr => "Session terminée, À bientôt.",
    en => "Session ended, goodbye.",
  },
  
  GivenByDefault => {
    fr => "Donné par défaut",
    en => "Granted by default",
  },
  DefaultsForStatus => {
    fr => "Attribution par defaut pour les statuts",
    en => "Defaults for status",
  },
  DefaultForTheStatus => {
    fr => "Défaut pour le statut <b>%detail</b>",
    en => "Default for the status <b>%detail</b>",
  },
  GivenByDefaultForStatus => {
    fr => "Donné par défaut pour les statuts",
    en => "Granted by default for status",
  },

  DefaultsForClasses => {
    fr => "Attribution par defaut pour les classes",
    en => "Defaults for classes",
  },
  DefaultForTheClass => {
    fr => "Défaut de la classe <b>%detail</b>",
    en => "Default for class  <b>%detail</b>",
  },
  GivenByDefaultForClasses => {
    fr => "Donné par défaut pour les classes",
    en => "Granted by default for classes",
  },
  #
  # Units
  #
  UnitsAdmin => {
    fr => "Unités",
    en => "Units",
  },
  ModifyThisUnit => {
    fr => "Modifier cette unité",
    en => "Modify this unit",
  },
  UnitType => {
    fr => "Type d'unité",
    en => "Unit type",
  },
  #
  # Rights
  #
  Right => {
    fr => "Droit",
    en => "Right",
  },
  Rights => {
    fr => "Droits",
    en => "Rights",
  },
  SeeTheRights => {
    fr => "Voir les droits",
    en => "See the rights",
  },
  RightsManagement => {
    fr => "Gestion des droits",
    en => "Rights management",
  },
  NoRight => {
    fr => "Vous devez spécifier le droit",
    en => "You must specify the right",
  },
  UnknownRight => {
    fr => "Droit inconnu : %right",
    en => "Unknown right : %right",
  },
  NoRights => {
    fr => "Aucun droit défini pour le type %type",
    en => "No rights defined for unit type %type",
  },
  ExplicitRights => {
    fr => "Droits explicites",
    en => "Explicit rights",
  },
  ActualRights => {
    fr => "Droits effectifs",
    en => "Actual rights",
  },
  InheritedRights => {
    fr => "Droits hérités",
    en => "Inherited rights",
  },
  InheritedRightsInUnit => {
    fr => "Droits hérités dans %inunit",
    en => "Inherited rights in %inunit",
  },
  ActualRightsInUnit => {
    fr => "Droits effectifs dans %inunit",
    en => "Actual rights in %inunit",
  },
  YourExplicitRights => {
    fr => "Vos droits explicites",
    en => "Your explicit rights",
  },
  AdminsRoles => {
    fr => "Rôles administrateurs",
    en => "Administrators roles",
  },
  RoleHasRights => {
    fr => "Le rôle donne les droits associés",
    en => "The role gives associated rights",
  },
  RoleCanDelegate => {
    fr => "Le rôle peut déléguer ses droits",
    en => "The role can delegates rights",
  },
  RoleIsProtected => {
    fr => "Le rôle est protégé",
    en => "The role is protected",
  },
  RightAdminsForUnit => {
    fr => "Administrateurs du droit pour %unit",
    en => "Right administrators for unit %unit",
  },
  RightForbiddenForUnit => {
    fr => "Ce droit n'est pas autorisé pour cette unité.",
    en => "This right is not authorized for this unit.",
  },
  AlreadyHasRight => {
    fr => "%pers est déjà titulaire de ce droit pour cette unité",
    en => "%pers already has this right for this unit",
  },
  HasNotRight => {
    fr => "%pers n'a pas ce droit pour cette unité",
    en => "%pers doesn't have this right for this unit",
  },
  DefinedInUnit => {
    fr => "Défini dans l'unité <b>%detail</b>",
    en => "Defined in unit  <b>%detail</b>",
  },
  ThanksToRole => {
    fr => "Grâce au rôle <b>%detail</b> dans <b>%detail2</b>",
    en => "Thanks to role  <b>%detail</b> in <b>%detail2</b>",
  },
  RemoveRightForUnit => {
    fr => "Enlever le droit spécifiquement pour %unit",
    en => "Remove this right specifically for %unit",
  },
  ConfirmGrantRight => {
    fr => "Voulez-vous vraiment %action le droit %right à ".
          "%pers pour l'unité %unit ?",
    en => "Do you really want to %action right %right to %pers in unit %unit ?",
  },
  ManageRightsInUnit => {
    fr => "Gestion du droit '<b>%right</b>' pour l'unité <b>%unit</b>",
    en => "Management of right '<b>%right</b>' in unit <b>%unit</b>",
  },
  ExplicitRightsInUnit => {
    fr => "Droits explicites dans %inunit",
    en => "Explicit rights in %inunit",
  },
  
  ManageRightsForPerson => {
    fr => "Gestion du droit '<b>%right</b>' pour <b>%pers</b>",
    en => "Management of right '<b>%right</b>' for <b>%pers</b>",
  },
  AddARight => {
    fr => "Ajouter un droit",
    en => "Add a right",
  },
  ConfirmDeleteRight => {
    fr => "Voulez-vous vraiment détruire le droit <b>'%right'<b> ?",
    en => "Do you really want to delete right <b>'%right'<b> ?",
  },
  WarnRightUsed => {
    fr => "Attention Le droit %right est attribué à une %npers personnes.".
          " Il leur sera supprimé d'abord.",
    en => "Warning right %right is used by %npers persons, it will first be revoked.",
  },
  ModifyThisRight => {
    fr => "Modifier ce droit",
    en => "Modify this right",
  },
  
  
  ManagingRights => {
    fr => "Droits contrôlant ce rôle",
    en => "Rights managing this role",
  },
  RolesManaged => {
    fr => "Rôles gérés par ce droit",
    en => "Roles managed by this right",
  },
  #ModifyThisRight => {
  #  fr => "Modifier ce droit",
  #  en => "Modify this right",
  #},
  #ModifyThisRight => {
  #  fr => "Modifier ce droit",
  #  en => "Modify this right",
  #},
  
  
  #
  # Workflows
  #
  Workflows => {
    fr => "Workflows",
    en => "Workflows",
  },
  Object => {
    fr => "Objet",
    en => "Object",
  },
  AddAWorkflow => {
    fr => "Ajouter un workflow",
    en => "Add a workflow",
  },
  NoWorkflowId => {
    fr => "Pas d'Id de workflow",
    en => "No workflow Id",
  },
  UnknownWorkflow => {
    fr => "Workflow inconnu : %workid",
    en => "Unknown workflow : %workid",
  },
  ModifyThisWorkflow => {
    fr => "Modifier ce workflow",
    en => "Modify this workflow",
  },
  Internal => {
    fr => "Interne",
    en => "Internal",
  },
  External => {
    fr => "Externe",
    en => "External",
  },
  AddThisRole => {
    fr => "Ajouter ce rôle",
    en => "Add this role",
  },
  Workflow => {
    fr => "Workflow",
    en => "Workflow",
  },
  ActiveWorkflows=> {
    fr => "Workflows actifs",
    en => "Active workflows",
  },
  BadAction => {
    fr => "Action inconnue : %action",
    en => "Unknown action : %action",
  },
  ActionsToApprove => {
    fr => "Actions à approuver",
    en => "Actions to approve",
  },
  ActionsToBeApproved => {
    fr => "Vos actions en attente d'approbation",
    en => "Your actions waiting to be approved",
  },
  NothingRelevant => {
    fr => "Rien à signaler",
    en => "Nothing relevant",
  },
  NothingInteresting => {
    fr => "Rien d'intéressant pour vous ici",
    en => "Nothing interesting for you here",
  },
  WaitingForApproval => {
    fr => "En attente d'approbation",
    en => "Waiting for approval",
  },

  Approvals => {
    fr => "Approbations nécessaires",
    en => "Necessary approvals",
  },
  ActionNeedApproval => {
    fr => "Cette action doit être approuvée",
    en => "This action is subject to independant approval",
  },
  ExternalApprovalAskDone => {
    fr => "Votre requête a été soumise à qui de droit",
    en => "Your request has been submitted",
  },
  ActionApprovalSent => {
    fr => "Votre requête a été soumise à qui de droit",
    en => "Your request has been submitted",
  },

  ApprovalExists => {
    fr => "Il y a déja une demande d'approbation de cette action pour ".
          "cette personne dans cette unité. Demande effectuée par %userid le %date",
    en => "There is already an approval request for this action, for ".
          "this person and this unit. Approval asked by %userid on %date",
  },
  
  ApprovalAlreadySigned => {
    fr => "Quelqu'un avec le rôle %role à déjà approuvé cette requête",
    en => "Someone with with role %role already approved this request",
  },
  
  Approval => {
    fr => "Approbation du %objtype %objname",
    en => "%objtype %objname  approval",
  },
  AlreadyApproved => {
    fr => "Déjà approuvé par un %roles",
    en => "Already approved by one %roles",
  },

  ReasonForApproval => {
    fr => "Vous êtes titulaire du <b>%object</b>",
    en => "You have <b>%object</b>",
  },

  Recipient => {
    fr => "Recipiendaire",
    en => "Recipient",
  },
  MyDecision => {
    fr => "Ma décision",
    en => "My décision",
  },
  Accept => {
    fr => "J'accepte",
    en => "I accept",
  },
  Deny => {
    fr => "Je refuse",
    en => "I refuse",
  },
  Decision => {
    fr => "Decision",
    en => "Decision",
  },
  BadDecision => {
    fr => "Décision invalide : %decision",
    en => "Invalid decision : %decision",
  },
  ApprovedDecision => {
    fr => "Accepté",
    en => "Approved",
  },
  DeniedDecision => {
    fr => "Refusé",
    en => "Denied",
  },
  State => {
    fr => "Etat",
    en => "State",
  },
  NothingToApprove => {
    fr => "Rien à approuver",
    en => "Nothing to approve",
  },
  #
  # Rights policy
  #
  ManageRightPolicy => {
    fr => "Gérer les autorisations par unité",
    en => "Manage by units policies",
  },
  ManageRightUnitPolicy => {
    fr => "Gestion des autorisations par unité",
    en => "Manage by units rights policy",
  },
  WhoHasThisRightExpl => {
    fr => "Voir qui a explicitement ce droit",
    en => "See who explicitly has this right",
  },
  WhoHasThisRightEffect => {
    fr => "Voir qui a effectivement ce droit",
    en => "See who actually has this right",
  },
  NobodyHasThisRight => {
    fr => "Personne n'a ce droit.",
    en => "Nobody has this right.",
  },
  PoliciesByUnits => {
    fr => "Autorisations par unités",
    en => "Autorisations by units",
  },
  Policy => {
    fr => "Policy",
    en => "Policy",
  },
  Policies => {
    fr => "Policies",
    en => "Policies",
  },
  AddRightPolicy => {
    fr => "Ajout d'une policy pour le droit '<b>%right</b>'",
    en => "Add a policy for right '<b>%right</b>'",
  },
  SuppressThisPolicy => {
    fr => "Supprimer cette policy",
    en => "Suppress this policy",
  },
  ManagerPerson => {
    fr => "SCIPER personne responsable",
    en => "SCIPER of manager",
  },
  InvalidManagerPerson => {
    fr => "SCIPER personne responsable invalide : %resp",
    en => "SCIPER of manager invalid : %resp",
  },
  AddThisAdminRole => {
    fr => "Ajouter ce rôle",
    en => "Add this role",
  },
  SuppressThisAdminRole => {
    fr => "Supprimer ce rôle",
    en => "Suppress this role",
  },
  AddThisStatus => {
    fr => "Ajouter ce statut",
    en => "Add this status",
  },
  SuppressThisStatus => {
    fr => "Supprimer ce statut",
    en => "Suppress this status",
  },
  AddThisClass => {
    fr => "Ajouter cette classe",
    en => "Add this class",
  },
  SuppressThisClass => {
    fr => "Supprimer cette classe",
    en => "Suppress this class",
  },
  HavingRight => {
    fr => "Personnes ayant le droit %right",
    en => "People having right %right",
  },
  ExplicitlyHavingRight => {
    fr => "Personnes ayant explicitement le droit %right",
    en => "People explicitly having right %right",
  },
  #
  # Roles
  #
  Role => {
    fr => "Rôle",
    en => "Role",
  },
  Roles => {
    fr => "Rôles",
    en => "Roles",
  },
  SeeTheRoles => {
    fr => "Voir les rôles",
    en => "See the roles",
  },
  RolesManagement => {
    fr => "Gestion des rôles",
    en => "Role management",
  },
  ActualRoles => {
    fr => "Rôles effectifs",
    en => "Actual roles",
  },
  InheritedRoles => {
    fr => "Rôles hérités",
    en => "Inherited roles",
  },
  ActualRolesInUnit => {
    fr => "Rôles effectifs dans %inunit",
    en => "Actual roles in %inunit",
  },
  InheritedRolesInUnit => {
    fr => "Rôles hérités dans %unit",
    en => "Inherited roles in %unit",
  },
  NoRole => {
    fr => "Vous devez spécifier le rôle",
    en => "You must specify the role",
  },
  UnknownRole => {
    fr => "Rôle inconnu : %role",
    en => "Unknown role : %role",
  },
  NoRoles => {
    fr => "Aucun rôle défini pour le type %type",
    en => "No role defined for unit type %type",
  },
  YourRoles => {
    fr => "Vos rôles",
    en => "Your roles",
  },
  ProtectedRole => {
    fr => "Vous ne pouvez pas donner ce rôle (protégé)",
    en => "You cannot grant this role (protected)",
  },
  ExplicitRolesInUnit => {
    fr => "Rôles explicites dans %inunit",
    en => "Explicit roles in %inunit",
  },
  RoleForbiddenForUnit => {
    fr => "Ce rôle n'est pas autorisé pour cette unité.",
    en => "This role is not authorized for this unit.",
  },
  AlreadyHasRole => {
    fr => "%pers est déjà titulaire de ce rôle pour cette unité",
    en => "%pers already has this role for this unit",
  },
  DefinedInUnit => {
    fr => "Défini dans l'unité <b>%detail</b>",
    en => "Defined in unit <b>%detail</b>",
  },
  ThanksToRole => {
    fr => "Grâce au rôle <b>%detail</b> dans <b>%detail2</b>",
    en => "Thanks to role  <b>%detail</b> in <b>%detail2</b>",
  },
  RemoveRoleForUnit => {
    fr => "Enlever le rôle spécifiquement pour %unit",
    en => "Remove this role specifically for %unit",
  },
  ConfirmGrantRole => {
    fr => "Voulez-vous vraiment %action le rôle %role à ".
          "%pers pour l'unité %unit ?",
    en => "Do you really want to %action role %role to/from %pers in unit %unit ?",
  },
  ManageRolesInUnit => {
    fr => "Gestion du rôle '<b>%role</b>' pour l'unité <b>%unit</b>",
    en => "Management of role '<b>%role</b>' in unit <b>%unit</b>",
  },
  ManageRolesForPerson => {
    fr => "Gestion du rôle '<b>%role</b>' pour <b>%pers</b>",
    en => "Management of role '<b>%role</b>' for <b>%pers</b>",
  },
  RightsManaged => {
    fr => "Droits gérés",
    en => "Rights managed",
  },
  AddARole => {
    fr => "Ajouter un rôle",
    en => "Add a role",
  },
  ConfirmDeleteRole => {
    fr => "Voulez-vous vraiment détruire le rôle <b>'%role'<b> ?",
    en => "Do you really want to delete role <b>'%role'<b> ?",
  },
  WarnRoleUsed => {
    fr => "Attention Le rôle %role est attribué à une %npers personnes.".
          " Il leur sera supprimé d'abord.",
    en => "Warning role %role is used by %npers persons, it will first be revoked.",
  },
  ModifyThisRole => {
    fr => "Modifier ce rôle",
    en => "Modify this role",
  },
  SuccessfullyModifyRole => {
    fr => "Rôle modifié avec succès.",
    en => "Role successfully modified.",
  },
  WhoHasThisRole => {
    fr => "Voir qui a ce rôle",
    en => "See who has this role",
  },
  UnitsWhereNobodyHasThisRole => {
    fr => "Unités où personne n'a ce rôle",
    en => "Units where nobody has this role",
  },
  UnitsWhereNobodyHasRole => {
    fr => "Unités où personne n'a le rôle %role",
    en => "Units where nobody has role %role",
  },
  NobodyHasThisRole => {
    fr => "Personne n'a ce rôle",
    en => "Nobody has this role",
  },
  PeopleWhoHasTheRole => {
    fr => "Personnes ayant le rôle '%role'",
    en => "People with role '%role'",
  },
  #
  # Properties
  #
  Property => {
    fr => "Propriété",
    en => "Property",
  },
  Properties => {
    fr => "Propriétés",
    en => "Properties",
  },
  NoProperty => {
    fr => "Vous devez spécifier la propriété",
    en => "You must specify the property",
  },
  UnknownProperty => {
    fr => "Propriété inconnue : %prop",
    en => "Unknown property : %prop",
  },
  PropertiesList => {
    fr => "Liste des propriétés",
    en => "List of properties",
  },
  AddAProperty => {
    fr => "Ajouter une propriété",
    en => "Add a property",
  },
  ModifyProperty => {
    fr => "Modifier la propriété %prop",
    en => "Modify property %prop",
  },
  ModifyThisProperty => {
    fr => "Modifier cette propriété",
    en => "Modify this property",
  },
  ModifyTheseProperties => {
    fr => "Modifier ces propriétés",
    en => "Modify these properties",
  },
  AddUnitPropPolicy => {
    fr => "Ajout d'une policy pour la propriété '<b>%prop</b>'",
    en => "Add a policy for property '<b>%prop</b>'",
  },
  AddPropClassPolicy => {
    fr => "Ajout d'une policy pour la propriété <b>%prop</b> ".
          "et la classe <b>%class</b>",
    en => "Add a policy for property <b>%prop</b> ".
          "and class <b>%class</b>",
  },
  ManagePropertyUnitPolicy => {
    fr => "Gestion des propriétés par unité",
    en => "Manage by units property policy",
  },
  ManagePropertyByUnit => {
    fr => "Propriétés '%prop' par unité",
    en => "Property '%prop' by unit",
  },
  ManagePropertyStatusPolicy => {
    fr => "Gestion des propriétés par statut",
    en => "Manage by property policy by status",
  },
  ManagePropertyByStatus => {
    fr => "Propriétés '%prop' par statut",
    en => "Property '%prop' by status",
  },
  ConfirmDeleteProperty => {
    fr => "Voulez-vous vraiment détruire la propriété %prop ?",
    en => "Do you really want to delete property %prop ?",
  },
  SeeTheListOfProperties => {
    fr => "Voir la liste des propriétés",
    en => "See the list of properties",
  },
  PropertiesOfAccred => {
    fr => "Propriétés de l'accréditation de %pers pour l'unité %unit",
    en => "Properties of accreditation of %pers in unit %unit",
  },
  DefaultOfParent => {
    fr => "Defaut du parent",
    en => "Default of parent",
  },
  DefaultPropertiesForUnit => {
    fr => "Propriétés par défaut pour l'unité %unit",
    en => "Default properties for unit %unit",
  },
  PolicyByStatus => {
    fr => "Politique d'attribution par statuts",
    en => "Policy by status",
  },
  PolicyByUnit => {
    fr => "Politique d'attribution par unités",
    en => "Policy by unit",
  },
  DefinedExplicitely => {
    fr => "Explicitement Défini",
    en => "Defined explicitely",
  },
  ForbiddenForUnit => {
    fr => "Interdit pour l'unité %unit",
    en => "Forbidden for unit %unit",
  },
  ForbiddenForStatus => {
    fr => "Interdit pour le statut '%status'",
    en => "Forbidden for status '%status'",
  },
  DefaultForUnit => {
    fr => "Défaut pour l'unité %unit",
    en => "Default for unit %unit",
  },
  DefaultForStatus => {
    fr => "Défaut pour le statut '%status'",
    en => "Default for status '%status'",
  },
  IDontKnow => {
    fr => "Je ne sais pas",
    en => "I don't know",
  },
  #
  # Positions
  #
  Position => {
    fr => "Fonction",
    en => "Position",
  },
  Positions => {
    fr => "Fonctions",
    en => "Positions",
  },
  NoPosition => {
    fr => "Vous devez spécifier la fonction",
    en => "You must give the position",
  },
  UnknownPosition => {
    fr => "Fonction inconnue : %pos",
    en => "Unknown position : %pos",
  },
  PositionAlreadyExists => {
    fr => "Fonction déjà existante : %pos",
    en => "Position already exists : %pos",
  },
  InvalidPositionId => {
    fr => "Id de fonction invalide : %posid",
    en => "Invalid position Id : %posid",
  },
  UnusedPosition => {
    fr => "Cette fonction n'est pas utilisée.",
    en => "This position is not used.",
  },
  ModifyThisPosition => {
    fr => "Modifier cette fonction",
    en => "Modify this position",
  },
  DeleteIt => {
    fr => "La détruire",
    en => "Destroy it",
  },
  UnableToDeletePosition => {
    fr => "Impossible de supprimer cette fonction",
    en => "Unable to delete this position",
  },
  PositionUsedBy => {
    fr => "Fonction utilisée par :",
    en => "Position used by :",
  },
  PositionIsUsedBy => {
    fr => "La fonction '%pos' est utilisée par :",
    en => "Position %pos is used by :",
  },
  TransferToPosition => {
    fr => "Transférer ces personnes sur la fonction suivante :",
    en => "Transfer these people to the following position :",
  },
  SeeListOfPositions => {
    fr => "Voir la liste des fonctions",
    en => "See the list of positions",
  },
  ListPositions => {
    fr => "Liste des %number fonctions",
    en => "List of %number positions",
  },
  ListPositionsInUnit => {
    fr => "Fonctions dans l'unité %unit (%nombre)",
    en => "List of positions in unit %unit (%number)",
  },
  SeeWhoHasThisPosition => {
    fr => "Voir qui a cette fonction",
    en => "See who has this position",
  },
  AddAPosition => {
    fr => "Ajouter une fonction",
    en => "Add a position",
  },
  AddPosition => {
    fr => "Ajout d'une fonction",
    en => "Add an position",
  },
  AddPositionPolicy => {
    fr => "Ajout d'une policy pour la fonction '<b>%position</b>'",
    en => "Add a policy for position '<b>%position</b>'",
  },
  ModifyPosition => {
    fr => "Modification d'une fonction",
    en => "Modify a position",
  },
  ManagePositionPolicies => {
    fr => "Gérer les autorisations par unité",
    en => "Manage by units position policies",
  },
  InvalidPosition => {
    fr => "Fonction invalide : %fct",
    en => "Invalid position : %fct",
  },
  PositionAllowedInUnit => {
    fr => "Fonctions autorisées dans %unit",
    en => "Positions allowed in %unit",
  },
  PositionTempRemoved => {
    fr => "Fonction supprimée temporairement",
    en => "Fonction temporarily suppressed",
  },
  GiveThePosition => {
    fr => "Précisez la fonction",
    en => "Specify the position",
  },
  PositionForUnit => {
    fr => "l'unité %uacro (%uname)",
    en => "unit %uacro (%uname)",
  },
  AllPositionsInsideEPFL => {
    fr => "Toutes les fonctions sont autorisées pour l'intérieur de l'EPFL",
    en => "All positions allowed inside EPFL",
  },
  ModifyPositionsInUnit => {
    fr => "Modifier les fonctions autorisées pour cette unité",
    en => "Modify positions allowed in this unit",
  },
  ModificationOfPositionsInUnit => {
    fr => "Modification des fonctions pour %unit",
    en => "Modification of positions allowed in unit %unit",
  },
  ConfirmRemPosition => {
    fr => "Êtes-vous sûr de vouloir détruire la fonction %pos ?",
    en => "Do you really want to remove position %pos ?",
  },
  Restricted => {
    fr => "Restreint",
    en => "Restricted",
  },
  Free => {
    fr => "Libre",
    en => "Free",
  },
  #
  # Actions
  #
  Action => {
    fr => "Action",
    en => "Action",
  },
  Actions => {
    fr => "Actions",
    en => "Actions",
  },
  SeeTheActions => {
    fr => "Voir les actions faites dans Accred",
    en => "See the actions done in Accred",
  },
  ActionsOrderedByPeople => {
    fr => "Consulter les actions faites dans Accred classées par personnes",
    en => "See the actions done in Accred by people",
  },
  ActionsOrderedByUnit => {
    fr => "Consulter les actions faites dans Accred classées par unités",
    en => "See the actions done in Accred by units",
  },
  ActionsInUnit => {
    fr => "Actions faites dans l'unité %unit",
    en => "Actions done in unit %unit",
  },
  ActionsDoneByPeople => {
    fr => "'%action' fait par %pers",
    en => "'%action' done by %pers",
  },
  ActionsDoneInUnit => {
    fr => "'%action' faites dans l'unité %unit",
    en => "'%action' done in unit %unit",
  },
  NoActionInPeriod => {
    fr => "Aucune action durant cette période.",
    en => "No actions during this period.",
  },
  NoActivityForPerson => {
    fr => "Aucune activité détectée chez cette personne.",
    en => "No actions for this person.",
  },
  NoActivityForUnit => {
    fr => "Aucune activité détectée dans cette unité.",
    en => "No actions for this person for this unit.",
  },
  Authors => {
    fr => "Auteurs",
    en => "Authors",
  },
  NumberOfTimes => {
    fr => "Nombre de fois",
    en => "Number of times",
  },
  LastDay => {
    fr => "Dernières 24 heures",
    en => "Last 24 hours",
  },
  LastWeek => {
    fr => "Dernière semaine",
    en => "Last week",
  },
  LastMonth => {
    fr => "Dernier mois",
    en => "Last month",
  },
  Last2Month => {
    fr => "Dernier 2 mois",
    en => "Last 2 month",
  },
  Last3Month => {
    fr => "Dernier 3 mois",
    en => "Last 3 month",
  },
  Last6Month => {
    fr => "Dernier 6 mois",
    en => "Last 6 month",
  },
  LastYear => {
    fr => "Dernière année",
    en => "Last year",
  },
  Ordering => {
    fr => "Classement",
    en => "Ordering",
  },
  ByPeople => {
    fr => "Par personne",
    en => "By person",
  },
  ByUnit => {
    fr => "Par unité",
    en => "By unit",
  },
  #
  # Sciper
  #
  PersonsData => {
    fr => "Données Sciper",
    en => "Sciper data",
  },
  PersonId => {
    fr => "Numéro Sciper",
    en => "Sciper number",
  },
  SearchCreatePerson => {
    fr => "Recherche/Création de Numéro SCIPER",
    en => "Search/Creation of Sciper Number",
  },
  SearchInPersonsDB => {
    fr => "Recherche de personnes dans la base Sciper",
    en => "Searching for a person in Sciper DB",
  },
  AddInPersonsDB => {
    fr => "Ajout d'une personne dans Sciper",
    en => "Add a person in Sciper",
  },
  PersonsDBModifyPerson => {
    fr => "Modification d'une personne dans Sciper",
    en => "Modify a person in Sciper",
  },
  ModifyThisPerson => {
    fr => "Modifier cette personne dans Sciper",
    en => "Modify this person in Sciper",
  },
  MustGiveName => {
    fr => "Recherche (vous devez spécifier le numéro Sciper ou au moins ".
          "le nom ou au moins le prénom et la date de naissance).",
    en => "Search (you must give the Sciper number or at least the name, ".
          "or at least firstname and birth date).",
  },
  MustGiveNameError => {
    fr => "Pour effectuer cette recherche, vous devez spécifier au moins le nom ".
          "ou au moins le prénom et la date de naissance.",
    en => "To do this search, you must give at least the name, or the firstname ".
          "and birth date",
  },
  AlreadyInPersonsDB => {
    fr => "Cette entrée (%pers, %datenaiss, %sexe) constitue un doublon ".
          "parfait dans la base Sciper sous le numéro %scip",
    en => "An identical person (%pers, %datenaiss, %sexe) already ".
          "exists in Sciper with number %scip",
  },
  ScipBadBirthDate => {
    fr => "Impossible d'attribuer le numéro Sciper : mauvaise date de naissance.",
    en => "Unable to attribute Sciper number : bad birth date.",
  },
  ScipNameIsUppercase => {
    fr => "Impossible d'attribuer le numéro Sciper : nom en majuscule.",
    en => "Unable to attribute Sciper number : name ia entirely uppercase.",
  },
  ScipBadStatus => {
    fr => "Impossible d'attribuer le numéro Sciper : status = %status.",
    en => "Unable to attribute Sciper number : status = %status.",
  },
  ScipAddedSuccess => {
    fr => "Numéro Sciper %persid attribué avec succès.",
    en => "Sciper number %persid attributed.",
  },
  DoubleCheckPersonData => {
    fr => "Attention, vérifiez bien que l'orthographe est correcte et correspond ".
          "parfaitement aux papiers d'identité de la personne (y compris les ".
          "éventuels accents). Dès qu'une personne est entrée dans la base Sciper, ".
          "toutes les applications utilisent ses données et il est très difficile ".
          "de revenir en arrière. Deux vérifications valent mieux qu'une.",
    en => "Be careful, check carefully that the person data matches exactly what is on ".
          "the official ID card, including accents. As soon as a person ".
          "is entered in the Sciper database, all applications will use the data ".
          "and it can be very difficult to go make correction.",
  },
  CheckCase => {
    fr => "Sauf exception, mettez la première lettre du nom et du prénom en majuscule ".
          "et les autres lettres en minuscules.",
    en => "Except for exceptional cases, put the first letter of name and firstname ".
          "in uppercase and other letters lowercase.",
  },
  ConsiderPersonExist => {
    fr => "D'autre part la personne suivante existe déjà",
    en => "Consider that the following person already exists",
  },
  ThatLooksLikeYourNewPerson => {
    fr => "Qui ressemble fort à votre nouvelle personne.",
    en => "Who looks very much like your new person.",
  },
  ConsiderPersonsExists => {
    fr => "D'autre part les personnes suivantes existent déjà",
    en => "Consider that the following persons already exist",
  },
  ThatLooksLikeYourNewPersonPlur => {
    fr => "Qui ressemblent fort à votre nouvelle personne.",
    en => "That looks very much like your new person.",
  },
  ReallyCreatePerson => {
    fr => "Voulez-vous vraiment vraiment créer un numéro Sciper ".
          "pour la personne suivante ?",
    en => "Do you really want to add the following person in Sciper ?",
  },
  ChooseDay => {
    fr => "Jour",
    en => "Day",
  },
  ChooseMonth => {
    fr => "Mois",
    en => "Month",
  },
  ChooseYear => {
    fr => "Année",
    en => "Year",
  },
  ExactResults => {
    fr => "%num résultats exacts",
    en => "%num exact results",
  },
  ApproxResults => {
    fr => "%num résultats approchants",
    en => "%num similar results",
  },
  ClickOnPersonId => {
    fr => "Cliquez sur le numéro sciper de la personne pour la sélectionner",
    en => "Click on Sciper number to select it",
  },
  NoMatchInPersonsDB => {
    fr => "Aucune personnes trouvée dans Sciper.",
    en => "No match found in Sciper.",
  },
  NoMatchingPerson => {
    fr => "Aucune de ces personnes ne correspond à ma recherche, ".
          "ajouter ma personne dans Sciper",
    en => "None of those persons fit my search, add my person in Sciper",
  },
  EnterMyPersonInPersonsDB => {
    fr => "Entrer ma personne dans SCIPER",
    en => "Enter my person in Sciper",
  },
  RedoSearch => {
    fr => "Recommencer la recherche",
    en => "Redo search",
  },
  Mister => {
    fr => "Monsieur",
    en => "Mr",
  },
  Miss => {
    fr => "Madame",
    en => "Mrs",
  },
  BornOn => {
    fr => "né le",
    en => "born on",
  },
  BornOnf => {
    fr => "née le",
    en => "born on",
  },
  TestMode => {
    fr => "Impossible de faire ça en mode test",
    en => "Cannot do this in test mode",
  },
  MustGiveAllFields => {
    fr => "Vous devez spécifier tous les champs",
    en => "All fields must be completed",
  },
  #
  # Deputies
  #
  Deputations => {
    fr => "Suppléances",
    en => "Deputations",
  },
  NoDeputation => {
    fr => "Pas de suppléance",
    en => "No deputation",
  },
  Holder => {
    fr => "Titulaire",
    en => "Holder",
  },
  Deputy => {
    fr => "Suppléant",
    en => "Deputy",
  },
  DeputyOf => {
    fr => "Suppléant de",
    en => "Deputy of",
  },
  Deputies => {
    fr => "Suppléants",
    en => "Deputies",
  },
  YourDeputies => {
    fr => "Vos suppléances",
    en => "Your deputies",
  },
  YourDeputations => {
    fr => "Vos remplacements",
    en => "Your replacements",
  },
  AlreadyDeputy => {
    fr => "%pers est déjà votre suppléant",
    en => "%pers is already your deputy",
  },
  NoDeputy => {
    fr => "Aucun suppléant",
    en => "No deputy defined",
  },
  WhenAbsent => {
    fr => "Quand je suis absent",
    en => "When I am absent",
  },
  DateRange => {
    fr => "Période",
    en => "Date range",
  },
  Permanent => {
    fr => "Permanent",
    en => "Permanent",
  },
  ChangeDates => {
    fr => "Changer la période",
    en => "Change dates",
  },
  
  ChoosePerson => {
    fr => "Choisissez une personne",
    en => "Choose a person",
  },
  FromTo => {
    fr => "Du %from au %to",
    en => "From %from to %to",
  },
  
  #
  # Services
  #
  Service => {
    fr => "Service",
    en => "Service",
  },
  Services => {
    fr => "Services",
    en => "Services",
  },
  NoService => {
    fr => "Vous devez spéficier un service",
    en => "You must specify a service",
  },
  UnknownService => {
    fr => "Service inconnu : %serv",
    en => "Unknown service : %serv",
  },
  AddService => {
    fr => "Ajout d'un service",
    en => "Add a service",
  },
  SearchService => {
    fr => "Recherche d'un service",
    en => "Search for a service",
  },
  ServiceName => {
    fr => "Nom du service",
    en => "Service name",
  },
  ModificationOfService => {
    fr => "Modification du service %serv",
    en => "Modification of service %serv",
  },
  ModifyThisService => {
    fr => "Modifier ce service",
    en => "Modify this service",
  },
  NoNameAndDesc => {
    fr => "Vous devez donner le nom et le description du service",
    en => "You must give the name and description of the service",
  },
  SuccessfullyCreatedService => {
    fr => "Service <b>%name</b> créé avec succès, le numéro Sciper est <b>%scip</b>.",
    en => "Service <b>%name</b> successfully created, Sciper number is <b>%scip</b>.",
  },
  AccreditThisServiceInUnit => {
    fr => "Accréditer ce service dans l'unité %unit",
    en => "Accredit this service in unit %unit",
  },
  #
  # Summary
  #
  SummaryDescription => {
    fr => "Ce tableau présente les attributions de droits et de rôles dont vous êtes ".
          "personnellement responsable. Si vous avez délégué cette gestion dans une ".
          "unité de niveau inférieur, elle n'y figurera pas. Par exemple, si vous êtes ".
          "responsable informatique d'un institut, vous ne verrez pas les droits associés ".
          "pour les labos qui ont leur propre responsable informatique.",
    en => "This interface presents rights and roles attributions for which you are ".
          "personnally responsible. If you delegated this management to sub-units, ".
          "you won't see them. For example, if you are IT manager in an institute, ".
          "you won't see rights associated for labs that have their own IT manager.",
  },
  YouDontManageAnyRight => {
    fr => "Vous n'êtes gestionnaire d'aucun droit",
    en => "You don't manage any rights",
  },
  YouDontManageAnyRole => {
    fr => "Vous n'êtes gestionnaire d'aucun role",
    en => "You don't manage any roles",
  },
  YouDontManageAnyRightOrRole => {
    fr => "Vous n'êtes gestionnaire d'aucun droit ou rôle",
    en => "You don't manage any rights or role",
  },
  ManagementOf => {
    fr => "Gestion des ",
    en => "Management of",
  },
  #
  # logs
  #
  SearchForCulprit => {
    fr => "Recherche d'un coupable",
    en => "Search for the culprit",
  },
  CommitedAction => {
    fr => "Action commise",
    en => "Committed action",
  },
  ChooseAnAction => {
    fr => "Choisir une action",
    en => "Choose an action",
  },
  IdOfPerson => {
    fr => "Sciper de la personne concernée",
    en => "Sciper of the person",
  },
  AtLeastOneCretirium => {
    fr => "Vous devez spécifier au moins un critère",
    en => "You must give at least one criterium",
  },
  IfNotYours => {
    fr => "Si pas le votre",
    en => "If not yours",
  },
  NoCorrespondingAction => {
    fr => "Aucune action correspondante",
    en => "No corresponding action",
  },
  ActionsOf => {
    fr => "Actions de %pers (%nactions)",
    en => "Actions of %pers (%nactions)",
  },
  AllEventsForPers => {
    fr => "Tout ce qui est arrivé à %pers",
    en => "All events concerning %pers",
  },
  NoEventForPers => {
    fr => "Aucun événement pour %pers",
    en => "No event for %pers",
  },
  RightAddition => {
    fr => "Ajout du droit <b>%right</b> dans l'unité <b>%unit</b>",
    en => "Addition of right <b>%right</b> in unit <b>%unit</b>",
  },
  RightRemoval => {
    fr => "Suppression du droit <b>%right</b> dans l'unité <b>%unit</b>",
    en => "Removal of right <b>%right</b> in unit <b>%unit</b>",
  },
  RoleAddition => {
    fr => "Ajout du rôle <b>%role</b> dans l'unité <b>%unit</b>",
    en => "Addition of role <b>%role</b> in unit <b>%unit</b>",
  },
  RoleRemoval => {
    fr => "Suppression du rôle <b>%role</b> dans l'unité <b>%unit</b>",
    en => "Removal of role <b>%role</b> in unit <b>%unit</b>",
  },
  ModifiedProperty => {
    fr => "Propriété modifiée",
    en => "Modified property",
  },
  OldValue => {
    fr => "Ancienne valeur",
    en => "Previous value",
  },
  NewValue => {
    fr => "Nouvelle valeur",
    en => "New value",
  },
  NoName => {
    fr => "(pas de nom)",
    en => "(no name)",
  },
  ModifiedField => {
    fr => "Champ modifié",
    en => "Modified field",
  },
  #
  # adminsofunits
  #
  AdminsOfUnitHelp => {
    fr => qq{
      <h3> Rôles et droits dans l'unité %unit </h3>
      Dans l'unité, ou dans une unité parente, certaines personnes bénéficient
      de privilèges gérés par l'application <b>Accred</b>.
      <dl>
        <dt> <b>Responsable accréditation</b> </dt>
        <dd>
          Un responsable accréditation a le droit de rattacher une personne à cette unité,
          de définir son statut et éventuellement de lui attribuer un ou des
          rôles particulier au sens Accred.
        </dd>
        <dt> <b>Rôles</b> </dt>
        <dd>
          Des applications sécurisées ne sont ouvertes qu'à certains rôles,
          par exemple seules les personnes qui ont le rôle de responsable
          informatique peuvent demander l'ouverture de machines sur Diode.
        </dd>
        <dt> <b>Droits</b> </dt>
        <dd>
          Si vous voulez disposer de certains droits (accès à la distribution
          de logiciels, demande de travaux etc.), il faut vous adresser à
          l'administrateur du droit correspondant dans votre unité.
        </dd>
      </dl>
      <br>
      Plus de renseignements:  <a href="http://accred.epfl.ch/">accred.epfl.ch</a>
      <br><br>
    },
    en => qq{
      <h3> Roles and rights in unit %unit </h3>
      In this unit or in parent units, certain people are granted privileges managed
      by the <b>Accred</b> application.
      <dl>
        <dt> <b> Accreditations' manager </b> </dt>
        <dd>
          Accreditations' managers can attach a person to units, define their status,
          and when necessary, grant them roles in these units.
        </dd>
        <dt> <b> Roles </b> </dt>
        <dd>
          Secured applications are accessible only to people with certain roles.
          For example, only persons having the 'IT manager' role, are able
          to request the accessibility of computers behind the Diode firewall.
        </dd>
        <dt> <b> Rights </b> </dt>
        <dd>
          If you need particular rights (for example, access to the software
          distribution system), you must ask the person having the role that
          manages this right in your unit.
        </dd>
      </dl>
      <br>
      More information :  <a href="http://accred.epfl.ch/">accred.epfl.ch</a>
      <br><br>
    },
  },
  NobodyContactAccred => {
    fr => "personne, voir un accréditeur.",
    en => "nobody, contact an accreditor.",
  },
  SeeRightsList => {
    fr => qq{
      consulter la liste des administrateurs
      et des personnes qui ont un droit pour l'unité %unit.
    },
    en => qq{
      Consult the list of administrators and people having a right in unit %unit.
    },
  },
  SelectARight => {
    fr => "Sélectionner un <b>droit</b> :",
    en => "Select a <b>right</b> :",
  },
  RightsDetails => {
    fr => "Détails du droit",
    en => "Right details",
  },
  PersonsHavingRightForUnit => {
    fr => "Personnes qui ont ce droit pour l'unité %unit",
    en => "Persons with this right for unit %unit",
  },
  #
  #
  #
  LogoutMessage => {
    fr => "Session terminée, <a href=\"%href\">À bientôt</a>.",
    en => "Session terminated, <a href=\"%href\">See you soon</a>.",
  },
  BadUser => {
    fr => "Vous êtes connecté avec l'utilisateur %user qui".
          " n'est pas autorisé à utiliser Accred.",
    en => "You are connected as user %user who is not authorized to use Accred.",
  },
  #
  # Notifications
  #
  Notifications => {
    fr => "Notifications",
    en => "Notifications",
  },
  #
  # Auditing.
  #
  Auditing => {
    fr => "Audit",
    en => "Auditing",
  },
  CForFund => {
    fr => "CF ou fonds",
    en => "CF or fund",
  },
  EnterPersonAndDate => {
    fr => "Entrez le nom de la personne ainsi <br>que la date de référence (à partir du 1.5.2016)",
    en => "Enter the person name with the reference date (after 5.1.2016)",
  },
  MustEnterPerson => {
    fr => "Vous devez spécifier le nom de la personne",
    en => "You must specify the person name",
  },
  EnterCFAndDate => {
    fr => "Entrez le CF ou le fond ainsi que la <br>date de référence (à partir du 1.5.2016)",
    en => "Enter the CF or fund with the reference date (after 5.1.2016)",
  },
  MustEnterCF => {
    fr => "Vous devez spécifier le CF ou le fond",
    en => "You must specify the CF or fund number",
  },
  MustEnterDate => {
    fr => "Vous devez spécifier la date",
    en => "You must specify the date",
  },
  DateTooEarly => {
    fr => "%date : date trop ancienne, avant la reprise du registre des ".
          "signatures dans Accred",
    en => "%date : too early, before management of signature register by Accred",
  },
  AllRightsInUnitAtDate => {
    fr => "Tous les droits de signature dans l'unité %unit le %date",
    en => "All signature rights in unit %unit at %date",
  },
  #
  # CSRF errors.
  #
  NoCSRFKeyFile => {
    fr => "Erreur interne : pas de fichier de clé CSRD.",
    en => "Internal error : no CSRF key file.",
  },
  NoCSRFToken => {
    fr => "Clé CSRF manquante.",
    en => "No CSRF token.",
  },
  BadCSRFToken => {
    fr => "Clé CSRF invalide.",
    en => "Bad CSRF token.",
  },
  ExpiredCSRFToken => {
    fr => "Clé CSRF expirée.<br>".
          "Rechargez la page pour corriger le problème.",
    en => "Expired CSRF token<br>".
          "Reload the page to fix the problem.",
  },
  NoCryptoModule => {
    fr => "Erreur de chargement du module de crypto",
    en => "Unable to load crypto module",
  },

};

$months = {
  fr => [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ],
  en => [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ],
};

$shortmonths = {
  fr => [
    'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jui',
    'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
  ],
  en => [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ],
};

sub msg {
  my ($key, @args) = @_;
  $language ||= 'en';
  unless ($messages->{$key}) {
    my ($pkg, $file, $line) = caller;
    warn "Messages: No message for key '$key' in $file at line $line\n";
    return "msg for $key"; 
  }
  my $msg = $messages->{$key}->{$language};
  foreach my $arg (@args) {
    $msg =~ s/(%\w+)/$arg/;
  }
  return $msg;
}

sub setlanguage {
  my $req = shift;
  $req->{language} ||= $defaultlang;
  $language = $req->{language};
}

sub setlanguage_full {
  my $req = shift;
  $req->{language} ||= $defaultlang;
  $language = $req->{language};
  my $callpkg = caller (0);
  no strict 'refs';
  foreach my $var (@pubvars) {
    *{$callpkg."::$var"} = \$messages->{$var}->{$language};
  }
  use strict 'refs';
  return;
}

1;























