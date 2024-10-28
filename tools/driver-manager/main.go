package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"

	"git.c3c.cz/c3c/control4-utils/tools/driver-manager/files"
)

var version string

func main() {
	err := run()
	if err != nil {
		fmt.Printf("driver-manager %s\n", version)
		fmt.Println(err) //nolint:forbidigo // Cli needs to output info
		os.Exit(1)
	}
}

func run() error {
	// This will be the input file path containing KNX group addresses
	if len(os.Args) < 2 {
		return errors.New("usage: driver-manager [input_package_json_file_path]")
	}

	packageJsonPath := os.Args[1]

	// Open and read the input file
	packageJsonFile, err := os.OpenFile(packageJsonPath, os.O_RDWR, 0o644)
	if err != nil {
		return fmt.Errorf("error reading file: %w", err)
	}

	var pJson map[string]interface{}
	dec := json.NewDecoder(packageJsonFile)

	err = dec.Decode(&pJson)
	if err != nil {
		return fmt.Errorf("error decoding file: %w", err)
	}

	if pJson["control4"] == nil {
		pJson["control4"] = make(map[string]interface{}, 0)
	}

	if v, ok := pJson["control4"].(map[string]interface{}); ok {
		if v["icon"] == nil {
			v["icon"] = make(map[string]interface{}, 0)
		}

		if i, ok := v["icon"].(map[string]interface{}); ok {
			i["image_source"] = "c4z"
			i["small"] = "icons/logo_16.png"
			i["large"] = "icons/logo_32.png"
			v["icon"] = i
		}

		v["manufacturer"] = "C3C"

		pJson["control4"] = v
	}

	err = packageJsonFile.Truncate(0)
	if err != nil {
		return fmt.Errorf("failed to truncate file: %w", err)
	}

	_, err = packageJsonFile.Seek(0, 0)
	if err != nil {
		return fmt.Errorf("failed to seek to the beginning of file: %w", err)
	}

	enc := json.NewEncoder(packageJsonFile)
	enc.SetIndent(" ", "  ")

	err = enc.Encode(pJson)
	if err != nil {
		return fmt.Errorf("error encoding json into file: %w", err)
	}

	return copyIcons(filepath.Join(filepath.Dir(packageJsonPath), "www"))
}

func copyIcons(dst string) error {
	return fs.WalkDir(files.Icons, ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		relPath := filepath.Join(dst, path)

		if d.IsDir() {
			err = os.MkdirAll(relPath, 0o755)
			if err != nil {
				return fmt.Errorf("failed to create icon dir %q: %w", path, err)
			}
			return nil
		}

		f, err := os.Create(relPath)
		if err != nil {
			return fmt.Errorf("failed to create icon file %q: %w", path, err)
		}

		src, err := files.Icons.Open(path)
		if err != nil {
			return fmt.Errorf("failed to open icon file %q: %w", path, err)
		}

		fmt.Printf("copying %q to %q\n", path, relPath)
		_, err = io.Copy(f, src)
		if err != nil {
			return fmt.Errorf("failed to copy icon file %q: %w", path, err)
		}

		return nil
	})
}
