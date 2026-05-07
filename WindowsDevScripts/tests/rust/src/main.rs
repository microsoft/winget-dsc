// Hello-world probe for the Rust flow.
//
// Stays in the cargo project shape (Cargo.toml + src/main.rs) so the
// upcoming cli-rust scenario can extend it cleanly with dependencies
// (clap) without re-shaping the test layout.

fn main() {
    println!("Hello, world!");
}
