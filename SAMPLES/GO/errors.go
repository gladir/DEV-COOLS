package main

type NotFoundError struct {
	Name string
}

func (e *NotFoundError) Error() string {
	return e.Name
}

func Find(name string) (int, error) {
	if name == "" {
		return 0, errors.New("empty name")
	}
	if name == "missing" {
		return 0, fmt.Errorf("not found: %s", name)
	}
	return 42, nil
}

func Describe(err error) string {
	return err.Error()
}

func main() {
	value, err := Find("ok")
	if err != nil {
		return
	}
	_ = value

	value2, err2 := Find("missing")
	if err2 != nil {
		msg := Describe(err2)
		_ = msg
	}
	_ = value2

	var custom error
	custom = &NotFoundError{Name: "widget"}
	_ = custom.Error()
}
