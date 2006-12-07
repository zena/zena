// ** I18N

// Calendar EN language
// Author: Mihai Bazon, <mihai_bazon@yahoo.com>
// Encoding: any
// Distributed under the same terms as the calendar itself.

// For translators: please use UTF-8 if possible.  We strongly believe that
// Unicode is the answer to a real internationalized world.  Also please
// include your contact information in the header, as can be seen above.

// full day names
Calendar._DN = new Array
("Dimanche",
 "Lundi",
 "Mardi",
 "Mercredi",
 "Jeudi",
 "Vendredi",
 "Samedi",
 "Dimanche");

// Please note that the following array of short day names (and the same goes
// for short month names, _SMN) isn't absolutely necessary.  We give it here
// for exemplification on how one can customize the short day names, but if
// they are simply the first N letters of the full name you can simply say:
//
//   Calendar._SDN_len = N; // short day name length
//   Calendar._SMN_len = N; // short month name length
//
// If N = 3 then this is not needed either since we assume a value of 3 if not
// present, to be compatible with translation files that were written before
// this feature.

// Using first 3 letters

// First day of the week. "0" means display Sunday first, "1" means display
// Monday first, etc.
Calendar._FD = 0;

// full month names
Calendar._MN = new Array
("Janvier",
 "Février",
 "Mars",
 "Avril",
 "Mai",
 "Juin",
 "Juillet",
 "Août",
 "Septembre",
 "Octobre",
 "Novembre",
 "Décembre");

// short month names
Calendar._SMN = new Array
("Jav",
 "Fév",
 "Mar",
 "Avr",
 "Mai",
 "Jui",
 "Jul",
 "Aoû",
 "Sep",
 "Oct",
 "Nov",
 "Déc");

// tooltips
Calendar._TT = {};
Calendar._TT["INFO"] = "À propos ...";

Calendar._TT["ABOUT"] =
"Sélection de Date/Heure DHTML\n" +
"(c) dynarch.com 2002-2005 / Author: Mihai Bazon\n" + // don't translate this this ;-)
"adapté à Rails et Zena: Gaspard Bucher\n" +
"Pour la dernière version: http://www.dynarch.com/projects/calendar/\n" +
"Distribué sous licence GNU LGPL. Voir http://gnu.org/licenses/lgpl.html pour les détails." +
"\n\n" +
"Sélection de date:\n" +
"- Utiliser les boutons \xab et \xbb pour choisir l'année\n" +
"- Utiliser les boutons " + String.fromCharCode(0x2039) + " et " + String.fromCharCode(0x203a) + " pour choisir le mois\n" +
"- Garder le bouton pressé sur un des boutons ci-dessus pour une sélection rapide.";
Calendar._TT["ABOUT_TIME"] = "\n\n" +
"Sélection de l'heure:\n" +
"- Cliquer sur n'importe quelle partie de l'heure pour l'augmenter\n" +
"- ou Shift-cliquer pour la diminuer\n" +
"- ou cliquer-déplacer pour une sélection rapide.";

Calendar._TT["PREV_YEAR"] = "Année préc. (presser pour le menu)";
Calendar._TT["PREV_MONTH"] = "Mois préc. (presser pour le menu)";
Calendar._TT["GO_TODAY"] = "Aller aujourd'hui";
Calendar._TT["NEXT_MONTH"] = "Mois suivant (presser pour le menu)";
Calendar._TT["NEXT_YEAR"] = "Année suivante (presser pour le menu)";
Calendar._TT["SEL_DATE"] = "Sélectionner la date";
Calendar._TT["DRAG_TO_MOVE"] = "Tirer-déplacer";
Calendar._TT["PART_TODAY"] = " (ajourd'hui)";

// the following is to inform that "%s" is to be the first day of week
// %s will be replaced with the day name.
Calendar._TT["DAY_FIRST"] = "Afficher %s en premier";

// This may be locale-dependent.  It specifies the week-end days, as an array
// of comma-separated numbers.  The numbers are from 0 to 6: 0 means Sunday, 1
// means Monday, etc.
Calendar._TT["WEEKEND"] = "0,6";

Calendar._TT["CLOSE"] = "Fermer";
Calendar._TT["TODAY"] = "Ajourd'hui";
Calendar._TT["TIME_PART"] = "(Shift-)Cliquer ou glisser pour modifier";

// date formats
Calendar._TT["DEF_DATE_FORMAT"] = "%d.%m.%Y %H:%M";
Calendar._TT["TT_DATE_FORMAT"] = "%d.%m.%Y";
Calendar._TT["FIRST_DAY"] = 1;

Calendar._TT["WK"] = "sem";
Calendar._TT["TIME"] = "Heure:";
