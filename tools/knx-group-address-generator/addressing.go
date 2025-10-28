package main

import (
	"fmt"
	"strconv"
	"strings"
)

type Kind int32

const (
	KindUNKNOWN Kind = iota
	KindSWITCH
	KindDIMMER
	KindHEATING
	KindVENTILATION
	KindSCENE
	KindMEDIA
	KindCONTROL
)

var KindName = map[Kind]string{
	0: "Other",
	1: "Switch",
	2: "Dimmer",
	3: "Heat",
	4: "Vent",
	5: "Scene",
	6: "Media",
	7: "Control",
}

func (x Kind) String() string {
	return KindName[x]
}

func (x Kind) Prefix() string {
	if x == KindUNKNOWN {
		return ""
	}

	return KindName[x] + " "
}

type Name struct {
	Prefix string
	Source string
}

func (x *Name) String() string {
	return x.Prefix + x.Source
}

type Address struct {
	Main   uint16
	Middle uint16
	Sub    uint16
}

func (x *Address) String() string {
	return fmt.Sprintf("%d/%d/%d", x.Main, x.Middle, x.Sub)
}

type DatapointType struct {
	Value     uint16
	IsUnknown bool
}

func (x *DatapointType) String() string {
	if x.IsUnknown {
		return "DPT_1"
	}

	return fmt.Sprintf("DPT_%d", x.Value)
}

type GroupAddress struct {
	Name          Name
	Description   string
	Kind          Kind
	Address       Address
	DatapointType DatapointType
}

func (x *GroupAddress) String() string {
	return x.Kind.Prefix() + x.Name.String()
}

func addressIsAParent(input string) bool {
	return strings.ContainsRune(input, '-')
}

func parseAddress(input string) (Address, error) {
	parts := strings.Split(input, "/")
	if len(parts) != 3 {
		return Address{}, fmt.Errorf("invalid input for a group address: %q", input)
	}

	main, err := strconv.ParseUint(parts[0], 10, 16)
	if err != nil {
		return Address{}, fmt.Errorf("invalid input for a group address, cannot parse main %q: %w", parts[0], err)
	}

	middle, err := strconv.ParseUint(parts[1], 10, 16)
	if err != nil {
		return Address{}, fmt.Errorf("invalid input for a group address, cannot parse middle %q: %w", parts[1], err)
	}

	sub, err := strconv.ParseUint(parts[2], 10, 16)
	if err != nil {
		return Address{}, fmt.Errorf("invalid input for a group address, cannot parse sub %q: %w", parts[2], err)
	}

	return Address{
		Main:   uint16(main),
		Middle: uint16(middle),
		Sub:    uint16(sub),
	}, nil
}

// make adjustments to the naming for consistency (should be fixed in the source ideally, TODO)
// some adjustments seem weird...backwards compat, sorrai
func parseName(source string, address *Address) Name {
	name := Name{
		Source: source,
	}

	if address.Main >= 1 && address.Main <= 6 {
		switch address.Middle {
		case 0:
			name.Prefix = "LF "
		case 1:
			name.Prefix = "UF "
		case 3:
			name.Prefix = "EXT "
		}

		if strings.HasPrefix(name.Source, name.Prefix) {
			name.Source = strings.Replace(name.Source, name.Prefix, "", 1)
		}
	}

	return name
}

func parseKind(address *Address) Kind {
	switch address.Main {
	case 0:
		if address.Middle == 2 {
			return KindSCENE
		}
	case 1:
		return KindSWITCH
	case 2:
		return KindDIMMER
	case 3:
		return KindHEATING
	case 4:
		return KindVENTILATION
	case 5:
		return KindMEDIA
	case 6:
		return KindCONTROL
	}

	return KindUNKNOWN
}

func parseDPTForDriverWorks(input string) DatapointType {
	parts := strings.Split(input, "-")
	if len(parts) < 2 {
		return DatapointType{
			IsUnknown: true,
		}
	}

	v, err := strconv.ParseUint(parts[1], 10, 16)
	if err != nil {
		return DatapointType{
			IsUnknown: true,
		}
	}

	return DatapointType{
		Value: uint16(v),
	}
}
