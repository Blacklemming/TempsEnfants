# Temps enfants — version 1.2
# Grandement généré par ChatGPT !

Contrôle parental local, sans cloud, compte supplémentaire, abonnement ou connexion Internet. Pour Windows 10/11 64 bits avec Windows PowerShell 5.1 et le Planificateur de tâches disponibles. Les sources sont fournies : scripts PowerShell et petit composant C# compilé automatiquement en mémoire avec les outils Windows, sans installation de compilateur.

Requis pour fonctionner :
- les comptes enfants à superviser n'ont pas le privilège administrateur.
- le logiciel s'installe depuis un compte administrateur.

## Installation sur chaque ordinateur

1. Décompressez **tout** le ZIP dans un dossier local (ou copiez tous les fichiers dans un dossier local, faites le sous votre session administrateur).
2. Depuis votre compte administrateur, double-cliquez sur **Installer.cmd** et acceptez la demande Windows de droits administrateur.
3. Le panneau s’ouvre. Réglez les heures et minutes pour chaque jour.
4. Cochez **Activer le contrôle parental**, puis cliquez sur **Enregistrer les réglages**.
5. Vérifiez que le panneau indique **Contrôle actif — agent en fonctionnement**.

Le contrôle est volontairement désactivé à la première installation. Exemple prérempli : lundi 0 h, mardi 1 h, mercredi 2 h, jeudi et vendredi 1 h, samedi et dimanche 3 h.

## Utilisation quotidienne

- Ouvrez le raccourci **Temps enfants** sur le Bureau pour modifier les limites et consulter la consommation. **Panneau.cmd** ouvre également le panneau après installation.
- Les droits administrateur sont nécessaires pour ouvrir le panneau. Fermer le panneau n’arrête pas le contrôle.
- Un même planning s’applique à tous les comptes non administrateurs, avec **un compteur distinct par compte et par ordinateur**. Plusieurs comptes d’un même enfant ont donc des quotas distincts.
- **0 h signifie aucune utilisation autorisée**, et 24 h 00 correspond à une journée entière. Les nouveaux réglages prennent effet en quelques secondes, sans remettre à zéro le temps déjà consommé.
- Pour interrompre le contrôle, décochez son activation puis enregistrez. Le temps de cette pause n’est pas compté ; les compteurs déjà consommés sont conservés.
- Les comptes apparaissent dans le tableau après avoir été détectés pendant que le contrôle est activé. Le tableau montre la consommation du jour, avec les minutes entières.

## Comptage et fermeture

Le temps est réservé par tranches de cinq secondes lorsqu’une session est active, même sans activité clavier/souris et même avec l’écran verrouillé. La veille, l’arrêt du PC et les sessions déconnectées ne consomment pas de nouvelles tranches. Le changement d’utilisateur met normalement l’ancienne session en état déconnecté. Un simple verrouillage ne met donc pas le compteur en pause.

Le compteur est sauvegardé sur disque et survit aux redémarrages et reconnexions. Chaque date locale possède son propre compteur ; à minuit, le quota du nouveau jour s’applique. Le petit arrondi des tranches peut compter jusqu’à cinq secondes de trop à une interruption. Le délai de boucle et les appels Windows peuvent aussi décaler légèrement l’échéance : ce n’est pas un chronomètre à la seconde exacte.

Un avertissement Windows est envoyé lorsqu’il reste au plus cinq minutes. À l’échéance, le logiciel demande la **fermeture de session**, ce qui ferme les applications : **le travail non enregistré peut être perdu**. Une session reconnectée avec un quota épuisé sera de nouveau fermée lors du contrôle suivant, habituellement sous cinq secondes. Ce logiciel ne bloque pas l’écran de connexion avant l’ouverture d’une session. Avec un quota de zéro, il n’y a pas de délai d’avertissement.

Le logiciel fonctionne sous le compte système Windows et démarre automatiquement. Une relance est prévue chaque minute si l’agent s’arrête. L’installation ne modifie pas la stratégie d’exécution PowerShell globale.

## Vérification initiale conseillée

Avant l’utilisation quotidienne, choisissez un compte standard sans travail ouvert. Fixez le quota du jour à une minute, activez le contrôle et ouvrez ce compte. Vérifiez l’avertissement et la fermeture de session, puis revenez à votre compte administrateur et remettez le quota souhaité. La minute du test reste consommée pour ce compte aujourd’hui.

## Désinstallation

Double-cliquez sur **Desinstaller.cmd**, acceptez les droits administrateur puis confirmez. Cela arrête l’agent, supprime sa tâche automatique et le raccourci du Bureau. Les fichiers et compteurs restent dans `C:\Program Files\TempsEnfants` sur une installation Windows habituelle. Vous pouvez ensuite supprimer ce dossier manuellement avec vos droits administrateur. Une réinstallation conserve ces données si le dossier existe encore.
