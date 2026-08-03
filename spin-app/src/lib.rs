use spin_sdk::http::{IntoResponse, Request, Response, Method};
use spin_sdk::http_component;

/// A simple Spin HTTP component.
#[http_component]
fn handle_spin_app(req: Request) -> anyhow::Result<impl IntoResponse> {
    match (req.method(), req.path_and_query().as_deref().unwrap_or("/")) {
        (&Method::Get, "/hello") => {
            Ok(Response::builder()
                .status(200)
                .header("content-type", "text/plain")
                .body("Hello, World!")
                .build())
        }
        (&Method::Get, "/compute") => {
            let result = fibonacci(35);
            Ok(Response::builder()
                .status(200)
                .header("content-type", "text/plain")
                .body(format!("Fibonacci(35) = {}", result))
                .build())
        }
        _ => {
            Ok(Response::builder()
                .status(404)
                .header("content-type", "text/plain")
                .body("Not Found")
                .build())
        }
    }
}

fn fibonacci(n: u32) -> u32 {
    if n <= 1 {
        return n;
    }
    fibonacci(n - 1) + fibonacci(n - 2)
}
