#!/usr/bin/env bash
set -e

# Nom du fichier Go et du binaire
GOFILE="wtexwatch.go"
BINARY="wtexwatch"

# Contenu du programme Go
cat << 'EOF' > "$GOFILE"
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/fsnotify/fsnotify"
	"flag"
)

func usage() {
	fmt.Fprintf(flag.CommandLine.Output(),
		"Usage: %s [-v] <tex file to watch>\n", filepath.Base(os.Args[0]))
	fmt.Fprintf(flag.CommandLine.Output(),
		"Cela surveille le fichier .tex et recompile avec pdflatex à chaque modification.\n\n")
	fmt.Fprintf(flag.CommandLine.Output(),
		"Options:\n")
	fmt.Fprintf(flag.CommandLine.Output(),
		"  -v    Mode verbeux : affiche la sortie complète de pdflatex.\n")
}

func fileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

func runPdflatex(texfile string, verbose bool, logPath string) error {
	cmd := exec.Command("pdflatex", "-interaction=nonstopmode", texfile)
	logFile, err := os.Create(logPath)
	if err != nil {
		return fmt.Errorf("impossible de créer le fichier de log: %w", err)
	}
	defer logFile.Close()

	cmd.Stdout = logFile
	cmd.Stderr = logFile

	err = cmd.Run()
	data, _ := os.ReadFile(logPath)
	if err != nil {
		fmt.Printf("pdflatex a échoué (voir ci-dessous) :\n%s\n", string(data))
		return err
	}

	if verbose {
		fmt.Printf("pdflatex a réussi, sortie complète :\n%s\n", string(data))
	} else {
		fmt.Print("OK\n")
	}
	return nil
}

func main() {
	verbose := flag.Bool("v", false, "Mode verbeux : afficher la sortie complète de pdflatex")
	flag.Usage = usage
	flag.Parse()

	if flag.NArg() != 1 {
		usage()
		os.Exit(1)
	}
	texfile := flag.Arg(0)

	absPath, err := filepath.Abs(texfile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Impossible de déterminer le chemin absolu: %v\n", err)
		os.Exit(1)
	}
	if !fileExists(absPath) {
		fmt.Fprintf(os.Stderr, "Fichier '%s' introuvable\n", absPath)
		os.Exit(1)
	}

	if _, err := exec.LookPath("pdflatex"); err != nil {
		fmt.Fprintln(os.Stderr, "pdflatex n'est pas installé ou non dans le PATH")
		os.Exit(1)
	}

	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Erreur lors de la création du watcher: %v\n", err)
		os.Exit(1)
	}
	defer watcher.Close()

	fmt.Printf("Surveillance de '%s' pour changements...\n", absPath)
	dir := filepath.Dir(absPath)
	if err := watcher.Add(dir); err != nil {
		fmt.Fprintf(os.Stderr, "Impossible d’ajouter le répertoire au watcher: %v\n", err)
		os.Exit(1)
	}

	var lastModTime time.Time
	debounceDelay := 500 * time.Millisecond
	events := make(chan struct{}, 1)

	go func() {
		for range events {
			time.Sleep(debounceDelay)
			select {
			case <-events:
			default:
			}
			fmt.Printf("Compilation de %s... ", absPath)
			logPath := "/tmp/wtex.log"
			if err := runPdflatex(absPath, *verbose, logPath); err != nil {
				// déjà affiché
			}
		}
	}()

	for {
		select {
		case ev, ok := <-watcher.Events:
			if !ok {
				return
			}
			if ev.Op&(fsnotify.Write|fsnotify.Create) != 0 && filepath.Clean(ev.Name) == absPath {
				info, err := os.Stat(absPath)
				if err != nil {
					continue
				}
				modTime := info.ModTime()
				if modTime.After(lastModTime) {
					lastModTime = modTime
					select {
					case events <- struct{}{}:
					default:
					}
				}
			}
		case err, ok := <-watcher.Errors:
			if !ok {
				return
			}
			fmt.Fprintf(os.Stderr, "Erreur du watcher: %v\n", err)
		}
	}
}
EOF

# Vérifier que Go est installé
if ! command -v go >/dev/null 2>&1; then
  echo "Erreur : Go n'est pas installé ou non dans le PATH. Veuillez installer Go avant de lancer ce script."
  exit 1
fi

# Initialiser le module Go si nécessaire
if [ ! -f go.mod ]; then
  echo "Initialisation du module Go..."
  go mod init wtexwatch
fi

# Ajouter la dépendance fsnotify et télécharger les modules
echo "Récupération de la dépendance github.com/fsnotify/fsnotify..."
go get github.com/fsnotify/fsnotify

# Tidy pour mettre à jour go.mod et go.sum
go mod tidy

# Compiler le programme
echo "Compilation du binaire..."
go build -o "$BINARY" "$GOFILE"

# Rendre le binaire exécutable (normalement déjà le cas)
chmod +x "$BINARY"

echo "Terminé. Vous pouvez lancer : ./$BINARY [-v] fichier.tex"