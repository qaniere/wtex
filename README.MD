# Wtex

Un utilitaire en Go qui surveille un fichier `.tex` et déclenche automatiquement `pdflatex` à chaque modification, en redirigeant la sortie dans un fichier de log et n’affichant les détails que si une erreur survient (ou toujours en mode verbeux).

## Prérequis

* **Go** (version récente) installé et disponible dans le PATH.
* **pdflatex** (distribué avec une distribution TeX, par exemple TeX Live ou MikTeX) installé et dans le PATH.

## Installation

1. Clonez ou téléchargez ce projet.
2. Rendez `setup.sh` exécutable si nécessaire :

   ```bash
   chmod +x setup.sh
   ```
3. Lancez le script d’installation :

   ```bash
   ./setup.sh
   ```

   Cela génère le fichier `wtexwatch.go`, initialise le module Go, récupère la dépendance `fsnotify`, et compile le binaire `wtexwatch`.

Après exécution, vous obtenez :

* `wtexwatch.go` (source)
* `wtexwatch` (binaire exécutable)

## Utilisation

Exécutez :

```bash
./wtexwatch [-v] chemin/vers/fichier.tex
```

* `-v`: mode verbeux. Affiche la sortie complète de la commande `pdflatex` à chaque compilation.
* Sans `-v`, la sortie de `pdflatex` est redirigée vers `/tmp/wtex.log`. Si la compilation réussit, seul un message court `OK` est affiché. En cas d’erreur, le contenu du log est affiché.

### Exemple

```bash
./wtexwatch mondocument.tex
```

Surveille `mondocument.tex` : dès que vous enregistrez des modifications, `pdflatex -interaction=nonstopmode mondocument.tex` est exécuté.

## Comportement détaillé

* Vérification que le fichier `.tex` existe.
* Vérification que `pdflatex` est accessible.
* Surveillance du répertoire contenant le fichier pour détecter les événements de type création ou écriture sur le fichier ciblé.
* Débounce de 500ms : si plusieurs sauvegardes rapides interviennent, une seule compilation est lancée après la série de modifications.
* La sortie de `pdflatex` est capturée dans `/tmp/wtex.log`. En mode non verbeux, seule une notification en cas de succès (`OK`) ou l’affichage du log en cas d’erreur. En mode verbeux, le log complet est affiché à chaque compilation.

## Personnalisation

* **Chemin du log** : actuellement fixé à `/tmp/wtex.log` dans le code. Vous pouvez modifier la variable `logPath` dans `wtexwatch.go` si besoin.
* **Délais de debounce** : fixé à 500ms. Ajustez `debounceDelay` dans `wtexwatch.go` pour réagir plus ou moins vite.
* **Support multi-fichiers** : par défaut, l’outil surveille un seul fichier passé en argument. Vous pouvez étendre le code pour surveiller plusieurs fichiers ou même un répertoire entier.
* **Options pdflatex** : le code utilise `-interaction=nonstopmode`. Si vous souhaitez d’autres options (par exemple `-shell-escape`), modifiez la commande dans `runPdflatex`.
* **Logs permanents** : pour conserver plusieurs logs, envisagez de générer des fichiers de log horodatés plutôt que d’écraser `/tmp/wtex.log`.

## Développement

* Le code Go utilise `fsnotify` pour la surveillance de fichiers. Voir la doc de [fsnotify](https://github.com/fsnotify/fsnotify).
* Structure du projet :

    * `setup.sh` : script d’installation et compilation.
    * `wtexwatch.go` : code source principal.
    * `go.mod`, `go.sum` : gérés automatiquement après `setup.sh`.