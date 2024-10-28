package main

import (
	"bytes"
	"encoding/csv"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"text/template"
)

func main() {
	// This will be the input file path containing KNX group addresses
	if len(os.Args) < 3 {
		fmt.Println("Usage: go run ./ [input_file] [output_dir]") //nolint:forbidigo // Cli needs to output info
		os.Exit(1)
	}

	// Read the input file path from command line argument
	outputDir := os.Args[2]

	// Open and read the input file
	fileContent, err := os.ReadFile(os.Args[1])
	if err != nil {
		fmt.Printf("error reading file: %v\n", err) //nolint:forbidigo // Cli needs to output info
		os.Exit(1)
	}

	if _, err = os.ReadDir(outputDir); err != nil {
		err = os.MkdirAll(outputDir, 0o750)
		if err != nil {
			fmt.Printf("error creating output dir: %v\n", err) //nolint:forbidigo // Cli needs to output info
			os.Exit(1)
		}
	}

	ga, err := parseCSV(fileContent)
	if err != nil {
		fmt.Printf("error parsing csv: %v\n", err) //nolint:forbidigo // Cli needs to output info
		os.Exit(1)
	}

	gaOutput, err := generateGAs(ga)
	if err != nil {
		fmt.Printf("error generating GA creator: %v\n", err) //nolint:forbidigo // Cli needs to output info
		os.Exit(1)
	}

	err = os.WriteFile(filepath.Join(outputDir, "createGroupAddresses.lua"), gaOutput, 0o644) //nolint:gosec // Group and others read is fine
	if err != nil {
		fmt.Printf("error writing GA creator at %q: %v\n", filepath.Join(outputDir, "createGroupAddresses.lua"), err) //nolint:forbidigo // Cli needs to output info
		os.Exit(1)
	}

	enumsOutput := generateGAEnums(ga)

	err = os.WriteFile(filepath.Join(outputDir, "ADDRESSES.lua"), enumsOutput, 0o644) //nolint:gosec // Group and others read is fine
	if err != nil {
		fmt.Printf("error writing GA enums: %v\n", err) //nolint:forbidigo // Cli needs to output info
		os.Exit(1)
	}
}

// parse the CSV content and convert it into a slice of GroupAddress structs
func parseCSV(content []byte) ([]GroupAddress, error) {
	// using encoding/csv package and csv.NewReader, parse the content as csv input into slice of GroupAddress struct
	reader := csv.NewReader(bytes.NewReader(content))

	var groupAddresses []GroupAddress

	var idx int

	for {
		record, err := reader.Read()
		idx++

		if err != nil {
			if errors.Is(err, io.EOF) {
				return groupAddresses, nil
			}

			return nil, err
		}

		// skip the header line
		if record[0] == "Group name" {
			continue
		}

		if len(record) < 6 {
			return nil, fmt.Errorf("csv line %d has too little data, expected at least 6 cols, got: %d", idx, len(record))
		}

		if addressIsAParent(record[1]) {
			continue
		}

		addr, err := parseAddress(record[1])
		if err != nil {
			return nil, fmt.Errorf("csv line %d has invalid address: %w", idx, err)
		}

		// convert each record into GroupAddress struct and append to slice
		groupAddress := GroupAddress{
			Name:          parseName(record[0], &addr),
			Address:       addr,
			DatapointType: parseDPTForDriverWorks(record[5]),
			Description:   strings.TrimSpace(record[4]),
			Kind:          parseKind(&addr),
		}

		groupAddresses = append(groupAddresses, groupAddress)
	}
}

func generateGAs(ga []GroupAddress) ([]byte, error) {
	tpl, err := template.New("").Parse(`
---@return table<number,GroupAddress>
function CreateGroupAddresses()
	return { {{ range .GroupAddresses }}
		GroupAddress("{{.}}", "{{.Address}}", "{{.DatapointType}}"),
		{{- end }}
	}
end
	`)
	if err != nil {
		return nil, err
	}

	b := bytes.NewBuffer([]byte{})

	err = tpl.Execute(b, map[string]interface{}{
		"GroupAddresses": ga,
	})
	if err != nil {
		return nil, err
	}

	return b.Bytes(), nil
}

func generateGAEnums(ga []GroupAddress) []byte {
	kinds := map[string][]GroupAddress{}

	header := bytes.NewBufferString("---@alias GROUP_ADDRESS_NAME")

	for _, g := range ga {
		k := g.Kind.String()

		if _, ok := kinds[k]; !ok {
			kinds[k] = make([]GroupAddress, 0)
		}

		kinds[k] = append(kinds[k], g)
	}

	b := bytes.NewBuffer([]byte{})

	for kind, GAs := range kinds {
		k := "GROUP_ADDRESS_NAME_" + kind

		header.WriteByte('\n')
		header.WriteString("---|" + k)

		b.WriteByte('\n')
		b.WriteString("---@alias " + k)
		b.WriteByte('\n')

		for _, g := range GAs {
			if g.Description != "" {
				b.WriteString("--- " + strings.Join(strings.Split(g.Description, "\n"), "\n--- ") + "\n")
			}

			if g.DatapointType.IsUnknown {
				b.WriteString("--- HAS UNKNOWN DPT\n")
			}

			fmt.Fprintf(b, "---|%q", g.String())
			b.WriteByte('\n')
		}
	}

	header.WriteByte('\n')

	return append(header.Bytes(), b.Bytes()...)
}
