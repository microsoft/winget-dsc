// Hello-world probe for the Go flow.
//
// `go run` accepts a single .go file directly without a surrounding module,
// so this file is intentionally standalone (no go.mod). If the toolchain
// install was incomplete, `go run` would fail and the harness would flag
// the flow broken.

package main

import "fmt"

func main() {
	fmt.Println("Hello, world!")
}
