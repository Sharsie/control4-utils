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

// TODO make it nice
// TODO provide a consistent way to inject utilities into driver implementations

var rev string

func main() {
	err := run()
	if err != nil {
		fmt.Printf("driver-manager [%s]\n", rev) //nolint:forbidigo // Cli needs to output info
		fmt.Println(err)                         //nolint:forbidigo // Cli needs to output info
		os.Exit(1)
	}
}

func run() error {
	// This will be the input file path containing KNX group addresses
	if len(os.Args) < 2 {
		return errors.New("usage: driver-manager [input_package_json_file_path]")
	}

	packageJSONPath := filepath.Clean(os.Args[1])

	// Open and read the input file
	packageJSONFile, err := os.OpenFile(packageJSONPath, os.O_RDWR, 0o644) //nolint:gosec // User should be able to provide arbitrary path
	if err != nil {
		return fmt.Errorf("error reading file: %w", err)
	}

	var pJSON map[string]interface{}
	dec := json.NewDecoder(packageJSONFile)

	err = dec.Decode(&pJSON)
	if err != nil {
		return fmt.Errorf("error decoding file: %w", err)
	}

	if pJSON["control4"] == nil {
		pJSON["control4"] = make(map[string]interface{}, 0)
	}

	if v, ok := pJSON["control4"].(map[string]interface{}); ok {
		if v["icon"] == nil {
			v["icon"] = make(map[string]interface{}, 0)
		}

		if i, iconOk := v["icon"].(map[string]interface{}); iconOk {
			if _, hasSmall := i["small"]; !hasSmall {
				i["small"] = "icons/logo_16.png"
			}

			if _, hasLarge := i["large"]; !hasLarge {
				i["large"] = "icons/logo_32.png"
			}

			i["image_source"] = "c4z"
			v["icon"] = i
		}

		v["manufacturer"] = "C3C"

		pJSON["control4"] = v
	}

	err = packageJSONFile.Truncate(0)
	if err != nil {
		return fmt.Errorf("failed to truncate file: %w", err)
	}

	_, err = packageJSONFile.Seek(0, 0)
	if err != nil {
		return fmt.Errorf("failed to seek to the beginning of file: %w", err)
	}

	enc := json.NewEncoder(packageJSONFile)
	enc.SetIndent(" ", "  ")

	err = enc.Encode(pJSON)
	if err != nil {
		return fmt.Errorf("error encoding json into file: %w", err)
	}

	return copyIcons(filepath.Join(filepath.Dir(packageJSONPath), "src", "www"))
}

func copyIcons(dst string) error {
	return fs.WalkDir(files.Icons, ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		relPath := filepath.Clean(filepath.Join(dst, path))

		if d.IsDir() {
			err = os.MkdirAll(relPath, 0o750)
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

		_, err = io.Copy(f, src)
		if err != nil {
			return fmt.Errorf("failed to copy icon file %q: %w", path, err)
		}

		return nil
	})
}
